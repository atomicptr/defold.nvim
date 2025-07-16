local defold = require "defold"
local deps = require "defold.service.deps"

return {
    Lua = {
        runtime = {
            version = "LuaJIT",
        },
        workspace = {
            library = { "lua", defold.defold_api_path(), deps.dependency_install_root() },
        },
        diagnostics = {
            globals = {
                "final",
                "fixed_update",
                "init",
                "on_input",
                "on_message",
                "on_reload",
                "update",
            },
        },
    },
}
