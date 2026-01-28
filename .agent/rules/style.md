# Code Style Guide - Agent Rules

## Core Philosophy
Code reads like a well-organized book. A developer returning after 6 months should understand intent in 30 seconds.

## File Structure Template
```lua
--[[============================================================================
  SYSTEM: Movement Physics
  
  PURPOSE: Applies velocity, gravity, and collision to moving entities
  
  DATA CONTRACT:
    READS:  Position, Velocity, Mass, Collider
    WRITES: Position, Velocity
    EMITS:  collision_event
    CONFIG: world_gravity, world_bounds
  
  UPDATE ORDER: After input, before rendering
============================================================================]]--

local movement = {}

-- DEPENDENCIES
local vec2 = require("lib.vector2")
local GRAVITY = 9.8

--[[----------------------------------------------------------------------------
  SHELL LAYER - World Access Only
----------------------------------------------------------------------------]]--

function movement.update(world, dt, config)
  -- Implementation
end

--[[----------------------------------------------------------------------------
  ORCHESTRATION LAYER - Pure Coordination
----------------------------------------------------------------------------]]--

-- Returns new physics state after applying forces
-- @param pos: vec2 - current position
-- @param vel: vec2 - current velocity  
-- @param mass: number - entity mass
-- @param dt: number - delta time
-- @param gravity: number - gravitational constant
-- @return {position: vec2, velocity: vec2}
function compute_physics_step(pos, vel, mass, dt, gravity)
  -- Implementation
end

--[[----------------------------------------------------------------------------
  PURE FUNCTIONS - Math & Logic
----------------------------------------------------------------------------]]--

-- Calculates acceleration from gravity and mass
-- @param gravity: number - gravitational constant
-- @param mass: number - object mass
-- @return vec2 - acceleration vector
function calculate_acceleration(gravity, mass)
  -- Implementation
end

return movement
```

## Naming Conventions

### System Files
- **Pattern**: `<domain>.lua`
- **Examples**: `movement.lua`, `combat.lua`
- **Rule**: Pure domain names for systems.

### System Table
- **Pattern**: Single-word domain name matching filename.
- **Examples**: `movement`, `combat`, `rendering`

### Shell Functions
- **Pattern**: `system.update(world, dt, config)`
- **Fixed Names**: `update`, `init`, `draw` (match LÖVE2D callbacks)
- **Rule**: Never rename - consistency across all systems

### Orchestrator Functions
- **Pattern**: `compute_<what_it_calculates>`
- **Examples**: `compute_physics_step`, `compute_damage_result`, `compute_pathfinding_route`
- **Rule**: Starts with `compute_`, describes return value

### Pure Functions
- **Pattern**: `<verb>_<noun>` (action-oriented)
- **Examples**: `calculate_acceleration`, `apply_velocity`, `clamp_to_bounds`, `normalize_vector`
- **Rule**: Verb first, crystal clear purpose

### Variables

**Local Variables (< 10 line scope)**: Short, clear abbreviations
- `pos` (position), `vel` (velocity), `accel` (acceleration)
- `hp` (health points), `dmg` (damage), `def` (defense)
- `ent` (entity), `comp` (component)

**Local Variables (> 10 line scope)**: Full descriptive names
- `player_position`, `enemy_velocity`, `collision_normal`
- `total_damage`, `final_health`, `updated_state`

**Function Parameters**: Full names unless universally understood
- Good: `dt` (delta time), `pos`, `vel`, `entity_id`, `component_data`
- Bad: `d`, `p`, `v`, `x` (ambiguous)

**Return Values**: Named tables with explicit keys
```lua
return {
  position = new_pos,
  velocity = new_vel,
  events = collision_events
}
```

**Loop Variables**: `i`, `j`, `k` acceptable for numeric loops. For entity loops use `entity` or `ent`, not `e`.

### Constants
- **Pattern**: `SCREAMING_SNAKE_CASE`
- **Examples**: `MAX_SPEED`, `GRAVITY`, `COLLISION_LAYERS`
- **Location**: Top of file after dependencies

## Comment Conventions

### File Header Block
```lua
--[[============================================================================
  SYSTEM: [Name]
  
  PURPOSE: [One sentence describing what this system does]
  
  DATA CONTRACT:
    READS:  [Component, Component]
    WRITES: [Component, Component]
    EMITS:  [event_type, event_type]
    CONFIG: [config_field, config_field]
  
  UPDATE ORDER: [When this runs relative to other systems]
============================================================================]]--
```

