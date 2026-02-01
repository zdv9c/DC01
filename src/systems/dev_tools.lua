--[[============================================================================
  SYSTEM: Dev Tools
  
  PURPOSE: Interaction system for developers. Handles setting targets and
           painting/deleting obstacles.
  
  DATA CONTRACT:
    READS:  AIControlled, SteeringState, Transform, Collider, Debug, Path, (world resource: camera, dev_mode)
    WRITES: SteeringState (set target), World (spawn/destroy entities)
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: Input phase
============================================================================]]--

local Concord = require "libs.Concord"
local Slab = require "libs.Slab"
local lume = require "libs.lume.lume"

local dev_tools = Concord.system({
  pool_ai = {"AIControlled"},
  pool_player = {"PlayerControlled"},
  pool_obstacles = {"Collider", "Debug"}
})

-- Persistence constants
local SAVE_FILE = "test_obstacles.lua"
-- Entity Factories
local Factories = {
  Block = require "entities.obstacle",
  NPC = require "entities.test_npc",
  Zombie = require "entities.zombie"
}

function dev_tools:init()
  self:load_obstacles()
  self.interaction_state = nil -- 'drag_target', 'painting', etc.
  self.last_grid_x = nil
  self.last_grid_y = nil
  
  self.last_click_time = 0
  self.double_click_threshold = 0.3
end

function dev_tools:keypressed(key)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end
  
  if key == "delete" then
    self:clear_all_obstacles()
  end
end

function dev_tools:mousepressed(x, y, button)
  local tool = self:getWorld():getResource("debug_tool")
  local dev_mode = self:getWorld():getResource("dev_mode")
  
  if not dev_mode or not tool or tool.mode == "none" or not Slab.IsVoidHovered() then return end
  
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  local wx, wy = camera:toWorld(x, y)
  
  if tool.mode == "select" then
    if button == 1 then -- Left Click: Select / Drag / Double-Click
      local now = love.timer.getTime()
      if now - self.last_click_time < self.double_click_threshold then
        local actor = self:find_actor_at(wx, wy)
        if actor then
          self:select_all_of_same_type(actor)
          self.interaction_state = nil
          self.last_click_time = 0
          return
        end
      end
      self.last_click_time = now

      local box = self:getWorld():getResource("debug_selection_box")
      box.active = true
      box.x1, box.y1 = wx, wy
      box.x2, box.y2 = wx, wy
      self.interaction_state = 'selecting'
    elseif button == 2 then -- Right Click: Target (with drag support)
      self:set_target_at(wx, wy)
      self.interaction_state = 'drag_target'
    end
  
  elseif tool.mode == "paint" then
    local grid_x, grid_y = self:snap_to_grid(wx, wy)
    
    if button == 1 then -- Left Click: Paint Add
      self.interaction_state = 'paint_add'
      self:apply_paint(grid_x, grid_y, tool.paint_type)
    elseif button == 2 then -- Right Click: Paint Remove
      self.interaction_state = 'paint_remove'
      -- self:remove_entity_at(wx, wy) REPLACED by apply_paint_remove below
      -- For consistency with previous behavior, let's stick to simple removal
      -- But wait, previous behavior was block specific. Now we have generic entities.
      -- Let's stick to grid-based block removal for now, or radius removal for entities.
      self:apply_paint_remove(wx, wy)
    end
  end
end

function dev_tools:mousereleased(x, y, button)
  if self.interaction_state == 'selecting' then
    local box = self:getWorld():getResource("debug_selection_box")
    self:select_entities_in_box(box)
    box.active = false
  end

  if self.interaction_state then
    if self.interaction_state == 'paint_add' or self.interaction_state == 'paint_remove' then
      self:save_obstacles()
    end
    self.interaction_state = nil
    self.last_grid_x = nil
    self.last_grid_y = nil
  end
end

