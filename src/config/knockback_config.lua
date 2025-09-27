-- Knockback Configuration - All tuning parameters for headbutt knockback physics
-- Centralized location for tweaking knockback feel and balance

local KNOCKBACK_CONFIG = rawget(_G, "__KNOCKBACK_CONFIG__")

if not KNOCKBACK_CONFIG then
    KNOCKBACK_CONFIG = {
        -- Base knockback velocity (pixels per second)
        BASE_SPEED = 150,

        -- Duration of knockback effect (seconds)
        DURATION = 0.3,

        -- Force curve power (0.0 to 1.0+)
        CURVE_POWER = 0.3,

        -- Physics decay settings
        PHYSICS = {
            DECAY_RATE = 4.0,
            DECAY_MODE = "exponential",
            INVERSE_BELL_HOLD = 0.78,
            INVERSE_BELL_SHARPNESS = 4.0,
            DEFAULT_MASS = 1.0,
            HEAVY_MASS = 1.5,
            LIGHT_MASS = 0.7
        },

        -- Charge calculation settings
        CHARGE = {
            MAX_CHARGE = 1.25,
            SNAP_FORWARD_DURATION = 0.25
        },

        -- Debug and visualization
        DEBUG = {
            SHOW_KNOCKBACK_VECTORS = false,
            SHOW_FORCE_CALCULATIONS = false
        }
    }

    _G.__KNOCKBACK_CONFIG__ = KNOCKBACK_CONFIG
else
    KNOCKBACK_CONFIG.PHYSICS = KNOCKBACK_CONFIG.PHYSICS or {}
    KNOCKBACK_CONFIG.CHARGE = KNOCKBACK_CONFIG.CHARGE or {}
    KNOCKBACK_CONFIG.DEBUG = KNOCKBACK_CONFIG.DEBUG or {}
end

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
    local mode = KNOCKBACK_CONFIG.PHYSICS.DECAY_MODE or "exponential"
    if mode == "inverse_bell" then
        return easing.inverse_bell_short_tail(
            time_progress,
            KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_HOLD,
            KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_SHARPNESS
        )
    else
        return easing.exponential_decay(time_progress, KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE)
    end
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
        BASE_SPEED = 360,
        DURATION = 0.5,
        CURVE_POWER = 0.2,
        DECAY_RATE = 2.6
    },

    -- Original legacy-style knockback (very strong)
    LEGACY = {
        BASE_SPEED = 420,
        DURATION = 1.1,
        CURVE_POWER = 0.3,
        DECAY_RATE = 2.2,
        DECAY_MODE = "inverse_bell",
        INVERSE_BELL_HOLD = 0.80,
        INVERSE_BELL_SHARPNESS = 4.5
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
    -- Reset optional physics fields to sane defaults unless overridden by preset
    KNOCKBACK_CONFIG.PHYSICS.DECAY_MODE = preset.DECAY_MODE or "exponential"
    KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_HOLD = preset.INVERSE_BELL_HOLD or 0.78
    KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_SHARPNESS = preset.INVERSE_BELL_SHARPNESS or 4.0
end

-- Get current configuration as a table (for saving/debugging)
function KNOCKBACK_CONFIG.get_current_settings()
    return {
        base_speed = KNOCKBACK_CONFIG.BASE_SPEED,
        duration = KNOCKBACK_CONFIG.DURATION,
        curve_power = KNOCKBACK_CONFIG.CURVE_POWER,
        decay_rate = KNOCKBACK_CONFIG.PHYSICS.DECAY_RATE,
        decay_mode = KNOCKBACK_CONFIG.PHYSICS.DECAY_MODE,
        inverse_bell_hold = KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_HOLD,
        inverse_bell_sharpness = KNOCKBACK_CONFIG.PHYSICS.INVERSE_BELL_SHARPNESS,
        max_charge = KNOCKBACK_CONFIG.CHARGE.MAX_CHARGE,
        snap_duration = KNOCKBACK_CONFIG.CHARGE.SNAP_FORWARD_DURATION
    }
end

return KNOCKBACK_CONFIG
