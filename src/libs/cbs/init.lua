-- init.lua
-- Context-Based Steering (CBS) Library
-- Main API module - ties everything together

local context_module = require("libs.cbs.context")
local behaviors = require("libs.cbs.behaviors")
local danger_module = require("libs.cbs.danger")
local solver_module = require("libs.cbs.solver")
local vec2 = require("libs.cbs.vec2")

local CBS = {}

-- ============================================================================
-- CONTEXT MANAGEMENT
-- ============================================================================

-- Creates a new steering context
-- @param resolution: number - number of direction slots (8, 16, 32 recommended)
-- @return context table
function CBS.new_context(resolution)
  return context_module.new(resolution)
end

-- Resets interest and danger maps to zero
-- Call this at the start of each frame
-- @param ctx: context
function CBS.reset_context(ctx)
  context_module.reset(ctx)
end

-- ============================================================================
-- BEHAVIORS (Interest Generation)
-- ============================================================================

-- Adds seek behavior - move toward target
-- @param ctx: context
-- @param target_direction: vec2 {x, y} - direction to seek
-- @param weight: number (optional) - strength multiplier (default 1.0)
function CBS.add_seek(ctx, target_direction, weight)
  behaviors.add_seek(ctx, target_direction, weight)
end

-- Adds flee behavior - move away from target
-- @param ctx: context
-- @param target_direction: vec2 - direction to flee from
-- @param weight: number (optional) - strength multiplier (default 1.0)
function CBS.add_flee(ctx, target_direction, weight)
  behaviors.add_flee(ctx, target_direction, weight)
end

-- Adds strafe behavior - move perpendicular to target with distance blending
-- @param ctx: context
-- @param target_direction: vec2 - direction to strafe around
-- @param distance: number - current distance to target
-- @param params: table (optional) - {min_range, max_range, seek_weight, flee_weight}
function CBS.add_strafe(ctx, target_direction, distance, params)
  behaviors.add_strafe(ctx, target_direction, distance, params)
end

-- Adds wander behavior - coherent meandering using noise
-- @param ctx: context
-- @param forward_direction: vec2 - agent's current forward direction
-- @param noise_cursor: number - current noise position
-- @param params: table (optional) - {noise_scale, angle_range, weight}
-- @return number - updated noise cursor (pass this back next frame)
function CBS.add_wander(ctx, forward_direction, noise_cursor, params)
  return behaviors.add_wander(ctx, forward_direction, noise_cursor, params)
end

-- Adds tether behavior - return to spawn when too far
-- @param ctx: context
-- @param current_position: vec2 - agent's current position
-- @param spawn_position: vec2 - home position
-- @param leash_radius: number - max allowed distance
-- @param return_weight: number (optional) - strength of pull (default 1.0)
function CBS.add_tether(ctx, current_position, spawn_position, leash_radius, return_weight)
  behaviors.add_tether(ctx, current_position, spawn_position, leash_radius, return_weight)
end

-- ============================================================================
-- DANGER (Obstacle Avoidance)
-- ============================================================================

-- Adds danger from raycast results
-- @param ctx: context
-- @param ray_results: array of {direction = vec2, hit_distance = number}
-- @param look_ahead: number - maximum raycast distance
-- @param dilation: number (optional) - danger spread (0 = none, 0.5 = moderate)
function CBS.add_danger_from_rays(ctx, ray_results, look_ahead, dilation)
  danger_module.add_danger_from_rays(ctx, ray_results, look_ahead, dilation)
end

-- Adds danger from proximity to obstacles
-- @param ctx: context
-- @param agent_position: vec2 - current position
-- @param obstacles: array of vec2 positions
-- @param danger_radius: number - how close is dangerous
function CBS.add_danger_from_proximity(ctx, agent_position, obstacles, danger_radius)
  danger_module.add_danger_from_proximity(ctx, agent_position, obstacles, danger_radius)
end

-- Adds danger in a specific direction
-- @param ctx: context
-- @param danger_direction: vec2 - direction to mark as dangerous
-- @param danger_value: number - how dangerous (0-1)
-- @param spread: number (optional) - how many neighboring slots to affect
function CBS.add_directional_danger(ctx, danger_direction, danger_value, spread)
  danger_module.add_directional_danger(ctx, danger_direction, danger_value, spread)
end

-- ============================================================================
-- SOLVER
-- ============================================================================

-- Solves for final steering direction using interest/danger masking
-- Uses sub-slot interpolation for smooth results
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
function CBS.solve(ctx)
  return solver_module.solve(ctx)
end

-- Simple solver without interpolation (faster, less smooth)
-- @param ctx: context
-- @return {direction = vec2, magnitude = number}
function CBS.solve_simple(ctx)
  return solver_module.solve_simple(ctx)
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

-- Advances noise cursor for wander behavior
-- @param cursor: number - current cursor value
-- @param dt: number - delta time
-- @param speed: number (optional) - advancement rate (default 1.0)
-- @return number - new cursor value
function CBS.advance_cursor(cursor, dt, speed)
  speed = speed or 1.0
  return cursor + (dt * speed)
end

-- Exports vec2 utilities for convenience
CBS.vec2 = vec2

-- Debug: Get masked interest/danger map
-- @param ctx: context
-- @return array of {slot = vec2, value = number}
function CBS.debug_get_masked_map(ctx)
  return solver_module.get_masked_map(ctx)
end

-- ============================================================================
-- VERSION INFO
-- ============================================================================

CBS.VERSION = "1.0.0"
CBS.DESCRIPTION = "Context-Based Steering library for agent movement"

return CBS
