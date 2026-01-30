-- main.lua
-- Entry point for the application.
-- Delegates callbacks to the active Gamestate.

-- 1. Setup paths (if needed, though libs/ is standard)
-- package.path = package.path .. ";libs/?.lua;libs/?/init.lua"

-- 2. Load globally required libraries (optional, but convenient for some)
-- local Gamestate = require "libs.hump.gamestate"

-- 3. Load States
local Gamestate = require "libs.hump.gamestate"
local Slab = require "libs.Slab"
local Play = require "states.Play"

local log = require "libs.log.log"

function love.load(args)
    -- Load gamepad mappings
    local mappings_file = "gamecontrollerdb.txt"
    if love.filesystem.getInfo(mappings_file) then
        love.joystick.loadGamepadMappings(mappings_file)
        log.info("Loaded gamepad mappings from " .. mappings_file)
    else
        log.warn("Could not find gamepad mappings file: " .. mappings_file)
    end

    Slab.Initialize(args)
    -- Switch to the Play state immediately for this proto
    Gamestate.switch(Play)
end

function love.joystickadded(joystick)
    log.info("Joystick Added: " .. joystick:getName() .. " (GUID: " .. joystick:getGUID() .. ")")
end

function love.joystickremoved(joystick)
    log.info("Joystick Removed: " .. joystick:getName())
end

function love.update(dt)
    Slab.Update(dt)
    Gamestate.update(dt)
end

function love.draw()
    Gamestate.draw()
    Slab.Draw()
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
