--[[============================================================================
  COMPONENT: Collider
  
  PURPOSE: Physical bounds for collision detection
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("Collider", function(c, width, height, collider_type)
  c.width = width or 16
  c.height = height or 16
  c.type = collider_type or "dynamic"  -- "static" or "dynamic"
  c.colliding = false  -- Set by collision system each frame
  c.collision_count = 0  -- Number of active collisions
end)
