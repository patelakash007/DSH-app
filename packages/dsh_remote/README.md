# dsh_remote

Pure-Dart client for remote host connections. Reaches remote engine APIs through Server Relay or directly over WebRTC DataChannel (LAN / P2P / TURN) with end-to-end encryption using `Noise_IK_25519_ChaChaPoly_SHA256`. Produces a standard `DshClient` instance so chat, streaming, approvals, models, and keys work identically to the local native engine.

## Features
- Direct LAN / P2P WebRTC data channels with automatic relay fallback.
- Noise protocol handshake for end-to-end cryptographic mutual authentication.
- Seamless connection re-establishment across Wi-Fi / cellular network transitions.
