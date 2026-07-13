# Typed aisstream input-validation conditions. Every non-transport abort is
# raised through abort_aisstream_validation_error(), classed
# c("aisstream_validation_error", "aisstream_error") -- aisstream_error is the
# connector's DOMAIN root, parallel to the transport connectcore_error root it
# inherits from connectcore::StreamClient. The message strings stay byte-identical
# to the bare rlang::abort() calls each site replaced (the goldens below pin
# that). If a golden fails, the backward-compatibility contract broke.

test_that("abort_aisstream_validation_error layers aisstream_validation_error then aisstream_error", {
  err <- tryCatch(aisstream:::abort_aisstream_validation_error("boom"), error = function(e) e)
  expect_identical(
    class(err),
    c("aisstream_validation_error", "aisstream_error", "rlang_error", "error", "condition")
  )
  expect_identical(conditionMessage(err), "boom")
})

test_that("aisstream_validation_error is caught by the aisstream_error root but is NOT a transport error", {
  caught <- tryCatch(aisstream:::abort_aisstream_validation_error("x"), aisstream_error = function(e) "root")
  expect_identical(caught, "root")
  err <- tryCatch(aisstream:::abort_aisstream_validation_error("x"), error = function(e) e)
  expect_false(inherits(err, "connectcore_error"))
})

# ---- Real sites: class, and byte-identical message (golden) ----

test_that("build_subscription rejects an empty api_key with aisstream_validation_error (golden)", {
  err <- tryCatch(
    build_subscription(api_key = "", bounding_boxes = list(list(c(-10, -10), c(10, 10)))),
    error = function(e) e
  )
  expect_s3_class(err, "aisstream_validation_error")
  expect_s3_class(err, "aisstream_error")
  expect_identical(
    conditionMessage(err),
    "`api_key` must be a non-empty string (set AISSTREAM_API_KEY or pass api_key)."
  )
})

test_that("build_subscription rejects an unknown message type with aisstream_validation_error (golden)", {
  err <- tryCatch(
    build_subscription(
      api_key = "k",
      bounding_boxes = list(list(c(-10, -10), c(10, 10))),
      message_types = "NotAType"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "aisstream_validation_error")
  expect_s3_class(err, "aisstream_error")
  expect_identical(conditionMessage(err), "Unknown message type(s): NotAType. See AIS_MESSAGE_TYPES.")
})
