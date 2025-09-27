-- Hot Reload Manager
-- Handles reloading of Lua modules during development

local HotReloadManager = {}
HotReloadManager.__index = HotReloadManager

-- Store the original require function
local original_require = require

-- Keep track of loaded module timestamps
local loaded_modules = {}
local module_paths = {}

function HotReloadManager.new()
    local self = setmetatable({}, HotReloadManager)
    self.debug_mode = false
    return self
end

-- Override the global require function to track module loads
function HotReloadManager:install()
    _G.require = function(modname)
        local result = original_require(modname)

        -- Convert module name to potential file path and record file modtime when available
        local path = modname:gsub("%.", "/") .. ".lua"
        local info = love.filesystem.getInfo(path)
        if info then
            module_paths[modname] = path
            loaded_modules[modname] = info.modtime
        else
            -- Fallback to runtime clock if filesystem modtime is unavailable
            loaded_modules[modname] = love.timer.getTime()
        end

        return result
    end
end

-- Restore original require function
function HotReloadManager:uninstall()
    _G.require = original_require
end

-- Check if any tracked modules have been modified
function HotReloadManager:check_for_changes()
    local reloaded_modules = {}

    for modname, path in pairs(module_paths) do
        local info = love.filesystem.getInfo(path)
        if info then
            local last_modified = info.modtime
            if last_modified > loaded_modules[modname] then
                -- Clear the package.loaded entry to force a reload
                package.loaded[modname] = nil
                -- Reload the module
                local success, err = pcall(function()
                    original_require(modname)
                end)
                if success then
                    -- Record the file's last modified timestamp to compare consistently next time
                    loaded_modules[modname] = last_modified
                    table.insert(reloaded_modules, modname)
                    if self.debug_mode then
                        print(string.format("Hot reloaded: %s", modname))
                    end
                else
                    if self.debug_mode then
                        print(string.format("Failed to reload %s: %s", modname, err))
                    end
                end
            end
        end
    end

    return reloaded_modules
end

-- Set debug mode
function HotReloadManager:set_debug(enabled)
    self.debug_mode = enabled
end

-- Clear all tracked modules
function HotReloadManager:clear()
    loaded_modules = {}
    module_paths = {}
end

return HotReloadManager
