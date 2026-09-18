# aisstream 0.2.2

## Replaced the remaining real-format MMSIs in the rendered docs

v0.2.1 replaced the real-format MMSI `368207620` in the offline parse test fixture (`tests/testthat/test-helpers_parse.R`) but missed the same value — and two more, `366998510` and `367123450` — still carried in `README.Rmd`/`README.md` and the `recording-ais` vignette.

* Replaced `368207620` with the canonical fake `999999999` in `README.Rmd` (and the regenerated `README.md`) and in `vignettes/recording-ais.Rmd`; kept the invented ship name "OCEAN TITAN" unchanged.
* Replaced the two-vessel `ship_mmsi` filter example in `README.Rmd`/`README.md` — `c("366998510", "367123450")`, both syntactically valid US-prefixed (MID 366/367) numbers, i.e. the format of real vessels — with two distinct all-nines fakes, `c("999999999", "999999998")`.
* Confirmed no other real-format MMSI remains under `README.Rmd`, `vignettes/`, the `R/` roxygen examples, or `inst/`.
* No code change; documentation only.

# aisstream 0.2.1

## Replaced a real-format MMSI in the offline parse fixtures

`tests/testthat/test-helpers_parse.R`'s representative `PositionReport` frame used MMSI `368207620` — a syntactically valid, US-prefixed (MID 368) vessel identifier, i.e. the format of a real ship's number, paired with the invented ship name "OCEAN TITAN". Nothing about the parser cares what the digits are (`mmsi` is carried through as a plain `character | NA` field with no format or checksum validation), so the fixture gains nothing from looking genuine.

* Replaced `368207620` with `999999999`, a canonical fake MMSI (all-nines, not a real assigned prefix), across all three occurrences in the file (the raw JSON fixture string, the parsed-list assertion, and the flattened-row assertion).
* Kept the invented ship name "OCEAN TITAN" unchanged.
* Confirmed no other test file in the package asserts on the old number.
* No code change; test fixture only.

# aisstream 0.2.0

## Typed input-validation conditions

* The connector's 11 non-transport `rlang::abort()` sites — a subscription argument or credential is malformed or violates a rule *before* any frame is sent (a bounding box that is not two corners, a coordinate outside its range, an empty api key, an unknown message type, more than 50 MMSI filters) — now signal a **classed condition** through a new `abort_aisstream_validation_error()` raiser (new `R/conditions.R`), so a caller branches on error *type* instead of grepping the message text. This follows the org convention (dereckscompany/tradebot-core#30; discussion "throw typed errors, not bare strings").
* The class vector is `c("aisstream_validation_error", "aisstream_error")`. `aisstream_error` is the connector's DOMAIN root, parallel to the transport `connectcore_error` root it inherits from `connectcore::StreamClient`: a validation failure is not a transport failure, so the two roots never meet — exactly the `core_error` / `connectcore_error` split the fleet already uses. Transport failures (connect, reconnect, keepalive, a `$send()` on a closed socket) keep their inherited `connectcore_stream_error` / `connectcore_error` classes, and a server error FRAME is still emitted Node-ws style as a `WS_EVENTS$ERROR` event rather than raised.
* The message strings are **byte-identical** to the bare `rlang::abort()` calls they replaced (a reverse-substitution proves all 11 reproduce master exactly; golden tests pin two representative sites), so existing tests and downstream message greps keep matching. The classes are purely additive; `conditionMessage()` and `inherits(e, "error")` are unchanged. No behaviour changes.

# aisstream 0.1.0

Modernise onto the released `connectcore` 0.3.0 and re-validate the WebSocket transport contract. aisstream was locked to `connectcore (>= 0.0.1)` — the version that predates the `StreamClient` `is_open()` readyState fix — so the inherited open-check compared the `websocket` package's *attributed* `readyState()` integer with `identical(., 1L)` and was `FALSE` even on an open socket, aborting every `send()` and throwing inside `.resubscribe()` so no subscription was ever sent (the silent-stall / 0-byte-capture failure mode). The floor bump carries connectcore's 0.2.1 fix (`== 1L` value comparison) into the live client; no aisstream code change was needed to adopt it because the `StreamClient` subclass contract — the two overridden seams (`.dispatch()`, `.resubscribe()`) and the public `send()`/`is_open()`/`run()`/`on()` surface — is unchanged across 0.0.1 -> 0.3.0.

* **`connectcore` Imports floor raised `0.0.1` -> `0.3.0`** and `renv.lock` re-recorded (via `renv::record`, never `snapshot`) to `connectcore` 0.3.0 (`RemoteSha` `a0410fd`); the previously missing `data.table` runtime record (a direct import) is added so a `renv::restore` install is complete.

* **WebSocket event names now reference `connectcore::WS_EVENTS`.** `.dispatch()` emits `connectcore::WS_EVENTS$ERROR` / `connectcore::WS_EVENTS$MESSAGE` instead of the bare `"error"` / `"message"` string literals — the same wire values, sourced from connectcore's exported constant rather than duplicated. The durable hourly-rolling `ndjson_sink()` recorder is retained deliberately: it is a superset of connectcore's single-line `ws_file_sink()` (UTC-hour rotation plus a flush timer that `ws_file_sink()` does not provide), and `parse_go_time()` parses AIS's Go-format timestamp string, for which connectcore has no epoch-based equivalent.

* No documented surface changed, so the regenerated docs (roxygen 7.3.3) are byte-identical to the release and the master-vs-tip `@return` sweep is clean; the two `data.table` methods keep their typed column bullets. The `Config/roxygen2/version` / `RoxygenNote` 7.3.3 reconciliation and the CI gates were already landed by the infra convergence PR (#9), so this release does not touch them.

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
