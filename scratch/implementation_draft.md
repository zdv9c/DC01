# CBS Architecture Refactor Plan

## Overview

Reorganize CBS implementation to support multiple discrete behaviors (Pathfind, Wander, Flee, Strafe) with blended state transitions. Behavior definitions are shared configs, entities hold only state references, and transitions use declarative condition tables.

## Goals

- **Separation of concerns**: Behavior definitions (shared) vs entity state (per-entity)
- **Smooth transitions**: Lerp between behaviors for organic movement
- **Declarative conditions**: Pure data tables, no functions in components
- **Searchable naming**: All CBS files prefixed with `cbs_`

---

## File Structure

```
src/config/
  cbs_behavior_defs.lua       -- Shared behavior configurations
  cbs_conditions.lua          -- Condition evaluator

src/components/
  cbs_behavior_state.lua      -- Per-entity behavior state (replaces SteeringState)
  cbs_behavior_transitions.lua -- Transition rules
  cbs_behavior_config.lua     -- Per-entity overrides (replaces SteeringConfig)
  cbs_modifiers.lua           -- Optional post-behavior modifiers

src/systems/
  cbs_transitions.lua         -- Checks conditions, triggers transitions
  cbs_movement.lua            -- Shell (replaces ai_movement.lua)

src/systems/behaviors/
  cbs_navigation.lua          -- Orchestrator (replaces ground_movement.lua)

src/libs/cbs/                 -- Unchanged, pure CBS library
```

---

## 1. Behavior Definitions

**File**: `src/config/cbs_behavior_defs.lua`

Shared, immutable behavior configurations. One copy in memory, referenced by all entities.

```lua
return {
  pathfind = {
    speed = 50,
    turn_smoothing = 5.0,
    velocity_smoothing = 2.0,
    danger_range = 3,              -- tiles
    danger_falloff = "linear",
    waypoint_reached = 0.5,        -- tiles
    path_lock_boost = 3.0,
    deadlock_threshold = 0.25,
    deadlock_bias = 0.25,
  },

  wander = {
    speed = 30,
    turn_smoothing = 3.0,
    velocity_smoothing = 2.0,
    danger_range = 2,
    wander_weight = 0.5,
    wander_rate = 0.5,
    wander_angle_range = math.pi / 4,
    leash_pull_strength = 2.0,
  },

  flee = {
    speed = 80,
    turn_smoothing = 8.0,          -- tighter turns when fleeing
    velocity_smoothing = 3.0,
    danger_range = 5,              -- more aware when fleeing
    flee_distance = 200,           -- pixels to flee before stopping
  },

  strafe = {
    speed = 60,
    turn_smoothing = 4.0,
    orbit_radius = 48,             -- pixels
    min_range = 32,                -- pixels
    max_range = 80,                -- pixels
    direction = 1,                 -- 1 = clockwise, -1 = counter
  },

  idle = {
    speed = 0,
    -- No movement, but CBS still runs for obstacle awareness
  },
}
```

---

## 2. Condition Evaluator

**File**: `src/config/cbs_conditions.lua`

Evaluates declarative condition tables. Conditions are pure data, evaluator interprets them.

