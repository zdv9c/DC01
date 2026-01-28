--[[============================================================================
  SYSTEM: Dev Inspector
  
  PURPOSE: Introspection system for developers. Handles visual gizmos, terminal
           logging, and the global "dev_mode" toggle.
  
  DATA CONTRACT:
    READS:  Transform, Debug, AIControlled, SteeringState, Path
    WRITES: Debug (internal logs state), World Resource (dev_mode)
    LISTENS: keypressed (tilde to toggle dev_mode)
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: After all game logic
============================================================================]]--

local Concord = require "libs.Concord"
local CBS = require "libs.cbs"

local dev_inspector = Concord.system({
  pool_debug = {"Debug"},
  pool_ai = {"AIControlled", "Transform", "SteeringState", "Debug", "Path"}
})

local MAX_LINE_LENGTH = 48    -- 3 tiles × 16px = max line length
local CIRCLE_SEGMENTS = 48    -- Smoothness of normalized circle
local GIZMO_LINE_WIDTH = 0.25   -- Half of the default 1.0

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function dev_inspector:init()
  -- Default dev_mode to true for development
  self:getWorld():setResource("dev_mode", true)
  
  -- Visibility Toggles
  self.viz = {
    ui = true,          -- "dev mode" text
    leash = true,       -- NPC leash radius
    path = true,        -- A* path waypoints/lines
    pruning = true,     -- LOS shortcutting visualization
    cbs_ring = false,    -- CBS gizmo circular base
    cbs_weights = true, -- CBS direction weight lines
    cbs_rays = false,    -- Physical raycast hits
    deadlock = true,    -- Deadlock resolution/side choice
    hard_mask = true    -- Slots blocked by the Hard Mask (danger > 0.85)
  }
end

function dev_inspector:keypressed(key)
  if key == "grave" or key == "~" or key == "`" then
    local dev_mode = not self:getWorld():getResource("dev_mode")
    self:getWorld():setResource("dev_mode", dev_mode)
    print("[DEV] Mode: " .. (dev_mode and "ENABLED" or "DISABLED"))
  end
  
  -- Toggle specific gizmos with numbers 1-6
  if self:getWorld():getResource("dev_mode") then
    if key == "1" then self.viz.ui = not self.viz.ui; print("[DEV] UI: " .. tostring(self.viz.ui)) end
    if key == "2" then self.viz.leash = not self.viz.leash; print("[DEV] Leash: " .. tostring(self.viz.leash)) end
    if key == "3" then self.viz.path = not self.viz.path; print("[DEV] Path: " .. tostring(self.viz.path)) end
    if key == "4" then self.viz.cbs_ring = not self.viz.cbs_ring; print("[DEV] CBS Ring: " .. tostring(self.viz.cbs_ring)) end
    if key == "5" then self.viz.cbs_weights = not self.viz.cbs_weights; print("[DEV] CBS Weights: " .. tostring(self.viz.cbs_weights)) end
    if key == "6" then self.viz.cbs_rays = not self.viz.cbs_rays; print("[DEV] CBS Rays: " .. tostring(self.viz.cbs_rays)) end
    if key == "7" then self.viz.deadlock = not self.viz.deadlock; print("[DEV] Deadlock: " .. tostring(self.viz.deadlock)) end
    if key == "8" then self.viz.hard_mask = not self.viz.hard_mask; print("[DEV] Hard Mask: " .. tostring(self.viz.hard_mask)) end
    if key == "9" then self.viz.pruning = not self.viz.pruning; print("[DEV] Pruning: " .. tostring(self.viz.pruning)) end
  end
end

function dev_inspector:update(dt)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end
  
  -- Handle Logging
  for _, entity in ipairs(self.pool_debug) do
    local debug_comp = entity.Debug
    
    if debug_comp.enabled then
      debug_comp.time_since_last_output = debug_comp.time_since_last_output + dt
      
      if debug_comp.time_since_last_output >= debug_comp.throttle_interval then
        debug_comp.time_since_last_output = 0
        
        local messages = compute_debug_messages(
          debug_comp,
          tostring(entity),
          entity.Transform,
          entity.Velocity,
          entity.Collider
        )
        
        for _, msg in ipairs(messages) do
          print(msg)
        end
      end
    end
  end
