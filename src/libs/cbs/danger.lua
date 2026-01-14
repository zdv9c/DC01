-- danger.lua
-- Danger map population from sensory input for CBS library

local vec2 = require("libs.cbs.vec2")
local context_module = require("libs.cbs.context")

local danger = {}

-- Adds danger from raycast results
-- @param ctx: context
-- @param ray_results: array of {direction = vec2, hit_distance = number}
-- @param look_ahead: number - maximum raycast distance
-- @param dilation: number - danger spread sigma (0 = no spread, 0.5 = moderate)
function danger.add_danger_from_rays(ctx, ray_results, look_ahead, dilation)
  look_ahead = look_ahead or 100
  dilation = dilation or 0.0

  for _, ray in ipairs(ray_results) do
    -- Find closest slot to ray direction
    local slot_index = context_module.find_closest_slot(ctx, ray.direction)

    -- Calculate danger value based on proximity
    -- Close hits = high danger (1.0), far hits = low danger (~0.0)
    local normalized_distance = ray.hit_distance / look_ahead
    local danger_value = 1.0 - math.min(1.0, normalized_distance)

    -- Add to danger map
    ctx.danger[slot_index] = math.max(ctx.danger[slot_index], danger_value)
  end

  -- Apply dilation if requested
  if dilation > 0 then
    danger.apply_dilation(ctx, dilation)
  end
end

-- Applies Gaussian dilation to spread danger to neighboring slots
-- This accounts for agent radius and creates smoother danger gradients
-- @param ctx: context
-- @param sigma: number - spread factor (0.5 = moderate, 1.0 = wide)
function danger.apply_dilation(ctx, sigma)
  -- Create temporary copy of danger map
  local original_danger = {}
  for i = 1, ctx.resolution do
    original_danger[i] = ctx.danger[i]
  end

  -- Apply Gaussian-like falloff to neighbors
  local spread_radius = math.ceil(sigma * 2)  -- How many neighbors to affect

  for i = 1, ctx.resolution do
    if original_danger[i] > 0.01 then  -- Only dilate significant danger
      -- Spread to neighbors
      for offset = -spread_radius, spread_radius do
        if offset ~= 0 then
          local neighbor_index = context_module.wrap_index(ctx, i + offset)

          -- Gaussian falloff based on distance
          local distance_factor = math.abs(offset) / spread_radius
          local falloff = math.exp(-(distance_factor * distance_factor) / (2 * sigma * sigma))

          -- Apply dilated danger (take max, don't accumulate)
          local dilated_value = original_danger[i] * falloff
          ctx.danger[neighbor_index] = math.max(ctx.danger[neighbor_index], dilated_value)
        end
      end
    end
  end
end

-- Adds danger from proximity to obstacles
-- Simpler than raycasts - just marks danger around obstacle positions
-- @param ctx: context
-- @param agent_position: vec2 - current position
-- @param obstacles: array of vec2 positions
-- @param danger_radius: number - how close is dangerous
function danger.add_danger_from_proximity(ctx, agent_position, obstacles, danger_radius)
  danger_radius = danger_radius or 50

  for _, obstacle_pos in ipairs(obstacles) do
    local to_obstacle = vec2.sub(obstacle_pos, agent_position)
    local distance = vec2.length(to_obstacle)

    if distance < danger_radius and distance > 0.01 then
      -- Find slot pointing toward obstacle
      local slot_index = context_module.find_closest_slot(ctx, to_obstacle)

      -- Danger inversely proportional to distance
      local danger_value = 1.0 - (distance / danger_radius)

      ctx.danger[slot_index] = math.max(ctx.danger[slot_index], danger_value)
    end
  end
end

-- Adds directional danger - marks specific directions as dangerous
-- Useful for "don't go this way" constraints
-- @param ctx: context
-- @param danger_direction: vec2 - direction to mark as dangerous
-- @param danger_value: number - how dangerous (0-1)
-- @param spread: number - how many neighboring slots to affect
function danger.add_directional_danger(ctx, danger_direction, danger_value, spread)
  danger_value = danger_value or 1.0
  spread = spread or 1

  local center_slot = context_module.find_closest_slot(ctx, danger_direction)

  -- Mark center slot and neighbors
  for offset = -spread, spread do
    local slot_index = context_module.wrap_index(ctx, center_slot + offset)

    -- Falloff based on distance from center
    local falloff = 1.0 - (math.abs(offset) / (spread + 1))
    local final_danger = danger_value * falloff

    ctx.danger[slot_index] = math.max(ctx.danger[slot_index], final_danger)
  end
end

return danger
