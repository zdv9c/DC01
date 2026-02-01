--[[============================================================================
  CBS MODIFIERS

  PURPOSE: Post-behavior modifiers that add subtle movement variation.
  Applied after primary behavior interest calculation, before CBS solve.

  MODIFIER TYPES:
    sway              - Perpendicular oscillation using noise
    obstacle_sensitivity - Multiply danger values
    speed_noise       - Perlin-based speed modulation

  USAGE:
    local CBS_Modifiers = require("libs.cbs.cbs_modifiers")
    CBS_Modifiers.apply_all(ctx, forward, modifiers, state, dt)
============================================================================]]--

local CBS_Modifiers = {}

local modifier_handlers = {}

--[[----------------------------------------------------------------------------
  SWAY MODIFIER
  Adds subtle perpendicular oscillation for organic movement.
----------------------------------------------------------------------------]]--

modifier_handlers.sway = function(ctx, forward, params, state)
  local weight = params.weight or 0.1
  local rate = params.rate or 0.5

  -- Perpendicular direction
  local perpendicular = {x = -forward.y, y = forward.x}

  -- Use noise for smooth variation
  local noise_val = love.math.noise((state.noise_time or 0) * rate, (state.seed or 0) * 0.01)
  local sway_amount = (noise_val - 0.5) * 2.0 * weight

  -- Add perpendicular interest bias
  for i = 1, ctx.resolution do
    local slot_dir = ctx.slots[i]
    local dot = slot_dir.x * perpendicular.x + slot_dir.y * perpendicular.y
    ctx.interest[i] = ctx.interest[i] + dot * sway_amount
  end
end

--[[----------------------------------------------------------------------------
  OBSTACLE SENSITIVITY MODIFIER
  Scales danger values (> 1.0 = more cautious, < 1.0 = more aggressive).
----------------------------------------------------------------------------]]--

modifier_handlers.obstacle_sensitivity = function(ctx, forward, params, state)
  local multiplier = params.multiplier or 1.0

  for i = 1, ctx.resolution do
    ctx.danger[i] = math.min(1.0, ctx.danger[i] * multiplier)
  end
end

--[[----------------------------------------------------------------------------
  SPEED NOISE MODIFIER
  Stores a speed modifier in state for velocity calculation.
----------------------------------------------------------------------------]]--

modifier_handlers.speed_noise = function(ctx, forward, params, state)
  local amount = params.amount or 0.1
  local rate = params.rate or 0.5

  local noise_val = love.math.noise(
    (state.noise_time or 0) * rate,
    ((state.seed or 0) + 1000) * 0.01
  )

  -- Map [0, 1] to [1 - amount, 1 + amount]
  state.speed_modifier = 1.0 + (noise_val - 0.5) * 2.0 * amount
end

--[[----------------------------------------------------------------------------
  PUBLIC API
----------------------------------------------------------------------------]]--

function CBS_Modifiers.apply_all(ctx, forward, modifiers_component, state, dt)
  if not modifiers_component or not modifiers_component.modifiers then
    return
  end

  -- Advance noise time
  state.noise_time = (state.noise_time or 0) + dt

  -- Apply each modifier
  for _, mod in ipairs(modifiers_component.modifiers) do
    local handler = modifier_handlers[mod.type]
    if handler then
      handler(ctx, forward, mod, state)
    end
  end
end

function CBS_Modifiers.register(name, handler_fn)
  modifier_handlers[name] = handler_fn
end

return CBS_Modifiers
