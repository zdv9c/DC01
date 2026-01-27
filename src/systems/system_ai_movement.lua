--[[============================================================================
  SYSTEM: AI Movement
  
  PURPOSE: CBS-driven steering for AI-controlled entities (wandering + tethering)
  
  DATA CONTRACT:
    READS:  Transform, Velocity, SteeringState, AIControlled, Collider (obstacles)
    WRITES: Velocity, SteeringState
    EMITS:  (none)
    CONFIG: CBS resolution, look_ahead, move_speed
  
  UPDATE ORDER: After Input, before Movement
============================================================================]]--

local Concord = require "libs.Concord"
local CBS = require "libs.cbs"

local ai_movement = Concord.system({
  pool = {"AIControlled", "Transform", "Velocity", "SteeringState", "Collider"},
  obstacles = {"Transform", "Collider"}
})

-- Config constants
local CBS_RESOLUTION = 16
local MOVE_SPEED = 100          -- Base movement speed (matches player)
local CURSOR_SPEED = 0.5        -- How fast noise cursor advances

local NOISE_CONFIG = {
  amount = 0.2,    -- Strength of noise (0-1)
  scale = 2.0,     -- Spatial scale (roughness around the ring)
  rate = 0.5       -- Temporal rate (how fast it changes)
}

-- Raycast config
local RAYCAST_RANGE = 64        -- Max distance to check for obstacles (4 tiles)
local RAYCAST_INTERVAL = 1/10   -- 10 updates per second
local ENABLE_STEERING_CORRECTION = true   -- Toggle steering correction (vs pure CBS)
local VELOCITY_SMOOTHING = 8.0  -- How fast velocity blends to target (higher = snappier)
local TARGET_REACHED_TOLERANCE = 8.0 -- Distance to consider target reached

-- Debug throttle
local DEBUG_INTERVAL = 0.25  -- 4 times per second
local debug_timer = 0

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function ai_movement:init()
  -- Store CBS contexts for debug visualization (keyed by entity)
  self.debug_contexts = {}
end

