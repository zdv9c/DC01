# HC Collision Detection Library - Quick Reference

## Overview
HC is a Lua collision detection library for LÖVE (Love2D). It detects collisions between arbitrary positioned and rotated shapes but does NOT resolve them - you decide how to respond. Uses spatial hashing for efficient neighbor detection.

**Supported Shapes**: rectangles, circles, polygons (including concave), points

## Installation
```lua
HC = require 'HC'
```

## Core Workflow
1. **Setup**: Create shapes and add to scene
2. **Update**: Move/rotate shapes  
3. **Detect**: Check for collisions
4. **React**: Handle collision response

---

## Main Module API

### Creating Shapes
All shape creation functions automatically register shapes with spatial hash.

```lua
-- Rectangle (centered on x,y)
shape = HC.rectangle(x, y, width, height)

-- Circle
shape = HC.circle(cx, cy, radius)

-- Polygon (any non-self-intersecting polygon, even concave)
shape = HC.polygon(x1,y1, x2,y2, x3,y3, ..., xn,yn)
-- Note: Auto-closed, collinear points removed

-- Point (fast collision check, useful for bullets)
shape = HC.point(x, y)
-- Warning: Separating vector invalid for point collisions
```

### Shape Management

```lua
-- Manually register custom shape
HC.register(shape)

-- Remove shape (invalidates shape:move/rotate/scale)
HC.remove(shape)
-- Must also remove from your own actor lists!

-- Reset everything (clears all shapes)
HC.resetHash()
```

### Collision Detection

```lua
-- Get all colliding shapes + separating vectors
collisions = HC.collisions(shape)
for other, sep_vec in pairs(collisions) do
    -- sep_vec.x, sep_vec.y: direction to move 'shape' to resolve
    shape:move(sep_vec.x/2, sep_vec.y/2)
    other:move(-sep_vec.x/2, -sep_vec.y/2)
end

-- Get nearby shapes (same spatial hash cell)
neighbors = HC.neighbors(shape)
for other in pairs(neighbors) do
    local collides, dx, dy = shape:collidesWith(other)
    if collides then
        other:move(dx, dy)
    end
end

-- Get shapes containing point
shapes = HC.shapesAt(x, y)
for shape in pairs(shapes) do
    -- process shape
end

-- Raycast
hits = HC.raycast(x, y, dx, dy, range)
for shape, points in pairs(hits) do
    for _, point in ipairs(points) do
        -- point.x, point.y
    end
end
```

### Multiple Collision Worlds

```lua
-- Create separate collision instances
collider = HC.new(cell_size)  -- default: 100

-- Use colon syntax for instance methods
ball = collider:circle(100, 100, 20)
rect = collider:rectangle(110, 90, 20, 100)

for shape, delta in pairs(collider:collisions(ball)) do
    shape:move(delta.x, delta.y)
end
```

**Cell Size Guide**: Set to ~4x average object size. Only tune if performance issues traced to spatial hash.

---

## Shape Methods

All shapes are Lua tables - you can attach custom data. Avoid keys starting with `_` or matching function names.

### Transform Methods

```lua
-- Relative movement
shape:move(dx, dy)

-- Absolute positioning (centers shape at x,y)
shape:moveTo(x, y)

-- Get center
cx, cy = shape:center()

-- Rotate by angle (radians)
shape:rotate(angle, [cx, cy])  -- optional rotation center

-- Set absolute rotation
shape:setRotation(angle, [cx, cy])

-- Get current rotation
angle = shape:rotation()

-- Scale relative to center
shape:scale(sx, sy)
```

### Query Methods

```lua
-- Axis-aligned bounding box
x1, y1, x2, y2 = shape:bbox()
-- x1,y1 = upper-left; x2,y2 = lower-right

-- Bounding circle
cx, cy, radius = shape:outcircle()

-- Check collision with another shape
collides, dx, dy = shape:collidesWith(other)
-- dx,dy: separating vector (direction to move 'other')

-- Point containment
contains = shape:contains(x, y)

-- Ray intersection (returns all intersections)
ts = shape:intersectionsWithRay(x, y, dx, dy)
for _, t in ipairs(ts) do
    ix, iy = x + t*dx, y + t*dy  -- intersection point
end

-- Ray intersection (returns first/closest)
intersects, t = shape:intersectsRay(x, y, dx, dy)
if intersects then
    ix, iy = x + t*dx, y + t*dy
end

-- Advanced: support function (for GJK algorithm)
vx, vy = shape:support(dx, dy)
-- Returns furthest vertex in direction (dx,dy)
```

### Drawing (Debug)

```lua
-- Draw shape
shape:draw(mode)  -- mode: 'fill' or 'line'

-- Example
love.graphics.setColor(255, 255, 255)
shape:draw('fill')
```

---

## Polygon Class

Standalone polygon utilities (no collision detection). For collision, use HC.polygon().

```lua
Polygon = require 'HC.polygon'
poly = Polygon(x1,y1, x2,y2, ..., xn,yn)
```

### Polygon Methods

