# File: R/helpers_subscription.R
# Pure, connection-free helpers that turn the client's stored parameters into the
# AISStream.io subscription frame. Unit-testable in isolation and — like the public
# methods — typed and asserted via roxyassert. Building the frame here (not inside
# the R6 method) keeps the validation rules in one place and lets tests exercise
# them without ever touching a socket.

#' Normalise a single bounding box to AISStream's nested-corner form
#'
#' Accepts a box in either supported shape and returns AISStream's canonical
#' `list(c(min_lat, min_lon), c(max_lat, max_lon))` (two `[lat, lon]` corners):
#' - a **named list** `list(min_lat=, min_lon=, max_lat=, max_lon=)` (the JS-object
#'   style), or
#' - a **raw nested box** `list(c(lat1, lon1), c(lat2, lon2))` (corner order is
#'   irrelevant; the corners are sorted into a min/max pair).
#' Every latitude is validated to `[-90, 90]` and every longitude to `[-180, 180]`.
#'
#' @param box (list) one bounding box, in either supported shape.
#' @return (list) the box as `list(c(min_lat, min_lon), c(max_lat, max_lon))`.
#' @export
normalise_bounding_box <- function(box) {
  assert_args_normalise_bounding_box(box)
  nms <- names(box)
  if (!is.null(nms) && all(c("min_lat", "min_lon", "max_lat", "max_lon") %in% nms)) {
    lats <- c(box[["min_lat"]], box[["max_lat"]])
    lons <- c(box[["min_lon"]], box[["max_lon"]])
  } else {
    if (length(box) != 2L) {
      rlang::abort("Each bounding box must have exactly two corners (or be a named min/max list).")
    }
    corner1 <- as.numeric(box[[1L]])
    corner2 <- as.numeric(box[[2L]])
    if (length(corner1) != 2L || length(corner2) != 2L) {
      rlang::abort("Each bounding-box corner must be a length-2 c(lat, lon).")
    }
    lats <- c(corner1[[1L]], corner2[[1L]])
    lons <- c(corner1[[2L]], corner2[[2L]])
  }
  lats <- as.numeric(lats)
  lons <- as.numeric(lons)
  if (anyNA(lats) || anyNA(lons)) {
    rlang::abort("Bounding-box coordinates must be numeric and non-missing.")
  }
  if (any(lats < -90) || any(lats > 90)) {
    rlang::abort("Bounding-box latitudes must lie in [-90, 90].")
  }
  if (any(lons < -180) || any(lons > 180)) {
    rlang::abort("Bounding-box longitudes must lie in [-180, 180].")
  }
  out <- list(
    c(min(lats), min(lons)),
    c(max(lats), max(lons))
  )
  return(assert_return_normalise_bounding_box(out))
}

#' Normalise a list of bounding boxes
#'
#' Applies [normalise_bounding_box()] to each box in a non-empty list; boxes may
#' overlap (AISStream de-duplicates server-side).
#'
#' @param bounding_boxes (list) a non-empty list of boxes, each in a shape
#'   [normalise_bounding_box()] accepts.
#' @return (list) the list of canonical nested-corner boxes.
#' @export
normalise_bounding_boxes <- function(bounding_boxes) {
  assert_args_normalise_bounding_boxes(bounding_boxes)
  if (length(bounding_boxes) == 0L) {
    rlang::abort("`bounding_boxes` must contain at least one box.")
  }
  return(assert_return_normalise_bounding_boxes(lapply(bounding_boxes, normalise_bounding_box)))
}

#' Build the AISStream.io subscription frame (as a JSON string)
#'
#' Assembles the one subscription message AISStream expects within 3 seconds of
#' connecting: `APIKey` and `BoundingBoxes` are always present; `FilterMessageTypes`
#' and `FiltersShipMMSI` are included **only when non-empty** (the server rejects an
#' empty `[]`). Bounding boxes are normalised and range-checked, the MMSI filter is
#' capped at 50, and message types must be a unique subset of [AIS_MESSAGE_TYPES].
#' `auto_unbox = TRUE` keeps the API key and scalar fields as JSON scalars, while
#' the box/filter arrays stay arrays.
#'
#' @param api_key (scalar<character>) the AISStream.io API key (non-empty).
#' @param bounding_boxes (list) a non-empty list of boxes (see
#'   [normalise_bounding_boxes()]).
#' @param message_types (vector<character, 0..> | NULL) optional `FilterMessageTypes`;
#'   unique values, each one of [AIS_MESSAGE_TYPES]. `NULL`/empty omits the field.
#' @param ship_mmsi (vector<character, 0..> | NULL) optional `FiltersShipMMSI`; at most
#'   50 MMSI strings. `NULL`/empty omits the field.
#' @return (scalar<character>) the subscription frame as a JSON string.
#' @importFrom jsonlite toJSON
#' @export
build_subscription <- function(api_key, bounding_boxes, message_types = NULL, ship_mmsi = NULL) {
  assert_args_build_subscription(api_key, bounding_boxes, message_types, ship_mmsi)
  if (!nzchar(api_key)) {
    rlang::abort("`api_key` must be a non-empty string (set AISSTREAM_API_KEY or pass api_key).")
  }
  payload <- list(
    APIKey = api_key,
    BoundingBoxes = normalise_bounding_boxes(bounding_boxes)
  )
  if (!is.null(message_types) && length(message_types) > 0L) {
    types <- as.character(message_types)
    if (anyDuplicated(types) > 0L) {
      rlang::abort("`message_types` must be unique (a duplicate is an AISStream server error).")
    }
    unknown <- setdiff(types, unlist(AIS_MESSAGE_TYPES, use.names = FALSE))
    if (length(unknown) > 0L) {
      rlang::abort(sprintf(
        "Unknown message type(s): %s. See AIS_MESSAGE_TYPES.",
        paste(unknown, collapse = ", ")
      ))
    }
    # I() forces a JSON array even for one element (auto_unbox would otherwise
    # collapse a length-1 vector to a scalar; the server wants an array here).
    payload$FilterMessageTypes <- I(types)
  }
  if (!is.null(ship_mmsi) && length(ship_mmsi) > 0L) {
    mmsi <- as.character(ship_mmsi)
    if (length(mmsi) > 50L) {
      rlang::abort("`ship_mmsi` may contain at most 50 MMSI strings (AISStream limit).")
    }
    payload$FiltersShipMMSI <- I(mmsi)
  }
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  return(assert_return_build_subscription(as.character(json)))
}
