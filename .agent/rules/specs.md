---
trigger: always_on
---

# Project Specifications

## Overview
An initially simple and small-scope, but modular, and highly scalable top-down action RPG.
Development will proceed via iterating increasingly complex vertical slices by gradually adding new features.

## Technical Specifications

### Metrics
- **Tile Size**: 16x16 pixels
- **Sprite Size**: 16x16 pixels
- **Grid**: 16x16 layout

### Gameplay Mechanics
- **Movement**: Top-down inertial movement.
- **Collision**: Bump and slide.
- **Entities**:
  - Player: Controlled by Input.
  - Actors: Identical to player, controlled by AI.
  - Blocks: 16x16 entities for collision testing.

### World
- **Map**: Basic infinite map.
- **Visuals**: Checkerboard of grey and black 16x16 tiles.

### Rendering
- **Placeholders**:
  - Entities: 16x16 solid color fill circles.
  - Debug Coloring: Use a debug color component to color entities based on their type.
