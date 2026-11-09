# Test NPM Tarball Fixtures

The `.tgz` files in this directory are pristine npm archives downloaded from the registry for test reproduction without executing code.

- `@liustack/modsearch@5.10.11`, MIT, 170839 bytes
- `@liustack/modlens@3.27.2`, MIT, 239567 bytes

To refresh fixtures, run `node scripts/capture-fixtures.mjs`. Standard unit tests (`npm test`) do not require network connectivity.
