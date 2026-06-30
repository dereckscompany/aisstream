# aisstream 0.0.3

* **`data.table` shapes now documented per column.** The `@return` of `ais_metadata()` and `as_position_report()` now refines its `data.table` with typed nested bullets — one bullet per column carrying its roxyassert element type (`character | NA`, `numeric | NA`, `POSIXct | NA`) — instead of a bare prose description. Documenting the columns generates the matching `assert_has_columns()` and per-column contracts, so a flattener that emits the wrong column set or type is now caught at the boundary. Every column is nullable because each derives from a `*_or_na` coercion (or `parse_go_time()`, which yields `NA` on a missing or unparseable timestamp).

# aisstream 0.0.2

* **Recorder API reshaped: `record_to_ndjson()` → `ndjson_sink()`.** The recorder is
  now a **message-handler factory** you register yourself, instead of a free function
  that mutated the client by side effect:

  ```r
  # before
  record_to_ndjson(ais, dir = "ais-data"); ais$run()
  # after
  ais$on("message", ndjson_sink("ais-data")); ais$run()
  ```

  `ndjson_sink(dir, flush_seconds = 5)` returns a `function(raw)` that, on each frame,
  appends the raw string to the current hourly file, rolls the file on the turn of a
  UTC hour, and flushes once per `flush_seconds` — all message-driven, with **no
  separate `later` timer** and no dependency on the client. Durability is unchanged:
  the durable write is the same, rotation is the same (`ais-YYYY-MM-DDTHH.ndjson` via
  `ndjson_hour_path()`, which is kept), and the data-at-risk on an abrupt kill is
  still bounded to roughly the last `flush_seconds`.

  This is a **breaking** change, made deliberately pre-1.0 (the package has zero
  adoption, so there is no deprecation shim). The motivation is idiom: the sink now
  mirrors [`connectcore::ws_file_sink()`](https://github.com/dereckscompany/connectcore)
  (a factory that returns a handler) and reads like Node — `ais$on("message", ...)` —
  rather than a free function reaching into the client to wire handlers and a timer.

* The unused `later` import is dropped (the sink no longer schedules on the `later`
  loop).

# aisstream 0.0.1

Initial release. A thin R client for the [AISStream.io](https://aisstream.io) live
vessel-tracking (AIS) WebSocket feed, built on
[connectcore](https://github.com/dereckscompany/connectcore). Open one socket,
subscribe with bounding boxes plus optional MMSI / message-type filters, and handle
raw frames Node-ws style — reconnect, re-subscribe, keepalive and a silence watchdog
are all inherited from `connectcore::StreamClient`.

* **`AisStream`** — the client (an R6 subclass of `connectcore::StreamClient`).
  Construct it with an API key and bounding boxes, register handlers with
  `$on(event, handler)`, then `$run()`. It overrides only two seams: `.resubscribe()`
  (send the subscription frame on every (re)connect, meeting the server's 3-second
  subscribe deadline) and `.dispatch()` (route `{"error": ...}` frames to the
  `"error"` event). `$update_subscription()` swaps the live subscription
  (swap-and-replace, ~1/sec).

* **The hot path is parse-free.** AISStream closes a connection whose TCP read queue
  backs up, and the whole-world firehose runs at ~300 msg/s — so `.dispatch()` does
  **no** JSON parsing on the data path. It emits the raw string under `"message"`;
  the only inspection is a cheap prefix check to split off error frames.

* **`record_to_ndjson()`** — the durable "read fast or get dropped" recorder. Opens
  an hourly NDJSON file before any frame, appends each raw frame with minimal work,
  and flushes / rolls by UTC hour on the `later` loop. Parse the files offline.

* **Parse helpers** — `parse_ais()` (JSON.parse for AIS), `parse_go_time()` (the Go
  non-ISO `time_utc` format), and flatteners `ais_metadata()` /
  `as_position_report()` for the stable common fields, plus the bounding-box and
  subscription builders. `AIS_MESSAGE_TYPES` exports the 25 known type names. Every
  argument and return is typed and runtime-checked with
  [roxyassert](https://github.com/dereckscompany/roxyassert).
