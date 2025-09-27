-- Error Handler - Comprehensive error handling and validation utilities
-- Provides safe function calls, validation, and graceful error recovery

---@class ErrorHandler
---@field error_log table[] List of logged errors
---@field max_log_size number Maximum number of errors to keep in log
---@field debug_mode boolean Whether to print errors to console
local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler

---@class ErrorInfo
---@field message string Error message
---@field stack_trace string? Stack trace if available
---@field timestamp number Time when error occurred
---@field context string? Additional context information
---@field severity string Error severity level

---Error severity levels
---@enum ErrorSeverity
local ErrorSeverity = {
    DEBUG = "debug",
    INFO = "info",
    WARNING = "warning",
    ERROR = "error",
    CRITICAL = "critical"
}

---Create a new error handler
---@param debug_mode boolean? Whether to print errors to console (default: false)
---@param max_log_size number? Maximum errors to keep in log (default: 100)
---@return ErrorHandler
function ErrorHandler.new(debug_mode, max_log_size)
    local self = setmetatable({}, ErrorHandler)

    self.error_log = {}
    self.max_log_size = max_log_size or 100
    self.debug_mode = debug_mode or false

    return self
end

---Log an error with context information
---@param message string Error message
---@param severity string? Error severity level
---@param context string? Additional context information
function ErrorHandler:log_error(message, severity, context)
    severity = severity or ErrorSeverity.ERROR

    local error_info = {
        message = message,
        stack_trace = debug.traceback(),
        timestamp = love.timer.getTime(),
        context = context,
        severity = severity
    }

    -- Add to log
    table.insert(self.error_log, error_info)

    -- Trim log if too large
    while #self.error_log > self.max_log_size do
        table.remove(self.error_log, 1)
    end

    -- Print to console if debug mode
    if self.debug_mode then
        local prefix = string.format("[%s] %s:", string.upper(severity), os.date("%H:%M:%S"))
        print(prefix .. " " .. message)
        if context then
            print("  Context: " .. context)
        end
        if severity == ErrorSeverity.CRITICAL or severity == ErrorSeverity.ERROR then
            print("  Stack trace: " .. (error_info.stack_trace or "Not available"))
        end
    end
end

---Safe function call with error handling
---@param func function Function to call safely
---@param error_message string? Custom error message
---@param context string? Additional context for debugging
---@param ... any Arguments to pass to function
---@return boolean success, any result_or_error
function ErrorHandler:safe_call(func, error_message, context, ...)
    if type(func) ~= "function" then
        self:log_error("safe_call: Expected function, got " .. type(func), ErrorSeverity.ERROR, context)
        return false, "Invalid function"
    end

    local success, result = pcall(func, ...)

    if not success then
        local message = error_message or ("Function call failed: " .. tostring(result))
        self:log_error(message, ErrorSeverity.ERROR, context)
        return false, result
    end

    return true, result
end

---Validate that a value is not nil
---@param value any Value to check
---@param name string Variable name for error messages
---@param context string? Additional context
---@return boolean is_valid
function ErrorHandler:validate_not_nil(value, name, context)
    if value == nil then
        self:log_error(string.format("Validation failed: %s is nil", name), ErrorSeverity.WARNING, context)
        return false
    end
    return true
end

---Validate that a value is of expected type
---@param value any Value to check
---@param expected_type string Expected type name
---@param name string Variable name for error messages
---@param context string? Additional context
---@return boolean is_valid
function ErrorHandler:validate_type(value, expected_type, name, context)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        self:log_error(
            string.format("Type validation failed: %s expected %s, got %s", name, expected_type, actual_type),
            ErrorSeverity.WARNING,
            context
        )
        return false
    end
    return true
end

