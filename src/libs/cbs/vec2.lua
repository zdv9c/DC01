-- vec2.lua
-- Minimal 2D vector utilities for CBS library
-- Pure functions, no dependencies

local vec2 = {}

-- Creates a new vector
-- @param x: number
-- @param y: number
-- @return {x: number, y: number}
function vec2.new(x, y)
  return {x = x or 0, y = y or 0}
end

-- Calculates vector length
-- @param v: vec2
-- @return number
function vec2.length(v)
  return math.sqrt(v.x * v.x + v.y * v.y)
end

-- Normalizes vector to unit length
-- @param v: vec2
-- @return vec2 - normalized vector, or {0,0} if zero length
function vec2.normalize(v)
  local len = vec2.length(v)
  if len < 0.0001 then
    return {x = 0, y = 0}
  end
  return {x = v.x / len, y = v.y / len}
end

-- Calculates dot product
-- @param a: vec2
-- @param b: vec2
-- @return number
function vec2.dot(a, b)
  return a.x * b.x + a.y * b.y
end

-- Scales vector by scalar
-- @param v: vec2
-- @param s: number - scalar
-- @return vec2
function vec2.scale(v, s)
  return {x = v.x * s, y = v.y * s}
end

-- Adds two vectors
-- @param a: vec2
-- @param b: vec2
-- @return vec2
function vec2.add(a, b)
  return {x = a.x + b.x, y = a.y + b.y}
end

-- Subtracts b from a
-- @param a: vec2
-- @param b: vec2
-- @return vec2
function vec2.sub(a, b)
  return {x = a.x - b.x, y = a.y - b.y}
end

-- Rotates vector by angle (radians)
-- @param v: vec2
-- @param angle: number - radians
-- @return vec2
function vec2.rotate(v, angle)
  local cos_a = math.cos(angle)
  local sin_a = math.sin(angle)
  return {
    x = v.x * cos_a - v.y * sin_a,
    y = v.x * sin_a + v.y * cos_a
  }
end

-- Calculates angle of vector in radians
-- @param v: vec2
-- @return number - angle in radians
function vec2.angle(v)
  return math.atan2(v.y, v.x)
end

-- Creates unit vector from angle
-- @param angle: number - radians
-- @return vec2 - unit vector
function vec2.from_angle(angle)
  return {x = math.cos(angle), y = math.sin(angle)}
end

return vec2
