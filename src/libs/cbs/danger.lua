-- danger.lua
-- Danger map population from sensory input for CBS library

local vec2 = require("libs.cbs.vec2")
local context_module = require("libs.cbs.context")
local raycast = require("libs.cbs.raycast")

local danger = {}

-- Casts a ray for each CBS slot and applies danger based on hit distance
-- Also returns ray results for reuse (steering correction, visualization)
-- @param ctx: context
-- @param origin: {x, y} - ray origin position
-- @param obstacles: array of {x, y, radius}
-- @param config: {range, falloff, forward_direction} - optional config
--   - range: max raycast distance
--   - falloff: "linear" or "quadratic"
--   - forward_direction: {x, y} - enables rear-biased danger spread
-- @return array of {slot_index, angle, distance, hit} for each slot
function danger.cast_slot_rays(ctx, origin, obstacles, config)
  config = config or {}
  local max_range = config.range or 64
  local falloff = config.falloff or "linear"
  
  local ray_results = {}
  
  for i = 1, ctx.resolution do
    local slot_dir = ctx.slots[i]
    local angle = math.atan2(slot_dir.y, slot_dir.x)
    
    -- Cast ray in this slot's direction
    local hit = raycast.cast(origin, angle, max_range, obstacles)
    
    -- Calculate danger from hit distance
    local danger_value = 0
    local hit_distance = max_range
    
    if hit then
      hit_distance = hit.distance
      
      -- Convert distance to danger (closer = more dangerous)
      local normalized = hit_distance / max_range
      if falloff == "quadratic" then
        danger_value = 1.0 - (normalized * normalized)
      else -- linear
        danger_value = 1.0 - normalized
      end
      
      -- Apply danger to this slot and spread to neighbors
      -- If forward direction provided, spread BACKWARD (rear-biased)
      -- Otherwise spread symmetrically
      local SPREAD_ANGLE = math.pi / 2  -- 90 degrees total spread
      
      -- Apply primary danger
      ctx.danger[i] = math.max(ctx.danger[i], danger_value)
      
      -- Spread to other slots
      if danger_value > 0.1 then
        -- Get forward direction if available
        local forward_angle = nil
        if config.forward_direction then
          forward_angle = math.atan2(config.forward_direction.y, config.forward_direction.x)
        end
        
        for j = 1, ctx.resolution do
          if i ~= j then
            local other_dir = ctx.slots[j]
            local other_angle = math.atan2(other_dir.y, other_dir.x)
            local diff_angle = math.abs(other_angle - angle)
            
            -- Handle wrap around
            if diff_angle > math.pi then 
              diff_angle = 2 * math.pi - diff_angle 
            end
            
            if diff_angle < SPREAD_ANGLE then
              -- If we have a forward direction, only spread to rear arc
              local should_spread = true
              
              if forward_angle then
                -- Calculate if this slot is in the rear arc relative to forward direction
                -- Rear arc = slots more than 90° away from forward direction
                local forward_diff = other_angle - forward_angle
                if forward_diff > math.pi then forward_diff = forward_diff - 2 * math.pi end
                if forward_diff < -math.pi then forward_diff = forward_diff + 2 * math.pi end
                
                -- Only spread to slots in rear hemisphere (±90° to ±180° from forward)
                should_spread = math.abs(forward_diff) > math.pi / 2
              end
              
              if should_spread then
                -- Linear falloff based on angle difference
                local falloff_factor = 1.0 - (diff_angle / SPREAD_ANGLE)
                local spread_danger = danger_value * falloff_factor
                ctx.danger[j] = math.max(ctx.danger[j], spread_danger)
              end
            end
          end
        end
      end
    end
    
    -- Store ray result for reuse
    ray_results[i] = {
      slot_index = i,
      angle = angle,
      distance = hit_distance,
      hit = hit ~= nil,
      danger = danger_value
    }
  end
  
  return ray_results
end

-- Legacy: Adds danger from pre-computed raycast results
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
      -- Spread to neighb,ors
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
      -- Scale: 1.0 at 16px (collision), 0.0 at danger_radius
      -- Assume 16px is effectively "touching" (radius + radius)
      local collision_dist = 8
      local effective_range = math.max(0.001, danger_radius - collision_dist)
      local dist_factor = math.max(0.0, distance - collision_dist) / effective_range
      -- Convex falloff: Danger stays high longer, then drops
      -- Formula: 1.0 - (factor^2)
      danger_value = 1.0 - (dist_factor * dist_factor)
      
      -- Ensure strictly non-negative
      danger_value = math.max(0.0, danger_value)

      ctx.danger[slot_index] = math.max(ctx.danger[slot_index], danger_value)
    end
  end
  
  -- Apply dilation to spread danger (simulates agent width)
  -- Sigma 1.2 spreads danger but keeps 45-degree paths cleaner
  danger.apply_dilation(ctx, 1.2)
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
