--[[============================================================================
  BEHAVIOR: Ground Movement
  
  PURPOSE: Standard movement logic for ground-based agents.
  Orchestrates path following, avoidance, and tactical maneuvers.
  
  DEPENDENCIES: CBS Lib
============================================================================]]--

local CBS = require("libs.cbs")

local GroundMovement = {}

--[[----------------------------------------------------------------------------
  navigate
  
  PARAMS:
    pos: {x,y}             - Current position
    vel: {x,y}             - Current velocity
    steering: table        - Steering state (cursor, forward, seed, etc)
    path: table            - Path state
    obstacles: list        - List of obstacles
    entity_radius: number  - Agent radius
    dt: number             - Delta time
    params: table          - MERGED configuration (Global + Component Overrides)
    should_debug: boolean  - Debug flag
    self_entity: table     - Entity ref
    
  RETURNS:
    vx, vy, cursor, forward_x/y, deadlock_side, debug_context, ray_results
----------------------------------------------------------------------------]]--
function GroundMovement.navigate(args)
  local pos = args.pos
  local vel = args.vel
  local steering = args.steering
  local path = args.path
  local obstacles = args.obstacles
  local radius = args.entity_radius
  local dt = args.dt
  local cfg = args.params or {} -- ALL configs are now flat in this table
  local self_entity = args.self_entity
  
  -- Use config values with defaults (though params should already have defaults from merge)
  local RESOLUTION = cfg.resolution or 16
  local DANGER_RANGE = cfg.danger_range or 48
  local DANGER_FALLOFF = cfg.danger_falloff or "linear"
  local WAYPOINT_REACHED = cfg.waypoint_reached or 8
  local TARGET_REACHED = cfg.target_reached or 8
  local PATH_LOCK_RANGE = cfg.path_lock_range or 48
  local NOISE_AMOUNT = cfg.noise_amount or 0.15 -- Deprecated
  local NOISE_SCALE = cfg.noise_scale or 1.0     -- Deprecated
  local NOISE_RATE = cfg.noise_rate or 0.5       -- Deprecated
  
  -- NEW Configs
  local WANDER_WEIGHT = cfg.wander_weight or 0.0
  local WANDER_RATE = cfg.wander_rate or 0.5
  local WANDER_ANGLE = cfg.wander_angle_range or math.pi/4
  
  local SPEED_NOISE_AMOUNT = cfg.speed_noise_amount or 0.0
  local SPEED_NOISE_RATE = cfg.speed_noise_rate or 0.5
  
  local DEADLOCK_THRESHOLD = cfg.deadlock_threshold or 0.25
  local DEADLOCK_BIAS = cfg.deadlock_bias or 0.25
  local TURN_SMOOTHING = cfg.turn_smoothing or 5.0
  local VELOCITY_SMOOTHING = cfg.velocity_smoothing or 2.0
  local SPEED = cfg.speed or 50
  local MIN_SPEED_BIAS = cfg.min_speed_bias or 0.5
  local PATH_LOCK_BOOST = cfg.path_lock_boost or 3.0
  
  local ctx = CBS.new_context(RESOLUTION)
  CBS.reset_context(ctx)
  
  -- 1. Determine Immediate Target
  local immediate_target = nil
  local dist_to_target = 0
  
  if path.is_valid and #path.waypoints > 0 then
    local wp = path.waypoints[path.current_index]
    if wp then
      local dx = wp.x - pos.x
      local dy = wp.y - pos.y
      local dist = math.sqrt(dx*dx + dy*dy)
      
      if dist < WAYPOINT_REACHED then
        if path.current_index >= #path.waypoints then
           path.final_target = nil
           path.waypoints = {}
           path.is_valid = false
           path.current_index = 1
           steering.has_target = false
           immediate_target = nil
        else
           path.current_index = path.current_index + 1
           wp = path.waypoints[path.current_index]
        end
      end
      immediate_target = wp
      dist_to_target = dist
    end
  elseif steering.has_target then
    immediate_target = {x = steering.target_x, y = steering.target_y}
    local dx = immediate_target.x - pos.x
    local dy = immediate_target.y - pos.y
    dist_to_target = math.sqrt(dx*dx + dy*dy)
  end
  
  -- 2. Apply Seek & Vector
  local has_movement = false
  local vec_to_target = nil
  local use_simple_solver = false
  
  if immediate_target and dist_to_target > TARGET_REACHED then
    local to_target = {
      x = immediate_target.x - pos.x, 
      y = immediate_target.y - pos.y
    }
    local d = math.sqrt(to_target.x*to_target.x + to_target.y*to_target.y)
    if d > 0 then
       vec_to_target = {x = to_target.x / d, y = to_target.y / d}
    end
    
    CBS.add_seek(ctx, to_target, 1.0)
    has_movement = true
  end
  
  -- 3. Apply Obstacle Avoidance
  local function ignore_self(obs)
    return obs.entity ~= self_entity
  end

  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = DANGER_RANGE,
    falloff = DANGER_FALLOFF,
    radius = radius,
    filter = ignore_self,
    -- Pass through flattened advanced danger params
    spread_angle = cfg.spread_angle, 
    min_danger_to_spread = cfg.min_danger_to_spread
  })
  
  -- 3b. Path Locking (Using new generic maneuver)
  if has_movement and vec_to_target then
    -- Maneuver Config logic
    local maneuver_config = {
      min_range = PATH_LOCK_RANGE,
      offset = cfg.path_lock_offset or 10,
      boost = PATH_LOCK_BOOST,
      margin = cfg.path_lock_margin or 4,
      ignore_filter = ignore_self
    }
    
    local applied, reason = CBS.try_path_locking(
      ctx, pos, vec_to_target, dist_to_target, obstacles, maneuver_config
    )
    
    if applied then
      use_simple_solver = true
    end
  end
  
  -- 4. Apply Behaviors (Swerving / Wander)
  -- This replaces the old spatial noise.
  -- Add wander behavior if weight is > 0
  if WANDER_WEIGHT > 0.0 then
    -- Current heading for reference
    local forward = {
       x = steering.forward_x or 1,
       y = steering.forward_y or 0
    }
    
    local new_cursor, wander_dir = CBS.add_wander(ctx, forward, steering.cursor, {
       angle_range = WANDER_ANGLE,
       weight = WANDER_WEIGHT,
       noise_scale = 1.0, -- Simplified: baked into rate/cursor logic
       seed = steering.seed or 0
    })
    
    -- NOTE: advance_cursor below updates the cursor for next frame based on rate
  end
 
  
  -- Resolve Deadlocks
  local new_deadlock_side = 0
  if vec_to_target then
    new_deadlock_side = CBS.resolve_deadlocks(
      ctx,
      {x = steering.forward_x, y = steering.forward_y},
      vec_to_target,
      DEADLOCK_THRESHOLD,
      DEADLOCK_BIAS,
      steering.deadlock_side
    )
  end
  
  -- 5. Solve
  local result = nil
  if use_simple_solver then
    result = CBS.solve_simple(ctx, cfg) -- Pass cfg (contains hard_mask_threshold)
  else
    result = CBS.solve(ctx, cfg) -- Pass cfg (contains hard_mask_threshold)
  end
  
  -- 6. Compute Velocity
  local new_vx, new_vy = 0, 0
  
  if has_movement and result.magnitude > 0.01 then
    local current_heading = {
      x = steering.forward_x or 1,
      y = steering.forward_y or 0
    }
    local new_heading = CBS.steering.smooth_turn(
      current_heading, 
      result.direction, 
      dt, 
      TURN_SMOOTHING
    )
    
    steering.forward_x = new_heading.x
    steering.forward_y = new_heading.y
  end
  
  local blend = 1.0 - math.exp(-VELOCITY_SMOOTHING * dt)
  local target_speed = 0
  
  if has_movement then
    local bias = MIN_SPEED_BIAS
    local clamped_magnitude = math.min(1.0, result.magnitude)
    local effective_magnitude = bias + (1.0 - bias) * clamped_magnitude
    target_speed = SPEED * effective_magnitude

    -- Apply Speed Noise (Lurching)
    if SPEED_NOISE_AMOUNT > 0 then
      steering.noise_time = (steering.noise_time or 0) + dt
      
      local n_time = steering.noise_time * SPEED_NOISE_RATE
      -- Offset seed to decorrelate from direction noise
      local n_val = love.math.noise(n_time, (steering.seed or 0) + 123.45)
      
      -- Map [0, 1] to [-1, 1] * amount
      local mod = (n_val - 0.5) * 2.0 * SPEED_NOISE_AMOUNT
      
      -- Modulate speed
      target_speed = target_speed * (1.0 + mod)
      target_speed = math.max(0, target_speed)
    end
  end
  
  -- Current speed smoothing
  steering.current_speed = steering.current_speed or 0
  steering.current_speed = steering.current_speed + (target_speed - steering.current_speed) * blend
  
  new_vx = steering.forward_x * steering.current_speed
  new_vy = steering.forward_y * steering.current_speed
  
  -- Advance cursor specifically for wander noise
  -- The cursor advances based on rate.
  -- WANDER_RATE controls how fast we sweep through the noise field.
  local new_cursor = CBS.advance_cursor(steering.cursor, dt, WANDER_RATE)
  
  -- Debug logging
  if args.should_debug and has_movement then
    print(string.format("[AI] pos=(%.0f,%.0f) target=(%.0f,%.0f) waypoints=%d/%d vel=(%.1f,%.1f)",
      pos.x, pos.y, 
      immediate_target.x, immediate_target.y,
      path.current_index, #path.waypoints,
      new_vx, new_vy))
  end

  return {
    vx = new_vx,
    vy = new_vy,
    cursor = new_cursor,
    forward_x = steering.forward_x,
    forward_y = steering.forward_y,
    deadlock_side = new_deadlock_side,
    debug_context = ctx,
    ray_results = ray_results
  }
end

return GroundMovement
