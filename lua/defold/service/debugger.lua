local editor = require "defold.editor"
local os = require "defold.service.os"
local project = require "defold.project"
local babashka = require "defold.service.babashka"
local log = require "defold.service.logger"

local M = {}

M.custom_executable = nil
M.custom_arguments = nil
M.path = nil

---@return string|nil
function M.mobdap_path()
    if M.custom_executable then
        return M.custom_executable
    end

    if os.command_exists "mobdap" then
        return vim.fn.exepath "mobdap"
    end

    if M.path then
        return M.path
    end

    local res = babashka.run_task_json "mobdap-path"

    if res.status ~= 200 then
        log.error("Unable to locate debugger: " .. vim.inspect(res))
        return nil
    end

    M.path = res.mobdap_path
    return res.mobdap_path
end

---@param custom_executable string|nil
---@param custom_arguments table<string>|nil
function M.setup(custom_executable, custom_arguments)
    M.custom_executable = custom_executable
    M.custom_arguments = custom_arguments

    M.mobdap_path()
end

function M.register_nvim_dap()
    local ok, dap = pcall(require, "dap")

    if not ok then
        log.error "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

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
                local libs = { project.defold_api_path() }

                for _, lib in ipairs(project.dependency_api_paths()) do
                    table.insert(libs, lib)
                end

                return libs
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

        local rootdir = vim.fs.root(0, { "game.project", ".git" })
        babashka.run_task_json("focus-neovim", { rootdir })
    end

    dap.listeners.after.continue.defold_nvim_switch_focus_on_continue = function(_, _)
        log.debug "debugger: continued"

        local rootdir = vim.fs.root(0, { "game.project", ".git" })
        babashka.run_task_json("focus-game", { rootdir })
    end
end

return M
