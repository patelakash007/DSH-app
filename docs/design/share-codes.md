# Encrypted Conversation Sharing & Replay Specification

End-to-end encrypted protocol for sharing conversation transcripts.

## Crypto Protocol
- Symmetric AES-GCM-256 encryption performed entirely on-device.
- Decryption key encoded into URL hash fragment (`#key=...`), never transmitted to share servers.
- Self-contained HTML viewer and native app deep-link import support.
