--[[============================================================================
  STATE: Play
  
  PURPOSE: Main gameplay state - sets up ECS world, entities, and systems
============================================================================]]--

local Concord = require "libs.Concord"
local Gamestate = require "libs.hump.gamestate"
local gamera = require "libs.gamera.gamera"


local Play = {}

--[[----------------------------------------------------------------------------
  GAMESTATE CALLBACKS
----------------------------------------------------------------------------]]--

local CreatePlayer = require "entities.player"
local CreateNPC = require "entities.test_npc"
local CreateBlock = require "entities.obstacle"

function Play:enter()
  -- Load components
  require "components.init"

  self.scale = 2
  local screenWidth, screenHeight = love.graphics.getDimensions()
  self.logicalWidth = math.floor(screenWidth / self.scale)
  self.logicalHeight = math.floor(screenHeight / self.scale)
  
  self.canvas = love.graphics.newCanvas(self.logicalWidth, self.logicalHeight)
  self.canvas:setFilter("nearest", "nearest")
  
  -- Create camera with world bounds centered around origin
  -- gamera.new(left, top, width, height)
  -- Using centered bounds so camera can freely move around (0,0)
  self.camera = gamera.new(-1000, -1000, 2000, 2000)
  -- Set camera window to our logical resolution
  self.camera:setWindow(0, 0, self.logicalWidth, self.logicalHeight)
  
  -- Create ECS world
  self.world = Concord.world()
  
  -- Store camera as world resource for systems to access
  self.world:setResource("camera", self.camera)
  self.world:setResource("dev_mode", true) -- Default dev mode to ON
  
  -- Add systems in order
  local InputSystem = require "systems.input"
  local AIMovementSystem = require "systems.ai_movement"
  local PathfindingSystem = require "systems.pathfinding"
  local MovementSystem = require "systems.movement"
  local CollisionSystem = require "systems.collision"
  local CameraSystem = require "systems.camera"
  local DevToolsSystem = require "systems.dev_tools"
  local DevInspectorSystem = require "systems.dev_inspector"
  local BackgroundSystem = require "systems.background"
  local RenderingSystem = require "systems.rendering"
  
  self.world:addSystem(InputSystem)
  self.world:addSystem(DevToolsSystem)
  self.world:addSystem(PathfindingSystem)
  self.world:addSystem(AIMovementSystem)
  self.world:addSystem(MovementSystem)
  self.world:addSystem(CollisionSystem)
  self.world:addSystem(CameraSystem)
  self.world:addSystem(BackgroundSystem)
  self.world:addSystem(DevInspectorSystem)
  self.world:addSystem(RenderingSystem)
  
  -- Create entities
  self:createWorld()
end

function Play:createWorld()
  -- Create Player
  local player = Concord.entity(self.world)
  CreatePlayer(player, 312, 280)
  
  -- Create AI Actor
  -- Spawn at 296, 296
  local enemy = Concord.entity(self.world)
  CreateNPC(enemy, 296, 296)
  
  -- Note: Static blocks are now managed by the persistent sandbox system (DevTools)
end

function Play:update(dt)
  self.world:emit("update", dt)
end

function Play:draw()
  -- Draw game world and UI to canvas
  love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    self.world:emit("draw")
    

  love.graphics.setCanvas()
  
  -- Draw scaled canvas to screen
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0, 0, self.scale, self.scale)
end

function Play:keypressed(key)
  print("[INPUT] Key pressed: " .. tostring(key))
  self.world:emit("keypressed", key)
  
  if key == "escape" then
    love.event.quit()
  end
end

function Play:mousepressed(x, y, button)
  -- Convert screen coordinates to logical coordinates
  local lx, ly = x / self.scale, y / self.scale
  self.world:emit("mousepressed", lx, ly, button)
end

function Play:mousereleased(x, y, button)
  local lx, ly = x / self.scale, y / self.scale
  self.world:emit("mousereleased", lx, ly, button)
end

return Play
