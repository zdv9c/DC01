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

function Play:enter()
  -- Load components
  require "components.init"
  
  -- Create camera with world bounds centered around origin
  -- gamera.new(left, top, width, height)
  -- Using centered bounds so camera can freely move around (0,0)
  self.camera = gamera.new(-1000, -1000, 2000, 2000)
  
  -- Create ECS world
  self.world = Concord.world()
  
  -- Store camera as world resource for systems to access
  self.world:setResource("camera", self.camera)
  
  -- Add systems in order
  local InputSystem = require "systems.system_input"
  local MovementSystem = require "systems.system_movement"
  local CollisionSystem = require "systems.system_collision"
  local CameraSystem = require "systems.system_camera"
  local DebugSystem = require "systems.system_debug"
  local RenderingSystem = require "systems.system_rendering"
  
  self.world:addSystem(InputSystem)
  self.world:addSystem(MovementSystem)
  self.world:addSystem(CollisionSystem)
  self.world:addSystem(CameraSystem)
  self.world:addSystem(DebugSystem)  -- After all logic, before rendering
  self.world:addSystem(RenderingSystem)
  
  -- Create entities
  self:createWorld()
end

function Play:createWorld()
  -- Create Player
  local player = Concord.entity(self.world)
  player:give("Transform", 100, 100)
  player:give("Velocity", 0, 0)
  player:give("Sprite", {0, 1, 0, 1}, 8)  -- Green circle
  player:give("Collider", 16, 16, "dynamic")
  player:give("PlayerControlled")
  player:give("CameraTarget")  -- Camera follows this entity
  player:give("Debug", {
    entity_name = "Player",
    track_position = true,
    track_velocity = true,
    track_collision = true
  })
  
  -- Create static blocks
  local function createBlock(x, y)
    local block = Concord.entity(self.world)
    block:give("Transform", x, y)
    block:give("Sprite", {0.5, 0.5, 0.5, 1}, 8)  -- Grey
    block:give("Collider", 16, 16, "static")
    return block
  end
  
  -- Wall of blocks
  local debugBlock = createBlock(200, 200)
  debugBlock:give("Debug", {
    entity_name = "Block",
    track_collision = true
  })
  createBlock(216, 200)
  createBlock(232, 200)
  createBlock(248, 200)
  createBlock(248, 216)
  createBlock(248, 232)
  
  -- Another wall for testing slide
  createBlock(300, 100)
  createBlock(300, 116)
  createBlock(300, 132)
  createBlock(300, 148)
  
  -- Create AI Actor (placeholder - no AI behavior yet)
  local enemy = Concord.entity(self.world)
  enemy:give("Transform", 300, 300)
  enemy:give("Velocity", 0, 0)
  enemy:give("Sprite", {1, 0, 0, 1}, 8)  -- Red
  enemy:give("Collider", 16, 16, "dynamic")
  enemy:give("AIControlled")
end

function Play:update(dt)
  self.world:emit("update", dt)
end

function Play:draw()
  self.world:emit("draw")
  
  -- UI overlay (not affected by camera)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("WASD/Arrows to move", 10, 10)
end

function Play:keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end

return Play
