-- Collision System - Pure component-based collision detection and response

local component_system = require("util.component_system")
local Vector2 = require("util.vector2")
local bit = require("bit")
local movement_config = require("config.movement_config")
local knockback_config = require("config.knockback_config")
local collision_config = require("config.collision_config")
local collision_utils = require("util.collision")
local SpatialHash = require("util.spatial_hash")

local CollisionSystem = {}
CollisionSystem.__index = CollisionSystem
setmetatable(CollisionSystem, {__index = component_system.System})

function CollisionSystem.new(component_manager)
    local self = setmetatable(component_system.System.new(component_manager), CollisionSystem)

    -- Track headbutt hits per entity to prevent multiple hits per attack
    self.headbutt_hits = {}

    -- Initialize spatial hash for broad-phase collision detection
    self.spatial_hash = SpatialHash.new(128) -- 128 pixel cells

    -- Debug settings
    self.debug_draw_spatial_hash = false
    self.debug_draw_collision_shapes = false

    -- Gentle push cooldown tracking per pair
    self.last_pair_push_time = {}
    self.push_cooldown = 0.08

    -- One-time debug log to confirm active knockback settings on first actual headbutt hit
    self._logged_knockback_settings = false

    return self
end

function CollisionSystem:get_required_components()
    return {"Transform", "Render", "Physics"}
end

