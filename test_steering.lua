local steering = require("src.libs.cbs.steering")
local vec2 = require("src.libs.cbs.vec2")

local h1 = {x = 1, y = 0}
local t1 = {x = 0, y = 1}
local dt = 0.016
local rate = 10.0

print("Testing smooth_turn...")
local new_h = steering.smooth_turn(h1, t1, dt, rate)
print("New heading:", new_h.x, new_h.y)
print("Angle current:", vec2.angle(h1))
print("Angle target:", vec2.angle(t1))
print("Angle new:", vec2.angle(new_h))
print("Test complete.")
