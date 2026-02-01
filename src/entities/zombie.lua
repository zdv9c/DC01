--[[============================================================================
  ENTITY: Zombie

  PURPOSE: Assembler for the Zombie agent (Chaos movement test)
============================================================================]]--

local AI_CONFIG = require("config.ai_config")

return function(e, x, y)
  -- Core Physics & Transform
  e:give("Transform", x, y)
  e:give("Velocity", 0, 0, AI_CONFIG.movement.speed, 0)
  e:give("Collider", 16, 16, "dynamic")

  -- Rendering (Dark Green)
  e:give("Sprite", {0, 0.5, 0, 1}, 8)

  -- AI Behavior
  e:give("AIControlled")
  e:give("CBSBehaviorState", x, y, "wander", math.random(10000))
  e:give("Path", x, y)

  -- Per-entity overrides: Drunk, lurching zombie movement
  e:give("CBSBehaviorConfig", {
    wander = {
      speed = 25,
      wander_weight = 0.8,
      wander_rate = 0.3,
      wander_angle_range = math.pi / 2,
    },
    pathfind = {
      speed = 40,
      path_lock_boost = 10,
    },
  })

  -- Modifiers for extra chaos
  e:give("CBSModifiers", {
    {type = "sway", weight = 0.2, rate = 0.4},
  })

  -- Debugging
  e:give("Debug", {
    entity_name = "Test Zombie",
    track_position = false,
    track_cbs = true,
  })

  return e
end
