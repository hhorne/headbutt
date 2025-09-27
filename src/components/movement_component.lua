-- Movement Component - Handles movement speed, direction, and physics

local component_system = require("util.component_system")
local movement_config = require("config.movement_config")
local Vector2 = require("util.vector2")

local MovementComponent = {}
MovementComponent.__index = MovementComponent
setmetatable(MovementComponent, {__index = component_system.Component})

function MovementComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), MovementComponent)

    local MOVEMENT = movement_config.MOVEMENT

    -- Movement parameters
    self.base_move_speed = data.base_move_speed or MOVEMENT.BASE_MOVE_SPEED
    self.base_rotation_speed = data.base_rotation_speed or MOVEMENT.BASE_ROTATION_SPEED

    -- Current movement state
    self.velocity = Vector2.zero()
    self.angular_velocity = 0

    -- Movement modifiers
    self.speed_multiplier = 1.0
    self.rotation_multiplier = 1.0

    -- Movement direction logic
    self.backward_speed_mult = MOVEMENT.BACKWARD_SPEED_MULT
    self.min_turn_speed_mult = MOVEMENT.MIN_TURN_SPEED_MULT
    self.turn_lerp_speed = MOVEMENT.TURN_LERP_SPEED
    self.turn_angle_deadzone = MOVEMENT.TURN_ANGLE_DEADZONE
    self.max_forward_turn = MOVEMENT.MAX_FORWARD_TURN

    return self
end

function MovementComponent:get_type()
    return "Movement"
end

function MovementComponent:get_effective_move_speed()
    return self.base_move_speed * self.speed_multiplier
end

function MovementComponent:get_effective_rotation_speed()
    return self.base_rotation_speed * self.rotation_multiplier
end

function MovementComponent:set_speed_multiplier(multiplier)
    self.speed_multiplier = math.max(0, multiplier)
end

function MovementComponent:set_rotation_multiplier(multiplier)
    self.rotation_multiplier = math.max(0, multiplier)
end

function MovementComponent:apply_movement_input(input_vector, current_facing, dt)
    if input_vector:is_zero() then
        self.velocity = Vector2.zero()
        return current_facing
    end

    local MOVEMENT = movement_config.MOVEMENT

    -- Convert facing angle to vector
    local facing_radians = MOVEMENT.degrees_to_radians(current_facing)
    local facing_vector = Vector2.new(math.sin(facing_radians), -math.cos(facing_radians))

    -- Use dot product to determine forward/backward movement
    local dot_product = input_vector:dot(facing_vector)
    local walking_backwards = dot_product < -0.1

    -- Calculate target facing direction
    local movement_angle_radians = input_vector:angle()
    local target_angle_radians = walking_backwards and
        (movement_angle_radians + math.pi) or movement_angle_radians

    -- Convert back to degrees for compatibility
    local target_angle = MOVEMENT.normalize_angle_degrees(
        MOVEMENT.radians_to_degrees(target_angle_radians) + 90
    )

    -- Calculate speed multiplier based on alignment
    local speed_mult = 1.0
    if walking_backwards then
        speed_mult = self.backward_speed_mult
    else
        local angle_diff = math.abs(MOVEMENT.angle_difference_degrees(current_facing, target_angle))
        if angle_diff > self.turn_angle_deadzone then
            local turn_ratio = (angle_diff - self.turn_angle_deadzone) /
                             (self.max_forward_turn - self.turn_angle_deadzone)
            turn_ratio = math.min(1.0, turn_ratio)
            speed_mult = 1.0 - (1.0 - self.min_turn_speed_mult) * turn_ratio
        end
    end

    -- Set velocity
    local effective_speed = self:get_effective_move_speed() * speed_mult
    self.velocity = input_vector * effective_speed

    -- Interpolate facing towards target angle
    local angle_delta = MOVEMENT.angle_difference_degrees(current_facing, target_angle)
    local new_facing = current_facing + angle_delta * self.turn_lerp_speed * dt

    return MOVEMENT.normalize_angle_degrees(new_facing)
end

function MovementComponent:apply_rotation_input(rotation_input, dt)
    self.angular_velocity = rotation_input * self:get_effective_rotation_speed()
end

function MovementComponent:get_velocity()
    return self.velocity
end

function MovementComponent:set_velocity(velocity)
    self.velocity = velocity
end

function MovementComponent:get_angular_velocity()
    return self.angular_velocity
end

function MovementComponent:set_angular_velocity(angular_velocity)
    self.angular_velocity = angular_velocity
end

function MovementComponent:update(dt)
    -- Movement is applied by the movement system, not here
    -- This component just stores state
end

-- Register component type
component_system.ComponentRegistry.register(MovementComponent, "Movement")

return MovementComponent
