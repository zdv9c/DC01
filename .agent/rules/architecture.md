---
trigger: always_on
---

# ECS Clean Architecture Pattern

## Core Principle
All dependencies are explicit. All world access is in system shells. All computation is pure.

## Layer Structure

### Layer 1: System Shell
- **Location**: Top of each system file (e.g., `movement.update`, `combat.update`)
- **Responsibilities**:
  - Query components from world
  - Extract component data into local variables
  - Call orchestrators with explicit parameters
  - Write returned results back to world
  - Enqueue events to event queue
- **Constraints**:
  - ONLY layer that reads/writes world state
  - Does NOT contain computation logic
  - Does NOT call other systems
- **Pattern**:
```lua
function system.update(world, dt, config)
  for entity in world:query(ComponentA, ComponentB) do
    local a = world:get(entity, ComponentA)
    local b = world:get(entity, ComponentB)
    
    local result = orchestrator(a, b, config.value, dt)
    
    world:set(entity, ComponentA, result.new_a)
    if result.events then
      for _, event in ipairs(result.events) do
        world:enqueue_event(event)
      end
    end
  end
end
```

### Layer 2: Orchestrators
- **Location**: Below shell in system file
- **Responsibilities**:
  - Compose pure functions to solve domain problems
  - Return computed results as data structures
  - Return events to be enqueued
- **Constraints**:
  - Pure or near-pure (no I/O, no world access)
  - ALL dependencies passed as parameters
  - Returns data only, never writes
- **Pattern**:
```lua
function compute_physics_step(pos, vel, mass, dt, gravity)
  local accel = calculate_acceleration(gravity, mass)
  local new_vel = apply_acceleration(vel, accel, dt)
  local new_pos = apply_velocity(pos, new_vel, dt)
  return {position = new_pos, velocity = new_vel}
end
```

### Layer 3: Pure Functions
- **Location**: Bottom of system file or utility modules
- **Responsibilities**:
  - Mathematical transformations
  - Logical operations
  - Data transformations
- **Constraints**:
  - Absolutely pure (no side effects)
  - No world access
  - No I/O
  - Values in, values out
- **Pattern**:
```lua
function calculate_acceleration(gravity, mass)
  return vec2(0, gravity / mass)
end
```

## Data Flow Rules

### Read Phase
- System shell queries world for entities with required components
- System shell extracts component data into local variables
- No other layer reads from world

### Compute Phase
- Shell calls orchestrators with explicit parameters
- Orchestrators call pure functions
- Values flow down as parameters
- Results flow up as return values

### Write Phase
- Orchestrators return data structures to shell
- Shell writes results back to world
- Shell enqueues events
- No other layer writes to world

## System Communication

### Prohibited
- System A calling system B directly
- Systems sharing mutable state
- Hidden communication channels

### Required
- Systems emit events via return values
- System scheduler processes event queue
- Systems react to events in next frame
- All communication visible in event queue

## Dependency Management

### Config Injection
- World-level configuration (gravity, bounds, game rules) injected at system initialization
- NOT grabbed from context during update
- Passed as explicit parameter to orchestrators when needed

### Component Dependencies
- Declared in query: `world:query(Position, Velocity, Mass)`
- If system needs component, it MUST appear in query
- Query serves as dependency declaration

### Cross-Cutting Concerns
- Injected at system creation, not retrieved during update
- Examples: physics config, damage tables, world bounds
- Pattern: `system.new(config) -> returns system with update(world, dt)`

## Code Smell Detection

### Shell Level
- **Smell**: Computation logic in shell
- **Fix**: Extract to orchestrator
- **Smell**: Shell reading components not in query
- **Fix**: Add component to query or remove read

### Orchestrator Level
- **Smell**: More than 7 parameters
- **Fix**: Group related data into value object, or split orchestrator
- **Smell**: Orchestrator accessing world
- **Fix**: Move world access to shell, pass data as parameter
- **Smell**: Orchestrator with I/O
- **Fix**: Move I/O to shell

### Pure Function Level
- **Smell**: Side effects
- **Fix**: Remove side effects, return values instead
- **Smell**: Global state access
- **Fix**: Pass as parameter

## Testing Strategy

### Shell Testing
- Integration tests
- Mock world with test components
- Verify correct reads/writes
- Verify events enqueued

### Orchestrator Testing
- Unit tests
- No mocking needed
- Pass test values, assert returned values
- Test edge cases with extreme inputs

### Pure Function Testing
- Property-based tests
- Mathematical correctness
- No setup required

## Prohibited Patterns

### Context Objects
- Do NOT pass context object with world access to orchestrators
- Hidden dependencies violate explicit parameter principle

### God Functions
- Do NOT accumulate responsibilities in one orchestrator
- Split when parameter count exceeds 7 or intent becomes unclear

### Direct System Coupling
- Do NOT call system B from system A
- Use events for all cross-system communication

### Hidden World Access
- Do NOT access world state below shell layer
- All reads/writes confined to shell

### Implicit Dependencies
- Do NOT grab configuration from global state
- All dependencies in function signature

## Scaling Pattern

### Adding New Behavior
1. Identify required components
2. Create system shell with component query
3. Extract component data
4. Create orchestrator with explicit parameters
5. Implement pure functions for computation
6. Return results to shell
7. Shell writes results

### Adding Cross-System Logic
1. System A computes result
2. System A returns event in result structure
3. Shell enqueues event
4. System scheduler processes events
5. System B queries for relevant events
6. System B reacts to events

