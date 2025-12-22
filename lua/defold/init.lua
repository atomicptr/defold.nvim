local root_markers = { "game.project" }

---@class DefoldEditorSettings Settings for the Defold Game Engine
---@field set_default_editor boolean Automatically set defold.nvim as the default editor in Defold
---@field auto_fetch_dependencies boolean Automatically fetch dependencies on launch
---@field hot_reload_enabled boolean Enable hot reloading when saving scripts in Neovim

---@class LauncherSettings Settings for the Neovim launcher run by Defold
---@field type "neovide"|"terminal" Neovim launcher run by Defold
---@field executable string|nil Executable to be used by the launcher, nil means we're trying to figure this out ourselves
---@field socket_type "fsock"|"netsock"|nil Run Neovims RPC protocol over file socket or network. Nil means it will be picked automatic (fsock on Unix, network on Windows)
---@field arguments table<string>|nil Extra arguments passed to the `executable` (or neovide)
---@field debug boolean|nil Enable debug settings for the bridge cli

---@class DebuggerSettings Settings for the integrated debugger
---@field enable boolean Enable the debugger
---@field custom_executable string|nil Use a custom executable for the debugger
---@field custom_arguments table<string>|nil Custom arguments for the debugger

---@class Keymap
---@field mode string|string[]
---@field mapping string

---@class DefoldNvimConfig Settings for defold.nvim
---@field defold DefoldEditorSettings Settings for the Defold Game Engine
---@field launcher LauncherSettings Settings for the Neovim launcher run by Defold
---@field debugger DebuggerSettings Settings for the integrated debugger
---@field keymaps table<string, Keymap>|nil Settings for key -> action mappings
---@field force_plugin_enabled boolean Force the plugin to be always enabled (even if we can't find the game.project file)
---@field debug boolean Enable debug settings for the plugin

---@type DefoldNvimConfig
local default_config = {
    defold = {
        set_default_editor = true,
        auto_fetch_dependencies = true,
        hot_reload_enabled = true,
    },

    launcher = {
        type = "neovide",
        executable = nil,
        arguments = nil,
    },

    debugger = {
        enable = true,
        custom_executable = nil,
        custom_arguments = nil,
    },

    keymaps = {
        build = {
            mode = { "n", "i" },
            mapping = "<C-b>",
        },
    },

    force_plugin_enabled = false,
    debug = false,
}

local M = {}

---@type boolean
M.loaded = false

---@type DefoldNvimConfig
M.config = default_config

---Returns true if we are in a defold project
---@return boolean
function M.is_defold_project()
    local root_dir = vim.fs.root(0, root_markers)

    if not root_dir then
        return false
    end

    return vim.fn.filereadable(root_dir .. "/game.project") == 1
end

---@return string
function M.plugin_root()
    local os = require "defold.service.os"
    return os.plugin_root()
end

local function update_lua_lsp_paths()
    local clients = vim.lsp.get_clients { name = "lua_ls" }

    local lsp_config = (require "defold.config.lsp")()

    for _, client in ipairs(clients) do
        client.settings = vim.tbl_deep_extend("force", client.settings or {}, lsp_config)

        client:notify("workspace/didChangeConfiguration", {
            settings = client.settings,
        })
    end
end

---@param opts DefoldNvimConfig|nil
function M.setup(opts)
    if M.loaded then
        return
    end

    local log = require "defold.service.logger"

    M.config = vim.tbl_deep_extend("force", default_config, opts or {})

    if M.config.debug then
        M.config.launcher.debug = true

        local sidecar = require "defold.sidecar"
        local ok, err = pcall(sidecar.set_log_level, "debug")
        if not ok then
            log.error(string.format("Could not setup sidecar: %s", err))
        end
    end

    -- add setup defold command
    vim.api.nvim_create_user_command("SetupDefold", function()
        local sidecar = require "defold.sidecar"
        local ok, err = pcall(sidecar.set_default_editor, M.plugin_root(), M.config.launcher)
        if not ok then
            log.error(string.format("Could not set default editor because: %s", err))
        end

        if M.config.debugger.enable then
            local debugger = require "defold.service.debugger"
            debugger.setup(M.config.debugger.custom_executable, M.config.debugger.custom_arguments)
        end

        log.info "Defold setup successfully"
    end, { nargs = 0, desc = "Setup Defold to use Neovim as its default editor" })

    -- register some filetypes
    vim.filetype.add(require("defold.config.filetype").minimal)

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

                -- cant connect to client?
                local client = vim.lsp.get_client_by_id(ev.data.client_id)
                if not client then
                    return
                end

                local lsp_config = (require "defold.config.lsp")()

                log.debug(string.format("For %s, loaded lsp config %s", root, vim.inspect(lsp_config)))

                client.root_dir = root
                client.settings = vim.tbl_deep_extend("force", client.settings or {}, lsp_config)

                -- load plugin, if not already loaded
                M.load_plugin()
            end
        end,
    })

    vim.defer_fn(function()
        if M.config.defold.set_default_editor then
            local sidecar = require "defold.sidecar"
            local ok, err = pcall(sidecar.set_default_editor, M.plugin_root(), M.config.launcher)

            if not ok then
                log.error(string.format("Could not set default editor because: %s", err))
            end
        end

        if M.config.debugger.enable then
            local debugger = require "defold.service.debugger"
            debugger.setup(M.config.debugger.custom_executable, M.config.debugger.custom_arguments)
        end

        if not M.config.force_plugin_enabled and not M.is_defold_project() then
            local root_dir = vim.fs.root(0, root_markers)
            log.debug(string.format("Project was not loaded because: '%s' was not a Defold project", root_dir))
            return
        end

        M.load_plugin()
    end, 0)
