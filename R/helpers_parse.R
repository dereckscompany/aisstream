# File: R/helpers_parse.R
# Offline parse helpers for AIS frames. These are deliberately OUT of the hot path:
# the live `.dispatch()` never parses (the vendor drops a slow reader), so parsing
# happens in a handler or, more usually, afterwards over recorded NDJSON. The
# flatteners model only the stable, common fields — the AISStream message bodies are
# BETA and unstable, so modelling all 25 of them would only rot. Built on
# connectcore's coercion toolkit.

#' Parse a Go-format AIS timestamp to POSIXct (UTC)
#'
#' AISStream stamps every frame's `MetaData$time_utc` in Go's default time format —
#' `"2006-01-02 15:04:05.999999999 -0700 MST"`, e.g.
#' `"2022-12-29 18:22:32.318353 +0000 UTC"` — which is **not** ISO 8601, so a plain
#' parser fails. This strips the trailing zone name (`UTC`) and parses the rest as
#' `"%Y-%m-%d %H:%M:%OS %z"`, preserving sub-second precision. Returns `NA` (UTC) for
#' `NULL`/empty/unparseable input rather than erroring.
#'
#' @param x (any) a scalar timestamp string (or `NULL`).
#' @return (class<POSIXct>) the time in UTC (length 1; `NA` if unparseable).
#' @importFrom lubridate parse_date_time with_tz
#' @export
parse_go_time <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(lubridate::with_tz(lubridate::parse_date_time(NA_character_, orders = "YmdHMOS", tz = "UTC"), "UTC"))
  }
  raw <- as.character(x[[1L]])
  # Drop the trailing Go zone abbreviation (e.g. " UTC", " MST"); keep the numeric
  # offset, which carries the actual zone.
  trimmed <- sub("\\s+[A-Za-z]+$", "", raw)
  parsed <- suppressWarnings(
    lubridate::parse_date_time(trimmed, orders = "Ymd HMOS z", tz = "UTC", exact = FALSE)
  )
  return(lubridate::with_tz(parsed, "UTC"))
}

#' Parse a raw AIS frame (JSON.parse for AIS)
#'
#' A thin wrapper over [jsonlite::fromJSON()] (with `simplifyVector = FALSE`, so the
#' shape is a predictable nested list) — the AIS analogue of JavaScript's
#' `JSON.parse`. Deliberately generic: it does **not** model the 25 message bodies,
#' because the AISStream API is BETA and its bodies shift. Use it in a handler, or —
#' more typically — offline over recorded NDJSON. Error frames (`{"error": "..."}`)
#' parse like any other object.
#'
#' @param raw (scalar<character>) one raw frame as a JSON string.
#' @return (list) the parsed frame (a nested list).
#' @importFrom jsonlite fromJSON
#' @export
parse_ais <- function(raw) {
  assert_args_parse_ais(raw)
  return(assert_return_parse_ais(jsonlite::fromJSON(raw, simplifyVector = FALSE)))
}

#' Flatten an AIS frame's MetaData to a one-row data.table
#'
#' Pulls the stable common fields from a parsed frame's `MetaData` (capital D) into a
#' single tidy row: `message_type`, `mmsi`, `ship_name` (trimmed), `latitude`,
#' `longitude`, and `time_utc` (POSIXct, via [parse_go_time()]). Present on every
#' message type, so it is the safe denominator across the feed.
#'
#' @param parsed (list) one frame, already parsed by [parse_ais()].
#' @return (class<data.table>) a one-row data.table of the common metadata.
#' @importFrom data.table data.table
#' @export
ais_metadata <- function(parsed) {
  assert_args_ais_metadata(parsed)
  meta <- parsed[["MetaData"]]
  if (is.null(meta)) {
    meta <- list()
  }
  dt <- data.table::data.table(
    message_type = connectcore::chr_or_na(parsed[["MessageType"]]),
    mmsi = connectcore::chr_or_na(meta[["MMSI"]]),
    ship_name = trimws(connectcore::chr_or_na(meta[["ShipName"]])),
    latitude = connectcore::num_or_na(meta[["latitude"]]),
    longitude = connectcore::num_or_na(meta[["longitude"]]),
    time_utc = parse_go_time(meta[["time_utc"]])
  )
  return(assert_return_ais_metadata(dt[]))
}

#' Flatten an AIS PositionReport to a one-row data.table
#'
#' Combines the common metadata (see [ais_metadata()]) with the stable fields of a
#' `PositionReport` body — speed/course over ground, true heading, navigational
#' status, rate of turn — into one tidy row. Returns the metadata row with `NA`
#' position fields when the frame is not a `PositionReport` (so it row-binds cleanly
#' across a mixed stream). The body lives under `Message$PositionReport`.
#'
#' @param parsed (list) one frame, already parsed by [parse_ais()].
#' @return (class<data.table>) a one-row data.table of position fields plus metadata.
#' @importFrom data.table set
#' @export
as_position_report <- function(parsed) {
  assert_args_as_position_report(parsed)
  dt <- ais_metadata(parsed)
  body <- parsed[["Message"]][["PositionReport"]]
  if (is.null(body)) {
    body <- list()
  }
  data.table::set(dt, j = "sog", value = connectcore::num_or_na(body[["Sog"]]))
  data.table::set(dt, j = "cog", value = connectcore::num_or_na(body[["Cog"]]))
  data.table::set(dt, j = "true_heading", value = connectcore::num_or_na(body[["TrueHeading"]]))
  data.table::set(dt, j = "nav_status", value = connectcore::num_or_na(body[["NavigationalStatus"]]))
  data.table::set(dt, j = "rate_of_turn", value = connectcore::num_or_na(body[["RateOfTurn"]]))
  return(assert_return_as_position_report(dt[]))
}
