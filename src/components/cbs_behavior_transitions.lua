--[[============================================================================
  COMPONENT: CBSBehaviorTransitions

  PURPOSE: Declarative transition rules for behavior state machine.
  Transitions are evaluated by cbs_transitions system.

  FORMAT:
    {
      {
        from = "wander",           -- Source behavior (or "any")
        to = "flee",               -- Target behavior
        condition = "hp_low",      -- String shortcut or condition table
        blend_duration = 0.3,      -- Seconds (default: 0.2)
        cooldown = 0.5,            -- Seconds before re-evaluation (default: 0.1)
        priority = 10,             -- Higher = checked first (default: 0)
      },
    }
============================================================================]]--

local Concord = require("libs.Concord")

Concord.component("CBSBehaviorTransitions", function(c, transitions)
  c.transitions = transitions or {}
end)
