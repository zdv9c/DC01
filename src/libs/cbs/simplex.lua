-- simplex.lua
-- 2D Simplex Noise implementation for CBS library
-- Based on OpenSimplex noise algorithm

local simplex = {}

-- Permutation table
local perm = {}
local perm_mod12 = {}

-- Gradient vectors for 2D
local grad2 = {
  {1, 1}, {-1, 1}, {1, -1}, {-1, -1},
  {1, 0}, {-1, 0}, {1, 0}, {-1, 0},
  {0, 1}, {0, -1}, {0, 1}, {0, -1}
}

-- Skewing and unskewing factors for 2D
local F2 = 0.5 * (math.sqrt(3.0) - 1.0)
local G2 = (3.0 - math.sqrt(3.0)) / 6.0

-- Initialize permutation table with seed
-- @param seed: number
local function init_perm(seed)
  -- Use seed to generate permutation
  math.randomseed(seed)

  local p = {}
  for i = 0, 255 do
    p[i] = i
  end

  -- Fisher-Yates shuffle
  for i = 255, 1, -1 do
    local j = math.random(0, i)
    p[i], p[j] = p[j], p[i]
  end

  -- Extend to avoid buffer overflow
  for i = 0, 511 do
    perm[i] = p[i % 256]
    perm_mod12[i] = perm[i] % 12
  end
end

-- Dot product for gradients
-- @param g: gradient vector {x, y}
-- @param x: number
-- @param y: number
-- @return number
local function dot2(g, x, y)
  return g[1] * x + g[2] * y
end

-- Fast floor function
-- @param x: number
-- @return integer
local function fast_floor(x)
  return x > 0 and math.floor(x) or math.floor(x) - 1
end

-- Creates a new noise generator
-- @param seed: number (optional, defaults to 0)
-- @return noise generator table
function simplex.new(seed)
  init_perm(seed or 0)
  return {seed = seed or 0}
end

-- Generate 2D simplex noise
-- @param gen: noise generator (not used currently, but kept for API)
-- @param xin: number - x coordinate
-- @param yin: number - y coordinate
-- @return number - noise value in range [-1, 1]
function simplex.noise2D(gen, xin, yin)
  local n0, n1, n2 -- Noise contributions from the three corners

  -- Skew the input space to determine which simplex cell we're in
  local s = (xin + yin) * F2
  local i = fast_floor(xin + s)
  local j = fast_floor(yin + s)

  local t = (i + j) * G2
  local X0 = i - t -- Unskew the cell origin back to (x,y) space
  local Y0 = j - t
  local x0 = xin - X0 -- The x,y distances from the cell origin
  local y0 = yin - Y0

  -- Determine which simplex we are in
  local i1, j1 -- Offsets for second (middle) corner of simplex in (i,j) coords
  if x0 > y0 then
    i1 = 1
    j1 = 0
  else
    i1 = 0
    j1 = 1
  end

  -- Offsets for middle corner in (x,y) unskewed coords
  local x1 = x0 - i1 + G2
  local y1 = y0 - j1 + G2
  -- Offsets for last corner in (x,y) unskewed coords
  local x2 = x0 - 1.0 + 2.0 * G2
  local y2 = y0 - 1.0 + 2.0 * G2

  -- Work out the hashed gradient indices of the three simplex corners
  local ii = i % 256
  local jj = j % 256
  local gi0 = perm_mod12[ii + perm[jj]]
  local gi1 = perm_mod12[ii + i1 + perm[jj + j1]]
  local gi2 = perm_mod12[ii + 1 + perm[jj + 1]]

  -- Calculate the contribution from the three corners
  local t0 = 0.5 - x0 * x0 - y0 * y0
  if t0 < 0 then
    n0 = 0.0
  else
    t0 = t0 * t0
    n0 = t0 * t0 * dot2(grad2[gi0 + 1], x0, y0)
  end

  local t1 = 0.5 - x1 * x1 - y1 * y1
  if t1 < 0 then
    n1 = 0.0
  else
    t1 = t1 * t1
    n1 = t1 * t1 * dot2(grad2[gi1 + 1], x1, y1)
  end

  local t2 = 0.5 - x2 * x2 - y2 * y2
  if t2 < 0 then
    n2 = 0.0
  else
    t2 = t2 * t2
    n2 = t2 * t2 * dot2(grad2[gi2 + 1], x2, y2)
  end

  -- Add contributions from each corner to get the final noise value
  -- The result is scaled to return values in the interval [-1, 1]
  return 70.0 * (n0 + n1 + n2)
end

return simplex
