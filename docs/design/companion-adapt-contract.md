# Companion Model Adapt Contract Specification

Defines the contract between the companion diagnostics engine and model adapter generators.

## Interface Contract
Payload format for `dsh-go/companion-adapt-request`:
- `v`: 1 (protocol version).
- `target`: `app-local-adapter-v1`.
- `diagnostics`: Motion curve, parameter lists, hit areas, and expression slots detected in the loaded Live2D model.
- `ruleAliases`: Standard parameter aliases mapping custom model parameters to standard tracking parameters (AngleX, AngleY, EyeOpen, MouthOpen).
- Output: Single JSON object adhering strictly to the `app-local-adapter-v1` schema.
