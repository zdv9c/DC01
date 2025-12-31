-- systems/Movement.lua
local Concord = require "libs.Concord"

local Movement = Concord.system({
    pool = {"Transform", "Velocity"}
})

function Movement:update(dt)
    for _, e in ipairs(self.pool) do
        local vel = e.Velocity
        local pos = e.Transform
        
        -- Apply Friction
        -- Friction direction is opposite to velocity
        -- Linear drag: v = v * (1 - friction * dt)
        
        local friction = vel.friction
        vel.x = vel.x * (1 - math.min(friction * dt, 1))
        vel.y = vel.y * (1 - math.min(friction * dt, 1))
        
        -- Clamp velocity to max speed (optional, but good practice)
        -- max_speed could be in Velocity component
        local speed_sq = vel.x^2 + vel.y^2
        local max_speed = vel.speed * 2 -- Allow some sprint or initial burst? Or just max = speed
        if speed_sq > max_speed^2 then
            local s = math.sqrt(speed_sq)
            vel.x = (vel.x / s) * max_speed
            vel.y = (vel.y / s) * max_speed
        end
        
        -- Apply Velocity to Position
        pos.x = pos.x + vel.x * dt
        pos.y = pos.y + vel.y * dt
        
        -- If we had a Collider, we'd update it here or in Physics
    end
end

return Movement