-- Advanced collision detection using OBB and proper collision utilities
function CollisionSystem:get_entity_body(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local render = self.component_manager:get_component(entity_id, "Render")

    if not transform or not render then
        return nil
    end

    return collision_utils.create_entity_body_composite(transform, render)
end

function CollisionSystem:get_entity_head_circle(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    local render = self.component_manager:get_component(entity_id, "Render")
    local animation = self.component_manager:get_component(entity_id, "Animation")

    if not transform or not render then
        return nil
    end

    return collision_utils.create_entity_head_circle(transform, render, animation)
end

function CollisionSystem:check_entity_collision(entity1_id, entity2_id)
    local body1 = self:get_entity_body(entity1_id)
    local body2 = self:get_entity_body(entity2_id)

    if not body1 or not body2 then
        return false, false, nil, nil
    end

    -- Use composite body collision detection (central rect + shoulder circles)
    local bodyCollision, contact_point, colliding_shoulder = collision_utils.composite_vs_composite(body1, body2)

    local head1 = self:get_entity_head_circle(entity1_id)
    local head2 = self:get_entity_head_circle(entity2_id)
    local headCollision = false

    if head1 and head2 then
        headCollision = collision_utils.circle_vs_circle(head1, head2)
    end

    return bodyCollision, headCollision, contact_point, colliding_shoulder
end

-- Get AABB for spatial partitioning
function CollisionSystem:get_entity_aabb(entity_id)
    local body = self:get_entity_body(entity_id)
    local head_circle = self:get_entity_head_circle(entity_id)

    if not body then
        return nil
    end

    local body_aabb = collision_utils.composite_to_aabb(body)

    -- Expand AABB to include head if present
    if head_circle then
        local head_aabb = collision_utils.circle_to_aabb(head_circle)
        -- Combine AABBs
        body_aabb.min.x = math.min(body_aabb.min.x, head_aabb.min.x)
        body_aabb.min.y = math.min(body_aabb.min.y, head_aabb.min.y)
        body_aabb.max.x = math.max(body_aabb.max.x, head_aabb.max.x)
        body_aabb.max.y = math.max(body_aabb.max.y, head_aabb.max.y)
    end

    return body_aabb
end

function CollisionSystem:check_headbutt_collision(attacker_id, target_id)
    local attacker_animation = self.component_manager:get_component(attacker_id, "Animation")
    local target_animation = self.component_manager:get_component(target_id, "Animation")

    -- Only check for headbutt collision if attacker is in snapping phase
    if not attacker_animation or attacker_animation:get_current_state() ~= 'snapping' then
        return false, 0
    end

    -- Respect i-frames on the target: if invincible, treat as no hit
    if target_animation and target_animation.is_invincible and target_animation:is_invincible() then
        return false, 0
    end

    local attackerHead = self:get_entity_head_circle(attacker_id)
    local targetBody = self:get_entity_body(target_id)
    local targetHead = self:get_entity_head_circle(target_id)

    if not attackerHead or not targetBody then
        return false, 0
    end

    -- Front-only guard: require target to be in front of attacker
    do
        local attacker_transform = self.component_manager:get_component(attacker_id, "Transform")
        local target_transform = self.component_manager:get_component(target_id, "Transform")
        if attacker_transform and target_transform then
            local angle = math.rad(attacker_transform:get_facing())
            -- Forward vector in screen space (0° = up): (sin(a), -cos(a))
            local fx = math.sin(angle)
            local fy = -math.cos(angle)
            -- Use head position for a more accurate directional test
            local hx = attackerHead.center.x
            local hy = attackerHead.center.y
            local dx = target_transform.x - hx
            local dy = target_transform.y - hy
            local dot = dx * fx + dy * fy
            if dot <= 0 then
                return false, 0
            end
        end
    end

    -- Check if attacker's head hits target's body (circle vs composite)
    local hitsBody = collision_utils.circle_vs_obb(attackerHead, targetBody.central_obb) or
                    collision_utils.circle_vs_circle(attackerHead, targetBody.left_shoulder) or
                    collision_utils.circle_vs_circle(attackerHead, targetBody.right_shoulder)

    -- Check if attacker's head hits target's head (circle vs circle)
    local hitsHead = targetHead and collision_utils.circle_vs_circle(attackerHead, targetHead) or false

    if hitsBody or hitsHead then
        -- Calculate knockback force based on charge using config
        local snapProgress = attacker_animation.head_state_machine.state_time / knockback_config.CHARGE.SNAP_FORWARD_DURATION
        local estimatedOriginalCharge = knockback_config.estimate_original_charge(attacker_animation.charge, snapProgress)

        -- Apply knockback curve using config
        local knockbackForce = knockback_config.calculate_force_multiplier(estimatedOriginalCharge)

        return true, knockbackForce
    end

    return false, 0
end

function CollisionSystem:process_entity(entity_id, dt)
    -- Store previous state for collision detection
    local transform = self.component_manager:get_component(entity_id, "Transform")
    if transform then
        transform:store_previous_state()
    end
end

function CollisionSystem:update(dt)
    local entities = self.component_manager:get_entities_with_components(self:get_required_components())

    -- Cache bodies and AABBs for this frame
    local body_cache = {}
    local aabb_cache = {}
    local physics_cache = {}
    local movement_cache = {}
    local transform_cache = {}

    -- Update spatial hash with current entity positions
    self.spatial_hash:clear()
    for _, entity_id in ipairs(entities) do
        local transform = transform_cache[entity_id] or self.component_manager:get_component(entity_id, "Transform")
        local render = self.component_manager:get_component(entity_id, "Render")
        if transform then transform_cache[entity_id] = transform end
        local body = render and collision_utils.create_entity_body_composite(transform, render) or nil
        body_cache[entity_id] = body

        local head_circle = render and collision_utils.create_entity_head_circle(transform, render, self.component_manager:get_component(entity_id, "Animation")) or nil
        local aabb = nil
        if body then
            aabb = collision_utils.composite_to_aabb(body)
            if head_circle then
                local head_aabb = collision_utils.circle_to_aabb(head_circle)
                aabb.min.x = math.min(aabb.min.x, head_aabb.min.x)
                aabb.min.y = math.min(aabb.min.y, head_aabb.min.y)
                aabb.max.x = math.max(aabb.max.x, head_aabb.max.x)
                aabb.max.y = math.max(aabb.max.y, head_aabb.max.y)
            end
        end
        aabb_cache[entity_id] = aabb
        if aabb then
            self.spatial_hash:add_entity(entity_id, aabb)
        end
    end

    -- Clear expired headbutt hit tracking
    for entity_id, hits in pairs(self.headbutt_hits) do
        local animation = self.component_manager:get_component(entity_id, "Animation")
        if not animation or animation:get_current_state() ~= 'snapping' then
            self.headbutt_hits[entity_id] = nil
        end
    end

    -- Process collisions using spatial partitioning for broad phase
    local processed_pairs = {}
    local contact_normals = {}
    self.debug_contacts = {}
    local narrow_checks = 0
    local iter_accum = 0
    local iter_pairs = 0

    for _, entity1_id in ipairs(entities) do
        local entity1_aabb = self:get_entity_aabb(entity1_id)
        if not entity1_aabb then
            goto continue
        end

        -- Get nearby entities using spatial hash (broad phase)
        local nearby_entities = self.spatial_hash:get_nearby_entities(entity1_id, entity1_aabb)

        -- Initialize headbutt hit tracking if needed
        local animation1 = self.component_manager:get_component(entity1_id, "Animation")
        if animation1 and animation1:get_current_state() == 'snapping' then
            if not self.headbutt_hits[entity1_id] then
                self.headbutt_hits[entity1_id] = {}
            end
        end

        for _, entity2_id in ipairs(nearby_entities) do
            -- Avoid duplicate pair checks
            local pair_key = entity1_id < entity2_id and (entity1_id .. "_" .. entity2_id) or (entity2_id .. "_" .. entity1_id)
            if processed_pairs[pair_key] then
                goto continue_inner
            end
            processed_pairs[pair_key] = true

            -- Narrow phase collision detection
            -- Mask/layer filtering (if configured)
            local phys1 = physics_cache[entity1_id] or self.component_manager:get_component(entity1_id, "Physics")
            local phys2 = physics_cache[entity2_id] or self.component_manager:get_component(entity2_id, "Physics")
            physics_cache[entity1_id] = phys1
            physics_cache[entity2_id] = phys2
            if phys1 and phys2 then
                local l1 = phys1.collision_layer or 0
                local m1 = phys1.collision_mask or 0
                local l2 = phys2.collision_layer or 0
                local m2 = phys2.collision_mask or 0
                if m1 ~= 0 and m2 ~= 0 then
                    local maskhit1 = bit.band(m1, bit.lshift(1, l2)) ~= 0
                    local maskhit2 = bit.band(m2, bit.lshift(1, l1)) ~= 0
                    if not (maskhit1 or maskhit2) then goto continue_inner end
                end
            end

            -- Narrow phase collision detection using cached bodies
            local body1 = body_cache[entity1_id]
            local body2 = body_cache[entity2_id]
            local bodyCollision, headCollision, contact_point, colliding_shoulder = false, false, nil, nil
            if body1 and body2 then
                narrow_checks = narrow_checks + 1
                bodyCollision, headCollision, contact_point, colliding_shoulder = collision_utils.composite_vs_composite(body1, body2), false, nil, nil
                local head1 = self:get_entity_head_circle(entity1_id)
                local head2 = self:get_entity_head_circle(entity2_id)
                if head1 and head2 then
                    headCollision = collision_utils.circle_vs_circle(head1, head2)
                end
            end

            if bodyCollision then
                local movement1 = movement_cache[entity1_id] or self.component_manager:get_component(entity1_id, "Movement")
                local movement2 = movement_cache[entity2_id] or self.component_manager:get_component(entity2_id, "Movement")
                movement_cache[entity1_id] = movement1
                movement_cache[entity2_id] = movement2
                local transform1 = transform_cache[entity1_id] or self.component_manager:get_component(entity1_id, "Transform")
                local transform2 = transform_cache[entity2_id] or self.component_manager:get_component(entity2_id, "Transform")
                transform_cache[entity1_id] = transform1
                transform_cache[entity2_id] = transform2

                -- Iterative soft separation using MTV to fully resolve visual overlap
                do
                    local iterations = collision_config.SOLVER_ITERATIONS or 1
                    local mover_bias = collision_config.MOVER_BIAS
                    local sep_frac = collision_config.SEPARATION_FRACTION
                    local max_sep = collision_config.MAX_SEPARATION_PER_FRAME

                    local v1 = movement1 and movement1:get_velocity() or Vector2.zero()
                    local v2 = movement2 and movement2:get_velocity() or Vector2.zero()
                    local v1_len = v1:magnitude()
                    local v2_len = v2:magnitude()

                    local bias1 = mover_bias
                    local bias2 = 1 - mover_bias
                    if v2_len > v1_len then
                        bias1, bias2 = bias2, bias1
                    end

                    local used_iterations = 0
                    for i = 1, iterations do
                        local body1 = body_cache[entity1_id]
                        local body2 = body_cache[entity2_id]
                        local mtv = collision_utils.composite_mtv(body1, body2)
                        if not mtv then break end
                        used_iterations = used_iterations + 1

                        local mtv_len = mtv:magnitude()
                        if mtv_len <= 0 then break end
                        local desired = math.max(collision_config.MIN_SEPARATION, mtv_len * sep_frac)
                        local clamped = math.min(desired, max_sep)
                        local dir = mtv:normalize()
                        contact_normals[pair_key] = dir

                        local move1 = Vector2.new(dir.x * clamped * bias1, dir.y * clamped * bias1)
                        local move2 = Vector2.new(-dir.x * clamped * bias2, -dir.y * clamped * bias2)

                        transform1:translate(move1.x, move1.y)
                        transform2:translate(move2.x, move2.y)
                        -- Update caches after movement
                        body_cache[entity1_id] = collision_utils.create_entity_body_composite(transform1, self.component_manager:get_component(entity1_id, "Render"))
                        body_cache[entity2_id] = collision_utils.create_entity_body_composite(transform2, self.component_manager:get_component(entity2_id, "Render"))
                    end
                    iter_accum = iter_accum + used_iterations
                    iter_pairs = iter_pairs + 1

                    -- Gentle push to the other dude to sell the block (with cooldown per pair)
                    local body1_final = body_cache[entity1_id]
                    local body2_final = body_cache[entity2_id]
                    local mtv_final = collision_utils.composite_mtv(body1_final, body2_final)
                    if mtv_final then
                        local dir = mtv_final:normalize()
                        contact_normals[pair_key] = dir
                        local now = love.timer.getTime()
                        local last = self.last_pair_push_time[pair_key] or 0
                        if now - last >= self.push_cooldown then
                            self.last_pair_push_time[pair_key] = now
                            local physics2 = self.component_manager:get_component(entity2_id, "Physics")
                            local physics1 = self.component_manager:get_component(entity1_id, "Physics")
                            if v1_len >= v2_len and physics2 then
                                physics2:add_knockback(dir, collision_config.GENTLE_PUSH_SPEED, collision_config.GENTLE_PUSH_DURATION)
                            elseif v2_len > v1_len and physics1 then
                                physics1:add_knockback(Vector2.new(-dir.x, -dir.y), collision_config.GENTLE_PUSH_SPEED, collision_config.GENTLE_PUSH_DURATION)
                            end
                        end

                        -- Record debug contact at midpoint
                        local c1x, c1y = transform1:get_position()
                        local c2x, c2y = transform2:get_position()
                        local mx = (c1x + c2x) * 0.5
                        local my = (c1y + c2y) * 0.5
                        table.insert(self.debug_contacts, {x = mx, y = my, nx = dir.x, ny = dir.y})
                    end

                    -- Optionally block inward velocity along the contact normal to prevent squeezing through
                    if collision_config.BLOCK_INWARD_VELOCITY then
                        local body1b = body_cache[entity1_id]
                        local body2b = body_cache[entity2_id]
                        local mtv_block = collision_utils.composite_mtv(body1b, body2b)
                        if mtv_block then
                            local n = mtv_block:normalize()
                            if movement1 then
                                local v = movement1:get_velocity()
                                local dot = v:dot(n)
                                if dot < 0 then
                                    local corrected = Vector2.new(v.x - n.x * dot, v.y - n.y * dot)
                                    movement1:set_velocity(corrected)
                                end
                            end
                            if movement2 then
                                local v = movement2:get_velocity()
                                local n2 = Vector2.new(-n.x, -n.y)
                                local dot = v:dot(n2)
                                if dot < 0 then
                                    local corrected = Vector2.new(v.x - n2.x * dot, v.y - n2.y * dot)
                                    movement2:set_velocity(corrected)
                                end
                            end

                            -- Tangential damping (reduce sliding along tangent)
                            local t = Vector2.new(-n.y, n.x)
                            local damp = collision_config.TANGENTIAL_DAMPING
                            if movement1 then
                                local v = movement1:get_velocity()
                                local vt = t:dot(v)
                                local vn = n:dot(v)
                                local v_damped = Vector2.new(n.x * vn + t.x * vt * damp, n.y * vn + t.y * vt * damp)
                                movement1:set_velocity(v_damped)
                            end
                            if movement2 then
                                local v = movement2:get_velocity()
                                local t2 = Vector2.new(n.y, -n.x)
                                local vt = t2:dot(v)
                                local vn = (-n.x) * v.x + (-n.y) * v.y
                                local v_damped = Vector2.new((-n.x) * vn + t2.x * vt * damp, (-n.y) * vn + t2.y * vt * damp)
                                movement2:set_velocity(v_damped)
                            end

                            -- Also block physics velocity along normal to prevent tunneling
                            local phys1 = physics_cache[entity1_id]
                            local phys2 = physics_cache[entity2_id]
                            if phys1 then
                                local pv = phys1:get_physics_velocity()
                                local dot = pv:dot(n)
                                if dot < 0 then
                                    phys1:set_physics_velocity(Vector2.new(pv.x - n.x * dot, pv.y - n.y * dot))
                                end
                            end
                            if phys2 then
                                local pv = phys2:get_physics_velocity()
                                local n2 = Vector2.new(-n.x, -n.y)
                                local dot = pv:dot(n2)
                                if dot < 0 then
                                    phys2:set_physics_velocity(Vector2.new(pv.x - n2.x * dot, pv.y - n2.y * dot))
                                end
                            end
                        end
                    end
                end

                -- Handle shoulder pivot blocking for rotation
                if contact_point and colliding_shoulder then
                    if movement1 and movement1:get_angular_velocity() ~= 0 then
                        local orig_x, orig_y = transform1:get_position()
                        local orig_facing = transform1:get_facing()
                        transform1:set_position(orig_x, orig_y)
                        local angular_velocity = movement1:get_angular_velocity()
                        local rotation_dir = angular_velocity > 0 and 1 or -1
                        if (colliding_shoulder == "left" and rotation_dir > 0) or
                           (colliding_shoulder == "right" and rotation_dir < 0) then
                            transform1:set_facing(orig_facing)
                            movement1:set_angular_velocity(0)
                        end
                    end
                end
            end

            -- Check headbutt collisions (entity1 attacking entity2)
            if animation1 and animation1:get_current_state() == 'snapping' then
                if not self.headbutt_hits[entity1_id][entity2_id] then
                    local hit, force = self:check_headbutt_collision(entity1_id, entity2_id)
                    if hit then
                        self.headbutt_hits[entity1_id][entity2_id] = true
                        self:apply_knockback(entity1_id, entity2_id, force)
                        -- Apply debug stun to valid target hits (respect i-frames via check_headbutt_collision)
                        local target_anim = self.component_manager:get_component(entity2_id, "Animation")
                        if target_anim and target_anim.add_debug_stun then
                            local stun_config = require("config.stun_config")
                            target_anim:add_debug_stun(stun_config.DURATION)
                        end
                        -- Also stun the attacker if not in i-frames
                        local attacker_anim = self.component_manager:get_component(entity1_id, "Animation")
                        if attacker_anim and attacker_anim.add_debug_stun then
                            local stun_config = require("config.stun_config")
                            attacker_anim:add_debug_stun(stun_config.DURATION)
                        end
                    end
                end
            end

            -- Check headbutt collisions (entity2 attacking entity1)
            local animation2 = self.component_manager:get_component(entity2_id, "Animation")
            if animation2 and animation2:get_current_state() == 'snapping' then
                if not self.headbutt_hits[entity2_id] then
                    self.headbutt_hits[entity2_id] = {}
                end
                if not self.headbutt_hits[entity2_id][entity1_id] then
                    local hit, force = self:check_headbutt_collision(entity2_id, entity1_id)
                    if hit then
                        self.headbutt_hits[entity2_id][entity1_id] = true
                        self:apply_knockback(entity2_id, entity1_id, force)
                        local target_anim = self.component_manager:get_component(entity1_id, "Animation")
                        if target_anim and target_anim.add_debug_stun then
                            local stun_config = require("config.stun_config")
                            target_anim:add_debug_stun(stun_config.DURATION)
                        end
                        -- Also stun the attacker if not in i-frames
                        local attacker_anim = self.component_manager:get_component(entity2_id, "Animation")
                        if attacker_anim and attacker_anim.add_debug_stun then
                            local stun_config = require("config.stun_config")
                            attacker_anim:add_debug_stun(stun_config.DURATION)
                        end
                    end
                end
            end

            ::continue_inner::
        end

        ::continue::
    end
    -- Expose debug stats
    -- Expose debug stats
    local pair_count = 0
    for _ in pairs(processed_pairs) do
        pair_count = pair_count + 1
    end
    self.debug_pairs_count = pair_count
    self.debug_narrow_checks = narrow_checks
    if iter_pairs > 0 then
        self.debug_avg_iterations = iter_accum / iter_pairs
    else
        self.debug_avg_iterations = 0
    end
end

function CollisionSystem:handle_collision_rollback(entity_id)
    local transform = self.component_manager:get_component(entity_id, "Transform")
    if transform then
        transform:restore_previous_state()
    end
end

function CollisionSystem:apply_knockback(attacker_id, target_id, force)
    local attacker_transform = self.component_manager:get_component(attacker_id, "Transform")
    local target_transform = self.component_manager:get_component(target_id, "Transform")
    local target_physics = self.component_manager:get_component(target_id, "Physics")

    if not attacker_transform or not target_transform or not target_physics then
        return
    end

    -- Calculate knockback direction
    local dx = target_transform.x - attacker_transform.x
    local dy = target_transform.y - attacker_transform.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance == 0 then
        -- Random direction if entities are on top of each other
        dx = math.random() - 0.5
        dy = math.random() - 0.5
        distance = math.sqrt(dx * dx + dy * dy)
    end

    -- Normalize direction
    local direction = Vector2.new(dx / distance, dy / distance)

    -- Apply knockback using config
    if not self._logged_knockback_settings then
        local settings = require("config.knockback_config").get_current_settings()
        print(string.format(
            "Applying knockback: Speed %d  Dur %.2f  Curve %.2f  Decay %.1f (%s)",
            settings.base_speed, settings.duration, settings.curve_power, settings.decay_rate, tostring(settings.decay_mode or "exp")
        ))
        self._logged_knockback_settings = true
    end
    target_physics:add_knockback(direction, knockback_config.BASE_SPEED * force, knockback_config.DURATION)
end

return CollisionSystem
