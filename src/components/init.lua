-- components/Transform.lua
-- Represents the position of an entity in the world.
local Concord = require "libs.Concord"

Concord.component("Transform", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

-- components/Velocity.lua
-- Represents the rate of change of position.
Concord.component("Velocity", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
    c.speed = 100 -- Default speed, can be overridden
    c.friction = 10 -- Friction factor
end)

-- components/Sprite.lua
-- Represents the visual representation of the entity (placeholder).
Concord.component("Sprite", function(c, color, radius)
    c.color = color or {1, 1, 1, 1}
    c.radius = radius or 8 -- 16x16 means radius 8
    c.type = "circle" -- visual type for debug
end)

-- components/Collider.lua
-- Represents the physical bounds for collision detection.
Concord.component("Collider", function(c, width, height, type)
    c.width = width or 16
    c.height = height or 16
    c.type = type or "dynamic" -- static or dynamic
    c.bounciness = 0
end)

-- components/PlayerControlled.lua
-- Tag component for entities controlled by the player.
Concord.component("PlayerControlled", function(c) end)

-- components/AIControlled.lua
-- Tag component for entities controlled by AI.
Concord.component("AIControlled", function(c) end)
