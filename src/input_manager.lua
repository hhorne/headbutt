---@class InputManager Handles input processing for keyboard, gamepad, and joystick
---@field controller1 love.Joystick? First assigned controller (Player 1)
---@field controller2 love.Joystick? Second assigned controller (Player 2)
---@field controller1_id number? ID of controller1
---@field controller2_id number? ID of controller2
---@field input_type string Current input type ("keyboard", "gamepad", "joystick", "mixed")
---@field input_buffer InputBuffer Buffer for timing-sensitive inputs (Player 1)
---@field input_buffer2 InputBuffer Buffer for timing-sensitive inputs (Player 2)
---@field prev_charging boolean[] Previous frame charging states per player
---@field prev_charge_cancel boolean[] Previous frame charge cancel states per player
---@field joysticks love.Joystick[]? List of available joysticks
local InputManager = {}
InputManager.__index = InputManager

local Vector2 = require("util.vector2")
local INPUT_CONFIG = require("config.input_config")
local ErrorUtils = require("util.error_handler")

---Input buffer to store recent inputs for timing-sensitive actions
---@class InputBuffer
---@field entries InputBufferEntry[] List of buffered input entries
local InputBuffer = {}
InputBuffer.__index = InputBuffer

---@class InputBufferEntry
---@field action string Action name that was performed
---@field time number Timestamp when action occurred

---Create a new input buffer
---@return InputBuffer buffer New input buffer instance
function InputBuffer.new()
    local self = setmetatable({}, InputBuffer)
    self.entries = {}
    return self
end

---Add an input action to the buffer
---@param action string Action name to buffer
---@param timestamp number Time when action occurred
function InputBuffer:add_input(action, timestamp)
    if not ErrorUtils.validate_type(action, "string", "action", "InputBuffer:add_input") then
        return
    end
    if not ErrorUtils.validate_type(timestamp, "number", "timestamp", "InputBuffer:add_input") then
        return
    end

    table.insert(self.entries, {action = action, time = timestamp})
end

---Check if an action was performed recently
---@param action string Action name to check
---@param current_time number Current timestamp
---@param max_age number? Maximum age in seconds (default: from config)
---@return boolean has_recent True if action was performed recently
function InputBuffer:has_recent_input(action, current_time, max_age)
    if not ErrorUtils.validate_type(action, "string", "action", "InputBuffer:has_recent_input") then
        return false
    end
    if not ErrorUtils.validate_type(current_time, "number", "current_time", "InputBuffer:has_recent_input") then
        return false
    end

    max_age = max_age or INPUT_CONFIG.BUFFER_DURATION
    for i = #self.entries, 1, -1 do
        local entry = self.entries[i]
        local age = current_time - entry.time
        if age > max_age then
            -- Remove old entries
            table.remove(self.entries, i)
        elseif entry.action == action and age <= max_age then
            return true
        end
    end
    return false
end

---Clear all buffered inputs
function InputBuffer:clear()
    self.entries = {}
end

---Create a new InputManager instance
---@return InputManager input_manager New InputManager instance
function InputManager.new()
    local self = setmetatable({}, InputManager)

    -- Validate input configuration with error handling
    local success, error_msg = ErrorUtils.safe_call(
        INPUT_CONFIG.validate,
        "Failed to validate input configuration",
        "InputManager.new"
    )

    if not success then
        ErrorUtils.log_error(
            "Input configuration validation failed, using defaults: " .. tostring(error_msg),
            ErrorUtils.Severity.WARNING,
            "InputManager.new"
        )
    end

    -- Controller slots for local multiplayer
    self.controller1 = nil
    self.controller2 = nil
    self.controller1_id = nil
    self.controller2_id = nil
    self.input_type = "keyboard"
    -- Separate input buffers per player for edge buffering
    self.input_buffer = InputBuffer.new() -- Player 1 buffer (back-compat name)
    self.input_buffer2 = InputBuffer.new() -- Player 2 buffer
    -- Track previous button states to detect press transitions (per player)
    self.prev_charging = {false, false}
    self.prev_charge_cancel = {false, false}

    -- Auto-assign first controller if available with error handling
    local success, joysticks = ErrorUtils.safe_call(
        love.joystick.getJoysticks,
        "Failed to get joystick list",
        "InputManager.new"
    )

    self.joysticks = success and (joysticks or {}) or {}
    -- Assign up to two controllers if available
    if #self.joysticks > 0 then
        local c1 = self.joysticks[1]
        if ErrorUtils.validate_controller_connection(c1, "InputManager.new") then
            local ok, id1 = ErrorUtils.safe_love_call(c1, "getID", "Failed to get controller ID", "InputManager.new")
            if ok then
                self.controller1 = c1
                self.controller1_id = id1
                self.input_type = c1:isGamepad() and "mixed" or "joystick"
            end
        end
    end
    if #self.joysticks > 1 then
        local c2 = self.joysticks[2]
        if ErrorUtils.validate_controller_connection(c2, "InputManager.new") then
            local ok, id2 = ErrorUtils.safe_love_call(c2, "getID", "Failed to get controller ID", "InputManager.new")
            if ok then
                self.controller2 = c2
                self.controller2_id = id2
            end
        end
    end

    return self
