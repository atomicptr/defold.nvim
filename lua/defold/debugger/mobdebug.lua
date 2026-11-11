local M = {}

---@param install_when_not_present? boolean
---@return string|nil
function M.get_path(install_when_not_present)
    local config = require "defold.config"
    local os = require "defold.service.os"
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    if config.state.debugger.mobdebug.mobdap_executable then
        return config.state.debugger.mobdebug.mobdap_executable
    end

    if os.command_exists "mobdap" then
        return vim.fn.exepath "mobdap"
    end

    if M.path then
        return M.path
    end

    if not install_when_not_present then
        return nil
    end

    local ok, res = pcall(sidecar.mobdap_install)
    if not ok then
        log.error(string.format("Could not install mobdap: %s", res))
        return
    end

    M.path = res
    return res
end

function M.setup()
    M.get_path(true)
end

function M.register()
    local config = require "defold.config"
    local dap = require "dap"
    local project = require "defold.project"

    dap.adapters.defold_nvim_mobdebug = {
        id = "defold_nvim_mobdebug",
        type = "executable",
        command = M.get_path(),
        args = config.state.debugger.mobdebug.mobdap_arguments,
    }

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
        require("defold.service.logger").debug "debugger: connected"
        require("defold.editor").run_game "send"
    end
end

return M
