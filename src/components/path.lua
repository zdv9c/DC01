--[[============================================================================
  COMPONENT: Path
  
  PURPOSE: Stores A* pathfinding data for navigation
  
  DATA:
    waypoints: array of {x, y} - Sequential list of path nodes
    final_target: {x, y} - Ultimate destination
    current_index: integer - Index of next waypoint to visit
    refresh_timer: number - Time since last path calculation
    last_target_pos: {x, y} - Position of target at last path calc
============================================================================]]--

local Concord = require("libs.Concord")

return Concord.component("Path", function(c, goal_x, goal_y)
  -- The list of waypoints to follow
  -- waypoints[1] is the NEXT point to reach
  c.waypoints = {}
  
  -- The ultimate destination (may be different from last waypoint)
  c.final_target = {x = goal_x or 0, y = goal_y or 0}
  
  -- Dynamic target (optional entity reference)
  c.target_entity = nil
  
  -- Current index in smooth path (usually 1 if consuming waypoints)
  c.current_index = 1
  
  -- Tracking for when to re-path
  c.refresh_timer = 0
  c.last_target_pos = {x = goal_x or 0, y = goal_y or 0}
  
  -- Status flags
  c.is_valid = false       -- True if a valid path exists
  c.is_finished = false    -- True if reached final target
end)