end

-- Device-specific input processors
local KeyboardProcessor = {}
local GamepadProcessor = {}
local JoystickProcessor = {}

function KeyboardProcessor.process(dt, current_time, input_buffer)
    local movement = Vector2.zero()
    local rotation = 0
    local charging = false
    local chargeCancel = false

    local config = INPUT_CONFIG.keyboard

    -- WASD movement
    if love.keyboard.isDown(config.move_up) then
        movement.y = movement.y - 1
    end
    if love.keyboard.isDown(config.move_down) then
        movement.y = movement.y + 1
    end
    if love.keyboard.isDown(config.move_left) then
        movement.x = movement.x - 1
    end
    if love.keyboard.isDown(config.move_right) then
        movement.x = movement.x + 1
    end

    -- H and L for rotation
    if love.keyboard.isDown(config.rotate_left) then
        rotation = rotation - 1
    end
    if love.keyboard.isDown(config.rotate_right) then
        rotation = rotation + 1
    end

    -- Action buttons
    if love.keyboard.isDown(config.charge) then
        charging = true
    end

    if love.keyboard.isDown(config.cancel_charge) then
        chargeCancel = true
    end

    -- Normalize diagonal movement
    movement = movement:normalized()

    return {
        movement = movement,
        rotation = rotation,
        charging = charging,
        chargeCancel = chargeCancel,
        inputType = "keyboard"
    }
end

---Process gamepad input with comprehensive error handling
---@param js love.Joystick? Joystick object
---@param dt number Delta time (unused)
---@param current_time number Current timestamp (unused)
---@param input_buffer InputBuffer Input buffer (unused)
---@return table? input_data Processed input data or nil if invalid
function GamepadProcessor.process(js, dt, current_time, input_buffer)
    -- Validate joystick connection
    if not ErrorUtils.validate_controller_connection(js, "GamepadProcessor.process") then
        return nil
    end

    -- Verify it's actually a gamepad
    local success, is_gamepad = ErrorUtils.safe_love_call(
        js,
        "isGamepad",
        "Failed to check if joystick is gamepad",
        "GamepadProcessor.process"
    )

    if not success or not is_gamepad then
        return nil
    end

    local config = INPUT_CONFIG.gamepad

    -- Analog stick movement with deadzone (with error handling)
    local lx, ly, rx = 0, 0, 0

    local success, axis_x = ErrorUtils.safe_love_call(
        js, "getGamepadAxis", nil, "GamepadProcessor.process", config.move_stick_x
    )
    if success then lx = axis_x or 0 end

    local success, axis_y = ErrorUtils.safe_love_call(
        js, "getGamepadAxis", nil, "GamepadProcessor.process", config.move_stick_y
    )
    if success then ly = axis_y or 0 end

    local success, rotate_axis = ErrorUtils.safe_love_call(
        js, "getGamepadAxis", nil, "GamepadProcessor.process", config.rotate_stick_x
    )
    if success then rx = rotate_axis or 0 end

    local movement = Vector2.new(lx, ly):apply_deadzone(INPUT_CONFIG.DEADZONE)
    local rotation = math.abs(rx) < INPUT_CONFIG.DEADZONE and 0 or rx

    -- D-pad movement (additive with analog stick) with error handling
    local dpad_states = {}
    local dpad_buttons = {
        {config.dpad_left, "dpad_left"},
        {config.dpad_right, "dpad_right"},
        {config.dpad_up, "dpad_up"},
        {config.dpad_down, "dpad_down"}
    }

    for _, button_info in ipairs(dpad_buttons) do
        local button, name = button_info[1], button_info[2]
        local success, is_down = ErrorUtils.safe_love_call(
            js, "isGamepadDown", nil, "GamepadProcessor.process", button
        )
        dpad_states[name] = success and is_down or false
    end

    if dpad_states.dpad_left then movement.x = movement.x - 1 end
    if dpad_states.dpad_right then movement.x = movement.x + 1 end
    if dpad_states.dpad_up then movement.y = movement.y - 1 end
    if dpad_states.dpad_down then movement.y = movement.y + 1 end

    -- Action buttons with error handling
    local charging, chargeCancel = false, false

    local success, charge_pressed = ErrorUtils.safe_love_call(
        js, "isGamepadDown", nil, "GamepadProcessor.process", config.charge
    )
    if success then charging = charge_pressed or false end

    local success, cancel_pressed = ErrorUtils.safe_love_call(
        js, "isGamepadDown", nil, "GamepadProcessor.process", config.cancel_charge
    )
    if success then chargeCancel = cancel_pressed or false end

    -- Clamp movement values and normalize if needed
    movement = movement:clamp(-1, 1)
    if movement:magnitude() > 1 then
        movement = movement:normalized()
    end

    return {
        movement = movement,
        rotation = rotation,
        charging = charging,
        chargeCancel = chargeCancel,
        inputType = "gamepad"
    }
