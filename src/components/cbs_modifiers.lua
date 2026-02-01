--[[============================================================================
  COMPONENT: CBSModifiers

  PURPOSE: Optional post-behavior modifiers for subtle movement variation.
  Applied after primary behavior, before CBS solve.

  FORMAT:
    {
      {type = "sway", weight = 0.1, rate = 0.5},
      {type = "obstacle_sensitivity", multiplier = 1.5},
      {type = "speed_noise", amount = 0.2, rate = 0.5},
    }
============================================================================]]--

local Concord = require("libs.Concord")

Concord.component("CBSModifiers", function(c, modifiers)
  c.modifiers = modifiers or {}
end)
