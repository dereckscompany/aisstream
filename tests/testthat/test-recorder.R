# The NDJSON recorder: hourly path naming + the wiring (no socket, no later loop).

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

test_that("record_to_ndjson opens the file before any message and appends raw frames", {
  dir <- withr::local_tempdir()
  ais <- AisStream$new(
    api_key = "K",
    bounding_boxes = list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1))
  )
  out <- record_to_ndjson(ais, dir)
  expect_identical(out, ais) # returns the client for chaining $run()

  # The current hour's file exists already (opened before any frame arrives).
  path <- ndjson_hour_path(dir)
  expect_true(file.exists(path))

  # Drive the registered "message" handler directly (no socket).
  ais$.__enclos_env__$private$.emit("message", '{"MessageType":"PositionReport","MetaData":{"MMSI":1}}')
  ais$.__enclos_env__$private$.emit("message", '{"MessageType":"ShipStaticData","MetaData":{"MMSI":2}}')

  # The frames are buffered on an open file connection; flush every open file
  # connection so the writes are readable, then check the file content.
  open_cons <- showConnections(all = FALSE)
  for (n in rownames(open_cons)) {
    try(flush(getConnection(as.integer(n))), silent = TRUE)
  }
  lines <- readLines(path)
  expect_length(lines, 2L)
  expect_match(lines[[1]], "PositionReport")
  expect_match(lines[[2]], "ShipStaticData")

  # parse_ais round-trips a recorded line offline.
  expect_identical(parse_ais(lines[[1]])$MessageType, "PositionReport")
})

test_that("record_to_ndjson refuses to wire an already-open client", {
  # R6 public methods are locked, so use a subclass whose is_open() reports open.
  OpenAisStream <- R6::R6Class(
    "OpenAisStream",
    inherit = AisStream,
    public = list(is_open = function() TRUE)
  )
  ais <- OpenAisStream$new(
    api_key = "K",
    bounding_boxes = list(list(min_lat = 0, min_lon = 0, max_lat = 1, max_lon = 1))
  )
  expect_error(record_to_ndjson(ais, withr::local_tempdir()), "before connecting")
})
