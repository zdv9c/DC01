-- solver.lua
-- Direction solver with sub-slot interpolation for CBS library

local vec2 = require("libs.cbs.vec2")
local context_module = require("libs.cbs.context")

local solver = {}

-- Solves for final steering direction using weighted average of all slots
-- Each slot contributes proportionally to its masked weight
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
function solver.solve(ctx)
  -- Compute weighted average of all directions
  local sum_x = 0
  local sum_y = 0
  local total_weight = 0
  local max_weight = 0
  
  for i = 1, ctx.resolution do
    -- Masked weight: interest reduced by danger
    local weight = ctx.interest[i] * (1.0 - ctx.danger[i])
    
    if weight > 0.001 then
      local slot = ctx.slots[i]
      sum_x = sum_x + slot.x * weight
      sum_y = sum_y + slot.y * weight
      total_weight = total_weight + weight
    end
    
    if weight > max_weight then
      max_weight = weight
    end
  end
  
  -- If no valid directions, return zero
  if total_weight < 0.001 then
    return {
      direction = {x = 0, y = 0},
      magnitude = 0.0
    }
  end
  
  -- Normalize to get average direction
  local avg_x = sum_x / total_weight
  local avg_y = sum_y / total_weight
  
  -- Normalize the result
  local len = math.sqrt(avg_x * avg_x + avg_y * avg_y)
  if len > 0.001 then
    avg_x = avg_x / len
    avg_y = avg_y / len
  end
  
  return {
    direction = {x = avg_x, y = avg_y},
    magnitude = max_weight  -- Report max weight for magnitude check
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
    local masked = ctx.interest[i] * (1.0 - ctx.danger[i])

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
