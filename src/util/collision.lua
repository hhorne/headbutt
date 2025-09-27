-- Advanced Collision Detection Utilities
-- Implements OBB (Oriented Bounding Box) and SAT (Separating Axis Theorem) collision detection

local Vector2 = require("util.vector2")
local collision_config = require("config.collision_config")

local Collision = {}

-- OBB (Oriented Bounding Box) structure
-- {center: Vector2, half_extents: Vector2, rotation: number}
function Collision.create_obb(center_x, center_y, width, height, rotation)
    return {
        center = Vector2.new(center_x, center_y),
        half_extents = Vector2.new(width / 2, height / 2),
        rotation = rotation or 0
    }
end

-- Get the four corners of an OBB in world space
function Collision.get_obb_corners(obb)
    local cos_rot = math.cos(obb.rotation)
    local sin_rot = math.sin(obb.rotation)

    -- Local corner offsets
    local corners = {
        Vector2.new(-obb.half_extents.x, -obb.half_extents.y),
        Vector2.new(obb.half_extents.x, -obb.half_extents.y),
        Vector2.new(obb.half_extents.x, obb.half_extents.y),
        Vector2.new(-obb.half_extents.x, obb.half_extents.y)
    }

    -- Transform to world space
    local world_corners = {}
    for i, corner in ipairs(corners) do
        local rotated_x = corner.x * cos_rot - corner.y * sin_rot
        local rotated_y = corner.x * sin_rot + corner.y * cos_rot
        world_corners[i] = Vector2.new(
            obb.center.x + rotated_x,
            obb.center.y + rotated_y
        )
    end

    return world_corners
end

-- Get the axes for SAT collision detection (normals to the edges)
function Collision.get_obb_axes(obb)
    local cos_rot = math.cos(obb.rotation)
    local sin_rot = math.sin(obb.rotation)

    return {
        Vector2.new(cos_rot, sin_rot),      -- Right vector
        Vector2.new(-sin_rot, cos_rot)      -- Up vector
    }
end

-- Project an OBB onto an axis and return the min/max projection values
function Collision.project_obb_onto_axis(obb, axis)
    local corners = Collision.get_obb_corners(obb)

    local min_proj = corners[1]:dot(axis)
    local max_proj = min_proj

    for i = 2, #corners do
        local proj = corners[i]:dot(axis)
        min_proj = math.min(min_proj, proj)
        max_proj = math.max(max_proj, proj)
    end

    return min_proj, max_proj
end

-- Check if two projection ranges overlap
function Collision.projections_overlap(min1, max1, min2, max2)
    return not (max1 < min2 or max2 < min1)
end

-- SAT-based OBB vs OBB collision detection
function Collision.obb_vs_obb(obb1, obb2)
    -- Get all potential separating axes (normals to edges of both OBBs)
    local axes1 = Collision.get_obb_axes(obb1)
    local axes2 = Collision.get_obb_axes(obb2)

    -- Test all axes
    local all_axes = {}
    for _, axis in ipairs(axes1) do
        table.insert(all_axes, axis)
    end
    for _, axis in ipairs(axes2) do
        table.insert(all_axes, axis)
    end

    -- For each axis, project both OBBs and check for separation
    for _, axis in ipairs(all_axes) do
        local min1, max1 = Collision.project_obb_onto_axis(obb1, axis)
        local min2, max2 = Collision.project_obb_onto_axis(obb2, axis)

        -- If projections don't overlap on this axis, objects are separated
        if not Collision.projections_overlap(min1, max1, min2, max2) then
            return false -- No collision
        end
    end

    return true -- Collision detected
end

