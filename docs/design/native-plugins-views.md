# Native Plugin Declarative View Specification

Component specification for JSON-defined views rendered by the Flutter client.

## Component Hierarchy
- Containers: `stack`, `row`, `card`, `callout`.
- Display: `text`, `metric`, `badge`, `progress`, `table`, `chart`, `image`.
- Interactive: `actions`, `button`, `options`, `confirm`, `input`.
- Limits: Maximum 120 components, 8 levels of nesting, 32 KiB payload size per panel.
