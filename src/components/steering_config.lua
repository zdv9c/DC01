--[[============================================================================
  COMPONENT: SteeringConfig
  
  PURPOSE: Per-entity overrides for AI movement configuration.
  Values set here override global defaults in config/ai_config.lua.
  Nil values mean "inherit global".
============================================================================]]--

local Concord = require("libs.Concord")

return Concord.component("SteeringConfig", function(c, config)
  config = config or {}
  
  -- Core Movement
  c.speed = config.speed
  c.turn_smoothing = config.turn_smoothing
  c.velocity_smoothing = config.velocity_smoothing
  
  -- CBS Core
  c.danger_range = config.danger_range
  c.resolution = config.resolution
  c.deadlock_threshold = config.deadlock_threshold
  c.deadlock_bias = config.deadlock_bias
  c.danger_falloff = config.danger_falloff
  
  -- CBS Advanced (Solver & Danger)
  c.hard_mask_threshold = config.hard_mask_threshold
  c.base_spread_angle = config.base_spread_angle
  c.min_danger_to_spread = config.min_danger_to_spread
  c.proximity_dilation = config.proximity_dilation
  c.collision_padding = config.collision_padding
  
  -- Pathfinding
  c.path_lock_range = config.path_lock_range
  c.waypoint_reached = config.waypoint_reached
  
  -- Path Locking Maneuver
  c.path_lock_boost = config.path_lock_boost
  c.path_lock_offset = config.path_lock_offset
  c.path_lock_margin = config.path_lock_margin
  
  -- Behaviors (Wander)
  c.wander_weight = config.wander_weight
  c.wander_rate = config.wander_rate
  c.wander_angle_range = config.wander_angle_range
  
  -- Speed Noise
  c.speed_noise_amount = config.speed_noise_amount
  c.speed_noise_rate = config.speed_noise_rate
end)
