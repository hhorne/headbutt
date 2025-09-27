-- Movement configuration for dude physics and animation
-- This centralizes all movement tuning parameters for easy balancing

local MOVEMENT_CONFIG = {
    -- Regular movement
    BASE_MOVE_SPEED = 250,        -- Base movement speed in pixels per second
    BASE_ROTATION_SPEED = 140,    -- Base rotation speed in degrees per second

    -- Directional movement
    BACKWARD_SPEED_MULT = 0.5,    -- Movement speed multiplier when walking backwards
    MIN_TURN_SPEED_MULT = 0.6,    -- Minimum speed multiplier when at maximum turn angle (90 degrees)
    TURN_LERP_SPEED = 7.0,        -- How quickly facing interpolates to match movement direction
    TURN_ANGLE_DEADZONE = 5,      -- Angle difference (in degrees) below which no speed penalty is applied
    MAX_FORWARD_TURN = 200,       -- Maximum angle difference for forward movement (will walk backwards beyond this)

    -- Charging movement
    CHARGE_MOVE_SPEED_MULT = 0.40, -- Slightly faster while charging to keep agency

    -- Charge buildup
    CHARGE_MAX = 1.25,             -- Maximum charge value achievable
    CHARGE_RATE = 3.0,             -- How quickly charge builds up (higher = faster)
    CHARGE_DECAY_RATE = 2.0,       -- How quickly charge decays when idle (units per second)

    -- Cancel animation
    CANCEL_DURATION = 0.333,       -- Duration of cancel animation in seconds
}

-- Head Animation Configuration
local HEAD_CONFIG = {
    OFFSET_SCALE = 0.4,            -- How far back the head pulls during charge
    SNAP_FORWARD_SCALE = 0.65,      -- How far forward the head snaps during headbutt
    SNAP_TOTAL_DURATION = 0.5,     -- Slightly longer to sell impact
    SNAP_FORWARD_RATIO = 0.5,      -- A hair more forward time for readability
	IFRAME_PRE_PEAK_TIME = 0.055,    -- Tiny increase for fairness
    SNAP_RETURN_EXTRA = 0.16,       -- Keep return smooth
}

-- Math constants for angle calculations
local MATH_CONFIG = {
    DEG_TO_RAD = math.pi / 180,
    RAD_TO_DEG = 180 / math.pi,
    TWO_PI = 2 * math.pi,
    HALF_PI = math.pi / 2,
}

-- Validation function to ensure all values are reasonable
function MOVEMENT_CONFIG.validate()
    -- Check for reasonable speed values
    assert(MOVEMENT_CONFIG.BASE_MOVE_SPEED > 0, "BASE_MOVE_SPEED must be positive")
    assert(MOVEMENT_CONFIG.BASE_ROTATION_SPEED > 0, "BASE_ROTATION_SPEED must be positive")

    -- Check multipliers are in reasonable ranges
    assert(MOVEMENT_CONFIG.BACKWARD_SPEED_MULT > 0 and MOVEMENT_CONFIG.BACKWARD_SPEED_MULT <= 1,
           "BACKWARD_SPEED_MULT must be between 0 and 1")
    assert(MOVEMENT_CONFIG.MIN_TURN_SPEED_MULT > 0 and MOVEMENT_CONFIG.MIN_TURN_SPEED_MULT <= 1,
           "MIN_TURN_SPEED_MULT must be between 0 and 1")
    assert(MOVEMENT_CONFIG.CHARGE_MOVE_SPEED_MULT > 0 and MOVEMENT_CONFIG.CHARGE_MOVE_SPEED_MULT <= 1,
           "CHARGE_MOVE_SPEED_MULT must be between 0 and 1")

    -- Check charge values
    assert(MOVEMENT_CONFIG.CHARGE_MAX > 0, "CHARGE_MAX must be positive")
    assert(MOVEMENT_CONFIG.CHARGE_RATE > 0, "CHARGE_RATE must be positive")
    assert(MOVEMENT_CONFIG.CHARGE_DECAY_RATE > 0, "CHARGE_DECAY_RATE must be positive")

    -- Check head animation values
    assert(HEAD_CONFIG.OFFSET_SCALE > 0, "HEAD_OFFSET_SCALE must be positive")
    assert(HEAD_CONFIG.SNAP_FORWARD_SCALE > 0, "HEAD_SNAP_FORWARD_SCALE must be positive")
    assert(HEAD_CONFIG.SNAP_TOTAL_DURATION > 0, "HEAD_SNAP_TOTAL_DURATION must be positive")
    assert(HEAD_CONFIG.SNAP_FORWARD_RATIO > 0 and HEAD_CONFIG.SNAP_FORWARD_RATIO < 1,
           "HEAD_SNAP_FORWARD_RATIO must be between 0 and 1")

    return true
end

-- Helper functions for common calculations
function MOVEMENT_CONFIG.degrees_to_radians(degrees)
    return degrees * MATH_CONFIG.DEG_TO_RAD
end

function MOVEMENT_CONFIG.radians_to_degrees(radians)
    return radians * MATH_CONFIG.RAD_TO_DEG
end

-- Normalize angle to [0, 2π) range
function MOVEMENT_CONFIG.normalize_angle_radians(angle)
    while angle < 0 do
        angle = angle + MATH_CONFIG.TWO_PI
    end
    while angle >= MATH_CONFIG.TWO_PI do
        angle = angle - MATH_CONFIG.TWO_PI
    end
    return angle
end

-- Normalize angle to [0, 360) range
function MOVEMENT_CONFIG.normalize_angle_degrees(angle)
    while angle < 0 do
        angle = angle + 360
    end
    while angle >= 360 do
        angle = angle - 360
    end
    return angle
end

-- Calculate shortest angle difference in radians
function MOVEMENT_CONFIG.angle_difference_radians(from, to)
    local diff = to - from
    while diff > math.pi do
        diff = diff - MATH_CONFIG.TWO_PI
    end
    while diff < -math.pi do
        diff = diff + MATH_CONFIG.TWO_PI
    end
    return diff
end

-- Calculate shortest angle difference in degrees
function MOVEMENT_CONFIG.angle_difference_degrees(from, to)
    local diff = to - from
    while diff > 180 do
        diff = diff - 360
    end
    while diff < -180 do
        diff = diff + 360
    end
    return diff
end

return {
    MOVEMENT = MOVEMENT_CONFIG,
    HEAD = HEAD_CONFIG,
    MATH = MATH_CONFIG
}
