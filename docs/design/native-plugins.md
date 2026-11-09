# Native Plugin Architecture Overview

Architectural overview of the native extensibility system in DSH.

## Core Tenets
1. Plugins execute in sandboxed engine runtimes; never in the UI main thread.
2. The UI renders declared JSON views using native Flutter components for optimal 120fps performance.
3. No foreign native code or dynamic dex loading required.
