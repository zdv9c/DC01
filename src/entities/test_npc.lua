--[[============================================================================
  ENTITY: Test NPC
  
  PURPOSE: Assembler for the test AI agent
============================================================================]]--

local AI_CONFIG = require "config.ai_config"

return function(e, x, y)
  -- Core Physics & Transform
  e:give("Transform", x, y)
  e:give("Velocity", 0, 0, AI_CONFIG.movement.speed, 0) -- kinematic (no friction)
  e:give("Collider", 16, 16, "dynamic")
  
  -- Rendering
  e:give("Sprite", {1, 1, 0, 1}, 8)  -- Yellow
  
  -- AI Behavior
  e:give("AIControlled")
  -- Spawn, 15-tile leash (240px), seed=42 (default hardcoded for now)
  e:give("SteeringState", x, y, 240, 42)
  e:give("Path", x, y)  -- Initialize path with spawn location
  
  -- Debugging
  e:give("Debug", {
    entity_name = "Enemy",
    track_position = false,
    track_velocity = false,
    track_collision = false,
    track_cbs = true  -- Enable CBS debug visualization
  })
  
  return e
end
