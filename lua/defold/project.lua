local babashka = require "defold.service.babashka"
local os = require "defold.service.os"

local M = {}

local function game_project_file()
    local root = vim.fs.root(0, { "game.project" })

    if not root then
        vim.notify("Could not find game.project file, not a Defold project?", vim.log.levels.ERROR)
        return {}
    end

    return '"' .. vim.fs.joinpath(root, "game.project") .. '"'
end

---@return string
function M.defold_api_path()
    local plugin_root = os.plugin_root()
    return vim.fs.joinpath(plugin_root, "resources", "defold_api")
end

function M.dependency_api_paths()
    local res = babashka.run_task_json("list-dependency-dirs", { game_project_file() })
    return res.dirs
end

---@param force_redownload boolean
function M.install_dependencies(force_redownload)
    local args = { game_project_file() }

    if force_redownload then
        table.insert(args, "force")
    end

    local res = babashka.run_task_json("install-dependencies", args)

    if res.error then
        vim.notify(string.format("Could not install dependencies, because: %s", res.error), vim.log.levels.ERROR)
        return
    end
end

return M
