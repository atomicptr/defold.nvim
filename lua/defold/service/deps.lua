local http = require "defold.service.http"
local fs = require "defold.service.fs"
local zip = require "defold.service.zip"
local babashka = require "defold.service.babashka"

local M = {}

function M.dependency_install_root()
    local root = vim.fs.root(0, { "game.project", ".git" })

    if not root then
        vim.notify("Could not find game.project file, not a Defold project?", vim.log.levels.ERROR)
        return nil
    end

    return vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "dependencies", root)
end

function M.dependency_cache_root(url)
    local parts = vim.fn.split(url, "/", false)
    table.remove(parts, 1) -- remove https:

    local file_path = table.concat(parts, "/")

    return vim.fs.joinpath(vim.fn.stdpath "cache", "defold.nvim", "download", file_path)
end

local function find_script_api_files(in_dir)
    return vim.fs.find(function(name)
        -- string ends with .script_api
        return string.sub(name, -(string.len ".script_api")) == ".script_api"
    end, { type = "file", path = in_dir })
end

function M.install_dependency(url)
    if string.sub(url, -4) ~= ".zip" then
        vim.notify(string.format("Tried to install %s, only zip files are supported", url), vim.log.levels.ERROR)
        return
    end

    local download_path = M.dependency_cache_root(url)
    local download_root = vim.fs.dirname(download_path)
    vim.fn.mkdir(download_root, "p")

    if not fs.file_exists(download_path) then
        http.download(url, download_path)
    end

    local files = vim.fs.find("game.project", { type = "file", path = download_root })

    if vim.tbl_isempty(files) then
        zip.extract(download_path, download_root)
    end

    -- re-search because we might have extracted the zip now
    files = vim.fs.find("game.project", { type = "file", path = download_root })

    if vim.tbl_isempty(files) then
        vim.notify(string.format("Could not find 'game.project' file in %s", download_path), vim.log.levels.ERROR)
        return
    end

    local pattern = "include_dirs%s*=%s*(.+)$"

    local include_dirs = {}

    -- find all include_dirs in project
    for _, file in ipairs(files) do
        local gp_dir = vim.fs.dirname(file)

        for line in io.lines(file) do
            local _, _, dirs = line:find(pattern)

            if dirs then
                local ds = vim.fn.split(dirs, ",", false)

                for _, d in ipairs(ds) do
                    table.insert(include_dirs, vim.fs.joinpath(gp_dir, d))
                end

                break
            end
        end
    end

    local install_root = M.dependency_install_root()

    if not install_root then
        return
    end

    vim.fn.mkdir(install_root, "p")

    for _, include_dir in ipairs(include_dirs) do
        for _, file in ipairs(find_script_api_files(include_dir)) do
            local res = babashka.run_task("compile-script-api", { file })

            local basename = vim.fs.basename(file)
            local filename = basename:sub(0, string.len(basename) - string.len ".script_api")
            local path = vim.fs.joinpath(include_dir, filename .. ".lua")

            local f = io.open(path, "w")
            if not f then
                return
            end
            f:write(res)
            f:close()
        end

        local target_dir = vim.fs.joinpath(install_root, vim.fs.dirname(include_dir))

        -- skip if already exists...
        if not fs.file_exists(target_dir) then
            vim.fn.system(string.format("cp -r '%s' '%s'", include_dir, install_root))
        end
    end
end

return M
