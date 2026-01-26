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
  pool = {"AIControlled", "Transform", "Velocity", "SteeringState"},
  obstacles = {"Transform", "Collider"}
})

-- Config constants
local CBS_RESOLUTION = 16
local DANGER_RADIUS = 48      -- How close is dangerous
local MOVE_SPEED = 60         -- Base movement speed
local CURSOR_SPEED = 0.5      -- How fast noise cursor advances
local WANDER_ANGLE = math.pi / 3  -- ±60 degrees max sway range

-- Tether config (soft inner radius, hard outer radius)
local TETHER_SOFT_RADIUS = 32   -- Start gentle pull at 2 tiles
local TETHER_HARD_RADIUS = 240  -- Strong pull at 15 tiles

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
    
    -- Gather obstacle positions (all other entities with colliders)
    local obstacle_positions = {}
    for _, obstacle_entity in ipairs(self.obstacles) do
      if obstacle_entity ~= entity then
        local obs_pos = obstacle_entity.Transform
        table.insert(obstacle_positions, {x = obs_pos.x, y = obs_pos.y})
      end
    end
    
    -- Call orchestrator
    local result = compute_ai_steering(
      pos.x, pos.y,
      steering.cursor,
      steering.seed,
      steering.forward_x, steering.forward_y,
      steering.spawn_x, steering.spawn_y,
      obstacle_positions,
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
    
    -- Store context for debug visualization
    self.debug_contexts[entity] = result.debug_context
  end
  
  -- Store debug contexts as world resource for debug_cbs system
  self:getWorld():setResource("ai_debug_contexts", self.debug_contexts)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes AI steering using CBS library
-- Wander heading is maintained separately from velocity to prevent spiraling
-- @param px, py: number - current position
-- @param cursor: number - noise cursor
-- @param seed: number - noise seed
-- @param fwd_x, fwd_y: number - current wander heading (NOT velocity)
-- @param spawn_x, spawn_y: number - spawn position
-- @param obstacles: table - array of {x, y} positions
-- @param dt: number - delta time
-- @param should_debug: boolean - whether to print debug info
-- @return {vx, vy, cursor, forward_x, forward_y, debug_context}
function compute_ai_steering(px, py, cursor, seed, fwd_x, fwd_y, 
                              spawn_x, spawn_y, obstacles, dt, should_debug)
  -- Create fresh CBS context
  local ctx = CBS.new_context(CBS_RESOLUTION)
  CBS.reset_context(ctx)
  
  -- Use stored wander heading (NOT derived from velocity!)
  local wander_heading = {x = fwd_x, y = fwd_y}
  
  -- Ensure heading is normalized
  local heading_len = math.sqrt(fwd_x * fwd_x + fwd_y * fwd_y)
  if heading_len < 0.1 then
    wander_heading = {x = 1, y = 0}  -- Default to right
  end
  
  -- Calculate distance to spawn
  local to_spawn_x = spawn_x - px
  local to_spawn_y = spawn_y - py
  local dist_to_spawn = math.sqrt(to_spawn_x * to_spawn_x + to_spawn_y * to_spawn_y)
  
  -- Calculate tether blend (0 = no pull, 1 = full pull toward spawn)
  -- Starts at TETHER_SOFT_RADIUS, reaches full at TETHER_HARD_RADIUS
  local tether_blend = 0.0
  if dist_to_spawn > TETHER_SOFT_RADIUS then
    tether_blend = math.min(1.0, (dist_to_spawn - TETHER_SOFT_RADIUS) / (TETHER_HARD_RADIUS - TETHER_SOFT_RADIUS))
  end
  
  -- Add wander behavior using noise-modified heading
  -- Weight is reduced as tether increases
  local wander_weight = 1.0 - (tether_blend * 0.8)  -- At max tether, still 20% wander
  CBS.add_wander(ctx, wander_heading, cursor, {
    noise_scale = 0.1,
    angle_range = WANDER_ANGLE,
    weight = wander_weight,
    seed = seed
  })
  
  -- Add tether as seek toward spawn (blends with wander)
  if tether_blend > 0.01 then
    local to_spawn = {x = to_spawn_x, y = to_spawn_y}
    CBS.add_seek(ctx, to_spawn, tether_blend * 1.5)
  end
  
  -- Add danger from nearby obstacles (including player)
  CBS.add_danger_from_proximity(ctx, {x = px, y = py}, obstacles, DANGER_RADIUS)
  
  -- Solve for final direction
  local result = CBS.solve(ctx)
  
  -- Update cursor (advances noise position over time)
  local new_cursor = CBS.advance_cursor(cursor, dt, CURSOR_SPEED)
  
  -- Calculate new velocity
  local new_vx, new_vy
  if result.magnitude > 0.01 then
    new_vx = result.direction.x * MOVE_SPEED * result.magnitude
    new_vy = result.direction.y * MOVE_SPEED * result.magnitude
  else
    -- No valid direction, stop
    new_vx = 0
    new_vy = 0
  end
  
  -- Update wander heading: slowly rotate toward the chosen direction
  -- This prevents snapping but keeps heading stable
  local new_forward = wander_heading
  if result.magnitude > 0.01 then
    -- Blend current heading toward result direction
    local blend_rate = 2.0 * dt  -- Smooth rotation
    new_forward = {
      x = wander_heading.x + (result.direction.x - wander_heading.x) * blend_rate,
      y = wander_heading.y + (result.direction.y - wander_heading.y) * blend_rate
    }
    -- Normalize
    local len = math.sqrt(new_forward.x * new_forward.x + new_forward.y * new_forward.y)
    if len > 0.1 then
      new_forward.x = new_forward.x / len
      new_forward.y = new_forward.y / len
    end
  end
  
  -- Debug output (throttled)
  if should_debug then
    print(string.format("[AI] pos=(%.0f,%.0f) dist=%.0f tether=%.2f wander_w=%.2f mag=%.2f vel=(%.1f,%.1f)",
      px, py, dist_to_spawn, tether_blend, wander_weight, result.magnitude, new_vx, new_vy))
  end
  
  return {
    vx = new_vx,
    vy = new_vy,
    cursor = new_cursor,
    forward_x = new_forward.x,
    forward_y = new_forward.y,
    debug_context = ctx
  }
end

return ai_movement
