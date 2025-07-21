local defold = require "defold"
local project = require "defold.project"

local libs = { defold.defold_api_path() }

for _, lib in ipairs(project.dependency_api_paths()) do
    table.insert(libs, lib)
end

return {
    Lua = {
        runtime = {
            version = "LuaJIT",
        },
        workspace = {
            library = libs,
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
