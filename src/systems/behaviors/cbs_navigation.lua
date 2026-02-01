--[[============================================================================
  BEHAVIOR: CBS Navigation

  PURPOSE: Pure orchestrator for CBS-driven navigation.
  Dispatches to behavior-specific handlers and handles blending.

  DEPENDENCIES: CBS Lib, cbs_behavior_defs
============================================================================]]--

local CBS = require("libs.cbs")
local BehaviorDefs = require("config.cbs_behavior_defs")

local CBS_Navigation = {}

local TILE_SIZE = 16

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Defined first for forward references
----------------------------------------------------------------------------]]--

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function get_merged_params(behavior_name, config)
  local base = BehaviorDefs[behavior_name] or BehaviorDefs.idle or {}

  if not config or not config.overrides or not config.overrides[behavior_name] then
    return base
  end

  -- Shallow merge: base + overrides
  local merged = {}
  for k, v in pairs(base) do merged[k] = v end
  for k, v in pairs(config.overrides[behavior_name]) do merged[k] = v end
  return merged
end

local function get_path_target(pos, path, waypoint_reached, state)
  if not path or not path.is_valid or not path.waypoints or #path.waypoints == 0 then
    return nil, 0
  end

  local wp = path.waypoints[path.current_index]
  if not wp then return nil, 0 end

  local dx = wp.x - pos.x
  local dy = wp.y - pos.y
  local dist = math.sqrt(dx * dx + dy * dy)

  -- Advance waypoint if reached
  if dist < waypoint_reached then
    if path.current_index >= #path.waypoints then
      -- Path complete
      path.final_target = nil
      path.waypoints = {}
      path.is_valid = false
      path.current_index = 1
      state.has_target = false
      return nil, 0
    else
      path.current_index = path.current_index + 1
      wp = path.waypoints[path.current_index]
      if wp then
        dx = wp.x - pos.x
        dy = wp.y - pos.y
        dist = math.sqrt(dx * dx + dy * dy)
      end
    end
  end

  return wp, dist
end

local function idle_result(args)
  local state = args.behavior_state
  return {
    vx = 0,
    vy = 0,
    cursor = state.cursor,
    forward_x = state.forward_x,
    forward_y = state.forward_y,
    current_speed = 0,
    deadlock_side = state.deadlock_side,
    ray_results = nil,
    debug_context = nil,
  }
end

local function finalize_movement(ctx, state, params, dt, ray_results, has_movement, new_deadlock_side)
  -- Solve CBS
  local result = CBS.solve(ctx, {hard_mask_threshold = params.hard_mask_threshold})

  local new_vx, new_vy = 0, 0
  local forward_x = state.forward_x
  local forward_y = state.forward_y

  if has_movement and result.magnitude > 0.01 then
    -- Smooth turning
    local current_heading = {x = state.forward_x, y = state.forward_y}
    local new_heading = CBS.steering.smooth_turn(
      current_heading,
      result.direction,
      dt,
      params.turn_smoothing or 5.0
    )
    forward_x = new_heading.x
    forward_y = new_heading.y
  end

  -- Calculate velocity with smoothing
  local SPEED = params.speed or 50
  local VELOCITY_SMOOTHING = params.velocity_smoothing or 2.0
  local MIN_SPEED_BIAS = params.min_speed_bias or 0.5

  local blend = 1.0 - math.exp(-VELOCITY_SMOOTHING * dt)
  local target_speed = 0

  if has_movement then
    local clamped_magnitude = math.min(1.0, result.magnitude)
    local effective_magnitude = MIN_SPEED_BIAS + (1.0 - MIN_SPEED_BIAS) * clamped_magnitude
    target_speed = SPEED * effective_magnitude
  end

  -- Smooth speed
  local current_speed = state.current_speed or 0
  current_speed = current_speed + (target_speed - current_speed) * blend

  new_vx = forward_x * current_speed
  new_vy = forward_y * current_speed

  return {
    vx = new_vx,
    vy = new_vy,
    cursor = state.cursor,
    forward_x = forward_x,
    forward_y = forward_y,
    current_speed = current_speed,
    deadlock_side = new_deadlock_side or state.deadlock_side,
    ray_results = ray_results,
    debug_context = ctx,
  }
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
  local radius = args.entity_radius
  local dt = args.dt
  local self_entity = args.self_entity

  local DANGER_RANGE = (params.danger_range or 3) * TILE_SIZE
  local WAYPOINT_REACHED = (params.waypoint_reached or 0.5) * TILE_SIZE

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Get current waypoint
  local target, dist_to_target = get_path_target(pos, path, WAYPOINT_REACHED, state)

  local vec_to_target = nil
  local has_movement = false

  if target and dist_to_target > WAYPOINT_REACHED then
    local dx = target.x - pos.x
    local dy = target.y - pos.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 0 then
      vec_to_target = {x = dx / d, y = dy / d}
      CBS.add_seek(ctx, {x = dx, y = dy}, 1.0)
      has_movement = true
    end
  end

  -- Raycast obstacles
  local ignore_self = function(obs) return obs.entity ~= self_entity end
  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = DANGER_RANGE,
    falloff = params.danger_falloff or "linear",
    radius = radius,
    filter = ignore_self,
    spread_angle = params.spread_angle,
    min_danger_to_spread = params.min_danger_to_spread,
  })

  -- Path locking maneuver
  if has_movement and vec_to_target then
    local PATH_LOCK_RANGE = (params.path_lock_range or 3) * TILE_SIZE
    CBS.try_path_locking(ctx, pos, vec_to_target, dist_to_target, obstacles, {
      min_range = PATH_LOCK_RANGE,
      offset = params.path_lock_offset or 10,
      boost = params.path_lock_boost or 3.0,
      margin = params.path_lock_margin or 4,
      ignore_filter = ignore_self,
    })
  end

  -- Deadlock resolution
  local forward = {x = state.forward_x, y = state.forward_y}
  local target_dir = vec_to_target or forward
  local new_deadlock_side = CBS.resolve_deadlocks(
    ctx, forward, target_dir,
    params.deadlock_threshold or 0.25,
    params.deadlock_bias or 0.25,
    state.deadlock_side
  )

  return finalize_movement(ctx, state, params, dt, ray_results, has_movement, new_deadlock_side)
