-- Render System - Handles drawing entities with render components

local component_system = require("util.component_system")
local movement_config = require("config.movement_config")

local RenderSystem = {}
RenderSystem.__index = RenderSystem
setmetatable(RenderSystem, {__index = component_system.System})

function RenderSystem.new(component_manager)
    local self = setmetatable(component_system.System.new(component_manager), RenderSystem)

    -- Trig cache for performance
    self.trig_cache = {}

    -- Debug renderer reference (set via draw_all_entities)
    self.debug_renderer = nil

    return self
end

function RenderSystem:get_required_components()
    return {"Transform", "Render"}
end

function RenderSystem:get_cached_trig(angle_radians)
    local key = math.floor(angle_radians * 1000) -- Cache with 0.001 precision
    if not self.trig_cache[key] then
        self.trig_cache[key] = {
            sin = math.sin(angle_radians),
            cos = math.cos(angle_radians)
        }
    end
    return self.trig_cache[key]
end

function RenderSystem:process_entity(entity_id, dt)
    -- Rendering happens in draw phase, not update
end

function RenderSystem:draw_entity(entity_id, debug_mode)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local render = self.component_manager:get_component(entity_id, "Render")

    if not transform or not render or not render:is_visible() then
        return
    end

    -- Get animation component for head offset
    local animation = self.component_manager:get_component(entity_id, "Animation")
    local head_offset = animation and animation:get_head_offset() or 0

    -- Use consistent radians internally
    local angle_radians = movement_config.MOVEMENT.degrees_to_radians(transform:get_facing())

    -- Subtle stun wobble (normal render path, not debug)
    if animation and animation.is_stunned and animation:is_stunned() then
        local stun_config = require("config.stun_config")
        local t = love.timer.getTime()
        local phase = (entity_id % 7) * 0.35
        local wobble_amp = stun_config.WOBBLE.AMP
        local wobble_freq = stun_config.WOBBLE.FREQ
        angle_radians = angle_radians + math.sin((t + phase) * wobble_freq) * wobble_amp
    end

    love.graphics.push()
    love.graphics.translate(transform:get_position())
    love.graphics.rotate(angle_radians)

    -- Draw body centered at origin
    love.graphics.setColor(render:get_body_color())
    local body_width, body_height = render:get_body_size()
    local corner_radius = math.min(body_width, body_height) * 0.5
    love.graphics.rectangle("fill", -body_width / 2, -body_height / 2, body_width, body_height, corner_radius, corner_radius)

    -- Draw head with offset when charging
    local head_r, head_g, head_b, head_a = render:get_head_color()
    do
        local animation = self.component_manager:get_component(entity_id, "Animation")
        if debug_mode and animation and animation.is_invincible and animation:is_invincible() then
            head_r, head_g, head_b = 0.3, 1.0, 0.3
        end
    end
    love.graphics.setColor(head_r, head_g, head_b, head_a)
    local head_offset_x = 0
    local head_offset_y = 0

    -- Apply head offset in the local coordinate system (already rotated)
    if head_offset and head_offset ~= 0 then
        local offset_distance = head_offset * render:get_head_radius() * 2
        head_offset_y = offset_distance -- Move forward in the local coordinate system
    end

    love.graphics.circle("fill", head_offset_x, head_offset_y, render:get_head_radius())

    love.graphics.pop()

    -- Draw debug information if requested
    if debug_mode and (render:should_draw_debug() or debug_mode == "all") then
        self:draw_debug_info(entity_id)
    end
end

