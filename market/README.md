# DSH Plugin Marketplace Catalog

This directory maintains the catalog definitions, static security audit rules, and schema verification scripts for native DSH plugins.

Outputs:
- `index.json`: Format 1 plugin index compatible with DSH web specifications
- `dsh-go.json`: Native plugin sidecar schema index
- `audit.json`: Structured security scanner audit trail

## Submitting a Plugin

1. Publish an OSI-licensed bundle to npm with an exact semantic version tag (ranges or `latest` are not accepted).
2. Fork this repository and create a plugin definition under `plugins/`. For non-scoped packages use `<name>.json`; for scoped packages use `@scope__name.json`.
3. Submit a pull request. Automated CI scanners evaluate package signatures, tarball integrity, and security heuristics before merging.

### Example Definition

```json
{
  "name": "@example/dsh-weather",
  "version": "1.0.0",
  "title": {"en": "Weather Forecast"},
  "summary": {"en": "Real-time weather forecast and satellite imagery."},
  "category": "tools",
  "screenshots": [],
  "homepage": "https://github.com/example/dsh-weather"
}
```

## Local Validation

Requires Node.js 22+.

```bash
npm ci --ignore-scripts
npm test          # Offline unit tests
npm run check     # Validation check against npm registry
npm run build     # Re-generate distribution indices in dist/
```
