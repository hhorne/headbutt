-- Animation System - Processes animation components

local component_system = require("util.component_system")

local AnimationSystem = {}
AnimationSystem.__index = AnimationSystem
setmetatable(AnimationSystem, {__index = component_system.System})

function AnimationSystem.new(component_manager)
    local self = setmetatable(component_system.System.new(component_manager), AnimationSystem)
    return self
end

function AnimationSystem:get_required_components()
    return {"Animation"}
end

function AnimationSystem:process_entity(entity_id, dt)
    local animation = self.component_manager:get_component(entity_id, "Animation")

    if not animation then
        return
    end

    -- Update the animation component (which updates the state machine)
    animation:update(dt)
end

function AnimationSystem:process_input(entity_id, input)
    local animation = self.component_manager:get_component(entity_id, "Animation")

    if not animation then
        return
    end

    -- Handle charge cancel (edge or hold ok)
    if input.chargeCancel then
        animation:cancel_charge()
    end

    -- Handle charging: press vs hold based on mode
    local mode = input.chargeInputMode or "press"
    if (mode == "press" and input.chargePressed) or (mode == "hold" and input.charging) then
        if not animation:is_currently_charging() and animation:can_charge() then
            animation:start_charging()
        end
    elseif not input.charging then
        -- Release charge if we were charging
        if animation:is_currently_charging() then
            animation:release_charge()
        end
    end
end

function AnimationSystem:apply_movement_speed_modifier(entity_id)
    local animation = self.component_manager:get_component(entity_id, "Animation")
    local movement = self.component_manager:get_component(entity_id, "Movement")

    if not animation or not movement then
        return
    end

    -- Apply charging speed penalty
    if animation:is_currently_charging() then
        local charge_mult = require("config.movement_config").MOVEMENT.CHARGE_MOVE_SPEED_MULT
        movement:set_speed_multiplier(charge_mult)
    else
        movement:set_speed_multiplier(1.0)
    end
end

return AnimationSystem
