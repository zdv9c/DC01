--[[============================================================================
  SYSTEM: AI Movement
  
  PURPOSE: CBS-driven steering for AI-controlled entities (wandering + path following)
  
  DATA CONTRACT:
    READS:  Transform, Velocity, SteeringState, Path, Collider (obstacles)
    WRITES: Velocity, SteeringState, Path
    EMITS:  (none)
    CONFIG: ai_config
  
  UPDATE ORDER: After Pathfinding, before Movement
============================================================================]]--

local Concord = require("libs.Concord")
local CBS = require("libs.cbs")
local raycast = require("libs.cbs.raycast") -- Required for manual path check
local AI_CONFIG = require("config.ai_config")

local ai_movement = Concord.system({
  pool = {"AIControlled", "Transform", "Velocity", "SteeringState", "Path", "Collider"},
  obstacles = {"Transform", "Collider"}
})

-- Local alias for config sections
local CBS_CFG = AI_CONFIG.cbs
local PATH_CFG = AI_CONFIG.pathfinding
local MOVE_CFG = AI_CONFIG.movement
local NOISE_CFG = AI_CONFIG.noise

--[[----------------------------------------------------------------------------
  HELPER FUNCTIONS
----------------------------------------------------------------------------]]--

-- Returns true if there is a clear path between two world points for the agent
local function has_clear_los(start_pos, end_pos, obstacles, radius, self_entity)
  local dx = end_pos.x - start_pos.x
  local dy = end_pos.y - start_pos.y
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist < 0.1 then return true end
  
  local angle = math.atan2(dy, dx)
  local filter = function(obs) return obs.entity ~= self_entity end
  
  -- Use a slightly larger radius for safety when checking LOS
  local safety_radius = radius + 2 
  local hit = raycast.cast(start_pos, angle, dist, obstacles, filter)
  
  return hit == nil
end

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function ai_movement:init()
  -- Store CBS contexts for debug visualization
  self.debug_contexts = {}
  self.debug_timer = 0
end

