-- noise.lua
-- Adds spatial noise to CBS interest map
-- Helps prevent robotic straight-line movement

local simplex = require("libs.cbs.simplex")

local noise = {}

-- Initialize noise generator
local generator = simplex.new(0)

-- Adds noise to the interest map
-- @param ctx: context
-- @param config: table {amount, scale, rate, seed, time}
function noise.add_spatial_noise(ctx, config)
  config = config or {}
  local amount = config.amount or 0.2
  local scale = config.scale or 1.0  -- Spatial scale (roughness around ring)
  local rate = config.rate or 0.5    -- Temporal rate
  local seed = config.seed or 0      -- Entity seed
  local time = config.time or 0      -- Accumulated time
  
  -- Re-init generator if seed changes (optimization: only if needed)
  if generator.seed ~= seed then
    generator = simplex.new(seed)
  end
  
  local time_offset = time * rate
  
  for i = 1, ctx.resolution do
    local slot_dir = ctx.slots[i]
    local angle = math.atan2(slot_dir.y, slot_dir.x)
    
    -- Sample noise along a circle in 2D noise space
    -- We animate the circle through Z (time) concept utilizing offset
    -- Since we only have 2D simplex, we move the circle center over time
    local nx = math.cos(angle) * scale + time_offset
    local ny = math.sin(angle) * scale + time_offset
    
    local n = simplex.noise2D(generator, nx, ny) -- Returns [-1, 1]
    
    -- Normalize to [0, 1] roughly (simplex can go slightly outside)
    local n_norm = (n + 1.0) * 0.5
    
    -- Apply noise to interest (additive or multiplicative?)
    -- Additive is safer for preserving strong interests
    -- But we want to perturb existing interest, not create interest where there is none?
    -- Actually, typically we want to add "wander desire" even if interest is uniform.
    
    -- Strategy: Add noise to base interest
    ctx.interest[i] = ctx.interest[i] + (n * amount)
    
    -- Clamp to [0, 1] (though solver handles >1 fine, <0 is bad)
    ctx.interest[i] = math.max(0.0, ctx.interest[i])
  end
end

return noise
