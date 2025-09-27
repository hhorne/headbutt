-- Player Controller Component - Identifies player-controlled entities and their input configuration
local component_system = require("util.component_system")

---@class PlayerControllerComponent : Component
---@field player_number number Player number (1 or 2)
---@field input_type string Input type ("keyboard", "gamepad", "mixed")
---@field controller_id number? Controller ID for gamepad input
local PlayerControllerComponent = {}
PlayerControllerComponent.__index = PlayerControllerComponent
setmetatable(PlayerControllerComponent, {__index = component_system.Component})

function PlayerControllerComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), PlayerControllerComponent)

    -- Player number (1 or 2)
    self.player_number = data.player_number or 1

    -- Input configuration
    self.input_type = data.input_type or "keyboard" -- "keyboard", "gamepad", "mixed"
    self.controller_id = data.controller_id -- nil for keyboard

    return self
end

function PlayerControllerComponent:get_type()
    return "PlayerController"
end

-- Register component type
component_system.ComponentRegistry.register(PlayerControllerComponent, "PlayerController")

return PlayerControllerComponent
