-- systems/Input.lua
local Concord = require "libs.Concord"
local Baton = require "libs.baton.baton" -- Adjust path if needed

local Input = Concord.system({
    pool = {"PlayerControlled", "Velocity"}
})

function Input:init()
    self.input = Baton.new {
        controls = {
            left = {'key:left', 'key:a', 'axis:leftx-', 'button:dpleft'},
            right = {'key:right', 'key:d', 'axis:leftx+', 'button:dpright'},
            up = {'key:up', 'key:w', 'axis:lefty-', 'button:dpup'},
            down = {'key:down', 'key:s', 'axis:lefty+', 'button:dpdown'},
            action = {'key:x', 'button:a'},
        },
        pairs = {
            move = {'left', 'right', 'up', 'down'}
        },
        joystick = love.joystick.getJoysticks()[1],
    }
end

function Input:update(dt)
    self.input:update()

    for _, e in ipairs(self.pool) do
        local x, y = self.input:get 'move'
        
        -- Wishful thinking: we just set the target velocity here?
        -- Or we accelerate?
        -- For robust inertial movement, we might assume the entity accelerates towards the input direction.
        
        local speed = e.Velocity.speed
        
        -- Simple acceleration logic:
        -- If input, accelerate. If no input, friction handles it (in Movement system).
        if x ~= 0 or y ~= 0 then
            e.Velocity.x = e.Velocity.x + x * speed * dt * 10 -- Arbitrary acceleration factor
            e.Velocity.y = e.Velocity.y + y * speed * dt * 10
        end
    end
end

return Input
