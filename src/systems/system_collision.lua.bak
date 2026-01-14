--[[============================================================================
  SYSTEM: Collision
  
  PURPOSE: Manages bump.lua collision detection and resolves collisions with slide response
  
  DATA CONTRACT:
    READS:  Transform, Collider, Velocity (optional)
    WRITES: Transform, Velocity
    EMITS:  (none - could emit collision events in future)
    CONFIG: (none)
  
  UPDATE ORDER: After Movement
============================================================================]]--

local Concord = require "libs.Concord"
local bump = require "libs.bump.bump"

local collision = Concord.system({
  pool = {"Transform", "Collider"}
})

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function collision:init()
  -- Create bump world with 16px cell size (matches tile size)
  self.bump_world = bump.newWorld(16)
  
  -- Track which entities have been added to bump world
  self.tracked_entities = {}
  
  self.logfile = io.open("collision_log.txt", "w")
  if self.logfile then
    self.logfile:write("Collision system initialized with bump.lua\n")
    self.logfile:flush()
  end
end

-- Log helper
function collision:log(msg)
  if self.logfile then
    self.logfile:write(msg .. "\n")
    self.logfile:flush()
  end
  print(msg)
end

-- Filter function for bump collisions
-- Returns collision type for each collision pair
local function collision_filter(item, other)
  -- Use "slide" response for all collisions
  -- This creates bump-and-slide behavior
  return "slide"
end

function collision:update(dt)
  -- Phase 1: Ensure all entities are added to bump world
  for _, entity in ipairs(self.pool) do
    if not self.tracked_entities[entity] then
      local pos = entity.Transform
      local col = entity.Collider
      
      -- Add entity to bump world
      self.bump_world:add(entity, 
        pos.x - col.width / 2,
        pos.y - col.height / 2,
        col.width,
        col.height)
      
      self.tracked_entities[entity] = true
      
      self:log(string.format("[COLLISION] Added entity to bump world at (%.1f, %.1f) size %dx%d type=%s", 
        pos.x, pos.y, col.width, col.height, col.type))
    end
  end
  
  -- Phase 2: Reset collision flags
  for _, entity in ipairs(self.pool) do
    local col = entity.Collider
    col.colliding = false
    col.collision_count = 0
  end
  
  -- Phase 3: Process dynamic entities with collision resolution
  for _, entity in ipairs(self.pool) do
    local col = entity.Collider
    
    if col.type == "dynamic" then
      local pos = entity.Transform
      local vel = entity.Velocity
      
      -- Calculate goal position (where entity wants to be)
      local goal_x = pos.x - col.width / 2
      local goal_y = pos.y - col.height / 2
      
      -- Use bump's move to handle collision resolution
      local actual_x, actual_y, cols, len = self.bump_world:move(
        entity, 
        goal_x, 
        goal_y, 
        collision_filter
      )
      
      -- Update position based on actual result (after collision resolution)
      pos.x = actual_x + col.width / 2
      pos.y = actual_y + col.height / 2
      
      -- Process collisions
      if len > 0 then
        self:log(string.format("[COLLISION] Entity at (%.1f, %.1f) has %d collision(s)", pos.x, pos.y, len))
        
        col.colliding = true
        col.collision_count = len
        
        -- Process velocity changes from collisions
        if vel then
          local result = compute_velocity_after_collisions(
            vel.x, vel.y,
            cols, len
          )
          
          vel.x = result.vx
          vel.y = result.vy
        end
        
        -- Mark other entities as colliding too
        for i = 1, len do
          local other = cols[i].other
          if other.Collider then
            other.Collider.colliding = true
            other.Collider.collision_count = other.Collider.collision_count + 1
          end
        end
      end
    end
  end
  
  -- Phase 4: Update static entities (no collision resolution)
  for _, entity in ipairs(self.pool) do
    local col = entity.Collider
    
    if col.type == "static" then
      local pos = entity.Transform
      
      -- Update position in bump world (no collision resolution needed)
      self.bump_world:update(
        entity,
        pos.x - col.width / 2,
        pos.y - col.height / 2
      )
    end
  end
end

function collision:draw()
  -- Debug draw (commented out for performance)
  -- Could visualize bump world cells or entity rects here
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes velocity after processing all collision normals
-- Removes velocity components that point into collision surfaces
-- @param vx: number - current velocity x
-- @param vy: number - current velocity y
-- @param cols: table - array of collision info from bump
-- @param len: number - number of collisions
-- @return {vx: number, vy: number}
function compute_velocity_after_collisions(vx, vy, cols, len)
  local result_vx = vx
  local result_vy = vy
  
  -- Process each collision's normal to adjust velocity
  for i = 1, len do
    local col = cols[i]
    local nx = col.normal.x
    local ny = col.normal.y
    
    -- Project velocity to remove component going into surface
    local projected = project_velocity_for_slide(result_vx, result_vy, nx, ny)
    result_vx = projected.vx
    result_vy = projected.vy
  end
  
  return {
    vx = result_vx,
    vy = result_vy
  }
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Projects velocity for sliding along a surface
-- Removes velocity component in the direction of the collision normal
-- @param vx: number - velocity x
-- @param vy: number - velocity y
-- @param nx: number - normal x (unit vector)
-- @param ny: number - normal y (unit vector)
-- @return {vx: number, vy: number}
function project_velocity_for_slide(vx, vy, nx, ny)
  -- Dot product of velocity and normal
  local dot = vx * nx + vy * ny
  
  -- Only remove velocity going INTO the surface (negative dot)
  if dot < 0 then
    return {
      vx = vx - dot * nx,
      vy = vy - dot * ny
    }
  end
  
  return {vx = vx, vy = vy}
end

return collision
