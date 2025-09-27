-- Head Animation State Machine
-- Manages the complex head animation states for charging, snapping, and canceling

local easing = require("util.easing")

local HeadStateMachine = {}
HeadStateMachine.__index = HeadStateMachine

-- State definitions
local STATES = {
    IDLE = "idle",
    CHARGING = "charging",
    SNAPPING = "snapping",
    CANCELING = "canceling"
}

-- State machine constructor
function HeadStateMachine.new(movement_config, head_config)
    local self = setmetatable({}, HeadStateMachine)
    self.current_state = STATES.IDLE
    self.state_time = 0
    self.stored_charge = 0
    self.movement_config = movement_config
    self.head_config = head_config
    self.charge_queued = false  -- Track if a charge has been queued during snap

    -- State handlers
    self.states = {
        [STATES.IDLE] = self:create_idle_state(),
        [STATES.CHARGING] = self:create_charging_state(),
        [STATES.SNAPPING] = self:create_snapping_state(),
        [STATES.CANCELING] = self:create_canceling_state()
    }

    return self
end

-- Create state handler functions
function HeadStateMachine:create_idle_state()
    return {
        enter = function(self, component)
            component.charge = 0
            component.head_offset = 0
            component.is_charging = false
        end,

        update = function(self, component, dt)
            -- Gradually reduce any remaining charge
            if component.charge > 0 then
                component.charge = math.max(0, component.charge - dt * self.movement_config.CHARGE_DECAY_RATE)
                component.head_offset = component.charge * self.head_config.OFFSET_SCALE
            end
        end,

        can_transition_to = function(self, new_state)
            return new_state == STATES.CHARGING
        end
    }
end

function HeadStateMachine:create_charging_state()
    return {
        enter = function(self, component)
            component.is_charging = true
            component.charge_time = 0
            component.i_frames_active = false
        end,

        update = function(self, component, dt)
            -- Increment charge time
            component.charge_time = component.charge_time + dt

            -- Calculate charge using logarithmic curve
            component.charge = self.movement_config.CHARGE_MAX * (1 - math.exp(-self.movement_config.CHARGE_RATE * component.charge_time))

            -- Update head offset based on charge
            component.head_offset = component.charge * self.head_config.OFFSET_SCALE
        end,

        can_transition_to = function(self, new_state)
            return new_state == STATES.SNAPPING or new_state == STATES.CANCELING
        end
    }
end

function HeadStateMachine:create_snapping_state()
    return {
        enter = function(self, component)
            component.is_charging = false
            self.stored_charge = component.charge -- Store charge at snap start
            component.i_frames_active = false
        end,

        update = function(self, component, dt)
            local total_duration = self.head_config.SNAP_TOTAL_DURATION
            local forward_ratio = self.head_config.SNAP_FORWARD_RATIO
            local return_extra = self.head_config.SNAP_RETURN_EXTRA or 0

            local snap_forward_duration = total_duration * forward_ratio
            local snap_return_duration = (total_duration * (1 - forward_ratio)) + return_extra

            if self.state_time <= snap_forward_duration then
                -- Phase 1: Snap forward
                local forward_progress = self.state_time / snap_forward_duration
                local target_charge = -math.abs(self.stored_charge)
                component.charge = self.stored_charge + (target_charge - self.stored_charge) * forward_progress
                component.head_offset = component.charge * self.head_config.SNAP_FORWARD_SCALE

                local pre_peak = snap_forward_duration - (self.head_config.IFRAME_PRE_PEAK_TIME or 0)
                component.i_frames_active = self.state_time >= pre_peak
            else
                -- Phase 2: Return to neutral
                local return_progress = (self.state_time - snap_forward_duration) / snap_return_duration
                local target_charge = -math.abs(self.stored_charge)
                component.charge = target_charge * (1 - return_progress)
                component.head_offset = component.charge * self.head_config.OFFSET_SCALE

                component.i_frames_active = false
            end
        end,

                can_transition_to = function(self, new_state)
            -- Allow transitioning to CHARGING at any time during SNAPPING
            -- Only allow IDLE transition when animation is complete
            return new_state == STATES.CHARGING or
                   (new_state == STATES.IDLE and self.state_time >= (self.head_config.SNAP_TOTAL_DURATION + (self.head_config.SNAP_RETURN_EXTRA or 0)))
        end
    }