```lua
local conditions = {}

--[[----------------------------------------------------------------------------
  CONDITION FORMAT

  String shortcut:
    "hp_low"

  Parameterized table:
    {check = "health_percent", op = "<", value = 0.3}

  Compound conditions:
    {all = {{check = "has_target"}, {check = "distance_to_target", op = "<", value = 80}}}
    {any = {{check = "hp_low"}, {check = "no_ammo"}}}
    {none = {{check = "in_safe_zone"}}}
----------------------------------------------------------------------------]]--

-- String shortcuts expand to full tables
local shortcuts = {
  hp_low = {check = "health_percent", op = "<", value = 0.3},
  hp_high = {check = "health_percent", op = ">", value = 0.5},
  hp_critical = {check = "health_percent", op = "<", value = 0.15},
  has_target = {check = "has_target"},
  no_target = {check = "has_target", op = "==", value = false},
  target_reached = {check = "target_reached"},
  at_home = {check = "distance_to_home", op = "<", value = 16},
  far_from_home = {check = "distance_to_home", op = ">", value = 240},
}

-- Comparison operators
local ops = {
  ["<"] = function(a, b) return a < b end,
  [">"] = function(a, b) return a > b end,
  ["<="] = function(a, b) return a <= b end,
  [">="] = function(a, b) return a >= b end,
  ["=="] = function(a, b) return a == b end,
  ["~="] = function(a, b) return a ~= b end,
}

-- Check implementations
local checks = {
  health_percent = function(entity)
    local health = entity.Health
    if not health or health.max == 0 then return nil end
    return health.current / health.max
  end,

  has_target = function(entity)
    local state = entity.CBSBehaviorState
    return state and state.has_target
  end,

  distance_to_target = function(entity)
    local state = entity.CBSBehaviorState
    local pos = entity.Transform
    if not state or not state.has_target or not pos then return nil end
    local dx = state.target_x - pos.x
    local dy = state.target_y - pos.y
    return math.sqrt(dx * dx + dy * dy)
  end,

  distance_to_home = function(entity)
    local state = entity.CBSBehaviorState
    local pos = entity.Transform
    if not state or not pos then return nil end
    local dx = state.spawn_x - pos.x
    local dy = state.spawn_y - pos.y
    return math.sqrt(dx * dx + dy * dy)
  end,

  target_reached = function(entity)
    local path = entity.Path
    return path and path.is_finished
  end,

  path_blocked = function(entity)
    local path = entity.Path
    return path and not path.is_valid
  end,
}

-- Expand string shortcut to table
local function expand_condition(condition)
  if type(condition) == "string" then
    return shortcuts[condition]
  end
  return condition
end

-- Evaluate a single check
local function evaluate_check(entity, condition)
  local cond = expand_condition(condition)
  if not cond then return false end

  -- Compound: all
  if cond.all then
    for _, sub in ipairs(cond.all) do
      if not evaluate_check(entity, sub) then return false end
    end
    return true
  end

  -- Compound: any
  if cond.any then
    for _, sub in ipairs(cond.any) do
      if evaluate_check(entity, sub) then return true end
    end
    return false
  end

  -- Compound: none
  if cond.none then
    for _, sub in ipairs(cond.none) do
      if evaluate_check(entity, sub) then return false end
    end
    return true
  end

  -- Simple check
  local check_fn = checks[cond.check]
  if not check_fn then return false end

  local actual = check_fn(entity)
  if actual == nil then return false end

  -- Boolean check (no operator)
  if cond.op == nil and cond.value == nil then
    return actual == true
  end

  -- Comparison check
  local op_fn = ops[cond.op or "=="]
  local expected = cond.value
  if expected == nil then expected = true end

  return op_fn(actual, expected)
end

-- Public API
function conditions.evaluate(entity, condition)
  return evaluate_check(entity, condition)
end

function conditions.register_shortcut(name, condition_table)
  shortcuts[name] = condition_table
end

function conditions.register_check(name, check_fn)
  checks[name] = check_fn
end

return conditions
```

---

## 3. Components

### CBSBehaviorState

**File**: `src/components/cbs_behavior_state.lua`

Per-entity state. Replaces SteeringState.

```lua
Concord.component("CBSBehaviorState", function(c, spawn_x, spawn_y, initial_behavior, seed)
  -- Current Behavior
  c.current = initial_behavior or "wander"
  c.previous = nil

  -- Blend State (for smooth transitions)
  c.blend_from = nil            -- Behavior we're blending from
  c.blend_progress = 1.0        -- 0 = fully old, 1 = fully new
  c.last_transition_time = 0    -- For cooldown tracking

  -- Per-Entity CBS State (persists across behaviors)
  c.cursor = 0.0                -- Wander noise cursor
  c.seed = seed or 0            -- Unique noise seed
  c.forward_x = 1.0             -- Current facing direction
  c.forward_y = 0.0
  c.current_speed = 0           -- Smoothed speed
  c.deadlock_side = 0           -- Persistent bias direction
  c.noise_time = 0              -- Speed noise accumulator

  -- Behavior-Specific State (cleared on transition)
  c.data = {}

  -- Home/Spawn (for wander leash, flee destination)
  c.spawn_x = spawn_x or 0
  c.spawn_y = spawn_y or 0
  c.leash_radius = 240

  -- Target (for pathfind, flee, strafe)
  c.has_target = false
  c.target_x = 0
  c.target_y = 0

  -- Debug
  c.last_ray_results = nil
end)
```

