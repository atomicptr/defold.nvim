local M = {}

M.custom_executable = nil
M.custom_arguments = nil
M.path = nil

---@return string|nil
function M.mobdap_path()
    local os = require "defold.service.os"
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    if M.custom_executable then
        return M.custom_executable
    end

    if os.command_exists "mobdap" then
        return vim.fn.exepath "mobdap"
    end

    if M.path then
        return M.path
    end

    local ok, res = pcall(sidecar.mobdap_install)
    if not ok then
        log.error(string.format("Could not install mobdap: %s", res))
        return
    end

    M.path = res
    return res
end

---@param custom_executable string|nil
---@param custom_arguments table<string>|nil
function M.setup(custom_executable, custom_arguments)
    M.custom_executable = custom_executable
    M.custom_arguments = custom_arguments

    M.mobdap_path()
end

function M.register_nvim_dap()
    local log = require "defold.service.logger"

    local dap_installed, dap = pcall(require, "dap")
    if not dap_installed then
        log.error "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

    local editor = require "defold.editor"
    local project = require "defold.project"

    dap.adapters.defold_nvim = {
        id = "defold_nvim",
        type = "executable",
        command = M.mobdap_path(),
        args = M.custom_arguments,
    }

    dap.configurations.lua = {
        {
            name = "defold.nvim: Debugger",
            type = "defold_nvim",
            request = "launch",

            rootdir = function()
                return vim.fs.root(0, { "game.project", ".git" })
            end,

            sourcedirs = function()
                return project.dependency_api_paths()
            end,

            -- TODO: make this configurable or better read it from the collection if possible
            port = 18172,
        },
    }

    dap.listeners.after.event_mobdap_waiting_for_connection.defold_nvim_start_game = function(_, _)
        log.debug "debugger: connected"

        editor.send_command "build"
    end

    dap.listeners.after.event_stopped.defold_nvim_switch_focus_on_stop = function(_, _)
        log.debug "debugger: event stopped"

        local sidecar = require "defold.sidecar"

        local rootdir = vim.fs.root(0, { "game.project", ".git" })

        local ok, err = pcall(sidecar.focus_neovim, rootdir)
        if not ok then
            log.error(string.format("Could not focus neovim: %s", err))
        end
    end

    dap.listeners.after.continue.defold_nvim_switch_focus_on_continue = function(_, _)
        log.debug "debugger: continued"

        local sidecar = require "defold.sidecar"

        local rootdir = vim.fs.root(0, { "game.project", ".git" })

        local ok, err = pcall(sidecar.focus_game, rootdir)
        if not ok then
            log.error(string.format("Could not focus neovim: %s", err))
        end
    end
end

return M
