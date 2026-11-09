# Native Plugin Protocol Specification

Communication protocol between native host application and plugin runtimes.

## Protocol Highlights
- JSON-RPC over local IPC / Unix domain sockets or loopback HTTP.
- Strict timeout budgets (3s for interactive UI callbacks, 60s for deferred background tasks).
- Capabilities handshake advertising client version, supported components, and display density.
