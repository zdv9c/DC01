# Context-Based Steering (CBS) Library - Implementation Plan

## Overview
Build a self-contained, drop-in steering library with zero external dependencies that implements context-based steering with interest/danger maps.

---

## Library Structure

```
src/libs/cbs/
├── init.lua          # Main API - public interface
├── vec2.lua          # 2D vector utilities
├── simplex.lua       # OpenSimplex noise implementation
├── context.lua       # Context map data structure
├── behaviors.lua     # Interest generation (seek, strafe, wander)
├── danger.lua        # Danger map population
└── solver.lua        # Direction solver with sub-slot interpolation
```

---

## Module Breakdown

### 1. vec2.lua
**Purpose**: Minimal 2D vector math utilities

**Functions**:
- `new(x, y)` → `{x, y}`
- `length(v)` → number
- `normalize(v)` → vec2
- `dot(a, b)` → number
- `scale(v, s)` → vec2
- `add(a, b)` → vec2
- `rotate(v, angle)` → vec2

**Note**: Pure functions, tables as vectors

---

### 2. simplex.lua
**Purpose**: OpenSimplex noise for coherent wandering

**Implementation**: 2D simplex noise
**Functions**:
- `new(seed)` → noise generator
- `noise2D(gen, x, y)` → number in [-1, 1]

**References**: Standard simplex noise algorithm

---

### 3. context.lua
**Purpose**: Context map data structure and slot management

**Data Structure**:
```lua
{
  resolution = N,           -- Number of slots (8, 16, 32)
  slots = {},               -- Array of N unit vectors (directions)
  interest = {},            -- Array of N floats [0, 1]
  danger = {}               -- Array of N floats [0, 1]
}
```

**Functions**:
- `new(resolution)` → context
- `reset(ctx)` → sets interest/danger to 0.0
- `get_slot_angle(index, resolution)` → angle in radians

---

### 4. behaviors.lua
**Purpose**: Interest map shaping functions

**Functions**:

**`add_seek(ctx, target_direction, weight)`**
- Maps dot product to interest
- `I[i] = max(0, dot(slot[i], target)) * weight`

**`add_strafe(ctx, target_direction, distance, params)`**
- Favors perpendicular movement
- `I[i] = (1.0 - |dot(slot[i], target)|) * weight`
- Distance blending: seek→strafe→flee based on min/max range
- Params: `{min_range, max_range, seek_weight, flee_weight}`

**`add_wander(ctx, forward_direction, noise_cursor, params)`**
- Uses simplex noise for angular offset
- Rotates forward by noise-driven angle
- Applies seek to wandering direction
- Params: `{noise_scale, angle_range}`
- Returns: new_cursor value

---

### 5. danger.lua
**Purpose**: Danger map population from sensors

**Functions**:

**`add_danger_from_rays(ctx, ray_results, look_ahead, dilation)`**
- ray_results: `{{direction = {x,y}, hit_distance = number}, ...}`
- Maps each ray to nearest slot
- `D[i] = 1.0 - (hit_distance / look_ahead)`
- Dilation: spread danger to neighbor slots (Gaussian falloff)

**`apply_dilation(ctx, sigma)`**
- Spreads danger values to neighbors
- Uses Gaussian or linear falloff

---

### 6. solver.lua
**Purpose**: Final direction calculation with sub-slot interpolation

**Functions**:

**`solve(ctx)`**
- Masking: `I_final[i] = interest[i] * (1.0 - danger[i])`
- Find index with max I_final
- Sub-slot interpolation (parabolic):
  - `x = (L - R) / (2 * (L - 2*C + R))`
  - `angle_final = angle[c] + (x * 2*pi / N)`
- Returns: `{direction = {x, y}, magnitude = I_final[best]}`

---

### 7. init.lua (Main API)
**Purpose**: Clean public API, ties everything together

**Exports**:
```lua
CBS = {
  -- Context management
  new_context(resolution) → context,
  reset_context(ctx),

  -- Behaviors (interest generation)
  add_seek(ctx, target_dir, weight),
  add_strafe(ctx, target_dir, distance, params),
  add_wander(ctx, forward_dir, cursor, params) → new_cursor,

  -- Danger
  add_danger_from_rays(ctx, rays, look_ahead, dilation),

  -- Solver
  solve(ctx) → {direction = {x,y}, magnitude = number},

  -- Utilities
  advance_cursor(cursor, dt, speed) → new_cursor,
}
```

---

## Implementation Order

1. ✅ **vec2.lua** - Foundation for everything
2. ✅ **simplex.lua** - Needed for wander
3. ✅ **context.lua** - Core data structure
4. ✅ **behaviors.lua** - Interest generation functions
5. ✅ **danger.lua** - Danger mapping
6. ✅ **solver.lua** - Direction calculation
7. ✅ **init.lua** - Public API assembly
8. ✅ **Documentation** - Usage examples

---

## Testing Strategy

For each module, test core functionality:

**vec2**: dot product, normalization, rotation
**simplex**: coherent output, range [-1, 1]
**context**: slot generation, reset
**behaviors**: correct interest patterns
**solver**: sub-slot interpolation accuracy
**integration**: full pipeline with mock data

---

## Usage Example (Target API)

```lua
local CBS = require("libs.cbs")

-- Setup
local ctx = CBS.new_context(16)  -- 16 directions
local wander_cursor = 0

-- Per frame:
CBS.reset_context(ctx)

-- Add behaviors
CBS.add_seek(ctx, {x = 1, y = 0}, 1.0)  -- Move right
CBS.add_wander(ctx, forward, wander_cursor, {
  noise_scale = 0.1,
  angle_range = math.pi / 4
})

-- Add danger (from raycasts done in system shell)
CBS.add_danger_from_rays(ctx, ray_hits, 100, 0.5)

-- Solve
local result = CBS.solve(ctx)
-- result.direction = {x, y} normalized
-- result.magnitude = [0, 1] strength

-- Update state
wander_cursor = CBS.advance_cursor(wander_cursor, dt, 1.0)
```

---

## Design Principles

1. **Zero dependencies**: Self-contained, works anywhere
2. **Pure functions**: Same inputs → same outputs
3. **Simple data**: Plain Lua tables, no metatables
4. **Stateless**: Caller manages state (cursors, etc.)
5. **Explicit**: All parameters passed in, no hidden config
6. **Reusable**: Works in any Lua project, not DC01-specific

---

## Status
- [x] Planning complete
- [ ] Implementation in progress
- [ ] Testing
- [ ] Documentation
- [ ] Integration example with DC01 architecture
