# Bounding-box normalisation + subscription-frame building (no network).

test_that("a named-list box normalises to canonical nested corners", {
  out <- normalise_bounding_box(list(min_lat = 40, min_lon = -74, max_lat = 41, max_lon = -73))
  expect_identical(out, list(c(40, -74), c(41, -73)))
})

test_that("a raw nested box normalises and sorts corners min/max", {
  # corners given reversed; should come out min-first.
  out <- normalise_bounding_box(list(c(41, -73), c(40, -74)))
  expect_identical(out, list(c(40, -74), c(41, -73)))
})

test_that("out-of-range coordinates abort", {
  expect_error(normalise_bounding_box(list(min_lat = 200, min_lon = 0, max_lat = 1, max_lon = 1)), "latitude")
  expect_error(normalise_bounding_box(list(min_lat = 0, min_lon = -200, max_lat = 1, max_lon = 1)), "longitude")
})

test_that("a malformed raw box aborts", {
  expect_error(normalise_bounding_box(list(c(1, 2, 3), c(4, 5))), "corner")
  expect_error(normalise_bounding_box(list(c(1, 2))), "two corners")
})

test_that("normalise_bounding_boxes rejects an empty list and maps over many", {
  expect_error(normalise_bounding_boxes(list()), "at least one")
  out <- normalise_bounding_boxes(list(
    list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1),
    list(c(11, 21), c(10, 20))
  ))
  expect_length(out, 2L)
  expect_identical(out[[2L]], list(c(10, 20), c(11, 21)))
})

test_that("build_subscription emits APIKey + BoundingBoxes and round-trips", {
  frame <- build_subscription(
    "TEST-KEY",
    list(list(min_lat = 40, min_lon = -74, max_lat = 41, max_lon = -73))
  )
  expect_type(frame, "character")
  parsed <- jsonlite::fromJSON(frame, simplifyVector = FALSE)
  expect_identical(parsed$APIKey, "TEST-KEY")
  # one box, two corners, each [lat, lon] (compare numerically: whole numbers may
  # round-trip back through JSON as integers)
  expect_length(parsed$BoundingBoxes, 1L)
  expect_equal(as.numeric(unlist(parsed$BoundingBoxes[[1]][[1]])), c(40, -74))
  expect_equal(as.numeric(unlist(parsed$BoundingBoxes[[1]][[2]])), c(41, -73))
})

test_that("empty filters are OMITTED entirely (never sent as [])", {
  frame <- build_subscription("K", list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)))
  expect_false(grepl("FilterMessageTypes", frame, fixed = TRUE))
  expect_false(grepl("FiltersShipMMSI", frame, fixed = TRUE))
  # explicit empty vectors are also omitted
  frame2 <- build_subscription(
    "K",
    list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
    message_types = character(0),
    ship_mmsi = character(0)
  )
  expect_false(grepl("Filter", frame2, fixed = TRUE))
})

test_that("a single filter value stays a JSON array (not unboxed to a scalar)", {
  frame <- build_subscription(
    "K",
    list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
    message_types = "PositionReport",
    ship_mmsi = "123456789"
  )
  parsed <- jsonlite::fromJSON(frame, simplifyVector = FALSE)
  expect_identical(parsed$FilterMessageTypes, list("PositionReport"))
  expect_identical(parsed$FiltersShipMMSI, list("123456789"))
})

test_that("duplicate message types abort", {
  expect_error(
    build_subscription(
      "K",
      list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
      message_types = c("PositionReport", "PositionReport")
    ),
    "unique"
  )
})

test_that("unknown message types abort", {
  expect_error(
    build_subscription(
      "K",
      list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
      message_types = "NotAType"
    ),
    "Unknown message type"
  )
})

test_that("more than 50 MMSI strings abort", {
  expect_error(
    build_subscription(
      "K",
      list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
      ship_mmsi = as.character(seq_len(51))
    ),
    "at most 50"
  )
  # exactly 50 is fine
  expect_type(
    build_subscription(
      "K",
      list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1)),
      ship_mmsi = as.character(seq_len(50))
    ),
    "character"
  )
})

test_that("an empty API key aborts", {
  expect_error(
    build_subscription("", list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1))),
    "non-empty"
  )
})
