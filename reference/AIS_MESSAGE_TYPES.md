# AIS Message Types

The 25 AIS message-type names AISStream.io can deliver. Use these to
build the optional `FilterMessageTypes` subscription field — values must
be a **unique** subset of this set (a duplicate is a server error). They
are also the keys you find both in an incoming frame's `MessageType`
field and as the single key under its `Message` object. Reference them
as e.g. `AIS_MESSAGE_TYPES[["PositionReport"]]`.

## Usage

``` r
AIS_MESSAGE_TYPES
```
