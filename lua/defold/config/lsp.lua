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
        },
    }
end
