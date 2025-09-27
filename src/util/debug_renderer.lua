-- Debug Renderer - Comprehensive debug visualization system
-- Provides structured debug drawing capabilities with layers, colors, and persistence

---@class DebugRenderer
---@field layers table<string, DebugLayer> Debug layers organized by name
---@field enabled boolean Whether debug rendering is globally enabled
---@field default_layer_name string Name of the default debug layer
local DebugRenderer = {}
DebugRenderer.__index = DebugRenderer

---@class DebugLayer
---@field name string Layer identifier
---@field enabled boolean Whether this layer is visible
---@field priority number Draw order priority (higher draws on top)
---@field items DebugItem[] List of debug items to draw
---@field persistent boolean Whether items persist between frames
local DebugLayer = {}
DebugLayer.__index = DebugLayer

---@class DebugItem
---@field type string Type of debug item ("line", "circle", "rect", "text", "arrow", "cross")
---@field data table Item-specific data
---@field color table RGBA color {r, g, b, a}
---@field lifetime number? Time remaining before item expires (nil = permanent)
---@field created_time number? Time when item was created

---@class DebugStyle
---@field line_width number Default line width
---@field font love.Font? Default font for text
---@field colors table<string, table> Named color palette
local DebugStyle = {
    line_width = 2,
    font = nil, -- Will be set to default font
    colors = {
        white = {1, 1, 1, 1},
        black = {0, 0, 0, 1},
        red = {1, 0, 0, 1},
        green = {0, 1, 0, 1},
        blue = {0, 0, 1, 1},
        yellow = {1, 1, 0, 1},
        cyan = {0, 1, 1, 1},
        magenta = {1, 0, 1, 1},
        orange = {1, 0.5, 0, 1},
        purple = {0.5, 0, 1, 1},
        gray = {0.5, 0.5, 0.5, 1},
        light_gray = {0.8, 0.8, 0.8, 1},
        dark_gray = {0.3, 0.3, 0.3, 1},
        transparent_white = {1, 1, 1, 0.5},
        transparent_red = {1, 0, 0, 0.5},
        transparent_green = {0, 1, 0, 0.5},
        transparent_blue = {0, 0, 1, 0.5}
    }
}

---Create a new debug renderer
---@return DebugRenderer
function DebugRenderer.new()
    local self = setmetatable({}, DebugRenderer)

    self.layers = {}
    self.enabled = false
    self.default_layer_name = "default"

    -- Initialize default font
    DebugStyle.font = love.graphics.getFont()

    -- Create default layer
    self:create_layer(self.default_layer_name, true, 0, false)

    return self
end

---Create a new debug layer
---@param name string Layer identifier
---@param enabled boolean Whether layer is initially visible
---@param priority number Draw order priority
---@param persistent boolean Whether items persist between frames
---@return DebugLayer
function DebugRenderer:create_layer(name, enabled, priority, persistent)
    local layer = setmetatable({}, DebugLayer)
    layer.name = name
    layer.enabled = enabled or false
    layer.priority = priority or 0
    layer.items = {}
    layer.persistent = persistent or false

    self.layers[name] = layer
    return layer
end

---Get or create a debug layer
---@param name string Layer identifier
---@return DebugLayer
function DebugRenderer:get_layer(name)
    if not self.layers[name] then
        self:create_layer(name, true, 0, false)
    end
    return self.layers[name]
end

---Enable/disable debug rendering globally
---@param enabled boolean
function DebugRenderer:set_enabled(enabled)
    self.enabled = enabled
end

---Enable/disable a specific layer
---@param name string Layer identifier
---@param enabled boolean
function DebugRenderer:set_layer_enabled(name, enabled)
    local layer = self:get_layer(name)
    layer.enabled = enabled
end

---Toggle a layer's visibility
---@param name string Layer identifier
function DebugRenderer:toggle_layer(name)
    local layer = self:get_layer(name)
    layer.enabled = not layer.enabled
end

---Clear all items from a layer
---@param name string? Layer identifier (nil = all layers)
function DebugRenderer:clear(name)
    if name then
        local layer = self.layers[name]
        if layer then
            layer.items = {}
        end
    else
        for _, layer in pairs(self.layers) do
            if not layer.persistent then
                layer.items = {}
            end
        end
    end
end

---Add a debug item to a layer
---@param layer_name string? Layer identifier (nil = default layer)
---@param item DebugItem Debug item to add
function DebugRenderer:add_item(layer_name, item)
    layer_name = layer_name or self.default_layer_name
    local layer = self:get_layer(layer_name)

    item.created_time = love.timer.getTime()
    table.insert(layer.items, item)
