local M = {}

local function game_project_root()
    local log = require "defold.service.logger"

    local root = vim.fs.root(0, { "game.project" })

    if not root then
        log.error "Could not find game.project file, not a Defold project?"
        return {}
    end

    return root
end

function M.dependency_api_paths()
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.list_dependency_dirs, game_project_root())
    if not ok then
        log.error(string.format("Could not get dependency paths because: %s", res))
        return {}
    end

    return res
end

---@param force_redownload boolean
function M.install_dependencies(force_redownload)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.install_dependencies, game_project_root(), force_redownload or false)
    if not ok then
        log.error(string.format("Could not install dependencies because: %s", res))
        return
    end
end

return M
