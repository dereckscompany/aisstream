# AisStream: Live Vessel-Tracking Client for AISStream.io

An event-driven client for the [AISStream.io](https://aisstream.io) live
AIS (vessel-tracking) WebSocket feed, built on
[connectcore::StreamClient](https://rdrr.io/pkg/connectcore/man/StreamClient.html).
You construct it with an API key and one or more bounding boxes (plus
optional MMSI / message-type filters), register handlers with
`$on(event, handler)` exactly as in Node's `ws.on(...)`, then `$run()`
to pump the loop. The 3-second subscribe deadline,
reconnect-and-resubscribe, keepalive, and a silence watchdog are all
inherited.

### The hot path is parse-free (this is non-negotiable)

AISStream monitors your TCP read queue and **closes the connection if it
backs up** — at the whole-world firehose (~300 msg/s) a per-message JSON
parse cannot keep up. So `.dispatch()` does **no** parsing on the data
path: it emits the raw string under `"message"`, and the *only*
inspection is a cheap
[`startsWith()`](https://rdrr.io/r/base/startsWith.html) prefix check to
route error frames (`{"error": ...}`) to the `"error"` event instead.
Parse in your own handler if you must, but for the firehose the proven
pattern is
[`ndjson_sink()`](https://dereckscompany.github.io/aisstream/reference/ndjson_sink.md)
— `$on("message", ndjson_sink(dir))` (append raw frames now, parse
offline later with
[`parse_ais()`](https://dereckscompany.github.io/aisstream/reference/parse_ais.md)).

### Bounding boxes

Each box is two opposite `[lat, lon]` corners. Pass them either as named
lists — `list(min_lat =, min_lon =, max_lat =, max_lon =)` (the
JS-object style) — or as raw nested corners
`list(c(lat1, lon1), c(lat2, lon2))`; both normalise to AISStream's
`[[min_lat, min_lon], [max_lat, max_lon]]`. Latitudes are validated to
`[-90, 90]`, longitudes to `[-180, 180]`. Boxes may overlap.

## Super class

[`connectcore::StreamClient`](https://rdrr.io/pkg/connectcore/man/StreamClient.html)
-\> `AisStream`

## Methods

### Public methods

- [`AisStream$new()`](#method-AisStream-initialize)

- [`AisStream$update_subscription()`](#method-AisStream-update_subscription)

- [`AisStream$subscription_frame()`](#method-AisStream-subscription_frame)

- [`AisStream$clone()`](#method-AisStream-clone)

Inherited methods

- [`connectcore::StreamClient$close()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-close)
- [`connectcore::StreamClient$connect()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-connect)
- [`connectcore::StreamClient$is_open()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-is_open)
- [`connectcore::StreamClient$on()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-on)
- [`connectcore::StreamClient$run()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-run)
- [`connectcore::StreamClient$send()`](https://rdrr.io/pkg/connectcore/man/StreamClient.html#method-send)

------------------------------------------------------------------------

### `AisStream$new()`

Initialise an AisStream client

Validates and stores the subscription parameters, then constructs the
underlying
[connectcore::StreamClient](https://rdrr.io/pkg/connectcore/man/StreamClient.html)
against the AISStream endpoint. The subscription itself is sent by
`.resubscribe()` after each (re)connect, so the 3-second subscribe
deadline is met automatically.

#### Usage

    AisStream$new(
      api_key = connectcore::env_or("AISSTREAM_API_KEY"),
      bounding_boxes,
      message_types = NULL,
      ship_mmsi = NULL,
      stale_timeout = 120,
      ...
    )

#### Arguments

- `api_key`:

  (scalar\<character\>) the AISStream.io API key. Defaults to the
  `AISSTREAM_API_KEY` environment variable.

- `bounding_boxes`:

  (list) a non-empty list of bounding boxes, each either a named
  `list(min_lat =, min_lon =, max_lat =, max_lon =)` or raw nested
  corners `list(c(lat1, lon1), c(lat2, lon2))`.

- `message_types`:

  (vector\<character, 0..\> \| NULL) optional `FilterMessageTypes`;
  unique values, each one of
  [AIS_MESSAGE_TYPES](https://dereckscompany.github.io/aisstream/reference/AIS_MESSAGE_TYPES.md).
  `NULL` (default) subscribes to all types.

- `ship_mmsi`:

  (vector\<character, 0..\> \| NULL) optional `FiltersShipMMSI`; at most
  50 MMSI strings. `NULL` (default) applies no MMSI filter.

- `stale_timeout`:

  (scalar\<numeric in \]0, Inf\[\>) force a reconnect if no frame
  arrives within this many seconds (silence watchdog). Default `120`.

- `...`:

  further arguments passed to
  [connectcore::StreamClient](https://rdrr.io/pkg/connectcore/man/StreamClient.html)'s
  constructor (e.g. `auto_reconnect`, `max_reconnects`,
  `proactive_reconnect`).

#### Returns

(class\<AisStream\>) invisibly, self.

------------------------------------------------------------------------

### `AisStream$update_subscription()`

Replace the live subscription (swap-and-replace)

Updates the stored subscription parameters and, if the socket is open,
re-sends the new subscription frame immediately. AISStream treats a
re-sent subscription as a full **swap-and-replace** (not a merge), and
rate-limits it to roughly **once per second** — call this no more than
once a second. Any argument left `NULL` leaves that part of the
subscription unchanged.

#### Usage

    AisStream$update_subscription(
      bounding_boxes = NULL,
      message_types = NULL,
      ship_mmsi = NULL
    )

#### Arguments

- `bounding_boxes`:

  (list \| NULL) replacement boxes (see `$initialize()`), or `NULL` to
  keep the current ones.

- `message_types`:

  (vector\<character, 0..\> \| NULL) replacement `FilterMessageTypes`,
  or `NULL` to keep the current value.

- `ship_mmsi`:

  (vector\<character, 0..\> \| NULL) replacement `FiltersShipMMSI`, or
  `NULL` to keep the current value.

#### Returns

(class\<AisStream\>) invisibly, self.

------------------------------------------------------------------------

### `AisStream$subscription_frame()`

The current subscription frame (JSON string)

Returns the exact JSON the client sends on (re)connect, built from the
stored parameters. Handy for tests and for inspecting what will go on
the wire without opening a socket.

#### Usage

    AisStream$subscription_frame()

#### Returns

(scalar\<character\>) the subscription frame as a JSON string.

------------------------------------------------------------------------

### `AisStream$clone()`

The objects of this class are cloneable with this method.

#### Usage

    AisStream$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Whole-world position reports, recorded to hourly NDJSON.
ais <- AisStream$new(
  bounding_boxes = list(list(min_lat = -90, min_lon = -180, max_lat = 90, max_lon = 180)),
  message_types = "PositionReport"
)
ais$on("message", ndjson_sink(dir = "ais-data"))
ais$on("error", function(e) message("AIS error: ", e))
ais$run() # blocks, pumping the event loop; Ctrl-C to stop
} # }
```
