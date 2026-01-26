--[[============================================================================
  COMPONENT: Debug
  
  PURPOSE: Configurable debug tracking for entities
  
  Attach this component to any entity to enable terminal output for debugging.
  Configure which aspects to track via flags.
============================================================================]]--

local Concord = require "libs.Concord"

Concord.component("Debug", function(c, config)
  config = config or {}
  
  c.enabled = config.enabled ~= false  -- Default true
  c.track_position = config.track_position or false
  c.track_velocity = config.track_velocity or false
  c.track_collision = config.track_collision or false
  c.track_cbs = config.track_cbs or false  -- CBS weight visualization
  c.entity_name = config.entity_name or "Entity"
  c.throttle_interval = config.throttle_interval or 0.25  -- Default 0.25s between updates
  
  -- Internal state tracking for change detection
  c.last_position = nil
  c.last_velocity = nil
  c.last_collision_state = nil
  c.time_since_last_output = 0
end)
