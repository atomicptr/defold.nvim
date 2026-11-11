local M = {}

---@alias defold.debugger.Variant
---| "native"
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

    return "native"
end

function M.setup()
    local config = require "defold.config"
    local variant = config.state.debugger.force_variant or M.infer_variant()

    if variant == "mobdebug" then
        require("defold.debugger.mobdebug").setup()
    end
end

function M.register_nvim_dap()
    local config = require "defold.config"
    if not config.state.debugger.enable then
        return
    end

    local log = require "defold.service.logger"
    local project = require "defold.project"

    local dap_installed, dap = pcall(require, "dap")
    if not dap_installed then
        log.warn "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

    local variant = config.state.debugger.force_variant or M.infer_variant()

    if variant == "native" then
        require("defold.debugger.native").register()
    elseif variant == "moonbug" then
        require("defold.debugger.moonbug").register()
    elseif variant == "mobdebug" then
        require("defold.debugger.mobdebug").register()
    end

    ---@param session dap.Session
    dap.listeners.after.event_stopped.defold_nvim_switch_focus_on_stop = function(session)
        if not (session.config.type or ""):match "^defold_nvim_" then
            return
        end

        log.debug "debugger: event stopped"

        local sidecar = require "defold.sidecar"
        local rootdir = project.project_root()

        local ok, err = pcall(sidecar.focus_neovim, rootdir)
        if not ok then
            log.error(string.format("Could not focus neovim: %s", err))
        end
    end

    ---@param session dap.Session
    dap.listeners.after.event_continued.defold_nvim_switch_focus_on_continue = function(session)
        if not (session.config.type or ""):match "^defold_nvim_" then
            return
        end

        log.debug "debugger: continued"

        local sidecar = require "defold.sidecar"
        local rootdir = project.project_root()

        local ok, err = pcall(sidecar.focus_game, rootdir)
        if not ok then
            log.error(string.format("Could not focus game: %s", err))
        end
    end
end

return M