end

function HeadStateMachine:create_canceling_state()
    return {
        enter = function(self, component)
            component.is_charging = false
            self.stored_charge = component.charge -- Store charge at cancel start
            component.i_frames_active = false
        end,

        update = function(self, component, dt)
            -- Use smooth easing curve for cancellation
            local cancel_progress = self.state_time / self.movement_config.CANCEL_DURATION
            -- Cubic easing out curve: progress = 1 - (1-t)^3
            local eased_progress = 1 - (1 - cancel_progress) * (1 - cancel_progress) * (1 - cancel_progress)
            component.charge = self.stored_charge * (1 - eased_progress)
            component.head_offset = component.charge * self.head_config.OFFSET_SCALE
        end,

        can_transition_to = function(self, new_state)
            return new_state == STATES.IDLE and self.state_time >= self.movement_config.CANCEL_DURATION
        end
    }
end

-- Main state machine interface
function HeadStateMachine:get_current_state()
    return self.current_state
end

function HeadStateMachine:can_charge()
    -- Allow charging in IDLE, CHARGING, or during SNAPPING
    return self.current_state == STATES.IDLE or
           self.current_state == STATES.CHARGING or
           self.current_state == STATES.SNAPPING
end

function HeadStateMachine:can_cancel()
    return self.current_state == STATES.CHARGING
end

function HeadStateMachine:can_snap()
    return self.current_state == STATES.CHARGING
end

function HeadStateMachine:transition_to(new_state, component)
    if not self.states[self.current_state].can_transition_to(self, new_state) then
        return false -- Invalid transition
    end

    -- Exit current state (if it has an exit handler)
    if self.states[self.current_state].exit then
        self.states[self.current_state].exit(self, component)
    end

    -- Change state
    self.current_state = new_state
    self.state_time = 0

    -- Enter new state
    self.states[new_state].enter(self, component)

    return true
end

function HeadStateMachine:update(component, dt)
    -- Update state time
    self.state_time = self.state_time + dt

    -- Update current state
    self.states[self.current_state].update(self, component, dt)

    -- Check for automatic transitions
    if self.current_state == STATES.SNAPPING then
        if self.state_time >= (self.head_config.SNAP_TOTAL_DURATION + (self.head_config.SNAP_RETURN_EXTRA or 0)) then
            -- If a charge was queued during snap, start it now
            if self.charge_queued then
                self.charge_queued = false
                self:transition_to(STATES.CHARGING, component)
            else
                self:transition_to(STATES.IDLE, component)
            end
        end
    elseif self.current_state == STATES.CANCELING then
        if self.state_time >= self.movement_config.CANCEL_DURATION then
            self:transition_to(STATES.IDLE, component)
        end
    end
end

-- Public interface for triggering state changes
function HeadStateMachine:start_charging(component)
    -- If we're in SNAPPING state, queue the charge instead of starting immediately
    if self.current_state == STATES.SNAPPING then
        self.charge_queued = true
        return true
    end

    -- Otherwise start charging if allowed
    if self:can_charge() then
        return self:transition_to(STATES.CHARGING, component)
    end
    return false
end

function HeadStateMachine:cancel_charge(component)
    if self:can_cancel() then
        return self:transition_to(STATES.CANCELING, component)
    end
    return false
end

function HeadStateMachine:release_charge(component)
    if self:can_snap() then
        return self:transition_to(STATES.SNAPPING, component)
    end
    return false
end

return {
    HeadStateMachine = HeadStateMachine,
    STATES = STATES
}
