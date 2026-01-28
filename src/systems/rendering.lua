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
      self:drawEntities()
    end)
  else
    -- Fallback: draw without camera
    self:drawEntities()
  end
end

function rendering:drawEntities()
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local sprite = entity.Sprite
    
    love.graphics.setColor(sprite.color)
    
    if sprite.type == "circle" then
      -- If entity has steering, draw as directional triangle/arrow
      if entity.SteeringState then
        local st = entity.SteeringState
        local angle = math.atan2(st.forward_y or 0, st.forward_x or 1)
        local r = sprite.radius
        
        love.graphics.push()
        love.graphics.translate(pos.x, pos.y)
        love.graphics.rotate(angle)
        
        -- Draw Arrow/Triangle pointing Right (0 rad)
        -- Tip at `r`, broad base at `-r`
        love.graphics.polygon("fill",
           r, 0,           -- Nose
          -r, -r * 0.8,    -- Top Tail
          -r * 0.5, 0,     -- Inner Notch
          -r,  r * 0.8     -- Bottom Tail
        )
        love.graphics.pop()
      else
        -- Fallback to circle
        love.graphics.circle("fill", pos.x, pos.y, sprite.radius)
      end
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

return rendering
