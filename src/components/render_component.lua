-- Render Component - Handles visual appearance and rendering data

local component_system = require("util.component_system")

local RenderComponent = {}
RenderComponent.__index = RenderComponent
setmetatable(RenderComponent, {__index = component_system.Component})

function RenderComponent.new(entity_id, data)
    local self = setmetatable(component_system.Component.new(entity_id), RenderComponent)

    -- Body appearance
    self.body_width = data.body_width or 120
    self.body_height = data.body_height or 60
    self.body_color = data.body_color or {0, 0.5, 1, 1}

    -- Head appearance
    self.head_radius = data.head_radius or math.min(self.body_width, self.body_height) * 0.5
    self.head_color = data.head_color or {1.0, 0.85, 0.73, 1}

    -- Rendering flags
    self.visible = data.visible ~= false -- Default to true
    self.draw_debug = data.draw_debug or false

    -- Render layer (for z-ordering)
    self.layer = data.layer or 0

    return self
end

function RenderComponent:get_type()
    return "Render"
end

function RenderComponent:set_body_color(r, g, b, a)
    self.body_color = {r, g, b, a or 1}
end

function RenderComponent:set_head_color(r, g, b, a)
    self.head_color = {r, g, b, a or 1}
end

function RenderComponent:get_body_color()
    return self.body_color[1], self.body_color[2], self.body_color[3], self.body_color[4]
end

function RenderComponent:get_head_color()
    return self.head_color[1], self.head_color[2], self.head_color[3], self.head_color[4]
end

function RenderComponent:set_body_size(width, height)
    self.body_width = width
    self.body_height = height
    -- Update head radius to maintain proportion
    self.head_radius = math.min(width, height) * 0.5
end

function RenderComponent:get_body_size()
    return self.body_width, self.body_height
end

function RenderComponent:set_head_radius(radius)
    self.head_radius = radius
end

function RenderComponent:get_head_radius()
    return self.head_radius
end

function RenderComponent:set_visible(visible)
    self.visible = visible
end

function RenderComponent:is_visible()
    return self.visible
end

function RenderComponent:set_debug_draw(enabled)
    self.draw_debug = enabled
end

function RenderComponent:should_draw_debug()
    return self.draw_debug
end

function RenderComponent:set_layer(layer)
    self.layer = layer
end

function RenderComponent:get_layer()
    return self.layer
end

function RenderComponent:update(dt)
    -- Render components typically don't need to update
    -- But this could be used for animations, color transitions, etc.
end

-- Register component type
component_system.ComponentRegistry.register(RenderComponent, "Render")

return RenderComponent
