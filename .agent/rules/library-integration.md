---
trigger: always_on
---

## Library Integration Rules

### General Principles
- Libraries are tools used by systems, never by components
- Libraries never store entity references or game state
- All library state confined to system shell or injected config
- Agents must understand library data flow before using
- **COMPREHENSIVE DOCS**: Before using any library, consult its manual in `.agent/docs/libraries/*.md`. These contain the full API and usage patterns for each integrated tool.

### Per-Library Rules

**Concord (ECS)**:
- Components: Pure data only, no methods
- Systems: Shell pattern only (query → compute → write)
- World: Pass explicitly, never store globally

**HardonCollider (Collision)**:
- Only collision system touches HC world
- Shapes stored in world.hc_shapes[entity_id], NEVER in components
- Shape-to-entity mapping in world.shape_to_entity[shape]
- NEVER use HC callbacks (on_collision, on_separate) - PROHIBITED
- Query collisions via world.hc_world:collisions() once per frame
- Shell processes collision pairs, emits events
- Collision response computed in orchestrators, never in HC callbacks
- HC world updated in collision system only

**Baton (Input)**:
- Only input system reads Baton
- Input system emits input events or writes InputState component
- Game systems react to input events, never read Baton directly
- Baton instance stored in world.input

**Cargo (Assets)**:
- Load all assets at init
- Store in world.assets table
- Systems read world.assets, never call Cargo during update
- Assets are immutable references, never modified

**lume (Utilities)**:
- Use in orchestrators and pure functions only
- Prefer lume functions over manual loops for clarity
- Pure functions: `lume.map`, `lume.filter`, `lume.reduce`
- Never use lume to store state (e.g., lume.memoize storing globals)

**flux (Tweening)**:
- Tween state lives in world.flux
- Systems schedule tweens via `world.flux:to(component, duration, {field = value})`
- Tween target is component data, never entity references
- Update world.flux in main loop, not in individual systems

**hump.timer (Delayed Actions)**:
- Timer state lives in world.timer
- Systems schedule via `world.timer:after(delay, fn)`
- Callbacks must only emit events, not modify world directly
- Update world.timer in main loop, not in individual systems

**hump.gamestate (State Machine)**:
- States are files in states/ directory
- Each state has init, update, draw functions
- State transitions via `gamestate.switch(state_name)`
- World passed to state functions, not stored in state

**gamera (Camera)**:
- Camera state lives in world.camera `{x, y, scale, rotation}`
- Only rendering system reads camera
- Game systems work in world space, never screen space
- Camera transformations applied only during rendering

**love2d-noise (Procedural Noise)**:
- Noise shader compiled at init with seed
- Stored in world.noise_shader
- Only procedural generation systems use noise
- Noise generation happens in orchestrators (seed + coords → noise value)
- Never store noise values in components (compute on demand or cache in world data)

**binser (Serialization)**:
- Only used in save/load system
- Serialize component data only, never entity IDs or library handles
- Save format: `{entities = {...}, world_data = {...}}`
- Loading creates new world, doesn't modify existing

**log.lua (Logging)**:
- Available globally via `log.info()`, `log.warn()`, `log.error()`
- Use in systems to trace event flow
- Never log in pure functions (breaks purity)
- Log at shell level: "System X processing entity Y"

**lust (Testing)**:
- Tests live in tests/ directory
- Test pure functions and orchestrators only
- Never test shells (those are integration tests)
- Pattern: `describe("function_name", function() it("behavior", ...) end)`
- Mock world data, don't create actual ECS world

**jumper (Pathfinding)** *(when added)*:
- Pathfinder instance stored in world.pathfinder
- Only pathfinding/AI systems use pathfinder
- Shell queries pathfinder: `path = pathfinder:getPath(start_x, start_y, goal_x, goal_y)`
- Orchestrator processes path into waypoints
- Paths stored in Path component as array of positions, not as jumper object

### Anti-Patterns
- ❌ Component storing library handle (e.g., `Shape {bump_shape}`)
- ❌ Library callback modifying world state directly
- ❌ System using library not declared in file header DATA CONTRACT
- ❌ Global library state accessed from multiple systems
- ❌ Library state updated in system update loop (should be in main loop or shell only)
- ❌ Storing library objects in components (store pure data only)
- ❌ UI directly reading/writing components (must go through events)
- ❌ Noise/procedural functions called every frame (compute once, cache if needed)

## Library State Storage Pattern

All library state lives in world object:
```lua
-- World initialization
world.bump_world = bump.newWorld()
world.input = baton.new(input_config)
world.assets = cargo.init(asset_manifest)
world.flux = flux.group()
world.timer = timer.new()
world.camera = gamera.new(0, 0, world_width, world_height)
world.noise_shader = noise.build_shader("noise.frag", world_seed)
world.pathfinder = jumper.pathfinder(grid, finder, walkable)
world.ui_context = nuklear.newUI()

-- Configuration (injected to systems)
world.config = {
  gravity = 9.8,
  world_bounds = {x = 0, y = 0, w = 1920, h = 1080},
  move_speed = 200,
  -- etc
}

-- Event queue
world.event_queue = {}
```

Systems receive world, extract what they need:
```lua
function collision.update(world, dt)
  local bump_world = world.bump_world
  -- Use bump_world...
end
```

This keeps all library state explicit and traceable.