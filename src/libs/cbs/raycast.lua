--[[============================================================================
  UTILITY: Raycast
  
  PURPOSE: Line-circle intersection for obstacle detection
  
  USAGE:
    local raycast = require("libs.cbs.raycast")
    local hit = raycast.cast(origin, angle, max_dist, obstacles)
    -- hit = {distance, obstacle} or nil if no hit
============================================================================]]--

local raycast = {}

-- Casts a ray from origin in direction (angle radians) up to max_dist
-- obstacles: array of {x, y, radius} tables
-- Returns: {distance, obstacle} if hit, nil if clear
-- filter_fn: optional function(obstacle) returns boolean. If false, obstacle is ignored.
-- Returns: {distance, obstacle} if hit, nil if clear
function raycast.cast(origin, angle, max_dist, obstacles, filter_fn)
  local dir_x = math.cos(angle)
  local dir_y = math.sin(angle)
  
  local closest_hit = nil
  local closest_dist = max_dist
  
  for _, obs in ipairs(obstacles) do
    -- Apply filter if provided
    if not filter_fn or filter_fn(obs) then
      local dist = raycast.line_circle_intersection(
        origin.x, origin.y,
        dir_x, dir_y,
        obs.x, obs.y, obs.radius,
        max_dist
      )
      
      if dist and dist < closest_dist then
        closest_dist = dist
        closest_hit = {
          distance = dist,
          obstacle = obs
        }
      end
    end
  end
  
  return closest_hit
end

-- Line-circle intersection
-- Returns distance to intersection point, or nil if no hit
-- Ray: origin + t * direction, t in [0, max_dist]
-- Circle: center (cx, cy), radius r
function raycast.line_circle_intersection(ox, oy, dx, dy, cx, cy, r, max_dist)
  -- Vector from ray origin to circle center
  local fx = ox - cx
  local fy = oy - cy
  
  -- Quadratic coefficients: at^2 + bt + c = 0
  local a = dx * dx + dy * dy
  local b = 2 * (fx * dx + fy * dy)
  local c = fx * fx + fy * fy - r * r
  
  local discriminant = b * b - 4 * a * c
  
  if discriminant < 0 then
    return nil  -- No intersection
  end
  
  local sqrt_disc = math.sqrt(discriminant)
  local t1 = (-b - sqrt_disc) / (2 * a)
  local t2 = (-b + sqrt_disc) / (2 * a)
  
  -- Find closest valid intersection (t > 0 and t <= max_dist)
  local t = nil
  if t1 > 0 and t1 <= max_dist then
    t = t1
  elseif t2 > 0 and t2 <= max_dist then
    t = t2
  end
  
  return t
end

return raycast
