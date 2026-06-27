# File: R/constants.R
# Exported constants for aisstream.

#' @title AIS Message Types
#' @description The 25 AIS message-type names AISStream.io can deliver. Use these
#' to build the optional `FilterMessageTypes` subscription field — values must be
#' a **unique** subset of this set (a duplicate is a server error). They are also
#' the keys you find both in an incoming frame's `MessageType` field and as the
#' single key under its `Message` object. Reference them as e.g.
#' `AIS_MESSAGE_TYPES[["PositionReport"]]`.
#' @export
AIS_MESSAGE_TYPES <- list(
  PositionReport = "PositionReport",
  UnknownMessage = "UnknownMessage",
  AddressedSafetyMessage = "AddressedSafetyMessage",
  AddressedBinaryMessage = "AddressedBinaryMessage",
  AidsToNavigationReport = "AidsToNavigationReport",
  AssignedModeCommand = "AssignedModeCommand",
  BaseStationReport = "BaseStationReport",
  BinaryAcknowledge = "BinaryAcknowledge",
  BinaryBroadcastMessage = "BinaryBroadcastMessage",
  ChannelManagement = "ChannelManagement",
  CoordinatedUTCInquiry = "CoordinatedUTCInquiry",
  DataLinkManagementMessage = "DataLinkManagementMessage",
  DataLinkManagementMessageData = "DataLinkManagementMessageData",
  ExtendedClassBPositionReport = "ExtendedClassBPositionReport",
  GroupAssignmentCommand = "GroupAssignmentCommand",
  GnssBroadcastBinaryMessage = "GnssBroadcastBinaryMessage",
  Interrogation = "Interrogation",
  LongRangeAisBroadcastMessage = "LongRangeAisBroadcastMessage",
  MultiSlotBinaryMessage = "MultiSlotBinaryMessage",
  SafetyBroadcastMessage = "SafetyBroadcastMessage",
  ShipStaticData = "ShipStaticData",
  SingleSlotBinaryMessage = "SingleSlotBinaryMessage",
  StandardClassBPositionReport = "StandardClassBPositionReport",
  StandardSearchAndRescueAircraftReport = "StandardSearchAndRescueAircraftReport",
  StaticDataReport = "StaticDataReport"
)

# The AISStream.io stream endpoint. WebSocket-only; there is no REST API.
AISSTREAM_URL <- "wss://stream.aisstream.io/v0/stream"

# AISStream.io caps the MMSI filter at this many entries.
AIS_MAX_MMSI <- 50L