function ai_movement:update(dt)
  -- Throttled debug output
  self.debug_timer = self.debug_timer + dt
  local should_debug = self.debug_timer >= AI_CONFIG.debug.print_interval
  if should_debug then 
    self.debug_timer = 0 
  end
  
  -- Collect obstacles for raycasting
  local obstacle_data = {}
  for _, entity in ipairs(self.obstacles) do
    local pos = entity.Transform
    local col = entity.Collider
    -- Use half width as efficient circle radius
    local radius = col and (col.width / 2) or 8
    table.insert(obstacle_data, {x = pos.x, y = pos.y, radius = radius, entity = entity})
  end
  
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    local steering = entity.SteeringState
    local path = entity.Path
    local collider = entity.Collider
    
    local entity_radius = collider and (collider.width / 2) or 8
    
    -- Sync steering target from Path component (if set by other systems)
    if path.final_target then
       steering.target_x = path.final_target.x
       steering.target_y = path.final_target.y
       steering.has_target = true
    end
    
    -- 0. Continuous Path Pruning (Greedy LOS) - DISABLED
    -- Relying on standard waypoint following for stability
    --[[
    if path.is_valid and #path.waypoints > 1 then
      -- Start checking from the furthest possible waypoint for one-frame shortcuts
      -- Limit lookahead to preventing aggressive corner cutting (e.g. only check next 3 nodes)
      local lookahead_limit = math.min(#path.waypoints, 4)
      local furthest_visible = 1
      for i = lookahead_limit, 2, -1 do
        if has_clear_los(pos, path.waypoints[i], obstacle_data, entity_radius, entity) then
          furthest_visible = i
          break
        end
      end
      
      -- Remove all waypoints before the furthest visible one
      for i = 1, furthest_visible - 1 do
        table.remove(path.waypoints, 1)
      end
    end
    ]]--
    
    -- Call orchestrator
    local result = compute_ai_steering(
      pos, vel, steering, path,
      obstacle_data, entity_radius, dt, should_debug, entity
    )
    
    -- Apply results
    vel.x = result.vx
    vel.y = result.vy
    steering.cursor = result.cursor
    steering.forward_x = result.forward_x
    steering.forward_y = result.forward_y
    steering.deadlock_side = result.deadlock_side
    steering.last_ray_results = result.ray_results  -- Export for debug viz
    
    -- Store context for debug visualization
    self.debug_contexts[entity] = result.debug_context
  end
  
  -- Expose debug contexts
  self:getWorld():setResource("ai_debug_contexts", self.debug_contexts)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes AI steering using Hybrid A* + CBS
-- @return {vx, vy, cursor, forward_x, forward_y, debug_context}
function compute_ai_steering(pos, vel, steering, path, obstacles, entity_radius, dt, should_debug, self_entity)
  local ctx = CBS.new_context(CBS_CFG.resolution)
  CBS.reset_context(ctx)
  
  -- 1. Determine Immediate Target (Tactical Goal)
  local immediate_target = nil
  local dist_to_target = 0
  
  -- A* Waypoint following
  if path.is_valid and #path.waypoints > 0 then
    -- Get current waypoint
    local wp = path.waypoints[path.current_index]
    
    if wp then
      -- Check if reached
      local dx = wp.x - pos.x
      local dy = wp.y - pos.y
      local dist = math.sqrt(dx*dx + dy*dy)
      
      if dist < PATH_CFG.waypoint_reached * AI_CONFIG.TILE_SIZE then
        if path.current_index >= #path.waypoints then
           -- Reached destination: Request target removal
           path.final_target = nil
           path.waypoints = {}
           path.is_valid = false
           path.current_index = 1
           steering.has_target = false
           immediate_target = nil
        else
           -- Advance to next waypoint
           path.current_index = path.current_index + 1
           wp = path.waypoints[path.current_index]
        end
      end
      
      immediate_target = wp
      dist_to_target = dist
    end
  elseif steering.has_target then
    -- Direct seek (fallback if no path found or LOS is clear)
    immediate_target = {x = steering.target_x, y = steering.target_y}
    local dx = immediate_target.x - pos.x
    local dy = immediate_target.y - pos.y
    dist_to_target = math.sqrt(dx*dx + dy*dy)
  end
  
  -- 2. Apply Behaviors
  local has_movement = false
  local vec_to_target = nil -- Normalized direction
  local dist_to_target_sq = 0
  local use_simple_solver = false -- Default to interpolated solver
  
  if immediate_target and dist_to_target > MOVE_CFG.target_reached * AI_CONFIG.TILE_SIZE then
    -- Seek immediate target (waypoint or final)
    -- Seek immediate target (waypoint or final)
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
  else
    -- Idle / Wander
    -- (Could add wander logic here if needed)
  end
  
  -- 3. Apply Obstacle Avoidance (Raycasts)
  -- Ignore self in raycasts using filter function
  local function ignore_self(obs)
    return obs.entity ~= self_entity
  end

  local ray_results = CBS.cast_slot_rays(ctx, {x = pos.x, y = pos.y}, obstacles, {
    range = CBS_CFG.danger_range * AI_CONFIG.TILE_SIZE,
    falloff = CBS_CFG.danger_falloff,
    radius = entity_radius,
    filter = ignore_self
  })
  
  -- 3b. Apply Path Locking (Clear Line of Sight Check)
  -- If we have a target and we can see it clearly, LOCK onto it
  -- 3b. Apply Path Locking (Clear Line of Sight Check)
  -- If we have a target and we can see it clearly, LOCK onto it
  -- Only engage if we are far enough away (prevent overshoot dancing)
  local path_lock_dist = PATH_CFG.path_lock_range * AI_CONFIG.TILE_SIZE
  if has_movement and vec_to_target and dist_to_target > path_lock_dist then
    local angle_to_target = math.atan2(vec_to_target.y, vec_to_target.x)
    
    -- Offset start by radius + small epsilon to avoid self-intersection artifacts
    -- Radius is approx 8 pixels
    local start_offset = 10 
    local start_x = pos.x + math.cos(angle_to_target) * start_offset
    local start_y = pos.y + math.sin(angle_to_target) * start_offset
    
    -- Adjust distance to account for offset
    -- Also subtract a safety margin (4px) to avoid hitting the target itself or the wall behind it
    local check_dist = math.max(0, dist_to_target - start_offset - 4)
    
    -- Cast a single ray directly at the target
    local hit = raycast.cast(
      {x = start_x, y = start_y},
      angle_to_target,
      check_dist,
      obstacles,
      ignore_self
    )
    
    -- If no hit (clear path), inject strong boost (was 10.0, reduced to 3.0 to reduce target dancing)
    if not hit then
       CBS.add_path_locking(ctx, vec_to_target, 3.0)
       use_simple_solver = true -- Winner Take All for clear paths
    end
  end
  
  -- 4. Apply Organic Noise
  steering.noise_time = (steering.noise_time or 0) + dt
  CBS.add_spatial_noise(ctx, {
    amount = NOISE_CFG.amount,
    scale = NOISE_CFG.scale,
    rate = NOISE_CFG.rate,
    seed = steering.seed or 0,
    time = steering.noise_time
  })
  
  -- Resolve potential deadlocks (dead-center obstacles)
  -- Uses target direction intention to break symmetry
  local new_deadlock_side = 0
  if vec_to_target then
    new_deadlock_side = CBS.resolve_deadlocks(
      ctx,
      {x = steering.forward_x, y = steering.forward_y},
      vec_to_target,
      CBS_CFG.deadlock_threshold,
      CBS_CFG.deadlock_bias,
      steering.deadlock_side
    )
  end
  
  -- 5. Solve for Direction
  local result = nil
  if use_simple_solver then
    result = CBS.solve_simple(ctx)
  else
    result = CBS.solve(ctx)
  end
  
  -- 6. Compute Velocity
  local target_vx, target_vy = 0, 0
  
  if has_movement and result.magnitude > 0.01 then
    -- 6. Rotational Heading Steering
    local current_heading = {
      x = steering.forward_x or 1,
      y = steering.forward_y or 0
    }
    local desired_direction = result.direction
    
    -- Smoothly rotate current heading toward desired direction
    local new_heading = CBS.steering.smooth_turn(
      current_heading, 
      desired_direction, 
      dt, 
      MOVE_CFG.turn_smoothing
    )
    
    -- Update forward heading (for logic and visual orientation)
    steering.forward_x = new_heading.x
    steering.forward_y = new_heading.y
  end
  
  -- 7. Smooth Velocity (Polar/Magnitude-Invariant)
  local blend = 1.0 - math.exp(-MOVE_CFG.velocity_smoothing * dt)
  
  -- Target speed is biased by the CBS magnitude (naturally brakes in danger)
  -- Uses min_speed_bias to prevent the NPC from slowing to a crawl
  local target_speed = 0
  if has_movement then
    local bias = MOVE_CFG.min_speed_bias or 0
    -- CLAMP magnitude to 1.0 to prevent super-speed from high interest boosts
    local clamped_magnitude = math.min(1.0, result.magnitude)
    local effective_magnitude = bias + (1.0 - bias) * clamped_magnitude
    target_speed = MOVE_CFG.speed * effective_magnitude
  end
  
  -- Use internal current_speed state to avoid lag after physical collisions
  steering.current_speed = steering.current_speed or 0
  steering.current_speed = steering.current_speed + (target_speed - steering.current_speed) * blend
  
  -- Velocity is simply the current heading (already smoothed) * current speed intent
  local new_vx = steering.forward_x * steering.current_speed
  local new_vy = steering.forward_y * steering.current_speed
  
  -- Advance wander cursor
  local new_cursor = CBS.advance_cursor(steering.cursor, dt, 1.0)
  
  -- Debug logging
  if should_debug and has_movement then
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

return ai_movement
