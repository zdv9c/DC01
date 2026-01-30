--[[============================================================================
  MODULE: CBS Maneuvers
  
  PURPOSE: Higher-order tactical decisions and conditional behaviors.
  These functions check world state (rays, distance) and apply behaviors conditionally.
  
  DEPENDENCIES: behaviors_core, raycast
============================================================================]]--

local behaviors_core = require("libs.cbs.behaviors_core")
local raycast = require("libs.cbs.raycast")

local maneuvers = {}

--[[----------------------------------------------------------------------------
  try_path_locking
  
  Checks if the path to the target is clear (using an offset raycast)
  and if so, applies a strong "lock" interest to the target direction.
  This allows agents to move faster/straighter when they have line of sight.
  
  PARAMS:
    ctx: context           - CBS context
    pos: {x,y}             - Current position
    target_vec: {x,y}      - Normalized direction to target
    dist: number           - Distance to target
    obstacles: list        - List of obstacles
    config: table {
      min_range: number    - Minimum distance to attempt locking (default 50)
      offset: number       - Start ray offset from center (default 10)
      margin: number       - Safety margin at end of ray (default 4)
      width: number        - (Unused)
      boost: number        - Interest strength to apply (default 3.0)
      ignore_filter: fn    - Optional filter for raycast
    }
    
  RETURNS:
    applied: boolean       - True if locking was applied
    reason: string         - "locked", "blocked", "too_close"
----------------------------------------------------------------------------]]--
function maneuvers.try_path_locking(ctx, pos, target_vec, dist, obstacles, config)
  config = config or {}
  local min_dist = config.min_range or 50
  
  if dist <= min_dist then 
    return false, "too_close" 
  end

  local angle = math.atan2(target_vec.y, target_vec.x)
  local offset = config.offset or 10
  
  -- Calculate start point (offset forward to avoid self-intersection or immediate clutter)
  local start_x = pos.x + math.cos(angle) * offset
  local start_y = pos.y + math.sin(angle) * offset
  
  -- Don't cast past the target (minus margin)
  local check_dist = math.max(0, dist - offset - (config.margin or 4))
  
  local hit = raycast.cast(
    {x = start_x, y = start_y},
    angle,
    check_dist,
    obstacles,
    config.ignore_filter
  )
  
  if not hit then
    behaviors_core.add_path_locking(ctx, target_vec, config.boost or 3.0)
    return true, "locked"
  end
  
  return false, "blocked"
end

return maneuvers