---Validate that a number is within a range
---@param value number Value to check
---@param min_val number Minimum allowed value
---@param max_val number Maximum allowed value
---@param name string Variable name for error messages
---@param context string? Additional context
---@return boolean is_valid
function ErrorHandler:validate_range(value, min_val, max_val, name, context)
    if type(value) ~= "number" then
        self:log_error(
            string.format("Range validation failed: %s is not a number (got %s)", name, type(value)),
            ErrorSeverity.WARNING,
            context
        )
        return false
    end

    if value < min_val or value > max_val then
        self:log_error(
            string.format("Range validation failed: %s (%s) not in range [%s, %s]", name, value, min_val, max_val),
            ErrorSeverity.WARNING,
            context
        )
        return false
    end

    return true
end

---Validate that a table has required fields
---@param tbl table Table to validate
---@param required_fields string[] List of required field names
---@param name string Table name for error messages
---@param context string? Additional context
---@return boolean is_valid
function ErrorHandler:validate_table_fields(tbl, required_fields, name, context)
    if type(tbl) ~= "table" then
        self:log_error(
            string.format("Table validation failed: %s is not a table (got %s)", name, type(tbl)),
            ErrorSeverity.WARNING,
            context
        )
        return false
    end

    for _, field in ipairs(required_fields) do
        if tbl[field] == nil then
            self:log_error(
                string.format("Table validation failed: %s missing required field '%s'", name, field),
                ErrorSeverity.WARNING,
                context
            )
            return false
        end
    end

    return true
end

---Safe table access with default value
---@param tbl table? Table to access
---@param key any Key to look up
---@param default any Default value if key not found or table is nil
---@param context string? Additional context for error logging
---@return any value
function ErrorHandler:safe_table_get(tbl, key, default, context)
    if type(tbl) ~= "table" then
        if tbl ~= nil then -- Only log if it's not nil (nil tables are expected sometimes)
            self:log_error(
                string.format("safe_table_get: Expected table, got %s", type(tbl)),
                ErrorSeverity.DEBUG,
                context
            )
        end
        return default
    end

    local value = tbl[key]
    return value ~= nil and value or default
end

---Safe component access for ECS systems
---@param component_manager any Component manager instance
---@param entity_id any Entity ID
---@param component_type string Component type name
---@param context string? Additional context
---@return any? component
function ErrorHandler:safe_get_component(component_manager, entity_id, component_type, context)
    if not self:validate_not_nil(component_manager, "component_manager", context) then
        return nil
    end

    if not self:validate_not_nil(entity_id, "entity_id", context) then
        return nil
    end

    if not self:validate_type(component_type, "string", "component_type", context) then
        return nil
    end

    local success, component = self:safe_call(
        function() return component_manager:get_component(entity_id, component_type) end,
        string.format("Failed to get component %s for entity %s", component_type, entity_id),
        context
    )

    if success then
        return component
    else
        return nil
    end
end

---Safe Love2D object method call
---@param object any Love2D object (joystick, font, etc.)
---@param method_name string Method name to call
---@param error_message string? Custom error message
---@param context string? Additional context
---@param ... any Arguments to pass to method
---@return boolean success, any result_or_error
function ErrorHandler:safe_love_call(object, method_name, error_message, context, ...)
    if not self:validate_not_nil(object, "object", context) then
        return false, "Object is nil"
    end

    if type(object[method_name]) ~= "function" then
        self:log_error(
            string.format("Method '%s' not found on object", method_name),
            ErrorSeverity.WARNING,
            context
        )
        return false, "Method not found"
    end

    local args = {...}
    return self:safe_call(
        function() return object[method_name](object, unpack(args)) end,
        error_message or string.format("Failed to call %s", method_name),
        context
    )
end

---Handle controller disconnection gracefully
---@param joystick love.Joystick? Joystick object that may be disconnected
---@param context string? Additional context
---@return boolean is_connected
function ErrorHandler:validate_controller_connection(joystick, context)
    if not joystick then
        return false
    end

    local success, connected = self:safe_love_call(
        joystick,
        "isConnected",
        "Failed to check controller connection",
        context
    )

    if not success then
        return false
    end

    if not connected then
        self:log_error(
            "Controller disconnected",
            ErrorSeverity.INFO,
            context
        )
        return false
    end

    return true
end

