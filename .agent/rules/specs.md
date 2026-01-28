# Project Specifications

## Overview
An evolving vertical slice composed of various action, adventure, RPG, and dungeon crawler-like features and mechanics.
Development proceeds via iterating increasingly complex vertical slices by gradually adding new features.

## Technical Specifications

### Metrics
- **Tile Size**: 16x16 pixels
- **Sprite Size**: 16x16 pixels
- **Grid**: 16x16 layout

### Gameplay Mechanics
- **Movement**: Top-down inertial movement with friction and speed clamping
- **Collision**: Bump and slide using HardonCollider (HC)
- **Camera**: Player-following gamera camera with TOPDOWN style
- **Entities**:
  - Player: Controlled by input, camera follows
  - Actors: Identical to player, controlled by AI (future)
  - Blocks: 16x16 static colliders

### World
- **Map**: Infinite checkerboard rendered relative to camera
- **Visuals**: Dark/light grey 16x16 tile pattern

### Rendering
- **Placeholders**:
  - Entities: 16x16 solid color circles
  - Player: Green, Enemy: Red, Blocks: Grey
- **Camera**: STALKER-X camera with attach/detach for world-space rendering

### Architecture
- **ECS Framework**: Concord
- **Pattern**: Shell/Orchestrator/Pure Function layers
- **Components**: Individual files in `components/`
- **Systems**: Named `<domain>.lua`, ordered: Input → Movement → Collision → Camera → Rendering
