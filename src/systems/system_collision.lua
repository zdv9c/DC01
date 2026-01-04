--[[============================================================================
  SYSTEM: Collision
  
  PURPOSE: Manages HardonCollider shapes and resolves collisions with bump/slide
  
  DATA CONTRACT:
    READS:  Transform, Collider, Velocity (optional)
    WRITES: Transform, Velocity
    EMITS:  (none - could emit collision events in future)
    CONFIG: (none)
  
  UPDATE ORDER: After Movement
============================================================================]]--

local Concord = require "libs.Concord"
local HC = require "libs.HC"

local collision = Concord.system({
  pool = {"Transform", "Collider"}
})

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function collision:init()
  self.hc = HC.new()
  self.shapes = {}  -- entity -> shape mapping
  self.logfile = io.open("collision_log.txt", "w")
  if self.logfile then
    self.logfile:write("Collision system initialized\n")
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

-- Creates a shape for an entity if one doesn't exist
function collision:ensureShape(entity)
  if self.shapes[entity] then
    return self.shapes[entity]
  end
  
  local pos = entity.Transform
  local col = entity.Collider
  
  -- Create rectangle shape centered on entity position
  local shape = self.hc:rectangle(
    pos.x - col.width / 2,
    pos.y - col.height / 2,
    col.width,
    col.height
  )
  
  shape.entity = entity
  self.shapes[entity] = shape
  
  self:log(string.format("[COLLISION] Created shape for entity at (%.1f, %.1f) size %dx%d type=%s", 
    pos.x, pos.y, col.width, col.height, col.type))
  
  return shape
end

function collision:update(dt)
  -- Phase 1: Ensure shapes exist and sync with transforms
  for _, entity in ipairs(self.pool) do
    local col = entity.Collider
    col.colliding = false
    col.collision_count = 0
    
    local shape = self:ensureShape(entity)
    local pos = entity.Transform
    
    shape:moveTo(pos.x, pos.y)
  end
  
  -- Phase 2: Resolve collisions for dynamic entities
  for _, entity in ipairs(self.pool) do
    local col = entity.Collider
    local shape = self.shapes[entity]
    
    -- Only resolve for dynamic entities
    if col.type == "dynamic" and shape then
      local pos = entity.Transform
      local vel = entity.Velocity
      
      local collisions = self.hc:collisions(shape)
      
      -- Debug: count collisions
      local count = 0
      for _ in pairs(collisions) do count = count + 1 end
      if count > 0 then
        self:log(string.format("[COLLISION] Entity at (%.1f, %.1f) has %d collision(s)", pos.x, pos.y, count))
      end
      
      for other_shape, separating_vector in pairs(collisions) do
        if other_shape ~= shape then
          -- Mark both entities as colliding
          col.colliding = true
          col.collision_count = col.collision_count + 1
          
          if other_shape.entity then
            local other_col = other_shape.entity.Collider
            if other_col then
              other_col.colliding = true
              other_col.collision_count = other_col.collision_count + 1
            end
          end
          
          -- Extract current state
          local vx = vel and vel.x or 0
          local vy = vel and vel.y or 0
          
          -- Compute collision response
          local result = compute_collision_response(
            pos.x, pos.y,
            vx, vy,
            separating_vector.x, separating_vector.y
          )
          
          -- Apply separation
          shape:move(separating_vector.x, separating_vector.y)
          
          -- Write results back
          pos.x = result.px
          pos.y = result.py
          
          if vel then
            vel.x = result.vx
            vel.y = result.vy
          end
        end
      end
    end
  end
end

function collision:draw()
  -- Debug draw (commented out for performance)
  -- for _, shape in pairs(self.shapes) do
  --   shape:draw("line")
  -- end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Computes new position and velocity after collision resolution
-- Implements bump (separation) and slide (velocity projection)
-- @param px: number - current position x
-- @param py: number - current position y
-- @param vx: number - current velocity x
-- @param vy: number - current velocity y
-- @param sep_x: number - separation vector x (MTV)
-- @param sep_y: number - separation vector y (MTV)
-- @return {px, py, vx, vy: number}
function compute_collision_response(px, py, vx, vy, sep_x, sep_y)
  -- Apply separation to position
  local new_px = px + sep_x
  local new_py = py + sep_y
  
  -- Calculate collision normal from separation vector
  local normal = normalize_vector(sep_x, sep_y)
  
  -- Project velocity onto collision normal and remove that component
  -- This creates the "slide" effect
  local slide_result = project_velocity_for_slide(vx, vy, normal.x, normal.y)
  
  return {
    px = new_px,
    py = new_py,
    vx = slide_result.vx,
    vy = slide_result.vy
  }
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Normalizes a vector to unit length
-- @param x: number - vector x
-- @param y: number - vector y
-- @return {x: number, y: number}
function normalize_vector(x, y)
  local len = math.sqrt(x * x + y * y)
  if len == 0 then
    return {x = 0, y = 0}
  end
  return {x = x / len, y = y / len}
end

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
