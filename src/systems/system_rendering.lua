--[[============================================================================
  SYSTEM: Rendering
  
  PURPOSE: Draws background checkerboard and entity sprites with camera transform
  
  DATA CONTRACT:
    READS:  Transform, Sprite
    WRITES: (none - only draws)
    EMITS:  (none)
    CONFIG: camera (Gamera camera instance)
  
  UPDATE ORDER: Last (after all logic systems)
============================================================================]]--

local Concord = require "libs.Concord"

local rendering = Concord.system({
  pool = {"Transform", "Sprite"}
})

-- CONSTANTS
local TILE_SIZE = 16
local COLOR_DARK = {0.1, 0.1, 0.1}
local COLOR_LIGHT = {0.2, 0.2, 0.2}

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function rendering:init()
  -- Camera is accessed from world resources in draw
end

function rendering:draw()
  -- Get camera from world resources
  local camera = self:getWorld():getResource("camera")
  
  -- Gamera wraps all world-space rendering in a draw() callback
  if camera then
    camera:draw(function()
      self:drawCheckerboard(camera)
      self:drawEntities()
    end)
  else
    -- Fallback: draw without camera
    self:drawCheckerboard(nil)
    self:drawEntities()
  end
end

function rendering:drawCheckerboard(camera)
  local cam_x, cam_y = 0, 0
  local cam_w, cam_h = love.graphics.getDimensions()
  
  if camera then
    -- Get camera visible area in world space
    cam_x, cam_y, cam_w, cam_h = camera:getVisible()
  end
  
  -- Calculate visible tile range
  local bounds = calculate_visible_bounds(cam_x, cam_y, cam_w, cam_h, TILE_SIZE)
  
  -- Draw tiles
  for tile_x = bounds.start_x, bounds.end_x do
    for tile_y = bounds.start_y, bounds.end_y do
      local world_x = tile_x * TILE_SIZE
      local world_y = tile_y * TILE_SIZE
      
      local color = get_checkerboard_color(tile_x, tile_y)
      love.graphics.setColor(color)
      love.graphics.rectangle("fill", world_x, world_y, TILE_SIZE, TILE_SIZE)
    end
  end
end

function rendering:drawEntities()
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local sprite = entity.Sprite
    
    love.graphics.setColor(sprite.color)
    
    if sprite.type == "circle" then
      love.graphics.circle("fill", pos.x, pos.y, sprite.radius)
    else
      love.graphics.rectangle(
        "fill",
        pos.x - sprite.radius,
        pos.y - sprite.radius,
        sprite.radius * 2,
        sprite.radius * 2
      )
    end
  end
  
  love.graphics.setColor(1, 1, 1)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- No orchestrators needed - drawing is inherently imperative

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Calculates the range of tiles visible in camera bounds
-- @param cam_x: number - camera left edge world x
-- @param cam_y: number - camera top edge world y
-- @param cam_w: number - camera width
-- @param cam_h: number - camera height
-- @param tile_size: number - size of each tile
-- @return {start_x, start_y, end_x, end_y: number}
function calculate_visible_bounds(cam_x, cam_y, cam_w, cam_h, tile_size)
  return {
    start_x = math.floor(cam_x / tile_size) - 1,
    start_y = math.floor(cam_y / tile_size) - 1,
    end_x = math.ceil((cam_x + cam_w) / tile_size) + 1,
    end_y = math.ceil((cam_y + cam_h) / tile_size) + 1
  }
end

-- Returns checkerboard color for a tile based on coordinates
-- @param tile_x: number - tile x index
-- @param tile_y: number - tile y index
-- @return {r, g, b: number}
function get_checkerboard_color(tile_x, tile_y)
  if (tile_x + tile_y) % 2 == 0 then
    return COLOR_DARK
  else
    return COLOR_LIGHT
  end
end

return rendering
