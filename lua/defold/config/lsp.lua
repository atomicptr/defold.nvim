return function()
    local project = require "defold.project"

    return {
        Lua = {
            runtime = {
                version = "LuaJIT",
            },
            workspace = {
                library = project.dependency_api_paths(),
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
end
