-- main.lua
-- Entry point for the application.
-- Delegates callbacks to the active Gamestate.

-- 1. Setup paths (if needed, though libs/ is standard)
-- package.path = package.path .. ";libs/?.lua;libs/?/init.lua"

-- 2. Load globally required libraries (optional, but convenient for some)
-- local Gamestate = require "libs.hump.gamestate"

-- 3. Load States
local Gamestate = require "libs.hump.gamestate"
local Play = require "states.Play"

function love.load()
    -- Switch to the Play state immediately for this proto
    Gamestate.switch(Play)
end

function love.update(dt)
    Gamestate.update(dt)
end

function love.draw()
    Gamestate.draw()
end

-- Forward other callbacks to Gamestate if needed (keypressed, etc.)
function love.keypressed(key)
    Gamestate.keypressed(key)
end

function love.mousepressed(x, y, button)
    Gamestate.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Gamestate.mousereleased(x, y, button)
end
