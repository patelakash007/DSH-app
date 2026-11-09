# Media Plugin Packaging & Distribution

Standard procedures for building, testing, and distributing the media generation extension package.

## Verification Checklist
1. Unit tests: `node --test test/*.test.js`
2. Archive packaging: `npm pack --dry-run`
3. Manifest consistency: Verify `cordis.patch.yml` and `package.json` version alignment.
