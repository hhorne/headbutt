-- Easing Functions Library
-- Provides smooth interpolation functions for animations
-- All functions take t (time progress 0-1) and return eased value (0-1)

local Easing = {}

-- Linear (no easing)
function Easing.linear(t)
    return t
end

-- Quadratic easing
function Easing.ease_in_quad(t)
    return t * t
end

function Easing.ease_out_quad(t)
    return 1 - (1 - t) * (1 - t)
end

function Easing.ease_in_out_quad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - 2 * (1 - t) * (1 - t)
    end
end

-- Cubic easing
function Easing.ease_in_cubic(t)
    return t * t * t
end

function Easing.ease_out_cubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

function Easing.ease_in_out_cubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local inv = 1 - t
        return 1 - 4 * inv * inv * inv
    end
end

-- Quartic easing
function Easing.ease_in_quart(t)
    return t * t * t * t
end

function Easing.ease_out_quart(t)
    local inv = 1 - t
    return 1 - inv * inv * inv * inv
end

function Easing.ease_in_out_quart(t)
    if t < 0.5 then
        return 8 * t * t * t * t
    else
        local inv = 1 - t
        return 1 - 8 * inv * inv * inv * inv
    end
end

-- Exponential easing
function Easing.ease_in_expo(t)
    if t == 0 then return 0 end
    return math.pow(2, 10 * (t - 1))
end

function Easing.ease_out_expo(t)
    if t == 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

function Easing.ease_in_out_expo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end

    if t < 0.5 then
        return 0.5 * math.pow(2, 20 * t - 10)
    else
        return 1 - 0.5 * math.pow(2, -20 * t + 10)
    end
end

-- Sine easing
function Easing.ease_in_sine(t)
    return 1 - math.cos(t * math.pi / 2)
end

function Easing.ease_out_sine(t)
    return math.sin(t * math.pi / 2)
end

function Easing.ease_in_out_sine(t)
    return 0.5 * (1 - math.cos(t * math.pi))
end

-- Back easing (overshoots then settles)
function Easing.ease_in_back(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return c3 * t * t * t - c1 * t * t
end

function Easing.ease_out_back(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local inv = t - 1
    return 1 + c3 * inv * inv * inv + c1 * inv * inv
end

function Easing.ease_in_out_back(t)
    local c1 = 1.70158
    local c2 = c1 * 1.525

    if t < 0.5 then
        return 0.5 * (4 * t * t * ((c2 + 1) * 2 * t - c2))
    else
        local inv = 2 * t - 2
        return 0.5 * (inv * inv * ((c2 + 1) * inv + c2) + 2)
    end
end

-- Elastic easing (spring-like)
function Easing.ease_in_elastic(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end

    local c4 = (2 * math.pi) / 3
    return -math.pow(2, 10 * t - 10) * math.sin((t * 10 - 10.75) * c4)
end

function Easing.ease_out_elastic(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end

    local c4 = (2 * math.pi) / 3
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

function Easing.ease_in_out_elastic(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end

    local c5 = (2 * math.pi) / 4.5

    if t < 0.5 then
        return -0.5 * math.pow(2, 20 * t - 10) * math.sin((20 * t - 11.125) * c5)
    else
        return 0.5 * math.pow(2, -20 * t + 10) * math.sin((20 * t - 11.125) * c5) + 1
    end
end

-- Bounce easing
function Easing.ease_out_bounce(t)
    local n1 = 7.5625
    local d1 = 2.75

    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

function Easing.ease_in_bounce(t)
    return 1 - Easing.ease_out_bounce(1 - t)
end

function Easing.ease_in_out_bounce(t)
    if t < 0.5 then
        return 0.5 * (1 - Easing.ease_out_bounce(1 - 2 * t))
    else
        return 0.5 * (1 + Easing.ease_out_bounce(2 * t - 1))
    end
end

-- Utility functions for common animation patterns

-- Smooth step (similar to smoothstep in graphics)
function Easing.smooth_step(t)
    return t * t * (3 - 2 * t)
end

-- Smoother step (even smoother than smooth_step)
function Easing.smoother_step(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Custom easing for knockback decay (exponential with configurable rate)
function Easing.exponential_decay(t, rate)
    rate = rate or 4.0
    return math.exp(-t * rate)
end

-- Custom easing for head animation (smooth charge buildup)
function Easing.charge_buildup(t)
    -- Starts slow, accelerates, then smooths out
    return Easing.ease_in_out_cubic(t)
end

-- Custom easing for head snap (quick snap with slight overshoot)
function Easing.head_snap(t)
    if t < 0.7 then
        -- Quick acceleration to overshoot
        local normalized_t = t / 0.7
        return 1.1 * Easing.ease_out_cubic(normalized_t)
    else
        -- Settle back to final position
        local normalized_t = (t - 0.7) / 0.3
        return 1.1 - 0.1 * Easing.ease_out_quad(normalized_t)
    end
end

-- Custom easing for head return (smooth return to idle)
function Easing.head_return(t)
    return Easing.ease_out_sine(t)
end

-- Get easing function by name (for configuration)
function Easing.get_function(name)
    local functions = {
        linear = Easing.linear,
        ease_in_quad = Easing.ease_in_quad,
        ease_out_quad = Easing.ease_out_quad,
        ease_in_out_quad = Easing.ease_in_out_quad,
        ease_in_cubic = Easing.ease_in_cubic,
        ease_out_cubic = Easing.ease_out_cubic,
        ease_in_out_cubic = Easing.ease_in_out_cubic,
        ease_in_quart = Easing.ease_in_quart,
        ease_out_quart = Easing.ease_out_quart,
        ease_in_out_quart = Easing.ease_in_out_quart,
        ease_in_expo = Easing.ease_in_expo,
        ease_out_expo = Easing.ease_out_expo,
        ease_in_out_expo = Easing.ease_in_out_expo,
        ease_in_sine = Easing.ease_in_sine,
        ease_out_sine = Easing.ease_out_sine,
        ease_in_out_sine = Easing.ease_in_out_sine,
        ease_in_back = Easing.ease_in_back,
        ease_out_back = Easing.ease_out_back,
        ease_in_out_back = Easing.ease_in_out_back,
        ease_in_elastic = Easing.ease_in_elastic,
        ease_out_elastic = Easing.ease_out_elastic,
        ease_in_out_elastic = Easing.ease_in_out_elastic,
        ease_in_bounce = Easing.ease_in_bounce,
        ease_out_bounce = Easing.ease_out_bounce,
        ease_in_out_bounce = Easing.ease_in_out_bounce,
        smooth_step = Easing.smooth_step,
        smoother_step = Easing.smoother_step,
        charge_buildup = Easing.charge_buildup,
        head_snap = Easing.head_snap,
        head_return = Easing.head_return
    }

    return functions[name]
end

-- List all available easing functions
function Easing.get_available_functions()
    return {
        "linear", "ease_in_quad", "ease_out_quad", "ease_in_out_quad",
        "ease_in_cubic", "ease_out_cubic", "ease_in_out_cubic",
        "ease_in_quart", "ease_out_quart", "ease_in_out_quart",
        "ease_in_expo", "ease_out_expo", "ease_in_out_expo",
        "ease_in_sine", "ease_out_sine", "ease_in_out_sine",
        "ease_in_back", "ease_out_back", "ease_in_out_back",
        "ease_in_elastic", "ease_out_elastic", "ease_in_out_elastic",
        "ease_in_bounce", "ease_out_bounce", "ease_in_out_bounce",
        "smooth_step", "smoother_step", "charge_buildup", "head_snap", "head_return"
    }
end

return Easing
