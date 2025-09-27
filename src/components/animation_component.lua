-- Animation Component - Handles head animations and charge states

local component_system = require("util.component_system")
local head_state_machine = require("util.head_state_machine")
local movement_config = require("config.movement_config")

---@class AnimationComponent: Component
---@field head_state_machine any
---@field charge number
---@field charge_time number
---@field is_charging boolean
---@field i_frames_active boolean
---@field head_offset number
---@field start_cancel_charge number
---@field start_charge number
---@field original_charge number
---@field debug_stun_timer number
local AnimationComponent = {}
AnimationComponent.__index = AnimationComponent
setmetatable(AnimationComponent, {__index = component_system.Component})

function AnimationComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), AnimationComponent)

    local MOVEMENT = movement_config.MOVEMENT
    local HEAD = movement_config.HEAD

    -- Head animation state
    self.head_state_machine = head_state_machine.HeadStateMachine.new(MOVEMENT, HEAD)

    -- Charge state
    self.charge = data.charge or 0
    self.charge_time = data.charge_time or 0
    self.is_charging = data.is_charging or false
    self.i_frames_active = false

    -- Head offset for visual animation
    self.head_offset = data.head_offset or 0

    -- Stored charge values for animations (used by state machine)
    self.start_cancel_charge = 0
    self.start_charge = 0
    self.original_charge = 0

    -- Debug-only stun visualization timer (seconds)
    self.debug_stun_timer = 0

    return self
end

function AnimationComponent:get_type()
    return "Animation"
end

function AnimationComponent:get_current_state()
    return self.head_state_machine:get_current_state()
end

function AnimationComponent:can_charge()
    if self.is_stunned and self:is_stunned() then
        return false
    end
    return self.head_state_machine:can_charge()
end

function AnimationComponent:can_cancel()
    return self.head_state_machine:can_cancel()
end

function AnimationComponent:can_snap()
    return self.head_state_machine:can_snap()
end

function AnimationComponent:start_charging()
    if self.is_stunned and self:is_stunned() then
        return false
    end
    return self.head_state_machine:start_charging(self)
end

function AnimationComponent:cancel_charge()
    return self.head_state_machine:cancel_charge(self)
end

function AnimationComponent:release_charge()
    return self.head_state_machine:release_charge(self)
end

function AnimationComponent:get_charge_level()
    return self.charge
end

function AnimationComponent:get_charge_time()
    return self.charge_time
end

function AnimationComponent:is_currently_charging()
    return self.is_charging
end

function AnimationComponent:get_head_offset()
    return self.head_offset
end

function AnimationComponent:is_invincible()
    return self.i_frames_active == true
end

function AnimationComponent:update(dt)
    -- Update the state machine
    self.head_state_machine:update(self, dt)

    -- Tick down debug stun timer
    if self.debug_stun_timer and self.debug_stun_timer > 0 then
        self.debug_stun_timer = math.max(0, self.debug_stun_timer - dt)
    end
end

function AnimationComponent:add_debug_stun(duration)
    if self:is_invincible() then return end
    local d = duration or 0
    if d <= 0 then return end
    -- Extend if a longer stun is applied while active
    self.debug_stun_timer = math.max(self.debug_stun_timer or 0, d)
end

function AnimationComponent:is_stunned()
    return (self.debug_stun_timer or 0) > 0
end

-- Register component type
component_system.ComponentRegistry.register(AnimationComponent, "Animation")

return AnimationComponent
