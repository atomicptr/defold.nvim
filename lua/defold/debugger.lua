local M = {}

---@alias defold.debugger.Variant
---| "moonbug"
---| "mobdebug"
---| "local"

---@return defold.debugger.Variant
function M.infer_variant()
    local project = require "defold.project"
    local sidecar = require "defold.sidecar"
    local log = require "defold.service.logger"

    local root = project.project_root(false)
    if not root then
        return "local"
    end

    local ok, game_project = pcall(sidecar.read_game_project, vim.fs.joinpath(root, "game.project"))
    if not ok then
        log.error("Could not read game project: " .. tostring(game_project))
        return "local"
    end

    for _, dep in ipairs(game_project.dependencies or {}) do
        if string.find(dep, "defold-moonbug", 1, true) then
            return "moonbug"
        end

        if string.find(dep, "defold-mobdebug", 1, true) then
            return "mobdebug"
        end
    end

    return "local"
end

---@param config                    defold.Config
---@param install_when_not_present? boolean
---@return string|nil
function M.get_mobdap_path(config, install_when_not_present)
    local os = require "defold.service.os"
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    if config.debugger.mobdebug.mobdap_executable then
        return config.debugger.mobdebug.mobdap_executable
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

---@param config defold.Config
function M.setup(config)
    local variant = config.debugger.force_variant or M.infer_variant()

    if variant == "mobdebug" then
        -- make sure mobdap is available
        M.get_mobdap_path(config, true)
    end
end

---@param config defold.Config
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
local function register_moonbug_debugger(config)
    local dap = require "dap"

    dap.adapters.defold_nvim_moonbug = {
        id = "defold_nvim_moonbug",
        type = "server",
        port = os.getenv "MOONBUG_PORT" or config.debugger.moonbug.port or 8888,
    }

    dap.configurations.lua = {
        {
            type = "defold_nvim_moonbug",
            request = "attach",
            name = "defold.nvim: Launch Game & Attach",
            project_root_dir = "${workspaceFolder}",
            before = create_game_launcher(config),
            -- TODO: offer this only when no game is running
        },
        {
            type = "defold_nvim_moonbug",
            request = "attach",
            name = "defold.nvim: Attach",
            project_root_dir = "${workspaceFolder}",
        },
    }
end

---@param config defold.Config
local function register_mobdebug_debugger(config)
    local dap = require "dap"
    local project = require "defold.project"

    dap.adapters.defold_nvim_mobdebug = {
        id = "defold_nvim_mobdebug",
        type = "executable",
        command = M.get_mobdap_path(config),
        args = config.debugger.mobdebug.mobdap_arguments,
    }

    dap.configurations.lua = {
        {
            name = "defold.nvim: Debugger",
            type = "defold_nvim_mobdebug",
            request = "launch",

            rootdir = function()
                return project.project_root()
            end,

            sourcedirs = function()
                return project.dependency_api_paths()
            end,

            port = config.debugger.mobdebug.port or 18172,
        },
    }

    dap.listeners.after["event_mobdap_waiting_for_connection"].defold_nvim_start_game = create_game_launcher(config)
end

---@param config defold.Config
function M.register_nvim_dap(config)
    if not config.debugger.enable then
        return
    end

    local log = require "defold.service.logger"
    local project = require "defold.project"

    local dap_installed, dap = pcall(require, "dap")
    if not dap_installed then
        log.warn "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

    local variant = config.debugger.force_variant or M.infer_variant()

    if variant == "moonbug" then
        register_moonbug_debugger(config)
    elseif variant == "mobdebug" then
        register_mobdebug_debugger(config)
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
