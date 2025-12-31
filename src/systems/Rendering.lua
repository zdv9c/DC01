-- systems/Rendering.lua
local Concord = require "libs.Concord"

local Rendering = Concord.system({
    pool = {"Transform", "Sprite"}
})

function Rendering:init()
    -- Wishful thinking: Camera should be initialized here or passed in.
    -- For now, we'll create a simple camera functionality or assume it exists in the World.
end

function Rendering:draw()
    -- Draw Background (Infinite Checkerboard)
    -- Ideally, we use the camera bounds to only draw what's visible.
    -- For now, just filling the screen with a static grid relative to (0,0) (no camera yet)
    
    local tileSize = 16
    local width, height = love.graphics.getDimensions()
    
    -- "Infinite" checkerboard relative to screen for this first vertical slice
    -- (Actually, to show movement, it must be world relative. 
    -- We need checks for camera offset if we implement camera logic now.
    -- Let's just draw enough tiles for the screen for now, assuming (0,0) is top-left)
    
    for x = 0, width, tileSize do
        for y = 0, height, tileSize do
            -- Checkerboard pattern
            -- We need world coordinates for the checkerboard to stay fixed
            -- For now, assume screen = world
            if ((x / tileSize) + (y / tileSize)) % 2 == 0 then
                love.graphics.setColor(0.2, 0.2, 0.2) -- Grey
            else
                love.graphics.setColor(0, 0, 0) -- Black
            end
            love.graphics.rectangle("fill", x, y, tileSize, tileSize)
        end
    end
    
    -- Draw Entities
    for _, e in ipairs(self.pool) do
        local pos = e.Transform
        local sprite = e.Sprite
        
        love.graphics.setColor(sprite.color)
        if sprite.type == "circle" then
            love.graphics.circle("fill", pos.x, pos.y, sprite.radius)
        else
            love.graphics.rectangle("fill", pos.x - sprite.radius, pos.y - sprite.radius, sprite.radius*2, sprite.radius*2)
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

return Rendering
