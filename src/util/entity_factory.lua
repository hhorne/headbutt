-- Entity Factory - Creates pre-configured entities with common component combinations

local component_system = require("util.component_system")

-- Require all component types
local TransformComponent = require("components.transform_component")
local MovementComponent = require("components.movement_component")
local AnimationComponent = require("components.animation_component")
local RenderComponent = require("components.render_component")
local PhysicsComponent = require("components.physics_component")

local EntityFactory = {}

function EntityFactory.create_dude(component_manager, config)
    config = config or {}

    -- Create entity
    local entity_id = component_manager:create_entity()

    -- Add Transform component
    local transform_data = {
        x = config.x or 0,
        y = config.y or 0,
        facing = config.facing or 0
    }
    component_manager:add_component(entity_id, "Transform", transform_data)

    -- Add Movement component
    local movement_data = {
        base_move_speed = config.base_move_speed,
        base_rotation_speed = config.base_rotation_speed
    }
    component_manager:add_component(entity_id, "Movement", movement_data)

    -- Add Animation component
    local animation_data = {
        charge = config.charge or 0,
        charge_time = config.charge_time or 0,
        is_charging = config.is_charging or false,
        head_offset = config.head_offset or 0
    }
    component_manager:add_component(entity_id, "Animation", animation_data)

    -- Add Render component
    local render_data = {
        body_width = config.body_width or 120,
        body_height = config.body_height or 60,
        body_color = config.body_color or {0, 0.5, 1, 1},
        head_color = config.head_color or {1.0, 0.85, 0.73, 1},
        visible = config.visible,
        draw_debug = config.draw_debug or false,
        layer = config.layer or 0
    }
    component_manager:add_component(entity_id, "Render", render_data)

    -- Add Physics component
    local physics_data = {
        can_collide = config.can_collide,
        collision_layer = config.collision_layer or 0,
        collision_mask = config.collision_mask or 0,
        mass = config.mass or 1.0,
        collision_type = "compound" -- Dudes have both body rect and head circle
    }
    component_manager:add_component(entity_id, "Physics", physics_data)

    return entity_id
end


function EntityFactory.create_simple_entity(component_manager, component_types, component_data)
    -- Generic entity creation with specified components
    local entity_id = component_manager:create_entity()

    for i, component_type in ipairs(component_types) do
        local data = component_data[i] or {}
        component_manager:add_component(entity_id, component_type, data)
    end

    return entity_id
end

function EntityFactory.create_player_dude(component_manager, config)
    local entity_id = EntityFactory.create_dude(component_manager, config)

    -- Add PlayerController component
    local controller_data = {
        player_number = config.player_number or 1,
        input_type = config.input_type or "keyboard",
        controller_id = config.controller_id
    }
    component_manager:add_component(entity_id, "PlayerController", controller_data)

    return entity_id
end

return EntityFactory