end

function JoystickProcessor.process(js, dt, current_time, input_buffer)
    if not js then
        return nil
    end

    local config = INPUT_CONFIG.joystick

    -- Raw joystick fallback: axes 1,2 (left stick), 3 (right stick X) on many devices
    local lx = js:getAxis(config.move_axis_x) or 0
    local ly = js:getAxis(config.move_axis_y) or 0
    local rx = js:getAxis(config.rotate_axis_x) or 0

    local movement = Vector2.new(lx, ly):apply_deadzone(INPUT_CONFIG.DEADZONE)

    return {
        movement = movement,
        rotation = math.abs(rx) < INPUT_CONFIG.DEADZONE and 0 or rx,
        charging = false, -- Raw joystick doesn't support reliable button detection
        chargeCancel = false,
        inputType = "joystick"
    }
end

-- Update joystick list
function InputManager:update_joysticks()
    self.joysticks = love.joystick.getJoysticks()
end

-- Get the first connected controller
function InputManager:get_first_controller()
    return self.joysticks and self.joysticks[1]
end

-- Main input processing function - supports multiple players but maintains backward compatibility
function InputManager:process_input(dt)
    local current_time = love.timer.getTime()
    local inputs = {}

    -- Process player 1 (keyboard + optional controller)
    local player1Input = {
        movement = Vector2.zero(),
        rotation = 0,
        charging = false,
        chargeCancel = false,
        inputType = "keyboard",
        player = 1
    }

    -- Start with keyboard input as base for player 1
    local keyboardInput = KeyboardProcessor.process(dt, current_time, self.input_buffer)
    player1Input = keyboardInput
    player1Input.player = 1

    -- Process controller input if available and merge with keyboard for player 1
    if self.controller1 then
        local controllerInput = nil
        if self.controller1:isGamepad() then
            controllerInput = GamepadProcessor.process(self.controller1, dt, current_time, self.input_buffer)
        else
            controllerInput = JoystickProcessor.process(self.controller1, dt, current_time, self.input_buffer)
        end

        if controllerInput then
            -- Combine movement inputs (additive) instead of priority-based
            if not controllerInput.movement:is_zero() or not player1Input.movement:is_zero() then
                local combined_movement = player1Input.movement + controllerInput.movement
                -- Normalize combined movement to prevent diagonal speed boost
                if combined_movement:magnitude() > 1 then
                    combined_movement = combined_movement:normalized()
                end
                player1Input.movement = combined_movement
            end

            -- Controller rotation takes priority (more precise)
            if controllerInput.rotation ~= 0 then
                player1Input.rotation = controllerInput.rotation
            end

            -- Combine action inputs (OR logic - either device can trigger)
            player1Input.charging = player1Input.charging or controllerInput.charging
            player1Input.chargeCancel = player1Input.chargeCancel or controllerInput.chargeCancel
            player1Input.inputType = "mixed"
        end
    end

    -- Process input buffering and edge detection for player 1
    local chargePressed = false
    local cancelPressed = false
    if player1Input.charging and not self.prev_charging[1] then
        chargePressed = true
        self.input_buffer:add_input("charge", current_time)
    end

    if player1Input.chargeCancel and not self.prev_charge_cancel[1] then
        cancelPressed = true
        self.input_buffer:add_input("cancel_charge", current_time)
    end

    -- Apply input buffering - if button isn't currently pressed but was pressed recently
    if not player1Input.charging and self.input_buffer:has_recent_input("charge", current_time) then
        player1Input.charging = true
    end

    if not player1Input.chargeCancel and self.input_buffer:has_recent_input("cancel_charge", current_time) then
        player1Input.chargeCancel = true
    end

    -- Expose press-edge booleans for systems that require explicit presses
    player1Input.chargePressed = chargePressed
    player1Input.cancelPressed = cancelPressed

    -- Update previous button states for next frame
    self.prev_charging[1] = player1Input.charging
    self.prev_charge_cancel[1] = player1Input.chargeCancel

    -- Convert Vector2 back to table for compatibility with existing dude system
    player1Input.movement = player1Input.movement:to_table()

    -- Add player 1 input to the inputs array
    inputs[1] = player1Input

    -- Build Player 2 input from controller 2 if present
    if self.controller2 then
        local p2 = {
            movement = Vector2.zero(),
            rotation = 0,
            charging = false,
            chargeCancel = false,
            inputType = "gamepad",
            player = 2
        }

        local controllerInput2 = nil
        if self.controller2:isGamepad() then
            controllerInput2 = GamepadProcessor.process(self.controller2, dt, current_time, self.input_buffer2)
        else
            controllerInput2 = JoystickProcessor.process(self.controller2, dt, current_time, self.input_buffer2)
        end

        if controllerInput2 then
            p2.movement = controllerInput2.movement
            p2.rotation = controllerInput2.rotation
            p2.charging = controllerInput2.charging
            p2.chargeCancel = controllerInput2.chargeCancel
            p2.inputType = controllerInput2.inputType
        end

        local chargePressed2 = false
        local cancelPressed2 = false
        if p2.charging and not self.prev_charging[2] then
            chargePressed2 = true
            self.input_buffer2:add_input("charge", current_time)
        end
        if p2.chargeCancel and not self.prev_charge_cancel[2] then
            cancelPressed2 = true
            self.input_buffer2:add_input("cancel_charge", current_time)
        end

        if not p2.charging and self.input_buffer2:has_recent_input("charge", current_time) then
            p2.charging = true
        end
        if not p2.chargeCancel and self.input_buffer2:has_recent_input("cancel_charge", current_time) then
            p2.chargeCancel = true
        end

        p2.chargePressed = chargePressed2
        p2.cancelPressed = cancelPressed2
        self.prev_charging[2] = p2.charging
        self.prev_charge_cancel[2] = p2.chargeCancel

        p2.movement = p2.movement:to_table()
        inputs[2] = p2
    end

    return inputs
