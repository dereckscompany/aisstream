# aisstream: Live Vessel-Tracking Stream Client for AISStream.io

A thin R client for the AISStream.io live vessel-tracking WebSocket
feed, built on connectcore. Open one socket, subscribe with bounding
boxes plus optional MMSI / message-type filters, and handle raw frames
Node-ws style. Reconnect, re-subscribe, keepalive and a watchdog are
inherited; the message hot path is parse-free so the vendor never drops
a slow reader, and parse helpers plus a durable NDJSON recorder are
included.

## See also

Useful links:

- <https://dereckscompany.github.io/aisstream>

- <https://github.com/dereckscompany/aisstream>

- Report bugs at <https://github.com/dereckscompany/aisstream/issues>

## Author

**Maintainer**: Dereck Mezquita <dereck@mezquita.io>
([ORCID](https://orcid.org/0000-0002-9307-6762))

Authors:

- Dereck Mezquita <dereck@mezquita.io>
  ([ORCID](https://orcid.org/0000-0002-9307-6762))
