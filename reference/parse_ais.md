# Parse a raw AIS frame (JSON.parse for AIS)

A thin wrapper over
[`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
(with `simplifyVector = FALSE`, so the shape is a predictable nested
list) — the AIS analogue of JavaScript's `JSON.parse`. Deliberately
generic: it does **not** model the 25 message bodies, because the
AISStream API is BETA and its bodies shift. Use it in a handler, or —
more typically — offline over recorded NDJSON. Error frames
(`{"error": "..."}`) parse like any other object.

## Usage

``` r
parse_ais(raw)
```

## Arguments

- raw:

  (scalar\<character\>) one raw frame as a JSON string.

## Value

(list) the parsed frame (a nested list).
