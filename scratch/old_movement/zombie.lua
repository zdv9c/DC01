--[[============================================================================
  ENTITY: Zombie
  
  PURPOSE: Assembler for the Zombie agent (Chaos movement test)
============================================================================]]--

local AI_CONFIG = require "config.ai_config"

return function(e, x, y)
  -- Core Physics & Transform
  e:give("Transform", x, y)
  e:give("Velocity", 0, 0, AI_CONFIG.movement.speed, 0) -- kinematic
  e:give("Collider", 16, 16, "dynamic")
  
  -- Rendering (Dark Green)
  e:give("Sprite", {0, 0.5, 0, 1}, 8)
  
  -- AI Behavior
  e:give("AIControlled")
  -- Spawn, 15-tile leash (240px), random seed
  e:give("SteeringState", x, y, 240, math.random(10000))
  e:give("Path", x, y)
  
  e:give("SteeringConfig", {
    -- High wander weight = strong swerving
    wander_weight = 0.8,
    -- Slow rate for "drunk walk" feel
    wander_rate = 0.3,
    -- Wide angle for exaggerated turns
    wander_angle_range = math.pi / 2,
    
    -- Speed Noise (Lurching)
    speed_noise_amount = 0.8,
    speed_noise_rate = 0.5,
    
    -- Slightly slower base speed
    speed = 40,
    path_lock_boost = 10
  })
  
  -- Debugging
  e:give("Debug", {
    entity_name = "Test Zombie",
    track_position = false,
    track_cbs = true
  })
  
  return e
end
