-- Transform Component - Handles position, rotation, and scale

local component_system = require("util.component_system")
local movement_config = require("config.movement_config")

local TransformComponent = {}
TransformComponent.__index = TransformComponent
setmetatable(TransformComponent, {__index = component_system.Component})

function TransformComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), TransformComponent)

    -- Position
    self.x = data.x or 0
    self.y = data.y or 0

    -- Rotation in degrees (0 = facing up, 90 = facing right, 180 = facing down, 270 = facing left)
    -- IMPORTANT: When converting to world space (e.g. for debug arrows), subtract 90 degrees to account for this convention
    self.facing = data.facing or 0

    -- Scale (for future use)
    self.scale_x = data.scale_x or 1
    self.scale_y = data.scale_y or 1

    -- Previous position for collision rollback
    self.prev_x = self.x
    self.prev_y = self.y
    self.prev_facing = self.facing

    return self
end

function TransformComponent:get_type()
    return "Transform"
end

function TransformComponent:get_position()
    return self.x, self.y
end

function TransformComponent:set_position(x, y)
    self.prev_x = self.x
    self.prev_y = self.y
    self.x = x
    self.y = y
end

function TransformComponent:translate(dx, dy)
    self:set_position(self.x + dx, self.y + dy)
end

function TransformComponent:get_facing()
    return self.facing
end

function TransformComponent:set_facing(angle)
    self.prev_facing = self.facing
    self.facing = movement_config.MOVEMENT.normalize_angle_degrees(angle)
end

function TransformComponent:rotate(delta_angle)
    self:set_facing(self.facing + delta_angle)
end

function TransformComponent:get_facing_radians()
    return movement_config.MOVEMENT.degrees_to_radians(self.facing)
end

function TransformComponent:set_facing_radians(angle_radians)
    self:set_facing(movement_config.MOVEMENT.radians_to_degrees(angle_radians))
end

function TransformComponent:store_previous_state()
    self.prev_x = self.x
    self.prev_y = self.y
    self.prev_facing = self.facing
end

function TransformComponent:restore_previous_state()
    self.x = self.prev_x
    self.y = self.prev_y
    self.facing = self.prev_facing
end

function TransformComponent:get_scale()
    return self.scale_x, self.scale_y
end

function TransformComponent:set_scale(scale_x, scale_y)
    self.scale_x = scale_x or scale_x
    self.scale_y = scale_y or scale_x -- Default to uniform scaling
end

-- Register component type
component_system.ComponentRegistry.register(TransformComponent, "Transform")

return TransformComponent
