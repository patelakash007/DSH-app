# Mascot Market Publication & Storage Protocol

Specification for mascot asset pack catalog indexing and Cloudflare Worker endpoints.

## Endpoints
- `GET /market/pets/index.json`: Public catalog index.
- `GET /market/pets/:id.zip`: Download signed asset bundle.
- Integrity verification: SHA-256 validation enforced prior to client extraction.
