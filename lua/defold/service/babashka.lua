local os = require "defold.service.os"
local fs = require "defold.service.fs"
local http = require "defold.service.http"

local bb_version = "1.12.206"
local bb_url = "https://github.com/babashka/babashka/releases/download/v%s/babashka-%s-%s-%s.%s"

local M = {}

local function local_bb()
    local bb_path = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "bin", "bb")

    if fs.file_exists(bb_path) then
        return bb_path
    end

    vim.fn.mkdir(vim.fs.dirname(bb_path), "p")

    local url = string.format(bb_url, bb_version, bb_version, os.name(), os.architecture(), "tar.gz")

    local download_path = bb_path .. ".tar.gz"

    http.download(url, download_path)

    vim.fn.system(string.format("tar -xf '%s' -C '%s'", download_path, vim.fs.dirname(bb_path)))
    vim.fn.system(string.format("chmod +x '%s'", bb_path))

    vim.fs.rm(download_path)

    return bb_path
end

local function bb_path()
    if os.command_exists "bb" then
        return vim.fn.exepath "bb"
    end

    return local_bb()
end

local function bb_edn_path()
    local script_path = debug.getinfo(1, "S").source
    if not string.sub(script_path, 1, 1) == "@" then
        vim.notify("Could not find bb.edn", vim.log.levels.ERROR)
        return ""
    end
    local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2)))))
    return vim.fs.joinpath(plugin_root, "bb.edn")
end

function M.run_task(task, args)
    local params = table.concat(args or {}, " ")
    local cmd = string.format("%s --config '%s' run %s %s", bb_path(), bb_edn_path(), task, params)
    return vim.fn.system(cmd)
end

function M.run_task_json(task, args)
    local res = M.run_task(task, args)
    return vim.json.decode(res)
end

return M
