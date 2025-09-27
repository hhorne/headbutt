-- Game Manager - Pure component-based game management
-- Replaces the old main.lua logic with clean component system

local component_system = require("util.component_system")
local entity_factory = require("util.entity_factory")

-- Import systems
local MovementSystem = require("systems.movement_system")
local AnimationSystem = require("systems.animation_system")
local RenderSystem = require("systems.render_system")
local CollisionSystem = require("systems.collision_system")
local PhysicsSystem = require("systems.physics_system")

-- Import utilities
local DebugRenderer = require("util.debug_renderer")
local ErrorUtils = require("util.error_handler")

-- Import components for type registration
require("components.transform_component")
require("components.movement_component")
require("components.animation_component")
require("components.render_component")
require("components.physics_component")
require("components.player_controller_component")

local GameManager = {}
GameManager.__index = GameManager

function GameManager.new()
    local self = setmetatable({}, GameManager)

    -- Create component manager
    self.component_manager = component_system.EntityComponentManager.new()

    -- Game state
    self.entities = {}
    self.debug_mode = false
    self.current_knockback_preset = "STRONG"
    self.charge_input_mode = "press"

	-- Apply selected knockback preset at startup
	require("config.knockback_config").apply_preset(self.current_knockback_preset)

    -- Create systems
    self.movement_system = MovementSystem.new(self.component_manager)
    self.animation_system = AnimationSystem.new(self.component_manager)
    self.render_system = RenderSystem.new(self.component_manager)
    self.collision_system = CollisionSystem.new(self.component_manager)
    self.physics_system = PhysicsSystem.new(self.component_manager)

    -- Initialize debug renderer
    self.debug_renderer = DebugRenderer.new()
    self.debug_renderer:create_layer("collision", true, 1, false)
    self.debug_renderer:create_layer("movement", true, 2, false)
    self.debug_renderer:create_layer("physics", true, 3, false)
    self.debug_renderer:create_layer("debug", true, 4, false)  -- General debug visuals
    self.debug_renderer:create_layer("ui", true, 10, true) -- UI layer with highest priority

    -- Print initial knockback preset info with error handling
    local success, knockback_config = ErrorUtils.safe_call(
        function() return require("config.knockback_config") end,
        "Failed to load knockback config",
        "GameManager.new"
    )

    if success then
        print("Game initialized with knockback preset: " .. self.current_knockback_preset)
        local settings = knockback_config.get_current_settings()
        print(string.format("  Settings - Speed:%d Duration:%.2f Curve:%.1f Decay:%.1f",
              settings.base_speed, settings.duration, settings.curve_power, settings.decay_rate))
        print("  Press F1 for debug mode, F2 to cycle presets")
    else
        ErrorUtils.log_error("Could not display initial knockback settings", ErrorUtils.Severity.WARNING, "GameManager.new")
    end

    return self
end

function GameManager:create_player_dude(x, y, facing, body_color, head_color, player_number)
    local config = {
        x = x,
        y = y,
        facing = facing,
        body_color = body_color or {0, 0.5, 1, 1},
        head_color = head_color or {1.0, 0.85, 0.73, 1},
        layer = 1, -- Player entities on top
        player_number = player_number or 1,
        input_type = player_number == 2 and "gamepad" or "keyboard"
    }

    local entity_id = entity_factory.create_player_dude(self.component_manager, config)
    table.insert(self.entities, entity_id)
    return entity_id
end

function GameManager:create_ai_dude(x, y, facing, body_color, head_color)
    local config = {
        x = x,
        y = y,
        facing = facing,
        body_color = body_color or {1, 0, 0, 1},
        head_color = head_color or {1.0, 0.85, 0.73, 1},
        layer = 0 -- AI entities behind player
    }

    local entity_id = entity_factory.create_dude(self.component_manager, config)
    table.insert(self.entities, entity_id)
    return entity_id
end