### Adding Dependencies
1. Add parameter to orchestrator signature
2. Shell extracts dependency from world/config
3. Shell passes as parameter
4. Dependency now visible and trackable

## Architecture Invariants

These MUST remain true:
- Only shells access world state
- All orchestrators are pure or near-pure
- All dependencies are explicit parameters
- Systems do not call systems
- Events are the only cross-system communication
- Component queries declare all dependencies
- Pure functions have zero side effects

## Entity-Component Rules

### Entities
- Entities are opaque IDs (strings or numbers)
- Entities have NO behavior, NO methods, NO state beyond their ID
- Entities are containers for components, nothing more

### Components
- Components are pure data structures (Lua tables)
- Components have NO methods, NO behavior
- Components represent facts about entities
- One component type per concern

### Component Design Rules

**Single Responsibility**: Each component represents one aspect of an entity
- Good: `Position {x, y}`, `Velocity {x, y}`, `Health {current, max}`
- Bad: `GameObject {x, y, vx, vy, hp, max_hp, sprite, ...}`

**No Computed Values**: Components store raw data, not derived state
- Good: `Velocity {x, y}` - systems compute speed when needed
- Bad: `Velocity {x, y, magnitude}` - magnitude is derived from x, y

**No Cross-References**: Components don't reference other entities directly
- Good: System finds related entities via queries
- Bad: `Parent {entity_id}` - creates hidden coupling
- Exception: If the relationship IS the data (like `AttachedTo {parent_id}`)

**Value Types Only**: Components contain primitives, vectors, enums
- Good: `Position {x: number, y: number}`
- Good: `Stats {attack: number, defense: number}`
- Bad: `Inventory {items: Item[]}` where Item is a complex object
- Solution: Items are entities with components, Inventory stores IDs

### Component Naming
- **Pattern**: Noun describing what it represents
- **Examples**: `Position`, `Velocity`, `Health`, `Sprite`, `PlayerControlled`
- **Not**: `Moveable` (behavior), `HasHealth` (verb), `Manager` (system name)

### Component Granularity

**Prefer Fine-Grained**: Small, focused components over large, kitchen-sink components
```lua
-- GOOD: Fine-grained
Position {x, y}
Velocity {dx, dy}
Acceleration {dx, dy}

-- BAD: Coarse-grained
Movement {
  x, y,           -- position
  dx, dy,         -- velocity  
  ddx, ddy,       -- acceleration
  max_speed,      -- constraint
  friction        -- physics property
}
```

Fine-grained components let systems query exactly what they need:
- Movement system: `query(Position, Velocity)`
- Rendering system: `query(Position, Sprite)`
- Physics system: `query(Position, Velocity, Mass)`

Coarse-grained forces systems to read data they don't need, hiding dependencies.

**When to Group**: Only when data is truly inseparable
```lua
-- GOOD: These are always used together
Health {current, max}
Stats {attack, defense, speed}

-- BAD: These are used independently
Transform {x, y, rotation, scale_x, scale_y}
-- Should be: Position {x, y} and Orientation {rotation, scale_x, scale_y}
```

### Component Schema Pattern

Define components as typed schemas for validation:
```lua
-- components/position.lua
return {
  name = "Position",
  schema = {
    x = "number",
    y = "number"
  },
  default = function()
    return {x = 0, y = 0}
  end
}
```

Benefits:
- Self-documenting
- Runtime validation possible
- Serialization is obvious
- Default values prevent nil errors

### Identifying New Components

When iterating, add components when:
1. A system needs to store state about an entity
2. Multiple systems need to share data about an entity
3. An entity needs a new capability that's orthogonal to existing ones

Don't add components when:
1. Data is temporary (use local variables)
2. Data is derived from other components (compute on demand)
3. Data is global config (use injected config)

### Anti-Patterns

**God Components**: Component with 10+ fields doing multiple jobs
- Smell: Many systems only use 2-3 fields each
- Fix: Split into focused components

**Computed Components**: Storing derived state
- Smell: Component values must be "kept in sync" 
- Fix: Compute from source data

**Behavioral Components**: Methods or function references
- Smell: Component has `update()` or `on_event()` fields
- Fix: Move behavior to systems

**Implicit Dependencies**: Component assumes others exist
- Smell: System crashes when expected component missing
- Fix: Query explicitly, handle absence gracefully

## Entity Archetypes (Optional Pattern)

For rapid prototyping, define entity templates:
```lua
-- entities/player.lua
return {
  components = {
    Position = {x = 0, y = 0},
    Velocity = {x = 0, y = 0},
    Health = {current = 100, max = 100},
    PlayerControlled = {},
    Sprite = {image = "player.png"}
  }
}

-- Spawn with:
local player = world:spawn(require("entities.player"))
```

Archetypes are templates, not classes. They just pre-fill component data.

## Component Discovery During Iteration

When building a vertical slice:

1. **Start with obvious components**: Position, Velocity for movement
2. **Add components when systems need them**: Collision system needs Collider component
3. **Split components when they're doing too much**: Transform splits into Position + Rotation
4. **Merge components when always used together**: FirstName + LastName → Name {first, last}

The architecture tells you when components are wrong:
- System has huge query? Components too fine.
- System only uses 20% of component? Component too coarse.
- Multiple systems write same component? Missing a coordinating system.

Violation of any invariant indicates technical debt.