-- SAT-based OBB vs OBB MTV (minimum translation vector) calculation
-- Returns a world-space Vector2 MTV that moves obb1 out of obb2, or nil if not colliding
function Collision.obb_mtv(obb1, obb2)
    -- Get all potential separating axes (normals to edges of both OBBs)
    local axes1 = Collision.get_obb_axes(obb1)
    local axes2 = Collision.get_obb_axes(obb2)

    local smallest_overlap = math.huge
    local smallest_axis = nil

    -- Center delta to determine MTV direction
    local center_delta = obb2.center - obb1.center

    local function test_axis(axis)
        -- Normalize axis
        local axis_len = math.sqrt(axis.x * axis.x + axis.y * axis.y)
        if axis_len == 0 then return end
        local nx = axis.x / axis_len
        local ny = axis.y / axis_len
        local n = Vector2.new(nx, ny)

        local min1, max1 = Collision.project_obb_onto_axis(obb1, n)
        local min2, max2 = Collision.project_obb_onto_axis(obb2, n)

        if max1 < min2 or max2 < min1 then
            -- Separated on this axis
            return false, 0, n
        end

        local overlap = math.min(max1, max2) - math.max(min1, min2)
        if overlap < smallest_overlap then
            smallest_overlap = overlap
            smallest_axis = n
        end

        return true, overlap, n
    end

    -- Test axes; if any axis doesn't overlap, no collision
    for _, axis in ipairs(axes1) do
        local ok = test_axis(axis)
        if ok == false then return nil end
    end
    for _, axis in ipairs(axes2) do
        local ok = test_axis(axis)
        if ok == false then return nil end
    end

    if not smallest_axis or smallest_overlap == math.huge then
        return nil
    end

    -- Direction: ensure MTV moves obb1 away from obb2
    local dot = center_delta:dot(smallest_axis)
    local direction = dot > 0 and Vector2.new(-smallest_axis.x, -smallest_axis.y) or smallest_axis
    return Vector2.new(direction.x * smallest_overlap, direction.y * smallest_overlap)
end

-- Circle structure
-- {center: Vector2, radius: number}
function Collision.create_circle(center_x, center_y, radius)
    return {
        center = Vector2.new(center_x, center_y),
        radius = radius
    }
end

-- Circle vs Circle collision detection
function Collision.circle_vs_circle(circle1, circle2)
    local distance = circle1.center:distance_to(circle2.center)
    return distance < (circle1.radius + circle2.radius)
end

-- Circle vs Circle MTV (moves circle1 out of circle2)
function Collision.circle_circle_mtv(circle1, circle2)
    local dx = circle1.center.x - circle2.center.x
    local dy = circle1.center.y - circle2.center.y
    local dist_sq = dx * dx + dy * dy
    local radii = circle1.radius + circle2.radius
    if dist_sq <= 0 then
        -- Same center; pick arbitrary axis
        return Vector2.new(radii, 0)
    end
    local dist = math.sqrt(dist_sq)
    if dist >= radii then
        return nil
    end
    local overlap = radii - dist
    local nx = dx / dist
    local ny = dy / dist
    return Vector2.new(nx * overlap, ny * overlap)
end

-- Circle vs OBB collision detection
function Collision.circle_vs_obb(circle, obb)
    -- Transform circle center to OBB's local space
    local local_circle_center = circle.center - obb.center
    local cos_rot = math.cos(-obb.rotation)
    local sin_rot = math.sin(-obb.rotation)

    local local_x = local_circle_center.x * cos_rot - local_circle_center.y * sin_rot
    local local_y = local_circle_center.x * sin_rot + local_circle_center.y * cos_rot

    -- Find closest point on OBB to circle center (in local space)
    local closest_x = math.max(-obb.half_extents.x, math.min(local_x, obb.half_extents.x))
    local closest_y = math.max(-obb.half_extents.y, math.min(local_y, obb.half_extents.y))

    -- Calculate distance from circle center to closest point
    local dx = local_x - closest_x
    local dy = local_y - closest_y
    local distance_squared = dx * dx + dy * dy

    return distance_squared < (circle.radius * circle.radius)
end

