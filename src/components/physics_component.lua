-- Physics Component - Handles physics state, velocity, and forces

local component_system = require("util.component_system")
local Vector2 = require("util.vector2")
local knockback_config = require("config.knockback_config")

local PhysicsComponent = {}
PhysicsComponent.__index = PhysicsComponent
setmetatable(PhysicsComponent, {__index = component_system.Component})

function PhysicsComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), PhysicsComponent)

    -- Physics velocity (separate from movement component's intended velocity)
    self.physics_velocity = Vector2.new(data.physics_velocity_x or 0, data.physics_velocity_y or 0)

    -- Active physics events affecting this entity
    self.active_events = {}

    -- Collision state
    self.can_collide = data.can_collide ~= false -- Default to true
    self.collision_layer = data.collision_layer or 0
    self.collision_mask = data.collision_mask or 0

    -- Mass for physics calculations
    self.mass = data.mass or 1.0

    -- Collision shape info (for optimization)
    self.collision_type = data.collision_type or "compound" -- "compound", "circle", "rect"

    return self
end

function PhysicsComponent:get_type()
    return "Physics"
end

function PhysicsComponent:add_physics_event(event)
    table.insert(self.active_events, event)
end

function PhysicsComponent:get_physics_velocity()
    return self.physics_velocity
end

function PhysicsComponent:set_physics_velocity(velocity)
    self.physics_velocity = velocity
end

function PhysicsComponent:add_force(force_vector, duration)
    local event = {
        type = "force",
        force = force_vector,
        duration = duration,
        time_remaining = duration
    }
    self:add_physics_event(event)
end

function PhysicsComponent:add_impulse(impulse_vector)
    -- Instant velocity change
    self.physics_velocity = self.physics_velocity + impulse_vector
end

function PhysicsComponent:add_knockback(direction, force, duration)
    -- Store initial velocity and let it decay over time
    local initial_velocity = direction * force
    local event = {
        type = "knockback",
        initial_velocity = initial_velocity,
        duration = duration,
        time_remaining = duration
    }
    self:add_physics_event(event)
end

function PhysicsComponent:update(dt)
    -- Process active physics events
    for i = #self.active_events, 1, -1 do
        local event = self.active_events[i]

        if event.type == "knockback" then
            -- Apply knockback with exponential decay using config
            local progress = 1 - (event.time_remaining / event.duration)
            local decay_factor = knockback_config.calculate_decay_factor(progress)
            self.physics_velocity = event.initial_velocity * decay_factor

            event.time_remaining = event.time_remaining - dt
            if event.time_remaining <= 0 then
                self.physics_velocity = Vector2.zero()
                table.remove(self.active_events, i)
            end

        elseif event.type == "force" then
            -- Apply continuous force
            local acceleration = event.force / self.mass
            self.physics_velocity = self.physics_velocity + (acceleration * dt)

            event.time_remaining = event.time_remaining - dt
            if event.time_remaining <= 0 then
                table.remove(self.active_events, i)
            end
        end
    end
end

function PhysicsComponent:clear_physics_events()
    self.active_events = {}
    self.physics_velocity = Vector2.zero()
end

-- Register component type
component_system.ComponentRegistry.register(PhysicsComponent, "Physics")

return PhysicsComponent
