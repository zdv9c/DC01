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

-- Local state
local grid_object = nil
local finder_object = nil
local collision_map = nil -- 2D array [y][x] = value (0=walkable, 1=blocked)
local grid_dirty = true   -- Force rebuild on first frame

--[[----------------------------------------------------------------------------
  HELPER FUNCTIONS
----------------------------------------------------------------------------]]--

-- Convert world coordinates to grid coordinates (1-based)
local function world_to_grid(x, y)
  return math.floor(x / TILE_SIZE) + 1, math.floor(y / TILE_SIZE) + 1
end

-- Convert grid coordinates to world coordinates (center of tile)
local function grid_to_world(gx, gy)
  return (gx - 1) * TILE_SIZE + TILE_SIZE / 2, (gy - 1) * TILE_SIZE + TILE_SIZE / 2
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
    if x0 >= 1 and x0 <= MAP_WIDTH and y0 >= 1 and y0 <= MAP_HEIGHT then
      if collision_map[y0] and collision_map[y0][x0] == 1 then
        return false -- Blocked
      end
    end
    
    if x0 == x1 and y0 == y1 then break end
    
    local e2 = 2 * err
    if e2 >= dy then
      err = err + dy
      x0 = x0 + sx
    end
    if e2 <= dx then
      err = err + dx
      y0 = y0 + sy
    end
  end
  
  return true
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
      local min_x = math.floor((pos.x - col.width/2 + margin) / TILE_SIZE) + 1
      local max_x = math.floor((pos.x + col.width/2 - margin) / TILE_SIZE) + 1
      local min_y = math.floor((pos.y - col.height/2 + margin) / TILE_SIZE) + 1
      local max_y = math.floor((pos.y + col.height/2 - margin) / TILE_SIZE) + 1
      
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
end

--[[----------------------------------------------------------------------------
  SYSTEM FUNCTIONS
----------------------------------------------------------------------------]]--

function pathfinding:init()
  self.grid_dirty = true
  self.obstacle_cache = {}
end

-- Robust integrity check: Detects New, Moved, and Removed obstacles
function pathfinding:check_static_integrity()
  local current_lookup = {}
  
  -- 1. Check for New or Moved obstacles
  for _, entity in ipairs(self.obstacles) do
    -- Mark as present
    current_lookup[entity] = true
    
    if entity.Collider and entity.Collider.type == "static" then
       local pos = entity.Transform
       local cached = self.obstacle_cache[entity]
       
       -- Check if New (uncached)
       if not cached then
         return true 
       end
       
       -- Check if Moved
       if math.abs(pos.x - cached.x) > 0.1 or math.abs(pos.y - cached.y) > 0.1 then
         return true
       end
    end
  end
  
  -- 2. Check for Removed obstacles
  -- If it's in cache but not in current obstacles list, it was removed
  for entity, _ in pairs(self.obstacle_cache) do
    if not current_lookup[entity] then
      return true
    end
  end
  
  return false
end

function pathfinding:update(dt)
  -- Lazy init or dirty rebuild
  if self.grid_dirty and #self.obstacles > 0 then
    self:rebuild_grid()
    self.grid_dirty = false
    -- print("[Pathfinding] Grid rebuilt (Creation/Destruction)")
  end
  
  if not finder_object then return end -- No grid yet
  
  local any_pathfinding_needed = false
  
  -- First pass: Check if any agent needs pathfinding
  for _, entity in ipairs(self.pool) do
     -- (Logic to check refresh timer/threshold without resetting it yet)
     -- Easier: copy logic or just loop
     local path = entity.Path
     
     -- Check timer
     if path.refresh_timer + dt >= AI_CONFIG.pathfinding.refresh_interval then
       any_pathfinding_needed = true
       break
     end
     
     -- Check movement (approximate, since we don't have new dt added to timer yet, but it's close)
     if path.final_target then
       local dx = path.final_target.x - path.last_target_pos.x
       local dy = path.final_target.y - path.last_target_pos.y
       if dx*dx + dy*dy > (AI_CONFIG.pathfinding.target_move_threshold * TILE_SIZE)^2 then
         any_pathfinding_needed = true
         break
       end
     end
  end
  
  -- Lazy Integrity Check: Only start scanning static blocks if we are about to pathfind
  if any_pathfinding_needed then
     if self:check_static_integrity() then
        self:rebuild_grid()
        self.grid_dirty = false -- Clear flag
        -- print("[Pathfinding] Grid rebuilt (Movement detected)")
     end
  end

  
  if not finder_object then return end -- No grid yet
  
  for _, entity in ipairs(self.pool) do
    local path = entity.Path
    local pos = entity.Transform
    
    -- Check if we need to refresh the path
    path.refresh_timer = path.refresh_timer + dt
    
    local needs_refresh = false
    
    -- 1. Timer check
    if path.refresh_timer >= AI_CONFIG.pathfinding.refresh_interval then
      needs_refresh = true
    end
    
    -- 2. Target movement check
    local dx = path.final_target.x - path.last_target_pos.x
    local dy = path.final_target.y - path.last_target_pos.y
    local dist_sq = dx*dx + dy*dy
    local threshold = AI_CONFIG.pathfinding.target_move_threshold * TILE_SIZE
    
    if dist_sq > threshold * threshold then
      needs_refresh = true
    end
    
    -- If refresh needed, run A*
    if needs_refresh then
      path.refresh_timer = 0
      path.last_target_pos.x = path.final_target.x
      path.last_target_pos.y = path.final_target.y
      
      -- Start and goal in grid coords
      local sx, sy = world_to_grid(pos.x, pos.y)
      local ex, ey = world_to_grid(path.final_target.x, path.final_target.y)
      
      -- Bound checks
      if collision_map[sy] and collision_map[sy][sx] and collision_map[ey] and collision_map[ey][ex] then
        -- Find path
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
          path.waypoints = smooth_path(nodes)
             
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
      else
        -- Start or end is out of bounds
        path.is_valid = false
      end
    end
  end
end

return pathfinding