### CBSBehaviorTransitions

**File**: `src/components/cbs_behavior_transitions.lua`

Declarative transition rules.

```lua
Concord.component("CBSBehaviorTransitions", function(c, transitions)
  c.transitions = transitions or {}
  --[[
    Format:
    {
      {
        from = "wander",           -- or "any"
        to = "flee",
        condition = "hp_low",      -- string shortcut
        blend_duration = 0.3,      -- seconds (default: 0.2)
        cooldown = 0.5,            -- seconds before re-evaluation (default: 0.1)
        priority = 1,              -- higher = checked first (default: 0)
      },
      {
        from = "wander",
        to = "strafe",
        condition = {              -- parameterized table
          all = {
            {check = "has_target"},
            {check = "distance_to_target", op = "<", value = 100}
          }
        },
        blend_duration = 0.5,
      },
    }
  ]]--
end)
```

### CBSBehaviorConfig

**File**: `src/components/cbs_behavior_config.lua`

Per-entity overrides, organized by behavior.

```lua
Concord.component("CBSBehaviorConfig", function(c, overrides)
  c.overrides = overrides or {}
  --[[
    Format:
    {
      wander = {speed = 20, wander_weight = 0.8},
      flee = {speed = 100},
      pathfind = {path_lock_boost = 10},
    }
  ]]--
end)
```

### CBSModifiers

**File**: `src/components/cbs_modifiers.lua`

Optional post-behavior modifiers.

```lua
Concord.component("CBSModifiers", function(c, modifiers)
  c.modifiers = modifiers or {}
  --[[
    Format:
    {
      {type = "sway", weight = 0.1, rate = 0.5},
      {type = "obstacle_sensitivity", multiplier = 1.5},
    }
  ]]--
end)
```

---

## 4. Transition System

**File**: `src/systems/cbs_transitions.lua`

Runs BEFORE cbs_movement. Checks conditions, triggers blended transitions.

```lua
local Concord = require("libs.concord")
local Conditions = require("config.cbs_conditions")

local cbs_transitions = Concord.system({
  pool = {"CBSBehaviorState", "CBSBehaviorTransitions"}
})

local DEFAULT_BLEND_DURATION = 0.2
local DEFAULT_COOLDOWN = 0.1

function cbs_transitions:update(dt)
  local current_time = love.timer.getTime()

  for _, entity in ipairs(self.pool) do
    local state = entity.CBSBehaviorState
    local transitions = entity.CBSBehaviorTransitions

    -- Advance blend progress if blending
    if state.blend_progress < 1.0 then
      local blend_duration = state.blend_duration or DEFAULT_BLEND_DURATION
      state.blend_progress = math.min(1.0, state.blend_progress + dt / blend_duration)

      -- Clear blend_from when complete
      if state.blend_progress >= 1.0 then
        state.blend_from = nil
      end
    end

    -- Check cooldown
    local time_since_transition = current_time - state.last_transition_time
    local cooldown = self:get_min_cooldown(transitions)
    if time_since_transition < cooldown then
      goto continue
    end

    -- Check transitions (sorted by priority)
    local new_behavior, transition_def = self:check_transitions(entity, state, transitions)
    if new_behavior and new_behavior ~= state.current then
      self:transition_behavior(entity, state, new_behavior, transition_def, current_time)
    end

    ::continue::
  end
end

function cbs_transitions:get_min_cooldown(transitions)
  local min_cooldown = DEFAULT_COOLDOWN
  for _, t in ipairs(transitions.transitions) do
    if t.cooldown and t.cooldown < min_cooldown then
      min_cooldown = t.cooldown
    end
  end
  return min_cooldown
end

function cbs_transitions:check_transitions(entity, state, transitions)
  -- Sort by priority (higher first)
  local sorted = {}
  for _, t in ipairs(transitions.transitions) do
    table.insert(sorted, t)
  end
  table.sort(sorted, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)

  -- Find first matching transition
  for _, t in ipairs(sorted) do
    if t.from == state.current or t.from == "any" then
      if Conditions.evaluate(entity, t.condition) then
        return t.to, t
      end
    end
  end

  return nil, nil
end

function cbs_transitions:transition_behavior(entity, state, new_behavior, transition_def, current_time)
  -- Set up blend
  state.blend_from = state.current
  state.blend_progress = 0.0
  state.blend_duration = transition_def.blend_duration or DEFAULT_BLEND_DURATION

  -- Update state
  state.previous = state.current
  state.current = new_behavior
  state.last_transition_time = current_time

  -- Clear behavior-specific data
  state.data = {}
end

return cbs_transitions
```

