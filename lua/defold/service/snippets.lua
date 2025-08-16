local M = {}

function M.install()
    local os = require "defold.service.os"

    local ok, luasnip = pcall(require, "luasnip.loaders.from_vscode")
    if not ok then
        return
    end

    luasnip.lazy_load { paths = { os.plugin_root() } }
end

return M