---Create a safe wrapper for a function that may fail
---@param func function Function to wrap
---@param default_return any Default value to return on error
---@param error_message string? Custom error message
---@param context string? Additional context
---@return function wrapped_function
function ErrorHandler:create_safe_wrapper(func, default_return, error_message, context)
    return function(...)
        local args = {...}
        local success, result = self:safe_call(func, error_message, context, unpack(args))
        return success and result or default_return
    end
end

---Get recent errors from the log
---@param count number? Number of recent errors to get (default: 10)
---@param min_severity string? Minimum severity level to include
---@return ErrorInfo[] recent_errors
function ErrorHandler:get_recent_errors(count, min_severity)
    count = count or 10
    min_severity = min_severity or ErrorSeverity.DEBUG

    local severity_levels = {
        [ErrorSeverity.DEBUG] = 1,
        [ErrorSeverity.INFO] = 2,
        [ErrorSeverity.WARNING] = 3,
        [ErrorSeverity.ERROR] = 4,
        [ErrorSeverity.CRITICAL] = 5
    }

    local min_level = severity_levels[min_severity] or 1
    local filtered_errors = {}

    -- Filter by severity and get recent errors
    for i = math.max(1, #self.error_log - count + 1), #self.error_log do
        local error_info = self.error_log[i]
        local error_level = severity_levels[error_info.severity] or 1
        if error_level >= min_level then
            table.insert(filtered_errors, error_info)
        end
    end

    return filtered_errors
end

---Clear the error log
function ErrorHandler:clear_log()
    self.error_log = {}
end

---Get error statistics
---@return table error_stats
function ErrorHandler:get_stats()
    local stats = {
        total_errors = #self.error_log,
        by_severity = {},
        recent_count = 0
    }

    local recent_threshold = love.timer.getTime() - 60 -- Last 60 seconds

    for _, error_info in ipairs(self.error_log) do
        local severity = error_info.severity
        stats.by_severity[severity] = (stats.by_severity[severity] or 0) + 1

        if error_info.timestamp >= recent_threshold then
            stats.recent_count = stats.recent_count + 1
        end
    end

    return stats
end

-- Global error handler instance
local global_error_handler = ErrorHandler.new(true, 200) -- Debug mode enabled, larger log

-- Convenience functions for global error handler
local ErrorUtils = {}

---@param message string
---@param severity string?
---@param context string?
function ErrorUtils.log_error(message, severity, context)
    global_error_handler:log_error(message, severity, context)
end

---@param func function
---@param error_message string?
---@param context string?
---@param ... any
---@return boolean, any
function ErrorUtils.safe_call(func, error_message, context, ...)
    local args = {...}
    return global_error_handler:safe_call(func, error_message, context, unpack(args))
end

---@param value any
---@param name string
---@param context string?
---@return boolean
function ErrorUtils.validate_not_nil(value, name, context)
    return global_error_handler:validate_not_nil(value, name, context)
end

---@param value any
---@param expected_type string
---@param name string
---@param context string?
---@return boolean
function ErrorUtils.validate_type(value, expected_type, name, context)
    return global_error_handler:validate_type(value, expected_type, name, context)
end

---@param component_manager any
---@param entity_id any
---@param component_type string
---@param context string?
---@return any?
function ErrorUtils.safe_get_component(component_manager, entity_id, component_type, context)
    return global_error_handler:safe_get_component(component_manager, entity_id, component_type, context)
end

---@param object any
---@param method_name string
---@param error_message string?
---@param context string?
---@param ... any
---@return boolean, any
function ErrorUtils.safe_love_call(object, method_name, error_message, context, ...)
    local args = {...}
    return global_error_handler:safe_love_call(object, method_name, error_message, context, unpack(args))
end

---@param joystick love.Joystick?
---@param context string?
---@return boolean
function ErrorUtils.validate_controller_connection(joystick, context)
    return global_error_handler:validate_controller_connection(joystick, context)
end

---Get the global error handler instance
---@return ErrorHandler
function ErrorUtils.get_global_handler()
    return global_error_handler
end

ErrorUtils.Severity = ErrorSeverity
ErrorUtils.Handler = ErrorHandler

return ErrorUtils
