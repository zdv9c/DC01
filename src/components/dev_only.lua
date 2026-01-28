--[[============================================================================
  COMPONENT: DevOnly
  
  PURPOSE: Marker component for entities that only exist/render in dev mode
============================================================================]]--

local Concord = require "libs.Concord"

local DevOnly = Concord.component("DevOnly", function(c)
  -- No data needed, just a tag
end)

return DevOnly
