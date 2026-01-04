---
trigger: always_on
---

# Technology Stack

## Core
- **Language**: Lua 5.1 / JIT (Standard for LÖVE)
- **Engine**: [LÖVE (Love2d)](https://love2d.org/) 11.4+

## Libraries
Libraries should be placed in the `libs/` directory.

- **ECS**: [Concord](https://github.com/Tjakka5/Concord)
    - *Purpose*: Entity Component System framework.
- **Input**: [Baton](https://github.com/tesselode/baton)
    - *Purpose*: Input mapping and handling.
- **Tweens**: [Flux](https://github.com/rxi/flux)
    - *Purpose*: Tweening library.
- **Collision**: [HardonCollider](https://github.com/vrld/HC)
    - *Purpose*: Spatial hashing and collision detection.
- **Camera**: [STALKER-X](https://github.com/adnzzzzZ/STALKER-X)
    - *Purpose*: Camera with shake, follow, etc.
- **GUI**: [Luis](https://github.com/SiENcE/luis)
    - *Purpose*: User Interface.
- **State Management**: [hump.gamestate](https://github.com/vrld/hump)
    - *Purpose*: Finite state machine for game screens (Menu, Play, Pause).
- **Asset/Data Management**: [Cargo](https://github.com/bjornbytes/cargo)
    - *Purpose*: Asset loader (images, sounds, etc.) as a Lua table.

## Directory Structure
- `libs/`: External libraries.
- `assets/`: Game assets (managed by Cargo).
- `components/`: ECS Components.
- `systems/`: ECS Systems.