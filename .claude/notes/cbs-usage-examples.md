# CBS Library - Usage Examples

## Basic Usage

### 1. Simple Seek Behavior

```lua
local CBS = require("libs.cbs")

-- Create context (one per agent, or reuse)
local ctx = CBS.new_context(16)  -- 16 direction slots

-- Per frame:
CBS.reset_context(ctx)

-- Add seek toward target
local target_pos = {x = 100, y = 200}
local agent_pos = {x = 50, y = 50}
local to_target = CBS.vec2.sub(target_pos, agent_pos)

CBS.add_seek(ctx, to_target, 1.0)

-- Solve for direction
local result = CBS.solve(ctx)
-- result.direction = {x, y} normalized
-- result.magnitude = strength [0, 1]

-- Apply to agent velocity
agent.velocity = CBS.vec2.scale(result.direction, max_speed * result.magnitude)
```

---

## 2. Seek with Obstacle Avoidance

```lua
local CBS = require("libs.cbs")

local ctx = CBS.new_context(16)

-- Per frame:
CBS.reset_context(ctx)

-- Seek behavior
local to_target = CBS.vec2.sub(target_pos, agent_pos)
CBS.add_seek(ctx, to_target, 1.0)

-- Add danger from raycasts (done in system shell with bump.lua)
local ray_results = {
  {direction = {x = 1, y = 0}, hit_distance = 25},   -- Obstacle ahead
  {direction = {x = 0.7, y = 0.7}, hit_distance = 50},  -- Obstacle at 45°
}

CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)
-- look_ahead = 100, dilation = 0.5

-- Solve (automatically avoids danger)
local result = CBS.solve(ctx)
```

---

## 3. Strafe Behavior (Circle Strafe Enemy)

```lua
local CBS = require("libs.cbs")

local ctx = CBS.new_context(16)

-- Per frame:
CBS.reset_context(ctx)

local to_enemy = CBS.vec2.sub(enemy_pos, agent_pos)
local distance = CBS.vec2.length(to_enemy)

-- Strafe around enemy at optimal range
CBS.add_strafe(ctx, to_enemy, distance, {
  min_range = 50,   -- Too close: flee
  max_range = 150,  -- Too far: seek
  seek_weight = 1.0,
  flee_weight = 1.5
})

-- Add danger from raycasts to avoid walls
CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)

local result = CBS.solve(ctx)
```

---

## 4. Wander Behavior

```lua
local CBS = require("libs.cbs")

local ctx = CBS.new_context(16)
local wander_cursor = 0  -- Store this in agent state

-- Per frame:
CBS.reset_context(ctx)

local forward = {x = 1, y = 0}  -- Agent's facing direction

-- Add wander with noise
wander_cursor = CBS.add_wander(ctx, forward, wander_cursor, {
  noise_scale = 0.1,        -- How fast noise changes
  angle_range = math.pi / 4, -- ±45° max deviation
  weight = 1.0
})

-- Add danger avoidance
CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)

local result = CBS.solve(ctx)

-- Advance cursor for next frame
wander_cursor = CBS.advance_cursor(wander_cursor, dt, 1.0)
```

---

## 5. Wander with Tether (Patrol Zone)

```lua
local CBS = require("libs.cbs")

local ctx = CBS.new_context(16)
local wander_cursor = 0
local spawn_pos = {x = 100, y = 100}

-- Per frame:
CBS.reset_context(ctx)

-- Wander behavior
wander_cursor = CBS.add_wander(ctx, forward, wander_cursor, {
  noise_scale = 0.1,
  angle_range = math.pi / 3,
  weight = 1.0
})

-- Tether to spawn point
CBS.add_tether(ctx, agent_pos, spawn_pos, 200, 1.5)
-- Pulls back strongly if distance > 200

-- Avoid obstacles
CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)

local result = CBS.solve(ctx)
wander_cursor = CBS.advance_cursor(wander_cursor, dt, 1.0)
```

---

## 6. Complex AI: Seek + Strafe + Flee

