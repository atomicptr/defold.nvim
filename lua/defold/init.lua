---@class DefoldConfig
local default_config = {}

local M = {}

---@type DefoldConfig
M.config = default_config

---@return string
function M.defold_api_path()
    local script_path = debug.getinfo(1, "S").source
    if not string.sub(script_path, 1, 1) == "@" then
        vim.notify("Could not find Defold API files", vim.log.levels.ERROR)
        return ""
    end
    local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2))))
    return vim.fs.joinpath(plugin_root, "data", "defold_api")
end

---@param opts DefoldConfig
function M.setup(opts)
    print "Setup Called"
    M.config = vim.tbl_extend("force", M.config, opts)
end

return M
