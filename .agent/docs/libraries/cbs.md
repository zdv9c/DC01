# Context-Based Steering (CBS) Library

A self-contained, drop-in Lua library for intelligent agent movement using context-based steering with interest/danger maps.

---

## Features

- **Zero Dependencies**: Completely self-contained, works in any Lua project
- **Pure Functions**: Stateless design, caller manages state
- **Sub-Slot Interpolation**: Smooth steering without direction snapping
- **Coherent Wandering**: OpenSimplex noise for natural meandering
- **Flexible Behaviors**: Seek, flee, strafe, wander, tether
- **Obstacle Avoidance**: Raycast-based danger mapping with dilation
- **Architecture-Friendly**: Designed for clean integration with ECS systems

---

## Quick Start

```lua
local CBS = require("libs.cbs")

-- Create context
local ctx = CBS.new_context(16)  -- 16 direction slots

-- Per frame:
CBS.reset_context(ctx)

-- Add behaviors
CBS.add_seek(ctx, {x = 1, y = 0}, 1.0)  -- Move right

-- Add danger (from raycasts)
CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)

-- Solve
local result = CBS.solve(ctx)
-- result.direction = {x, y} normalized
-- result.magnitude = [0, 1]
```

---

## How It Works

### Context Maps

Each agent has a **context** with N evenly-spaced direction slots (typically 8-32). Each slot has:

- **Interest**: How much the agent wants to move in that direction
- **Danger**: How blocked/dangerous that direction is

### Pipeline

1. **Reset**: Clear interest/danger maps
2. **Behaviors**: Add interest (seek, strafe, wander, etc.)
3. **Sensors**: Add danger (raycasts, proximity)
4. **Solver**: Mask interest by danger, find best direction with interpolation
5. **Output**: Direction vector and magnitude

### Key Formula

```
Final Interest[i] = Interest[i] × (1.0 - Danger[i])
```

Directions with high interest and low danger win.

---

## API Reference

### Context Management

#### `CBS.new_context(resolution)`
Creates a new steering context.
- **resolution**: Number of direction slots (8, 16, 32 recommended)
- **Returns**: context table

#### `CBS.reset_context(ctx)`
Resets interest/danger to zero. Call at start of each frame.

---

### Behaviors (Interest Generation)

#### `CBS.add_seek(ctx, target_direction, weight)`
Move toward target.
- **target_direction**: `{x, y}` vector
- **weight**: Strength multiplier (optional, default 1.0)

#### `CBS.add_flee(ctx, target_direction, weight)`
Move away from target.

#### `CBS.add_strafe(ctx, target_direction, distance, params)`
Move perpendicular to target, with distance-based blending.
- **distance**: Current distance to target
- **params**: `{min_range, max_range, seek_weight, flee_weight}`
  - Far (>max_range): Seeks
  - Close (<min_range): Flees
  - Mid-range: Strafes

#### `CBS.add_wander(ctx, forward_direction, noise_cursor, params)`
Coherent meandering using simplex noise.
- **forward_direction**: Agent's facing direction
- **noise_cursor**: Current noise position (state)
- **params**: `{noise_scale, angle_range, weight, seed}`
  - `seed`: Noise seed for deterministic patterns (default 0)
- **Returns**: Updated cursor (pass back next frame)

#### `CBS.add_tether(ctx, current_position, spawn_position, leash_radius, return_weight)`
Pull back to spawn when too far (patrol zones).

---

### Danger (Obstacle Avoidance)

#### `CBS.add_danger_from_rays(ctx, ray_results, look_ahead, dilation)`
Add danger from raycast hits.
- **ray_results**: Array of `{direction = {x,y}, hit_distance = number}`
- **look_ahead**: Max raycast distance
- **dilation**: Danger spread factor (0 = sharp, 0.5 = smooth)

**Ray Result Format** (computed in shell):
```lua
local ray_results = {}
for i = 1, resolution do
  local dir = ctx.slots[i]
  local hit_dist = perform_raycast(agent_pos, dir, look_ahead)
  if hit_dist then
    table.insert(ray_results, {direction = dir, hit_distance = hit_dist})
  end
end
```

#### `CBS.add_danger_from_proximity(ctx, agent_position, obstacles, danger_radius)`
Add danger from nearby obstacle positions.

#### `CBS.add_directional_danger(ctx, danger_direction, danger_value, spread)`
Mark specific direction as dangerous.

---

### Solver

#### `CBS.solve(ctx)`
Computes final steering direction with sub-slot interpolation.
- **Returns**: `{direction = {x, y}, magnitude = number}`

#### `CBS.solve_simple(ctx)`
Faster solver without interpolation (less smooth).

---

### Utilities

#### `CBS.advance_cursor(cursor, dt, speed)`
Resets noise cursor for wander behavior.

#### `CBS.vec2`
Exposed vector utilities: `new`, `normalize`, `dot`, `scale`, `add`, `sub`, `rotate`, etc.

#### `CBS.debug_get_masked_map(ctx)`
Returns array of `{slot = vec2, value = number}` for visualization.

---

## Architecture Integration

### Component Pattern

```lua
-- SteeringState component (stores wander cursor)
{
  cursor = 0.0,  -- Wander noise cursor
  seed = 0       -- Optional: unique seed per entity
}
```

**Note**: Context is NOT stored in components. Create fresh each frame.