function ai_movement:update(dt)
  -- Throttled debug output
  debug_timer = debug_timer + dt
  local should_debug = debug_timer >= DEBUG_INTERVAL
  if should_debug then
    debug_timer = 0
  end
  
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    local steering = entity.SteeringState
    local collider = entity.Collider
    
    -- Entity's collision radius for shoulder-width LOS check
    local entity_radius = collider and (collider.width / 2) or 8
    
    -- Gather obstacle positions with radius (for raycast detection)
    local obstacle_data = {}
    for _, obstacle_entity in ipairs(self.obstacles) do
      if obstacle_entity ~= entity then
        local obs_pos = obstacle_entity.Transform
        local obs_col = obstacle_entity.Collider
        -- Use half the collider width as radius (assumes roughly square colliders)
        local radius = obs_col and (obs_col.width / 2) or 8
        table.insert(obstacle_data, {x = obs_pos.x, y = obs_pos.y, radius = radius})
      end
    end
    
    -- Debug: Check obstacle count
    if should_debug and #self.pool > 0 and entity == self.pool[1] then
       print("Obstacles found in list: " .. #self.obstacles)
       print("Obstacles stored for processing: " .. #obstacle_data)
    end
    -- Call orchestrator
    local result = compute_ai_steering(
      pos.x, pos.y,
      vel.x, vel.y,  -- Current velocity for smoothing
      steering,
      obstacle_data,
      entity_radius,
      dt,
      should_debug
    )
    
    -- Write velocity back
    vel.x = result.vx
    vel.y = result.vy
    
    -- Update steering state (forward is the wander heading, NOT velocity)
    steering.cursor = result.cursor
    steering.forward_x = result.forward_x
    steering.forward_y = result.forward_y
    
    -- Clear target if arrived (within tolerance)
    if steering.has_target then
      local dx = steering.target_x - pos.x
      local dy = steering.target_y - pos.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist <= TARGET_REACHED_TOLERANCE then
        steering.has_target = false
      end
    end
    
    -- Store context for debug visualization
    self.debug_contexts[entity] = result.debug_context
  end
  
  -- Store debug contexts as world resource for debug_cbs system
  self:getWorld():setResource("ai_debug_contexts", self.debug_contexts)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes AI steering using CBS with per-slot raycasting
-- @param px, py: number - current position
-- @param curr_vx, curr_vy: number - current velocity (for smoothing)
-- @param steering: table - SteeringState component data
-- @param obstacles: table - array of {x, y, radius}
-- @param entity_radius: number - half-width of entity for shoulder LOS check
-- @param dt: number - delta time
-- @param should_debug: boolean - whether to print debug info
-- @return {vx, vy, cursor, forward_x, forward_y, debug_context, ray_results}
function compute_ai_steering(px, py, curr_vx, curr_vy, steering, obstacles, entity_radius, dt, should_debug)
  -- Create fresh CBS context
  local ctx = CBS.new_context(CBS_RESOLUTION)
  CBS.reset_context(ctx)
  
  -- Use stored wander heading
  local wander_heading = {x = steering.forward_x, y = steering.forward_y}
  local heading_len = math.sqrt(steering.forward_x * steering.forward_x + steering.forward_y * steering.forward_y)
  if heading_len < 0.1 then
    wander_heading = {x = 1, y = 0}
  end
  
  -- Track if we have a movement target
  local has_movement = false
  local ray_results = nil
  local to_target = nil
  local target_dist = 0
  
  -- Check for manual target
  if steering.has_target then
    local target_pos = {x = steering.target_x, y = steering.target_y}
    to_target = {x = target_pos.x - px, y = target_pos.y - py}
    target_dist = math.sqrt(to_target.x * to_target.x + to_target.y * to_target.y)
    
    ctx.target_position = target_pos
    
    -- Narrow opening detection for aggressive gap threading
    -- When center ray is clear but adjacent rays are blocked, force direct path
    local clear_los = false
    local force_direct = false
    
    if target_dist > 0 then
      local dir_x = to_target.x / target_dist
      local dir_y = to_target.y / target_dist
      
      -- Use target distance as ray range (check all the way to target)
      local los_range = target_dist
      
      -- Check center ray
      local center_blocked = false
      for _, obs in ipairs(obstacles) do
        local hit = ray_circle_intersect(px, py, dir_x, dir_y, obs.x, obs.y, obs.radius, los_range)
        if hit then
          center_blocked = true
          break
        end
      end
      
      clear_los = not center_blocked
      
      -- If center is clear, check if this is a narrow opening
      -- Check multiple rays in a small cone around center direction
      -- Narrow opening = center clear, but most nearby rays blocked
      if clear_los then
        local blocked_count = 0
        local total_rays = 4  -- Check 4 adjacent rays (2 left, 2 right)
        
        -- Check rays at +/- 10° and +/- 20° from center
        local angles = {math.pi/18, -math.pi/18, math.pi/9, -math.pi/9}  -- ~10° and ~20°
        
        for _, angle in ipairs(angles) do
          local cos_a = math.cos(angle)
          local sin_a = math.sin(angle)
          local ray_dir_x = dir_x * cos_a - dir_y * sin_a
          local ray_dir_y = dir_x * sin_a + dir_y * cos_a
          
          for _, obs in ipairs(obstacles) do
            local hit = ray_circle_intersect(px, py, ray_dir_x, ray_dir_y, obs.x, obs.y, obs.radius, los_range)
            if hit then
              blocked_count = blocked_count + 1
              break
            end
          end
        end
        
        -- Narrow opening: center clear, at least 2 of 4 adjacent rays blocked
        force_direct = blocked_count >= 2
        
        -- Debug output for narrow opening detection
        if should_debug then
          print(string.format("[LOS] dist=%.0f clear=true blocked=%d/%d force=%s", 
            target_dist, blocked_count, total_rays, tostring(force_direct)))
        end
      else
        -- Debug output when center blocked
        if should_debug then
          print(string.format("[LOS] dist=%.0f clear=false force=false", target_dist))
        end
      end
    end
    
    -- Add seek toward target
    -- force_direct: only target slot gets interest (thread the needle)
    -- clear_los: zeros rear arc for focused forward movement
    CBS.add_seek(ctx, to_target, 1.0, clear_los, force_direct)
    has_movement = true
  else
    -- No target: idle
    ctx.wander_direction = wander_heading
  end
  
  -- Apply spatial noise (organic subtle wander)
  -- This makes the movement less robotic even when seeking
  steering.noise_time = (steering.noise_time or 0) + dt
  CBS.add_spatial_noise(ctx, {
    amount = NOISE_CONFIG.amount,
    scale = NOISE_CONFIG.scale,
    rate = NOISE_CONFIG.rate,
    seed = steering.seed or 0,
    time = steering.noise_time
  })
  
  -- Cast slot rays (throttled) - returns results for visualization and steering
  steering.raycast_timer = steering.raycast_timer + dt
  if steering.raycast_timer >= RAYCAST_INTERVAL then
    steering.raycast_timer = 0
    
    -- Dynamic range optimization: don't check further than the target
    local dynamic_range = RAYCAST_RANGE
    if steering.has_target then
      -- Checking slightly past target (+8px, half tile) to be safe
      dynamic_range = math.min(RAYCAST_RANGE, target_dist + 8)
    end
    
    -- Cast rays for all CBS slots (danger is applied internally)
    ray_results = CBS.cast_slot_rays(ctx, {x = px, y = py}, obstacles, {
      range = dynamic_range,
      falloff = "quadratic",  -- Softer falloff: danger stays low until close
      forward_direction = wander_heading  -- Enable rear-biased danger spread
    })
    
    -- Store for reuse between raycast updates
    steering.last_ray_results = ray_results
  else
    -- Use cached ray results
    ray_results = steering.last_ray_results
    
    -- Apply danger from cached results (cast_slot_rays only applies when called)
    if ray_results then
      for _, ray in ipairs(ray_results) do
        if ray.hit then
          ctx.danger[ray.slot_index] = math.max(ctx.danger[ray.slot_index], ray.danger)
        end
      end
    end
  end
  
  -- Apply organic steering correction (Soft Interest Injection)
  -- Instead of replacing the target, we inject interest into clear directions
  -- SKIP if we're forcing direct path through narrow opening (would fight against it)
  if ENABLE_STEERING_CORRECTION and has_movement and ray_results and not force_direct then
    local direct_angle = math.atan2(to_target.y, to_target.x)
    
    -- 1. Analyze directions to find the "Best Available" slot
    local best_slot = nil
    local best_score = -1e9
    
    -- Get current forward angle for bias (prevents jitter)
    local forward_angle = math.atan2(wander_heading.y, wander_heading.x)
    
    for _, ray in ipairs(ray_results) do
      -- Only consider slots generally in front (±90 degrees of target)
      local target_diff = math.abs(ray.angle - direct_angle)
      if target_diff > math.pi then target_diff = 2 * math.pi - target_diff end
      
      if target_diff < math.pi / 2 then
        local clearance = ray.hit and ray.distance or RAYCAST_RANGE
        
        -- Bias: detailed scoring to pick the most stable, clear path
        -- A. Clearance (most important - avoid collisions)
        local score = clearance * 2.0
        
        -- B. Target alignment (goal seeking - find the opening)
        -- Prioritize directions that lead toward the target
        local target_bonus = (1.0 - target_diff / math.pi) * 20.0
        score = score + target_bonus
        
        -- C. Forward alignment (momentum/hysteresis - reduce jitter)
        -- Secondary priority to prevent rapid direction changes
        local forward_diff = math.abs(ray.angle - forward_angle)
        if forward_diff > math.pi then forward_diff = 2 * math.pi - forward_diff end
        local alignment_bonus = (1.0 - forward_diff / math.pi) * 8.0
        score = score + alignment_bonus

        if score > best_score then
          best_score = score
          best_slot = ray
        end
      end
    end
    
    -- 2. Inject interest into the best slot if the direct path is compromised
    if best_slot then
      -- Reuse shoulder LOS check from earlier (already computed)
      -- Re-do the check to get distances (earlier check only got hit/miss)
      local perp_x = -to_target.y / target_dist
      local perp_y = to_target.x / target_dist
      local shoulder_offset = entity_radius * 0.9
      
      local left_x = px + perp_x * shoulder_offset
      local left_y = py + perp_y * shoulder_offset
      local right_x = px - perp_x * shoulder_offset
      local right_y = py - perp_y * shoulder_offset
      
      local left_blocked = false
      local right_blocked = false
      local left_dist = RAYCAST_RANGE
      local right_dist = RAYCAST_RANGE
      
      for _, obs in ipairs(obstacles) do
        -- Check left shoulder ray
        local hit_l, dist_l = ray_circle_intersect(
          left_x, left_y,
          to_target.x / target_dist, to_target.y / target_dist,
          obs.x, obs.y, obs.radius,
          RAYCAST_RANGE
        )
        if hit_l and dist_l < left_dist then
          left_dist = dist_l
          left_blocked = true
        end
        
        -- Check right shoulder ray
        local hit_r, dist_r = ray_circle_intersect(
          right_x, right_y,
          to_target.x / target_dist, to_target.y / target_dist,
          obs.x, obs.y, obs.radius,
          RAYCAST_RANGE
        )
        if hit_r and dist_r < right_dist then
          right_dist = dist_r
          right_blocked = true
        end
      end
      
      -- Blockage based on whichever shoulder is more blocked
      local min_shoulder_dist = math.min(left_dist, right_dist)
      local path_blocked = left_blocked or right_blocked
      local blockage_factor = path_blocked and (1.0 - (min_shoulder_dist / RAYCAST_RANGE)) or 0.0
      
      -- Smooth the avoidance weight for gradual curve-back
      -- Initialize if missing
      steering.avoidance_weight = steering.avoidance_weight or 0.0
      
      -- Target weight based on blockage (0.0 when clear, up to 2.0 when fully blocked)
      local target_weight = blockage_factor * 2.0
      
      -- Smoothly blend toward target weight (fast ramp up, slow decay for curved return)
      local weight_blend_speed = target_weight > steering.avoidance_weight and 8.0 or 6.0
      steering.avoidance_weight = steering.avoidance_weight + (target_weight - steering.avoidance_weight) * weight_blend_speed * dt
      
      -- Only inject avoidance interest if weight is significant
      if steering.avoidance_weight > 0.05 then
        -- Smoothly blend the avoidance heading (Persistence)
        -- This prevents the "best slot" from flickering rapidly
        local target_ax = math.cos(best_slot.angle)
        local target_ay = math.sin(best_slot.angle)
        
        -- Initialize avoidance_heading if missing
        if not steering.avoidance_heading then 
          steering.avoidance_heading = {x = target_ax, y = target_ay} 
        end
        
        -- Lerp toward new best direction
        local lerp_speed = 5.0 * dt
        steering.avoidance_heading.x = steering.avoidance_heading.x + (target_ax - steering.avoidance_heading.x) * lerp_speed
        steering.avoidance_heading.y = steering.avoidance_heading.y + (target_ay - steering.avoidance_heading.y) * lerp_speed
        
        -- Normalize
        local len = math.sqrt(steering.avoidance_heading.x^2 + steering.avoidance_heading.y^2)
        if len > 0 then
          steering.avoidance_heading.x = steering.avoidance_heading.x / len
          steering.avoidance_heading.y = steering.avoidance_heading.y / len
        end
        
        -- Inject the avoidance interest with smoothed weight
        CBS.add_seek(ctx, steering.avoidance_heading, steering.avoidance_weight)
      end
    end
  end
  
  -- Solve CBS for final direction
  local cbs_result = CBS.solve(ctx)
  
  -- Update cursor
  local new_cursor = CBS.advance_cursor(steering.cursor, dt, CURSOR_SPEED)
  
  -- Calculate target velocity from CBS result
  local target_vx, target_vy
  if has_movement and cbs_result.magnitude > 0.01 then
    -- Normalize and apply speed
    local dir = cbs_result.direction
    local dir_len = math.sqrt(dir.x * dir.x + dir.y * dir.y)
    if dir_len > 0 then
      target_vx = (dir.x / dir_len) * MOVE_SPEED
      target_vy = (dir.y / dir_len) * MOVE_SPEED
    else
      target_vx = 0
      target_vy = 0
    end
  else
    target_vx = 0
    target_vy = 0
  end
  
  -- Smooth velocity blend (exponential ease toward target)
  local blend = 1.0 - math.exp(-VELOCITY_SMOOTHING * dt)
  local new_vx = curr_vx + (target_vx - curr_vx) * blend
  local new_vy = curr_vy + (target_vy - curr_vy) * blend
  
  -- Update wander heading toward CBS direction
  local new_forward = wander_heading
  if has_movement and cbs_result.magnitude > 0.01 then
    local blend_rate = 2.0 * dt
    local dir = cbs_result.direction
    new_forward = {
      x = wander_heading.x + (dir.x - wander_heading.x) * blend_rate,
      y = wander_heading.y + (dir.y - wander_heading.y) * blend_rate
    }
    local len = math.sqrt(new_forward.x * new_forward.x + new_forward.y * new_forward.y)
    if len > 0.1 then
      new_forward.x = new_forward.x / len
      new_forward.y = new_forward.y / len
    end
  end
  
  -- Debug output
  if should_debug then
    local target_dist = 0
    if steering.has_target then
      local dx = steering.target_x - px
      local dy = steering.target_y - py
      target_dist = math.sqrt(dx*dx + dy*dy)
    end
    print(string.format("[AI] pos=(%.0f,%.0f) target_dist=%.0f vel=(%.1f,%.1f)",
      px, py, target_dist, new_vx, new_vy))
  end
  
  return {
    vx = new_vx,
    vy = new_vy,
    cursor = new_cursor,
    forward_x = new_forward.x,
    forward_y = new_forward.y,
    debug_context = ctx,
    ray_results = ray_results
  }
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Ray-circle intersection test for shoulder LOS checks
-- @param ray_x, ray_y: number - ray origin
-- @param dir_x, dir_y: number - ray direction (normalized)
-- @param cx, cy: number - circle center
-- @param radius: number - circle radius
-- @param max_dist: number - maximum ray distance
-- @return hit: boolean, distance: number
function ray_circle_intersect(ray_x, ray_y, dir_x, dir_y, cx, cy, radius, max_dist)
  -- Vector from ray origin to circle center
  local oc_x = ray_x - cx
  local oc_y = ray_y - cy
  
  -- Quadratic coefficients (a = 1 since dir is normalized)
  local b = 2 * (oc_x * dir_x + oc_y * dir_y)
  local c = (oc_x * oc_x + oc_y * oc_y) - radius * radius
  
  local discriminant = b * b - 4 * c
  
  if discriminant < 0 then
    return false, max_dist
  end
  
  local sqrt_d = math.sqrt(discriminant)
  local t1 = (-b - sqrt_d) / 2
  local t2 = (-b + sqrt_d) / 2
  
  -- Find nearest positive intersection
  local t = nil
  if t1 > 0 and t1 < max_dist then
    t = t1
  elseif t2 > 0 and t2 < max_dist then
    t = t2
  end
  
  if t then
    return true, t
  end
  
  return false, max_dist
end

return ai_movement
