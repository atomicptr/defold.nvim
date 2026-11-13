local M = {}

---@param client vim.lsp.Client
---@return boolean
function M.matches(client)
    -- lua-language-server may be registered under another name (e.g. luals, sumneko_lua)
    local cmd = client.config.cmd
    return client.name == "lua_ls" or (type(cmd) == "table" and vim.fs.basename(cmd[1] or "") == "lua-language-server")
end

---@return table
function M.settings()
    return {
        Lua = {
            runtime = {
                version = "LuaJIT",
            },
            workspace = {
                library = require("defold.project").dependency_api_paths(),
            },
        },
    }
end

return M
