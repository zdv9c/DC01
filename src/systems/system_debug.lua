--[[============================================================================
  SYSTEM: Debug Output
  
  PURPOSE: Outputs entity state to terminal for agent-friendly debugging
  
  DATA CONTRACT:
    READS:  Debug, Transform (optional), Velocity (optional), Collider (optional)
    WRITES: Debug (internal state tracking)
    EMITS:  None
    CONFIG: None
  
  UPDATE ORDER: Last (after all game logic, before rendering)
============================================================================]]--

local Concord = require "libs.Concord"

local debug = Concord.system({
  pool = {"Debug"}
})

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function debug:update(dt)
  for _, entity in ipairs(self.pool) do
    local debug_comp = entity.Debug
    
    if debug_comp.enabled then
      -- Accumulate time and check throttle
      debug_comp.time_since_last_output = debug_comp.time_since_last_output + dt
      
      if debug_comp.time_since_last_output >= debug_comp.throttle_interval then
        debug_comp.time_since_last_output = 0
        
        -- Extract available component data
        local transform = entity.Transform or nil
        local vel = entity.Velocity or nil
        local collider = entity.Collider or nil
        
        -- Generate debug output
        local messages = format_debug_output(
          debug_comp,
          tostring(entity),
          transform,
          vel,
          collider
        )
        
        -- Print all messages to terminal
        for _, msg in ipairs(messages) do
          print(msg)
        end
      end
    end
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Formats debug messages based on tracking configuration
-- @param debug_comp: Debug - debug component with tracking flags
-- @param entity_id: string - entity identifier
-- @param transform: Transform|nil - transform component if available
-- @param vel: Velocity|nil - velocity component if available
-- @param collider: Collider|nil - collider component if available
-- @return table - array of debug message strings
function format_debug_output(debug_comp, entity_id, transform, vel, collider)
  local messages = {}
  local name = debug_comp.entity_name
  
  -- Track position changes
  if debug_comp.track_position and transform then
    local pos_changed = has_position_changed(debug_comp.last_position, transform)
    if pos_changed then
      table.insert(messages, format_position_line(name, entity_id, transform))
      debug_comp.last_position = {x = transform.x, y = transform.y}
    end
  end
  
  -- Track velocity changes
  if debug_comp.track_velocity and vel then
    local vel_changed = has_velocity_changed(debug_comp.last_velocity, vel)
    if vel_changed then
      table.insert(messages, format_velocity_line(name, entity_id, vel))
      debug_comp.last_velocity = {x = vel.x, y = vel.y}
    end
  end
  
  -- Track collision state
  if debug_comp.track_collision and collider then
    local state = get_collision_state(collider)
    if debug_comp.last_collision_state ~= state then
      table.insert(messages, format_collision_line(name, entity_id, state, transform))
      debug_comp.last_collision_state = state
    end
  end
  
  return messages
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Checks if position has changed significantly (> 0.1 pixels)
-- @param last: table|nil - {x, y} or nil
-- @param current: Transform - current transform component
-- @return boolean - true if changed
function has_position_changed(last, current)
  if not last then return true end
  
  local dx = math.abs(current.x - last.x)
  local dy = math.abs(current.y - last.y)
  local threshold = 0.1
  
  return dx > threshold or dy > threshold
end

-- Checks if velocity has changed significantly (> 0.1 units)
-- @param last: table|nil - {x, y} or nil
-- @param current: Velocity - current velocity component
-- @return boolean - true if changed
function has_velocity_changed(last, current)
  if not last then return true end
  
  local dx = math.abs(current.x - last.x)
  local dy = math.abs(current.y - last.y)
  local threshold = 0.1
  
  return dx > threshold or dy > threshold
end

-- Gets collision state from collider
-- @param collider: Collider - collider component
-- @return string - collision state description
function get_collision_state(collider)
  if collider.colliding then
    return string.format("COLLIDING (%d)", collider.collision_count)
  end
  return "none"
end

-- Formats position debug line
-- @param name: string - entity name
-- @param id: string - entity id
-- @param transform: Transform - transform component
-- @return string - formatted message
function format_position_line(name, id, transform)
  return string.format(
    "[DEBUG:%s#%s] Position: (%.2f, %.2f)",
    name,
    id,
    transform.x,
    transform.y
  )
end

-- Formats velocity debug line
-- @param name: string - entity name
-- @param id: string - entity id
-- @param vel: Velocity - velocity component
-- @return string - formatted message
function format_velocity_line(name, id, vel)
  local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
  return string.format(
    "[DEBUG:%s#%s] Velocity: (%.2f, %.2f) Speed: %.2f",
    name,
    id,
    vel.x,
    vel.y,
    speed
  )
end

-- Formats collision state debug line
-- @param name: string - entity name
-- @param id: string - entity id
-- @param state: string - collision state
-- @param transform: Transform|nil - transform for context
-- @return string - formatted message
function format_collision_line(name, id, state, transform)
  if transform then
    return string.format(
      "[DEBUG:%s#%s] Collision: %s at (%.2f, %.2f)",
      name,
      id,
      state,
      transform.x,
      transform.y
    )
  else
    return string.format(
      "[DEBUG:%s#%s] Collision: %s",
      name,
      id,
      state
    )
  end
end

return debug
