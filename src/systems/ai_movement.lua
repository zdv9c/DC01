--[[============================================================================
  SYSTEM: AI Movement (Refactored)
  
  PURPOSE: CBS-driven steering for AI-controlled entities (wandering + path following).
  Integrates Centralized Config and Generic Orchestrators.
  
  DATA CONTRACT:
    READS:  Transform, Velocity, SteeringState, Path, Collider, SteeringConfig
    WRITES: Velocity, SteeringState, Path
    CONFIG: ai_config + SteeringConfig component
    
  UPDATE ORDER: After Pathfinding, before Movement
============================================================================]]--

local Concord = require("libs.Concord")
local AI_CONFIG = require("config.ai_config")
local GroundMovement = require("systems.behaviors.ground_movement")

local ai_movement = Concord.system({
  pool = {"AIControlled", "Transform", "Velocity", "SteeringState", "Path", "Collider"},
  obstacles = {"Transform", "Collider"}
})

function ai_movement:init()
  -- Store CBS contexts for debug visualization
  self.debug_contexts = {}
  self.debug_timer = 0
  
  -- Pre-calculate default parameters (Flatten & Convert Units)
  -- This creates a single flat table that matches the "GroundMovement.navigate" expected params
  -- AND the library params.
  local TILE = AI_CONFIG.TILE_SIZE
  local cbs = AI_CONFIG.cbs
  local cbs_danger = cbs.danger or {}
  local cbs_solver = cbs.solver or {}
  local move = AI_CONFIG.movement
  local path = AI_CONFIG.pathfinding
  local path_locking = path.path_locking or {}
  local behaviors = AI_CONFIG.behaviors or {}
  local wander = behaviors.wander or {}
  local behaviors = AI_CONFIG.behaviors or {}
  local wander = AI_CONFIG.wander or {} -- New top-level wander table
  local speed_noise = AI_CONFIG.movement.speed_noise or {}
  
  self.defaults = {
    -- Movement
    speed = move.speed,
    velocity_smoothing = move.velocity_smoothing,
    turn_smoothing = move.turn_smoothing,
    min_speed_bias = move.min_speed_bias,
    target_reached = move.target_reached * TILE,
    
    -- CBS Core
    resolution = cbs.resolution,
    danger_range = cbs.danger_range * TILE,
    danger_falloff = cbs.danger_falloff,
    deadlock_threshold = cbs.deadlock_threshold,
    deadlock_bias = cbs.deadlock_bias,
    
    -- CBS Advanced (Solver)
    hard_mask_threshold = cbs_solver.hard_mask_threshold,
    
    -- CBS Advanced (Danger Mapping)
    spread_angle = cbs_danger.base_spread_angle,
    min_danger_to_spread = cbs_danger.min_danger_to_spread,
    proximity_dilation = cbs_danger.proximity_dilation,
    collision_padding = cbs_danger.collision_padding,
    
    -- Pathfinding / Tactics
    refresh_interval = path.refresh_interval,
    target_move_threshold = path.target_move_threshold,
    waypoint_reached = path.waypoint_reached * TILE,
    path_lock_range = path.path_lock_range * TILE,
    
    -- Path Locking Maneuver
    path_lock_offset = path_locking.ray_offset,
    path_lock_margin = path_locking.ray_margin,
    path_lock_boost = path_locking.boost,
    
    -- Behaviors
    wander_angle_range = wander.angle_range,
    
    -- Behaviors (Wander)
    wander_weight = wander.weight,
    wander_angle_range = wander.angle_range,
    wander_rate = wander.rate,

    -- Speed Noise
    speed_noise_amount = speed_noise.amount,
    speed_noise_rate = speed_noise.rate
  }
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
  
  local TILE = AI_CONFIG.TILE_SIZE
  
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    local steering = entity.SteeringState
    local path = entity.Path
    local collider = entity.Collider
    
    local entity_radius = collider and (collider.width / 2) or 8
    
    -- Sync steering target from Path component
    if path.final_target then
       steering.target_x = path.final_target.x
       steering.target_y = path.final_target.y
       steering.has_target = true
    end
    
    -- Merge Configuration
    local params = self.defaults -- Start with defaults (shared table)
    local override = entity.SteeringConfig
    
    if override then
      -- If overrides exist, need a new table to mix them
      params = setmetatable({}, {__index = self.defaults})
      
      -- Helper: Only copy if not nil
      local function copy(key, scale)
        if override[key] ~= nil then
          params[key] = override[key] * (scale or 1)
        end
      end
      
      copy("speed")
      copy("turn_smoothing")
      copy("velocity_smoothing")
      
      copy("resolution")
      copy("danger_range", TILE)
      copy("danger_falloff") -- string, no scale
      copy("deadlock_threshold")
      copy("deadlock_bias")
      
      copy("hard_mask_threshold")
      copy("base_spread_angle") -- mapped to params.spread_angle below if different
      if override.base_spread_angle then params.spread_angle = override.base_spread_angle end
      
      copy("min_danger_to_spread")
      copy("proximity_dilation")
      copy("collision_padding")
      
      copy("path_lock_range", TILE)
      copy("waypoint_reached", TILE)
      
      copy("path_lock_boost")
      copy("path_lock_offset")
      copy("path_lock_margin")
      
      copy("wander_angle_range")
      
      copy("wander_weight")
      copy("wander_angle_range")
      copy("wander_rate")
      
      copy("speed_noise_amount")
      copy("speed_noise_rate")
    end
    
    -- Call Orchestrator
    local result = GroundMovement.navigate({
      pos = pos,
      vel = vel,
      steering = steering,
      path = path,
      obstacles = obstacle_data,
      entity_radius = entity_radius,
      dt = dt,
      params = params,
      should_debug = should_debug,
      self_entity = entity
    })
    
    -- Apply Results
    vel.x = result.vx
    vel.y = result.vy
    steering.cursor = result.cursor
    steering.forward_x = result.forward_x
    steering.forward_y = result.forward_y
    steering.deadlock_side = result.deadlock_side
    steering.last_ray_results = result.ray_results
    
    self.debug_contexts[entity] = result.debug_context
  end
  
  -- Expose for gizmos
  self:getWorld():setResource("ai_debug_contexts", self.debug_contexts)
end

return ai_movement
