--[[============================================================================
  ENTITY: Obstacle
  
  PURPOSE: Assembler for static block obstacles
============================================================================]]--

return function(e, x, y)
  -- Core Physics & Transform
  e:give("Transform", x, y)
  e:give("Collider", 16, 16, "static")
  
  -- Rendering
  e:give("Sprite", {0.5, 0.5, 0.5, 1}, 8)  -- Grey
  
  -- Debugging
  e:give("Debug", {
    entity_name = "Block",
    track_collision = false
  })
  
  return e
end
