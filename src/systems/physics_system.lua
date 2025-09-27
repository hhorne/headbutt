-- Physics System - Processes physics components and applies physics forces

local component_system = require("util.component_system")
local Vector2 = require("util.vector2")

local PhysicsSystem = {}
PhysicsSystem.__index = PhysicsSystem
setmetatable(PhysicsSystem, {__index = component_system.System})

function PhysicsSystem.new(component_manager)
    local self = setmetatable(component_system.System.new(component_manager), PhysicsSystem)
    return self
end

function PhysicsSystem:get_required_components()
    return {"Transform", "Physics"}
end

function PhysicsSystem:process_entity(entity_id, dt)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local physics = self.component_manager:get_component(entity_id, "Physics")

    if not transform or not physics then
        return
    end

    -- Update physics component (processes forces, knockback, etc.)
    physics:update(dt)

    -- Apply physics velocity to transform
    local physics_velocity = physics:get_physics_velocity()
    if not physics_velocity:is_zero() then
        transform:translate(physics_velocity.x * dt, physics_velocity.y * dt)
    end
end

-- Public interface for applying forces
function PhysicsSystem:add_force_to_entity(entity_id, force_vector, duration)
    local physics = self.component_manager:get_component(entity_id, "Physics")
    if physics then
        physics:add_force(force_vector, duration)
    end
end

function PhysicsSystem:add_impulse_to_entity(entity_id, impulse_vector)
    local physics = self.component_manager:get_component(entity_id, "Physics")
    if physics then
        physics:add_impulse(impulse_vector)
    end
end

function PhysicsSystem:add_knockback_to_entity(entity_id, direction, force, duration)
    local physics = self.component_manager:get_component(entity_id, "Physics")
    if physics then
        physics:add_knockback(direction, force, duration)
    end
end

function PhysicsSystem:clear_physics_for_entity(entity_id)
    local physics = self.component_manager:get_component(entity_id, "Physics")
    if physics then
        physics:clear_physics_events()
    end
end

return PhysicsSystem
