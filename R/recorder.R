# File: R/recorder.R
# The durable NDJSON recorder — the answer to "read fast or get dropped". It is a
# message-handler factory: `ndjson_sink()` returns a `function(raw)` you register
# yourself with `ais$on("message", ...)`, mirroring connectcore::ws_file_sink. Each
# frame does the minimum (append the raw string to an open hourly file) and the same
# handler rolls the file by UTC hour and flushes on a timer it tracks itself — no
# separate `later` loop, no dependency on the client. This mirrors the proven
# data-scraper recorder.

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

#' A durable hourly-NDJSON message sink
#'
#' The proven "read fast or get dropped" recorder, as a **message-handler factory**.
#' Returns a `function(raw)` you register yourself — `ais$on("message",
#' ndjson_sink(dir))` — exactly the way you would use [connectcore::ws_file_sink()],
#' so the sink is a pure handler with no dependency on the client and reads like Node.
#'
#' Each frame keeps the durable-write behaviour message-driven (there is no separate
#' `later` timer): on every call it computes the current UTC hour slot and, when the
#' slot changes (or on the very first frame), closes the previous hourly file and
#' opens the next one (`<dir>/ais-YYYY-MM-DDTHH.ndjson`) in append mode; it then
#' appends the **raw** frame plus a newline immediately — the hot path stays
#' parse-free, one frame per line (NDJSON). Only once at least `flush_seconds` have
#' elapsed since the last flush does it `flush()` the connection and reset the timer.
#'
#' Durability semantics: writes are **append-only**, so any already-flushed line
#' survives an abrupt kill (`SIGKILL`, power loss); the data at risk is bounded to the
#' frames written in the last `flush_seconds` window. The final partial buffer is
#' flushed when the process exits — the open file connection is flushed and closed on
#' garbage collection / R shutdown — so a clean stop loses nothing. Parse the
#' resulting files offline with [parse_ais()] and the flatteners.
#'
#' @param dir (scalar<character>) output directory; created if missing.
#' @param flush_seconds (scalar<numeric in ]0, Inf[>) minimum seconds between flushes
#'   to disk; the data-at-risk window on an abrupt kill. Default `5`.
#' @return (function) a handler `function(raw)` suitable for
#'   `ais$on("message", ...)`.
#' @importFrom lubridate now floor_date
#' @export
ndjson_sink <- function(dir, flush_seconds = 5) {
  assert_args_ndjson_sink(dir, flush_seconds)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  state <- new.env(parent = emptyenv())
  state$hour <- NULL
  state$con <- NULL
  state$last_flush <- NULL

  handler <- function(raw) {
    now_utc <- lubridate::now("UTC")
    this_hour <- lubridate::floor_date(now_utc, "hour")
    if (is.null(state$con) || this_hour > state$hour) {
      if (!is.null(state$con)) {
        try(close(state$con), silent = TRUE)
      }
      state$hour <- this_hour
      state$con <- file(ndjson_hour_path(dir, this_hour), open = "at")
      state$last_flush <- now_utc
    }

    # Append the raw frame — the absolute minimum on the hot path.
    cat(raw, "\n", file = state$con, sep = "")

    if (as.numeric(now_utc - state$last_flush, units = "secs") >= flush_seconds) {
      try(flush(state$con), silent = TRUE)
      state$last_flush <- now_utc
    }
    return(invisible(NULL))
  }

  return(assert_return_ndjson_sink(handler))
}
