--[[============================================================================
  COMPONENT: CBSBehaviorState

  PURPOSE: Per-entity CBS behavior state. Stores current behavior, blend state,
  and persistent steering data. Replaces SteeringState.
============================================================================]]--

local Concord = require("libs.Concord")

Concord.component("CBSBehaviorState", function(c, spawn_x, spawn_y, initial_behavior, seed)
  -- Current Behavior
  c.current = initial_behavior or "wander"
  c.previous = nil

  -- Blend State (for smooth transitions)
  c.blend_from = nil              -- Behavior we're blending from (nil = not blending)
  c.blend_progress = 1.0          -- 0 = fully old, 1 = fully new
  c.blend_duration = 0.2          -- Duration of current blend
  c.last_transition_time = 0      -- For cooldown tracking

  -- Per-Entity CBS State (persists across behaviors)
  c.cursor = 0.0                  -- Wander noise cursor
  c.seed = seed or 0              -- Unique noise seed per entity
  c.forward_x = 1.0               -- Current facing direction X
  c.forward_y = 0.0               -- Current facing direction Y
  c.current_speed = 0             -- Smoothed speed
  c.deadlock_side = 0             -- Persistent bias direction (0, 1, -1)
  c.noise_time = 0                -- Speed noise accumulator

  -- Behavior-Specific State (cleared on transition)
  c.data = {}

  -- Home/Spawn (for wander leash, flee destination)
  c.spawn_x = spawn_x or 0
  c.spawn_y = spawn_y or 0
  c.leash_radius = 240            -- Max distance from spawn (15 tiles × 16px)

  -- Target (for pathfind, flee, strafe)
  c.has_target = false
  c.target_x = 0
  c.target_y = 0

  -- Debug/Visualization
  c.last_ray_results = nil

  -- Manual Override (debug GUI bypass)
  c.manual_override_until = 0  -- Timestamp until automatic transitions are blocked
end)
