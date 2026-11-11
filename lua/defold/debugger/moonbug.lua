local M = {}

function M.register()
    local config = require "defold.config"
    local dap = require "dap"

    dap.adapters.defold_nvim_moonbug = {
        id = "defold_nvim_moonbug",
        type = "server",
        port = os.getenv "MOONBUG_PORT" or config.state.debugger.moonbug.port or 8888,
    }

    dap.configurations.lua = {
        {
            type = "defold_nvim_moonbug",
            request = "attach",
            name = "defold.nvim: Launch Game & Attach",
            project_root_dir = "${workspaceFolder}",
            before = function()
                require("defold.service.logger").debug "debugger: connected"
                require("defold.editor").run_game "send"
            end,
            -- TODO: offer this only when no game is running
        },
        {
            type = "defold_nvim_moonbug",
            request = "attach",
            name = "defold.nvim: Attach",
            project_root_dir = "${workspaceFolder}",
        },
    }
end

return M
