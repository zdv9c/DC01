--[[============================================================================
  ENTITY: Player
  
  PURPOSE: Assembler for the main player character
============================================================================]]--

return function(e, x, y)
  -- Core Physics & Transform
  e:give("Transform", x, y)
  e:give("Velocity", 0, 0)
  e:give("Collider", 16, 16, "dynamic")
  
  -- Rendering
  e:give("Sprite", {0, 1, 0, 1}, 8)  -- Green circle
  
  -- Behavior / Tags
  e:give("PlayerControlled")
  e:give("CameraTarget")  -- Camera follows this entity
  
  -- Debugging
  e:give("Debug", {
    entity_name = "Player",
    track_position = true,
    track_velocity = true,
    track_collision = true
  })
  
  return e
end
