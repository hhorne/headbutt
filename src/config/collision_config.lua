-- Collision Configuration - tuning for soft body-body resolution

local COLLISION_CONFIG = {
    -- How strongly to separate overlapping bodies per iteration (1.0 = full MTV)
    SEPARATION_FRACTION = 1.0,

    -- Minimum separation to avoid lingering micro-overlaps (in pixels)
    MIN_SEPARATION = 0.5,

    -- Bias for splitting separation between two bodies (mover vs other)
    -- 1.0 means all on mover, 0.5 split evenly
    MOVER_BIAS = 0.7,

    -- Gentle push impulse to the other dude when bumped during normal motion
    -- Applied as a short knockback-like nudge via Physics
    GENTLE_PUSH_SPEED = 40,
    GENTLE_PUSH_DURATION = 0.08,

    -- Limit of how much we move entities in one update to avoid tunneling jitter
    MAX_SEPARATION_PER_FRAME = 12.0,

    -- Number of solver iterations per pair per frame (recomputes MTV after each move)
    SOLVER_ITERATIONS = 3,

    -- Remove inward velocity along contact normal for the pusher
    BLOCK_INWARD_VELOCITY = true,

    -- Dampen tangential sliding when in contact (1.0 = no damping)
    TANGENTIAL_DAMPING = 0.9,

    -- Shape tuning for dude composite collider
    SHOULDER_RADIUS_FACTOR = 0.5,   -- As fraction of min(width, height). 0.5 ~= rounded corner radius
    EPSILON_SHRINK = 0.5,           -- Pixels to shrink shapes to reduce micro-overlaps
    USE_CORNER_CIRCLES = false,     -- Optional small rounded-rect corners for better visual match
    CORNER_RADIUS_FACTOR = 0.1,     -- As fraction of min(width, height)
}

return COLLISION_CONFIG


