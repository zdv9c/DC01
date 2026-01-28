-- solver.lua
-- Direction solver with sub-slot interpolation for CBS library

local vec2 = require("libs.cbs.vec2")
local context_module = require("libs.cbs.context")

local solver = {}

-- Solves for final steering direction using weighted average of all slots
-- Each slot contributes proportionally to its masked weight
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
-- Solves for final steering direction using the "Best Peak" approach
-- Finds the slot with highest masked interest and interpolates with neighbors
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
function solver.solve(ctx)
  local max_value = 0
  local best_index = 0
  
  -- 1. Apply Masking & Find Best Slot
  -- We use a non-linear mask: as danger rises, interest is penalized exponentially
  local masked_values = {}
  for i = 1, ctx.resolution do
    local d = ctx.danger[i]
    local interest = ctx.interest[i]
    
    -- Hard Mask: If danger is extremely high, interest becomes 0
    -- If danger is moderate, interest is suppressed quadratically
    local mask = 1.0 - (d * d)
    if d > 0.85 then mask = 0 end
    
    local val = interest * mask
    masked_values[i] = val
    
    if val > max_value then
      max_value = val
      best_index = i
    end
  end
  
  -- 2. Handle "No Path Found" case
  if best_index == 0 or max_value < 0.001 then
    return {
      direction = {x = 0, y = 0},
      magnitude = 0.0
    }
  end
  
  -- 3. Interpolate between the best slot and its neighbors
  -- This provides sub-slot precision for smooth aiming
  local interpolated_dir = solver.interpolate_direction(ctx, masked_values, best_index)
  
  return {
    direction = interpolated_dir,
    magnitude = math.min(1.0, max_value)
  }
end

-- Performs sub-slot interpolation to find true peak direction
-- Uses parabolic interpolation for smoother steering
-- @param ctx: context
-- @param values: array of masked interest values
-- @param center_index: number - index of maximum value
-- @return vec2 - interpolated direction (normalized)
function solver.interpolate_direction(ctx, values, center_index)
  local res = ctx.resolution

  -- Get neighboring values (with wrapping)
  local left_index = context_module.wrap_index(ctx, center_index - 1)
  local right_index = context_module.wrap_index(ctx, center_index + 1)

  local L = values[left_index]
  local C = values[center_index]
  local R = values[right_index]

  -- Calculate sub-slot offset using parabolic interpolation
  -- Formula: x = (L - R) / (2 * (L - 2*C + R))
  local denominator = 2.0 * (L - 2.0 * C + R)
  local offset = 0.0

  if math.abs(denominator) > 0.0001 then
    offset = (L - R) / denominator
    -- Clamp offset to reasonable range [-0.5, 0.5]
    offset = math.max(-0.5, math.min(0.5, offset))
  end

  -- Calculate final angle
  local center_angle = context_module.get_slot_angle(center_index, res)
  local angle_step = (2.0 * math.pi) / res
  local final_angle = center_angle + (offset * angle_step)

  -- Convert to unit vector
  return vec2.from_angle(final_angle)
end

-- Alternative solver: simple winner-take-all (no interpolation)
-- Faster but less smooth than interpolated solve
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
function solver.solve_simple(ctx)
  local max_value = 0.0
  local max_index = 1

  for i = 1, ctx.resolution do
    local d = ctx.danger[i]
    local mask = 1.0 - (d * d)
    if d > 0.85 then mask = 0 end
    
    local masked = ctx.interest[i] * mask

    if masked > max_value then
      max_value = masked
      max_index = i
    end
  end

  if max_value < 0.001 then
    return {
      direction = {x = 0, y = 0},
      magnitude = 0.0
    }
  end

  return {
    direction = ctx.slots[max_index],
    magnitude = max_value
  }
end

-- Debug helper: returns all masked values for visualization
-- @param ctx: context
-- @return array of {slot = vec2, value = number}
function solver.get_masked_map(ctx)
  local result = {}

  for i = 1, ctx.resolution do
    local masked = ctx.interest[i] * (1.0 - ctx.danger[i])
    result[i] = {
      slot = ctx.slots[i],
      value = masked
    }
  end

  return result
end

return solver