-- Circle vs OBB MTV (moves circle out of obb)
function Collision.circle_obb_mtv(circle, obb)
    -- Transform circle center to OBB's local space
    local local_circle_center = circle.center - obb.center
    local cos_rot = math.cos(-obb.rotation)
    local sin_rot = math.sin(-obb.rotation)

    local local_x = local_circle_center.x * cos_rot - local_circle_center.y * sin_rot
    local local_y = local_circle_center.x * sin_rot + local_circle_center.y * cos_rot

    -- Find closest point on OBB to circle center (in local space)
    local closest_x = math.max(-obb.half_extents.x, math.min(local_x, obb.half_extents.x))
    local closest_y = math.max(-obb.half_extents.y, math.min(local_y, obb.half_extents.y))

    local dx = local_x - closest_x
    local dy = local_y - closest_y
    local dist_sq = dx * dx + dy * dy

    -- Not intersecting
    if dist_sq >= (circle.radius * circle.radius) then
        return nil
    end

    local dist = math.sqrt(math.max(dist_sq, 1e-6))
    local overlap = circle.radius - dist

    -- If center is exactly on closest point, pick axis toward greatest penetration
    local nx, ny
    if dist < 1e-6 then
        local to_edge_x = (math.abs(local_x) - obb.half_extents.x)
        local to_edge_y = (math.abs(local_y) - obb.half_extents.y)
        if math.abs(to_edge_x) > math.abs(to_edge_y) then
            nx = local_x >= 0 and 1 or -1
            ny = 0
        else
            nx = 0
            ny = local_y >= 0 and 1 or -1
        end
    else
        nx = dx / dist
        ny = dy / dist
    end

    -- Rotate direction back to world space
    local cos_r = math.cos(obb.rotation)
    local sin_r = math.sin(obb.rotation)
    local world_nx = nx * cos_r - ny * sin_r
    local world_ny = nx * sin_r + ny * cos_r

    return Vector2.new(world_nx * overlap, world_ny * overlap)
end

-- AABB (Axis-Aligned Bounding Box) structure for spatial partitioning
-- {min: Vector2, max: Vector2}
function Collision.create_aabb(min_x, min_y, max_x, max_y)
    return {
        min = Vector2.new(min_x, min_y),
        max = Vector2.new(max_x, max_y)
    }
end

-- Get AABB from OBB (bounding box of the oriented box)
function Collision.obb_to_aabb(obb)
    local corners = Collision.get_obb_corners(obb)

    local min_x = corners[1].x
    local max_x = corners[1].x
    local min_y = corners[1].y
    local max_y = corners[1].y

    for i = 2, #corners do
        min_x = math.min(min_x, corners[i].x)
        max_x = math.max(max_x, corners[i].x)
        min_y = math.min(min_y, corners[i].y)
        max_y = math.max(max_y, corners[i].y)
    end

    return Collision.create_aabb(min_x, min_y, max_x, max_y)
end

-- Get AABB from composite body
function Collision.composite_to_aabb(composite_body)
    -- Get AABB of central OBB
    local central_aabb = Collision.obb_to_aabb(composite_body.central_obb)

    -- Get AABBs of shoulder circles
    local left_aabb = Collision.circle_to_aabb(composite_body.left_shoulder)
    local right_aabb = Collision.circle_to_aabb(composite_body.right_shoulder)

    local min_x = math.min(central_aabb.min.x, left_aabb.min.x, right_aabb.min.x)
    local min_y = math.min(central_aabb.min.y, left_aabb.min.y, right_aabb.min.y)
    local max_x = math.max(central_aabb.max.x, left_aabb.max.x, right_aabb.max.x)
    local max_y = math.max(central_aabb.max.y, left_aabb.max.y, right_aabb.max.y)

    if composite_body.corner_circles then
        for _, c in ipairs(composite_body.corner_circles) do
            local ca = Collision.circle_to_aabb(c)
            min_x = math.min(min_x, ca.min.x)
            min_y = math.min(min_y, ca.min.y)
            max_x = math.max(max_x, ca.max.x)
            max_y = math.max(max_y, ca.max.y)
        end
    end

    return Collision.create_aabb(min_x, min_y, max_x, max_y)
