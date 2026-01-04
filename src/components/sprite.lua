--[[============================================================================
  COMPONENT: Sprite
  
  PURPOSE: Visual representation of entity (placeholder circles/rectangles)
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("Sprite", function(c, color, radius, shape_type)
  c.color = color or {1, 1, 1, 1}
  c.radius = radius or 8  -- 16x16 means radius 8
  c.type = shape_type or "circle"
end)
