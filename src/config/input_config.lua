-- Input configuration for keyboard and gamepad mappings
-- This centralizes all input bindings to make remapping easier

local INPUT_CONFIG = {
    -- Deadzone for analog sticks to filter drift
    DEADZONE = 0.04,

    -- Input buffer duration in seconds (helps with timing-sensitive inputs)
    BUFFER_DURATION = 0.1,

    -- Keyboard bindings
    keyboard = {
        -- Movement (WASD)
        move_up = "w",
        move_down = "s",
        move_left = "a",
        move_right = "d",

        -- Rotation (H/L)
        rotate_left = "h",
        rotate_right = "l",

        -- Actions
        charge = "j",
        cancel_charge = "k",

        -- Debug
        toggle_debug = "f1",
        cycle_knockback_preset = "f2",
        toggle_charge_mode = "f3",
        hot_reload = "f5"
    },

    -- Gamepad bindings (using standard gamepad mapping)
    gamepad = {
        -- Movement sticks
        move_stick_x = "leftx",
        move_stick_y = "lefty",
        rotate_stick_x = "rightx",

        -- D-pad movement
        dpad_up = "dpup",
        dpad_down = "dpdown",
        dpad_left = "dpleft",
        dpad_right = "dpright",

        -- Action buttons
        charge = "rightshoulder",
        cancel_charge = "leftshoulder"
    },

    -- Raw joystick fallback (for non-gamepad controllers)
    joystick = {
        move_axis_x = 1,
        move_axis_y = 2,
        rotate_axis_x = 3
        -- Note: Raw joystick doesn't support button mapping reliably
    }
}

-- Validation function to ensure all required bindings are present
function INPUT_CONFIG.validate()
    local required_keyboard = {
        "move_up", "move_down", "move_left", "move_right",
        "rotate_left", "rotate_right", "charge", "cancel_charge"
    }

    local required_gamepad = {
        "move_stick_x", "move_stick_y", "rotate_stick_x",
        "dpad_up", "dpad_down", "dpad_left", "dpad_right",
        "charge", "cancel_charge"
    }

    -- Check keyboard bindings
    for _, key in ipairs(required_keyboard) do
        if not INPUT_CONFIG.keyboard[key] then
            error("Missing keyboard binding: " .. key)
        end
    end

    -- Check gamepad bindings
    for _, key in ipairs(required_gamepad) do
        if not INPUT_CONFIG.gamepad[key] then
            error("Missing gamepad binding: " .. key)
        end
    end

    return true
end

-- Function to remap a keyboard key
function INPUT_CONFIG.remap_keyboard(action, new_key)
    if not INPUT_CONFIG.keyboard[action] then
        error("Unknown keyboard action: " .. tostring(action))
    end
    INPUT_CONFIG.keyboard[action] = new_key
end

-- Function to remap a gamepad button/axis
function INPUT_CONFIG.remap_gamepad(action, new_binding)
    if not INPUT_CONFIG.gamepad[action] then
        error("Unknown gamepad action: " .. tostring(action))
    end
    INPUT_CONFIG.gamepad[action] = new_binding
end

-- Get all current bindings for display/saving
function INPUT_CONFIG.get_all_bindings()
    return {
        keyboard = INPUT_CONFIG.keyboard,
        gamepad = INPUT_CONFIG.gamepad,
        joystick = INPUT_CONFIG.joystick
    }
end

return INPUT_CONFIG
