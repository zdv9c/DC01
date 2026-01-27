--[[============================================================================
  STATE: Play
  
  PURPOSE: Main gameplay state - sets up ECS world, entities, and systems
============================================================================]]--

local Concord = require "libs.Concord"
local Gamestate = require "libs.hump.gamestate"
local gamera = require "libs.gamera.gamera"
local AI_CONFIG = require "config.ai_config"

local Play = {}

--[[----------------------------------------------------------------------------
  GAMESTATE CALLBACKS
----------------------------------------------------------------------------]]--

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
  
  -- Add systems in order
  local InputSystem = require "systems.system_input"
  local AIMovementSystem = require "systems.system_ai_movement"
  local PathfindingSystem = require "systems.system_pathfinding"
  local MovementSystem = require "systems.system_movement"
  local CollisionSystem = require "systems.system_collision"
  local CameraSystem = require "systems.system_camera"
  local DebugSystem = require "systems.system_debug"
  local DebugCBSSystem = require "systems.system_debug_cbs"
  local RenderingSystem = require "systems.system_rendering"
  
  self.world:addSystem(InputSystem)
  self.world:addSystem(require "systems.system_sandbox") -- Sandbox interaction
  self.world:addSystem(PathfindingSystem)
  self.world:addSystem(AIMovementSystem)
  self.world:addSystem(MovementSystem)
  self.world:addSystem(CollisionSystem)
  self.world:addSystem(CameraSystem)
  self.world:addSystem(RenderingSystem)
  self.world:addSystem(DebugSystem)  -- After all logic, before rendering
  self.world:addSystem(DebugCBSSystem)  -- CBS weight visualization
  
  -- Create entities
  self:createWorld()
end

function Play:createWorld()
  -- Create Player
  local player = Concord.entity(self.world)
  player:give("Transform", 312, 280)
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
    block:give("Debug", {
      entity_name = "Block",
      track_collision = false
    })
    return block
  end
  
  -- Wall of blocks
  -- (Removed: Managed by persistent sandbox system now)
  
  -- Another wall for testing slide
  -- (Removed: Managed by persistent sandbox system now)
  
  -- Create AI Actor with CBS wandering
  local enemy_spawn_x, enemy_spawn_y = 296, 296
  local enemy = Concord.entity(self.world)
  enemy:give("Transform", enemy_spawn_x, enemy_spawn_y)
  enemy:give("Velocity", 0, 0, AI_CONFIG.movement.speed, 0) -- kinematic (no friction)
  enemy:give("Sprite", {1, 1, 0, 1}, 8)  -- Yellow
  enemy:give("Collider", 16, 16, "dynamic")
  enemy:give("AIControlled")
  enemy:give("SteeringState", enemy_spawn_x, enemy_spawn_y, 240, 42)  -- Spawn, 15-tile leash, seed=42
  enemy:give("Path", enemy_spawn_x, enemy_spawn_y)  -- Initialize path with spawn location
  enemy:give("Debug", {
    entity_name = "Enemy",
    track_position = false,
    track_velocity = false,
    track_collision = false,
    track_cbs = true  -- Enable CBS debug visualization
  })
end

function Play:update(dt)
  self.world:emit("update", dt)
end

function Play:draw()
  -- Draw game world and UI to canvas
  love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    self.world:emit("draw")
    
    -- UI overlay (now in logical coordinates)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD/Arrows to move", 10, 10)
  love.graphics.setCanvas()
  
  -- Draw scaled canvas to screen
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0, 0, self.scale, self.scale)
end

function Play:keypressed(key)
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
