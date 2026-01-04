--[[============================================================================
  COMPONENT: Transform
  
  PURPOSE: Represents position of an entity in the 2D world
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("Transform", function(c, x, y)
  c.x = x or 0
  c.y = y or 0
end)