end

function dev_inspector:draw()
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end
  
  -- 1. Draw UI Overlay (Screen Space)
  if self.viz.ui then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("dev mode (1:ui 2:leash 3:path 4:ring 5:wghts 6:rays 7:dead 8:hmask 9:prune)", 10, 10)
  end
  
  -- 2. Draw World Gizmos (Camera Space)
  local camera = self:getWorld():getResource("camera")
  local debug_contexts = self:getWorld():getResource("ai_debug_contexts")
  
  if camera then
    camera:draw(function()
      love.graphics.setLineWidth(GIZMO_LINE_WIDTH)
      for _, entity in ipairs(self.pool_ai) do
        local dbg = entity.Debug
        if dbg.enabled and dbg.track_cbs then
          local pos = entity.Transform
          local ctx = debug_contexts and debug_contexts[entity]
          local steering = entity.SteeringState
          
          if steering and self.viz.leash then draw_leash_perimeter(steering) end
          if entity.Path then
             if self.viz.path then draw_path_gizmo(entity.Path) end
             if self.viz.pruning then draw_pruning_gizmo(pos, entity.Path) end
          end
          if ctx then draw_cbs_gizmo(pos.x, pos.y, ctx, steering, self.viz) end
        end
      end
      love.graphics.setLineWidth(1) -- Reset for other systems
    end)
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

function compute_debug_messages(debug_comp, entity_id, transform, vel, collider)
  local messages = {}
  local name = debug_comp.entity_name
  
  if debug_comp.track_position and transform then
    if has_significant_change(debug_comp.last_position, transform) then
      table.insert(messages, string.format("[DEBUG:%s#%s] Position: (%.2f, %.2f)", name, entity_id, transform.x, transform.y))
      debug_comp.last_position = {x = transform.x, y = transform.y}
    end
  end
  
  if debug_comp.track_velocity and vel then
    if has_significant_change(debug_comp.last_velocity, vel) then
      local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
      table.insert(messages, string.format("[DEBUG:%s#%s] Velocity: (%.2f, %.2f) Speed: %.2f", name, entity_id, vel.x, vel.y, speed))
      debug_comp.last_velocity = {x = vel.x, y = vel.y}
    end
  end
  
  if debug_comp.track_collision and collider then
    local state = collider.colliding and string.format("COLLIDING (%d)", collider.collision_count) or "none"
    if debug_comp.last_collision_state ~= state then
      table.insert(messages, string.format("[DEBUG:%s#%s] Collision: %s", name, entity_id, state))
      debug_comp.last_collision_state = state
    end
  end
  
  return messages
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

function has_significant_change(last, current)
  if not last then return true end
  return math.abs(current.x - last.x) > 0.1 or math.abs(current.y - last.y) > 0.1
end

function draw_leash_perimeter(steering)
  love.graphics.setColor(1, 0, 0, 0.3)
  love.graphics.circle("line", steering.spawn_x, steering.spawn_y, steering.leash_radius, 64)
  love.graphics.setColor(1, 1, 1, 1)
end

function draw_path_gizmo(path)
  if not path.waypoints or #path.waypoints == 0 then return end
  love.graphics.setLineWidth(GIZMO_LINE_WIDTH * 2)
  local last_x, last_y
  for i, wp in ipairs(path.waypoints) do
    if i >= path.current_index then
      if last_x then
        love.graphics.setColor(0.2, 0.6, 1.0, 0.8)
        love.graphics.line(last_x, last_y, wp.x, wp.y)
      end
      love.graphics.setColor(i == path.current_index and {0,1,1,1} or {0.2,0.6,1,0.6})
      love.graphics.circle("fill", wp.x, wp.y, i == path.current_index and 4 or 3)
      last_x, last_y = wp.x, wp.y
    end
  end
  if last_x then
    love.graphics.setColor(0.2, 0.6, 1.0, 0.4)
    love.graphics.line(last_x, last_y, path.final_target.x, path.final_target.y)
  end
  love.graphics.setLineWidth(GIZMO_LINE_WIDTH)
