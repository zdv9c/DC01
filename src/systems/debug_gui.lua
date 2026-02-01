--[[============================================================================
  SYSTEM: Debug GUI
  
  PURPOSE: Renders the developer debug menu using Slab.
           Controls debug gizmo visibility, simulation state, and interaction tools.
           Split into Left (Tools) and Right (Inspector) docked panels.
  
  DATA CONTRACT:
    READS:  World Resource (debug_gizmos, debug_tool, debug_selection, dev_mode, time_scale, simulation_paused)
    WRITES: World Resource (debug_gizmos, debug_tool, debug_selection, time_scale, simulation_paused, single_step)
    EMITS:  (none)
    CONFIG: (none)
  
  UPDATE ORDER: After game logic, before rendering (UI state update)
============================================================================]]--

local Concord = require "libs.Concord"
local Slab = require "libs.Slab"

local DebugGUI = Concord.system({
  pool_ai = {"AIControlled", "Debug"},
  pool_player = {"PlayerControlled", "Debug"},
  pool_obstacles = {"Collider", "Debug"}
})

-- UI State (local to system)
local UI = {
  tree_gizmos = true,
  tree_path = true,
  tree_cbs = true,
  tree_sim = true,
  tree_hierarchy = true,
  filter_text = "",
  instant_transitions = false
}

--[[----------------------------------------------------------------------------
  BEHAVIOR HELPERS
----------------------------------------------------------------------------]]--

-- States that use targets for their behavior
local TARGET_USING_STATES = {
  pathfind = true,
  seek = true,
  flee = true,
  strafe = true
}

-- Clear pathfinding waypoints (pathfind-specific data)
local function clear_pathfind_waypoints(entity)
  local path = entity.Path
  if path then
    path.waypoints = {}
    path.is_valid = false
    path.is_finished = true
    path.current_index = 1
  end
end