end

behavior_handlers.wander = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local radius = args.entity_radius
  local dt = args.dt
  local self_entity = args.self_entity

  local DANGER_RANGE = (params.danger_range or 2) * TILE_SIZE

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  -- Wander behavior
  local forward = {x = state.forward_x, y = state.forward_y}
  local new_cursor, wander_dir = CBS.add_wander(ctx, forward, state.cursor, {
    angle_range = params.wander_angle_range or math.pi / 4,
    weight = params.wander_weight or 0.5,
    noise_scale = 1.0,
    seed = state.seed or 0,
  })

  -- Leash to home (tether) - only apply when actively wandering, not when blending out
  local apply_leash = true
  if args.is_blending and args.blending_from == "wander" and args.blending_to ~= "wander" then
    apply_leash = false  -- Don't pull back to spawn when transitioning away from wander
  end

  if apply_leash then
    local to_home_x = state.spawn_x - pos.x
    local to_home_y = state.spawn_y - pos.y
    local home_dist = math.sqrt(to_home_x * to_home_x + to_home_y * to_home_y)
    local leash = state.leash_radius or 240

    if home_dist > leash * 0.5 then
      local pull = (home_dist - leash * 0.5) / (leash * 0.5)
      pull = math.min(pull, 1.0) * (params.leash_pull_strength or 2.0)
      if home_dist > 0 then
        CBS.add_seek(ctx, {x = to_home_x / home_dist, y = to_home_y / home_dist}, pull)
      end
    end
  end

  -- Raycast obstacles
  local ignore_self = function(obs) return obs.entity ~= self_entity end
  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = DANGER_RANGE,
    falloff = params.danger_falloff or "linear",
    radius = radius,
    filter = ignore_self,
    spread_angle = params.spread_angle,
    min_danger_to_spread = params.min_danger_to_spread,
  })

  -- Advance cursor for wander
  local wander_rate = params.wander_rate or 0.5
  state.cursor = CBS.advance_cursor(state.cursor, dt, wander_rate)

  return finalize_movement(ctx, state, params, dt, ray_results, true, 0)
end

behavior_handlers.flee = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local radius = args.entity_radius
  local dt = args.dt
  local self_entity = args.self_entity

  local DANGER_RANGE = (params.danger_range or 5) * TILE_SIZE

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  local has_movement = false

  -- Flee from target (move away)
  if state.has_target then
    local away_x = pos.x - state.target_x
    local away_y = pos.y - state.target_y
    local dist = math.sqrt(away_x * away_x + away_y * away_y)
    if dist > 0 then
      CBS.add_seek(ctx, {x = away_x / dist, y = away_y / dist}, 1.0)
      has_movement = true
    end
  end

  -- Raycast obstacles (higher awareness when fleeing)
  local ignore_self = function(obs) return obs.entity ~= self_entity end
  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = DANGER_RANGE,
    falloff = params.danger_falloff or "linear",
    radius = radius,
    filter = ignore_self,
    spread_angle = params.spread_angle,
    min_danger_to_spread = params.min_danger_to_spread,
  })

  return finalize_movement(ctx, state, params, dt, ray_results, has_movement, 0)
