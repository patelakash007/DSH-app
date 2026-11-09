# Companion Model Adaptation & Calibration

Technical design for automatically fitting imported Live2D companion models to native viewport and interaction boundaries.

## Pipeline
1. **Model Ingestion**: The app loads `.moc3`, texture atlases, and motion definitions into an off-screen canvas.
2. **Feature Extraction**: Extracts all parameter IDs, part names, and expression definitions.
3. **Parameter Mapping**: Normalizes gaze, head angle, eye blinks, and mouth forms to standard float ranges [-1.0, 1.0].
4. **Validation**: Enforces strict bounds checking to prevent canvas clipping or floating-point anomalies.
