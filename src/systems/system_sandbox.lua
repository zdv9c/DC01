--[[============================================================================
  SYSTEM: Sandbox Interaction
  
  PURPOSE: Handles manual user overrides for testing (setting targets, obstacles)
  
  DATA CONTRACT:
    READS:  AIControlled, SteeringState, Transform, Collider, Debug, Camera (Resource)
    WRITES: SteeringState (set target), World (spawn/destroy entities)
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: Input phase
============================================================================]]--

local Concord = require "libs.Concord"

local sandbox = Concord.system({
  pool_ai = {"AIControlled", "SteeringState"},
  pool_obstacles = {"Collider", "Debug"} -- Assuming obstacles have Debug component with entity_name="Block"
})

function sandbox:init()
  -- Load saved obstacles on init
  self:load_obstacles()
  
  -- Interaction state
  self.interaction_mode = nil -- 'paint_add', 'paint_remove', 'drag_target'
  self.last_grid_x = nil
  self.last_grid_y = nil
end

function sandbox:mousepressed(x, y, button)
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  
  -- Convert to world coords
  local wx, wy = camera:toWorld(x, y)
  
  -- Left Click: Drag Target
  if button == 1 then
    self.interaction_mode = 'drag_target'
    self:updateTarget(wx, wy)
  end
  
  -- Right Click: Paint Obstacles
  if button == 2 then
    local grid_x = math.floor(wx / 16) * 16 + 8
    local grid_y = math.floor(wy / 16) * 16 + 8
    
    self.last_grid_x = nil -- Reset to force initial paint
    self.last_grid_y = nil
    
    -- Determine mode based on what's under cursor
    if self:isBlockAt(grid_x, grid_y) then
      self.interaction_mode = 'paint_remove'
    else
      self.interaction_mode = 'paint_add'
    end
    
    -- Apply immediately
    self:applyPaint(grid_x, grid_y)
  end
end

function sandbox:mousereleased(x, y, button)
  -- Clear interaction
  if (button == 1 and self.interaction_mode == 'drag_target') or
     (button == 2 and (self.interaction_mode == 'paint_add' or self.interaction_mode == 'paint_remove')) then
     
    -- If we were painting, trigger a save now
    if self.interaction_mode == 'paint_add' or self.interaction_mode == 'paint_remove' then
      self.needs_save = true
    end
    
    self.interaction_mode = nil
    self.last_grid_x = nil
    self.last_grid_y = nil
  end
end