end

-- Drawing functions

---Draw a line
---@param x1 number Start X coordinate
---@param y1 number Start Y coordinate
---@param x2 number End X coordinate
---@param y2 number End Y coordinate
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_line(x1, y1, x2, y2, color, layer_name, lifetime)
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "line",
        data = {x1 = x1, y1 = y1, x2 = x2, y2 = y2},
        color = color,
        lifetime = lifetime
    })
end

---Draw a circle
---@param x number Center X coordinate
---@param y number Center Y coordinate
---@param radius number Circle radius
---@param mode string? "line" or "fill" (default: "line")
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_circle(x, y, radius, mode, color, layer_name, lifetime)
    mode = mode or "line"
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "circle",
        data = {x = x, y = y, radius = radius, mode = mode},
        color = color,
        lifetime = lifetime
    })
end

---Draw a rectangle
---@param x number Top-left X coordinate
---@param y number Top-left Y coordinate
---@param width number Rectangle width
---@param height number Rectangle height
---@param mode string? "line" or "fill" (default: "line")
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_rect(x, y, width, height, mode, color, layer_name, lifetime)
    mode = mode or "line"
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "rect",
        data = {x = x, y = y, width = width, height = height, mode = mode},
        color = color,
        lifetime = lifetime
    })
end

---Draw an oriented bounding box
---@param obb table OBB with center, half_extents, rotation
---@param mode string? "line" or "fill" (default: "line")
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_obb(obb, mode, color, layer_name, lifetime)
    mode = mode or "line"
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "obb",
        data = {obb = obb, mode = mode},
        color = color,
        lifetime = lifetime
    })
end

---Draw text
---@param text string Text to display
---@param x number X coordinate
---@param y number Y coordinate
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_text(text, x, y, color, layer_name, lifetime)
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "text",
        data = {text = tostring(text), x = x, y = y},
        color = color,
        lifetime = lifetime
    })
end

---Draw an arrow
---@param x1 number Start X coordinate
---@param y1 number Start Y coordinate
---@param x2 number End X coordinate
---@param y2 number End Y coordinate
---@param head_size number? Arrow head size (default: 10)
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_arrow(x1, y1, x2, y2, head_size, color, layer_name, lifetime)
    head_size = head_size or 10
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "arrow",
        data = {x1 = x1, y1 = y1, x2 = x2, y2 = y2, head_size = head_size},
        color = color,
        lifetime = lifetime
    })
end

---Draw a cross/plus marker
---@param x number Center X coordinate
---@param y number Center Y coordinate
---@param size number Cross size
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_cross(x, y, size, color, layer_name, lifetime)
    color = self:resolve_color(color or "white")
    self:add_item(layer_name, {
        type = "cross",
        data = {x = x, y = y, size = size},
        color = color,
        lifetime = lifetime
    })
end

---Draw a vector from origin
---@param origin_x number Origin X coordinate
---@param origin_y number Origin Y coordinate
---@param vector_x number Vector X component
---@param vector_y number Vector Y component
---@param scale number? Vector scale multiplier (default: 1)
---@param color string|table? Color name or RGBA table
---@param layer_name string? Layer identifier
---@param lifetime number? Item lifetime in seconds
function DebugRenderer:draw_vector(origin_x, origin_y, vector_x, vector_y, scale, color, layer_name, lifetime)
    scale = scale or 1
    local end_x = origin_x + vector_x * scale
    local end_y = origin_y + vector_y * scale
    self:draw_arrow(origin_x, origin_y, end_x, end_y, 8, color, layer_name, lifetime)
end

---Resolve color name to RGBA table
---@param color string|table Color name or RGBA table
---@return table RGBA color table
function DebugRenderer:resolve_color(color)
    if type(color) == "string" then
        return DebugStyle.colors[color] or DebugStyle.colors.white
    elseif type(color) == "table" then
        return color
    else
        return DebugStyle.colors.white
    end
end

---Update debug renderer (remove expired items)
---@param dt number Delta time
function DebugRenderer:update(dt)
    local current_time = love.timer.getTime()

    for _, layer in pairs(self.layers) do
        for i = #layer.items, 1, -1 do
            local item = layer.items[i]
            if item.lifetime then
                local age = current_time - item.created_time
                if age >= item.lifetime then
                    table.remove(layer.items, i)
                end
            end
        end
    end
