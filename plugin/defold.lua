local editor = require "defold.editor"
local utils = require "defold.utils"

local root_markers = { "game.project" }

-- register filetypes
vim.filetype.add(require "defold.config.filetype")

-- attach to lsp
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local ft = vim.filetype.match { buf = ev.buf }

        if ft == "lua" then
            local root = vim.fs.root(ev.buf, root_markers)

            -- not a defold project?
            if not root then
                return
            end

            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            if not client then
                return
            end

            client.root_dir = root
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, require "defold.config.lsp")
        end
    end,
})

-- register commands
local function fetch_commands()
    local commands = editor.list_commands()

    for cmd, description in pairs(commands) do
        vim.api.nvim_create_user_command("DefoldCmd" .. utils.kebab_case_to_pascal_case(cmd), function()
            editor.send_command(cmd)
        end, { nargs = 0, desc = description })
    end
end

vim.api.nvim_create_user_command("DefoldRefreshCommands", function()
    fetch_commands()
end, { nargs = 0, desc = "Refresh the Defold editor provided commands" })

vim.api.nvim_create_user_command("DefoldSend", function(opt)
    editor.send_command(opt.args)
end, { nargs = 1, desc = "Send a command to the Defold editor directly" })

fetch_commands()
