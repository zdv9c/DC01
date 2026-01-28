# CBS Navigation System Walkthrough

This document describes the current implementation of the **Context-Based Steering (CBS)** navigation system used for AI movement.

## Core Architecture

The navigation system follows a **Shell/Orchestrator/Pure Function** pattern to ensure predictable and testable AI behavior.

### System Flow
1. **System Shell** (`ai_movement.lua`): Queries the world for AI entities and obstacles. Extracts physical data (position, velocity, radius).
2. **Orchestrator** (`compute_ai_steering`):
   - Determines the current tactical goal (A* waypoint or direct target).
   - Generates an **Interest Map** (where the NPC *wants* to go).
   - Generates a **Danger Map** (where the NPC *must not* go).
   - Resolves symmetric deadlocks with persistence.
   - Solves for the final heading and velocity.
3. **CBS Library** (`src/libs/cbs/`): Provides the mathematical tools for interest/danger generation and direction solving.

---

## Files Involved

| File | Responsibility |
| :--- | :--- |
| `src/config/ai_config.lua` | Centralized tuning parameters for all AI behaviors. |
| `src/systems/ai_movement.lua` | Coordinates between pathfinding, CBS, and physics. |
| `src/libs/cbs/init.lua` | Main API entry point for the navigation library. |
| `src/libs/cbs/danger.lua` | **Physical Awareness**: Raycasting, radius padding, and danger dilation. |
| `src/libs/cbs/solver.lua` | **Masking & Solving**: Quadratic masking and peak-based interpolation. |
| `src/libs/cbs/behaviors.lua` | **Interest**: Seek, Flee, Strafe, and Path Locking behaviors. |
| `src/libs/cbs/noise.lua` | **Organic Variation**: Adds spatial noise to the interest map. |
| `src/libs/cbs/steering.lua` | Rotational physics (smoothing head turning). |

---

## Active Behaviors

### 1. Radius-Aware Obstacle Avoidance
Casts rays in a 360-degree ring to detect obstacles.
- **Physical Padding**: Unlike standard CBS, this implementation subtracts the agent's radius from hit distances. Danger reaches **1.0** at the exact moment of physical contact.
- **Dynamic Dilation**: Closer objects "spread" their danger wider across the slot map, preventing grazing or "shoulder-checking" obstacles.
- **Config Variables**:
  - `cbs.danger_range`: Maximum detection distance (in tiles).
  - `cbs.danger_falloff`: `"linear"`, `"quadratic"`, or `"logarithmic"`. (Quadratic is recommended).

### 2. Path Locking (LOS Enforcement)
When a clear Line-of-Sight (LOS) to the target is detected, the system injects a massive interest boost into the direct direction.
- **Effect**: If the path is clear, it overrides "wandering" or "strafing" tendencies for aggressive, linear movement.
- **Logic**: A single direct raycast is used to verify the path. If clear, the `solve_simple` (Winner Take All) solver is engaged for maximum precision.

### 3. Persistent Deadlock Resolution
Resolves "Dead Center" collisions where an obstacle is perfectly centered on the target path.
- **Symmetry Breaking**: Uses a persistent `deadlock_side` (stored in `SteeringState`) to commit to a direction (Left or Right).
- **Hysteresis**: Once a side is chosen, the NPC sticks to it until the direct path to the target is clear. This prevents "flicker" or indecision.
- **Config Variables**:
  - `cbs.deadlock_threshold`: Danger level at which to trigger symmetry breaking.
  - `cbs.deadlock_bias`: Amount of interest to add to the chosen flank.

### 4. Organic Spatial Noise
Adds Perlin/Simplex noise to the interest map.
- **Effect**: Creates organic, slightly "wandery" movement that feels alive rather than robotic.
- **Config Variables**:
  - `noise.amount`: Strength of the jitter (0.0 to 1.0).
  - `noise.scale`: Spatial frequency (how "rough" the map is).
  - `noise.rate`: Temporal speed (how fast the "ripples" change).

### 5. Hard Masking & Peak Solving
The final direction is determined by a non-linear solver.
- **Suicide Prevention**: If danger in a slot exceeds `0.85`, its interest is hard-clipped to **zero**. This prevents high-interest behaviors (like Path Locking) from "pushing through" physical boundaries.
- **Quadratic Masking**: Interest is suppressed quadratically as danger increases (`interest * (1.0 - d^2)`).
- **Peak Solving**: Instead of averaging all directions, the solver finds the "Best Peak" and performs sub-slot parabolic interpolation for perfectly smooth aiming.

---

## Steering & Physical Settings

These variables in `ai_config.lua` control the feel of the NPC's actual movement:

| Variable | Effect |
| :--- | :--- |
| `movement.speed` | Base pixels-per-second. |
| `movement.turn_smoothing` | Higher = snappier turning; Lower = wide, drifting arcs. |
| `movement.velocity_smoothing` | Higher = tighter inertia; Lower = slippery/sluggish. |
| `movement.min_speed_bias` | Prevents NPC from slowing to a complete crawl in high-danger zones. |
| `cbs.resolution` | Number of direction slots. `16` is default. `32` is smoother but heavier. |
