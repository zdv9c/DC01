---
trigger: always_on
---

# Code Style & Conventions

## Philosophy
- **Wishful Thinking**: Write code as if ideal functions already exist, then implement them (Lisp-inspired).
- **SRP (Single Responsibility Principle)**: Stick to it.
- **Human Readability**: Code is written for humans first, machines second. Avoid obscure idioms.

## Naming
- **snake_case**: Use snake_case for all symbols.
- **Descriptive Names**: All functions should be named descriptively.
- **Variables**:
  - Prefer short/abbreviated but descriptive names for disposable locals (e.g., `pos` -> `position`).
  - **NO** single-letter names (`x`, `y`, `z`) unless they actually represent coordinates.
  - Highly visible variables need **highly descriptive and friendly names**.
  - **System Main Functions**: Match the LÖVE2D callback name (e.g., `system_name.update`, `system_name.draw`).
  - **Logic Functions**: Use descriptive, verb-first names for "True Functions" (e.g., `calculate_damage`, `apply_knockback`).

## Comments
- **Declarations**: Always comment declarations of variables, functions, and objects.
  - Explain the **WHAT**, **WHY**, and **WHERE**.
- **System Headers**: Use comment blocks to provide a high-level overview of every system.
- **Maintenance**: Always update comments when code changes.

## Structure
- Design code to be read top-down.

## System Declarations
- **Data Locality Header**: Every system file must begin with a comment block explicitly listing data dependencies:
  - **Reads**: Components/Events the system monitors.
  - **Writes**: Components/Events the system modifies.

## File Structure for all Systems
- **Physical Layout**: 
  - Section 1: Data Locality Header.
  - Section 2: Main Functions.
  - Section 3: Top-Level Functions.
  - Section 4: True Functions (grouped logically).

## Formatting
- **Encapsulation**: If using objects for scoping, ensure they contain functions ONLY. No data properties allowed inside system-level objects.
