# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the game
cd src && love .
# Or use the script
./run.sh

# Run tests
lua tests/run.lua
```

No build step required - Lua is interpreted. Requires LÖVE 11.4+.

## Architecture Overview

DC01 is a LÖVE2D game using Concord ECS with a strict **Shell → Orchestrator → Pure** layered architecture.

### Layer Responsibilities

1. **Shell** (top of system files): ONLY layer that reads/writes world state. Queries components, calls orchestrators, writes results back.

2. **Orchestrator**: Pure coordination functions. All dependencies passed as parameters. Returns data structures, never writes.

3. **Pure Functions**: Mathematical/logical operations with zero side effects.

### Critical Invariants

- Only shells access world state
- Systems never call other systems directly (use events/shared components)
- Components are pure data - no methods, no behavior
- All dependencies explicit in function signatures

### System Execution Order

Input → Pathfinding → AIMovement → Movement → Collision → Camera → Background → DevInspector → Rendering → DevTools → DebugGUI

Systems are added to the world in `states/Play.lua`.

### Key Files

- `src/main.lua` - LÖVE entry point, delegates to gamestate
- `src/states/Play.lua` - Main gameplay state, creates world and systems
- `src/components/init.lua` - Loads all components into world
- `src/config/ai_config.lua` - Centralized AI tuning parameters

### World Resources

```lua
world:getResource("camera")        -- gamera camera instance
world:getResource("debug_gizmos")  -- debug visualization toggles
world:getResource("simulation_paused")
world:getResource("time_scale")
```

## Creating Entities

Use assemblers in `src/entities/`:
```lua
local player = Concord.entity(world)
CreatePlayer(player, x, y)
```

Or directly:
```lua
local entity = Concord.entity(world)
entity:give("Transform", x, y)
entity:give("Velocity", 0, 0, speed, friction)
entity:give("Sprite", {r, g, b, a}, radius)
```

## Adding a New System

1. Create `src/systems/system_name.lua` with file header documenting DATA CONTRACT
2. Define pools for component queries
3. Implement shell in `update(dt)` method
4. Add orchestrator functions (`compute_*`)
5. Add pure functions at bottom
6. Register in `states/Play.lua` in correct order

## Key Libraries

| Library | Purpose | Access Pattern |
|---------|---------|----------------|
| Concord | ECS | `Concord.system()`, `Concord.entity()` |
| HardonCollider | Collision | Via world.hc_world, world.hc_shapes |
| Baton | Input | Via world.input |
| gamera | Camera | Via world.camera |
| Slab | Debug GUI | Updated in main.lua |
| cbs/ | AI Steering | Used by ai_movement system |
| Jumper | Pathfinding | Used by pathfinding system |

Library documentation in `.agent/docs/libraries/`.

## Code Style Quick Reference

- System files: `system_domain.lua`
- Orchestrators: `compute_what_it_returns(...)`
- Pure functions: `verb_noun(...)`
- 2-space indent, max 80 chars, max 20 lines per function
- Comments explain WHY, not WHAT
- Every system needs DATA CONTRACT header

Full style guide in `.agent/rules/style.md`.

## Rules Structure

This project uses shared rules between Antigravity IDE and Claude Code:
- **Source of truth**: `.agent/rules/` and `.agent/docs/`
- **Claude symlinks**: `.claude/rules/` and `.claude/docs/` point to `.agent/`
- Edit rules in `.agent/` - both IDEs will see changes
