# Parse a Go-format AIS timestamp to POSIXct (UTC)

AISStream stamps every frame's `MetaData$time_utc` in Go's default time
format — `"2006-01-02 15:04:05.999999999 -0700 MST"`, e.g.
`"2022-12-29 18:22:32.318353 +0000 UTC"` — which is **not** ISO 8601, so
a plain parser fails. This strips the trailing zone name (`UTC`) and
parses the rest as `"%Y-%m-%d %H:%M:%OS %z"`, preserving sub-second
precision. Returns `NA` (UTC) for `NULL`/empty/unparseable input rather
than erroring.

## Usage

``` r
parse_go_time(x)
```

## Arguments

- x:

  (any) a scalar timestamp string (or `NULL`).

## Value

(class\<POSIXct\>) the time in UTC (length 1; `NA` if unparseable).
