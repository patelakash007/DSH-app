# Plugin Marketplace Architecture

Ecosystem design for discovering, rating, and installing verified plugins.

## Verification Gates
1. Manifest structure and schema validation.
2. License verification (OSI-approved open source).
3. Risk analysis (detects undeclared network or shell access).
4. Signed catalog distribution via static Pages and Cloudflare Workers.
