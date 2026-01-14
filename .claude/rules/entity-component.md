---
trigger: always_on
---

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