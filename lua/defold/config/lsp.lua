local defold = require "defold"

return {
    Lua = {
        runtime = {
            version = "LuaJIT",
        },
        workspace = {
            library = { "lua", defold.defold_api_path() },
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
