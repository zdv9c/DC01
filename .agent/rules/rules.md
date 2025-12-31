---
trigger: always_on
---

# Project Rules & Architecture

## Architecture
- **Strict ECS**: We stick to the Entity Component System pattern using Concord.
- **One System, One Object, One File**: Each system resides in its own file and returns a single object.
- **No Inter-System Dependencies**: Systems should be decoupled.

## Main Function Pattern
The `main.lua` entry point only calls `love.load`, `love.update`, and `love.draw`.
These global callbacks **ONLY** call special "main" functions provided by each system.

### System "Main" Functions
- Act as containers/organizers for top-level system functions.
- Generally named after the Love2d callback:
  - `combat.load`
  - `combat.update`
  - `combat.draw`
- Additional main functions allowed only if absolutely necessary for order of operations (use sparingly).

## Function Organization
1. **Main Functions**: (e.g., `update`, `draw`)
2. **Top-Level Functions**: Top of wishful thinking, containers for top "ideal" functions
3. **Ideal functions:** Created to make top-level functions possible, should be pure functions when possible
4. **Pure Function Rule:** Output = f(Input). Deterministic; no external state access (read/write); no mutations of arguments; no I/O side effects.

Files should be ordered:
1. Main Functions
2. Top-Level Functions
3. Ideal Functions (grouped by which top-level function they serve)

## Nesting
- Nesting functions in objects for scoping/organization is encouraged **IF** the objects only contain functions.
- Separation of data and behavior is the primary goal.