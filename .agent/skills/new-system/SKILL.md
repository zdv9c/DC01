---
description: Create a new ECS system following the strict 3-layer Clean Architecture (Shell, Orchestrator, Pure Functions).
---

# Skill: New ECS System

This skill creates a new ECS system file in `src/systems/` and a corresponding test in `src/tests/` (if applicable), enforcing the project's architectural rules.

## usage
When the user asks to "create a [Name] system", follow these steps.

## Steps

1.  **Analyze Dependencies**:
    *   Identify which components the system will need to operate (Read/Write).
    *   Determine what logic belongs in the Orchestrator vs Shell.

2.  **Generate System File**:
    *   Read `.agent/skills/new-system/system_template.lua`.
    *   Create a new file `src/systems/[name_snake_case].lua`.
    *   Replace placeholders:
        *   `SystemName` -> The PascalCase name of the system (e.g., `CombatSystem`).
        *   `pool = {...}` -> The list of string component names required.
        *   `process_entity` -> Rename to something descriptive (e.g., `resolve_combat`).
        *   Implement the core loop in `update` to match the logic.

3.  **Strict Architecture Checks**:
    *   **Layer 1 (Shell)**: Ensure `update` ONLY handles World I/O (component reads/writes, event emission). NO math/logic here.
    *   **Layer 2 (Orchestrator)**: Ensure the local function called by `update` takes *only* data arguments (tables/numbers), never the `entity` object itself or the `world`.
    *   **Layer 3 (Pure)**: Use `lume` or local functions for math.

4.  **Register System**:
    *   Check `src/main.lua` or wherever systems are initialized (often a `game_state` or `world_init`).
    *   Add the `require` and add the system to the world.

5.  **Generate Test File** (Optional but recommended):
    *   Create `src/tests/test_[name_snake_case].lua` using `test_template.lua`.

## Example

User: "Create a HealthRegen system that adds health over time."

Action:
1. Create `src/systems/health_regen.lua`.
2. Pool: `{'Health', 'RegenStats'}`.
3. Orchestrator: `calculate_new_health(current, max, rate, dt)`.
4. Shell: Query loop -> `calculate_new_health` -> `entity.Health.current = new_val`.
