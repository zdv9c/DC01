--[[============================================================================
  SYSTEM: CBS Movement

  PURPOSE: Shell layer for CBS-driven AI movement. Handles world access,
  component extraction, and result writing. Replaces ai_movement.lua.

  DATA CONTRACT:
    READS:  AIControlled, Transform, Velocity, CBSBehaviorState, Path, Collider,
            CBSBehaviorConfig, CBSModifiers
    WRITES: Velocity, CBSBehaviorState
    CONFIG: cbs_behavior_defs (via orchestrator)

  UPDATE ORDER: After CBS Transitions, before Movement
============================================================================]]--

local Concord = require("libs.Concord")
local CBS_Navigation = require("systems.behaviors.cbs_navigation")

local cbs_movement = Concord.system({
  pool = {"AIControlled", "Transform", "Velocity", "CBSBehaviorState", "Path", "Collider"},
  obstacles = {"Transform", "Collider"}
})

function cbs_movement:init()
  -- Store CBS contexts for debug visualization
  self.debug_contexts = {}
end

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function cbs_movement:update(dt)
  -- Collect obstacle data (world access)
  local obstacle_data = {}
  for _, entity in ipairs(self.obstacles) do
    local pos = entity.Transform
    local col = entity.Collider
    if col and col.type == "static" then
      local radius = col and (col.width / 2) or 8
      table.insert(obstacle_data, {
        x = pos.x,
        y = pos.y,
        radius = radius,
        entity = entity
      })
    end
  end

  -- Process each AI entity
  for _, entity in ipairs(self.pool) do
    local pos = entity.Transform
    local vel = entity.Velocity
    local state = entity.CBSBehaviorState
    local path = entity.Path
    local collider = entity.Collider
    local config = entity.CBSBehaviorConfig
    local modifiers = entity.CBSModifiers

    local entity_radius = collider and (collider.width / 2) or 8

    -- Sync target from Path component
    -- Priority: 1. Target entity (if exists and valid), 2. Static final_target
    if path then
      if path.target_entity and path.target_entity.Transform then
        -- Entity-based targeting (updates as entity moves)
        local target_pos = path.target_entity.Transform
        state.target_x = target_pos.x
        state.target_y = target_pos.y
        state.has_target = true
      elseif path.final_target then
        -- Static position targeting
        state.target_x = path.final_target.x
        state.target_y = path.final_target.y
        state.has_target = true
      else
        state.has_target = false
      end
    else
      state.has_target = false
    end

    -- Clear target when reached (prevent spinning at destination)
    if state.has_target and state.current == "seek" and path then
      local dx = state.target_x - pos.x
      local dy = state.target_y - pos.y
      local dist_sq = dx * dx + dy * dy
      local REACHED_THRESHOLD = 4 -- Quarter tile

      if dist_sq < REACHED_THRESHOLD * REACHED_THRESHOLD then
        path.final_target = nil
        path.target_entity = nil
        state.has_target = false
      end
    end

    -- Call orchestrator
    local result = CBS_Navigation.navigate({
      pos = pos,
      vel = vel,
      behavior_state = state,
      behavior_config = config,
      modifiers = modifiers,
      path = path,
      obstacles = obstacle_data,
      entity_radius = entity_radius,
      dt = dt,
      self_entity = entity,
    })

    -- Write results back to world
    vel.x = result.vx
    vel.y = result.vy
    state.cursor = result.cursor
    state.forward_x = result.forward_x
    state.forward_y = result.forward_y
    state.current_speed = result.current_speed
    state.deadlock_side = result.deadlock_side
    state.last_ray_results = result.ray_results

    -- Store debug context
    self.debug_contexts[entity] = result.debug_context
  end

  -- Expose for debug gizmos
  self:getWorld():setResource("ai_debug_contexts", self.debug_contexts)
end

return cbs_movement
