local defold = require "defold"

local root_markers = { "game.project" }

-- register commands
-- TODO: register commands

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
