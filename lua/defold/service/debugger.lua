local M = {}

M.path = nil

---@param config                    defold.Config
---@param install_when_not_present? boolean
---@return string|nil
function M.mobdap_path(config, install_when_not_present)
    local os = require "defold.service.os"
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    if config.debugger.custom_executable then
        return config.debugger.custom_executable
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

local function create_game_launcher(config)
    local editor = require "defold.editor"
    local log = require "defold.service.logger"
    return function(_, _)
        log.debug "debugger: connected"

        local res = editor.send_command "build"

        if config.quickfix.enable then
            editor.open_quickfix_from_command_result(res, config.quickfix.min_severity, config.quickfix.open_list)
        end
    end
end

---@param config defold.Config
local function setup_adapter_mobdap(config)
    local dap = require "dap"
    local project = require "defold.project"

    dap.adapters.defold_nvim = {
        id = "defold_nvim",
        type = "executable",
        command = M.mobdap_path(config),
        args = M.custom_arguments,
    }

    dap.configurations.lua = {
        {
            name = "defold.nvim: Debugger",
            type = "defold_nvim",
            request = "launch",

            rootdir = function()
                return project.project_root()
            end,

            sourcedirs = function()
                return project.dependency_api_paths()
            end,

            -- TODO: read it from the collection if possible
            port = config.debugger.custom_port or 18172,
        },
    }

    dap.listeners.after["event_mobdap_waiting_for_connection"].defold_nvim_start_game = create_game_launcher(config)
end

---@param config defold.Config
function M.register_nvim_dap(config)
    local log = require "defold.service.logger"

    local dap_installed, dap = pcall(require, "dap")
    if not dap_installed then
        log.warn "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

    local project = require "defold.project"

    -- TODO: make default nil and try to infer from project
    if config.debugger.integration == "mobdap" then
        setup_adapter_mobdap(config)
    end

    dap.listeners.after.event_stopped.defold_nvim_switch_focus_on_stop = function(_, _)
        log.debug "debugger: event stopped"

        local sidecar = require "defold.sidecar"
        local rootdir = project.project_root()

        local ok, err = pcall(sidecar.focus_neovim, rootdir)
        if not ok then
            log.error(string.format("Could not focus neovim: %s", err))
        end
    end

    dap.listeners.after.continue.defold_nvim_switch_focus_on_continue = function(_, _)
        log.debug "debugger: continued"

        local sidecar = require "defold.sidecar"
        local rootdir = project.project_root()

        local ok, err = pcall(sidecar.focus_game, rootdir)
        if not ok then
            log.error(string.format("Could not focus neovim: %s", err))
        end
    end
end

return M
