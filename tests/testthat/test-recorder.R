# The NDJSON recorder: hourly path naming + the message-driven sink (no socket, no
# later loop).

test_that("ndjson_hour_path names files by UTC hour", {
  at <- lubridate::ymd_hms("2024-03-15 09:42:11", tz = "UTC")
  expect_identical(
    ndjson_hour_path("data", at),
    file.path("data", "ais-2024-03-15T09.ndjson")
  )
})

test_that("ndjson_hour_path converts a non-UTC time to UTC before naming", {
  at <- lubridate::with_tz(lubridate::ymd_hms("2024-03-15 09:42:11", tz = "UTC"), "America/New_York")
  expect_identical(ndjson_hour_path("d", at), file.path("d", "ais-2024-03-15T09.ndjson"))
})

test_that("ndjson_sink returns a message handler and creates the directory", {
  dir <- file.path(withr::local_tempdir(), "ais-data")
  expect_false(dir.exists(dir))
  sink <- ndjson_sink(dir)
  expect_true(is.function(sink))
  expect_true(dir.exists(dir))
})

test_that("ndjson_sink opens the current hour's file and appends raw frames verbatim", {
  dir <- withr::local_tempdir()
  sink <- ndjson_sink(dir)

  # Feed a few raw frames straight to the handler (no socket).
  sink('{"MessageType":"PositionReport","MetaData":{"MMSI":1}}')
  sink('{"MessageType":"ShipStaticData","MetaData":{"MMSI":2}}')

  # The file for the current hour exists and frames are buffered on the open
  # connection; flush every open connection so the writes are readable.
  path <- ndjson_hour_path(dir)
  expect_true(file.exists(path))
  for (n in rownames(showConnections(all = FALSE))) {
    try(flush(getConnection(as.integer(n))), silent = TRUE)
  }

  lines <- readLines(path)
  expect_length(lines, 2L)
  expect_identical(lines[[1]], '{"MessageType":"PositionReport","MetaData":{"MMSI":1}}')
  expect_identical(lines[[2]], '{"MessageType":"ShipStaticData","MetaData":{"MMSI":2}}')

  # parse_ais round-trips a recorded line offline.
  expect_identical(parse_ais(lines[[1]])$MessageType, "PositionReport")
})

test_that("ndjson_sink flushes after flush_seconds so lines survive an abrupt kill", {
  dir <- withr::local_tempdir()
  # flush_seconds at the floor: every frame triggers a flush, so the line is on
  # disk without us touching the connection.
  sink <- ndjson_sink(dir, flush_seconds = 1e-9)
  sink('{"MessageType":"PositionReport","MetaData":{"MMSI":42}}')

  lines <- readLines(ndjson_hour_path(dir))
  expect_length(lines, 1L)
  expect_match(lines[[1]], "PositionReport")
})

test_that("ndjson_sink registers cleanly via on(\"message\") and records frames", {
  dir <- withr::local_tempdir()
  ais <- AisStream$new(
    api_key = "K",
    bounding_boxes = list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1))
  )
  out <- ais$on("message", ndjson_sink(dir))
  expect_identical(out, ais) # $on chains the client

  # Drive the registered handler directly (no socket).
  ais$.__enclos_env__$private$.emit("message", '{"MessageType":"PositionReport","MetaData":{"MMSI":1}}')

  for (n in rownames(showConnections(all = FALSE))) {
    try(flush(getConnection(as.integer(n))), silent = TRUE)
  }
  lines <- readLines(ndjson_hour_path(dir))
  expect_length(lines, 1L)
  expect_match(lines[[1]], "PositionReport")
})

test_that("ndjson_hour_path rolls the file name at the turn of a UTC hour", {
  dir <- "feed"
  before <- lubridate::ymd_hms("2024-03-15 09:59:59", tz = "UTC")
  after <- lubridate::ymd_hms("2024-03-15 10:00:00", tz = "UTC")
  expect_identical(ndjson_hour_path(dir, before), file.path("feed", "ais-2024-03-15T09.ndjson"))
  expect_identical(ndjson_hour_path(dir, after), file.path("feed", "ais-2024-03-15T10.ndjson"))
  expect_false(identical(ndjson_hour_path(dir, before), ndjson_hour_path(dir, after)))
})
