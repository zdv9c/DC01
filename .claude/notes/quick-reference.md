# Quick Reference Guide - DC01

## Architecture Quick Check

### Before Writing Any Code:
```
☐ Which layer am I in? (Shell/Orchestrator/Pure)
☐ Are all dependencies in function signature?
☐ Am I reading/writing world only in shell?
☐ Am I returning data, not modifying state?
☐ Is my DATA CONTRACT updated in file header?
```

### Component Rules
```
✓ Pure data structures (Lua tables)
✓ No methods, no behavior
✓ Fine-grained (Position separate from Velocity)
✓ No computed values (compute on demand)
✗ Never store library handles in components
```

### System Rules
```
✓ Shell queries → extracts → calls orchestrator → writes
✓ Orchestrator receives explicit params → returns data
✓ Pure functions have zero side effects
✗ Never call another system directly
✗ Never access world below shell layer
✗ Never pass world/context to orchestrators
```

---

## File Patterns

### System File Template
```lua
--[[============================================================================
  SYSTEM: [Name]

  PURPOSE: [One sentence]

  DATA CONTRACT:
    READS:  [Component, Component]
    WRITES: [Component, Component]
    EMITS:  [event_type, event_type]
    CONFIG: [config.field, config.field]

  UPDATE ORDER: [When this runs]
============================================================================]]--

-- DEPENDENCIES
local Thing = require("path.to.thing")
local CONSTANT = 42

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function system.update(world, dt)
  for entity in world:query(CompA, CompB) do
    local a = entity[CompA]
    local b = entity[CompB]

    local result = compute_something(a, b, dt)

    entity[CompA] = result.new_a
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Returns new state after computation
-- @param a: type - description
-- @param b: type - description
-- @return {new_a: type}
function compute_something(a, b, dt)
  local x = pure_calc(a.value, dt)
  return {new_a = {value = x}}
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Calculates X from Y
-- @param y: number
-- @return number
function pure_calc(y, dt)
  return y * dt
end

return system
```

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| System file | `system_domain.lua` | `system_movement.lua` |
| System table | `domain` | `movement` |
| Shell function | `system.update(world, dt)` | `movement.update(world, dt)` |
| Orchestrator | `compute_<result>` | `compute_physics_step` |
| Pure function | `<verb>_<noun>` | `calculate_acceleration` |
| Local var (short) | abbreviation | `pos`, `vel`, `dt` |
| Local var (long) | full_name | `player_position` |
| Constant | `SCREAMING_CASE` | `MAX_SPEED`, `GRAVITY` |

---

## System Execution Order

1. system_input.lua - Read input → write InputState
2. system_movement.lua - Apply velocity → update position
3. system_collision.lua - Detect/resolve collisions
4. system_camera.lua - Update camera follow
5. system_rendering.lua - Draw everything

---

## Library State Storage

All library state lives in world object:

```lua
world.bump_world = bump.newWorld()
world.camera = gamera.new(...)
world.input = baton.new(...)
world.config = { gravity = 9.8, ... }
world.event_queue = {}
```

Systems extract what they need:
```lua
function collision.update(world, dt)
  local bump_world = world.bump_world
  -- Use bump_world...
end
```

---

## Common Anti-Patterns to Avoid

❌ **Shell with computation logic**
Fix: Extract to orchestrator

❌ **Orchestrator accessing world**
Fix: Pass data as parameter from shell

❌ **System calling another system**
Fix: Emit event, other system reacts

❌ **Component with methods**
Fix: Move behavior to system

❌ **God component with 10+ fields**
Fix: Split into focused components

❌ **Storing library handles in components**
Fix: Store in world, components have pure data

❌ **Global state access in pure function**
Fix: Pass as parameter

❌ **More than 7 parameters**
Fix: Group into value object or split function

---

## Current Components

| Component | Fields | Purpose |
|-----------|--------|---------|
| Transform | x, y | Position in world |
| Velocity | dx, dy | Movement vector |
| Sprite | (placeholder) | Visual representation |
| Collider | (in bump_world) | Collision detection |
| PlayerControlled | (marker) | Flag for input system |
| AiControlled | (marker) | Flag for AI system |
| CameraTarget | (marker) | Camera follows this |
| Debug | (marker) | Show debug info |

---

## Specs at a Glance

- Tile/Sprite: 16x16 pixels
- Grid: 16x16 layout
- Movement: Top-down inertial with friction
- Collision: Bump & slide (bump.lua)
- Camera: Player-following (gamera TOPDOWN)
- World: Infinite checkerboard

---

## Markdown Rule

**Remember**: Never write markdown to `.agent/`
Write to `scratch/` or `.claude/notes/` instead!

---

## Git Branch

**Current branch**: `claude/onboard-antigravity-rlUlt`
Always develop and push to this branch.

---

## When Stuck

1. Check `.claude/rules/architecture.md` for architecture patterns
2. Check `.claude/rules/style.md` for code style
3. Check `.claude/docs/libraries/[lib].md` for library usage
4. Ask: "Does this violate any invariants?"
5. Ask: "Are all dependencies explicit?"
6. Ask: "Will I understand this in 6 months?"
