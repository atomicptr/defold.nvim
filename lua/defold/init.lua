local editor = require "defold.editor"
local utils = require "defold.utils"

local root_markers = { "game.project" }

---@class DefoldConfig
local default_config = {
    hot_reload_enabled = true,
    register_editor_commands = true,
}

local M = {}

---@type DefoldConfig
M.config = default_config

---@return string
function M.defold_api_path()
    local script_path = debug.getinfo(1, "S").source
    if not string.sub(script_path, 1, 1) == "@" then
        vim.notify("Could not find Defold API files", vim.log.levels.ERROR)
        return ""
    end
    local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2))))
    return vim.fs.joinpath(plugin_root, "data", "defold_api")
end

---@param opts DefoldConfig|nil
function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})

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

    -- register hot reload when saving lua files
    if M.config.hot_reload_enabled then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.lua", "*.script" },
            callback = function()
                editor.send_command "hot-reload"
            end,
        })
    end

    -- register commands
    local function fetch_commands()
        local commands = editor.list_commands()

        for cmd, description in pairs(commands) do
            vim.api.nvim_create_user_command("DefoldCmd" .. utils.kebab_case_to_pascal_case(cmd), function()
                editor.send_command(cmd)
            end, { nargs = 0, desc = description })
        end
    end

    vim.api.nvim_create_user_command("DefoldSend", function(opt)
        editor.send_command(opt.args)
    end, { nargs = 1, desc = "Send a command to the Defold editor" })

    if M.config.register_editor_commands then
        vim.api.nvim_create_user_command("DefoldRefreshCommands", function()
            fetch_commands()
        end, { nargs = 0, desc = "Refresh the Defold editor provided commands" })

        fetch_commands()
    end
end

return M