**Rules**:
- Every system file MUST have this header
- Update DATA CONTRACT immediately when changing component access
- PURPOSE is one sentence max

### Section Dividers
```lua
--[[----------------------------------------------------------------------------
  SECTION NAME - Brief Description
----------------------------------------------------------------------------]]--
```

Use for layer boundaries and logical groupings. Max 3-4 sections per file.

### Function Comments
```lua
-- [One sentence: purpose and return value]
-- @param name: type - description
-- @return type - description
function name(param1, param2)
```

Always include param types and return type. Update when signature changes.

### Inline Comments
```lua
-- Comment the WHY, not the WHAT
local speed = base_speed * 0.8  -- Reduced by 20% for underwater movement

-- GOOD: Explains reasoning
if health <= 0 then
  -- Death animation must complete before entity removal
  start_death_animation(entity)
end

-- BAD: States the obvious
if health <= 0 then
  -- Check if health is zero or less
  start_death_animation(entity)
end
```

If code needs a comment explaining WHAT it does, rewrite the code.

### TODO Comments
```lua
-- TODO(username): Brief description
-- FIXME(username): Known bug description
-- HACK(username): Technical debt description
```

Delete when resolved.

## Code Organization

### Top-Down Reading
```lua
function compute_physics_step(pos, vel, mass, dt, gravity)
  -- 1. Extract/prepare inputs
  local current_speed = vel:length()
  
  -- 2. High-level algorithm steps
  local accel = calculate_acceleration(gravity, mass)
  local new_vel = apply_acceleration(vel, accel, dt)
  local new_pos = apply_velocity(pos, new_vel, dt)
  
  -- 3. Package and return
  return {position = new_pos, velocity = new_vel}
end
```

Read like a recipe: preparation, steps, plating. One blank line between sections. Max 20 lines per function.

### Early Returns for Guards
```lua
function compute_damage_result(attacker_stats, defender_stats)
  -- Guard: Early exit for invalid input
  if not attacker_stats or not defender_stats then
    return {damage = 0, events = {}}
  end
  
  -- Main logic (least indented)
end
```

Validate inputs at top. Comment guards with "Guard:" prefix.

## Formatting

**Indentation**: 2 spaces, never tabs, max 3 nesting levels

**Line Length**: Target 80 chars, hard limit 100

**Blank Lines**:
- 1 between functions
- 1 between logical sections within functions
- 2 before section dividers
- 0 at start/end of functions

**Tables**:
```lua
-- Single line if < 80 chars
local point = {x = 10, y = 20}

-- Multi-line if longer
local config = {
  gravity = 9.8,
  max_speed = 500,
  friction = 0.95,  -- Trailing comma
}
```

## Anti-Patterns

**God Functions**: Delegate to orchestrators, keep shells under 20 lines

**Magic Numbers**: Extract to named constants

**Cryptic Abbreviations**: `eploc` → `enemy_position`

**Obvious Comments**: Delete them

**Stale Comments**: Update or delete immediately

## Visual Consistency

Every system file has identical structure:
1. Header block
2. Dependencies
3. Three layer sections (Shell, Orchestration, Pure)

Function signatures are self-documenting:
```lua
-- Clear
function compute_damage_result(attacker_stats, defender_stats, modifiers)

-- Unclear
function process(a, b, c)
```

Data flows are visible:
```lua
local pos = world:get(entity, Position)
local result = compute_new_position(pos, dt)
world:set(entity, Position, result)
```

## Quick Reference

**Naming**:
- System file: `<domain>.lua`
- Orchestrator: `compute_what_it_returns(...)`
- Pure function: `verb_noun(...)`
- Local var: short if < 10 lines, full if longer
- Constant: `SCREAMING_CASE`

**Commenting**:
- File header: Always present, always current
- Function: Purpose, params, return type
- Inline: Why, not what
- TODO: Include username

**Organizing**:
- Top-down: Abstract to concrete
- Early returns: Guards first
- Max nesting: 3 levels
- Max function: 20 lines

**When stuck**: Ask "Will I understand this in 6 months?" If no, clarify.
