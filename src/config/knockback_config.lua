-- Knockback Configuration - All tuning parameters for headbutt knockback physics
-- Centralized location for tweaking knockback feel and balance

local KNOCKBACK_CONFIG = {
    -- Base knockback velocity (pixels per second)
    -- This is the initial velocity applied to the target when hit by a fully charged headbutt
    BASE_SPEED = 150, -- Was 400 originally, reduced to 150 for more reasonable knockback

    -- Duration of knockback effect (seconds)
    -- How long the knockback force lasts before naturally decaying to zero
    DURATION = 0.3,

    -- Force curve power (0.0 to 1.0+)
    -- Controls how charge level affects knockback force
    -- Lower values (0.3): More dramatic reduction at high charge levels (diminishing returns)
    -- Higher values (0.8): More linear relationship between charge and force
    -- 1.0: Completely linear (charge 0.5 = 50% force, charge 1.0 = 100% force)
    CURVE_POWER = 0.3,

    -- Physics decay settings
    PHYSICS = {
        -- Exponential decay rate (higher = faster decay)
        -- Controls how quickly knockback velocity decreases over time
        -- 4.0: Rapid decay with smooth deceleration
        -- 2.0: Slower decay, longer sliding
        -- 6.0: Very rapid decay, quick stop
        DECAY_RATE = 4.0,

        -- Mass multiplier for different entity types (future extensibility)
        DEFAULT_MASS = 1.0,
        HEAVY_MASS = 1.5,    -- Takes less knockback
        LIGHT_MASS = 0.7     -- Takes more knockback
    },

    -- Charge calculation settings
    CHARGE = {
        -- Maximum charge level that can be achieved
        MAX_CHARGE = 1.25,

        -- Duration of the snap forward animation (seconds)
        -- Used to estimate original charge during the snap phase
        SNAP_FORWARD_DURATION = 0.25
    },

    -- Debug and visualization
    DEBUG = {
        -- Show knockback vectors and force calculations
        SHOW_KNOCKBACK_VECTORS = false,

        -- Show charge level and force multipliers
        SHOW_FORCE_CALCULATIONS = false
    }
}

-- Helper functions for knockback calculations

-- Calculate the knockback force multiplier based on charge level
function KNOCKBACK_CONFIG.calculate_force_multiplier(charge_level)
    local normalized_charge = math.min(charge_level / KNOCKBACK_CONFIG.CHARGE.MAX_CHARGE, 1.0)
    return math.pow(normalized_charge, KNOCKBACK_CONFIG.CURVE_POWER)
end

-- Calculate the final knockback velocity for a given charge level
function KNOCKBACK_CONFIG.calculate_knockback_velocity(charge_level)
    local force_multiplier = KNOCKBACK_CONFIG.calculate_force_multiplier(charge_level)
    return KNOCKBACK_CONFIG.BASE_SPEED * force_multiplier
end

-- Calculate decay factor for a given time progress (0.0 to 1.0)
function KNOCKBACK_CONFIG.calculate_decay_factor(time_progress)
    local easing = require("util.easing")
    return easing.exponential_decay(time_progress, KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE)
end

-- Estimate original charge from current charge during snap animation
function KNOCKBACK_CONFIG.estimate_original_charge(current_charge, snap_progress)
    if snap_progress >= 1 then
        return KNOCKBACK_CONFIG.CHARGE.MAX_CHARGE
    end
    return math.abs(current_charge) / (1 - snap_progress)
end

-- Validation function to ensure all values are reasonable
function KNOCKBACK_CONFIG.validate()
    assert(KNOCKBACK_CONFIG.BASE_SPEED > 0, "BASE_SPEED must be positive")
    assert(KNOCKBACK_CONFIG.DURATION > 0, "DURATION must be positive")
    assert(KNOCKBACK_CONFIG.CURVE_POWER >= 0, "CURVE_POWER must be non-negative")
    assert(KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE > 0, "DECAY_RATE must be positive")
    assert(KNOCKBACK_CONFIG.CHARGE.MAX_CHARGE > 0, "MAX_CHARGE must be positive")
    assert(KNOCKBACK_CONFIG.CHARGE.SNAP_FORWARD_DURATION > 0, "SNAP_FORWARD_DURATION must be positive")
    return true
end

-- Preset configurations for different gameplay feels
KNOCKBACK_CONFIG.PRESETS = {
    -- Gentle knockback for casual gameplay
    GENTLE = {
        BASE_SPEED = 100,
        DURATION = 0.25,
        CURVE_POWER = 0.5,
        DECAY_RATE = 5.0
    },

    -- Current balanced settings
    BALANCED = {
        BASE_SPEED = 150,
        DURATION = 0.3,
        CURVE_POWER = 0.3,
        DECAY_RATE = 4.0
    },

    -- Strong knockback for competitive gameplay
    STRONG = {
        BASE_SPEED = 250,
        DURATION = 0.4,
        CURVE_POWER = 0.2,
        DECAY_RATE = 3.0
    },

    -- Original legacy-style knockback (very strong)
    LEGACY = {
        BASE_SPEED = 400,
        DURATION = 0.3,
        CURVE_POWER = 0.3,
        DECAY_RATE = 2.0
    }
}

-- Apply a preset configuration
function KNOCKBACK_CONFIG.apply_preset(preset_name)
    local preset = KNOCKBACK_CONFIG.PRESETS[preset_name]
    if not preset then
        error("Unknown preset: " .. tostring(preset_name))
    end

    KNOCKBACK_CONFIG.BASE_SPEED = preset.BASE_SPEED
    KNOCKBACK_CONFIG.DURATION = preset.DURATION
    KNOCKBACK_CONFIG.CURVE_POWER = preset.CURVE_POWER
    KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE = preset.DECAY_RATE
end

-- Get current configuration as a table (for saving/debugging)
function KNOCKBACK_CONFIG.get_current_settings()
    return {
        base_speed = KNOCKBACK_CONFIG.BASE_SPEED,
        duration = KNOCKBACK_CONFIG.DURATION,
        curve_power = KNOCKBACK_CONFIG.CURVE_POWER,
        decay_rate = KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE,
        max_charge = KNOCKBACK_CONFIG.CHARGE.MAX_CHARGE,
        snap_duration = KNOCKBACK_CONFIG.CHARGE.SNAP_FORWARD_DURATION
    }
end

return KNOCKBACK_CONFIG
