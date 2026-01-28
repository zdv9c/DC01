-- danger.lua
-- Danger map population from sensory input for CBS library

local vec2 = require("libs.cbs.vec2")
local context_module = require("libs.cbs.context")
local raycast = require("libs.cbs.raycast")

local danger = {}

-- Casts a ray for each CBS slot and applies danger based on hit distance
-- Also returns ray results for reuse (visualization, debug)
-- @param ctx: context
-- @param origin: {x, y} - ray origin position
-- @param obstacles: array of {x, y, radius}
-- @param config: {range, falloff, radius} - optional config
--   - range: max raycast distance (default 64)
--   - falloff: "linear", "quadratic", or "logarithmic" (default "linear")
--   - radius: agent radius (default 0)
-- @return array of {slot_index, angle, distance, hit, danger} for each slot
function danger.cast_slot_rays(ctx, origin, obstacles, config)
  config = config or {}
  local max_range = config.range or 64
  local falloff = config.falloff or "linear"
  local agent_radius = config.radius or 0
  
  -- Effective range is from the agent's edge to max_range
  local effective_range = math.max(1, max_range - agent_radius)
  
  -- Danger spread angle (±22.5° = one slot on each side for 16-slot resolution)
  -- Variable spread: Closer objects spread danger wider
  local BASE_SPREAD = math.pi / 4  -- 45 degrees 
  
  local ray_results = {}
  
  for i = 1, ctx.resolution do
    local slot_dir = ctx.slots[i]
    local angle = math.atan2(slot_dir.y, slot_dir.x)
    
    -- Cast ray in this slot's direction
    local hit = raycast.cast(origin, angle, max_range, obstacles, config.filter)
    
    -- Calculate danger from hit distance
    local danger_value = 0
    local hit_distance = max_range
    
    if hit then
      hit_distance = hit.distance
      
      -- Convert distance to "Gap" (distance between boundaries)
      -- 1.0 danger occurs when gap is 0 (physical contact)
      local gap = math.max(0, hit_distance - agent_radius)
      local normalized = math.min(1.0, gap / effective_range)
      
      if falloff == "quadratic" then
        danger_value = 1.0 - (normalized * normalized)
      elseif falloff == "logarithmic" then
        -- Strong repulsion that stays high longer (Convex/Hard Shell)
        danger_value = 1.0 - (normalized * normalized * normalized * normalized)
      else -- linear
        danger_value = 1.0 - normalized
      end
      
      -- Apply primary danger to this slot
      ctx.danger[i] = math.max(ctx.danger[i], danger_value)
      
      -- Spread danger to neighboring slots
      -- Closer objects spread WIDER to prevent clipping edges
      if danger_value > 0.05 then
        -- Spread up to 90 degrees total if nearly touching
        local spread_factor = 0.5 + 0.5 * danger_value
        local current_spread = BASE_SPREAD * spread_factor
        
        for j = 1, ctx.resolution do
          if i ~= j then
            local other_dir = ctx.slots[j]
            local other_angle = math.atan2(other_dir.y, other_dir.x)
            local diff_angle = math.abs(other_angle - angle)
            
            -- Handle wrap around
            if diff_angle > math.pi then 
              diff_angle = 2 * math.pi - diff_angle 
            end
            
            if diff_angle < current_spread then
              -- Linear falloff based on angle difference
              local angle_factor = 1.0 - (diff_angle / current_spread)
              local spread_danger = danger_value * angle_factor
              ctx.danger[j] = math.max(ctx.danger[j], spread_danger)
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

-- Resolves symmetric deadlocks (dead-center obstacles) by biasing the clearer side
-- @param ctx: context
-- @param threshold: number - danger threshold to trigger deadlock check (default 0.5)
-- @param bias: number - interest bonus to add to the clearer side (default 0.5)
-- Resolves deadlocks by biasing towards the target direction when forward is blocked
-- @param ctx: context
-- @param forward_dir: vec2 - current agent heading
-- @param target_dir: vec2 - desired path direction
-- @param threshold: number - danger threshold (default 0.5)
-- @param bias: number - interest bonus (default 0.5)
-- @param side: number - current persistent side decision (0, 1, -1)
-- @return number - updated side decision
function danger.resolve_deadlocks(ctx, forward_dir, target_dir, threshold, bias, side)
  threshold = threshold or 0.5
  bias = bias or 0.5
  side = side or 0
  
  -- 1. Find the slot closest to the TARGET (Where we want to go)
  local target_slot = context_module.find_closest_slot(ctx, target_dir)
  
  -- 2. Check if "The Way" is blocked
  -- If the direct path to target has danger, we need to pick a side
  local d_target = ctx.danger[target_slot]
  
  if d_target < threshold then
    return 0 -- Return 0 to indicate no deadlock (clears persistence)
  end
  
  -- 3. Determine which side to flank
  -- If we already have a committed side, stick to it.
  -- Otherwise, use Cross Product of Forward vs Target to see which side we are ALREADY favoring.
  -- LÖVE2D (Y-down): Positive Cross = Target is to the Right of Forward.
  -- To stay on our current side (Left), we add a negative offset to the target slot.
  if side == 0 then
    local cross = forward_dir.x * target_dir.y - forward_dir.y * target_dir.x
    side = (cross >= 0) and -1 or 1
  end
  
  -- 4. Inject bias into flank slots
  -- We boost slots 45-90 degrees to the chosen side relative to the TARGET vector
  -- This creates a "Virtual Target" to the side of the obstacle
  for i = 2, 4 do -- Offset 2,3,4 slots (approx 45-90 deg)
    local idx = context_module.wrap_index(ctx, target_slot + (i * side))
    ctx.interest[idx] = ctx.interest[idx] + bias
  end
  
  return side
end

return danger
