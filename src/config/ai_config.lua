--[[============================================================================
  CONFIG: AI Movement
  
  PURPOSE: Centralized AI navigation and movement settings
  
  USAGE: 
    local AI_CONFIG = require("config.ai_config")
    local range = AI_CONFIG.cbs.danger_range * AI_CONFIG.TILE_SIZE
============================================================================]]--

-- Base unit for all tile-relative measurements
local TILE_SIZE = 16

return {
  -- ============================================================================
  -- CORE SETTINGS
  -- ============================================================================
  
  TILE_SIZE = TILE_SIZE,
  
  -- ============================================================================
  -- CBS (Context-Based Steering) SETTINGS
  -- Local reactive obstacle avoidance
  -- ============================================================================
  
  cbs = {
    -- Number of direction slots (8 = fast/rough, 16 = balanced, 32 = smooth/slow)
    resolution = 16,
    
    -- How far to detect obstacles (in tiles)
    -- Higher = earlier avoidance, but may avoid things NPC could pass
    danger_range = 3,  -- 2 tiles = 32px
    
    -- Danger falloff curve
    -- "quadratic": danger stays low until very close, then spikes
    -- "logarithmic": danger is high even at distance (hard shell)
    danger_falloff = "linear",
    
    -- Deadlock Resolution (Symmetry Breaking)
    deadlock_threshold = 0.25,  -- Trigger if Target path danger > this
    deadlock_bias = 0.25,       -- Interest bonus to add to clearer side
  },
  
  -- ============================================================================
  -- A* PATHFINDING SETTINGS
  -- Strategic navigation around large obstacles
  -- ============================================================================
  
  pathfinding = {
    -- Seconds between automatic path recalculations
    -- Lower = more responsive, but higher CPU cost
    refresh_interval = 1.0,
    
    -- If target moves more than this many tiles, recalculate immediately
    target_move_threshold = 3,
    
    -- Lower = more precise path following, but may cause jitter
    waypoint_reached = 0.5,  -- 0.5 tiles = 8px

    -- Threshold to stop locking onto target (prevent overshoot jitter)
    path_lock_range = 3.0,   -- 3 tiles = 48px
  },
  
  -- ============================================================================
  -- MOVEMENT SETTINGS
  -- Physical movement properties
  -- ============================================================================
  
  movement = {
    -- Base movement speed (pixels per second)
    speed = 50,
    
    -- Velocity smoothing rate (higher = snappier, lower = more gradual)
    -- Controls how fast velocity blends toward target velocity
    velocity_smoothing = 2.0,
    
    -- Turn smoothing rate (higher = tighter turns, lower = wider arcs)
    turn_smoothing = 5.0,
    
    -- Minimum speed percentage even when magnitude is low (0.0 to 1.0)
    -- Prevents NPC from "crawling" too much in complex areas
    min_speed_bias = 0.5,
    
    -- Distance (in tiles) to consider target "reached" and stop
    target_reached = 0.5,  -- 0.5 tiles = 8px
  },
  
  -- ============================================================================
  -- NOISE SETTINGS
  -- Organic movement variation (prevents robotic movement)
  -- ============================================================================
  
  noise = {
    -- Strength of noise added to steering (0.0 = none, 1.0 = full)
    -- Higher = more wandery movement even when seeking
    amount = 0.15,
    
    -- Spatial scale of noise (roughness around the direction ring)
    -- Higher = more rapid direction changes
    scale = 1.0,
    
    -- Temporal rate of noise change
    -- Higher = faster oscillation over time
    rate = 0.5,
  },
  
  -- ============================================================================
  -- DEBUG SETTINGS
  -- Development and debugging options
  -- ============================================================================
  
  debug = {
    -- Throttle debug print frequency (seconds)
    print_interval = 0.25,
    
    -- Enable/disable various debug outputs
    log_pathfinding = false,
    log_steering = false,
  },
}
