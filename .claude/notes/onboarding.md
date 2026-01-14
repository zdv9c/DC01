# Claude Code Onboarding Notes - DC01 (Antigravity Platform)

**Date**: 2026-01-14
**Agent**: Claude Code
**Session**: Initial onboarding

---

## Project Overview

**DC01** is an evolving vertical slice game combining action, adventure, RPG, and dungeon crawler mechanics. The project is being developed on Google's **antigravity platform** (a new development environment I'm learning about through this codebase).

### Key Characteristics
- Iterative development through increasingly complex vertical slices
- Agent-optimized architecture designed for AI-assisted development
- Zero technical debt philosophy - clean architecture is enforced through rules
- Built with LÖVE2D game framework using Lua

---

## Architecture Philosophy

### ECS Clean Architecture (Shell/Orchestrator/Pure)

The project follows a strict three-layer pattern:

**Layer 1: System Shell**
- ONLY layer that reads/writes world state
- Queries components from world
- Calls orchestrators with explicit parameters
- Writes results back to world
- Enqueues events

**Layer 2: Orchestrators**
- Pure or near-pure functions
- Compose pure functions to solve domain problems
- ALL dependencies passed as parameters
- Returns data structures only

**Layer 3: Pure Functions**
- Absolutely pure (no side effects)
- Mathematical transformations and logic
- Values in, values out

### Critical Invariants (MUST NEVER VIOLATE)
- Only shells access world state
- All orchestrators are pure or near-pure
- All dependencies are explicit parameters
- Systems do not call systems
- Events are the only cross-system communication
- Component queries declare all dependencies
- Pure functions have zero side effects

---

## Technology Stack

**Core**:
- Language: Lua 5.1 / LuaJIT
- Engine: LÖVE 11.4+

**Essential Libraries**:
- ECS: Concord
- Collision: bump.lua (migrated from HardonCollider)
- Camera: gamera (migrated from STALKER-X)
- Input: Baton
- State Management: hump.gamestate
- Tweening: flux
- Timer: hump.timer

**Utilities**:
- lume (functional utilities)
- log.lua (logging)
- binser (serialization)
- lust (testing)
- love2d-noise (procedural generation)
- jumper (pathfinding)

---

## Project Structure

```
/home/user/DC01/
├── .agent/           # Original agent rules (from antigravity platform)
│   ├── rules/        # Architecture and style rules
│   └── docs/         # Library documentation
├── .claude/          # My copy of rules and notes (this file!)
│   ├── rules/        # Copied from .agent/rules
│   ├── docs/         # Copied from .agent/docs
│   └── notes/        # My onboarding notes
├── src/
│   ├── main.lua      # Entry point
│   ├── conf.lua      # LÖVE configuration
│   ├── components/   # ECS component definitions (pure data)
│   ├── systems/      # System files (shell/orchestrator/pure layers)
│   ├── states/       # Game states (Play.lua currently)
│   └── libs/         # External libraries
├── readme.md         # User-facing documentation
├── architecture.md   # Mermaid diagram of architecture
└── run.sh           # Launch script
```

---

## Current Implementation State

### Working Features
- Top-down inertial movement with friction
- Bump & slide collision using bump.lua
- Player-following camera with gamera (TOPDOWN style)
- Infinite checkerboard world rendering
- Input handling via Baton

### Components Implemented
- Transform (position data)
- Velocity (movement data)
- Sprite (visual representation)
- Collider (collision data)
- PlayerControlled (input marker)
- AiControlled (AI marker)
- CameraTarget (camera follows this)
- Debug (debug info marker)

### Systems Implemented (in order)
1. system_input.lua - Reads input, writes InputState/Velocity
2. system_movement.lua - Applies velocity to position
3. system_collision.lua - Handles bump.lua collision detection
4. system_camera.lua - Updates camera to follow target
5. system_rendering.lua - Draws world and entities

---

## Key Rules to Remember

### Entity-Component Design
- **Entities**: Opaque IDs only, no behavior, no state
- **Components**: Pure data structures (Lua tables), no methods
- **Fine-grained**: Prefer small focused components over large ones
- Position/Velocity/Mass separate, not combined into Movement

### Library Integration
- Libraries used by systems only, never by components
- Library state stored in world object (world.bump_world, world.camera, etc.)
- Never store library handles in components
- Consult `.claude/docs/libraries/*.md` before using any library

### Code Style
- System files: `system_domain.lua`
- Orchestrators: `compute_what_it_returns(...)`
- Pure functions: `verb_noun(...)`
- File header with DATA CONTRACT (READS/WRITES/EMITS/CONFIG)
- Max 3 nesting levels, max 20 lines per function
- Comment WHY not WHAT

### Markdown Edits Rule
- **DO NOT** write markdown to `.agent/`
- **DO** write markdown to `scratch/` (or `.claude/notes/` in my case)

---

## Current Technical Specs

### Metrics
- Tile Size: 16x16 pixels
- Sprite Size: 16x16 pixels
- Grid: 16x16 layout

### Gameplay
- Movement: Top-down inertial with friction and speed clamping
- Collision: Bump and slide using bump.lua
- Camera: Player-following gamera camera (TOPDOWN style)

### Entities
- Player: Green circle, input controlled, camera follows
- Actors: Identical to player, AI controlled (future)
- Blocks: Grey 16x16 static colliders

### World
- Infinite checkerboard pattern (dark/light grey)
- Rendered relative to camera position

---

## Antigravity Platform Observations

Based on the codebase structure, the antigravity platform appears to provide:

1. **Agent Rules System**: Structured rules in `.agent/` directory
   - Trigger-based rules (always_on, glob patterns)
   - Comprehensive architecture guidelines
   - Library integration rules
   - Code style enforcement

2. **Documentation Pattern**: Extensive library docs in `.agent/docs/libraries/`
   - Full API documentation for each integrated library
   - Usage patterns and constraints
   - Integration rules specific to this architecture

3. **Agent-Optimized Development**:
   - Rules designed for AI agent comprehension
   - Explicit dependency tracking
   - Clear boundaries between layers
   - Self-documenting code patterns

4. **Zero Technical Debt Philosophy**:
   - Architecture invariants that must never be violated
   - Code smell detection built into rules
   - Anti-pattern documentation
   - Testing strategy baked into architecture

---

## My Action Plan

When working on this project, I will:

1. **Always Read Rules First**: Check `.claude/rules/` before making changes
2. **Consult Library Docs**: Use `.claude/docs/libraries/` for any library usage
3. **Follow the Pattern**: Shell → Orchestrator → Pure function layers
4. **Explicit Dependencies**: All parameters visible in signatures
5. **Test Pure Functions**: They're easy to test since they're pure
6. **No System-to-System Calls**: Use events for communication
7. **Keep Components Simple**: Pure data, no behavior
8. **Document Data Contracts**: Update file headers when changing component access

---

## Questions to Explore Later

- How does the antigravity platform handle agent collaboration?
- Are there CI/CD integrations specific to antigravity?
- How does the platform enforce these rules automatically?
- What other antigravity platform features exist beyond the `.agent/` structure?

---

## Migration Notes (Recent Changes)

From commit history:
- Migrated collision from HardonCollider → bump.lua
- Migrated camera from stalker → gamera
- Updated library documentation accordingly
- Refactored with improved architecture, added collision

---

## Conclusion

This is a well-architected, agent-friendly codebase with clear separation of concerns. The antigravity platform's rule system provides excellent guardrails for maintaining code quality. I'm ready to contribute to this project following the established patterns.

**Status**: Onboarded and familiar with architecture ✓