-- Clear target data (when transitioning to states that don't use targets)
local function clear_target(entity)
  local path = entity.Path
  if path then
    path.final_target = nil
    path.target_entity = nil
  end

  local state = entity.CBSBehaviorState
  if state then
    state.has_target = false
    state.target_x = 0
    state.target_y = 0
  end
end

function DebugGUI:init()
  local world = self:getWorld()
  
  if not world:getResource("debug_gizmos") then
    world:setResource("debug_gizmos", {
      ui = true, leash = true, path = true, pruning = true,
      cbs_ring = false, cbs_weights = true, cbs_rays = false,
      deadlock = true, hard_mask = true
    })
  end
  
  -- Set Global Transparency for Panels
  local style = Slab.GetStyle()
  style.WindowBackgroundColor[4] = 0.7
  
  self:generate_icons()
end

function DebugGUI:generate_icons()
  -- Generate procedural icons for the spawner
  self.icons = {}
  
  local function make_icon(draw_fn)
    local active_canvas = love.graphics.getCanvas()
    local canvas = love.graphics.newCanvas(64, 64)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.push()
    love.graphics.scale(2, 2) -- Draw at 32x32 logic scale
    draw_fn()
    love.graphics.pop()
    love.graphics.setCanvas(active_canvas)
    return canvas
  end
  
  self.icons["Block"] = make_icon(function()
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.circle("fill", 16, 16, 8)
  end)
  
  self.icons["NPC"] = make_icon(function()
    love.graphics.setColor(1, 1, 0, 1) -- Yellow
    love.graphics.circle("fill", 16, 16, 8)
  end)
  
  self.icons["Zombie"] = make_icon(function()
    love.graphics.setColor(0, 0.5, 0, 1) -- Green
    love.graphics.circle("fill", 16, 16, 8)
  end)
end

function DebugGUI:update(dt)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end

  self:draw_left_panel()
  self:draw_view_options_panel()
  self:draw_right_panel()
end

--[[----------------------------------------------------------------------------
  LEFT PANEL: Tools & Settings
----------------------------------------------------------------------------]]--

function DebugGUI:draw_left_panel()
  local W, H = love.graphics.getDimensions()
  local PANEL_W = 208
  local PANEL_H = math.floor(H / 2)

  Slab.BeginWindow('LeftPanel', {
    Title = "Tools",
    X = 0, Y = 0, W = PANEL_W, H = PANEL_H,
    AutoSizeWindow = false, AllowResize = false, AllowMove = false
  })

  self:draw_simulation_controls()
  Slab.Separator()
  self:draw_tool_selector()

  Slab.EndWindow()
end

function DebugGUI:draw_simulation_controls()
  local world = self:getWorld()
  local paused = world:getResource("simulation_paused")
  local scale = world:getResource("time_scale") or 1.0

  Slab.Text("Simulation")

  -- Transport Controls
  if Slab.Button(paused and "RESUME" or "PAUSE", {W = 80}) then
    world:setResource("simulation_paused", not paused)
  end
  Slab.SameLine()
  if Slab.Button("STEP", {W = 60, Disabled = not paused}) then
     world:setResource("single_step", true)
  end

  Slab.NewLine()

  -- Time Scale Selector
  Slab.Text("Time Scale")
  local scale_options = {0.1, 0.5, 1.0, 2.0, 5.0, 10.0}
  local style = Slab.GetStyle()

  for i, option in ipairs(scale_options) do
    local is_current = math.abs(scale - option) < 0.01
    -- Wrap after 3 buttons per row
    if i > 1 and (i - 1) % 3 ~= 0 then Slab.SameLine() end

    local old_color = nil
    if is_current then
      old_color = {unpack(style.ButtonColor)}
      style.ButtonColor = {0.2, 0.5, 0.2, 1}
    end

    local label = string.format("%.1fx", option)
    if Slab.Button(label, {W = 50, H = 20}) then
      world:setResource("time_scale", option)
    end

    if is_current and old_color then
      style.ButtonColor = old_color
    end
  end
end

function DebugGUI:draw_view_options_panel()
  local W, H = love.graphics.getDimensions()
  local PANEL_W = 208
  local PANEL_H = math.floor(H / 2)
  local PANEL_Y = PANEL_H

  Slab.BeginWindow('ViewOptionsPanel', {
    Title = "View Options",
    X = 0, Y = PANEL_Y, W = PANEL_W, H = PANEL_H,
    AutoSizeWindow = false, AllowResize = false, AllowMove = false
  })

  self:draw_gizmo_settings()

  Slab.EndWindow()
end

function DebugGUI:draw_tool_selector()
  local tool = self:getWorld():getResource("debug_tool")
  local selection = self:getWorld():getResource("debug_selection")

  Slab.Text("Active Tool")

  -- Mode Selection (Toggle Buttons)
  if self:private_draw_toggle("Actor Controller", tool.mode == "select") then
    tool.mode = "select"
  end

  if self:private_draw_toggle("Entity Painter", tool.mode == "paint") then
    tool.mode = "paint"
  end
  
  -- Contextual Options
  if tool.mode == "paint" then
    Slab.NewLine()
    Slab.Text("Entities")
    
    -- Grid of Icons
    local types = {"Block", "NPC", "Zombie"}
    local x, y = Slab.GetCursorPos()
    local start_x = x
    
    for i, t in ipairs(types) do
      if i > 1 and (i - 1) % 3 ~= 0 then Slab.SameLine() end
      
      local is_active = tool.paint_type == t
      if self:private_draw_icon_button(t, self.icons[t], is_active) then
        tool.paint_type = t
      end
    end
    
  elseif tool.mode == "select" then
    Slab.NewLine()
    if #selection.entities > 0 then
      if Slab.Button("Clear Selection ("..#selection.entities..")", {W = 200}) then selection.entities = {} end
    else
        Slab.Text("No selection")
    end
  end
end

function DebugGUI:draw_gizmo_settings()
  local gizmos = self:getWorld():getResource("debug_gizmos")
  local style = Slab.GetStyle()

  -- Pathfinding Section Header/Toggle
  local any_path_on = gizmos.path or gizmos.pruning
  local path_color = nil
  if any_path_on then
    path_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end

  if Slab.Button("Pathing") then
    local new_state = not any_path_on
    gizmos.path = new_state
    gizmos.pruning = new_state
  end

  if path_color then style.ButtonColor = path_color end
  Slab.Separator()

  -- Draw Paths
  local path_btn_color = nil
  if gizmos.path then
    path_btn_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Draw Paths") then gizmos.path = not gizmos.path end
  if path_btn_color then style.ButtonColor = path_btn_color end

  -- Show Pruning
  local prune_btn_color = nil
  if gizmos.pruning then
    prune_btn_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Show Pruning") then gizmos.pruning = not gizmos.pruning end
  if prune_btn_color then style.ButtonColor = prune_btn_color end

  Slab.Separator()

  -- CBS Section Header/Toggle
  local any_cbs_on = gizmos.cbs_ring or gizmos.cbs_weights or gizmos.cbs_rays
                     or gizmos.deadlock or gizmos.hard_mask or gizmos.leash
  local cbs_color = nil
  if any_cbs_on then
    cbs_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end

  if Slab.Button("CBS") then
    local new_state = not any_cbs_on
    gizmos.cbs_ring = new_state
    gizmos.cbs_weights = new_state
    gizmos.cbs_rays = new_state
    gizmos.deadlock = new_state
    gizmos.hard_mask = new_state
    gizmos.leash = new_state
  end

  if cbs_color then style.ButtonColor = cbs_color end
  Slab.Separator()

  -- Interests Ring
  local ring_color = nil
  if gizmos.cbs_ring then
    ring_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Interests Ring") then gizmos.cbs_ring = not gizmos.cbs_ring end
  if ring_color then style.ButtonColor = ring_color end

  -- Direction Weights
  local weights_color = nil
  if gizmos.cbs_weights then
    weights_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Direction Weights") then gizmos.cbs_weights = not gizmos.cbs_weights end
  if weights_color then style.ButtonColor = weights_color end

  -- Raycasts
  local rays_color = nil
  if gizmos.cbs_rays then
    rays_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Raycasts") then gizmos.cbs_rays = not gizmos.cbs_rays end
  if rays_color then style.ButtonColor = rays_color end

  -- Deadlock Arrow
  local deadlock_color = nil
  if gizmos.deadlock then
    deadlock_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Deadlock Arrow") then gizmos.deadlock = not gizmos.deadlock end
  if deadlock_color then style.ButtonColor = deadlock_color end

  -- Hard Masks
  local mask_color = nil
  if gizmos.hard_mask then
    mask_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Hard Masks") then gizmos.hard_mask = not gizmos.hard_mask end
  if mask_color then style.ButtonColor = mask_color end

  -- Leash Radius
  local leash_color = nil
  if gizmos.leash then
    leash_color = {unpack(style.ButtonColor)}
    style.ButtonColor = {0.2, 0.5, 0.2, 1}
  end
  if Slab.Button("Leash Radius") then gizmos.leash = not gizmos.leash end
  if leash_color then style.ButtonColor = leash_color end
end

--[[----------------------------------------------------------------------------
  RIGHT PANEL: Inspector & Hierarchy
----------------------------------------------------------------------------]]--

function DebugGUI:draw_right_panel()
  local W, H = love.graphics.getDimensions()
  local PANEL_W = 208
  
  Slab.BeginWindow('RightPanel', {
    Title = "Inspector",
    X = W - PANEL_W, Y = 0, W = PANEL_W, H = H,
    AutoSizeWindow = false, AllowResize = true, AllowMove = false,
    SizerFilter = {"W"}
  })
  
  self:draw_outliner()
  Slab.Separator()
  self:draw_inspector_content()
  
  Slab.EndWindow()
end

function DebugGUI:draw_outliner()
  if Slab.BeginTree('Hierarchy', {IsOpen = UI.tree_hierarchy}) then
    UI.tree_hierarchy = true
    
    local selection = self:getWorld():getResource("debug_selection")
    
    if Slab.Input('##Filter', {Text = UI.filter_text, PlaceHolder = "Filter..."}) then
      UI.filter_text = Slab.GetInputText()
    end
    
    local function draw_list(label, pool)
      if Slab.BeginTree(label, {IsOpen = true}) then
        for _, entity in ipairs(pool) do
           local name = entity.Debug.entity_name or "Entity"
           if UI.filter_text == "" or string.find(string.lower(name), string.lower(UI.filter_text)) then
             local is_selected = false
             for _, s in ipairs(selection.entities) do if s == entity then is_selected = true break end end
             
             if Slab.TextSelectable(string.format("%s [ID:%s]", name, tostring(entity):sub(-6)), {IsSelected = is_selected}) then
               local shift = love.keyboard.isDown('lshift', 'rshift')
               local ctrl = love.keyboard.isDown('lctrl', 'rctrl')
               if ctrl then
                 local idx = nil
                 for i, s in ipairs(selection.entities) do if s == entity then idx = i break end end
                 if idx then table.remove(selection.entities, idx) else table.insert(selection.entities, entity) end
               elseif shift then
                 table.insert(selection.entities, entity)
               else
                 selection.entities = {entity}
               end
             end
           end
        end
        Slab.EndTree()
      end
    end
    
    draw_list("Player", self.pool_player)
    draw_list("AI Agents", self.pool_ai)
    draw_list("Obstacles", self.pool_obstacles)
    
    Slab.EndTree()
  else UI.tree_hierarchy = false end
end

function DebugGUI:draw_inspector_content()
  local selection = self:getWorld():getResource("debug_selection")
  local entities = selection.entities

  if #entities == 0 then return end

  if #entities > 1 then
    Slab.Text("Selection: " .. #entities .. " items")
    return
  end

  local entity = entities[1]
  Slab.Text("PROPERTIES: " .. (entity.Debug and entity.Debug.entity_name or "Unknown"))
  Slab.Separator()

  if entity.Transform then
    Slab.Text("Transform")
    Slab.Text(string.format("  X: %.2f", entity.Transform.x))
    Slab.Text(string.format("  Y: %.2f", entity.Transform.y))
  end

  if entity.Velocity then
    Slab.Text("Velocity")
    Slab.Text(string.format("  X: %.2f", entity.Velocity.x))
    Slab.Text(string.format("  Y: %.2f", entity.Velocity.y))
  end

  if entity.CBSBehaviorState then
    local state = entity.CBSBehaviorState
    Slab.Text("CBS Behavior")

    -- Current behavior with change buttons
    local override_active = state.manual_override_until > love.timer.getTime()
    local state_text = "  State: " .. (state.current or "none")
    if override_active then
      state_text = state_text .. " [MANUAL]"
    end
    Slab.Text(state_text)

    -- Blend indicator
    if state.blend_from and state.blend_progress < 1.0 then
      Slab.Text(string.format("  Blending: %s -> %s (%.0f%%)",
        state.blend_from, state.current, state.blend_progress * 100))
    end

    -- Behavior selection buttons
    Slab.Text("  Set Behavior:")
    local behaviors = {"pathfind", "seek", "wander", "flee", "strafe", "idle"}
    for i, behavior in ipairs(behaviors) do
      local is_current = state.current == behavior
      -- Wrap after 3 buttons per row
      if i > 1 and (i - 1) % 3 ~= 0 then Slab.SameLine() end

      local style = Slab.GetStyle()
      local old_color = nil
      if is_current then
        old_color = {unpack(style.ButtonColor)}
        style.ButtonColor = {0.2, 0.5, 0.2, 1}
      end

      if Slab.Button(behavior:sub(1,1):upper() .. behavior:sub(2,4), {W = 50, H = 20}) then
        if not is_current then
          -- Clear pathfinding waypoints when leaving pathfind state
          if state.current == "pathfind" and behavior ~= "pathfind" then
            clear_pathfind_waypoints(entity)
          end

          -- Clear target when transitioning to a state that doesn't use targets
          if TARGET_USING_STATES[state.current] and not TARGET_USING_STATES[behavior] then
            clear_target(entity)
          end

          -- Trigger blended transition with manual override protection
          local now = love.timer.getTime()
          state.blend_from = state.current
          state.blend_progress = 0.0
          state.blend_duration = UI.instant_transitions and 0.0 or 0.2
          state.previous = state.current
          state.current = behavior
          state.last_transition_time = now
          state.data = {}
          -- Block automatic transitions for 30 seconds after manual override
          state.manual_override_until = now + 30.0
        end
      end

      if is_current and old_color then
        style.ButtonColor = old_color
      end
    end

    -- Instant transitions toggle for testing
    Slab.NewLine()
    if Slab.CheckBox(UI.instant_transitions, "Instant Transitions") then
      UI.instant_transitions = not UI.instant_transitions
    end

    -- Speed display
    if state.current_speed then
      Slab.Text(string.format("  Speed: %.1f", state.current_speed))
    end

    -- Target info
    if state.has_target then
      Slab.Text(string.format("  Target: (%.0f, %.0f)", state.target_x, state.target_y))
    else
      Slab.Text("  Target: none")
    end

    -- Override debug info
    local now = love.timer.getTime()
    if override_active then
      local remaining = state.manual_override_until - now
      Slab.Text(string.format("  Override: %.1fs remaining", remaining))
    else
      Slab.Text("  Override: expired")
    end

    -- Last auto-transition info
    if state.last_auto_transition then
      local t = state.last_auto_transition
      local age = now - t.time
      Slab.Text(string.format("  Last auto: %s->%s (%.1fs ago)",
        t.from, t.to, age))
      Slab.Text(string.format("    condition: %s", tostring(t.condition)))
    end
  end

  if entity.Path then
    Slab.Text("Path")
    if entity.Path.waypoints then
      Slab.Text("  Waypoints: " .. #entity.Path.waypoints)
      Slab.Text("  Idx: " .. (entity.Path.current_index or 0))
    end
    Slab.Text("  Valid: " .. tostring(entity.Path.is_valid or false))
  end
end

--[[----------------------------------------------------------------------------
  UI HELPERS
----------------------------------------------------------------------------]]--

function DebugGUI:private_draw_toggle(label, is_active)
  local style = Slab.GetStyle()
  local old_color = nil
  
  if is_active then
     old_color = {unpack(style.ButtonColor)}
     style.ButtonColor = {0.3, 0.6, 0.3, 1}
  end
  
  local clicked = Slab.Button(label, {W = 200})
  
  if is_active then 
      style.ButtonColor = old_color
  end
  return clicked
end

function DebugGUI:private_draw_icon_button(name, image, is_active)
  -- For image buttons, we don't use ButtonColor since we draw an Image.
  -- But we use outline color for active state.
  
  local SIZE = 64
  
  Slab.Image(name, {
    Image = image,
    W = SIZE, H = SIZE,
    UseOutline = true,
    OutlineColor = is_active and {1, 1, 0, 1} or {0,0,0,1},
    OutlineW = is_active and 3 or 1,
    Tooltip = name
  })
  
  -- Check for click
  if Slab.IsControlClicked() then
    return true
  end
  
  return false
end

return DebugGUI
