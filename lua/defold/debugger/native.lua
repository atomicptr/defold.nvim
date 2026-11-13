local M = {}

local launching = false

---@type integer?
local debugger_port = nil

---@return integer?
function M.port()
    return debugger_port
end

---@class defold.debugger.NativeConfiguration: dap.Configuration
---@field launch_native? boolean Run the game before attaching
---@field host?          string  DAP connection host (default: 127.0.0.1)
---@field address?       string  Engine debugger bind address (default: 127.0.0.1)
---@field port?          integer DAP port (default: choose on launch, reuse on attach)

---@param callback       fun(port: integer)
---@param session_config defold.debugger.NativeConfiguration
local function launch(callback, session_config)
    local log = require "defold.logger"
    local project = require "defold.project"
    local editor = require "defold.editor"
    local config = require "defold.config"
    local sidecar = require "defold.sidecar"

    if launching then
        log.error "A debug launch is already in progress"
        return
    end

    if not project.project_root() or not project.editor_port() then
        log.error "Could not find the Defold editor/project"
        return
    end

    launching = true
    debugger_port = nil

    ---@param err string?
    local function fail(err)
        launching = false
        log.error("Debug launch failed: " .. tostring(err))
    end

    local result = editor.send_command("run", true)
    if result and config.state.quickfix.enable then
        editor.open_quickfix_from_command_result(result)
    end

    if not result or not result.success then
        fail "Defold could not run the game"
        return
    end

    if not result.target or type(result.target.url) ~= "string" then
        fail "Defold did not return target.url; update the editor and rebuild/update the defold.nvim sidecar"
        return
    end

    -- request a fresh port for every launch
    sidecar.worker_call("start_native_debugger", function(port, err)
        if type(port) ~= "number" then
            fail(err)
            return
        end

        launching = false
        debugger_port = port
        callback(port)
    end, result.target.url, session_config.port or 0, session_config.address or "127.0.0.1")
end

function M.register()
    local log = require "defold.logger"
    local dap = require "dap"
    local project = require "defold.project"

    ---@param callback       fun(adapter: dap.ServerAdapter)
    ---@param session_config defold.debugger.NativeConfiguration
    dap.adapters.defold_nvim_native = function(callback, session_config)
        ---@param port integer?
        local function attach(port)
            if not port then
                log.error "No debugger port available. Launch the game first."
                return
            end

            callback {
                id = "defold_nvim_native",
                type = "server",
                host = session_config.host or "127.0.0.1",
                port = port,
                options = session_config.launch_native and { max_retries = 100 } or nil,
            }
        end

        if session_config.launch_native then
            launch(attach, session_config)
        else
            attach(session_config.port or debugger_port)
        end
    end

    dap.configurations.lua = {
        {
            type = "defold_nvim_native",
            request = "attach",
            name = "defold.nvim: Launch Game & Attach",
            launch_native = true,
            ---@return string?
            localRoot = function()
                return project.project_root()
            end,
            stopOnEntry = false,
        },
        {
            type = "defold_nvim_native",
            request = "attach",
            name = "defold.nvim: Attach to Debugger",
            ---@return string?
            localRoot = function()
                return project.project_root()
            end,
            stopOnEntry = false,
        },
    }
end

return M