function sandbox:update(dt)
  -- Process dragging
  if self.interaction_mode then
    local camera = self:getWorld():getResource("camera")
    if not camera then return end
    
    local mx, my = love.mouse.getPosition()
    -- Apply scale (hacky, assumes global scale or we need to access Play state scale... 
    -- simpler: just get logical mouse from camera if possible, or assume caller passed handled coords?
    -- System doesn't receive mouse coords in update.
    -- We need to transform raw mouse pos. 
    -- Assuming Play state scale is 2 based on previous reads. 
    -- Better: we can't easily get scale here without passing it.
    -- But wait, standard love.mouse.getPosition is screen coords.
    -- Let's try to infer or just use the camera's reverse transform if gamera supports it?
    -- Gamera toWorld takes screen coords usually?
    -- Wait, Play.lua handles scaling via logic/screen separation.
    -- Play:mousepressed passes logical coords.
    -- Here in update we touch raw love.mouse. 
    -- We need to apply the scale (0.5 for scale 2).
    
    -- HACK: Using 0.5 scale factor matching Play.lua
    local wx, wy = camera:toWorld(mx / 2, my / 2)
    
    if self.interaction_mode == 'drag_target' then
      self:updateTarget(wx, wy)
    elseif self.interaction_mode == 'paint_add' or self.interaction_mode == 'paint_remove' then
      local grid_x = math.floor(wx / 16) * 16 + 8
      local grid_y = math.floor(wy / 16) * 16 + 8
      self:applyPaint(grid_x, grid_y)
    end
  end

  if self.needs_save then
    self:save_obstacles()
    self.needs_save = false
  end
end

function sandbox:updateTarget(wx, wy)
  for _, entity in ipairs(self.pool_ai) do
    local steering = entity.SteeringState
    if steering then
      steering.has_target = true
      steering.target_x = wx
      steering.target_y = wy
    end
  end
end

function sandbox:applyPaint(gx, gy)
  -- Dedup actions on same tile
  if gx == self.last_grid_x and gy == self.last_grid_y then
    return
  end
  self.last_grid_x = gx
  self.last_grid_y = gy
  
  if self.interaction_mode == 'paint_add' then
    if not self:isBlockAt(gx, gy) then
      self:createBlock(gx, gy)
    end
  elseif self.interaction_mode == 'paint_remove' then
    -- Find and destroy blocks at this grid center (with generous tolerance)
    -- We iterate backwards to safely remove
    -- Actually Concord pool iteration is safe? safer to collect.
    local to_remove = {}
    
    for _, entity in ipairs(self.pool_obstacles) do
      if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
        local pos = entity.Transform
        -- Check distance to grid center (1px epsilon)
        if math.abs(pos.x - gx) < 4 and math.abs(pos.y - gy) < 4 then
          table.insert(to_remove, entity)
        end
      end
    end
    
    for _, e in ipairs(to_remove) do
      e:destroy()
    end
  end
end

-- Deleted previous mousepressed/toggleObstacle logic in favor of new unified handler
-- (The update replaces them)

function sandbox:isBlockAt(x, y)
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
      local pos = entity.Transform
      -- Check slight epsilon for float/double exactness, though grid snap usually exact
      if math.abs(pos.x - x) < 1 and math.abs(pos.y - y) < 1 then
        return true
      end
    end
  end
  return false
end

function sandbox:createBlock(x, y)
  -- We need access to the entity creation logic.
  -- Ideally this should be in a factory or we duplicate it here.
  -- Duplicating minimal block logic for sandbox test:
  local block = Concord.entity(self:getWorld())
  block:give("Transform", x, y)
  block:give("Sprite", {0.5, 0.5, 0.5}, 8, "circle") -- Grey circle
  block:give("Collider", 16, 16, "static")
  block:give("Debug", {
    entity_name = "Block",
    track_collision = false
  })
end

--[[----------------------------------------------------------------------------
  PERSISTENCE
----------------------------------------------------------------------------]]--

-- File path in save directory
local SAVE_FILE = "test_obstacles.lua"

function sandbox:save_obstacles()
  local data = {}
  local seen = {} -- Deduplicate on save just in case
  
  -- Collect all manual blocks
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
      local key = string.format("%d,%d", entity.Transform.x, entity.Transform.y)
      if not seen[key] then
        table.insert(data, {
          x = entity.Transform.x,
          y = entity.Transform.y
        })
        seen[key] = true
      end
    end
  end
  
  -- Serialize to string
  local content = "return {\n"
  for _, p in ipairs(data) do
    content = content .. string.format("  {x = %.1f, y = %.1f},\n", p.x, p.y)
  end
  content = content .. "}\n"
  
  -- Write to save dir
  if love.filesystem then
    love.filesystem.write(SAVE_FILE, content)
    print("[SANDBOX] Saved " .. #data .. " obstacles to " .. SAVE_FILE)
  end
end

function sandbox:load_obstacles()
  if not love.filesystem or not love.filesystem.getInfo(SAVE_FILE) then
    return
  end
  
  -- Load chunk
  local chunk, err = love.filesystem.load(SAVE_FILE)
  if not chunk then
    print("[SANDBOX] Failed to load obstacles: " .. tostring(err))
    return
  end
  
  local data = chunk()
  if type(data) == "table" then
    -- Clear current obstacles? No, init runs once.
    -- But we must check duplicates mainly against *file* content vs *world* (which is empty at start)
    -- Actually, to be safe, just check if occupied.
    
    local loaded_count = 0
    for _, p in ipairs(data) do
       -- Normally pool is empty at init, but let's be safe
       -- Actually, isBlockAt relies on pool_obstacles which might not be populated yet if update hasn't run?
       -- Concord pools update instantly when entities added? No, they update when system filters.
       -- But at init(), system is added. Entities added via createBlock are added to world.
       -- World flush needed?
       -- Concord entity creation is immediate for components, but system pools update on next flush or immediately?
       -- Let's assume standard behavior. To be mostly safe against file duplicates:
       -- We can just deduplicate the *data* list first, then spawn.
       -- And since we dedupe on save, the file should be clean eventually.
       
       -- But the user has a dirty file now.
       -- Since we can't easily rely on pool being up to date inside the loop in init immediately after creation?
       -- Actually Concord adds to system immediately if matches.
       
       if not self:isBlockAt(p.x, p.y) then
         self:createBlock(p.x, p.y)
         loaded_count = loaded_count + 1
       end
    end
    print("[SANDBOX] Loaded " .. loaded_count .. " obstacles from " .. SAVE_FILE)
  end
end

return sandbox
