# Package index

## Client

The live vessel-tracking client.

- [`AisStream`](https://dereckscompany.github.io/aisstream/reference/AisStream.md)
  : AisStream: Live Vessel-Tracking Client for AISStream.io

## Recording

Durable NDJSON recording — read fast or get dropped.

- [`ndjson_sink()`](https://dereckscompany.github.io/aisstream/reference/ndjson_sink.md)
  : A durable hourly-NDJSON message sink
- [`ndjson_hour_path()`](https://dereckscompany.github.io/aisstream/reference/ndjson_hour_path.md)
  : Build the hourly NDJSON file path for a UTC time

## Parsing

Offline parse helpers for recorded AIS frames.

- [`parse_ais()`](https://dereckscompany.github.io/aisstream/reference/parse_ais.md)
  : Parse a raw AIS frame (JSON.parse for AIS)
- [`parse_go_time()`](https://dereckscompany.github.io/aisstream/reference/parse_go_time.md)
  : Parse a Go-format AIS timestamp to POSIXct (UTC)
- [`ais_metadata()`](https://dereckscompany.github.io/aisstream/reference/ais_metadata.md)
  : Flatten an AIS frame's MetaData to a one-row data.table
- [`as_position_report()`](https://dereckscompany.github.io/aisstream/reference/as_position_report.md)
  : Flatten an AIS PositionReport to a one-row data.table

## Subscription

Building and validating the subscription frame.

- [`build_subscription()`](https://dereckscompany.github.io/aisstream/reference/build_subscription.md)
  : Build the AISStream.io subscription frame (as a JSON string)
- [`normalise_bounding_box()`](https://dereckscompany.github.io/aisstream/reference/normalise_bounding_box.md)
  : Normalise a single bounding box to AISStream's nested-corner form
- [`normalise_bounding_boxes()`](https://dereckscompany.github.io/aisstream/reference/normalise_bounding_boxes.md)
  : Normalise a list of bounding boxes

## Constants

- [`AIS_MESSAGE_TYPES`](https://dereckscompany.github.io/aisstream/reference/AIS_MESSAGE_TYPES.md)
  : AIS Message Types
