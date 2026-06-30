# Normalise a single bounding box to AISStream's nested-corner form

Accepts a box in either supported shape and returns AISStream's
canonical `list(c(min_lat, min_lon), c(max_lat, max_lon))` (two
`[lat, lon]` corners):

- a **named list** `list(min_lat=, min_lon=, max_lat=, max_lon=)` (the
  JS-object style), or

- a **raw nested box** `list(c(lat1, lon1), c(lat2, lon2))` (corner
  order is irrelevant; the corners are sorted into a min/max pair).
  Every latitude is validated to `[-90, 90]` and every longitude to
  `[-180, 180]`.

## Usage

``` r
normalise_bounding_box(box)
```

## Arguments

- box:

  (list) one bounding box, in either supported shape.

## Value

(list) the box as `list(c(min_lat, min_lon), c(max_lat, max_lon))`.
