local Concord = require("Concord")

-- 1. System Definition
-- Define the system and the components it requires.
-- Note: 'system_' prefix is legacy, we prefer just the name now, but follow project conventions.
local SystemName = Concord.system({
    pool = {"ComponentA", "ComponentB"} -- Replace with actual components
})

-- 2. Pure Functions (Layer 3)
-- Pure domain logic. No side effects, no world access.
local function calculate_something(val_a, val_b, dt)
    return val_a + val_b * dt
end

-- 3. Orchestrators (Layer 2)
-- Composes pure functions. Receives data, returns data. No world access.
-- Helper to keep the shell clean.
local function process_entity(a_data, b_data, dt)
    local result = calculate_something(a_data.value, b_data.value, dt)
    
    -- Return changes purely as data
    return {
        new_value = result,
        should_emit_event = result > 100
    }
end

-- 4. System Shell (Layer 1)
-- The ONLY place with World access.
-- Reads components -> Calls Orchestrator -> Writes components/events.
function SystemName:update(dt)
    -- 'self.pool' is automatically populated by Concord based on the system definition
    for _, entity in ipairs(self.pool) do
        -- A. READ from World
        local a = entity.ComponentA
        local b = entity.ComponentB
        
        -- B. COMPUTE (via Orchestrator)
        -- Pass loose values or immutable tables, avoid passing the whole entity if possible
        local result = process_entity(a, b, dt)
        
        -- C. WRITE to World
        if result.new_value ~= a.value then
            a.value = result.new_value
            -- If components are immutable/schema-based replace the whole thing:
            -- entity:give("ComponentA", {value = result.new_value})
        end
        
        if result.should_emit_event then
            -- strict ECS: self:getWorld():emit("EventName", entity)
            -- or usage of a central event queue if defined in architecture
             if self:getWorld().event_queue then
                table.insert(self:getWorld().event_queue, {type = "ThresholdReached", entity = entity})
             end
        end
    end
end

return SystemName