end

-- Get AABB from Circle
function Collision.circle_to_aabb(circle)
    return Collision.create_aabb(
        circle.center.x - circle.radius,
        circle.center.y - circle.radius,
        circle.center.x + circle.radius,
        circle.center.y + circle.radius
    )
end

-- AABB vs AABB collision detection (for broad phase)
function Collision.aabb_vs_aabb(aabb1, aabb2)
    return not (aabb1.max.x < aabb2.min.x or aabb2.max.x < aabb1.min.x or
                aabb1.max.y < aabb2.min.y or aabb2.max.y < aabb1.min.y)
end

-- Check if a point is inside an AABB
function Collision.point_in_aabb(point, aabb)
    return point.x >= aabb.min.x and point.x <= aabb.max.x and
           point.y >= aabb.min.y and point.y <= aabb.max.y
end

-- Expand an AABB by a margin
function Collision.expand_aabb(aabb, margin)
    return Collision.create_aabb(
        aabb.min.x - margin,
        aabb.min.y - margin,
        aabb.max.x + margin,
        aabb.max.y + margin
    )
end

-- Get the area of an AABB
function Collision.aabb_area(aabb)
    local width = aabb.max.x - aabb.min.x
    local height = aabb.max.y - aabb.min.y
    return width * height
end

-- Composite body collision shape (central rectangle + shoulder circles)
function Collision.create_composite_body(center_x, center_y, width, height, rotation)
    local min_dim = math.min(width, height)
    local eps = collision_config.EPSILON_SHRINK or 0

    local shoulder_r = (collision_config.SHOULDER_RADIUS_FACTOR or 0.2) * min_dim
    local central_width = math.max(1, width - 2 * shoulder_r)

    local obb_w = math.max(1, central_width - 2 * eps)
    local obb_h = math.max(1, height - 2 * eps)
    local central_obb = Collision.create_obb(center_x, center_y, obb_w, obb_h, rotation)

    local cos_rot = math.cos(rotation)
    local sin_rot = math.sin(rotation)
    local offset = central_width * 0.5

    local left_x = center_x - offset * cos_rot
    local left_y = center_y - offset * sin_rot
    local right_x = center_x + offset * cos_rot
    local right_y = center_y + offset * sin_rot

    local shoulder_radius = math.max(shoulder_r - eps, math.max(0, shoulder_r * 0.5))
    local left_shoulder = Collision.create_circle(left_x, left_y, shoulder_radius)
    local right_shoulder = Collision.create_circle(right_x, right_y, shoulder_radius)

    local corners = nil
    if collision_config.USE_CORNER_CIRCLES then
        local corner_r = (collision_config.CORNER_RADIUS_FACTOR or 0.1) * min_dim
        corner_r = math.max(corner_r - eps, 0)
        if corner_r > 0 then
            local corners_world = Collision.get_obb_corners(central_obb)
            corners = {
                Collision.create_circle(corners_world[1].x, corners_world[1].y, corner_r),
                Collision.create_circle(corners_world[2].x, corners_world[2].y, corner_r),
                Collision.create_circle(corners_world[3].x, corners_world[3].y, corner_r),
                Collision.create_circle(corners_world[4].x, corners_world[4].y, corner_r),
            }
        end
    end

    return {
        central_obb = central_obb,
        left_shoulder = left_shoulder,
        right_shoulder = right_shoulder,
        corner_circles = corners,
        rotation = rotation
    }
end

