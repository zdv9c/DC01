--[[============================================================================
  COMPONENT: Velocity
  
  PURPOSE: Represents rate of change of position, with friction and speed limits
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("Velocity", function(c, x, y, speed, friction)
  c.x = x or 0
  c.y = y or 0
  c.speed = speed or 100
  c.friction = friction or 10
end)
