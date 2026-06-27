# AisStream: the subclass seams, exercised with NO live socket. We reach the
# private .dispatch()/.resubscribe() via .__enclos_env__. R6 public methods are
# locked bindings, so to fake the transport we use a tiny test subclass that
# overrides send()/is_open() and records what would go on the wire.

make_client <- function(...) {
  return(AisStream$new(
    api_key = "TEST-KEY",
    bounding_boxes = list(list(min_lat = 40, min_lon = -74, max_lat = 41, max_lon = -73)),
    ...
  ))
}

# A client whose socket is pretend-open and whose send() captures the frame.
FakeAisStream <- R6::R6Class(
  "FakeAisStream",
  inherit = AisStream,
  public = list(
    sent = NULL,
    fake_open = FALSE,
    send = function(message) {
      self$sent <- c(self$sent, message)
      return(invisible(self))
    },
    is_open = function() {
      return(self$fake_open)
    }
  )
)

make_fake <- function(open = FALSE, ...) {
  fake <- FakeAisStream$new(
    api_key = "TEST-KEY",
    bounding_boxes = list(list(min_lat = 40, min_lon = -74, max_lat = 41, max_lon = -73)),
    ...
  )
  fake$fake_open <- open
  return(fake)
}

test_that("a fresh client constructs, inherits StreamClient, and is not open", {
  ais <- make_client()
  expect_s3_class(ais, "AisStream")
  expect_s3_class(ais, "StreamClient")
  expect_false(ais$is_open())
})

test_that("subscription_frame reflects the constructor parameters", {
  ais <- make_client(message_types = "PositionReport", ship_mmsi = "123456789")
  parsed <- jsonlite::fromJSON(ais$subscription_frame(), simplifyVector = FALSE)
  expect_identical(parsed$APIKey, "TEST-KEY")
  expect_identical(parsed$FilterMessageTypes, list("PositionReport"))
  expect_identical(parsed$FiltersShipMMSI, list("123456789"))
})

test_that("constructor validation aborts on bad input", {
  expect_error(make_client(message_types = "Nope"), "Unknown message type")
  expect_error(make_client(ship_mmsi = as.character(1:51)), "at most 50")
  expect_error(
    AisStream$new(api_key = "K", bounding_boxes = list(list(min_lat = 200, min_lon = 0, max_lat = 1, max_lon = 1))),
    "latitude"
  )
  expect_error(AisStream$new(api_key = "K", bounding_boxes = list()), "at least one")
})

test_that("an empty API key aborts construction", {
  expect_error(
    AisStream$new(api_key = "", bounding_boxes = list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1))),
    "api_key"
  )
})

test_that(".dispatch routes error frames to 'error' and everything else to 'message'", {
  ais <- make_client()
  seen <- new.env(parent = emptyenv())
  seen$messages <- character(0)
  seen$errors <- character(0)
  ais$on("message", function(m) seen$messages <- c(seen$messages, m))
  ais$on("error", function(e) seen$errors <- c(seen$errors, e))

  dispatch <- ais$.__enclos_env__$private$.dispatch
  dispatch('{"MessageType":"PositionReport","MetaData":{}}')
  dispatch('{"error": "Api Key Is Not Valid"}')
  dispatch('{"errorless":"still a message"}') # only the exact {"error prefix routes to error

  expect_length(seen$messages, 2L)
  expect_length(seen$errors, 1L)
  expect_identical(seen$errors[[1]], '{"error": "Api Key Is Not Valid"}')
})

test_that(".dispatch emits the RAW string (parse-free hot path)", {
  ais <- make_client()
  captured <- NULL
  ais$on("message", function(m) captured <<- m)
  raw <- '{"MessageType":"PositionReport","MetaData":{"MMSI":1}}'
  ais$.__enclos_env__$private$.dispatch(raw)
  expect_type(captured, "character")
  expect_identical(captured, raw) # verbatim, not parsed
})

test_that(".resubscribe sends the subscription frame", {
  fake <- make_fake(open = TRUE, message_types = "PositionReport")
  fake$.__enclos_env__$private$.resubscribe()
  expect_identical(fake$sent, fake$subscription_frame())
})

test_that("update_subscription swaps stored params and re-validates", {
  ais <- make_client()
  ais$update_subscription(message_types = "ShipStaticData", ship_mmsi = "999")
  parsed <- jsonlite::fromJSON(ais$subscription_frame(), simplifyVector = FALSE)
  expect_identical(parsed$FilterMessageTypes, list("ShipStaticData"))
  expect_identical(parsed$FiltersShipMMSI, list("999"))

  # NULL arguments leave the corresponding part unchanged.
  ais$update_subscription(message_types = "PositionReport")
  parsed2 <- jsonlite::fromJSON(ais$subscription_frame(), simplifyVector = FALSE)
  expect_identical(parsed2$FilterMessageTypes, list("PositionReport"))
  expect_identical(parsed2$FiltersShipMMSI, list("999")) # untouched

  # invalid replacements still abort
  expect_error(ais$update_subscription(message_types = "Nope"), "Unknown message type")
})

test_that("update_subscription does not send while the socket is closed", {
  fake <- make_fake(open = FALSE)
  fake$update_subscription(message_types = "PositionReport")
  expect_null(fake$sent) # is_open() is FALSE, so no send
})

test_that("update_subscription re-sends immediately while the socket is open", {
  fake <- make_fake(open = TRUE)
  fake$update_subscription(message_types = "PositionReport")
  expect_identical(fake$sent, fake$subscription_frame())
})
