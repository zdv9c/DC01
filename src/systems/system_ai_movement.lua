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
  if should_debug then self.debug_timer = 0 end
  
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
        -- Advance to next waypoint
        path.current_index = math.min(path.current_index + 1, #path.waypoints)
        wp = path.waypoints[path.current_index]
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
  
  if immediate_target and dist_to_target > MOVE_CFG.target_reached * AI_CONFIG.TILE_SIZE then
    -- Seek immediate target (waypoint or final)
    local to_target = {
      x = immediate_target.x - pos.x, 
      y = immediate_target.y - pos.y
    }
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
    filter = ignore_self
  })
  
  -- 4. Apply Organic Noise
  steering.noise_time = (steering.noise_time or 0) + dt
  CBS.add_spatial_noise(ctx, {
    amount = NOISE_CFG.amount,
    scale = NOISE_CFG.scale,
    rate = NOISE_CFG.rate,
    seed = steering.seed or 0,
    time = steering.noise_time
  })
  
  -- 5. Solve for Direction
  local result = CBS.solve(ctx)
  
  -- 6. Compute Velocity
  local target_vx, target_vy = 0, 0
  
  if has_movement and result.magnitude > 0.01 then
    local dir = result.direction
    target_vx = dir.x * MOVE_CFG.speed
    target_vy = dir.y * MOVE_CFG.speed
    
    -- Update forward heading (for noise and visual orientation)
    steering.forward_x = dir.x
    steering.forward_y = dir.y
  end
  
  -- Smooth acceleration (Exponential Decay)
  local blend = 1.0 - math.exp(-MOVE_CFG.velocity_smoothing * dt)
  local new_vx = vel.x + (target_vx - vel.x) * blend
  local new_vy = vel.y + (target_vy - vel.y) * blend
  
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
    debug_context = ctx,
    ray_results = ray_results
  }
end

return ai_movement
