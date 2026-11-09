# Companion Mascot Architecture

System architecture for interactive desktop companion pets (Deepy Whale and Whale Girl).

## Components
1. **Live2D Runtime**: Lightweight WebGL / Canvas execution engine rendering model animations at target refresh rates.
2. **State Machine**: Manages states (`idle`, `thinking`, `happy`, `sleeping`, `speaking`) mapped to chat and system lifecycle events.
3. **Asset Packaging**: Model assets are bundled into verified `.zip` asset packs with SHA-256 integrity checks.
4. **Touch Interactions**: Magnetic snapping to screen edges, swipe-to-dismiss, and long-press radial menu dispatch.