### System Pattern (Shell/Orchestrator/Pure)

**Shell** (ai_movement.lua):
- Query entities with steering components
- Extract position, velocity, state
- **Perform raycasts** (only layer with world access)
- Call orchestrator with explicit data
- Write velocity results

**Orchestrator**:
- Create/reset CBS context
- Add behaviors based on AI state
- Add danger from raycast results
- Solve and return direction

**Pure**: CBS library itself (all functions pure)

### Shell Example

```lua
function ai_movement.update(world, dt, config)
  for entity in world:query(Position, Velocity, SteeringState, AIState) do
    local pos = world:get(entity, Position)
    local vel = world:get(entity, Velocity)
    local steering = world:get(entity, SteeringState)
    local ai = world:get(entity, AIState)
    
    -- Perform raycasts (shell responsibility)
    local ray_results = perform_raycasts(world, pos, config.look_ahead)
    
    -- Call orchestrator
    local result = compute_steering(pos, vel, steering, ai, ray_results, config, dt)
    
    -- Write velocity
    world:set(entity, Velocity, result.velocity)
    world:set(entity, SteeringState, result.steering)
  end
end

-- Orchestrator (pure)
function compute_steering(pos, vel, steering, ai, ray_results, config, dt)
  local ctx = CBS.new_context(16)
  CBS.reset_context(ctx)
  
  -- Add behaviors based on AI state
  if ai.target then
    CBS.add_seek(ctx, ai.target_direction, 1.0)
  else
    steering.cursor = CBS.add_wander(ctx, vel, steering.cursor, {seed = steering.seed})
  end
  
  -- Add danger
  CBS.add_danger_from_rays(ctx, ray_results, config.look_ahead, 0.5)
  
  -- Solve
  local result = CBS.solve(ctx)
  steering.cursor = CBS.advance_cursor(steering.cursor, dt, 1.0)
  
  return {
    velocity = CBS.vec2.scale(result.direction, config.move_speed * result.magnitude),
    steering = steering
  }
end
```

---

## Debug Visualization

```lua
-- In rendering system
function draw_steering_debug(ctx, agent_pos, scale)
  local masked = CBS.debug_get_masked_map(ctx)
  
  for i, data in ipairs(masked) do
    local length = data.value * scale
    local end_x = agent_pos.x + data.slot.x * length
    local end_y = agent_pos.y + data.slot.y * length
    
    -- Green = interest, Red overlay for danger
    love.graphics.setColor(0, data.value, 0)
    love.graphics.line(agent_pos.x, agent_pos.y, end_x, end_y)
  end
end
```

---

## Performance

### Resolution Guidelines
- **8 slots**: Fast, rough (simple enemies)
- **16 slots**: Balanced (recommended default)
- **32 slots**: Smooth, expensive (player, important NPCs)

### Optimization Tips
- Reuse context objects (reset instead of recreate)
- Use `solve_simple()` if smoothness not critical
- Reduce resolution for distant agents
- Limit dilation radius

---

## Examples

### Simple Seek with Avoidance
```lua
CBS.reset_context(ctx)
CBS.add_seek(ctx, to_target, 1.0)
CBS.add_danger_from_rays(ctx, rays, 100, 0.5)
local result = CBS.solve(ctx)
```

### Circle Strafe Enemy
```lua
CBS.reset_context(ctx)
CBS.add_strafe(ctx, to_enemy, distance, {
  min_range = 50,
  max_range = 150
})
CBS.add_danger_from_rays(ctx, rays, 100, 0.5)
local result = CBS.solve(ctx)
```

### Wandering Patrol
```lua
CBS.reset_context(ctx)
cursor = CBS.add_wander(ctx, forward, cursor, {
  noise_scale = 0.1,
  angle_range = math.pi / 4,
  seed = entity_id  -- Unique per entity
})
CBS.add_tether(ctx, pos, spawn, 200, 1.5)
CBS.add_danger_from_rays(ctx, rays, 100, 0.5)
local result = CBS.solve(ctx)
cursor = CBS.advance_cursor(cursor, dt, 1.0)
```

---

## Technical Details

### Sub-Slot Interpolation

Uses parabolic interpolation to find the true peak between discrete slots:

```
offset = (L - R) / (2 * (L - 2*C + R))
final_angle = slot_angle + (offset * angle_step)
```

This eliminates visible snapping when switching between slots.

### Noise Implementation

2D Simplex noise for coherent wander patterns:
- Seeded random permutation table
- Gradient-based noise generation
- Output range: [-1, 1]

### Danger Dilation

Gaussian-like falloff spreads danger to neighboring slots:
- Accounts for agent radius
- Creates smoother avoidance gradients
- Prevents getting stuck in local minima

---

## Library Structure

```
src/libs/cbs/
├── init.lua          # Main API
├── vec2.lua          # Vector utilities
├── simplex.lua       # OpenSimplex noise
├── context.lua       # Context structure
├── behaviors.lua     # Interest generation
├── danger.lua        # Danger mapping
└── solver.lua        # Direction solver
```

---

## Version

**1.0.1** - Fixed noise seed configuration, fast_floor bug

---

## References

- Context-Based Steering: Evolved from bucket-based steering behaviors
- Sub-slot interpolation eliminates direction quantization
- Simplex noise for natural movement patterns
- Architecture designed for ECS integration
