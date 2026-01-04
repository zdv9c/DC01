--[[============================================================================
  SYSTEM: Camera
  
  PURPOSE: Updates STALKER-X camera to follow entities with CameraTarget component
  
  DATA CONTRACT:
    READS:  Transform, CameraTarget
    WRITES: (none - updates external camera object)
    EMITS:  (none)
    CONFIG: camera (STALKER-X camera instance)
  
  UPDATE ORDER: After Collision, before Rendering
============================================================================]]--

local Concord = require "libs.Concord"

local camera_system = Concord.system({
  pool = {"Transform", "CameraTarget"}
})

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function camera_system:init()
  -- Camera is accessed from world resources in update
end

function camera_system:update(dt)
  -- Get camera from world resources
  local camera = self:getWorld():getResource("camera")
  
  -- Guard: No camera configured
  if not camera then return end
  
  -- Find first camera target and follow it
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    
    camera:follow(pos.x, pos.y)
    break  -- Only follow first target
  end
  
  -- Update camera (handles lerp, shake, etc.)
  camera:update(dt)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- No orchestrators needed - camera logic is in STALKER-X library

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- No pure functions needed - camera handles all internally

return camera_system
