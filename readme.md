# DC01

An experiment using agent-optimized architecture and rules to build and scale cleanly with minimal oversight without technical debt.

---

## About

**DC01** is an evolving vertical slice combining action, adventure, RPG, and dungeon crawler mechanics. Development proceeds by iterating increasingly complex vertical slices, gradually adding new features while maintaining clean architecture.

## Getting Started

### Prerequisites

- [LÖVE 11.4+](https://love2d.org/) (Love2D game framework)

### Running the Game

```bash
cd src
love .
```

Or use the provided script:

```bash
./run.sh
```

## Controls

| Key | Action |
|-----|--------|
| WASD / Arrow Keys | Move |
| Escape | Quit |

## Current Features

- **Top-down inertial movement** with friction and speed clamping
- **Bump & slide collision** walk into walls and slide along them
- **Player-following camera** using gamera
- **Infinite checkerboard world** rendered relative to camera

## Technology Stack

| Category | Technology |
|----------|------------|
| Language | Lua 5.1 / LuaJIT |
| Engine | LÖVE 11.4+ |
| ECS | [Concord](https://github.com/Tjakka5/Concord) |
| Input | [Baton](https://github.com/tesselode/baton) |
| Collision | [HardonCollider](https://github.com/vrld/HC) |
| Camera | [STALKER-X](https://github.com/adnzzzzZ/STALKER-X) |
| State Management | [hump.gamestate](https://github.com/vrld/hump) |

## Project Structure

```
src/
├── main.lua              # Entry point
├── conf.lua              # LÖVE configuration
├── components/           # ECS component definitions
│   ├── init.lua          # Component loader
│   ├── transform.lua
│   ├── velocity.lua
│   ├── sprite.lua
│   ├── collider.lua
│   ├── player_controlled.lua
│   ├── ai_controlled.lua
│   └── camera_target.lua
├── systems/              # ECS systems (shell/orchestrator/pure layers)
│   ├── system_input.lua
│   ├── system_movement.lua
│   ├── system_collision.lua
│   ├── system_camera.lua
│   └── system_rendering.lua
├── states/               # Game states
│   └── Play.lua
├── libs/                 # External libraries
└── assets/               # Game assets
```

## Architecture

This project follows an **ECS Clean Architecture** pattern where:

- **System Shells** are the only layer that reads/writes world state
- **Orchestrators** compose pure functions and return results
- **Pure Functions** handle math and logic with no side effects
- Systems communicate via events, never by calling each other directly

See `.agent/rules/` for detailed architecture documentation.

## License

[Your license here]