---

## 5. Navigation Orchestrator

**File**: `src/systems/behaviors/cbs_navigation.lua`

Pure orchestrator with behavior-specific handlers. Handles blending.

```lua
local CBS = require("libs.cbs")
local BehaviorDefs = require("config.cbs_behavior_defs")

local CBS_Navigation = {}

--[[----------------------------------------------------------------------------
  MAIN ENTRY POINT
----------------------------------------------------------------------------]]--

function CBS_Navigation.navigate(args)
  local state = args.behavior_state
  local config = args.behavior_config
  local modifiers = args.modifiers

  -- Get behavior definitions
  local current_def = get_merged_params(state.current, config)

  -- Check if blending
  if state.blend_from and state.blend_progress < 1.0 then
    local from_def = get_merged_params(state.blend_from, config)
    return navigate_blended(args, from_def, current_def, state.blend_progress)
  end

  -- Single behavior
  return navigate_single(args, current_def, state.current)
end

--[[----------------------------------------------------------------------------
  BLENDED NAVIGATION
----------------------------------------------------------------------------]]--

local function navigate_blended(args, from_def, to_def, progress)
  local state = args.behavior_state

  -- Run both handlers
  local from_result = run_behavior_handler(args, from_def, state.blend_from)
  local to_result = run_behavior_handler(args, to_def, state.current)

  -- Lerp velocity
  local vx = lerp(from_result.vx, to_result.vx, progress)
  local vy = lerp(from_result.vy, to_result.vy, progress)

  -- Lerp compatible state (use "to" for non-lerpable)
  local forward_x = lerp(from_result.forward_x, to_result.forward_x, progress)
  local forward_y = lerp(from_result.forward_y, to_result.forward_y, progress)

  -- Normalize forward after lerp
  local len = math.sqrt(forward_x * forward_x + forward_y * forward_y)
  if len > 0 then
    forward_x = forward_x / len
    forward_y = forward_y / len
  end

  return {
    vx = vx,
    vy = vy,
    cursor = to_result.cursor,
    forward_x = forward_x,
    forward_y = forward_y,
    deadlock_side = to_result.deadlock_side,
    ray_results = to_result.ray_results,
    debug_context = to_result.debug_context,
  }
end

--[[----------------------------------------------------------------------------
  SINGLE BEHAVIOR NAVIGATION
----------------------------------------------------------------------------]]--

local function navigate_single(args, params, behavior_name)
  return run_behavior_handler(args, params, behavior_name)
end

local function run_behavior_handler(args, params, behavior_name)
  local handler = behavior_handlers[behavior_name]
  if handler then
    return handler(args, params)
  end
  return idle_result(args)
end

--[[----------------------------------------------------------------------------
  BEHAVIOR HANDLERS
----------------------------------------------------------------------------]]--

local behavior_handlers = {}

behavior_handlers.pathfind = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local path = args.path
  local obstacles = args.obstacles
  local dt = args.dt

  -- Create CBS context
  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Get current waypoint
  local target = get_current_waypoint(path)
  if target then
    local to_target = {x = target.x - pos.x, y = target.y - pos.y}
    local dist = math.sqrt(to_target.x * to_target.x + to_target.y * to_target.y)

    if dist > 0 then
      to_target.x = to_target.x / dist
      to_target.y = to_target.y / dist

      -- Add seek interest
      CBS.add_seek(ctx, to_target, 1.0)

      -- Path locking (if clear line of sight)
      CBS.try_path_locking(ctx, pos, to_target, dist, obstacles, {
        min_range = params.waypoint_reached * 16,
        boost = params.path_lock_boost,
      })
    end
  end

  -- Raycast obstacles
  local ray_results = CBS.cast_slot_rays(ctx, pos, obstacles, {
    range = params.danger_range * 16,
    falloff = params.danger_falloff,
    radius = args.entity_radius,
  })

  -- Deadlock resolution
  local forward = {x = state.forward_x, y = state.forward_y}
  local target_dir = target and {x = target.x - pos.x, y = target.y - pos.y} or forward
  state.deadlock_side = CBS.resolve_deadlocks(
    ctx, forward, target_dir,
    params.deadlock_threshold, params.deadlock_bias,
    state.deadlock_side
  )

  -- Solve and apply
  return finalize_movement(ctx, state, params, dt, ray_results)
end

behavior_handlers.wander = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local dt = args.dt

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Wander behavior
  local forward = {x = state.forward_x, y = state.forward_y}
  local new_cursor, wander_dir = CBS.add_wander(ctx, forward, state.cursor, {
    angle_range = params.wander_angle_range,
    weight = params.wander_weight,
    seed = state.seed,
    rate = params.wander_rate,
    dt = dt,
  })
  state.cursor = new_cursor

  -- Leash to home (tether)
  local to_home = {x = state.spawn_x - pos.x, y = state.spawn_y - pos.y}
  local home_dist = math.sqrt(to_home.x * to_home.x + to_home.y * to_home.y)
  if home_dist > state.leash_radius * 0.5 then
    local pull = (home_dist - state.leash_radius * 0.5) / (state.leash_radius * 0.5)
    pull = math.min(pull, 1.0) * params.leash_pull_strength
    CBS.add_seek(ctx, {x = to_home.x / home_dist, y = to_home.y / home_dist}, pull)
  end

  -- Raycast obstacles
  local ray_results = CBS.cast_slot_rays(ctx, pos, obstacles, {
    range = params.danger_range * 16,
    falloff = params.danger_falloff,
    radius = args.entity_radius,
  })

  return finalize_movement(ctx, state, params, dt, ray_results)
end

behavior_handlers.flee = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local dt = args.dt

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Flee from target
  if state.has_target then
    local away = {x = pos.x - state.target_x, y = pos.y - state.target_y}
    local dist = math.sqrt(away.x * away.x + away.y * away.y)
    if dist > 0 then
      away.x = away.x / dist
      away.y = away.y / dist
      CBS.add_seek(ctx, away, 1.0)
    end
  end

  -- Raycast obstacles (higher range when fleeing)
  local ray_results = CBS.cast_slot_rays(ctx, pos, obstacles, {
    range = params.danger_range * 16,
    falloff = params.danger_falloff,
    radius = args.entity_radius,
  })

  return finalize_movement(ctx, state, params, dt, ray_results)
end

behavior_handlers.strafe = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local dt = args.dt

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Strafe around target
  if state.has_target then
    local to_target = {x = state.target_x - pos.x, y = state.target_y - pos.y}
    local dist = math.sqrt(to_target.x * to_target.x + to_target.y * to_target.y)

    CBS.add_strafe(ctx, to_target, dist, {
      min_range = params.min_range,
      max_range = params.max_range,
      direction = params.direction,
    })
  end

  -- Raycast obstacles
  local ray_results = CBS.cast_slot_rays(ctx, pos, obstacles, {
    range = params.danger_range * 16,
    falloff = params.danger_falloff,
    radius = args.entity_radius,
  })

  return finalize_movement(ctx, state, params, dt, ray_results)
end

behavior_handlers.idle = function(args, params)
  return idle_result(args)
end

--[[----------------------------------------------------------------------------
  SHARED HELPERS
----------------------------------------------------------------------------]]--

local function finalize_movement(ctx, state, params, dt, ray_results)
  -- Solve CBS
  local result = CBS.solve(ctx)

  -- Smooth turning
  local forward = {x = state.forward_x, y = state.forward_y}
  local new_heading = CBS.steering.smooth_turn(
    forward, result.direction, dt, params.turn_smoothing
  )

  -- Calculate velocity
  local target_speed = params.speed * result.magnitude
  local smoothed_speed = lerp(state.current_speed, target_speed, dt * params.velocity_smoothing)
  state.current_speed = smoothed_speed

  return {
    vx = new_heading.x * smoothed_speed,
    vy = new_heading.y * smoothed_speed,
    cursor = state.cursor,
    forward_x = new_heading.x,
    forward_y = new_heading.y,
    deadlock_side = state.deadlock_side,
    ray_results = ray_results,
    debug_context = ctx,
  }
end

local function idle_result(args)
  local state = args.behavior_state
  return {
    vx = 0,
    vy = 0,
    cursor = state.cursor,
    forward_x = state.forward_x,
    forward_y = state.forward_y,
    deadlock_side = state.deadlock_side,
    ray_results = nil,
    debug_context = nil,
  }
end

local function get_merged_params(behavior_name, config)
  local base = BehaviorDefs[behavior_name] or BehaviorDefs.idle
  if not config or not config.overrides or not config.overrides[behavior_name] then
    return base
  end

  -- Shallow merge
  local merged = {}
  for k, v in pairs(base) do merged[k] = v end
  for k, v in pairs(config.overrides[behavior_name]) do merged[k] = v end
  return merged
end

local function get_current_waypoint(path)
  if not path or not path.waypoints or not path.current_index then
    return nil
  end
  return path.waypoints[path.current_index]
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

return CBS_Navigation
```

