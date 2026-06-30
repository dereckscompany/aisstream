# Normalise a list of bounding boxes

Applies
[`normalise_bounding_box()`](https://dereckscompany.github.io/aisstream/reference/normalise_bounding_box.md)
to each box in a non-empty list; boxes may overlap (AISStream
de-duplicates server-side).

## Usage

``` r
normalise_bounding_boxes(bounding_boxes)
```

## Arguments

- bounding_boxes:

  (list) a non-empty list of boxes, each in a shape
  [`normalise_bounding_box()`](https://dereckscompany.github.io/aisstream/reference/normalise_bounding_box.md)
  accepts.

## Value

(list) the list of canonical nested-corner boxes.