function GameManager:update(dt, player_input)
    -- Process inputs for player-controlled entities
    if player_input then
        local is_array = type(player_input) == "table" and player_input[1] ~= nil
        if is_array then
            -- Map by PlayerController.player_number
            local players = self.component_manager:get_entities_with_component("PlayerController")
            for _, entity_id in ipairs(players) do
                local pc = self.component_manager:get_component(entity_id, "PlayerController")
                local input = player_input[pc.player_number]
                if input then
                    input.chargeInputMode = self.charge_input_mode
                    self.movement_system:process_input(entity_id, input, dt)
                    self.animation_system:process_input(entity_id, input)
                    self.animation_system:apply_movement_speed_modifier(entity_id)
                end
            end
        else
            -- Back-compat: apply to first entity
            if #self.entities > 0 then
                player_input.chargeInputMode = self.charge_input_mode
                local player_entity = self.entities[1]
                self.movement_system:process_input(player_entity, player_input, dt)
                self.animation_system:process_input(player_entity, player_input)
                self.animation_system:apply_movement_speed_modifier(player_entity)
            end
        end
    end

    -- Update all systems for all entities in proper order
    self.animation_system:update(dt)      -- Update animations first
    self.movement_system:update(dt)       -- Apply movement
    self.physics_system:update(dt)        -- Apply physics forces
    self.collision_system:update(dt)      -- Handle collisions and knockback

    -- Update debug renderer
    if self.debug_mode then
        self.debug_renderer:update(dt)
        self:update_debug_visualization()
    end
end


function GameManager:draw()
    self.render_system:draw_all_entities(self.debug_mode and "all" or false, self)

    -- Draw debug visualization
    if self.debug_mode then
        self.debug_renderer:set_enabled(true)
        self.debug_renderer:render()
    else
        self.debug_renderer:set_enabled(false)
    end
end

function GameManager:update_debug_visualization()
    -- Clear non-persistent debug layers
    self.debug_renderer:clear("collision")
    self.debug_renderer:clear("movement")
    self.debug_renderer:clear("physics")
    self.debug_renderer:clear("debug")
    -- Explicitly clear UI layer since it's persistent by design
    self.debug_renderer:clear("ui")

    -- Draw collision shapes for all entities
    for _, entity_id in ipairs(self.entities) do
        self:debug_draw_entity_collision(entity_id)
        self:debug_draw_entity_movement(entity_id)
        self:debug_draw_entity_physics(entity_id)
    end

    -- Draw contact normals (arrows) and stats
    if self.collision_system.debug_contacts then
        for _, c in ipairs(self.collision_system.debug_contacts) do
            local scale = 18
            self.debug_renderer:draw_arrow(c.x, c.y, c.x + c.nx * scale, c.y + c.ny * scale, 6, "orange", "collision")
        end
    end

    -- Stats moved into RenderSystem debug UI
end

