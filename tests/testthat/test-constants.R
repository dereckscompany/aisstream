# Exported constants.

test_that("AIS_MESSAGE_TYPES holds the 25 known type names", {
  expect_type(AIS_MESSAGE_TYPES, "list")
  expect_length(AIS_MESSAGE_TYPES, 25L)
  # name == value for every entry (so AIS_MESSAGE_TYPES$PositionReport works)
  expect_identical(names(AIS_MESSAGE_TYPES), unlist(AIS_MESSAGE_TYPES, use.names = FALSE))
  expect_identical(AIS_MESSAGE_TYPES[["PositionReport"]], "PositionReport")
  expect_identical(AIS_MESSAGE_TYPES[["ShipStaticData"]], "ShipStaticData")
  expect_true("StandardSearchAndRescueAircraftReport" %in% unlist(AIS_MESSAGE_TYPES))
})

test_that("AIS_MESSAGE_TYPES has no duplicates", {
  vals <- unlist(AIS_MESSAGE_TYPES, use.names = FALSE)
  expect_identical(anyDuplicated(vals), 0L)
})