---

## 6. Movement Shell

**File**: `src/systems/cbs_movement.lua`

Replaces ai_movement.lua. World access only.

```lua
local Concord = require("libs.concord")
local CBS_Navigation = require("systems.behaviors.cbs_navigation")

local cbs_movement = Concord.system({
  pool = {"AIControlled", "Transform", "Velocity", "CBSBehaviorState", "Path", "Collider"},
  obstacles = {"Transform", "Collider"}
})

function cbs_movement:update(dt)
  -- Collect obstacle data (world access)
  local obstacle_data = {}
  for _, entity in ipairs(self.obstacles) do
    local pos = entity.Transform
    local col = entity.Collider
    if col.type == "static" then
      table.insert(obstacle_data, {
        x = pos.x,
        y = pos.y,
        radius = math.max(col.width, col.height) / 2
      })
    end
  end

  -- Process each AI entity
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    local state = entity.CBSBehaviorState
    local path = entity.Path
    local collider = entity.Collider
    local config = entity.CBSBehaviorConfig
    local modifiers = entity.CBSModifiers

    local entity_radius = math.max(collider.width, collider.height) / 2

    -- Call orchestrator
    local result = CBS_Navigation.navigate({
      pos = pos,
      vel = vel,
      behavior_state = state,
      behavior_config = config,
      modifiers = modifiers,
      path = path,
      obstacles = obstacle_data,
      entity_radius = entity_radius,
      dt = dt,
      self_entity = entity,
    })

    -- Write results back to world
    vel.x = result.vx
    vel.y = result.vy
    state.cursor = result.cursor
    state.forward_x = result.forward_x
    state.forward_y = result.forward_y
    state.deadlock_side = result.deadlock_side
    state.last_ray_results = result.ray_results
  end
end

return cbs_movement
```

