# Flatten an AIS frame's MetaData to a one-row data.table

Pulls the stable common fields from a parsed frame's `MetaData` (capital
D) into a single tidy row: `message_type`, `mmsi`, `ship_name`
(trimmed), `latitude`, `longitude`, and `time_utc` (POSIXct, via
[`parse_go_time()`](https://dereckscompany.github.io/aisstream/reference/parse_go_time.md)).
Present on every message type, so it is the safe denominator across the
feed.

## Usage

``` r
ais_metadata(parsed)
```

## Arguments

- parsed:

  (list) one frame, already parsed by
  [`parse_ais()`](https://dereckscompany.github.io/aisstream/reference/parse_ais.md).

## Value

(data.table) a one-row data.table of the common metadata.

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
