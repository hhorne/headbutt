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
    }
}

function STUN_CONFIG.validate()
    assert(STUN_CONFIG.DURATION >= 0, "STUN.DURATION must be non-negative")
    assert(STUN_CONFIG.WOBBLE.AMP >= 0, "STUN.WOBBLE.AMP must be non-negative")
    assert(STUN_CONFIG.WOBBLE.FREQ >= 0, "STUN.WOBBLE.FREQ must be non-negative")
    return true
end

return STUN_CONFIG