end

function draw_pruning_gizmo(pos, path)
  if not path.waypoints or #path.waypoints == 0 then return end
  -- Show a thin line from NPC to the current target waypoint to highlight shortcutting
  local target = path.waypoints[1]
  love.graphics.setColor(0, 1, 0, 0.4)
  love.graphics.setLineWidth(GIZMO_LINE_WIDTH * 0.5)
  love.graphics.line(pos.x, pos.y, target.x, target.y)
  love.graphics.circle("line", pos.x, pos.y, 4)
  love.graphics.setLineWidth(GIZMO_LINE_WIDTH)
end

function draw_cbs_gizmo(cx, cy, ctx, steering, viz)
  if viz.cbs_ring then
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.circle("line", cx, cy, MAX_LINE_LENGTH, CIRCLE_SEGMENTS)
  end
  
  if viz.cbs_weights then
    local masked_map = CBS.debug_get_masked_map(ctx)
    for i, data in ipairs(masked_map) do
      local val = math.max(0, math.min(1, data.value))
      local danger = ctx.danger[i] or 0
      local length = (0.2 + val * 0.8) * MAX_LINE_LENGTH
      
      -- 1. Draw blocked slot (Hard Mask)
      if viz.hard_mask and danger > 0.85 then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", cx + data.slot.x * MAX_LINE_LENGTH, cy + data.slot.y * MAX_LINE_LENGTH, 2)
      end

      -- 2. Draw weighted direction line
      -- Interpolate: 1.0 (Green, 100% opac) -> 0.15 (Red, 50% opac)
      local t = math.max(0, (val - 0.15) / (1.0 - 0.15))
      love.graphics.setColor(1 - t, t, 0, 0.5 + 0.5 * t)
      
      love.graphics.line(cx, cy, cx + data.slot.x * length, cy + data.slot.y * length)
    end
  end
  
  -- 3. Draw deadlock resolution side
  if viz.deadlock and steering and steering.deadlock_side and steering.deadlock_side ~= 0 then
    -- Draw an arc or arrow representing the persistent bias side
    local angle = math.atan2(steering.forward_y, steering.forward_x)
    local offset = steering.deadlock_side * (math.pi / 4)
    local side_x = math.cos(angle + offset)
    local side_y = math.sin(angle + offset)
    
    love.graphics.setColor(1, 1, 0, 1) -- Yellow for decision
    love.graphics.setLineWidth(GIZMO_LINE_WIDTH * 3)
    love.graphics.line(cx, cy, cx + side_x * (MAX_LINE_LENGTH * 0.8), cy + side_y * (MAX_LINE_LENGTH * 0.8))
    love.graphics.print(steering.deadlock_side > 0 and "L" or "R", cx + side_x * MAX_LINE_LENGTH, cy + side_y * MAX_LINE_LENGTH)
    love.graphics.setLineWidth(GIZMO_LINE_WIDTH)
  end
  
  if viz.cbs_rays and steering and steering.last_ray_results then
    for _, ray in ipairs(steering.last_ray_results) do
      if ray.hit then
        love.graphics.setColor(1, 0, 0, 0.3 + (ray.danger or 0) * 0.5)
        local dx, dy = math.cos(ray.angle), math.sin(ray.angle)
        -- Simplified solid line for ray hit
        love.graphics.line(cx, cy, cx + dx * ray.distance, cy + dy * ray.distance)
        love.graphics.circle("fill", cx + dx * ray.distance, cy + dy * ray.distance, 2)
      end
    end
  end
end

return dev_inspector
