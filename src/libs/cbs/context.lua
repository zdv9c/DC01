-- context.lua
-- Context map data structure for CBS library

local vec2 = require("libs.cbs.vec2")

local context = {}

-- Creates a new context with given resolution
-- @param resolution: number - number of direction slots (8, 16, 32, etc.)
-- @return context table
function context.new(resolution)
  local ctx = {
    resolution = resolution,
    slots = {},      -- Array of unit direction vectors
    interest = {},   -- Array of interest values [0, 1]
    danger = {}      -- Array of danger values [0, 1]
  }

  -- Generate evenly-spaced direction slots
  for i = 1, resolution do
    local angle = context.get_slot_angle(i, resolution)
    ctx.slots[i] = vec2.from_angle(angle)
    ctx.interest[i] = 0.0
    ctx.danger[i] = 0.0
  end

  return ctx
end

-- Resets interest and danger maps to zero
-- @param ctx: context
function context.reset(ctx)
  for i = 1, ctx.resolution do
    ctx.interest[i] = 0.0
    ctx.danger[i] = 0.0
  end
end

-- Calculates the angle for a given slot index
-- @param index: number - slot index (1-based)
-- @param resolution: number - total number of slots
-- @return number - angle in radians
function context.get_slot_angle(index, resolution)
  -- Convert to 0-based for calculation
  local i = index - 1
  return (2.0 * math.pi * i) / resolution
end

-- Finds the slot index closest to a given direction
-- @param ctx: context
-- @param direction: vec2 - direction to match
-- @return number - slot index (1-based)
function context.find_closest_slot(ctx, direction)
  local dir_normalized = vec2.normalize(direction)
  local best_index = 1
  local best_dot = -math.huge

  for i = 1, ctx.resolution do
    local dot = vec2.dot(ctx.slots[i], dir_normalized)
    if dot > best_dot then
      best_dot = dot
      best_index = i
    end
  end

  return best_index
end

-- Wraps index to valid range [1, resolution]
-- @param ctx: context
-- @param index: number - potentially out-of-range index
-- @return number - wrapped index
function context.wrap_index(ctx, index)
  local res = ctx.resolution
  -- Handle negative and large values
  return ((index - 1) % res) + 1
end

return context
