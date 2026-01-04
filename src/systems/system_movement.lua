--[[============================================================================
  SYSTEM: Movement
  
  PURPOSE: Applies velocity to position with friction and speed clamping
  
  DATA CONTRACT:
    READS:  Transform, Velocity
    WRITES: Transform, Velocity
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: After Input, before Collision
============================================================================]]--

local Concord = require "libs.Concord"

local movement = Concord.system({
  pool = {"Transform", "Velocity"}
})

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function movement:update(dt)
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    
    local result = compute_movement_step(
      pos.x, pos.y,
      vel.x, vel.y,
      vel.speed,
      vel.friction,
      dt
    )
    
    pos.x = result.px
    pos.y = result.py
    vel.x = result.vx
    vel.y = result.vy
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes new position and velocity after movement step
-- @param px: number - current position x
-- @param py: number - current position y
-- @param vx: number - current velocity x
-- @param vy: number - current velocity y
-- @param max_speed: number - maximum speed
-- @param friction: number - friction coefficient
-- @param dt: number - delta time
-- @return {px, py, vx, vy: number}
function compute_movement_step(px, py, vx, vy, max_speed, friction, dt)
  -- Apply friction first
  local friction_result = apply_friction(vx, vy, friction, dt)
  vx, vy = friction_result.vx, friction_result.vy
  
  -- Clamp to max speed
  local clamp_result = clamp_velocity(vx, vy, max_speed * 2)
  vx, vy = clamp_result.vx, clamp_result.vy
  
  -- Apply velocity to position
  local new_px = px + vx * dt
  local new_py = py + vy * dt
  
  return {px = new_px, py = new_py, vx = vx, vy = vy}
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Applies linear drag to velocity
-- @param vx: number - velocity x
-- @param vy: number - velocity y
-- @param friction: number - friction coefficient
-- @param dt: number - delta time
-- @return {vx: number, vy: number}
function apply_friction(vx, vy, friction, dt)
  local factor = 1 - math.min(friction * dt, 1)
  return {
    vx = vx * factor,
    vy = vy * factor
  }
end

-- Clamps velocity magnitude to max speed
-- @param vx: number - velocity x
-- @param vy: number - velocity y
-- @param max_speed: number - maximum speed
-- @return {vx: number, vy: number}
function clamp_velocity(vx, vy, max_speed)
  local speed_sq = vx * vx + vy * vy
  if speed_sq > max_speed * max_speed then
    local speed = math.sqrt(speed_sq)
    return {
      vx = (vx / speed) * max_speed,
      vy = (vy / speed) * max_speed
    }
  end
  return {vx = vx, vy = vy}
end

return movement
