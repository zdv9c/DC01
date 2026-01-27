-- steering.lua
-- Kinematic steering utilities for CBS library

local vec2 = require("libs.cbs.vec2")

local steering = {}

-- Interpolates between two angles correctly across the 0/2PI boundary
-- @param a: current angle (radians)
-- @param b: target angle (radians)
-- @param t: interpolation factor (0-1)
-- @return new angle
function steering.lerp_angle(a, b, t)
  local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
  return a + (diff * t)
end

-- Smooths turning by interpolating the heading vector
-- @param current_heading: vec2 - unit vector of current direction
-- @param target_dir: vec2 - unit vector of desired direction
-- @param dt: delta time
-- @param smoothing_rate: rate of interpolation
-- @return vec2 - new unit heading
function steering.smooth_turn(current_heading, target_dir, dt, smoothing_rate)
  -- 1. Get angles
  local current_angle = vec2.angle(current_heading)
  local target_angle = vec2.angle(target_dir)
  
  -- 2. Blend angles
  local blend = 1.0 - math.exp(-smoothing_rate * dt)
  local result_angle = steering.lerp_angle(current_angle, target_angle, blend)
  
  -- 3. Return unit vector
  return vec2.from_angle(result_angle)
end

return steering
