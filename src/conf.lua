function love.conf(t)
    t.identity = "tower_rpg" 
    t.window.title = "Tower RPG"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 240
    
    t.modules.physics = false -- We use HardonCollider, so we can disable Box2D if not needed
    t.console = true
end
