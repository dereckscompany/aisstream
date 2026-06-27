# Offline parse helpers: parse_ais, the Go time parser, and the flatteners.

# A representative PositionReport frame (the shape AISStream delivers).
position_frame <- paste0(
  '{"MessageType":"PositionReport",',
  '"MetaData":{"MMSI":368207620,"ShipName":"OCEAN TITAN  ",',
  '"latitude":40.12,"longitude":-74.21,',
  '"time_utc":"2022-12-29 18:22:32.318353 +0000 UTC"},',
  '"Message":{"PositionReport":{"Sog":12.3,"Cog":89.1,',
  '"TrueHeading":90,"NavigationalStatus":0,"RateOfTurn":-2}}}'
)

test_that("parse_ais is JSON.parse for AIS (nested list, predictable shape)", {
  p <- parse_ais(position_frame)
  expect_type(p, "list")
  expect_identical(p$MessageType, "PositionReport")
  expect_identical(p$MetaData$MMSI, 368207620L)
  expect_identical(p$Message$PositionReport$Sog, 12.3)
})

test_that("parse_ais parses an error frame like any other object", {
  p <- parse_ais('{"error": "Api Key Is Not Valid"}')
  expect_identical(p$error, "Api Key Is Not Valid")
})

test_that("parse_go_time parses the Go (non-ISO) timestamp to UTC POSIXct", {
  t <- parse_go_time("2022-12-29 18:22:32.318353 +0000 UTC")
  expect_s3_class(t, "POSIXct")
  expect_identical(attr(t, "tzone"), "UTC")
  expect_equal(
    as.numeric(t),
    as.numeric(as.POSIXct("2022-12-29 18:22:32", tz = "UTC")),
    tolerance = 1
  )
})

test_that("parse_go_time honours a non-zero offset", {
  # +0100 means the UTC instant is one hour earlier than the wall clock.
  t <- parse_go_time("2022-12-29 19:22:32.000000 +0100 CET")
  expect_equal(
    as.numeric(t),
    as.numeric(as.POSIXct("2022-12-29 18:22:32", tz = "UTC")),
    tolerance = 1
  )
})

test_that("parse_go_time returns NA (UTC POSIXct) for NULL/empty/garbage", {
  expect_true(is.na(parse_go_time(NULL)))
  expect_true(is.na(parse_go_time(character(0))))
  expect_true(is.na(parse_go_time("not a time")))
  expect_s3_class(parse_go_time(NULL), "POSIXct")
})

test_that("ais_metadata flattens the common fields to one tidy row", {
  dt <- ais_metadata(parse_ais(position_frame))
  expect_s3_class(dt, "data.table")
  expect_identical(nrow(dt), 1L)
  expect_identical(dt$message_type, "PositionReport")
  expect_identical(dt$mmsi, "368207620")
  expect_identical(dt$ship_name, "OCEAN TITAN") # trimmed
  expect_equal(dt$latitude, 40.12)
  expect_equal(dt$longitude, -74.21)
  expect_s3_class(dt$time_utc, "POSIXct")
})

test_that("ais_metadata copes with a missing MetaData block", {
  dt <- ais_metadata(parse_ais('{"MessageType":"UnknownMessage"}'))
  expect_identical(dt$message_type, "UnknownMessage")
  expect_true(is.na(dt$mmsi))
  expect_true(is.na(dt$latitude))
})

test_that("as_position_report adds the stable body fields", {
  dt <- as_position_report(parse_ais(position_frame))
  expect_s3_class(dt, "data.table")
  expect_identical(nrow(dt), 1L)
  expect_equal(dt$sog, 12.3)
  expect_equal(dt$cog, 89.1)
  expect_equal(dt$true_heading, 90)
  expect_equal(dt$nav_status, 0)
  expect_equal(dt$rate_of_turn, -2)
})

test_that("as_position_report yields NA body fields for a non-position frame", {
  dt <- as_position_report(parse_ais('{"MessageType":"ShipStaticData","MetaData":{"MMSI":1}}'))
  expect_identical(dt$message_type, "ShipStaticData")
  expect_true(is.na(dt$sog))
  expect_true(is.na(dt$cog))
})

test_that("flatteners row-bind cleanly across a mixed stream", {
  frames <- list(
    position_frame,
    '{"MessageType":"ShipStaticData","MetaData":{"MMSI":42,"time_utc":"2022-01-01 00:00:00 +0000 UTC"}}'
  )
  dt <- data.table::rbindlist(lapply(frames, function(f) as_position_report(parse_ais(f))), fill = TRUE)
  expect_identical(nrow(dt), 2L)
  expect_equal(dt$sog, c(12.3, NA_real_))
})
