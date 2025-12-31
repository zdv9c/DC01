-- systems/Physics.lua
local Concord = require "libs.Concord"
local HC = require "libs.HC"

local Physics = Concord.system({
    pool = {"Transform", "Collider"}
})

function Physics:init()
    self.collider = HC.new()
    self.shapes = {} -- Mapping entity -> shape
end

function Physics:entityAdded(e)
    local t = e.Transform
    local c = e.Collider
    
    local shape
    if c.type == "circle" then
        shape = self.collider:circle(t.x, t.y, c.radius or c.width/2)
    else
        shape = self.collider:rectangle(t.x, t.y, c.width, c.height)
    end
    
    self.shapes[e] = shape
    shape.parent = e -- Back reference
end

function Physics:entityRemoved(e)
    if self.shapes[e] then
        self.collider:remove(self.shapes[e])
        self.shapes[e] = nil
    end
end

function Physics:update(dt)
    -- 1. Sync Shapes with Transforms (in case they moved)
    for _, e in ipairs(self.pool) do
        local shape = self.shapes[e]
        local t = e.Transform
        if shape then
            shape:moveTo(t.x, t.y)
        end
    end
    
    -- 2. Resolve Collisions
    -- For this simple spec, we just prevent overlap (stop or slide).
    -- We can iterate dynamic entities and check against others.
    
    for _, e in ipairs(self.pool) do
        local shape = self.shapes[e]
        -- Only resolve for dynamic entities (like Player)
        -- We assume 'static' colliders don't move or resolve.
        if e.Collider.type == "dynamic" and shape then
            -- Check for collisions
            local collisions = self.collider:collisions(shape)
            for other_shape, mtv in pairs(collisions) do
                -- mtv = minimum translation vector (x, y) to separate
                if other_shape ~= shape then
                    shape:move(mtv.x, mtv.y)
                    
                    -- Update Transform to match resolved position
                    local x, y = shape:center()
                    e.Transform.x = x
                    e.Transform.y = y
                    
                    -- Simple slide/bump: we processed the resolution via MTV (separation).
                    -- If we want to kill velocity into the wall:
                    if e.Velocity then
                         -- Project velocity onto separate axis?
                         -- For simple top down, MTV separation often feels like "slide" enough for 16x16.
                         -- But ideally we zero out velocity component in normal direction.
                    end
                end
            end
        end
    end
end

function Physics:draw()
    -- Debug draw
    -- self.collider:draw() -- Warning: HC draw is slow/debug only
end

return Physics
