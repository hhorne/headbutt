-- Movement Component - Handles movement speed, direction, and physics
local component_system = require("util.component_system")
local movement_config = require("config.movement_config")
local Vector2 = require("util.vector2")

local MovementComponent = {}
MovementComponent.__index = MovementComponent
setmetatable(MovementComponent, {__index = component_system.Component})

function MovementComponent.new(entity_id, data)
    ---@class MovementComponent : Component
    ---@field base_move_speed number
    ---@field base_rotation_speed number
    ---@field velocity Vector2
    ---@field desired_velocity Vector2
    ---@field angular_velocity number
    ---@field speed_multiplier number
    ---@field rotation_multiplier number
    ---@field backward_speed_mult number
    ---@field min_turn_speed_mult number
    ---@field turn_lerp_speed number
    ---@field turn_angle_deadzone number
    ---@field max_forward_turn number
    ---@field accel number
    ---@field decel number
    local self = setmetatable(component_system.Component.new(entity_id), MovementComponent)

    local MOVEMENT = movement_config.MOVEMENT

    -- Movement parameters
    self.base_move_speed = data.base_move_speed or MOVEMENT.BASE_MOVE_SPEED
    self.base_rotation_speed = data.base_rotation_speed or MOVEMENT.BASE_ROTATION_SPEED

    -- Current movement state
    self.velocity = Vector2.zero()
    self.desired_velocity = Vector2.zero()
    self.angular_velocity = 0

    -- Movement modifiers
    self.speed_multiplier = 1.0
    self.rotation_multiplier = 1.0

    -- Simple acceleration model to reduce floaty feel
    self.accel = data.accel or 2200
    self.decel = data.decel or 2800

    -- Movement direction logic
    self.backward_speed_mult = MOVEMENT.BACKWARD_SPEED_MULT
    self.min_turn_speed_mult = MOVEMENT.MIN_TURN_SPEED_MULT
    self.turn_lerp_speed = MOVEMENT.TURN_LERP_SPEED
    self.turn_angle_deadzone = MOVEMENT.TURN_ANGLE_DEADZONE
    self.max_forward_turn = MOVEMENT.MAX_FORWARD_TURN

	-- Stagger tracking while stunned (world-space jitter bookkeeping)
	self.last_stagger_x = 0
	self.last_stagger_y = 0

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
        self.desired_velocity = Vector2.zero()
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

    -- Set desired velocity, then accel/decel toward it in update()
    local effective_speed = self:get_effective_move_speed() * speed_mult
    self.desired_velocity = input_vector * effective_speed

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
    -- Smooth velocity toward desired_velocity using accel / decel
    local dv = Vector2.new(self.desired_velocity.x - self.velocity.x, self.desired_velocity.y - self.velocity.y)
    local diff_len_sq = dv:magnitude_squared()
    if diff_len_sq > 0 then
        local diff_len = math.sqrt(diff_len_sq)
        local direction = dv:divide(diff_len)
        local speed_target_len = self.desired_velocity:magnitude()
        local current_len = self.velocity:magnitude()
        local is_accelerating = speed_target_len > current_len + 1e-3
        local rate = is_accelerating and self.accel or self.decel
        local step = rate * dt
        if step >= diff_len then
            self.velocity = self.desired_velocity
        else
            self.velocity = Vector2.new(self.velocity.x + direction.x * step, self.velocity.y + direction.y * step)
        end
    else
        -- If we have no desired velocity, decelerate to zero
        local vlen = self.velocity:magnitude()
        if vlen > 0 then
            local step = self.decel * dt
            if step >= vlen then
                self.velocity = Vector2.zero()
            else
                local dir = self.velocity:divide(vlen)
                self.velocity = Vector2.new(self.velocity.x - dir.x * step, self.velocity.y - dir.y * step)
            end
        end
    end
end

-- Register component type
component_system.ComponentRegistry.register(MovementComponent, "Movement")

return MovementComponent
