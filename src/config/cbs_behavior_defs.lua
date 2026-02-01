--[[============================================================================
  CONFIG: CBS Behavior Definitions

  PURPOSE: Shared, immutable behavior configurations for CBS navigation.
  One copy in memory, referenced by all entities via string key.

  USAGE:
    local BehaviorDefs = require("config.cbs_behavior_defs")
    local params = BehaviorDefs.pathfind
============================================================================]]--

local TILE_SIZE = 16

return {
  --[[--------------------------------------------------------------------------
    PATHFIND
    Active path following with obstacle avoidance.
  --------------------------------------------------------------------------]]--
  pathfind = {
    speed = 50,
    turn_smoothing = 5.0,
    velocity_smoothing = 2.0,
    resolution = 16,
    danger_range = 3,              -- tiles
    danger_falloff = "linear",
    waypoint_reached = 0.5,        -- tiles
    path_lock_boost = 3.0,
    path_lock_offset = 10,
    path_lock_margin = 4,
    deadlock_threshold = 0.25,
    deadlock_bias = 0.25,
    hard_mask_threshold = 0.85,
    spread_angle = math.pi / 4,
    min_danger_to_spread = 0.05,
  },

  --[[--------------------------------------------------------------------------
    WANDER
    Idle meandering within leash radius.
  --------------------------------------------------------------------------]]--
  wander = {
    speed = 30,
    turn_smoothing = 3.0,
    velocity_smoothing = 2.0,
    resolution = 16,
    danger_range = 2,              -- tiles
    danger_falloff = "linear",
    wander_weight = 0.5,
    wander_rate = 0.5,
    wander_angle_range = math.pi / 4,
    leash_pull_strength = 2.0,
    hard_mask_threshold = 0.85,
    spread_angle = math.pi / 4,
    min_danger_to_spread = 0.05,
  },

  --[[--------------------------------------------------------------------------
    FLEE
    Rapid escape from threat.
  --------------------------------------------------------------------------]]--
  flee = {
    speed = 80,
    turn_smoothing = 8.0,          -- tighter turns when fleeing
    velocity_smoothing = 3.0,
    resolution = 16,
    danger_range = 5,              -- more aware when fleeing
    danger_falloff = "linear",
    flee_distance = 200,           -- pixels to flee before stopping
    hard_mask_threshold = 0.85,
    spread_angle = math.pi / 4,
    min_danger_to_spread = 0.05,
  },

  --[[--------------------------------------------------------------------------
    STRAFE
    Circle-strafing around target.
  --------------------------------------------------------------------------]]--
  strafe = {
    speed = 60,
    turn_smoothing = 4.0,
    velocity_smoothing = 2.0,
    resolution = 16,
    danger_range = 3,
    danger_falloff = "linear",
    orbit_radius = 48,             -- pixels
    min_range = 32,                -- pixels
    max_range = 80,                -- pixels
    strafe_direction = 1,          -- 1 = clockwise, -1 = counter
    hard_mask_threshold = 0.85,
    spread_angle = math.pi / 4,
    min_danger_to_spread = 0.05,
  },

  --[[--------------------------------------------------------------------------
    IDLE
    Stationary, but CBS still runs for obstacle awareness.
  --------------------------------------------------------------------------]]--
  idle = {
    speed = 0,
    turn_smoothing = 5.0,
    velocity_smoothing = 2.0,
    resolution = 16,
    danger_range = 2,
    danger_falloff = "linear",
    hard_mask_threshold = 0.85,
    spread_angle = math.pi / 4,
    min_danger_to_spread = 0.05,
  },
}
