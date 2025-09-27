-- Movement System - Processes movement and transform components

local component_system = require("util.component_system")
local Vector2 = require("util.vector2")

local MovementSystem = {}
MovementSystem.__index = MovementSystem
setmetatable(MovementSystem, {__index = component_system.System})

function MovementSystem.new(component_manager)
    local self = setmetatable(component_system.System.new(component_manager), MovementSystem)
    return self
end

function MovementSystem:get_required_components()
    return {"Transform", "Movement"}
end

function MovementSystem:process_entity(entity_id, dt)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local movement = self.component_manager:get_component(entity_id, "Movement")

    if not transform or not movement then
        return
    end

    -- Store previous state for collision rollback
    transform:store_previous_state()

    -- Apply velocity to position
    local velocity = movement:get_velocity()
    if not velocity:is_zero() then
        transform:translate(velocity.x * dt, velocity.y * dt)
    end

    -- Apply angular velocity to rotation
    local angular_velocity = movement:get_angular_velocity()
    if angular_velocity ~= 0 then
        transform:rotate(angular_velocity * dt)
    end
end

function MovementSystem:process_input(entity_id, input, dt)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local movement = self.component_manager:get_component(entity_id, "Movement")

    if not transform or not movement then
        return
    end

    -- Process movement input
    if input.movement then
        local input_vector = Vector2.from_table(input.movement)
        local current_facing = transform:get_facing()
        local new_facing = movement:apply_movement_input(input_vector, current_facing, dt)
        transform:set_facing(new_facing)
    end

    -- Process rotation input
    if input.rotation then
        movement:apply_rotation_input(input.rotation, dt)
    end
end

function MovementSystem:handle_collision_rollback(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    if transform then
        transform:restore_previous_state()
    end
end

return MovementSystem