function RenderSystem:draw_debug_info(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local render = self.component_manager:get_component(entity_id, "Render")

    if not transform or not render then
        return
    end

    -- Draw facing direction line
    local x, y = transform:get_position()
    local angle_radians = movement_config.MOVEMENT.degrees_to_radians(transform:get_facing() - 90)
    local trig = self:get_cached_trig(angle_radians)

    -- Calculate arrow length as 24% of head circumference (20% * 1.2 = 24% for 20% increase)
    local head_circumference = 2 * math.pi * render:get_head_radius()
    local arrow_length = head_circumference * 0.24

    -- Calculate end point using cached trig values
    local end_x = x + trig.cos * arrow_length
    local end_y = y + trig.sin * arrow_length

    -- Draw the debug arrow if we have a debug renderer
    if self.debug_renderer then
        self.debug_renderer:draw_arrow(x, y, end_x, end_y, 8, "yellow", "debug")
    end
end

function RenderSystem:draw_all_entities(debug_mode, game_manager)
    -- Store debug renderer reference from game manager
    self.debug_renderer = game_manager.debug_renderer
    -- Get all entities with render components, sorted by layer
    local entities = self.component_manager:get_entities_with_components({"Transform", "Render"})

    -- Sort by render layer
    table.sort(entities, function(a, b)
        local render_a = self.component_manager:get_component(a, "Render")
        local render_b = self.component_manager:get_component(b, "Render")
        return render_a:get_layer() < render_b:get_layer()
    end)

    -- Draw all entities in layer order
    for _, entity_id in ipairs(entities) do
        self:draw_entity(entity_id, debug_mode)
    end

    -- Draw debug UI if debug mode is active
    if debug_mode and game_manager then
        self:draw_debug_ui(game_manager)
    end

	-- Always draw player-facing gamepad help (place away from F1 panel)
	self:draw_gamepad_help()
end

function RenderSystem:draw_debug_ui(game_manager)
    -- Save current graphics state
    love.graphics.push("all")

    -- Reset transformations for UI drawing
    love.graphics.origin()

    -- Set up UI rendering
    love.graphics.setColor(1, 1, 1, 0.9) -- White with slight transparency
    love.graphics.setFont(love.graphics.getFont()) -- Use default font

    -- Draw debug information panel
    local ui_x = 10
    local ui_y = 10
    local line_height = 20
    local current_y = ui_y

    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.7) -- Semi-transparent black background
    love.graphics.rectangle("fill", ui_x - 5, ui_y - 5, 360, 180)

    -- Debug text
    love.graphics.setColor(1, 1, 1, 1) -- White text
    love.graphics.print("DEBUG MODE (F1 to toggle)", ui_x, current_y)
    current_y = current_y + line_height
    current_y = current_y + 4

    -- Current knockback preset
    local preset_text = "Knockback Preset: " .. (game_manager.current_knockback_preset or "UNKNOWN")
    love.graphics.print(preset_text, ui_x, current_y)
    current_y = current_y + line_height

    -- Preset cycling instruction
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("F2 to cycle knockback presets", ui_x, current_y)
    current_y = current_y + line_height

    -- Knockback properties directly under controls
    local knockback_config = require("config.knockback_config")
    local settings = knockback_config.get_current_settings()
    local settings_text = string.format(
        "Knockback: Speed %d  Dur %.2f  Curve %.1f  Decay %.1f (%s)",
        settings.base_speed,
        settings.duration,
        settings.curve_power,
        settings.decay_rate,
        tostring(settings.decay_mode or "exp")
    )
    love.graphics.setColor(0.7, 0.7, 1, 1)
    love.graphics.print(settings_text, ui_x, current_y)
    current_y = current_y + line_height
    current_y = current_y + 4

    -- Charge input mode
    love.graphics.setColor(1, 1, 1, 1)
    local charge_text = "Charge-After-Cancel Mode: " .. (game_manager.charge_input_mode or "press")
    love.graphics.print(charge_text, ui_x, current_y)
    current_y = current_y + line_height

    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("F3 to toggle charge mode", ui_x, current_y)
    current_y = current_y + line_height
    current_y = current_y + 4

    -- Collision stats
    love.graphics.setColor(1, 1, 0.6, 1)
    local pairs = game_manager.collision_system.debug_pairs_count or 0
    local narrow = game_manager.collision_system.debug_narrow_checks or 0
    local avgIter = game_manager.collision_system.debug_avg_iterations or 0
    local stats_text = string.format("Collisions: Pairs %d  Narrow %d  AvgIter %.2f", pairs, narrow, avgIter)
    love.graphics.print(stats_text, ui_x, current_y)

    -- Restore graphics state
    love.graphics.pop()
end

function RenderSystem:draw_gamepad_help()
	-- Draw a small, non-intrusive gamepad help panel in the bottom-left
	love.graphics.push("all")
	love.graphics.origin()

	local padding = 6
	local margin = 10
	local lines = {
		"GAMEPAD CONTROLS",
		"Left Stick: Move",
		"Right Stick X: Rotate",
		"D-Pad: Move (discrete)",
		"Right Shoulder: Charge",
		"Left Shoulder: Cancel Charge",
	}

	local font = love.graphics.getFont()
	local line_height = font:getHeight() + 4

	local max_width = 0
	for _, text in ipairs(lines) do
		local w = font:getWidth(text)
		if w > max_width then
			max_width = w
		end
	end

	local panel_w = max_width + padding * 2
	local panel_h = line_height * #lines + padding * 2
	local ui_x = margin
	local ui_y = love.graphics.getHeight() - panel_h - margin

	-- Background
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", ui_x, ui_y, panel_w, panel_h)

	-- Text
	local y = ui_y + padding
	for i, text in ipairs(lines) do
		if i == 1 then
			love.graphics.setColor(1, 1, 1, 1)
		else
			love.graphics.setColor(0.9, 0.9, 0.9, 1)
		end
		love.graphics.print(text, ui_x + padding, y)
		y = y + line_height
	end

	love.graphics.pop()
end

return RenderSystem