end

-- Controller assignment helpers
local function joystick_equals(a, b)
    return a ~= nil and b ~= nil and a == b
end

function InputManager:handle_gamepad_pressed(joystick, button)
    if joystick_equals(self.controller1, joystick) or joystick_equals(self.controller2, joystick) then
        return
    end
    if not self.controller1 then
        self.controller1 = joystick
        self.controller1_id = joystick:getID()
        self.input_type = joystick:isGamepad() and "mixed" or "joystick"
    elseif not self.controller2 then
        self.controller2 = joystick
        self.controller2_id = joystick:getID()
    end
end

function InputManager:handle_joystick_pressed(joystick, button)
    if joystick_equals(self.controller1, joystick) or joystick_equals(self.controller2, joystick) then
        return
    end
    if not self.controller1 then
        self.controller1 = joystick
        self.controller1_id = joystick:getID()
        self.input_type = "joystick"
    elseif not self.controller2 then
        self.controller2 = joystick
        self.controller2_id = joystick:getID()
    end
end

function InputManager:handle_joystick_added(joystick)
    self:update_joysticks()
    local jid = joystick:getID()
    if self.controller1_id == jid then
        self.controller1 = joystick
        self.input_type = joystick:isGamepad() and "mixed" or "joystick"
        return
    end
    if self.controller2_id == jid then
        self.controller2 = joystick
        return
    end
    if not self.controller1 then
        self.controller1 = joystick
        self.controller1_id = jid
        self.input_type = joystick:isGamepad() and "mixed" or "joystick"
    elseif not self.controller2 then
        self.controller2 = joystick
        self.controller2_id = jid
    end
end

function InputManager:handle_joystick_removed(joystick)
    self:update_joysticks()
    if joystick_equals(self.controller1, joystick) then
        self.controller1 = nil
        self.controller1_id = nil
        self.input_type = "keyboard"
    elseif joystick_equals(self.controller2, joystick) then
        self.controller2 = nil
        self.controller2_id = nil
    end
end

return InputManager