---

## 7. Modifier System

**File**: `src/libs/cbs/cbs_modifiers.lua`

Applied after primary behavior, before solve.

```lua
local CBS_Modifiers = {}

local modifier_handlers = {}

modifier_handlers.sway = function(ctx, forward, params, state)
  local weight = params.weight or 0.1
  local rate = params.rate or 0.5

  -- Perpendicular sway using noise
  local perpendicular = {x = -forward.y, y = forward.x}
  local noise_val = love.math.noise(state.noise_time * rate, state.seed)
  local sway_amount = (noise_val - 0.5) * 2.0 * weight

  -- Add subtle perpendicular interest
  for i = 1, ctx.resolution do
    local slot_dir = ctx.slots[i]
    local dot = slot_dir.x * perpendicular.x + slot_dir.y * perpendicular.y
    ctx.interest[i] = ctx.interest[i] + dot * sway_amount
  end
end

modifier_handlers.obstacle_sensitivity = function(ctx, forward, params, state)
  local multiplier = params.multiplier or 1.0
  for i = 1, ctx.resolution do
    ctx.danger[i] = math.min(1.0, ctx.danger[i] * multiplier)
  end
end

modifier_handlers.speed_noise = function(ctx, forward, params, state)
  -- Handled in finalize_movement, stored in state
  local amount = params.amount or 0.1
  local rate = params.rate or 0.5
  local noise_val = love.math.noise(state.noise_time * rate, state.seed + 1000)
  state.speed_modifier = 1.0 + (noise_val - 0.5) * 2.0 * amount
end

function CBS_Modifiers.apply_all(ctx, forward, modifiers, state, dt)
  if not modifiers then return end

  state.noise_time = (state.noise_time or 0) + dt

  for _, mod in ipairs(modifiers) do
    local handler = modifier_handlers[mod.type]
    if handler then
      handler(ctx, forward, mod, state)
    end
  end
end

return CBS_Modifiers
```

