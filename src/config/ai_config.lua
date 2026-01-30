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
    danger_range = 3,  -- 2 tiles = 32px
    
    -- Danger falloff curve ("linear", "quadratic", "logarithmic", "cosine")
    danger_falloff = "linear",
    
    -- Deadlock Resolution (Symmetry Breaking)
    deadlock_threshold = 0.25,
    deadlock_bias = 0.25,
    
    -- Solver Settings
    solver = {
      -- Hard Mask: If danger > this, interest is zeroed (Physically impossible mask)
      hard_mask_threshold = 0.85, 
    },
    
    -- Danger Map Settings
    danger = {
      -- Base angular width of danger shadow behind obstacles (radians)
      base_spread_angle = math.pi / 4,
      
      -- Minimum danger value required to trigger spreading/dilation
      min_danger_to_spread = 0.05,
      
      -- Gaussian dilation factor for proximity danger (smoothing)
      proximity_dilation = 1.2,
      
      -- Padding logic: How many pixels inside the sprite radius count as "collision"
      -- Used to calculate exact gap distance.
      collision_padding = 8,
    }
  },
  
  -- ============================================================================
  -- A* PATHFINDING & TACTICAL SETTINGS
  -- ============================================================================
  
  pathfinding = {
    -- Seconds between automatic path recalculations
    refresh_interval = 1.0,
    
    -- If target moves more than this many tiles, recalculate immediately
    target_move_threshold = 3,
    
    -- Lower = more precise path following, but may cause jitter
    waypoint_reached = 0.5,  -- 0.5 tiles = 8px

    -- Threshold to stop locking onto target (prevent overshoot jitter)
    path_lock_range = 3.0,   -- 3 tiles = 48px
    
    -- Path Locking Maneuver (Shortcutting A* when clear)
    path_locking = {
       ray_offset = 10,  -- Start ray forward of center to avoid self/clutter
       ray_margin = 4,   -- Stop ray short of target to avoid target collision overlap
       boost = 3.0,      -- Interest bonus for locked path
    }
  },
  
  -- ============================================================================
  -- BEHAVIORS SETTINGS
  -- Specific tuning for composite behaviors
  -- ============================================================================
  
  behaviors = {
    wander = {
       -- Angular range for wander jitter (radians, +/- from forward)
       angle_range = math.pi / 4,
    }
  },

  -- ============================================================================
  -- MOVEMENT SETTINGS
  -- Physical movement properties
  -- ============================================================================
  
  movement = {
    -- Base movement speed (pixels per second)
    speed = 50,
    
    -- Velocity smoothing rate (higher = snappier, lower = more gradual)
    velocity_smoothing = 2.0,
    
    -- Turn smoothing rate (higher = tighter turns, lower = wider arcs)
    turn_smoothing = 5.0,
    
    -- Minimum speed percentage even when magnitude is low (0.0 to 1.0)
    min_speed_bias = 0.5,
    
    -- Distance (in tiles) to consider target "reached" and stop
    target_reached = 0.5,

    -- Speed Variation (Lurching)
    speed_noise = {
      amount = 0.0, -- Default off
      rate = 0.5,
    }
  },
  
  -- ============================================================================
  -- NOISE SETTINGS (Wander / Swerve)
  -- Organic movement variation
  -- ============================================================================
  
  -- Replaces old 'noise' table
  wander = {
    -- Interest weight for wander behavior
    weight = 0.3,

    -- Angular range for wander jitter (radians, +/- from forward)
    angle_range = math.pi / 4,

    -- Temporal rate of noise change (swerving speed)
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
