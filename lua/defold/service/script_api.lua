local bb = require "defold.service.babashka"

local M = {}

local function compiler_script()
    local script_path = debug.getinfo(1, "S").source
    if not string.sub(script_path, 1, 1) == "@" then
        vim.notify("Could not find script_api compiler script", vim.log.levels.ERROR)
        return ""
    end
    local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2)))))
    return vim.fs.joinpath(plugin_root, "scripts", "compile-script-api.clj")
end

function M.compile_file(file)
    return bb.execute_file(compiler_script(), { file })
end

return M