end

behavior_handlers.strafe = function(args, params)
  local pos = args.pos
  local state = args.behavior_state
  local obstacles = args.obstacles
  local radius = args.entity_radius
  local dt = args.dt
  local self_entity = args.self_entity

  local DANGER_RANGE = (params.danger_range or 3) * TILE_SIZE

  local ctx = CBS.new_context(params.resolution or 16)
  CBS.reset_context(ctx)

  local has_movement = false

  -- Strafe around target
  if state.has_target then
    local to_target_x = state.target_x - pos.x
    local to_target_y = state.target_y - pos.y
    local dist = math.sqrt(to_target_x * to_target_x + to_target_y * to_target_y)

    if dist > 0 then
      CBS.add_strafe(ctx, {x = to_target_x, y = to_target_y}, dist, {
        min_range = params.min_range or 32,
        max_range = params.max_range or 80,
        direction = params.strafe_direction or 1,
      })
      has_movement = true
    end
  end

  -- Raycast obstacles
  local ignore_self = function(obs) return obs.entity ~= self_entity end
  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = DANGER_RANGE,
    falloff = params.danger_falloff or "linear",
    radius = radius,
    filter = ignore_self,
    spread_angle = params.spread_angle,
    min_danger_to_spread = params.min_danger_to_spread,
  })

  return finalize_movement(ctx, state, params, dt, ray_results, has_movement, 0)
end

behavior_handlers.idle = function(args, params)
  return idle_result(args)
end

--[[----------------------------------------------------------------------------
  HANDLER DISPATCH
----------------------------------------------------------------------------]]--

local function run_behavior_handler(args, params, behavior_name)
  local handler = behavior_handlers[behavior_name]
  if handler then
    return handler(args, params)
  end
  return idle_result(args)
end

--[[----------------------------------------------------------------------------
  BLENDED NAVIGATION
----------------------------------------------------------------------------]]--

local function navigate_blended(args, from_def, to_def, progress)
  local state = args.behavior_state

  -- Mark that we're blending and which direction
  args.is_blending = true
  args.blending_from = state.blend_from
  args.blending_to = state.current

  -- Run both behavior handlers
  local from_result = run_behavior_handler(args, from_def, state.blend_from)
  local to_result = run_behavior_handler(args, to_def, state.current)

  -- Clean up blend flags
  args.is_blending = nil
  args.blending_from = nil
  args.blending_to = nil

  -- Lerp velocity
  local vx = lerp(from_result.vx, to_result.vx, progress)
  local vy = lerp(from_result.vy, to_result.vy, progress)

  -- Lerp forward direction
  local forward_x = lerp(from_result.forward_x, to_result.forward_x, progress)
  local forward_y = lerp(from_result.forward_y, to_result.forward_y, progress)

  -- Normalize forward after lerp
  local len = math.sqrt(forward_x * forward_x + forward_y * forward_y)
  if len > 0.001 then
    forward_x = forward_x / len
    forward_y = forward_y / len
  else
    forward_x = 1.0
    forward_y = 0.0
  end

  return {
    vx = vx,
    vy = vy,
    cursor = to_result.cursor,
    forward_x = forward_x,
    forward_y = forward_y,
    current_speed = lerp(from_result.current_speed or 0, to_result.current_speed or 0, progress),
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

--[[----------------------------------------------------------------------------
  MAIN ENTRY POINT
----------------------------------------------------------------------------]]--

function CBS_Navigation.navigate(args)
  local state = args.behavior_state
  local config = args.behavior_config

  -- Get behavior definitions with entity overrides
  local current_def = get_merged_params(state.current, config)

  -- Check if blending between behaviors
  if state.blend_from and state.blend_progress < 1.0 then
    local from_def = get_merged_params(state.blend_from, config)
    return navigate_blended(args, from_def, current_def, state.blend_progress)
  end

  -- Single behavior (no blend)
  return navigate_single(args, current_def, state.current)
end

-- Export behavior handlers for potential extension
CBS_Navigation.behavior_handlers = behavior_handlers

return CBS_Navigation
