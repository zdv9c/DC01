--[[============================================================================
  SYSTEM: Pathfinding
  
  PURPOSE: Strategic A* navigation using Jumper
  
  DATA CONTRACT:
    READS:  Transform, Path, Collider (obstacles)
    WRITES: Path (waypoints)
    EMITS:  (none)
    CONFIG: ai_config (pathfinding settings)
  
  UPDATE ORDER: Before AI Movement
============================================================================]]--

local Concord = require("libs.Concord")
local Grid = require("libs.jumper.grid")
local Pathfinder = require("libs.jumper.pathfinder")
local AI_CONFIG = require("config.ai_config")

local pathfinding = Concord.system({
  pool = {"Path", "Transform"},
  obstacles = {"Collider", "Transform"}
})

-- Grid configuration
local TILE_SIZE = AI_CONFIG.TILE_SIZE
local MAP_WIDTH = 100 -- Default size (will expand if needed)
local MAP_HEIGHT = 100
local GRID_OFFSET_X = math.floor(MAP_WIDTH / 2)  -- Center grid around world (0,0)
local GRID_OFFSET_Y = math.floor(MAP_HEIGHT / 2)

-- Local state
local grid_object = nil
local finder_object = nil
local collision_map = nil -- 2D array [y][x] = value (0=walkable, 1=blocked)
local grid_dirty = true   -- Force rebuild on first frame

--[[----------------------------------------------------------------------------
  HELPER FUNCTIONS
----------------------------------------------------------------------------]]--

-- Convert world coordinates to grid coordinates (1-based, centered at world 0,0)
local function world_to_grid(x, y)
  return math.floor(x / TILE_SIZE) + GRID_OFFSET_X + 1,
         math.floor(y / TILE_SIZE) + GRID_OFFSET_Y + 1
end

-- Convert grid coordinates to world coordinates (center of tile)
local function grid_to_world(gx, gy)
  return (gx - GRID_OFFSET_X - 1) * TILE_SIZE + TILE_SIZE / 2,
         (gy - GRID_OFFSET_Y - 1) * TILE_SIZE + TILE_SIZE / 2
end

-- Check if a grid coordinate is blocked
local function is_grid_blocked(gx, gy)
  if gx < 1 or gx > MAP_WIDTH or gy < 1 or gy > MAP_HEIGHT then return true end
  return collision_map[gy] and collision_map[gy][gx] == 1
end

