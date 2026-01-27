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
    -- "linear": danger decreases linearly with distance
    -- "quadratic": danger stays low until very close, then spikes
    danger_falloff = "quadratic",
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
    
    -- Distance (in tiles) to consider waypoint "reached" and advance to next
    -- Lower = more precise path following, but may cause jitter
    waypoint_reached = 0.5,  -- 0.5 tiles = 8px
    
    -- When to use A* vs direct CBS
    -- If target is within this range AND has LOS, skip pathfinding
    direct_range = 4,  -- 4 tiles = 64px
  },
  
  -- ============================================================================
  -- MOVEMENT SETTINGS
  -- Physical movement properties
  -- ============================================================================
  
  movement = {
    -- Base movement speed (pixels per second)
    speed = 100,
    
    -- Velocity smoothing rate (higher = snappier, lower = more gradual)
    -- Controls how fast velocity blends toward target velocity
    velocity_smoothing = 8.0,
    
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
    amount = 0.33,
    
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
