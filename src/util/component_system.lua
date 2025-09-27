-- Component System - Entity Component System (ECS) implementation
-- Allows for modular, reusable functionality attached to entities

---@class ComponentSystem
local ComponentSystem = {}

---@alias EntityId number Unique identifier for an entity

---Base Component class
---@class Component
---@field entity_id EntityId The entity this component belongs to
---@field enabled boolean Whether this component is active
local Component = {}
Component.__index = Component

---Create a new component instance
---@param entity_id EntityId The entity this component belongs to
---@return Component component New component instance
function Component.new(entity_id)
    local self = setmetatable({}, Component)
    self.entity_id = entity_id
    self.enabled = true
    return self
end

---Get the type name of this component
---@return string type_name Component type identifier
function Component:get_type()
    return "Component"
end

---Update the component (override in subclasses)
---@param dt number Delta time in seconds
function Component:update(dt)
    -- Override in subclasses
end

---Destroy the component
function Component:destroy()
    self.enabled = false
end

---Component Registry - tracks all component types
---@class ComponentRegistry
---@field register fun(component_class: table, type_name: string): nil
---@field get_type fun(type_name: string): table?
---@field get_all_types fun(): string[]
local ComponentRegistry = {}

---@type table<string, table> Map of component type names to their classes
local component_types = {}

---Register a component type
---@param component_class table The component class to register
---@param type_name string Unique type identifier
function ComponentRegistry.register(component_class, type_name)
    component_types[type_name] = component_class
    component_class.TYPE_NAME = type_name
end

---Get a component class by type name
---@param type_name string Component type identifier
---@return table? component_class The component class or nil if not found
function ComponentRegistry.get_type(type_name)
    return component_types[type_name]
end

---Get all registered component type names
---@return string[] type_names List of all component type names
function ComponentRegistry.get_all_types()
    local types = {}
    for name, _ in pairs(component_types) do
        table.insert(types, name)
    end
    return types
end

-- Entity Component Manager - manages components for entities
local EntityComponentManager = {}
EntityComponentManager.__index = EntityComponentManager

function EntityComponentManager.new()
    local self = setmetatable({}, EntityComponentManager)
    self.entities = {} -- entity_id -> { component_type -> component }
    self.component_pools = {} -- component_type -> { entity_id -> component }
    self.next_entity_id = 1
    return self
end

function EntityComponentManager:create_entity()
    local entity_id = self.next_entity_id
    self.next_entity_id = self.next_entity_id + 1
    self.entities[entity_id] = {}
    return entity_id
end

function EntityComponentManager:destroy_entity(entity_id)
    if not self.entities[entity_id] then
        return false
    end

    -- Remove all components
    for component_type, component in pairs(self.entities[entity_id]) do
        self:remove_component(entity_id, component_type)
    end

    self.entities[entity_id] = nil
    return true
end

function EntityComponentManager:add_component(entity_id, component_type, component_data)
    if not self.entities[entity_id] then
        error("Entity " .. entity_id .. " does not exist")
    end

    local ComponentClass = ComponentRegistry.get_type(component_type)
    if not ComponentClass then
        error("Unknown component type: " .. component_type)
    end

    -- Create component instance
    local component = ComponentClass.new(entity_id, component_data or {})

    -- Add to entity
    self.entities[entity_id][component_type] = component

    -- Add to component pool for efficient queries
    if not self.component_pools[component_type] then
        self.component_pools[component_type] = {}
    end
    self.component_pools[component_type][entity_id] = component

    return component
end

function EntityComponentManager:remove_component(entity_id, component_type)
    if not self.entities[entity_id] then
        return false
    end

    local component = self.entities[entity_id][component_type]
    if not component then
        return false
    end

    -- Destroy component
    component:destroy()

    -- Remove from entity
    self.entities[entity_id][component_type] = nil

    -- Remove from component pool
    if self.component_pools[component_type] then
        self.component_pools[component_type][entity_id] = nil
    end

    return true
end

function EntityComponentManager:get_component(entity_id, component_type)
    if not self.entities[entity_id] then
        return nil
    end
    return self.entities[entity_id][component_type]
end

function EntityComponentManager:has_component(entity_id, component_type)
    return self:get_component(entity_id, component_type) ~= nil
end

function EntityComponentManager:has_components(entity_id, component_types)
    for _, component_type in ipairs(component_types) do
        if not self:has_component(entity_id, component_type) then
            return false
        end
    end
    return true
end

function EntityComponentManager:get_entities_with_component(component_type)
    local entities = {}
    if self.component_pools[component_type] then
        for entity_id, component in pairs(self.component_pools[component_type]) do
            if component.enabled then
                table.insert(entities, entity_id)
            end
        end
    end
    return entities
end

function EntityComponentManager:get_entities_with_components(component_types)
    if #component_types == 0 then
        return {}
    end

    -- Start with entities that have the first component type
    local entities = self:get_entities_with_component(component_types[1])

    -- Filter to only entities that have ALL required components
    local filtered = {}
    for _, entity_id in ipairs(entities) do
        if self:has_components(entity_id, component_types) then
            table.insert(filtered, entity_id)
        end
    end

    return filtered
end

function EntityComponentManager:update_components(component_type, dt)
    if not self.component_pools[component_type] then
        return
    end

    for entity_id, component in pairs(self.component_pools[component_type]) do
        if component.enabled then
            component:update(dt)
        end
    end
end

function EntityComponentManager:get_all_entities()
    local entities = {}
    for entity_id, _ in pairs(self.entities) do
        table.insert(entities, entity_id)
    end
    return entities
end

-- System base class for processing components
local System = {}
System.__index = System

function System.new(component_manager)
    local self = setmetatable({}, System)
    self.component_manager = component_manager
    self.enabled = true
    return self
end

function System:get_required_components()
    return {} -- Override in subclasses
end

function System:update(dt)
    if not self.enabled then
        return
    end

    local required = self:get_required_components()
    local entities = self.component_manager:get_entities_with_components(required)

    for _, entity_id in ipairs(entities) do
        self:process_entity(entity_id, dt)
    end
end

function System:process_entity(entity_id, dt)
    -- Override in subclasses
end

return {
    Component = Component,
    ComponentRegistry = ComponentRegistry,
    EntityComponentManager = EntityComponentManager,
    System = System
}
