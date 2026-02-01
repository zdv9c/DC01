--[[============================================================================
  CONFIG: CBS Condition Evaluator

  PURPOSE: Evaluates declarative condition tables for behavior transitions.
  Conditions are pure data; this module interprets them.

  CONDITION FORMATS:
    String shortcut:
      "hp_low"

    Parameterized table:
      {check = "health_percent", op = "<", value = 0.3}

    Compound conditions:
      {all = {{check = "has_target"}, {check = "distance_to_target", op = "<", value = 80}}}
      {any = {{check = "hp_low"}, {check = "no_ammo"}}}
      {none = {{check = "in_safe_zone"}}}

  USAGE:
    local Conditions = require("config.cbs_conditions")
    if Conditions.evaluate(entity, "hp_low") then ... end
    if Conditions.evaluate(entity, {check = "health_percent", op = "<", value = 0.2}) then ... end
============================================================================]]--

local conditions = {}

--[[----------------------------------------------------------------------------
  STRING SHORTCUTS
  Expand common conditions to full table format.
----------------------------------------------------------------------------]]--

local shortcuts = {
  hp_low = {check = "health_percent", op = "<", value = 0.3},
  hp_high = {check = "health_percent", op = ">", value = 0.5},
  hp_critical = {check = "health_percent", op = "<", value = 0.15},
  hp_full = {check = "health_percent", op = ">=", value = 1.0},
  has_target = {check = "has_target"},
  no_target = {check = "has_target", op = "==", value = false},
  target_reached = {check = "target_reached"},
  path_finished = {check = "path_finished"},
  path_blocked = {check = "path_blocked"},
  at_home = {check = "distance_to_home", op = "<", value = 16},
  far_from_home = {check = "distance_to_home", op = ">", value = 240},
}

--[[----------------------------------------------------------------------------
  COMPARISON OPERATORS
----------------------------------------------------------------------------]]--

local ops = {
  ["<"] = function(a, b) return a < b end,
  [">"] = function(a, b) return a > b end,
  ["<="] = function(a, b) return a <= b end,
  [">="] = function(a, b) return a >= b end,
  ["=="] = function(a, b) return a == b end,
  ["~="] = function(a, b) return a ~= b end,
}

--[[----------------------------------------------------------------------------
  CHECK IMPLEMENTATIONS
  Each check function returns a value to compare, or nil if unavailable.
----------------------------------------------------------------------------]]--

local checks = {
  health_percent = function(entity)
    local health = entity.Health
    if not health or not health.max or health.max == 0 then return nil end
    return health.current / health.max
  end,

  has_target = function(entity)
    local state = entity.CBSBehaviorState
    return state and state.has_target or false
  end,

  distance_to_target = function(entity)
    local state = entity.CBSBehaviorState
    local pos = entity.Transform
    if not state or not state.has_target or not pos then return nil end
    local dx = state.target_x - pos.x
    local dy = state.target_y - pos.y
    return math.sqrt(dx * dx + dy * dy)
  end,

  distance_to_home = function(entity)
    local state = entity.CBSBehaviorState
    local pos = entity.Transform
    if not state or not pos then return nil end
    local dx = state.spawn_x - pos.x
    local dy = state.spawn_y - pos.y
    return math.sqrt(dx * dx + dy * dy)
  end,

  target_reached = function(entity)
    local path = entity.Path
    return path and path.is_finished or false
  end,

  path_finished = function(entity)
    local path = entity.Path
    if not path then return false end
    return not path.is_valid or #path.waypoints == 0
  end,

  path_blocked = function(entity)
    local path = entity.Path
    return path and not path.is_valid or false
  end,

  current_behavior = function(entity)
    local state = entity.CBSBehaviorState
    return state and state.current or nil
  end,

  blend_complete = function(entity)
    local state = entity.CBSBehaviorState
    return state and state.blend_progress >= 1.0
  end,
}

--[[----------------------------------------------------------------------------
  INTERNAL HELPERS
----------------------------------------------------------------------------]]--

local function expand_condition(condition)
  if type(condition) == "string" then
    return shortcuts[condition]
  end
  return condition
end

local function evaluate_check(entity, condition)
  local cond = expand_condition(condition)
  if not cond then return false end

  -- Compound: all (AND)
  if cond.all then
    for _, sub in ipairs(cond.all) do
      if not evaluate_check(entity, sub) then return false end
    end
    return true
  end

  -- Compound: any (OR)
  if cond.any then
    for _, sub in ipairs(cond.any) do
      if evaluate_check(entity, sub) then return true end
    end
    return false
  end

  -- Compound: none (NOR)
  if cond.none then
    for _, sub in ipairs(cond.none) do
      if evaluate_check(entity, sub) then return false end
    end
    return true
  end

  -- Simple check
  local check_fn = checks[cond.check]
  if not check_fn then return false end

  local actual = check_fn(entity)
  if actual == nil then return false end

  -- Boolean check (no operator specified)
  if cond.op == nil and cond.value == nil then
    return actual == true
  end

  -- Comparison check
  local op_fn = ops[cond.op or "=="]
  if not op_fn then return false end

  local expected = cond.value
  if expected == nil then expected = true end

  return op_fn(actual, expected)
end

--[[----------------------------------------------------------------------------
  PUBLIC API
----------------------------------------------------------------------------]]--

function conditions.evaluate(entity, condition)
  return evaluate_check(entity, condition)
end

function conditions.register_shortcut(name, condition_table)
  shortcuts[name] = condition_table
end

function conditions.register_check(name, check_fn)
  checks[name] = check_fn
end

return conditions