```lua
local CBS = require("libs.cbs")

local ctx = CBS.new_context(32)  -- Higher resolution for smoother steering

-- Per frame:
CBS.reset_context(ctx)

-- Multiple targets/threats
local to_player = CBS.vec2.sub(player_pos, agent_pos)
local to_powerup = CBS.vec2.sub(powerup_pos, agent_pos)
local to_danger = CBS.vec2.sub(explosion_pos, agent_pos)

local player_dist = CBS.vec2.length(to_player)

-- Strafe around player
CBS.add_strafe(ctx, to_player, player_dist, {
  min_range = 50,
  max_range = 150
})

-- Seek powerup (lower weight)
CBS.add_seek(ctx, to_powerup, 0.5)

-- Flee from danger (high weight)
CBS.add_flee(ctx, to_danger, 2.0)

-- Danger from environment
CBS.add_danger_from_rays(ctx, ray_results, 100, 0.5)

local result = CBS.solve(ctx)
```

---

## 7. Integration with DC01 Architecture

### In System Shell:

```lua
--[[============================================================================
  SYSTEM: AI Movement

  DATA CONTRACT:
    READS:  Transform, Velocity, AIControlled, SteeringContext
    WRITES: Velocity
    EMITS:  none
    CONFIG: none
============================================================================]]--

local CBS = require("libs.cbs")

function ai_movement.update(world, dt)
  -- Query entities with AI
  for entity in world:query(Transform, Velocity, AIControlled, SteeringContext) do
    local transform = entity[Transform]
    local velocity = entity[Velocity]
    local steering = entity[SteeringContext]

    -- Extract data
    local pos = {x = transform.x, y = transform.y}
    local forward = CBS.vec2.normalize({x = velocity.dx, y = velocity.dy})

    -- Compute steering (orchestrator)
    local result = compute_ai_steering(pos, forward, steering.cursor, dt, world)

    -- Write back
    entity[Velocity] = {
      dx = result.velocity.x,
      dy = result.velocity.y
    }
    entity[SteeringContext] = {
      cursor = result.new_cursor
    }
  end
end

-- Orchestrator
function compute_ai_steering(pos, forward, cursor, dt, world)
  local ctx = CBS.new_context(16)
  CBS.reset_context(ctx)

  -- Add behaviors based on AI state
  cursor = CBS.add_wander(ctx, forward, cursor, {
    noise_scale = 0.1,
    angle_range = math.pi / 4
  })

  -- Danger from raycasts (done in shell)
  local rays = perform_raycasts(pos, world.bump_world)
  CBS.add_danger_from_rays(ctx, rays, 100, 0.5)

  local result = CBS.solve(ctx)

  return {
    velocity = CBS.vec2.scale(result.direction, 100),
    new_cursor = CBS.advance_cursor(cursor, dt, 1.0)
  }
end
```

---

## Tips and Best Practices

### Resolution Choice
- **8 slots**: Fast, rough steering (simple enemies)
- **16 slots**: Good balance (most cases)
- **32 slots**: Smooth, precise (player character, important NPCs)

### Weights
- Use weights to prioritize behaviors
- Higher weight = more influence
- Example: Danger avoidance = 2.0, Wander = 1.0

### Dilation
- Use 0.3-0.5 for moderate danger spread
- Higher values make avoidance smoother but less precise
- Use 0 for sharp, responsive avoidance

### Performance
- Reuse context objects when possible
- Use lower resolution for distant/unimportant agents
- Use `solve_simple()` instead of `solve()` if interpolation not needed

### Debugging
```lua
local masked = CBS.debug_get_masked_map(ctx)
for i, slot in ipairs(masked) do
  -- Visualize slot.value at slot.slot direction
  draw_debug_ray(pos, slot.slot, slot.value)
end
```

---

## Common Patterns

### Patrol Behavior
```lua
-- Wander + Tether
CBS.add_wander(ctx, forward, cursor, params)
CBS.add_tether(ctx, pos, patrol_center, patrol_radius, 1.5)
```

### Chase and Attack
```lua
local dist = CBS.vec2.length(to_target)
if dist > attack_range then
  CBS.add_seek(ctx, to_target, 1.0)
else
  CBS.add_strafe(ctx, to_target, dist, {min_range = 30, max_range = 100})
end
```

### Flee to Safety
```lua
CBS.add_flee(ctx, to_threat, 2.0)
CBS.add_seek(ctx, to_safe_zone, 1.0)
```

### Follow Path
```lua
-- Seek next waypoint
CBS.add_seek(ctx, to_waypoint, 1.0)

-- Avoid obstacles
CBS.add_danger_from_rays(ctx, rays, look_ahead, 0.5)
```
