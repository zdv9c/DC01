--[[============================================================================
  SYSTEM: CBS Transitions

  PURPOSE: Evaluates behavior transition conditions and triggers blended
  state changes. Runs BEFORE cbs_movement.

  DATA CONTRACT:
    READS:  CBSBehaviorState, CBSBehaviorTransitions, Health, Transform, Path
    WRITES: CBSBehaviorState (current, blend_from, blend_progress, etc.)

  UPDATE ORDER: After Pathfinding, before CBS Movement
============================================================================]]--

local Concord = require("libs.Concord")
local Conditions = require("config.cbs_conditions")

local cbs_transitions = Concord.system({
  pool = {"CBSBehaviorState"}
})

local DEFAULT_BLEND_DURATION = 0.2
local DEFAULT_COOLDOWN = 0.1

--[[----------------------------------------------------------------------------
  SHELL LAYER
----------------------------------------------------------------------------]]--

function cbs_transitions:update(dt)
  local current_time = love.timer.getTime()

  for _, entity in ipairs(self.pool) do
    local state = entity.CBSBehaviorState
    local transitions = entity.CBSBehaviorTransitions  -- May be nil

    -- ALWAYS advance blend progress if currently blending (manual or automatic)
    if state.blend_progress < 1.0 then
      local blend_duration = state.blend_duration or DEFAULT_BLEND_DURATION
      state.blend_progress = math.min(1.0, state.blend_progress + dt / blend_duration)

      -- Clear blend_from when blend completes
      if state.blend_progress >= 1.0 then
        state.blend_from = nil
      end
    end

    -- Skip automatic transitions if no transitions component
    if not transitions then
      goto continue
    end

    -- Skip AUTOMATIC transitions if manual override is active
    if state.manual_override_until > current_time then
      goto continue
    end

    -- Check cooldown before evaluating transitions
    local time_since_transition = current_time - state.last_transition_time
    local min_cooldown = get_min_cooldown(transitions)
    if time_since_transition < min_cooldown then
      goto continue
    end

    -- Check transitions (sorted by priority)
    local new_behavior, transition_def = check_transitions(entity, state, transitions)
    if new_behavior and new_behavior ~= state.current then
      -- Store last transition info for debugging
      state.last_auto_transition = {
        from = state.current,
        to = new_behavior,
        condition = transition_def.condition,
        time = current_time
      }
      transition_behavior(state, new_behavior, transition_def, current_time)
    end

    ::continue::
  end
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER
----------------------------------------------------------------------------]]--

function get_min_cooldown(transitions)
  if not transitions then return DEFAULT_COOLDOWN end

  local min_cooldown = DEFAULT_COOLDOWN
  for _, t in ipairs(transitions.transitions) do
    local cooldown = t.cooldown or DEFAULT_COOLDOWN
    if cooldown < min_cooldown then
      min_cooldown = cooldown
    end
  end
  return min_cooldown
end

function check_transitions(entity, state, transitions)
  -- Sort by priority (higher first)
  local sorted = {}
  for _, t in ipairs(transitions.transitions) do
    table.insert(sorted, t)
  end
  table.sort(sorted, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)

  -- Find first matching transition
  for _, t in ipairs(sorted) do
    if t.from == state.current or t.from == "any" then
      if Conditions.evaluate(entity, t.condition) then
        return t.to, t
      end
    end
  end

  return nil, nil
end

function transition_behavior(state, new_behavior, transition_def, current_time)
  -- Set up blend from current to new
  state.blend_from = state.current
  state.blend_progress = 0.0
  state.blend_duration = transition_def.blend_duration or DEFAULT_BLEND_DURATION

  -- Update behavior state
  state.previous = state.current
  state.current = new_behavior
  state.last_transition_time = current_time

  -- Clear behavior-specific data (new behavior starts fresh)
  state.data = {}
end

return cbs_transitions
