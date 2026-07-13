# File: R/conditions.R
# aisstream's typed input-validation condition. aisstream is a thin subscriber
# over `connectcore::StreamClient`, so its TRANSPORT failures (connect, reconnect,
# keepalive, a `$send()` on a closed socket) are raised by connectcore as
# `connectcore_stream_error` / `connectcore_error` and inherited for free, and a
# server error FRAME is emitted Node-ws style as a `WS_EVENTS$ERROR` event, not
# raised. The only aborts aisstream owns are NON-transport input validation --
# a malformed bounding box, an out-of-range coordinate, an empty api key, an
# unknown message type -- which this raiser types.
#
# Backward compatibility is a hard contract: the message string is byte-identical
# to the bare `rlang::abort()` this replaced. The classes are purely additive.

#' Raise a typed aisstream input-validation error
#'
#' Signals a condition classed `c("aisstream_validation_error", "aisstream_error")`
#' (on top of rlang's error classes) for a NON-transport failure: a subscription
#' argument or credential is malformed or violates a rule before any frame is
#' sent (a bounding box that is not two corners, a latitude outside [-90, 90], an
#' empty api key, an unknown message type, more than 50 MMSI filters).
#' `aisstream_error` is the connector's DOMAIN root, parallel to the transport
#' `connectcore_error` root it inherits from [connectcore::StreamClient]: a
#' validation failure is not a transport failure, so the two roots never meet --
#' exactly the `core_error` / `connectcore_error` split the fleet already uses.
#' The `message` is passed through verbatim, so the string stays byte-identical to
#' the bare `rlang::abort()` this replaced. See
#' [connectcore::connectcore_conditions] for the inherited transport taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<aisstream_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_aisstream_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("aisstream_validation_error", "aisstream_error"),
    ...,
    call = call
  ))
}
