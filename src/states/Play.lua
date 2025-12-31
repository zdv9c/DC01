-- states/Play.lua
local Concord = require "libs.Concord"
local Gamestate = require "libs.hump.gamestate"

local Play = {}

function Play:enter()
    -- Load Components
    require "components.init"
    
    -- Create Instance
    self.instance = Concord.world()
    
    -- Add Systems
    -- Order matters!
    self.instance:addSystem(require("systems.Input"))      -- Input first
    self.instance:addSystem(require("systems.Movement"))   -- Move based on velocity
    self.instance:addSystem(require("systems.Physics"))    -- Resolve overlaps
    self.instance:addSystem(require("systems.Rendering"))  -- Draw
    
    -- Create Entities
    self:createWorld()
end

function Play:createWorld()
    -- Create Player
    local player = Concord.entity(self.instance)
    player:give("Transform", 100, 100)
    player:give("Velocity", 0, 0)
    player:give("Sprite", {0, 1, 0, 1}, 8) -- Green circle
    player:give("Collider", 16, 16, "dynamic")
    player:give("PlayerControlled")
    
    -- Create some walls/blocks
    local function createBlock(x, y)
        local block = Concord.entity(self.instance)
        block:give("Transform", x, y)
        block:give("Sprite", {0.5, 0.5, 0.5, 1}, 8) -- Grey
        block:give("Collider", 16, 16, "static")
        -- Static blocks don't need Velocity
    end
    
    createBlock(200, 200)
    createBlock(216, 200)
    createBlock(232, 200)
    
    -- Create AI Actor (Placeholder)
    local enemy = Concord.entity(self.instance)
    enemy:give("Transform", 300, 300)
    enemy:give("Velocity", 0, 0)
    enemy:give("Sprite", {1, 0, 0, 1}, 8) -- Red
    enemy:give("Collider", 16, 16, "dynamic")
    enemy:give("AIControlled")
end

function Play:update(dt)
    self.instance:emit("update", dt)
end

function Play:draw()
    self.instance:emit("draw")
    
    -- Debug info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD/Arrows to move", 10, 10)
end

return Play
