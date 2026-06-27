
# aisstream

<!-- badges: start -->

<!-- badges: end -->

A thin R client for the [AISStream.io](https://aisstream.io) live
vessel-tracking (AIS) WebSocket feed, built on
[connectcore](https://github.com/dereckscompany/connectcore). Open one
socket, subscribe with bounding boxes plus optional MMSI / message-type
filters, and handle raw frames Node-ws style. Reconnect, re-subscribe,
keepalive and a silence watchdog are inherited; parse helpers and a
durable NDJSON recorder are included.

## Why it is shaped this way

AISStream is **WebSocket-only** (no REST). On connect you must send one
JSON subscription within three seconds or the server drops you, and —
the rule that shapes everything — it **monitors your TCP read queue and
closes the connection if it backs up**. The whole-world feed runs at
roughly 300 messages a second, so the message hot path cannot afford a
per-message JSON parse.

So `aisstream` keeps the data path **parse-free**: `.dispatch()` emits
each frame as the raw string and only does a cheap prefix check to split
off error frames. You record the raw frames now (see
[`record_to_ndjson()`](#recording)) and parse them offline. The
connection machinery — the 3-second subscribe, reconnect-and-
resubscribe, keepalive, the silence watchdog — all comes from
`connectcore`.

## Installation

This package uses [renv](https://rstudio.github.io/renv/):

``` r
renv::install("dereckscompany/aisstream")
```

## Constructing a client and inspecting the subscription

Everything below is **network-free** — no socket is opened. We build a
client and look at the exact subscription frame it would send.

``` r
library(aisstream)

ais <- AisStream$new(
  api_key = "DEMO-KEY", # normally read from the AISSTREAM_API_KEY env var
  bounding_boxes = list(
    # a box is two opposite [lat, lon] corners; pass it JS-object style ...
    list(min_lat = 40.4, min_lon = -74.3, max_lat = 41.0, max_lon = -73.7),
    # ... or as raw nested corners (order does not matter).
    list(c(50.0, -1.5), c(51.0, 1.5))
  ),
  message_types = "PositionReport",
  ship_mmsi = c("366998510", "367123450")
)

# The exact JSON sent on (re)connect — APIKey + BoundingBoxes always, filters only
# when non-empty (an empty filter is omitted, never sent as []).
cat(ais$subscription_frame())
#> {"APIKey":"DEMO-KEY","BoundingBoxes":[[[40.4,-74.3],[41,-73.7]],[[50,-1.5],[51,1.5]]],"FilterMessageTypes":["PositionReport"],"FiltersShipMMSI":["366998510","367123450"]}
```

Filters are omitted entirely when empty:

``` r
minimal <- AisStream$new(
  api_key = "DEMO-KEY",
  bounding_boxes = list(list(min_lat = -90, min_lon = -180, max_lat = 90, max_lon = 180))
)
cat(minimal$subscription_frame())
#> {"APIKey":"DEMO-KEY","BoundingBoxes":[[[-90,-180],[90,180]]]}
```

## Handling frames

Register handlers Node-ws style, then `$run()` to pump the event loop.
`"message"` carries the **raw** string (parse it yourself if you must);
`"error"` carries an AISStream error frame.

``` r
ais$on("message", function(raw) {
  pr <- as_position_report(parse_ais(raw))
  print(pr[, .(mmsi, ship_name, latitude, longitude, sog, cog)])
})
ais$on("error", function(raw) message("AIS error: ", raw))

ais$run() # blocks, pumping the loop; Ctrl-C to stop
```

## Parsing frames offline

`parse_ais()` is JSON.parse for AIS, and the flatteners pull the stable
common fields into a `data.table`. The `time_utc` field arrives in Go’s
(non-ISO) format and is parsed specially.

``` r
frame <- paste0(
  '{"MessageType":"PositionReport",',
  '"MetaData":{"MMSI":368207620,"ShipName":"OCEAN TITAN  ",',
  '"latitude":40.12,"longitude":-74.21,',
  '"time_utc":"2022-12-29 18:22:32.318353 +0000 UTC"},',
  '"Message":{"PositionReport":{"Sog":12.3,"Cog":89.1,',
  '"TrueHeading":90,"NavigationalStatus":0,"RateOfTurn":-2}}}'
)

as_position_report(parse_ais(frame))
#>      message_type      mmsi   ship_name latitude longitude            time_utc
#>            <char>    <char>      <char>    <num>     <num>              <POSc>
#> 1: PositionReport 368207620 OCEAN TITAN    40.12    -74.21 2022-12-29 18:22:32
#>      sog   cog true_heading nav_status rate_of_turn
#>    <num> <num>        <num>      <num>        <num>
#> 1:  12.3  89.1           90          0           -2
```

## Recording

The proven “read fast or get dropped” pattern: wire the recorder before
connecting, then run. It appends each raw frame to an hourly NDJSON file
(rolling by UTC hour, flushing every few seconds) doing the minimum on
the hot path.

``` r
ais <- AisStream$new(
  bounding_boxes = list(list(min_lat = -90, min_lon = -180, max_lat = 90, max_lon = 180)),
  message_types = "PositionReport"
)
record_to_ndjson(ais, dir = "ais-data")
ais$run()
```

See `vignette("recording-ais")` for the full rationale.

## The message types

``` r
length(AIS_MESSAGE_TYPES)
#> [1] 25
head(unlist(AIS_MESSAGE_TYPES, use.names = FALSE))
#> [1] "PositionReport"         "UnknownMessage"         "AddressedSafetyMessage"
#> [4] "AddressedBinaryMessage" "AidsToNavigationReport" "AssignedModeCommand"
```

## License

MIT
