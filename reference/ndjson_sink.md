# A durable hourly-NDJSON message sink

The proven "read fast or get dropped" recorder, as a **message-handler
factory**. Returns a `function(raw)` you register yourself —
`ais$on("message", ndjson_sink(dir))` — exactly the way you would use
[`connectcore::ws_file_sink()`](https://rdrr.io/pkg/connectcore/man/ws_file_sink.html),
so the sink is a pure handler with no dependency on the client and reads
like Node.

## Usage

``` r
ndjson_sink(dir, flush_seconds = 5)
```

## Arguments

- dir:

  (scalar\<character\>) output directory; created if missing.

- flush_seconds:

  (scalar\<numeric in \]0, Inf\[\>) minimum seconds between flushes to
  disk; the data-at-risk window on an abrupt kill. Default `5`.

## Value

(function) a handler `function(raw)` suitable for
`ais$on("message", ...)`.

## Details

Each frame keeps the durable-write behaviour message-driven (there is no
separate `later` timer): on every call it computes the current UTC hour
slot and, when the slot changes (or on the very first frame), closes the
previous hourly file and opens the next one
(`<dir>/ais-YYYY-MM-DDTHH.ndjson`) in append mode; it then appends the
**raw** frame plus a newline immediately — the hot path stays
parse-free, one frame per line (NDJSON). Only once at least
`flush_seconds` have elapsed since the last flush does it
[`flush()`](https://rdrr.io/r/base/connections.html) the connection and
reset the timer.

Durability semantics: writes are **append-only**, so any already-flushed
line survives an abrupt kill (`SIGKILL`, power loss); the data at risk
is bounded to the frames written in the last `flush_seconds` window. The
final partial buffer is flushed when the process exits — the open file
connection is flushed and closed on garbage collection / R shutdown — so
a clean stop loses nothing. Parse the resulting files offline with
[`parse_ais()`](https://dereckscompany.github.io/aisstream/reference/parse_ais.md)
and the flatteners.
