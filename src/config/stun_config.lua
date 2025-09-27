-- Stun Configuration - Tuning for stun visuals and duration

local STUN_CONFIG = {
    -- Base stun duration (seconds)
    DURATION = 0.75,

    -- Wobble visual while stunned (applied in normal render)
    WOBBLE = {
        -- Rotation amplitude in radians (0.035 ≈ 2 degrees)
        AMP = 0.15,
        -- Frequency in Hz
        FREQ = 16.0,
    },

    -- Additional head-local wobble while stunned
    HEAD_WOBBLE = {
        -- Lateral amplitude in pixels (local X in body space)
        PIXEL_AMP = 4.0,
        -- Frequency in Hz
        FREQ = 14.0,
    },

    -- Small world-space positional stagger while stunned
    STAGGER = {
        -- Amplitude in pixels
        PIXEL_AMP = 6.0,
        -- Frequency in Hz
        FREQ = 7.5,
    },
}

function STUN_CONFIG.validate()
    assert(STUN_CONFIG.DURATION >= 0, "STUN.DURATION must be non-negative")
    assert(STUN_CONFIG.WOBBLE.AMP >= 0, "STUN.WOBBLE.AMP must be non-negative")
    assert(STUN_CONFIG.WOBBLE.FREQ >= 0, "STUN.WOBBLE.FREQ must be non-negative")
    assert(STUN_CONFIG.HEAD_WOBBLE.PIXEL_AMP >= 0, "STUN.HEAD_WOBBLE.PIXEL_AMP must be non-negative")
    assert(STUN_CONFIG.HEAD_WOBBLE.FREQ >= 0, "STUN.HEAD_WOBBLE.FREQ must be non-negative")
    assert(STUN_CONFIG.STAGGER.PIXEL_AMP >= 0, "STUN.STAGGER.PIXEL_AMP must be non-negative")
    assert(STUN_CONFIG.STAGGER.FREQ >= 0, "STUN.STAGGER.FREQ must be non-negative")
    return true
end

return STUN_CONFIG


