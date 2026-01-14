-- behaviors.lua
-- Interest generation functions for CBS library

local vec2 = require("libs.cbs.vec2")
local simplex = require("libs.cbs.simplex")

local behaviors = {}

-- Simplex noise generator (shared for all wander behaviors)
local noise_gen = simplex.new(12345)

-- Adds seek interest - maximizes movement toward target
-- @param ctx: context
-- @param target_direction: vec2 - direction to seek
-- @param weight: number - strength multiplier (default 1.0)
function behaviors.add_seek(ctx, target_direction, weight)
  weight = weight or 1.0
  local target_norm = vec2.normalize(target_direction)

  for i = 1, ctx.resolution do
    local dot_product = vec2.dot(ctx.slots[i], target_norm)
    -- Only positive dot products (forward directions)
    local interest_value = math.max(0.0, dot_product) * weight
    ctx.interest[i] = ctx.interest[i] + interest_value
  end
end

-- Adds flee interest - maximizes movement away from target
-- @param ctx: context
-- @param target_direction: vec2 - direction to flee from
-- @param weight: number - strength multiplier (default 1.0)
function behaviors.add_flee(ctx, target_direction, weight)
  weight = weight or 1.0
  -- Flee is just seek in opposite direction
  local opposite = vec2.scale(target_direction, -1.0)
  behaviors.add_seek(ctx, opposite, weight)
end

-- Adds strafe interest - maximizes perpendicular movement
-- @param ctx: context
-- @param target_direction: vec2 - direction to strafe around
-- @param distance: number - distance to target
-- @param params: table - {min_range, max_range, seek_weight, flee_weight}
function behaviors.add_strafe(ctx, target_direction, distance, params)
  params = params or {}
  local min_range = params.min_range or 50
  local max_range = params.max_range or 200
  local seek_weight = params.seek_weight or 1.0
  local flee_weight = params.flee_weight or 1.0

  -- Distance-based blending
  if distance > max_range then
    -- Far away: use seek
    behaviors.add_seek(ctx, target_direction, seek_weight)

  elseif distance < min_range then
    -- Too close: use flee
    behaviors.add_flee(ctx, target_direction, flee_weight)

  else
    -- In range: use strafe
    local target_norm = vec2.normalize(target_direction)

    -- Blend factor: 0.0 at max_range, 1.0 at min_range
    local blend = (max_range - distance) / (max_range - min_range)
    local strafe_weight = blend

    for i = 1, ctx.resolution do
      local dot_product = vec2.dot(ctx.slots[i], target_norm)
      -- Interest peaks at perpendicular (dot = 0)
      local strafe_value = (1.0 - math.abs(dot_product)) * strafe_weight
      ctx.interest[i] = ctx.interest[i] + strafe_value
    end
  end
end

-- Adds wander interest - coherent meandering using noise
-- @param ctx: context
-- @param forward_direction: vec2 - agent's current forward direction
-- @param noise_cursor: number - current noise position
-- @param params: table - {noise_scale, angle_range, weight}
-- @return number - new noise cursor value
function behaviors.add_wander(ctx, forward_direction, noise_cursor, params)
  params = params or {}
  local noise_scale = params.noise_scale or 0.1
  local angle_range = params.angle_range or math.pi / 4  -- ±45 degrees
  local weight = params.weight or 1.0

  -- Sample noise to get angular offset
  local noise_value = simplex.noise2D(noise_gen, noise_cursor * noise_scale, 0)
  -- noise_value is in [-1, 1], map to angle range
  local angle_offset = noise_value * angle_range

  -- Rotate forward direction by noise-driven angle
  local wander_direction = vec2.rotate(forward_direction, angle_offset)

  -- Apply seek toward wander direction
  behaviors.add_seek(ctx, wander_direction, weight)

  -- Return updated cursor (caller decides how to advance it)
  return noise_cursor
end

-- Adds interest with tethering - returns to spawn when too far
-- @param ctx: context
-- @param current_position: vec2 - agent's current position
-- @param spawn_position: vec2 - spawn/home position
-- @param leash_radius: number - max distance from spawn
-- @param return_weight: number - strength of return pull (default 1.0)
function behaviors.add_tether(ctx, current_position, spawn_position, leash_radius, return_weight)
  return_weight = return_weight or 1.0

  local to_spawn = vec2.sub(spawn_position, current_position)
  local distance = vec2.length(to_spawn)

  if distance > leash_radius then
    -- Outside leash: pull back to spawn
    local pull_strength = ((distance - leash_radius) / leash_radius) * return_weight
    behaviors.add_seek(ctx, to_spawn, pull_strength)
  end
end

return behaviors
