local window = require("util.window")
local graphics = require("util.graphics")
local input_manager = require("input_manager")
local GameManager = require("game_manager")
local HotReloadManager = require("util.hot_reload")

-- Initialize hot reload manager
local hot_reload_manager = HotReloadManager.new()
hot_reload_manager:install()

local dudeOffset = 240
local inputManager = {}
local gameManager = {}

--@class love
function love.load()
    window.resize()
    inputManager = input_manager.new()
    gameManager = GameManager.new()

    -- Create player 1 dude (blue)
    gameManager:create_player_dude(
        window.width / 2 - dudeOffset,
        window.height / 2,
        90,
        {0, 0, 1, 1},
        {1.0, 0.85, 0.73, 1},
        1
    )

    -- Create player 2 dude (red)
    gameManager:create_player_dude(
        window.width / 2 + dudeOffset,
        window.height / 2,
        -90,
        {1, 0, 0, 1},
        {1.0, 0.85, 0.73, 1},
        2
    )
end

function love.update(dt)
    local playerInput = inputManager:process_input(dt)

    -- Check for hot reload changes
    if gameManager.debug_mode then
        local reloaded = hot_reload_manager:check_for_changes()
        if #reloaded > 0 then
            -- Preserve important state
            local state = {
                debug_mode = gameManager.debug_mode,
                charge_input_mode = gameManager.charge_input_mode,
                current_knockback_preset = gameManager.current_knockback_preset
            }

            -- Recreate game manager with preserved state
            gameManager = GameManager.new()
            gameManager.debug_mode = state.debug_mode
            gameManager.charge_input_mode = state.charge_input_mode
            gameManager.current_knockback_preset = state.current_knockback_preset

            -- Recreate players
            gameManager:create_player_dude(
                window.width / 2 - dudeOffset,
                window.height / 2,
                90,
                {0, 0, 1, 1},
                {1.0, 0.85, 0.73, 1},
                1
            )
            gameManager:create_player_dude(
                window.width / 2 + dudeOffset,
                window.height / 2,
                -90,
                {1, 0, 0, 1},
                {1.0, 0.85, 0.73, 1},
                2
            )
        end
    end

    -- Update game using component system
    gameManager:update(dt, playerInput)
end

function love.draw()
    graphics.preDraw(window)

    -- Draw all entities using component system
    gameManager:draw()

    love.graphics.pop()
end

function love.resize(w, h)
    window.resize(w, h)
end

function love.joystickadded(joystick)
    inputManager:handle_joystick_added(joystick)
end

function love.joystickremoved(joystick)
    inputManager:handle_joystick_removed(joystick)
end

function love.gamepadpressed(joystick, button)
    inputManager:handle_gamepad_pressed(joystick, button)
end

function love.joystickpressed(joystick, button)
    inputManager:handle_joystick_pressed(joystick, button)
end

function love.keypressed(key)
    local INPUT_CONFIG = require("config.input_config")

    -- Handle hot reload key
    if key == INPUT_CONFIG.keyboard.hot_reload then
        hot_reload_manager:set_debug(gameManager.debug_mode)
        local reloaded = hot_reload_manager:check_for_changes()
        if #reloaded > 0 and gameManager.debug_mode then
            print("Hot reloaded modules:", table.concat(reloaded, ", "))
        end
        return
    end
    if key == INPUT_CONFIG.keyboard.toggle_debug then
        gameManager:toggle_debug_mode()
    elseif key == INPUT_CONFIG.keyboard.cycle_knockback_preset then
        gameManager:cycle_knockback_preset()
    elseif key == INPUT_CONFIG.keyboard.toggle_charge_mode then
        gameManager:toggle_charge_input_mode()
    end
end