# Media Catalog Contract Specification

Defines the contract for reading image and video generation catalogs and model profiles from plugins.

## Catalog Schema
The catalog is exposed via the plugin namespace schema:
- `services`: Map of configured service instances with provider credentials.
- `models`: List of available generative models with capability flags (`kind: image | video`, supported `ratios`, `sizes`, `maxN`).
- `presets`: Optional predefined templates for service onboarding.
