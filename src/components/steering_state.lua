--[[============================================================================
  COMPONENT: SteeringState
  
  PURPOSE: Stores per-entity CBS steering state for AI movement
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("SteeringState", function(c, spawn_x, spawn_y, leash_radius, seed)
  c.cursor = 0.0                    -- Noise cursor for wander (advances with time)
  c.seed = seed or 0                -- Unique noise seed per entity
  c.spawn_x = spawn_x or 0          -- Home position X
  c.spawn_y = spawn_y or 0          -- Home position Y
  c.leash_radius = leash_radius or 240  -- Max distance from spawn (15 tiles × 16px)
  c.forward_x = 1.0                 -- Current facing direction X
  c.forward_y = 0.0                 -- Current facing direction Y
end)