-- Check line of sight (Bresenham's line algorithm)
-- Returns true if line between (x0,y0) and (x1,y1) is clear
-- Input is in GRID coordinates
local function has_line_of_sight(x0, y0, x1, y1)
  local dx = math.abs(x1 - x0)
  local dy = -math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy
  
  while true do
    -- Check collision at current point
    if is_grid_blocked(x0, y0) then
      return false -- Blocked
    end
    
    if x0 == x1 and y0 == y1 then break end
    
    local e2 = 2 * err
    local x_changed, y_changed = false, false
    
    -- Track current position before moving
    local prev_x, prev_y = x0, y0

    if e2 >= dy then
      err = err + dy
      x0 = x0 + sx
      x_changed = true
    end
    if e2 <= dx then
      err = err + dx
      y0 = y0 + sy
      y_changed = true
    end

    -- If we moved diagonally, check if we are zipping through a diagonal gap
    -- A gap is blocked if BOTH tiles we are cutting between are occupied
    if x_changed and y_changed then
      if is_grid_blocked(prev_x + sx, prev_y) and is_grid_blocked(prev_x, prev_y + sy) then
        return false -- Squeezing through diagonal gap
      end
    end
  end
  
  return true
end

-- Check if entity can reach target via direct path (dual-ray shoulder-width check)
-- This is ONLY for deciding whether to skip A*, NOT for A* node validation
-- @param sx, sy: Start grid coordinates
-- @param ex, ey: End grid coordinates
-- @param entity_width: Entity collision width in pixels
-- @return boolean: true if both shoulder rays are clear
local function has_direct_path(sx, sy, ex, ey, entity_width)
  -- Check center ray first (fast rejection)
  if not has_line_of_sight(sx, sy, ex, ey) then
    return false
  end

  -- Calculate perpendicular offset in grid units
  -- entity_width is in pixels, divide by TILE_SIZE to get grid offset
  local offset_tiles = math.ceil(entity_width / TILE_SIZE / 2)

  -- Direction vector (grid space)
  local dx = ex - sx
  local dy = ey - sy
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 0.1 then return true end  -- Same tile

  -- Normalized direction
  local dir_x = dx / dist
  local dir_y = dy / dist

  -- Perpendicular vector (rotated 90 degrees)
  local perp_x = -dir_y
  local perp_y = dir_x

  -- Two shoulder ray start points (offset by entity half-width)
  local s1x = math.floor(sx + perp_x * offset_tiles)
  local s1y = math.floor(sy + perp_y * offset_tiles)
  local s2x = math.floor(sx - perp_x * offset_tiles)
  local s2y = math.floor(sy - perp_y * offset_tiles)

  -- Check both shoulder rays
  local ray1_clear = has_line_of_sight(s1x, s1y, ex, ey)
  local ray2_clear = has_line_of_sight(s2x, s2y, ex, ey)

  return ray1_clear and ray2_clear
end

-- Smooth a path by removing redundant waypoints (Theta* style post-processing)
local function smooth_path(nodes)
  if #nodes <= 2 then return nodes end
  
  local smoothed = {nodes[1]}
  local current_idx = 1
  
  while current_idx < #nodes do
    local next_idx = current_idx + 1
    
    -- Try to connect to furthest visible node
    for i = #nodes, current_idx + 2, -1 do
      local p1 = nodes[current_idx]
      local p2 = nodes[i]
      
      -- Convert to grid coords for LOS check
      local gx1, gy1 = world_to_grid(p1.x, p1.y)
      local gx2, gy2 = world_to_grid(p2.x, p2.y)
      
      if has_line_of_sight(gx1, gy1, gx2, gy2) then
        next_idx = i
        break
      end
    end
    
    table.insert(smoothed, nodes[next_idx])
    current_idx = next_idx
  end
  
  return smoothed
end

-- Rebuild collision grid from static obstacles
-- NOTE: In a real game, you might load this from a map file or update incrementally
function pathfinding:rebuild_grid()
  local obstacles_list = self.obstacles

  -- 1. Initialize empty map
  collision_map = {}
  for y = 1, MAP_HEIGHT do
    collision_map[y] = {}
    for x = 1, MAP_WIDTH do
      collision_map[y][x] = 0 -- Walkable
    end
  end
  
  -- Cache positions to detect movement later
  self.obstacle_cache = {}
  
  -- 2. Mark obstacles
  for _, entity in ipairs(obstacles_list) do
    -- Only add static obstacles to the pathfinding grid
    -- Dynamic entities (like other agents) are handled by CBS local avoidance
    local col = entity.Collider
    if col and col.type == "static" then
      local pos = entity.Transform
      
      -- Cache for movement detection
      self.obstacle_cache[entity] = {x = pos.x, y = pos.y}
      
      -- Convert obstacle bounds to grid tiles with small epsilon to prevent edge bleeding
      -- This ensures a 16px block aligned to grid only occupies 1 tile
      local margin = 0.1
      local min_x, min_y = world_to_grid(pos.x - col.width/2 + margin, pos.y - col.height/2 + margin)
      local max_x, max_y = world_to_grid(pos.x + col.width/2 - margin, pos.y + col.height/2 - margin)
      
      -- Clamp to map bounds
      min_x = math.max(1, min_x); max_x = math.min(MAP_WIDTH, max_x)
      min_y = math.max(1, min_y); max_y = math.min(MAP_HEIGHT, max_y)
      
      for y = min_y, max_y do
        for x = min_x, max_x do
          collision_map[y][x] = 1 -- Blocked
        end
      end
    end
  end
  
  -- 3. Create Jumper objects
  grid_object = Grid(collision_map)
  finder_object = Pathfinder(grid_object, 'JPS', 0) -- Jump Point Search, walkable=0
  
  -- Prevent corner cutting for safer movement
  finder_object:setMode('ORTHOGONAL')
  
  -- Increment version so agents know to update
  self.grid_version = self.grid_version + 1
  print("[Pathfinding] Grid Rebuilt. Version: " .. self.grid_version)
end

--[[----------------------------------------------------------------------------
  SYSTEM FUNCTIONS
----------------------------------------------------------------------------]]--

function pathfinding:init()
  self.grid_dirty = true
  self.grid_version = 0
  self.obstacle_cache = {}
  
  -- Manually wire up the 'obstacles' pool callbacks
  -- Concord only calls system:entityAdded for the PRIMARY pool (pool)
  -- For secondary pools (obstacles), we must attach handlers directly.
  
  self.obstacles.onAdded = function(pool, entity)
    if entity.Collider and entity.Collider.type == "static" then
      print("[Pathfinding] Static Obstacle Added (Pool Hook)")
      self.grid_dirty = true
    end
  end
  
  self.obstacles.onRemoved = function(pool, entity)
    if entity.Collider and entity.Collider.type == "static" then
      print("[Pathfinding] Static Obstacle Removed (Pool Hook)")
      self.grid_dirty = true
    end
  end
end

-- Force a manual rebuild (call this if a static object moves)
function pathfinding:force_rebuild()
  self.grid_dirty = true
end

-- Prunes waypoints that the agent is already past
-- @param waypoints: table - list of waypoints {x, y}
-- @param pos: {x, y} - agent current position
-- @param reached_threshold: number - distance to consider waypoint reached
-- Finds the furthest reachable waypoint via Line of Sight
-- This ensures the agent always targets the furthest clear point, 
-- which stabilizes movement and prevents stuttering on recalculations.
-- @param waypoints: table - list of waypoints {x, y}
-- @param pos: {x, y} - agent current position
-- @return table - pruned waypoints starting with the best target
function prune_initial_waypoints(waypoints, pos)
  if #waypoints == 0 then return {} end
  
  -- Convert agent to grid for LOS checks
  local gx, gy = world_to_grid(pos.x, pos.y)
  
  -- Find the furthest waypoint we have LOS to
  local furthest_idx = 1
  -- We can skip nodes 1 to N if we have LOS to N.
  -- Nodes are already corners from smooth_path, so this just skips "reached" or "visible-behind" corners.
  for i = #waypoints, 1, -1 do
    local wp = waypoints[i]
    local gwx, gwy = world_to_grid(wp.x, wp.y)
    
    if has_line_of_sight(gx, gy, gwx, gwy) then
      furthest_idx = i
      break
    end
  end
  
  -- Create the new pruned list starting from that furthest visible point
  local pruned = {}
  for i = furthest_idx, #waypoints do
    table.insert(pruned, {x = waypoints[i].x, y = waypoints[i].y})
  end
  
  return pruned
end


function pathfinding:update(dt)
  -- Lazy init or dirty rebuild
  if self.grid_dirty and #self.obstacles > 0 then
    self:rebuild_grid()
    self.grid_dirty = false
    -- print("[Pathfinding] Grid rebuilt (Creation/Destruction)")
  end
  
  if not finder_object then return end -- No grid yet
  
  if not finder_object then return end -- No grid yet
  
  for _, entity in ipairs(self.pool) do
    local path = entity.Path
    local pos = entity.Transform
    local state = entity.CBSBehaviorState

    -- ONLY pathfind when in pathfind state
    if state and state.current ~= "pathfind" then
      goto continue
    end

    -- Sync with target entity if it exists
    if path.target_entity and path.target_entity.Transform then
      if not path.final_target then path.final_target = {x=0, y=0} end
      path.final_target.x = path.target_entity.Transform.x
      path.final_target.y = path.target_entity.Transform.y
    end
    
    -- Only proceed if we have a valid destination
    if path.final_target then
      -- Check if we need to refresh the path
      path.refresh_timer = path.refresh_timer + dt
      
      local needs_refresh = false
      
      -- 1. Version check (map changed)
      if path.grid_version ~= self.grid_version then
        needs_refresh = true
      end
      
      -- 2. Timer check for retries (if path failed or is old)
      -- Keeping a SLOW timer just in case an agent gets stuck is usually good practice,
      -- but per user request, we are relying on events.
      -- However, if target MOVES, we still need to update.

      
      -- 2. Target movement check
      local dx = path.final_target.x - path.last_target_pos.x
      local dy = path.final_target.y - path.last_target_pos.y
      local move_threshold = AI_CONFIG.pathfinding.target_move_threshold * TILE_SIZE
      if dx*dx + dy*dy > move_threshold * move_threshold then
        needs_refresh = true
      end
      
      -- 3. Timer check (Periodic refresh)
      if path.refresh_timer > AI_CONFIG.pathfinding.refresh_interval then
         needs_refresh = true
      end
      
      -- If refresh needed, run A*
      if needs_refresh then
        path.refresh_timer = 0
        path.last_target_pos.x = path.final_target.x
        path.last_target_pos.y = path.final_target.y
        path.grid_version = self.grid_version
        
        -- Start and goal in grid coords
        local sx, sy = world_to_grid(pos.x, pos.y)
        local ex, ey = world_to_grid(path.final_target.x, path.final_target.y)

        -- Check if direct path exists (dual-ray shoulder-width LOS)
        local entity_width = entity.Collider and entity.Collider.width or 16
        local direct_path_clear = has_direct_path(sx, sy, ex, ey, entity_width)

        -- Bound checks & A*
        if collision_map[sy] and collision_map[sy][sx] and collision_map[ey] and collision_map[ey][ex] then
          if direct_path_clear then
            -- Skip A* - use direct waypoint
            path.waypoints = {{x = path.final_target.x, y = path.final_target.y}}
            path.is_valid = true
            path.is_finished = false
            path.current_index = 1
          else
            -- Run A* normally
            -- Jumper returns a path iterator, or nil
            local path_obj = finder_object:getPath(sx, sy, ex, ey)
          
          if path_obj then
            path.waypoints = {}
            path.current_index = 1
            path.is_valid = true
            path.is_finished = false
            
            -- Convert nodes to world waypoints
            local nodes = {}
            for node, count in path_obj:nodes() do
              local wx, wy = grid_to_world(node:getX(), node:getY())
              table.insert(nodes, {x = wx, y = wy})
            end
            
            -- Apply smoothing
            local smoothed = smooth_path(nodes)
            
            -- Prune waypoints we are already past to prevent "snap-back" jerks
            path.waypoints = prune_initial_waypoints(smoothed, pos)
               
            if AI_CONFIG.debug.log_pathfinding then
               print(string.format("[Pathfinding] Found path with %d nodes (smoothed to %d)", 
                 path_obj:getLength(), #path.waypoints))
            end
          else
            -- Path search failed (blocked or unreachable)
            -- Clear existing waypoints so we don't visualize/follow stale path
            path.waypoints = {} 
            path.current_index = 1
            path.is_valid = false
            
            if AI_CONFIG.debug.log_pathfinding then
              print("[Pathfinding] NO PATH found from ("..sx..","..sy..") to ("..ex..","..ey..")")
            end
          end
          end  -- End of A* else branch
        else
          -- Start or end is out of bounds
          path.is_valid = false
        end
      end
    else
      -- No target, ensure path invalid
      path.waypoints = {}
      path.is_valid = false
    end

    ::continue::
  end
end

return pathfinding
