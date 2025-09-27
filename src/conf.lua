--@class love
function love.conf(t)
    t.window.title = "Headbutt"
    t.window.width = 1280                          -- The window width
    t.window.height = 720                          -- The window height
    t.window.resizable = true                      -- Disable window resizing
    t.window.vsync = 1                             -- Enable vertical sync
    t.window.highdpi = true                        -- Enable high-DPI mode
    t.window.usedpiscale = true                    -- Scale the window according to DPI
    t.modules.audio = true                         -- Enable the audio module
    t.modules.keyboard = true                      -- Enable the keyboard module
    t.modules.mouse = true                         -- Enable the mouse module
    t.modules.joystick = true                      -- Enable joystick/gamepad module
    t.modules.graphics = true                      -- Enable the graphics module
    t.version = "11.4"                             -- The LÖVE version this game was made for                      -- The window height
end