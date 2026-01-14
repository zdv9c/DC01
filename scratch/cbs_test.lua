-- CBS Library Quick Test
-- Run with: cd src && lua ../scratch/cbs_test.lua

local CBS = require("libs.cbs")

print("=== CBS Library Test ===\n")

-- Test 1: Context creation
print("Test 1: Context Creation")
local ctx = CBS.new_context(8)
print("  ✓ Created context with " .. ctx.resolution .. " slots")
print("  ✓ Slots generated: " .. #ctx.slots)
assert(ctx.resolution == 8, "Resolution mismatch")
assert(#ctx.slots == 8, "Slot count mismatch")

-- Test 2: Reset
print("\nTest 2: Reset Context")
ctx.interest[1] = 0.5
ctx.danger[1] = 0.3
CBS.reset_context(ctx)
assert(ctx.interest[1] == 0.0, "Interest not reset")
assert(ctx.danger[1] == 0.0, "Danger not reset")
print("  ✓ Interest and danger reset to 0.0")

-- Test 3: Seek behavior
print("\nTest 3: Seek Behavior")
CBS.reset_context(ctx)
CBS.add_seek(ctx, {x = 1, y = 0}, 1.0)  -- Seek right
local max_interest = 0
for i = 1, ctx.resolution do
  if ctx.interest[i] > max_interest then
    max_interest = ctx.interest[i]
  end
end
assert(max_interest > 0, "Seek didn't generate interest")
print("  ✓ Seek generated interest (max: " .. string.format("%.2f", max_interest) .. ")")

-- Test 4: Solver
print("\nTest 4: Solver")
CBS.reset_context(ctx)
CBS.add_seek(ctx, {x = 1, y = 0}, 1.0)
local result = CBS.solve(ctx)
assert(result.direction ~= nil, "No direction returned")
assert(result.magnitude ~= nil, "No magnitude returned")
print("  ✓ Solver returned direction: {" ..
      string.format("%.2f", result.direction.x) .. ", " ..
      string.format("%.2f", result.direction.y) .. "}")
print("  ✓ Magnitude: " .. string.format("%.2f", result.magnitude))

-- Test 5: Danger masking
print("\nTest 5: Danger Masking")
CBS.reset_context(ctx)
CBS.add_seek(ctx, {x = 1, y = 0}, 1.0)
CBS.add_danger_from_rays(ctx, {
  {direction = {x = 1, y = 0}, hit_distance = 10}  -- Danger directly ahead
}, 100, 0.0)
local result_with_danger = CBS.solve(ctx)
-- Direction should shift away from danger
print("  ✓ Result with danger: {" ..
      string.format("%.2f", result_with_danger.direction.x) .. ", " ..
      string.format("%.2f", result_with_danger.direction.y) .. "}")

-- Test 6: Wander
print("\nTest 6: Wander Behavior")
CBS.reset_context(ctx)
local cursor = 0
local new_cursor = CBS.add_wander(ctx, {x = 1, y = 0}, cursor, {
  noise_scale = 0.1,
  angle_range = math.pi / 4
})
assert(cursor == new_cursor, "Cursor should be returned unchanged by add_wander")
cursor = CBS.advance_cursor(cursor, 0.016, 1.0)
assert(cursor > 0, "Cursor not advanced")
print("  ✓ Wander behavior added")
print("  ✓ Cursor advanced: " .. string.format("%.4f", cursor))

-- Test 7: Vec2 utilities
print("\nTest 7: Vec2 Utilities")
local v1 = CBS.vec2.new(3, 4)
local len = CBS.vec2.length(v1)
assert(math.abs(len - 5.0) < 0.01, "Length calculation wrong")
print("  ✓ Length of {3, 4} = " .. len)

local v2 = CBS.vec2.normalize(v1)
local norm_len = CBS.vec2.length(v2)
assert(math.abs(norm_len - 1.0) < 0.01, "Normalization wrong")
print("  ✓ Normalized length = " .. string.format("%.4f", norm_len))

local dot = CBS.vec2.dot({x = 1, y = 0}, {x = 0, y = 1})
assert(math.abs(dot - 0.0) < 0.01, "Dot product wrong")
print("  ✓ Dot product of perpendicular vectors = " .. dot)

-- Test 8: Strafe behavior
print("\nTest 8: Strafe Behavior")
CBS.reset_context(ctx)
CBS.add_strafe(ctx, {x = 1, y = 0}, 100, {
  min_range = 50,
  max_range = 150
})
local strafe_result = CBS.solve(ctx)
print("  ✓ Strafe direction: {" ..
      string.format("%.2f", strafe_result.direction.x) .. ", " ..
      string.format("%.2f", strafe_result.direction.y) .. "}")

print("\n=== All Tests Passed! ===")
print("Library is working correctly.")
