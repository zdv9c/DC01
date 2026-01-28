--[[============================================================================
  SYSTEM: Input
  
  PURPOSE: Reads player input and applies acceleration to controlled entities
  
  DATA CONTRACT:
    READS:  PlayerControlled, Velocity
    WRITES: Velocity
    EMITS:  (none)
    CONFIG: (none - uses Baton internally)
  
  UPDATE ORDER: First (before Movement)
============================================================================]]--

local Concord = require "libs.Concord"
local Baton = require "libs.baton.baton"

local input = Concord.system({
  pool = {"PlayerControlled", "Velocity"}
})

-- CONSTANTS
local ACCELERATION_FACTOR = 10

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function input:init()
  self.baton = Baton.new {
    controls = {
      left = {'key:left', 'key:a', 'axis:leftx-', 'button:dpleft'},
      right = {'key:right', 'key:d', 'axis:leftx+', 'button:dpright'},
      up = {'key:up', 'key:w', 'axis:lefty-', 'button:dpup'},
      down = {'key:down', 'key:s', 'axis:lefty+', 'button:dpdown'},
      action = {'key:x', 'button:a'},
    },
    pairs = {
      move = {'left', 'right', 'up', 'down'}
    },
    joystick = love.joystick.getJoysticks()[1],
  }
end

function input:update(dt)
  self.baton:update()
  
  local input_x, input_y = self.baton:get('move')
  
  for _, entity in ipairs(self.pool) do
    local vel = entity.Velocity
    
    local result = compute_acceleration(
      vel.x, vel.y,
      input_x, input_y,
      vel.speed,
      dt
    )
    
    vel.x = result.vx
    vel.y = result.vy
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes new velocity after applying input-based acceleration
-- @param vx: number - current velocity x
-- @param vy: number - current velocity y
-- @param input_x: number - input axis x (-1 to 1)
-- @param input_y: number - input axis y (-1 to 1)
-- @param speed: number - entity speed stat
-- @param dt: number - delta time
-- @return {vx: number, vy: number}
function compute_acceleration(vx, vy, input_x, input_y, speed, dt)
  if input_x == 0 and input_y == 0 then
    return {vx = vx, vy = vy}
  end
  
  local accel = calculate_input_acceleration(input_x, input_y, speed, dt)
  local new_vx = vx + accel.x
  local new_vy = vy + accel.y
  
  return {vx = new_vx, vy = new_vy}
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Calculates acceleration vector from input and speed
-- @param input_x: number - input axis x
-- @param input_y: number - input axis y  
-- @param speed: number - entity speed stat
-- @param dt: number - delta time
-- @return {x: number, y: number}
function calculate_input_acceleration(input_x, input_y, speed, dt)
  return {
    x = input_x * speed * dt * ACCELERATION_FACTOR,
    y = input_y * speed * dt * ACCELERATION_FACTOR
  }
end

return input
