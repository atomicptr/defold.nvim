local babashka = require "defold.service.babashka"
local editor = require "defold.editor"
local project = require "defold.project"

local root_markers = { "game.project", ".git" }

---@class DefoldConfig
local default_config = {
    hot_reload_enabled = true,
    auto_fetch_dependencies = true,
    always_enable_plugin = false,
    set_neovim_as_default_editor = true,
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
    return vim.fs.joinpath(plugin_root, "resources", "defold_api")
end

---Returns true if we are in a defold project
---@return boolean
function M.is_defold_project()
    local root_dir = vim.fs.root(0, root_markers)

    if not root_dir then
        return false
    end

    return vim.fn.filereadable(root_dir .. "/game.project") == 1
end

function M.prepare()
    babashka.setup {
        set_editor = M.config.set_neovim_as_default_editor,
    }
end

---@param opts DefoldConfig|nil
function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})

    M.prepare()

    vim.api.nvim_create_user_command("SetupDefold", function()
        babashka.run_task("set-default-editor", { babashka.setup {
            set_editor = true,
        } })

        vim.notify "defold.nvim: Defold setup successfully"
    end, { nargs = 0, desc = "Setup Defold to use Neovim as its default editor" })

    -- dont actually setup the project unless we are in a Defold project
    if M.config.always_enable_plugin or not M.is_defold_project() then
        return
    end

    -- init babashka
    babashka.run_task("init", {})

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
                editor.send_command("hot-reload", true)
            end,
        })
    end

    vim.api.nvim_create_user_command("Defold", function()
        local cmds = {}
        local options = {}

        local commands = editor.list_commands()

        if not commands then
            return
        end

        for cmd, desc in pairs(commands) do
            table.insert(cmds, cmd)
            table.insert(options, string.format("%s - %s", cmd, desc))
        end

        vim.ui.select(options, {
            prompt = "Select a command to run:",
        }, function(choice, idx)
            if not choice then
                return
            end

            editor.send_command(cmds[idx])
        end)
    end, { nargs = 0, desc = "Select a command to run" })

    vim.api.nvim_create_user_command("DefoldSend", function(opt)
        editor.send_command(opt.args)
    end, { nargs = 1, desc = "Send a command to the Defold editor" })

    vim.api.nvim_create_user_command("DefoldFetch", function(opt)
        project.install_dependencies(opt.bang)
    end, { bang = true, nargs = 0, desc = "Fetch & create Defold project dependency annotations" })

    if M.config.auto_fetch_dependencies then
        project.install_dependencies(false)
    end
end

return M
