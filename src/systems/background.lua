--[[============================================================================
  SYSTEM: Background
  
  PURPOSE: Draws the background checkerboard
============================================================================]]--

local Concord = require "libs.Concord"

local background = Concord.system({})

local TILE_SIZE = 16
local COLOR_DARK = {0.1, 0.1, 0.1}
local COLOR_LIGHT = {0.2, 0.2, 0.2}

function background:draw()
  local camera = self:getWorld():getResource("camera")
  if camera then
    camera:draw(function()
      local cam_x, cam_y, cam_w, cam_h = camera:getVisible()
      
      local start_x = math.floor(cam_x / TILE_SIZE) - 1
      local start_y = math.floor(cam_y / TILE_SIZE) - 1
      local end_x = math.ceil((cam_x + cam_w) / TILE_SIZE) + 1
      local end_y = math.ceil((cam_y + cam_h) / TILE_SIZE) + 1
      
      for tile_x = start_x, end_x do
        for tile_y = start_y, end_y do
          if (tile_x + tile_y) % 2 == 0 then
            love.graphics.setColor(COLOR_DARK)
          else
            love.graphics.setColor(COLOR_LIGHT)
          end
          love.graphics.rectangle("fill", tile_x * TILE_SIZE, tile_y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
        end
      end
    end)
  end
end

return background
