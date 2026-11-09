# Hosted Share Links & Worker API

Cloudflare Worker backend architecture serving encrypted conversation links.

## Design
- Zero-knowledge storage: The server stores only ciphertext blobs and metadata tags.
- TTL expiration policies (7 days, 30 days, or permanent).
- Rate-limited upload and deletion endpoints.
