-- Spatial Hash Grid for efficient collision detection
-- Divides space into a grid and tracks which entities are in each cell

local Vector2 = require("util.vector2")
local collision_utils = require("util.collision")

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cell_size, world_width, world_height)
    local self = setmetatable({}, SpatialHash)

    self.cell_size = cell_size or 128 -- Size of each grid cell
    self.world_width = world_width or 1920
    self.world_height = world_height or 1080

    -- Calculate grid dimensions
    self.grid_width = math.ceil(self.world_width / self.cell_size)
    self.grid_height = math.ceil(self.world_height / self.cell_size)

    -- Grid storage: grid[y][x] = {entity_id1, entity_id2, ...}
    self.grid = {}
    for y = 1, self.grid_height do
        self.grid[y] = {}
        for x = 1, self.grid_width do
            self.grid[y][x] = {}
        end
    end

    -- Track which cells each entity is in for efficient removal
    self.entity_cells = {}

    return self
end

-- Convert world coordinates to grid coordinates
function SpatialHash:world_to_grid(x, y)
    local grid_x = math.floor(x / self.cell_size) + 1
    local grid_y = math.floor(y / self.cell_size) + 1

    -- Clamp to grid bounds
    grid_x = math.max(1, math.min(grid_x, self.grid_width))
    grid_y = math.max(1, math.min(grid_y, self.grid_height))

    return grid_x, grid_y
end

-- Get all grid cells that an AABB overlaps
function SpatialHash:get_overlapping_cells(aabb)
    local min_x, min_y = self:world_to_grid(aabb.min.x, aabb.min.y)
    local max_x, max_y = self:world_to_grid(aabb.max.x, aabb.max.y)

    local cells = {}
    for y = min_y, max_y do
        for x = min_x, max_x do
            table.insert(cells, {x = x, y = y})
        end
    end

    return cells
end

-- Add an entity to the spatial hash
function SpatialHash:add_entity(entity_id, aabb)
    -- Remove entity if it was already in the hash
    self:remove_entity(entity_id)

    -- Get cells the entity overlaps
    local cells = self:get_overlapping_cells(aabb)

    -- Add entity to each overlapping cell
    for _, cell in ipairs(cells) do
        table.insert(self.grid[cell.y][cell.x], entity_id)
    end

    -- Track which cells this entity is in
    self.entity_cells[entity_id] = cells
end

-- Remove an entity from the spatial hash
function SpatialHash:remove_entity(entity_id)
    local cells = self.entity_cells[entity_id]
    if not cells then
        return
    end

    -- Remove entity from each cell it was in
    for _, cell in ipairs(cells) do
        local cell_entities = self.grid[cell.y][cell.x]
        for i = #cell_entities, 1, -1 do
            if cell_entities[i] == entity_id then
                table.remove(cell_entities, i)
                break
            end
        end
    end

    -- Clear entity tracking
    self.entity_cells[entity_id] = nil
end

-- Get potential collision candidates for an entity
function SpatialHash:get_nearby_entities(entity_id, aabb)
    local cells = self:get_overlapping_cells(aabb)
    local nearby_entities = {}
    local seen = {}

    for _, cell in ipairs(cells) do
        local cell_entities = self.grid[cell.y][cell.x]
        for _, other_entity_id in ipairs(cell_entities) do
            if other_entity_id ~= entity_id and not seen[other_entity_id] then
                table.insert(nearby_entities, other_entity_id)
                seen[other_entity_id] = true
            end
        end
    end

    return nearby_entities
end

-- Update an entity's position in the spatial hash
function SpatialHash:update_entity(entity_id, aabb)
    self:add_entity(entity_id, aabb)
end

-- Clear all entities from the spatial hash
function SpatialHash:clear()
    for y = 1, self.grid_height do
        for x = 1, self.grid_width do
            self.grid[y][x] = {}
        end
    end
    self.entity_cells = {}
end

-- Get statistics about the spatial hash (for debugging)
function SpatialHash:get_stats()
    local total_entities = 0
    local non_empty_cells = 0
    local max_entities_per_cell = 0

    for y = 1, self.grid_height do
        for x = 1, self.grid_width do
            local cell_count = #self.grid[y][x]
            total_entities = total_entities + cell_count
            if cell_count > 0 then
                non_empty_cells = non_empty_cells + 1
                max_entities_per_cell = math.max(max_entities_per_cell, cell_count)
            end
        end
    end

    return {
        total_cells = self.grid_width * self.grid_height,
        non_empty_cells = non_empty_cells,
        total_entity_entries = total_entities,
        max_entities_per_cell = max_entities_per_cell,
        cell_size = self.cell_size,
        grid_dimensions = {width = self.grid_width, height = self.grid_height}
    }
end

-- Debug: Get all entities in a specific cell
function SpatialHash:get_entities_in_cell(grid_x, grid_y)
    if grid_x < 1 or grid_x > self.grid_width or
       grid_y < 1 or grid_y > self.grid_height then
        return {}
    end

    return self.grid[grid_y][grid_x]
end

-- Debug: Visualize the spatial hash grid
function SpatialHash:draw_debug(camera_x, camera_y, screen_width, screen_height)
    camera_x = camera_x or 0
    camera_y = camera_y or 0
    screen_width = screen_width or love.graphics.getWidth()
    screen_height = screen_height or love.graphics.getHeight()

    love.graphics.push("all")
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.setLineWidth(1)

    -- Draw vertical grid lines
    for x = 1, self.grid_width + 1 do
        local world_x = (x - 1) * self.cell_size
        local screen_x = world_x - camera_x
        if screen_x >= -self.cell_size and screen_x <= screen_width + self.cell_size then
            love.graphics.line(screen_x, 0, screen_x, screen_height)
        end
    end

    -- Draw horizontal grid lines
    for y = 1, self.grid_height + 1 do
        local world_y = (y - 1) * self.cell_size
        local screen_y = world_y - camera_y
        if screen_y >= -self.cell_size and screen_y <= screen_height + self.cell_size then
            love.graphics.line(0, screen_y, screen_width, screen_y)
        end
    end

    -- Draw cell occupancy
    love.graphics.setColor(1, 0, 0, 0.2)
    for y = 1, self.grid_height do
        for x = 1, self.grid_width do
            local entity_count = #self.grid[y][x]
            if entity_count > 0 then
                local world_x = (x - 1) * self.cell_size
                local world_y = (y - 1) * self.cell_size
                local screen_x = world_x - camera_x
                local screen_y = world_y - camera_y

                if screen_x >= -self.cell_size and screen_x <= screen_width and
                   screen_y >= -self.cell_size and screen_y <= screen_height then
                    local alpha = math.min(entity_count / 4, 1) -- Scale alpha by entity count
                    love.graphics.setColor(1, 0.5, 0, alpha)
                    love.graphics.rectangle("fill", screen_x, screen_y, self.cell_size, self.cell_size)
                end
            end
        end
    end

    love.graphics.pop()
end

return SpatialHash