end

---@return integer
function M.editor_port()
    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.find_editor_port)

    if ok then
        return res
    end

    local log = require "defold.service.logger"
    log.error(string.format("Could not find editor port, because: %s", res))

    return -1
end

---Makes sure the native library `sidecar` gets loaded
function M.download()
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local ok, err = pcall(sidecar.find_bridge_path, M.plugin_root())
    if not ok then
        log.error(string.format("Could not setup bridge: %s", err))
    end
end

function M.load_plugin()
    if M.loaded then
        return
    end

    M.loaded = true

    -- register all filetypes
    vim.filetype.add(require("defold.config.filetype").full)

    local sidecar = require "defold.sidecar"
    local debugger = require "defold.service.debugger"
    local editor = require "defold.editor"
    local log = require "defold.service.logger"
    local project = require "defold.project"

    log.debug "============= defold.nvim: Loaded plugin"
    log.debug("Sidecar Version: " .. sidecar.version)

    local bridge_ok, bridge_path = pcall(sidecar.find_bridge_path, M.plugin_root())
    if bridge_ok then
        log.debug("Bridge Path: " .. bridge_path)
    end

    if debugger.mobdap_path() then
        log.debug("Mobdap Path: " .. debugger.mobdap_path())
    end
    log.debug("Config: " .. vim.inspect(M.config))

    -- register hot reload when saving lua files
    if M.config.defold.hot_reload_enabled then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.lua", "*.script", "*.gui_script" },
            callback = function()
                editor.send_command(M.editor_port(), "hot-reload", true)
            end,
        })
    end

    -- add the :Defold command for interacting with the editor
    vim.api.nvim_create_user_command("Defold", function()
        local cmds = {}
        local options = {}

        local commands = editor.list_commands()

        if not commands then
            return
        end

        for cmd, desc in pairs(commands) do
            -- hide debugger related commands as they'd give the user the impression that these
            -- work with our debugger integration
            local is_debugger_command = string.find(cmd, "debugger")

            if not is_debugger_command then
                table.insert(cmds, cmd)
                table.insert(options, string.format("%s - %s", cmd, desc))
            end
        end

        vim.ui.select(options, {
            prompt = "Select a command to run:",
        }, function(choice, idx)
            if not choice then
                return
            end

            editor.send_command(M.editor_port(), cmds[idx])
        end)
    end, { nargs = 0, desc = "Select a command to run" })

    -- add the ":DefoldSend cmd" command to send commands to the editor
    vim.api.nvim_create_user_command("DefoldSend", function(opt)
        editor.send_command(M.editor_port(), opt.args)
    end, { nargs = 1, desc = "Send a command to the Defold editor" })

    -- add the ":DefoldFetch" command to fetch dependencies & annoatations
    vim.api.nvim_create_user_command("DefoldFetch", function(opt)
        -- when a user runs DefoldFetch I recon they also expect us to update the dependencies
        editor.send_command(M.editor_port(), "fetch-libraries", true)

        project.install_dependencies(opt.bang)

        update_lua_lsp_paths()
    end, { bang = true, nargs = 0, desc = "Fetch & create Defold project dependency annotations" })

    -- integrate the debugger into dap
    if M.config.debugger.enable then
        debugger.register_nvim_dap(M.editor_port)
    end

    -- add snippets
    require("defold.service.snippets").install()

    -- add icons
    require("defold.service.icons").install()

    -- setup keymaps
    for action, keymap in pairs(M.config.keymaps) do
        log.debug(string.format("Setup action '%s' for keymap '%s'", action, vim.json.encode(keymap)))

        vim.keymap.set(keymap.mode, keymap.mapping, function()
            editor.send_command(M.editor_port(), action)
        end)
    end

    -- fetch dependencies
    if M.config.defold.auto_fetch_dependencies then
        project.install_dependencies(false)
    end
end

return M
