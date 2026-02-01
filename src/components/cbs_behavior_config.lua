--[[============================================================================
  COMPONENT: CBSBehaviorConfig

  PURPOSE: Per-entity overrides for behavior parameters.
  Values here override defaults from cbs_behavior_defs.lua.
  Organized by behavior name.

  FORMAT:
    {
      wander = {speed = 20, wander_weight = 0.8},
      flee = {speed = 100},
      pathfind = {path_lock_boost = 10},
    }
============================================================================]]--

local Concord = require("libs.Concord")

Concord.component("CBSBehaviorConfig", function(c, overrides)
  c.overrides = overrides or {}
end)
