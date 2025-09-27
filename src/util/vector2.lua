-- Vector2 utility class for 2D math operations

local Vector2 = {}
Vector2.__index = Vector2

-- Constructor
function Vector2.new(x, y)
    return setmetatable({
        x = x or 0,
        y = y or 0
    }, Vector2)
end

-- Create from table {x, y}
function Vector2.from_table(t)
    return Vector2.new(t.x or 0, t.y or 0)
end

-- Zero vector
function Vector2.zero()
    return Vector2.new(0, 0)
end

-- Unit vectors
function Vector2.up()
    return Vector2.new(0, -1)
end

function Vector2.down()
    return Vector2.new(0, 1)
end

function Vector2.left()
    return Vector2.new(-1, 0)
end

function Vector2.right()
    return Vector2.new(1, 0)
end

-- Basic operations
function Vector2:add(other)
    return Vector2.new(self.x + other.x, self.y + other.y)
end

function Vector2:subtract(other)
    return Vector2.new(self.x - other.x, self.y - other.y)
end

function Vector2:multiply(scalar)
    return Vector2.new(self.x * scalar, self.y * scalar)
end

function Vector2:divide(scalar)
    if scalar == 0 then
        error("Division by zero")
    end
    return Vector2.new(self.x / scalar, self.y / scalar)
end

-- Vector operations
function Vector2:magnitude()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vector2:magnitude_squared()
    return self.x * self.x + self.y * self.y
end

function Vector2:normalize()
    local mag = self:magnitude()
    if mag == 0 then
        return Vector2.zero()
    end
    return self:divide(mag)
end

function Vector2:normalized()
    return self:normalize()
end

function Vector2:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector2:distance_to(other)
    return self:subtract(other):magnitude()
end

function Vector2:angle()
    return math.atan2(self.y, self.x)
end

function Vector2:angle_to(other)
    return math.atan2(other.y - self.y, other.x - self.x)
end

-- Utility functions
function Vector2:is_zero()
    return self.x == 0 and self.y == 0
end

function Vector2:clamp(min_val, max_val)
    return Vector2.new(
        math.max(min_val, math.min(max_val, self.x)),
        math.max(min_val, math.min(max_val, self.y))
    )
end

-- Apply deadzone to both components
function Vector2:apply_deadzone(deadzone)
    local x = math.abs(self.x) < deadzone and 0 or self.x
    local y = math.abs(self.y) < deadzone and 0 or self.y
    return Vector2.new(x, y)
end

-- Convert to table for compatibility
function Vector2:to_table()
    return {x = self.x, y = self.y}
end

-- String representation
function Vector2:__tostring()
    return string.format("Vector2(%.2f, %.2f)", self.x, self.y)
end

-- Metamethods for operators
function Vector2:__add(other)
    return self:add(other)
end

function Vector2:__sub(other)
    return self:subtract(other)
end

function Vector2:__mul(scalar)
    return self:multiply(scalar)
end

function Vector2:__div(scalar)
    return self:divide(scalar)
end

function Vector2:__eq(other)
    return self.x == other.x and self.y == other.y
end

return Vector2