function dev_tools:update(dt)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode or not self.interaction_state then return end
  
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  
  local mx, my = love.mouse.getPosition()
  local wx, wy = camera:toWorld(mx / 2, my / 2) -- Assumes scale=2 from Play.lua
  
  local tool = self:getWorld():getResource("debug_tool")
  
  if self.interaction_state == 'paint_add' then
    local gx, gy = self:snap_to_grid(wx, wy)
    self:apply_paint(gx, gy, tool.paint_type)
  elseif self.interaction_state == 'paint_remove' then
    self:apply_paint_remove(wx, wy)
  elseif self.interaction_state == 'drag_target' then
    self:set_target_at(wx, wy)
  elseif self.interaction_state == 'selecting' then
    local box = self:getWorld():getResource("debug_selection_box")
    box.x2, box.y2 = wx, wy
  end
end

--[[----------------------------------------------------------------------------
  INTERACTION LOGIC
----------------------------------------------------------------------------]]--

function dev_tools:select_entities_in_box(box)
  local selection = self:getWorld():getResource("debug_selection")
  local x_min, x_max = math.min(box.x1, box.x2), math.max(box.x1, box.x2)
  local y_min, y_max = math.min(box.y1, box.y2), math.max(box.y1, box.y2)
  
  -- Small threshold for single clicks
  local is_single = math.abs(box.x1 - box.x2) < 4 and math.abs(box.y1 - box.y2) < 4
  
  local touched_entities = {}
  
  -- Search relevant pools
  local candidates = {}
  for _, e in ipairs(self.pool_ai) do table.insert(candidates, e) end
  for _, e in ipairs(self.pool_player) do table.insert(candidates, e) end
  
  if is_single then
    -- Traditional proximity check for single click
    local best = self:find_actor_at(box.x1, box.y1)
    if best then table.insert(touched_entities, best) end
  else
    -- AABB check for box selection
    for _, entity in ipairs(candidates) do
      local pos = entity.Transform
      if pos.x >= x_min and pos.x <= x_max and pos.y >= y_min and pos.y <= y_max then
        table.insert(touched_entities, entity)
      end
    end
  end
  
  -- Handle Modifiers
  local shift = love.keyboard.isDown('lshift', 'rshift')
  local ctrl = love.keyboard.isDown('lctrl', 'rctrl')
  
  if shift then
    -- Additive
    for _, e in ipairs(touched_entities) do
      if not lume.find(selection.entities, e) then
        table.insert(selection.entities, e)
      end
    end
  elseif ctrl then
    -- Toggle
    for _, e in ipairs(touched_entities) do
      local idx = lume.find(selection.entities, e)
      if idx then
        table.remove(selection.entities, idx)
      else
        table.insert(selection.entities, e)
      end
    end
  else
    -- Normal Selection (Replace)
    selection.entities = touched_entities
  end
  
  print("[DEV] Selection updated: " .. #selection.entities .. " entities")
end

function dev_tools:set_target_at(wx, wy)
  local selection = self:getWorld():getResource("debug_selection")
  
  -- Check if clicking on another actor (to follow)
  local target_entity = self:find_actor_at(wx, wy)

  for _, entity in ipairs(selection.entities) do
    if entity.Path then
      entity.Path.target_entity = target_entity
      if not target_entity then
        if not entity.Path.final_target then entity.Path.final_target = {} end
        entity.Path.final_target.x, entity.Path.final_target.y = wx, wy
      end
      entity.Path.refresh_timer = 100 -- Force refresh
    end
  end
  print("[DEV] Target set for " .. #selection.entities .. " entities. Target Entity: " .. tostring(target_entity))
end

function dev_tools:find_actor_at(wx, wy)
  local candidates = {}
  for _, e in ipairs(self.pool_ai) do table.insert(candidates, e) end
  for _, e in ipairs(self.pool_player) do table.insert(candidates, e) end
  
  local best = nil
  local min_dist = 16
  for _, entity in ipairs(candidates) do
    local pos = entity.Transform
    if pos then
      local dx, dy = pos.x - wx, pos.y - wy
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist < min_dist then
        min_dist = dist
        best = entity
      end
    end
  end
  return best
end

function dev_tools:select_all_of_same_type(actor)
  local debug = actor.Debug
  if not debug or not debug.entity_name then return end
  
  local target_type = debug.entity_name
  local selection = self:getWorld():getResource("debug_selection")
  local camera = self:getWorld():getResource("camera")
  
  -- Screen bounds in world space
  local l, t, w, h = camera:getVisible()
  local r, b = l + w, t + h
  
  local candidates = {}
  for _, e in ipairs(self.pool_ai) do table.insert(candidates, e) end
  for _, e in ipairs(self.pool_player) do table.insert(candidates, e) end
  
  local new_selection = {}
  for _, e in ipairs(candidates) do
    if e.Debug and e.Debug.entity_name == target_type then
      local pos = e.Transform
      if pos and pos.x >= l and pos.x <= r and pos.y >= t and pos.y <= b then
        table.insert(new_selection, e)
      end
    end
  end
  
  selection.entities = new_selection
  print("[DEV] Double-click: Selected all " .. target_type .. " on screen (" .. #new_selection .. ")")
end

function dev_tools:apply_paint(gx, gy, type_name)
  if gx == self.last_grid_x and gy == self.last_grid_y then return end
  self.last_grid_x, self.last_grid_y = gx, gy
  
  -- Avoid stacking
  if type_name == "Block" then
    if self:is_block_at(gx, gy) then return end
  else
     -- For non-blocks, check crude distance to avoid infinite stack in one frame
     -- Actually, applying paint every frame for NPCs is bad. They should probably be single-click spawn.
     -- But let's leave as drag-paint for fun, but maybe throttle?
     -- Or just check if we have ANY entity close by?
  end
  
  self:create_entity(gx, gy, type_name)
end

function dev_tools:apply_paint_remove(wx, wy)
  -- Remove anything close to mouse
  for _, entity in ipairs(self.pool_obstacles) do
     local pos = entity.Transform
     if pos and math.abs(pos.x - wx) < 8 and math.abs(pos.y - wy) < 8 then
       entity:destroy()
     end
  end
  -- Also check AI pool for removal
   for _, entity in ipairs(self.pool_ai) do
     local pos = entity.Transform
     if pos and math.abs(pos.x - wx) < 8 and math.abs(pos.y - wy) < 8 then
       entity:destroy()
     end
  end
end

function dev_tools:clear_all_obstacles()
  local to_destroy = {}
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" then
      table.insert(to_destroy, entity)
    end
  end
  for _, entity in ipairs(to_destroy) do entity:destroy() end
  print("[DEV] Cleared obstacles.")
  self:save_obstacles()
end

--[[----------------------------------------------------------------------------
  UTILITIES & PERSISTENCE
----------------------------------------------------------------------------]]--

function dev_tools:snap_to_grid(x, y)
  return math.floor(x / 16) * 16 + 8, math.floor(y / 16) * 16 + 8
end

function dev_tools:is_block_at(x, y)
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
      local pos = entity.Transform
      if math.abs(pos.x - x) < 1 and math.abs(pos.y - y) < 1 then return true end
    end
  end
  return false
end

function dev_tools:create_entity(x, y, type_name)
  local factory = Factories[type_name]
  if factory then
    local entity = Concord.entity(self:getWorld())
    factory(entity, x, y)
  end
end

-- Legacy block removal removed in favor of generic apply_paint_remove above
-- Keeping is_block_at for block-specific logic if needed

function dev_tools:save_obstacles()
  if not love.filesystem then return end
  local data = {}
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
      table.insert(data, {x = entity.Transform.x, y = entity.Transform.y})
    end
  end
  local content = "return {\n"
  for _, p in ipairs(data) do content = content .. string.format("  {x = %.1f, y = %.1f},\n", p.x, p.y) end
  content = content .. "}\n"
  love.filesystem.write(SAVE_FILE, content)
end

function dev_tools:load_obstacles()
  if not love.filesystem or not love.filesystem.getInfo(SAVE_FILE) then return end
  local chunk = love.filesystem.load(SAVE_FILE)
  if not chunk then return end
  local data = chunk()
  if type(data) == "table" then
  if type(data) == "table" then
    for _, p in ipairs(data) do
      if not self:is_block_at(p.x, p.y) then self:create_entity(p.x, p.y, "Block") end
    end
  end
  end
end

return dev_tools
