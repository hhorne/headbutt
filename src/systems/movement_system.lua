-- Movement System - Processes movement and transform components

local component_system = require("util.component_system")
local Vector2 = require("util.vector2")
local stun_config = require("config.stun_config")

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
    local animation = self.component_manager:get_component(entity_id, "Animation")

    if not transform or not movement then
        return
    end

    -- Update movement state (accel/decel toward desired velocity)
    if movement.update then
        movement:update(dt)
    end

    -- Store previous state for collision rollback
    transform:store_previous_state()

    -- Apply velocity to position
    local velocity = movement:get_velocity()
    if not velocity:is_zero() then
        transform:translate(velocity.x * dt, velocity.y * dt)
    end

    -- Apply small world-space stagger while stunned (offset around nominal position)
    if animation and animation.is_stunned and animation:is_stunned() then
        local t = love.timer.getTime()
        local phase = (entity_id % 13) * 0.41
        local s = stun_config.STAGGER
        local target_x = math.sin((t + phase) * s.FREQ) * s.PIXEL_AMP
        local target_y = math.cos((t * 0.9 + phase * 1.37) * s.FREQ) * (s.PIXEL_AMP * 0.7)
        local dx = target_x - (movement.last_stagger_x or 0)
        local dy = target_y - (movement.last_stagger_y or 0)
        if dx ~= 0 or dy ~= 0 then
            transform:translate(dx, dy)
            movement.last_stagger_x = target_x
            movement.last_stagger_y = target_y
        end
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