function GameManager:debug_draw_entity_collision(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local render = self.component_manager:get_component(entity_id, "Render")
    local animation = self.component_manager:get_component(entity_id, "Animation")

    if not transform or not render then
        return
    end

    -- Draw composite body (central OBB + shoulder circles)
    local body = self.collision_system:get_entity_body(entity_id)
    if body then
        -- Draw central OBB
        self.debug_renderer:draw_obb(body.central_obb, "line", "green", "collision")

        -- Draw shoulder circles
        self.debug_renderer:draw_circle(
            body.left_shoulder.center.x, body.left_shoulder.center.y,
            body.left_shoulder.radius,
            "line", "green", "collision"
        )
        self.debug_renderer:draw_circle(
            body.right_shoulder.center.x, body.right_shoulder.center.y,
            body.right_shoulder.radius,
            "line", "green", "collision"
        )

        -- Draw optional corner circles (rounded-rect corners)
        if body.corner_circles then
            for _, c in ipairs(body.corner_circles) do
                self.debug_renderer:draw_circle(c.center.x, c.center.y, c.radius, "line", "light_gray", "collision")
            end
        end
    end

    -- Draw head circle
    local head_circle = self.collision_system:get_entity_head_circle(entity_id)
    if head_circle then
        self.debug_renderer:draw_circle(
            head_circle.center.x, head_circle.center.y, head_circle.radius,
            "line", "yellow", "collision"
        )
    end

    -- Draw AABB for spatial partitioning
    local aabb = self.collision_system:get_entity_aabb(entity_id)
    if aabb then
        self.debug_renderer:draw_rect(
            aabb.min.x, aabb.min.y,
            aabb.max.x - aabb.min.x, aabb.max.y - aabb.min.y,
            "line", "transparent_blue", "collision"
        )
    end

    -- Stun overlay (debug only): draw a semi-transparent red fill over body when stunned
    if animation and animation.is_stunned and animation:is_stunned() then
        local body = self.collision_system:get_entity_body(entity_id)
        if body and body.central_obb then
            self.debug_renderer:draw_obb(body.central_obb, "fill", {1, 0, 0, 0.35}, "debug")
        end
    end
end

function GameManager:debug_draw_entity_movement(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local movement = self.component_manager:get_component(entity_id, "Movement")

    if not transform or not movement then
        return
    end

    -- Draw velocity vector
    local velocity = movement:get_velocity()
    if velocity and (velocity.x ~= 0 or velocity.y ~= 0) then
        self.debug_renderer:draw_vector(
            transform.x, transform.y,
            velocity.x, velocity.y,
            0.1, -- Scale down for visibility
            "cyan", "movement"
        )
    end

end

function GameManager:debug_draw_entity_physics(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local physics = self.component_manager:get_component(entity_id, "Physics")

    if not transform or not physics then
        return
    end

    -- Draw physics velocity
    local physics_velocity = physics:get_physics_velocity()
    if physics_velocity and not physics_velocity:is_zero() then
        self.debug_renderer:draw_vector(
            transform.x, transform.y,
            physics_velocity.x, physics_velocity.y,
            0.05, -- Scale down for visibility
            "red", "physics"
        )

        -- Draw physics velocity magnitude as text
        local magnitude = physics_velocity:magnitude()
        if magnitude > 1 then
            self.debug_renderer:draw_text(
                string.format("%.0f", magnitude),
                transform.x + 20, transform.y - 20,
                "red", "physics"
            )
        end
    end
end

function GameManager:toggle_debug_mode()
    self.debug_mode = not self.debug_mode
    if self.debug_mode then
        print("Debug mode enabled")
        print("  F1: Toggle debug mode")
        print("  F2: Cycle knockback presets")
        print("  F3: Toggle charge input mode (press/hold)")
    else
        print("Debug mode disabled")
    end
end

function GameManager:cycle_knockback_preset()
    local knockback_config = require("config.knockback_config")
    local presets = {"GENTLE", "BALANCED", "STRONG", "LEGACY"}

    -- Find current preset index
    local current_index = 1
    for i, preset in ipairs(presets) do
        if preset == self.current_knockback_preset then
            current_index = i
            break
        end
    end

    -- Cycle to next preset
    local next_index = (current_index % #presets) + 1
    self.current_knockback_preset = presets[next_index]

    -- Apply the preset
    knockback_config.apply_preset(self.current_knockback_preset)

    print("Knockback preset changed to: " .. self.current_knockback_preset)
    local settings = knockback_config.get_current_settings()
    print(string.format("  Base Speed: %d, Duration: %.2f, Curve: %.2f, Decay: %.1f",
          settings.base_speed, settings.duration, settings.curve_power, settings.decay_rate))
end

function GameManager:toggle_charge_input_mode()
    self.charge_input_mode = (self.charge_input_mode == "press") and "hold" or "press"
    print("Charge input mode: " .. self.charge_input_mode)
end

function GameManager:get_component_manager()
    return self.component_manager
end

function GameManager:get_entities()
    return self.entities
end

function GameManager:cleanup()
    for _, entity_id in ipairs(self.entities) do
        self.component_manager:destroy_entity(entity_id)
    end
    self.entities = {}
end

return GameManager
