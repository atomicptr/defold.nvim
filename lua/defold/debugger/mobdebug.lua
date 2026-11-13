local M = {}

---@return string|nil
function M.get_path()
    local config = require "defold.config"
    local os = require "defold.os"

    if config.state.debugger.mobdebug.mobdap_executable then
        return config.state.debugger.mobdebug.mobdap_executable
    end

    if os.command_exists "mobdap" then
        return vim.fn.exepath "mobdap"
    end

    return M.path
end

---@param on_ready? fun(path: string)
function M.setup(on_ready)
    local log = require "defold.logger"
    local os = require "defold.os"
    local sidecar = require "defold.sidecar"
    local download = require "defold.download"

    local path = M.get_path()
    if path then
        if on_ready then
            on_ready(path)
        end

        return
    end

    local data = sidecar.data_dir()

    local archive = "tar.gz"
    local filename = "mobdap"

    if os.is_windows() then
        archive = "zip"
        filename = "mobdap.exe"
    end

    local architecture = os.architecture()

    if architecture == "aarch64" then
        architecture = "arm64"
    end

    download.ensure({
        name = "Mobdap",
        owner = "atomicptr",
        repo = "mobdap",
        asset = string.format("mobdap-%s-%s.%s", os.name(), architecture, archive),

        path = vim.fs.joinpath(data, "bin", filename),
        version_path = vim.fs.joinpath(data, "meta", "mobdap_version"),

        archive = true,
        entry = filename,
        executable = true,
    }, function(installed, err)
        if not installed then
            log.error(string.format("Installation failed (Mobdap): %s", tostring(err)))
            return
        end

        M.path = installed

        if on_ready then
            on_ready(installed)
        end
    end)
end

function M.register()
    local log = require "defold.logger"
    local config = require "defold.config"
    local dap = require "dap"
    local project = require "defold.project"

    dap.adapters.defold_nvim_mobdebug = function(callback)
        M.setup(function(path)
            callback {
                id = "defold_nvim_mobdebug",
                type = "executable",
                command = path,
                args = config.state.debugger.mobdebug.mobdap_arguments,
            }
        end)
    end

    dap.configurations.lua = {
        {
            name = "defold.nvim: Debugger",
            type = "defold_nvim_mobdebug",
            request = "launch",

            ---@return string?
            rootdir = function()
                return project.project_root()
            end,

            ---@return string[]
            sourcedirs = function()
                return project.dependency_api_paths()
            end,

            port = config.state.debugger.mobdebug.port or 18172,
        },
    }

    dap.listeners.after["event_mobdap_waiting_for_connection"].defold_nvim_start_game = function()
        log.debug "debugger: connected"
        require("defold.editor").run_game "send"
    end
end

return M
