---
trigger: always_on
---

# Technology Stack

## Core
- **Language**: Lua 5.1 / JIT
- **Engine**: LÖVE 11.4+

## Essential Libraries
- **ECS**: [Concord](https://github.com/Tjakka5/Concord)
- **Collision**: [HardonCollider](https://github.com/vrld/HC)
- **Input**: [Baton](https://github.com/tesselode/baton)
- **State Management**: [hump.gamestate](https://github.com/vrld/hump)
- **Asset Loading**: [Cargo](https://github.com/bjornbytes/cargo)
- **Tweening**: [flux](https://github.com/rxi/flux)
- **Timer**: [hump.timer](https://github.com/vrld/hump)

## Utilities
- **Utilities**: [lume](https://github.com/rxi/lume)
- **Logging**: [log.lua](https://github.com/rxi/log.lua)
- **Serialization**: [binser](https://github.com/bakpakin/binser)
- **Unit Testing**: [lust](https://github.com/bjornbytes/lust)

## Rendering
- **Camera**: [gamera](https://github.com/kikito/gamera)
- **GUI**: Custom (follows system pattern)

## Procedural Generation
- **Noise**: [love2d-noise](https://github.com/25A0/love2d-noise)
- **Pathfinding**: [jumper](https://github.com/Yonaba/Jumper)
- **RNG**: Lua built-in math.random with seed management
