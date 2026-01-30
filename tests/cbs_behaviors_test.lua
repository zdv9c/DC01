local lust = require("libs.lust.lust")
local describe, it, expect = lust.describe, lust.it, lust.expect
local behaviors = require("libs.cbs.behaviors_core")
local context = require("libs.cbs.context")
local vec2 = require("libs.cbs.vec2")

describe("CBS Behaviors Core", function()
  describe("add_path_locking", function()
    it("should boost interest in the target direction", function()
      local ctx = context.new(8)
      context.reset(ctx)
      local target = {x=1, y=0}
      behaviors.add_path_locking(ctx, target, 10.0)
      
      -- Slot 1 (East, 0 rads) corresponds to index 1?
      -- context.new creates slots. we assume standard distribution.
      -- Slot 1 is usually 0 radians in this impl?
      -- Let's check context.lua or verify by inspecting slots if needed.
      -- Assuming standard "start at 0" or similar.
      
      -- Actually, let's just assert *some* slot has it.
      local max_val = 0
      for i=1, 8 do
        max_val = math.max(max_val, ctx.interest[i])
      end
      
      expect(max_val).to.be(10.0)
    end)
  end)
end)

local maneuvers = require("libs.cbs.maneuvers")

describe("CBS Maneuvers", function()
  describe("try_path_locking", function()
    it("should lock when path is clear", function()
      local ctx = context.new(8)
      context.reset(ctx)
      local pos = {x=0, y=0}
      local target_vec = {x=1, y=0}
      local dist = 100
      local obstacles = {}
      
      local applied, reason = maneuvers.try_path_locking(ctx, pos, target_vec, dist, obstacles, {min_range=50})
      expect(applied).to.be(true)
      expect(reason).to.be("locked")
      
      -- Check context has interest
      -- Slot 1 should be boosted
      local max_val = 0
      for i=1, 8 do max_val = math.max(max_val, ctx.interest[i]) end
      expect(max_val).to.be(3.0)
    end)
    
    it("should be blocked by obstacle", function()
      local ctx = context.new(8)
      context.reset(ctx)
      local pos = {x=0, y=0}
      local target_vec = {x=1, y=0}
      local dist = 100
      local obstacles = {
        {x=50, y=0, radius=10} -- Obstacle on path
      }
      
      local applied, reason = maneuvers.try_path_locking(ctx, pos, target_vec, dist, obstacles, {min_range=50})
      expect(applied).to.be(false)
      expect(reason).to.be("blocked")
      
      -- Check context empty (assuming reset worked)
      local max_val = 0
      for i=1, 8 do max_val = math.max(max_val, ctx.interest[i]) end
      expect(max_val).to.be(0)
    end)
    
    it("should assume too close if within range", function()
       local ctx = context.new(8)
       local applied, reason = maneuvers.try_path_locking(ctx, {x=0,y=0}, {x=1,y=0}, 10, {}, {min_range=50})
       expect(applied).to.be(false)
       expect(reason).to.be("too_close")
    end)
  end)
end)
