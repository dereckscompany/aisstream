# File: R/AisStream.R
# The AISStream.io live vessel-tracking client. A thin subclass of
# connectcore::StreamClient that overrides only two seams — .resubscribe() (send the
# subscription frame on every (re)connect) and .dispatch() (route error frames out
# of the data stream). Everything else — reconnect, keepalive, the silence watchdog —
# is inherited.

#' AisStream: Live Vessel-Tracking Client for AISStream.io
#'
#' An event-driven client for the [AISStream.io](https://aisstream.io) live AIS
#' (vessel-tracking) WebSocket feed, built on [connectcore::StreamClient]. You
#' construct it with an API key and one or more bounding boxes (plus optional MMSI /
#' message-type filters), register handlers with `$on(event, handler)` exactly as in
#' Node's `ws.on(...)`, then `$run()` to pump the loop. The 3-second subscribe
#' deadline, reconnect-and-resubscribe, keepalive, and a silence watchdog are all
#' inherited.
#'
#' ### The hot path is parse-free (this is non-negotiable)
#' AISStream monitors your TCP read queue and **closes the connection if it backs
#' up** — at the whole-world firehose (~300 msg/s) a per-message JSON parse cannot
#' keep up. So `.dispatch()` does **no** parsing on the data path: it emits the raw
#' string under `"message"`, and the *only* inspection is a cheap `startsWith()`
#' prefix check to route error frames (`{"error": ...}`) to the `"error"` event
#' instead. Parse in your own handler if you must, but for the firehose the proven
#' pattern is [ndjson_sink()] — `$on("message", ndjson_sink(dir))` (append raw frames
#' now, parse offline later with [parse_ais()]).
#'
#' ### Bounding boxes
#' Each box is two opposite `[lat, lon]` corners. Pass them either as named lists —
#' `list(min_lat =, min_lon =, max_lat =, max_lon =)` (the JS-object style) — or as
#' raw nested corners `list(c(lat1, lon1), c(lat2, lon2))`; both normalise to
#' AISStream's `[[min_lat, min_lon], [max_lat, max_lon]]`. Latitudes are validated to
#' `[-90, 90]`, longitudes to `[-180, 180]`. Boxes may overlap.
#'
#' @examples
#' \dontrun{
#' # Whole-world position reports, recorded to hourly NDJSON.
#' ais <- AisStream$new(
#'   bounding_boxes = list(list(min_lat = -90, min_lon = -180, max_lat = 90, max_lon = 180)),
#'   message_types = "PositionReport"
#' )
#' ais$on("message", ndjson_sink(dir = "ais-data"))
#' ais$on("error", function(e) message("AIS error: ", e))
#' ais$run() # blocks, pumping the event loop; Ctrl-C to stop
#' }
#'
#' @importFrom R6 R6Class
#' @export
AisStream <- R6::R6Class(
  "AisStream",
  inherit = connectcore::StreamClient,
  public = list(
    #' @description
    #' Initialise an AisStream client
    #'
    #' Validates and stores the subscription parameters, then constructs the
    #' underlying [connectcore::StreamClient] against the AISStream endpoint. The
    #' subscription itself is sent by `.resubscribe()` after each (re)connect, so the
    #' 3-second subscribe deadline is met automatically.
    #' @param api_key (scalar<character>) the AISStream.io API key. Defaults to the
    #'   `AISSTREAM_API_KEY` environment variable.
    #' @param bounding_boxes (list) a non-empty list of bounding boxes, each either a
    #'   named `list(min_lat =, min_lon =, max_lat =, max_lon =)` or raw nested
    #'   corners `list(c(lat1, lon1), c(lat2, lon2))`.
    #' @param message_types (vector<character, 0..> | NULL) optional `FilterMessageTypes`;
    #'   unique values, each one of [AIS_MESSAGE_TYPES]. `NULL` (default) subscribes
    #'   to all types.
    #' @param ship_mmsi (vector<character, 0..> | NULL) optional `FiltersShipMMSI`; at most
    #'   50 MMSI strings. `NULL` (default) applies no MMSI filter.
    #' @param stale_timeout (scalar<numeric in ]0, Inf[>) force a reconnect if no
    #'   frame arrives within this many seconds (silence watchdog). Default `120`.
    #' @param ... further arguments passed to [connectcore::StreamClient]'s
    #'   constructor (e.g. `auto_reconnect`, `max_reconnects`, `proactive_reconnect`).
    #' @return (class<AisStream>) invisibly, self.
    initialize = function(
      api_key = connectcore::env_or("AISSTREAM_API_KEY"),
      bounding_boxes,
      message_types = NULL,
      ship_mmsi = NULL,
      stale_timeout = 120,
      ...
    ) {
      assert_args_AisStream__initialize(api_key, bounding_boxes, message_types, ship_mmsi, stale_timeout)
      if (!nzchar(api_key)) {
        rlang::abort("`api_key` is empty; set AISSTREAM_API_KEY or pass api_key.")
      }
      # Validate eagerly by building the frame once (also normalises the boxes).
      private$.bounding_boxes <- normalise_bounding_boxes(bounding_boxes)
      private$.message_types <- message_types
      private$.ship_mmsi <- ship_mmsi
      private$.api_key <- api_key
      build_subscription(api_key, private$.bounding_boxes, message_types, ship_mmsi)
      super$initialize(url = AISSTREAM_URL, stale_timeout = stale_timeout, ...)
      return(invisible(assert_return_AisStream__initialize(self)))
    },

    #' @description
    #' Replace the live subscription (swap-and-replace)
    #'
    #' Updates the stored subscription parameters and, if the socket is open, re-sends
    #' the new subscription frame immediately. AISStream treats a re-sent subscription
    #' as a full **swap-and-replace** (not a merge), and rate-limits it to roughly
    #' **once per second** — call this no more than once a second. Any argument left
    #' `NULL` leaves that part of the subscription unchanged.
    #' @param bounding_boxes (list | NULL) replacement boxes (see `$initialize()`), or
    #'   `NULL` to keep the current ones.
    #' @param message_types (vector<character, 0..> | NULL) replacement
    #'   `FilterMessageTypes`, or `NULL` to keep the current value.
    #' @param ship_mmsi (vector<character, 0..> | NULL) replacement `FiltersShipMMSI`, or
    #'   `NULL` to keep the current value.
    #' @return (class<AisStream>) invisibly, self.
    update_subscription = function(bounding_boxes = NULL, message_types = NULL, ship_mmsi = NULL) {
      assert_args_AisStream__update_subscription(bounding_boxes, message_types, ship_mmsi)
      if (!is.null(bounding_boxes)) {
        private$.bounding_boxes <- normalise_bounding_boxes(bounding_boxes)
      }
      if (!is.null(message_types)) {
        private$.message_types <- message_types
      }
      if (!is.null(ship_mmsi)) {
        private$.ship_mmsi <- ship_mmsi
      }
      # Re-validate the whole frame before storing intent.
      frame <- build_subscription(
        private$.api_key,
        private$.bounding_boxes,
        private$.message_types,
        private$.ship_mmsi
      )
      if (self$is_open()) {
        self$send(frame)
      }
      return(invisible(assert_return_AisStream__update_subscription(self)))
    },

    #' @description
    #' The current subscription frame (JSON string)
    #'
    #' Returns the exact JSON the client sends on (re)connect, built from the stored
    #' parameters. Handy for tests and for inspecting what will go on the wire without
    #' opening a socket.
    #' @return (scalar<character>) the subscription frame as a JSON string.
    subscription_frame = function() {
      frame <- build_subscription(
        private$.api_key,
        private$.bounding_boxes,
        private$.message_types,
        private$.ship_mmsi
      )
      return(assert_return_AisStream__subscription_frame(frame))
    }
  ),
  private = list(
    .api_key = NULL,
    .bounding_boxes = NULL,
    .message_types = NULL,
    .ship_mmsi = NULL,

    # Sent after every (re)connect by connectcore — this is what meets the
    # 3-second subscribe deadline and restores the subscription on reconnect.
    .resubscribe = function() {
      self$send(self$subscription_frame())
      return(invisible(NULL))
    },

    # The ONLY deviation from the inherited default, and it stays parse-free: a cheap
    # prefix check routes error frames ({"error": ...}) to "error"; every other frame
    # is emitted verbatim under "message" as the raw string. No JSON parse on the data
    # path — the vendor drops slow readers, so this is non-negotiable. The closing
    # quote of the "error" key is included so the check never mistakes a key that
    # merely *starts* with "error" for the error key.
    .dispatch = function(raw) {
      if (startsWith(raw, "{\"error\"")) {
        private$.emit("error", raw)
      } else {
        private$.emit("message", raw)
      }
      return(invisible(NULL))
    }
  )
)
