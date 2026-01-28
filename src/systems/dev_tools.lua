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

local dev_tools = Concord.system({
  pool_ai = {"AIControlled", "SteeringState", "Path"},
  pool_obstacles = {"Collider", "Debug"},
  pool_player = {"PlayerControlled", "Transform"}
})

-- Persistence constants
local SAVE_FILE = "test_obstacles.lua"

function dev_tools:init()
  self:load_obstacles()
  self.interaction_mode = nil
  self.last_grid_x = nil
  self.last_grid_y = nil
end

function dev_tools:keypressed(key)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end
  
  if key == "delete" then
    self:clear_all_obstacles()
  end
end

function dev_tools:mousepressed(x, y, button)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end
  
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  
  local wx, wy = camera:toWorld(x, y)
  
  if button == 1 then
    self.interaction_mode = 'drag_target'
    self:update_ai_targets(wx, wy)
  elseif button == 2 then
    local grid_x, grid_y = self:snap_to_grid(wx, wy)
    self.interaction_mode = self:is_block_at(grid_x, grid_y) and 'paint_remove' or 'paint_add'
    self:apply_paint(grid_x, grid_y)
  end
end

function dev_tools:mousereleased(x, y, button)
  if self.interaction_mode then
    if self.interaction_mode == 'paint_add' or self.interaction_mode == 'paint_remove' then
      self:save_obstacles()
    end
    self.interaction_mode = nil
  end
end

function dev_tools:update(dt)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode or not self.interaction_mode then return end
  
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  
  local mx, my = love.mouse.getPosition()
  local wx, wy = camera:toWorld(mx / 2, my / 2) -- Assumes scale=2 from Play.lua
  
  if self.interaction_mode == 'drag_target' then
    self:update_ai_targets(wx, wy)
  else
    local gx, gy = self:snap_to_grid(wx, wy)
    self:apply_paint(gx, gy)
  end
end

--[[----------------------------------------------------------------------------
  INTERACTION LOGIC
----------------------------------------------------------------------------]]--

function dev_tools:update_ai_targets(wx, wy)
  -- Check if we clicked on a player
  local player_to_follow = nil
  for _, player in ipairs(self.pool_player) do
    local pos = player.Transform
    -- Check distance (simple radius check, assuming 8px radius like in Play.lua)
    local dx, dy = pos.x - wx, pos.y - wy
    if dx*dx + dy*dy < 12*12 then -- 12px tolerance
      player_to_follow = player
      break
    end
  end

  for _, entity in ipairs(self.pool_ai) do
    local path = entity.Path
    if path then
      path.target_entity = player_to_follow
      if not player_to_follow then
        path.final_target.x, path.final_target.y = wx, wy
      end
      path.refresh_timer = 100 -- Force refresh
    end
    local steering = entity.SteeringState
    if steering then
      steering.has_target = true
      if player_to_follow then
        steering.target_x, steering.target_y = player_to_follow.Transform.x, player_to_follow.Transform.y
      else
        steering.target_x, steering.target_y = wx, wy
      end
    end
  end
  
  if player_to_follow then
    print("[DEV] NPC now following Player")
  end
end

function dev_tools:apply_paint(gx, gy)
  if gx == self.last_grid_x and gy == self.last_grid_y then return end
  self.last_grid_x, self.last_grid_y = gx, gy
  
  if self.interaction_mode == 'paint_add' then
    if not self:is_block_at(gx, gy) then self:create_block(gx, gy) end
  elseif self.interaction_mode == 'paint_remove' then
    self:remove_block_at(gx, gy)
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

function dev_tools:create_block(x, y)
  local block = Concord.entity(self:getWorld())
  block:give("Transform", x, y)
  block:give("Sprite", {0.5, 0.5, 0.5}, 8, "circle")
  block:give("Collider", 16, 16, "static")
  block:give("Debug", { entity_name = "Block", track_collision = false })
end

function dev_tools:remove_block_at(gx, gy)
  for _, entity in ipairs(self.pool_obstacles) do
    if entity.Debug and entity.Debug.entity_name == "Block" and entity.Transform then
      local pos = entity.Transform
      if math.abs(pos.x - gx) < 4 and math.abs(pos.y - gy) < 4 then
        entity:destroy()
        return
      end
    end
  end
end

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
    for _, p in ipairs(data) do
      if not self:is_block_at(p.x, p.y) then self:create_block(p.x, p.y) end
    end
  end
end

return dev_tools