-- Composite body vs composite body collision with contact point detection
function Collision.composite_vs_composite(body1, body2)
    local collision = false
    local contact_point = nil
    local colliding_shoulder = nil

    -- Check central OBB collision
    if Collision.obb_vs_obb(body1.central_obb, body2.central_obb) then
        collision = true
        -- Use center point for central collisions
        contact_point = Vector2.new(body1.central_obb.center.x, body1.central_obb.center.y)
    end

    -- Check shoulder circle collisions
    local function check_shoulder_collision(shoulder1, shoulder2, shoulder_name)
        if Collision.circle_vs_circle(shoulder1, shoulder2) then
            collision = true
            -- Use the shoulder center as contact point
            contact_point = Vector2.new(shoulder1.center.x, shoulder1.center.y)
            colliding_shoulder = shoulder_name
            return true
        end
        return false
    end

    -- Check all shoulder combinations
    if not collision then
        if check_shoulder_collision(body1.left_shoulder, body2.left_shoulder, "left") then
        elseif check_shoulder_collision(body1.left_shoulder, body2.right_shoulder, "left") then
        elseif check_shoulder_collision(body1.right_shoulder, body2.left_shoulder, "right") then
        elseif check_shoulder_collision(body1.right_shoulder, body2.right_shoulder, "right") then
        end
    end

    -- Check shoulder vs OBB collisions
    local function check_shoulder_vs_obb(shoulder, obb, shoulder_name)
        if Collision.circle_vs_obb(shoulder, obb) then
            collision = true
            -- Use the shoulder center as contact point
            contact_point = Vector2.new(shoulder.center.x, shoulder.center.y)
            colliding_shoulder = shoulder_name
            return true
        end
        return false
    end

    -- Check all shoulder vs OBB combinations
    if not collision then
        if check_shoulder_vs_obb(body1.left_shoulder, body2.central_obb, "left") then
        elseif check_shoulder_vs_obb(body1.right_shoulder, body2.central_obb, "right") then
        elseif check_shoulder_vs_obb(body2.left_shoulder, body1.central_obb, nil) then
            -- For body2's shoulders, we don't track which shoulder since we pivot around body1
            contact_point = Vector2.new(body2.left_shoulder.center.x, body2.left_shoulder.center.y)
        elseif check_shoulder_vs_obb(body2.right_shoulder, body1.central_obb, nil) then
            contact_point = Vector2.new(body2.right_shoulder.center.x, body2.right_shoulder.center.y)
        end
    end

    -- Optional: corners involvement
    if not collision and body1.corner_circles then
        for _, corner in ipairs(body1.corner_circles) do
            if Collision.circle_vs_obb(corner, body2.central_obb) then
                collision = true
                contact_point = Vector2.new(corner.center.x, corner.center.y)
                break
            end
        end
    end
    if not collision and body2.corner_circles then
        for _, corner in ipairs(body2.corner_circles) do
            if Collision.circle_vs_obb(corner, body1.central_obb) then
                collision = true
                contact_point = Vector2.new(corner.center.x, corner.center.y)
                break
            end
        end
    end
    if not collision and body1.corner_circles and body2.corner_circles then
        for _, c1 in ipairs(body1.corner_circles) do
            for _, c2 in ipairs(body2.corner_circles) do
                if Collision.circle_vs_circle(c1, c2) then
                    collision = true
                    contact_point = Vector2.new(c1.center.x, c1.center.y)
                    break
                end
            end
            if collision then break end
        end
    end

    return collision, contact_point, colliding_shoulder
end

