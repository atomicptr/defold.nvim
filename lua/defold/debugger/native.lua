local M = {}

local launching = false
local ports = {}

---@return integer?
function M.port()
    return ports[require("defold.project").project_root()]
end

---@param console  { lines: string[] }
---@param previous { lines: string[] }
---@return integer?
local function console_port(console, previous)
    if type(console) ~= "table" or type(console.lines) ~= "table" then
        return nil
    end

    local first_new = 1
    local old_lines = type(previous) == "table" and previous.lines or {}

    while console.lines[first_new] and console.lines[first_new] == old_lines[first_new] do
        first_new = first_new + 1
    end

    for index = #console.lines, first_new, -1 do
        local line = console.lines[index]
        local value = line:match "Lua DAP debugger listening on %S+:(%d+)" or line:match "Lua DAP debugger port: (%d+)"

        local port = tonumber(value)
        if port and port >= 1 and port <= 65535 then
            return port
        end
    end

    return nil
end

---@param callback fun(port: integer)
local function launch(callback)
    local log = require "defold.service.logger"

    if launching then
        log.error "A debug launch is already in progress"
        return
    end

    local project = require "defold.project"
    local editor_port = project.editor_port()
    local root = project.project_root()

    if not editor_port or not root then
        log.error "Could not find the Defold editor/project"
        return
    end

    local os = require "defold.service.os"
    local editor = require "defold.editor"

    local base = string.format("http://127.0.0.1:%d", editor_port)
    local started = false
    launching = true

    ---@param err string
    local function fail(err)
        launching = false
        if started then
            editor.send_command("debugger-detach", true)
        end
        log.error(string.format("Debug launch failed: %s", err))
    end

    os.fetch_json(base .. "/console", function(previous, previous_err)
        if previous_err then
            fail(previous_err)
            return
        end

        local result = editor.send_command("debugger-start", true)
        if result and require("defold.config").state.quickfix.enable then
            editor.open_quickfix_from_command_result(result)
        end

        if not result or not result.success then
            fail "Defold could not start its debugger"
            return
        end

        started = true

        local deadline = vim.uv.hrtime() + 5e9

        local function discover()
            os.fetch_json(base .. "/console", function(console, console_err)
                if console_err then
                    fail(console_err)
                    return
                end

                local port = console_port(console, previous)
                if not port then
                    if vim.uv.hrtime() < deadline then
                        vim.defer_fn(discover, 100)
                        return
                    end

                    fail "No debugger port announced in the Defold console"
                    return
                end

                local detached = editor.send_command("debugger-detach", true)
                if not detached or detached.status ~= 200 then
                    fail "Defold could not detach its debugger"
                    return
                end

                ports[root] = port
                launching = false

                callback(port)
            end)
        end

        discover()
    end)
end

function M.register()
    local log = require "defold.service.logger"
    local dap = require "dap"
    local project = require "defold.project"

    ---@param callback fun(adapter: dap.ServerAdapter)
    dap.adapters.defold_nvim_native = function(callback, session_config)
        ---@param port integer?
        local function attach(port)
            if not port then
                log.error "No debugger port discovered for this project. Launch the game first."
                return
            end

            callback {
                id = "defold_nvim_native",
                type = "server",
                host = "127.0.0.1",
                port = port,
                options = session_config.launch_native and { max_retries = 100 } or nil,
            }
        end

        if session_config.launch_native then
            launch(attach)
        else
            attach(M.port())
        end
    end

    dap.configurations.lua = {
        {
            type = "defold_nvim_native",
            request = "attach",
            name = "defold.nvim: Launch Game & Attach",
            -- TODO: offer this only when no game is running.
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