end

---Render all debug items
function DebugRenderer:render()
    if not self.enabled then
        return
    end

    -- Save graphics state
    love.graphics.push("all")

    -- Get sorted layers by priority
    local sorted_layers = {}
    for _, layer in pairs(self.layers) do
        if layer.enabled then
            table.insert(sorted_layers, layer)
        end
    end
    table.sort(sorted_layers, function(a, b) return a.priority < b.priority end)

    -- Render each layer
    for _, layer in ipairs(sorted_layers) do
        self:render_layer(layer)
    end

    -- Restore graphics state
    love.graphics.pop()
end

---Render a specific layer
---@param layer DebugLayer Layer to render
function DebugRenderer:render_layer(layer)
    for _, item in ipairs(layer.items) do
        self:render_item(item)
    end
end

---Render a specific debug item
---@param item DebugItem Item to render
function DebugRenderer:render_item(item)
    love.graphics.setColor(item.color)
    love.graphics.setLineWidth(DebugStyle.line_width)

    if item.type == "line" then
        love.graphics.line(item.data.x1, item.data.y1, item.data.x2, item.data.y2)

    elseif item.type == "circle" then
        love.graphics.circle(item.data.mode, item.data.x, item.data.y, item.data.radius)

    elseif item.type == "rect" then
        love.graphics.rectangle(item.data.mode, item.data.x, item.data.y, item.data.width, item.data.height)

    elseif item.type == "obb" then
        self:render_obb(item.data.obb, item.data.mode)

    elseif item.type == "text" then
        love.graphics.setFont(DebugStyle.font)
        love.graphics.print(item.data.text, item.data.x, item.data.y)

    elseif item.type == "arrow" then
        self:render_arrow(item.data)

    elseif item.type == "cross" then
        local x, y, size = item.data.x, item.data.y, item.data.size
        love.graphics.line(x - size, y, x + size, y)
        love.graphics.line(x, y - size, x, y + size)
    end
end

---Render an oriented bounding box
---@param obb table OBB with center, half_extents, rotation
---@param mode string "line" or "fill"
function DebugRenderer:render_obb(obb, mode)
    local collision_utils = require("util.collision")
    local corners = collision_utils.get_obb_corners(obb)

    if mode == "fill" then
        -- Draw filled polygon
        local points = {}
        for _, corner in ipairs(corners) do
            table.insert(points, corner.x)
            table.insert(points, corner.y)
        end
        love.graphics.polygon("fill", points)
    else
        -- Draw outline
        for i = 1, #corners do
            local next_i = (i % #corners) + 1
            love.graphics.line(corners[i].x, corners[i].y, corners[next_i].x, corners[next_i].y)
        end
    end
end

---Render an arrow
---@param data table Arrow data with x1, y1, x2, y2, head_size
function DebugRenderer:render_arrow(data)
    local x1, y1, x2, y2 = data.x1, data.y1, data.x2, data.y2
    local head_size = data.head_size

    -- Draw main line
    love.graphics.line(x1, y1, x2, y2)

    -- Calculate arrow head
    local angle = math.atan2(y2 - y1, x2 - x1)
    local head_angle1 = angle + math.pi * 0.75
    local head_angle2 = angle - math.pi * 0.75

    local head_x1 = x2 + math.cos(head_angle1) * head_size
    local head_y1 = y2 + math.sin(head_angle1) * head_size
    local head_x2 = x2 + math.cos(head_angle2) * head_size
    local head_y2 = y2 + math.sin(head_angle2) * head_size

    -- Draw arrow head
    love.graphics.line(x2, y2, head_x1, head_y1)
    love.graphics.line(x2, y2, head_x2, head_y2)
end

---Get debug statistics
---@return table Statistics about debug renderer state
function DebugRenderer:get_stats()
    local stats = {
        enabled = self.enabled,
        total_layers = 0,
        enabled_layers = 0,
        total_items = 0,
        items_by_layer = {}
    }

    for name, layer in pairs(self.layers) do
        stats.total_layers = stats.total_layers + 1
        if layer.enabled then
            stats.enabled_layers = stats.enabled_layers + 1
        end

        local item_count = #layer.items
        stats.total_items = stats.total_items + item_count
        stats.items_by_layer[name] = {
            enabled = layer.enabled,
            priority = layer.priority,
            persistent = layer.persistent,
            item_count = item_count
        }
    end

    return stats
end

return DebugRenderer
