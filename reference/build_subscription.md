# Build the AISStream.io subscription frame (as a JSON string)

Assembles the one subscription message AISStream expects within 3
seconds of connecting: `APIKey` and `BoundingBoxes` are always present;
`FilterMessageTypes` and `FiltersShipMMSI` are included **only when
non-empty** (the server rejects an empty `[]`). Bounding boxes are
normalised and range-checked, the MMSI filter is capped at 50, and
message types must be a unique subset of
[AIS_MESSAGE_TYPES](https://dereckscompany.github.io/aisstream/reference/AIS_MESSAGE_TYPES.md).
`auto_unbox = TRUE` keeps the API key and scalar fields as JSON scalars,
while the box/filter arrays stay arrays.

## Usage

``` r
build_subscription(
  api_key,
  bounding_boxes,
  message_types = NULL,
  ship_mmsi = NULL
)
```

## Arguments

- api_key:

  (scalar\<character\>) the AISStream.io API key (non-empty).

- bounding_boxes:

  (list) a non-empty list of boxes (see
  [`normalise_bounding_boxes()`](https://dereckscompany.github.io/aisstream/reference/normalise_bounding_boxes.md)).

- message_types:

  (vector\<character, 0..\> \| NULL) optional `FilterMessageTypes`;
  unique values, each one of
  [AIS_MESSAGE_TYPES](https://dereckscompany.github.io/aisstream/reference/AIS_MESSAGE_TYPES.md).
  `NULL`/empty omits the field.

- ship_mmsi:

  (vector\<character, 0..\> \| NULL) optional `FiltersShipMMSI`; at most
  50 MMSI strings. `NULL`/empty omits the field.

## Value

(scalar\<character\>) the subscription frame as a JSON string.