---

## 8. Entity Assembler Example

**File**: `src/entities/goblin.lua`

```lua
local AI_CONFIG = require("config.ai_config")

return function(e, x, y)
  -- Core
  e:give("Transform", x, y)
  e:give("Velocity", 0, 0, 50, 0)
  e:give("Collider", 16, 16, "dynamic")
  e:give("Sprite", {0.2, 0.8, 0.2, 1}, 8)
  e:give("Health", 50, 50)

  -- AI
  e:give("AIControlled")
  e:give("CBSBehaviorState", x, y, "wander", math.random(10000))
  e:give("Path", x, y)

  -- Transitions
  e:give("CBSBehaviorTransitions", {
    {from = "wander", to = "flee", condition = "hp_low", blend_duration = 0.3, priority = 10},
    {from = "flee", to = "wander", condition = "hp_high", blend_duration = 0.5},
    {from = "wander", to = "pathfind", condition = "has_target", blend_duration = 0.2},
    {from = "pathfind", to = "wander", condition = "no_target", blend_duration = 0.3},
  })

  -- Per-entity overrides (optional)
  e:give("CBSBehaviorConfig", {
    wander = {speed = 25, wander_weight = 0.6},
    flee = {speed = 90},
  })

  -- Modifiers (optional)
  e:give("CBSModifiers", {
    {type = "sway", weight = 0.15, rate = 0.4},
  })

  return e
end
```

---

## 9. System Registration

**File**: `src/states/Play.lua` (update)

```lua
-- System order
local systems = {
  require("systems.input"),
  require("systems.pathfinding"),
  require("systems.cbs_transitions"),    -- NEW: before movement
  require("systems.cbs_movement"),       -- RENAMED: was ai_movement
  require("systems.movement"),
  require("systems.collision"),
  require("systems.camera"),
  require("systems.rendering"),
  -- ...
}
```

---

## Migration Checklist

1. [ ] Create `src/config/cbs_behavior_defs.lua`
2. [ ] Create `src/config/cbs_conditions.lua`
3. [ ] Create `src/components/cbs_behavior_state.lua`
4. [ ] Create `src/components/cbs_behavior_transitions.lua`
5. [ ] Create `src/components/cbs_behavior_config.lua`
6. [ ] Create `src/components/cbs_modifiers.lua`
7. [ ] Create `src/systems/cbs_transitions.lua`
8. [ ] Create `src/systems/behaviors/cbs_navigation.lua`
9. [ ] Rename `src/systems/ai_movement.lua` → `src/systems/cbs_movement.lua`
10. [ ] Update system to use new components and orchestrator
11. [ ] Create `src/libs/cbs/cbs_modifiers.lua`
12. [ ] Update entity assemblers to use new components
13. [ ] Update `states/Play.lua` system registration order
14. [ ] Test with existing NPCs
15. [ ] Delete old files: `SteeringState`, `SteeringConfig`, `ground_movement.lua`

---

## Benefits

- **Clarity**: Each behavior has its own config and handler
- **Smooth transitions**: Lerped blending between behaviors
- **Declarative conditions**: Pure data, no functions in components
- **Extensibility**: Add behaviors/conditions without touching core systems
- **Reusability**: Behavior configs shared, only state is per-entity
- **Performance**: Cooldowns prevent excessive condition checks
- **Debuggability**: Clear state machine, visible blend progress
- **Searchability**: All CBS files found with `cbs_` search
