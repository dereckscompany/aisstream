# Build the hourly NDJSON file path for a UTC time

Files roll by UTC hour: `<dir>/ais-YYYY-MM-DDTHH.ndjson`. Exposed so
callers (and tests) can predict and find the current file.

## Usage

``` r
ndjson_hour_path(dir, at = lubridate::now("UTC"))
```

## Arguments

- dir:

  (scalar\<character\>) the output directory.

- at:

  (class\<POSIXct\>) the time whose hour names the file. Default
  `lubridate::now("UTC")`.

## Value

(scalar\<character\>) the full file path for that hour.