```lua
-- Get vertices for drawing
x1,y1, ..., xn,yn = poly:unpack()
love.graphics.polygon('line', poly:unpack())

-- Deep copy (avoid reference issues)
copy = poly:clone()

-- Bounding box
x1, y1, x2, y2 = poly:bbox()

-- Check if convex
is_convex = poly:isConvex()

-- Transform
poly:move(dx, dy)
poly:rotate(angle, [cx, cy])

-- Triangulation
triangles = poly:triangulate()  -- returns table of Polygons
for i, tri in ipairs(triangles) do
    -- each tri is a Polygon with 3 vertices
end

-- Split into convex sub-polygons
convex_parts = poly:splitConvex()

-- Merge two polygons sharing an edge
merged = poly:mergedWith(other)  -- returns nil if no shared edge

-- Point containment
contains = poly:contains(x, y)

-- Ray intersection
ts = poly:intersectionsWithRay(x, y, dx, dy)
```

---

## Spatial Hash

Access via `HC.hash()` - usually not needed directly.

```lua
spatialhash = require 'HC.spatialhash'
hash = Spatialhash(cell_size)

-- Get cell coordinates
cx, cy = hash:cellCoords(x, y)
```

---

## Usage Patterns

### Basic Example
```lua
HC = require 'HC'

function love.load()
    rect = HC.rectangle(200, 400, 400, 20)
    mouse = HC.circle(400, 300, 20)
    mouse:moveTo(love.mouse.getPosition())
end

function love.update(dt)
    mouse:moveTo(love.mouse.getPosition())
    rect:rotate(dt)
    
    for shape, delta in pairs(HC.collisions(mouse)) do
        -- Handle collision
    end
end

function love.draw()
    rect:draw('fill')
    mouse:draw('fill')
end
```

### Bullet Management
```lua
-- Use points for fast bullet collision
bullets[#bullets+1] = HC.point(player.x, player.y)

-- Cleanup
for i = #bullets, 1, -1 do
    if bullets[i]:collidesWith(player) then
        HC.remove(bullets[i])
        table.remove(bullets, i)
    end
end
```

### Efficient Collision Detection
```lua
-- 1. Check neighbors first (broad phase)
local candidates = HC.neighbors(shape)

-- 2. Precise collision check (narrow phase)
for other in pairs(candidates) do
    local collides, dx, dy = shape:collidesWith(other)
    if collides then
        -- Resolve collision
    end
end
```

### Attach Game Data
```lua
player = HC.circle(100, 100, 20)
player.health = 100
player.type = "player"
player.speed = 200

enemy = HC.rectangle(300, 300, 40, 40)
enemy.type = "enemy"
enemy.damage = 10

-- In collision handling
for other, sep in pairs(HC.collisions(player)) do
    if other.type == "enemy" then
        player.health = player.health - other.damage
    end
end
```

---

## Important Notes

### Shape Transformations
- Rectangle/polygon transforms are relative to **center**, not corner
- Always use registered shapes with HC.collisions()/neighbors()
- Shapes created with HC.rectangle/circle/etc are auto-registered

### Memory Management
- HC.remove() invalidates move/rotate/scale - remove from your lists too!
- Use HC.resetHash() to clear entire scene
- Shapes are Lua tables with references - use polygon:clone() for copies

### Performance
- Spatial hash grid is sparse (cells created on-demand)
- Optimal cell_size ≈ 4× average object size
- Point shapes are faster than other shapes for collision checks
- Use HC.neighbors() for broad-phase before detailed checks

### Collision Vectors
- Separating vector points in direction to move the **second** shape
- For point collisions, separating vector is invalid
- Vector length = minimum distance to separate shapes

### Polygon Requirements
- Must be non-self-intersecting
- Concave polygons supported
- Auto-removes collinear points
- Auto-closes polygon (first != last point)

---

## Common Pitfalls

```lua
-- ❌ WRONG: Using unregistered shape
custom_shape = MyShape()
HC.collisions(custom_shape)  -- Won't work!

-- ✅ CORRECT: Register first
custom_shape = MyShape()
HC.register(custom_shape)
HC.collisions(custom_shape)

-- ❌ WRONG: Forgetting to remove from own list
HC.remove(bullet)
-- bullet still in your bullets[] table!

-- ✅ CORRECT: Remove from both
HC.remove(bullets[i])
table.remove(bullets, i)

-- ❌ WRONG: Reference instead of clone
p2 = p1
p2:rotate(math.pi)  -- p1 also rotates!

-- ✅ CORRECT: Clone the polygon
p2 = p1:clone()
p2:rotate(math.pi)  -- only p2 rotates
```

---

## Quick Command Reference

```lua
-- Shape Creation
HC.rectangle(x, y, w, h)
HC.circle(cx, cy, r)
HC.polygon(x1,y1, ...)
HC.point(x, y)

-- Management
HC.register(shape)
HC.remove(shape)
HC.resetHash()

-- Detection
HC.collisions(shape) -> {[shape]=vec}
HC.neighbors(shape) -> {[shape]=true}
HC.shapesAt(x,y) -> {[shape]=true}
HC.raycast(x,y,dx,dy,range) -> {[shape]={points}}

-- Transform
shape:move(dx, dy)
shape:moveTo(x, y)
shape:rotate(angle, [cx, cy])
shape:scale(sx, sy)

-- Query
shape:collidesWith(other) -> bool, dx, dy
shape:contains(x, y) -> bool
shape:bbox() -> x1, y1, x2, y2
shape:center() -> x, y

-- Polygon Specific
poly:triangulate() -> {Polygon}
poly:splitConvex() -> {Polygon}
poly:unpack() -> x1,y1,...,xn,yn
poly:isConvex() -> bool
```

---

## Version Info
- Version: 0.1-1
- Author: Matthias Richter (vrld)
- Source: https://github.com/vrld/HC
- Docs: https://hc.readthedocs.io/