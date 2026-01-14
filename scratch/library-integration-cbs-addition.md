# CBS Addition for library-integration.md

Add this section to `.memory/library-integration.md` under **Per-Library Rules**:

---

**CBS (Context-Based Steering)**:
- Only movement/AI systems use CBS functions
- CBS context created fresh per-frame via `CBS.new_context(resolution)`
- Context is NOT stored in components (it's transient frame data)
- Raycast results computed in shell, passed to `add_danger_from_rays()`
- Wander cursor IS stored in component: `SteeringState {cursor = 0.0, seed = 0}`
- CBS returns direction, shell converts to velocity
- Pure library, no world access, no callbacks
- Each entity needing unique wander uses different `params.seed`

---

Add this to **Anti-Patterns**:

```markdown
- ❌ Storing CBS context in components (context is per-frame, recreate with new_context)
- ❌ Performing raycasts inside CBS calls (raycasts happen in shell, results passed in)
- ❌ Directly using CBS result as velocity (CBS returns direction, multiply by speed in shell)
```

---

Add this to **Library State Storage Pattern** example:

```lua
-- No world.cbs needed - CBS is stateless
-- Only component stores cursor for wander continuity:
-- SteeringState = {cursor = 0.0, seed = entity_id}
```
