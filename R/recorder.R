# File: R/recorder.R
# The durable NDJSON recorder — the answer to "read fast or get dropped". It wires a
# "message" handler that does the minimum (append the raw frame to an open
# connection, via connectcore::ws_file_sink) and schedules flush/roll on the `later`
# loop so the hot path never blocks on I/O. This mirrors the proven data-scraper
# recorder.

#' Build the hourly NDJSON file path for a UTC time
#'
#' Files roll by UTC hour: `<dir>/ais-YYYY-MM-DDTHH.ndjson`. Exposed so callers (and
#' tests) can predict and find the current file.
#'
#' @param dir (scalar<character>) the output directory.
#' @param at (class<POSIXct>) the time whose hour names the file. Default
#'   `lubridate::now("UTC")`.
#' @return (scalar<character>) the full file path for that hour.
#' @importFrom lubridate now with_tz
#' @export
ndjson_hour_path <- function(dir, at = lubridate::now("UTC")) {
  assert_args_ndjson_hour_path(dir, at)
  stamp <- format(lubridate::with_tz(at, "UTC"), "%Y-%m-%dT%H")
  return(assert_return_ndjson_hour_path(file.path(dir, sprintf("ais-%s.ndjson", stamp))))
}

#' Record an AIS stream to durable hourly NDJSON
#'
#' The proven "read fast or get dropped" recorder. It opens the first hourly file
#' **before** any message arrives, registers a `"message"` handler that appends each
#' **raw** frame (via [connectcore::ws_file_sink()] — the minimum work, so the socket
#' drains fast enough that AISStream never drops you), and schedules a task on the
#' `later` loop that every `flush_seconds` flushes the buffer to disk and, on the
#' turn of a UTC hour, closes the current file and opens the next. One frame per line,
#' so a crash costs at most the last unflushed window.
#'
#' This only **wires** the recorder; the caller then drives the loop with `ais$run()`
#' (or `ais$connect()` inside a host loop). Parse the resulting files offline with
#' [parse_ais()] and the flatteners.
#'
#' @param ais (class<AisStream>) the client to record (must not be open yet).
#' @param dir (scalar<character>) output directory; created if missing.
#' @param flush_seconds (scalar<numeric in ]0, Inf[>) flush/roll check interval in
#'   seconds. Default `5`.
#' @return (class<AisStream>) invisibly, `ais` (so the caller can chain `$run()`).
#' @importFrom lubridate now with_tz floor_date
#' @export
record_to_ndjson <- function(ais, dir, flush_seconds = 5) {
  assert_args_record_to_ndjson(ais, dir, flush_seconds)
  if (ais$is_open()) {
    rlang::abort("Wire `record_to_ndjson()` before connecting; `ais` is already open.")
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  state <- new.env(parent = emptyenv())
  state$hour <- lubridate::floor_date(lubridate::now("UTC"), "hour")
  state$path <- ndjson_hour_path(dir, state$hour)
  state$con <- file(state$path, open = "at")

  # Append each raw frame — the absolute minimum on the hot path.
  ais$on("message", connectcore::ws_file_sink(state$con))

  roll <- function() {
    now_utc <- lubridate::now("UTC")
    this_hour <- lubridate::floor_date(now_utc, "hour")
    if (this_hour > state$hour) {
      try(close(state$con), silent = TRUE)
      state$hour <- this_hour
      state$path <- ndjson_hour_path(dir, this_hour)
      state$con <- file(state$path, open = "at")
    } else {
      try(flush(state$con), silent = TRUE)
    }
    return(invisible(NULL))
  }

  schedule <- function() {
    later::later(
      function() {
        if (ais$is_open() || isTRUE(state$keep_going)) {
          roll()
        }
        schedule()
        return(invisible(NULL))
      },
      flush_seconds
    )
    return(invisible(NULL))
  }
  state$keep_going <- TRUE
  schedule()

  return(invisible(assert_return_record_to_ndjson(ais)))
}
