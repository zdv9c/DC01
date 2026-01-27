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
  
  -- Manual target override (Sandbox control)
  c.has_target = false
  c.target_x = 0
  c.target_y = 0
  
  -- Raycast state
  c.raycast_timer = 0.0               -- Timer for throttled raycast updates
  c.last_ray_results = nil            -- Cached slot ray results for visualization
end)
