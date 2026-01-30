# Slab: Immediate Mode GUI for LÖVE

Slab is an immediate mode GUI (IMGUI) library. State is managed by the library or your own logic, not by persistent UI objects.

## Integration Contract
```lua
local Slab = require 'libs.Slab'

function love.load(args)
    Slab.Initialize(args)
end

function love.update(dt)
    Slab.Update(dt)
    -- UI logic goes here (inside update or systems called by update)
end

function love.draw()
    Slab.Draw() -- Must be called last to overlay game world
end
```

## Core API Reference

- `Slab.BeginWindow(Id, Options)`: Starts a window context. `Options` include `Title`, `X`, `Y`, `W`, `H`, `AutoSizeWindow`, `AllowResize`, `AllowMove`.
  - **DOCKING**: To ensure stable docking, set `AutoSizeWindow = false` and provide fixed `W` and `H`.
  - **STABILITY**: Accidental 1-pixel drags do NOT undock/flicker windows due to a 25px "tear" threshold and a core fix in `Window.lua`.
- `Slab.EndWindow()`: Closes window context. **Required** if `BeginWindow` was called.

### Controls
- `Slab.Button(Label, Options)`: Returns `true` on click.
- `Slab.CheckBox(Enabled, Label, Options)`: Returns `true` on value change. Requires your own state tracking: `if Slab.CheckBox(my_var, "Label") then my_var = not my_var end`.
- `Slab.RadioButton(Label, Options)`: **CRITICAL**: Requires a table with `Index` and `SelectedIndex`.
  - `Options = { Index = 1, SelectedIndex = active_idx }`
  - Returns `true` if clicked.
- `Slab.Text(Label, Options)`: Static text.
- `Slab.TextSelectable(Label, Options)`: Selectable text (e.g., for lists). Returns `true` on click. Note: There is no `TextSelect`.

### Layout & Spacing
- `Slab.Separator()`: Draws a line.
- `Slab.NewLine()`: Manual vertical jump.
- `Slab.SameLine()`: Places next widget on the same horizontal line.

### Complex Widgets
- `Slab.BeginComboBox(Id, Options)`: Returns `true` if open. Requires `Slab.EndComboBox()`.
  - Use `Slab.TextSelectable` inside for items.
- `Slab.BeginTree(Id, Options)`: Returns `true` if expanded. Requires `Slab.EndTree()`.

---

## AGENT DOs AND DONTs

### ✅ DO
- **Use unique IDs**: Always provide unique string IDs for overlapping widgets or windows.
- **Handle returns**: Most widgets return a boolean indicating interaction; use `if` blocks to update your model state immediately.
- **Pass Options as Tables**: Even if empty, passing `{}` is safer than `nil`.
- **Query resources**: In ECS (Concord), store GUI visibility toggles in `world.getResource("dev_mode")`.

### ❌ DONT
- **DO NOT pass booleans to RadioButton**: `Slab.RadioButton("Label", true)` will **CRASH**. Use `{Index = 1, SelectedIndex = 1}`.
- **DO NOT call widgets outside of Update**: All `Begin/End` and logic must happen during `love.update`. Only `Slab.Draw()` happens in `love.draw`.
- **DO NOT mismatch Begin/End**: Every `BeginWindow`, `BeginComboBox`, `BeginTree` etc. **MUST** have a corresponding `End` call if the `Begin` call succeeded (or always for Windows).
- **DO NOT use TextSelect**: It doesn't exist. Use `TextSelectable`.
- **DO NOT re-enable the `IsDragging` check in `Window.Begin`**: This check in `libs/Slab/Internal/UI/Window.lua` was removed to fix "dock flickering." Removing it ensures docked windows respect their docked coordinates even while the user is clicking/dragging inside the window.
- **DO NOT use AutoSizeWindow for Docked Tools**: It can cause flickering as content height shifts; prefer fixed dimensions for complex side-bar tools.

## Pattern: ECS Integration
```lua
function UI_System:update(dt)
  local dev_mode = self:getWorld():getResource("dev_mode")
  if not dev_mode then return end

  Slab.BeginWindow('MyMenu', {Title = "Controls"})
    if Slab.Button("Clear All") then
      self:emit("clear_world")
    end
  Slab.EndWindow()
end
```
