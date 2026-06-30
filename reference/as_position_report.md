# Flatten an AIS PositionReport to a one-row data.table

Combines the common metadata (see
[`ais_metadata()`](https://dereckscompany.github.io/aisstream/reference/ais_metadata.md))
with the stable fields of a `PositionReport` body — speed/course over
ground, true heading, navigational status, rate of turn — into one tidy
row. Returns the metadata row with `NA` position fields when the frame
is not a `PositionReport` (so it row-binds cleanly across a mixed
stream). The body lives under `Message$PositionReport`.

## Usage

``` r
as_position_report(parsed)
```

## Arguments

- parsed:

  (list) one frame, already parsed by
  [`parse_ais()`](https://dereckscompany.github.io/aisstream/reference/parse_ais.md).

## Value

(data.table) a one-row data.table of position fields plus metadata.

- message_type (character \| NA) the AIS message type (e.g.
  `"PositionReport"`); `NA` when the frame omits it.

- mmsi (character \| NA) the vessel MMSI identifier; `NA` when absent.

- ship_name (character \| NA) the trimmed ship name; `NA` when absent.

- latitude (numeric \| NA) latitude in decimal degrees; `NA` when
  absent.

- longitude (numeric \| NA) longitude in decimal degrees; `NA` when
  absent.

- time_utc (POSIXct \| NA) the frame timestamp in UTC; `NA` when missing
  or unparseable.

- sog (numeric \| NA) speed over ground (knots); `NA` for a non-position
  frame.

- cog (numeric \| NA) course over ground (degrees); `NA` for a
  non-position frame.

- true_heading (numeric \| NA) true heading (degrees); `NA` for a
  non-position frame.

- nav_status (numeric \| NA) navigational status code; `NA` for a
  non-position frame.

- rate_of_turn (numeric \| NA) rate of turn; `NA` for a non-position
  frame.