-- Compute MTV for composite bodies (central OBB + shoulders)
-- Returns a Vector2 MTV that moves body1 out of body2, or nil
function Collision.composite_mtv(body1, body2)
    local candidates = {}

    -- OBB vs OBB
    local mtv = Collision.obb_mtv(body1.central_obb, body2.central_obb)
    if mtv then table.insert(candidates, mtv) end

    -- Shoulder vs shoulder (circle-circle)
    mtv = Collision.circle_circle_mtv(body1.left_shoulder, body2.left_shoulder)
    if mtv then table.insert(candidates, mtv) end
    mtv = Collision.circle_circle_mtv(body1.left_shoulder, body2.right_shoulder)
    if mtv then table.insert(candidates, mtv) end
    mtv = Collision.circle_circle_mtv(body1.right_shoulder, body2.left_shoulder)
    if mtv then table.insert(candidates, mtv) end
    mtv = Collision.circle_circle_mtv(body1.right_shoulder, body2.right_shoulder)
    if mtv then table.insert(candidates, mtv) end

    -- Shoulder vs OBB (both directions). For body2's shoulder vs body1's OBB, invert to move body1
    mtv = Collision.circle_obb_mtv(body1.left_shoulder, body2.central_obb)
    if mtv then table.insert(candidates, mtv) end
    mtv = Collision.circle_obb_mtv(body1.right_shoulder, body2.central_obb)
    if mtv then table.insert(candidates, mtv) end
    mtv = Collision.circle_obb_mtv(body2.left_shoulder, body1.central_obb)
    if mtv then table.insert(candidates, Vector2.new(-mtv.x, -mtv.y)) end
    mtv = Collision.circle_obb_mtv(body2.right_shoulder, body1.central_obb)
    if mtv then table.insert(candidates, Vector2.new(-mtv.x, -mtv.y)) end

    -- Corners vs central OBBs
    if body1.corner_circles then
        for _, c in ipairs(body1.corner_circles) do
            mtv = Collision.circle_obb_mtv(c, body2.central_obb)
            if mtv then table.insert(candidates, mtv) end
        end
    end
    if body2.corner_circles then
        for _, c in ipairs(body2.corner_circles) do
            mtv = Collision.circle_obb_mtv(c, body1.central_obb)
            if mtv then table.insert(candidates, Vector2.new(-mtv.x, -mtv.y)) end
        end
    end

    -- Corners vs corners
    if body1.corner_circles and body2.corner_circles then
        for _, c1 in ipairs(body1.corner_circles) do
            for _, c2 in ipairs(body2.corner_circles) do
                mtv = Collision.circle_circle_mtv(c1, c2)
                if mtv then table.insert(candidates, mtv) end
            end
        end
    end

    -- Corners vs shoulders
    if body1.corner_circles then
        for _, c in ipairs(body1.corner_circles) do
            mtv = Collision.circle_circle_mtv(c, body2.left_shoulder)
            if mtv then table.insert(candidates, mtv) end
            mtv = Collision.circle_circle_mtv(c, body2.right_shoulder)
            if mtv then table.insert(candidates, mtv) end
        end
    end
    if body2.corner_circles then
        for _, c in ipairs(body2.corner_circles) do
            mtv = Collision.circle_circle_mtv(c, body1.left_shoulder)
            if mtv then table.insert(candidates, Vector2.new(-mtv.x, -mtv.y)) end
            mtv = Collision.circle_circle_mtv(c, body1.right_shoulder)
            if mtv then table.insert(candidates, Vector2.new(-mtv.x, -mtv.y)) end
        end
    end

    local best = nil
    local best_len_sq = math.huge
    for _, v in ipairs(candidates) do
        local len_sq = v.x * v.x + v.y * v.y
        if len_sq < best_len_sq then
            best = v
            best_len_sq = len_sq
        end
    end

    return best
end

-- Utility function to create collision shapes from entity components
function Collision.create_entity_body_composite(transform, render)
    local angle_radians = math.rad(transform.facing)
    return Collision.create_composite_body(
        transform.x, transform.y,
        render.body_width, render.body_height,
        angle_radians
    )
end

function Collision.create_entity_head_circle(transform, render, animation)
    local angle_radians = math.rad(transform.facing)
    local head_offset = animation and animation.head_offset or 0

    -- Calculate head position with offset
    local head_x = transform.x
    local head_y = transform.y

    if head_offset ~= 0 then
        local offset_distance = head_offset * render.head_radius * 2
        head_x = head_x + math.cos(angle_radians) * 0 - math.sin(angle_radians) * offset_distance
        head_y = head_y + math.sin(angle_radians) * 0 + math.cos(angle_radians) * offset_distance
    end

    return Collision.create_circle(head_x, head_y, render.head_radius)
end

return Collision
