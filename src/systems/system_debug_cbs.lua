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
          draw_cbs_gizmo(pos.x, pos.y, ctx)
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

-- Draws the CBS weight visualization gizmo
-- @param cx: number - center x
-- @param cy: number - center y
-- @param ctx: CBS context - context with interest/danger maps
function draw_cbs_gizmo(cx, cy, ctx)
  -- Get masked interest values for visualization
  local masked_map = CBS.debug_get_masked_map(ctx)
  
  -- Draw normalized circle (shows max possible length)
  love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
  love.graphics.circle("line", cx, cy, MAX_LINE_LENGTH, CIRCLE_SEGMENTS)
  
  -- Draw each direction weight as a line
  for i, data in ipairs(masked_map) do
    local slot_dir = data.slot
    local value = data.value
    
    -- Calculate line length based on weight value
    local line_length = value * MAX_LINE_LENGTH
    
    -- Calculate end point
    local end_x = cx + slot_dir.x * line_length
    local end_y = cy + slot_dir.y * line_length
    
    -- Color based on value (green = desirable, fades to dark when blocked)
    if value > 0.01 then
      love.graphics.setColor(0, value, 0, 0.8)
      love.graphics.line(cx, cy, end_x, end_y)
      
      -- Small dot at end for visibility
      love.graphics.circle("fill", end_x, end_y, 2)
    else
      -- Draw very short red line for blocked directions
      local blocked_length = MAX_LINE_LENGTH * 0.15
      local blocked_end_x = cx + slot_dir.x * blocked_length
      local blocked_end_y = cx + slot_dir.y * blocked_length
      love.graphics.setColor(0.5, 0, 0, 0.4)
      love.graphics.line(cx, cy, blocked_end_x, blocked_end_y)
    end
  end
  
  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
end

return debug_cbs
