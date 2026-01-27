--[[============================================================================
  SYSTEM: CBS Debug Visualization
  
  PURPOSE: Draws CBS weight maps as visual gizmos for debugging AI movement
  
  DATA CONTRACT:
    READS:  Transform, Debug, AIControlled, SteeringState, (world resource: ai_debug_contexts)
    WRITES: None (draw only)
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: During draw phase, after main rendering
============================================================================]]--

local Concord = require "libs.Concord"
local CBS = require "libs.cbs"

local debug_cbs = Concord.system({
  pool = {"AIControlled", "Transform", "SteeringState", "Debug"}
})

-- Config constants
local MAX_LINE_LENGTH = 48    -- 3 tiles × 16px = max line length
local CIRCLE_SEGMENTS = 32    -- Smoothness of normalized circle

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function debug_cbs:init()
  -- Nothing needed
end

function debug_cbs:draw()
  -- Get debug contexts from world resource (set by AI movement system)
  local debug_contexts = self:getWorld():getResource("ai_debug_contexts")
  if not debug_contexts then return end
  
  local camera = self:getWorld():getResource("camera")
  if not camera then return end
  
  -- Draw within camera transform
  camera:draw(function()
    for _, entity in ipairs(self.pool) do
      local dbg = entity.Debug
      
      -- Only draw if CBS debug is enabled
      if dbg.enabled and dbg.track_cbs then
        local pos = entity.Transform
        
        -- Try to get context for this entity
        local ctx = debug_contexts[entity]
        
        if ctx then
          -- Draw leash perimeter (spawn point + radius)
          local steering = entity.SteeringState
          if steering then
             draw_leash_perimeter(steering)
          end

          draw_cbs_gizmo(pos.x, pos.y, ctx, steering)
        else
          -- Fallback: draw indicator that context not found  
          draw_no_context_indicator(pos.x, pos.y)
        end
      end
    end
  end)
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Draws a simple indicator when no CBS context is available
-- @param cx: number - center x
-- @param cy: number - center y
function draw_no_context_indicator(cx, cy)
  love.graphics.setColor(1, 1, 0, 0.5)  -- Yellow
  love.graphics.circle("line", cx, cy, MAX_LINE_LENGTH, CIRCLE_SEGMENTS)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Draws the wander leash perimeter (spawn point radius)
-- @param steering: table - SteeringState component
function draw_leash_perimeter(steering)
  love.graphics.setColor(1, 0, 0, 0.3) -- Red, low alpha
  love.graphics.circle("line", steering.spawn_x, steering.spawn_y, steering.leash_radius, 64)
  -- Draw spawn center cross
  local size = 4
  love.graphics.line(steering.spawn_x - size, steering.spawn_y - size, steering.spawn_x + size, steering.spawn_y + size)
  love.graphics.line(steering.spawn_x - size, steering.spawn_y + size, steering.spawn_x + size, steering.spawn_y - size)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Draws the CBS weight visualization gizmo
-- @param cx: number - center x
-- @param cy: number - center y
-- @param ctx: CBS context - context with interest/danger maps
-- @param steering: SteeringState component (optional, for raycast visualization)
function draw_cbs_gizmo(cx, cy, ctx, steering)
  -- Get masked interest values for visualization
  local masked_map = CBS.debug_get_masked_map(ctx)
  
  -- 1. Find maximum weight to normalize lines
  local max_weight = 0.0
  for _, data in ipairs(masked_map) do
    if data.value > max_weight then
      max_weight = data.value
    end
  end
  
  -- Draw normalized circle (outer boundary) - Green with 50% alpha
  love.graphics.setColor(0, 1, 0, 0.5)
  love.graphics.circle("line", cx, cy, MAX_LINE_LENGTH, CIRCLE_SEGMENTS)
  
  -- If max weight is negligible (idle), don't draw any lines
  if max_weight < 0.01 then
    love.graphics.setColor(1, 1, 1, 1)
    return
  end
  
  -- Draw each direction weight as a line
  -- Unified logic: One set of lines, color based on weight threshold
  local MIN_SCALE = 0.20
  local RED_THRESHOLD = 0.15
  
  for i, data in ipairs(masked_map) do
    local slot_dir = data.slot
    local value = data.value
    
    -- Use absolute value for visualization (don't normalize to max_weight)
    -- This ensures we see "Bad" options as short/red even if they are the "Best" available.
    local absolute_value = math.max(0.0, math.min(1.0, value))
    
    -- Calculate visual length (scale 20% to 100%)
    local visual_scale = MIN_SCALE + absolute_value * (1.0 - MIN_SCALE)
    local line_length = visual_scale * MAX_LINE_LENGTH
    
    local end_x = cx + slot_dir.x * line_length
    local end_y = cy + slot_dir.y * line_length
    
    -- Determine color based on absolute value
    if absolute_value < RED_THRESHOLD then
      -- Low weight = Red (Danger/Blocked)
      love.graphics.setColor(1, 0, 0, 0.8)
    else
      -- High weight = Green (Desirable)
      love.graphics.setColor(0, 1, 0, 0.5 + 0.5 * absolute_value)
    end
    
    love.graphics.line(cx, cy, end_x, end_y)
  end
  
  -- Draw slot raycast lines (one per CBS slot, colored by danger)
  if steering and steering.last_ray_results then
    local RAYCAST_RANGE = 64
    
    for _, ray in ipairs(steering.last_ray_results) do
      -- Only draw ray if it hit something
      if ray.hit then
        local ray_length = ray.distance
        local dir_x = math.cos(ray.angle)
        local dir_y = math.sin(ray.angle)
        
        -- Red with opacity based on danger (more opaque = more dangerous)
        local danger = ray.danger or 0
        local a = 0.3 + danger * 0.5  -- More opaque when dangerous
        
        love.graphics.setColor(1, 0, 0, a)
        
        -- Draw as dotted line
        local dot_length = 4
        local gap_length = 4
        local t = 0
        while t < ray_length do
          local seg_start = t
          local seg_end = math.min(t + dot_length, ray_length)
          
          local x1 = cx + dir_x * seg_start
          local y1 = cy + dir_y * seg_start
          local x2 = cx + dir_x * seg_end
          local y2 = cy + dir_y * seg_end
          
          love.graphics.line(x1, y1, x2, y2)
          
          t = t + dot_length + gap_length
        end
        
        -- Draw hit marker (X)
        local hx = cx + dir_x * ray.distance
        local hy = cy + dir_y * ray.distance
        local size = 3
        
        love.graphics.setColor(1, 0, 0, 0.6)
        love.graphics.line(hx - size, hy - size, hx + size, hy + size)
        love.graphics.line(hx - size, hy + size, hx + size, hy - size)
      end
    end
  end
  
  -- Draw Manual Target "X" (if set)
  if ctx.target_position then
    local tx = ctx.target_position.x
    local ty = ctx.target_position.y
    local size = 6
    
    love.graphics.setColor(0, 1, 0, 1) -- Green
    love.graphics.setLineWidth(2)
    love.graphics.line(tx - size, ty - size, tx + size, ty + size)
    love.graphics.line(tx - size, ty + size, tx + size, ty - size)
    love.graphics.setLineWidth(1)
  end
  
  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
end

return debug_cbs
