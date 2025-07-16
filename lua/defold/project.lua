local deps = require "defold.service.deps"

local M = {}

function M.find_dependencies()
    local root = vim.fs.root(0, { "game.project" })

    if not root then
        vim.notify("Could not find game.project file, not a Defold project?", vim.log.levels.ERROR)
        return {}
    end

    local deps = {}

    local pattern = "dependencies#%d+%s*=%s*(.+)$"

    for line in io.lines(vim.fs.joinpath(root, "game.project")) do
        local _, _, url = line:find(pattern)

        if url then
            table.insert(deps, url)
        end
    end

    return deps
end

---@param force_redownload boolean
function M.install_dependencies(force_redownload)
    if force_redownload or false then
        local root = deps.dependency_install_root()
        if root then
            vim.fs.rm(root, { recursive = true, force = true })
        end
    end

    for _, url in ipairs(M.find_dependencies()) do
        vim.notify(string.format("installing %s...", url))

        if force_redownload then
            local root = deps.dependency_cache_root(url)
            if root then
                vim.fs.rm(root, { recursive = true, force = true })
            end
        end

        deps.install_dependency(url)
    end
end

return M
