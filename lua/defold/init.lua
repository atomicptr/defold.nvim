local root_markers = { "game.project" }

---@class DefoldEditorSettings Settings for the Defold Game Engine
---@field set_default_editor boolean Automatically set defold.nvim as the default editor in Defold
---@field auto_fetch_dependencies boolean Automatically fetch dependencies on launch
---@field hot_reload_enabled boolean Enable hot reloading when saving scripts in Neovim

---@class LauncherSettings Settings for the Neovim launcher run by Defold
---@field type "neovide"|"terminal" Neovim launcher run by Defold
---@field executable string|nil Executable to be used by the launcher, nil means we're trying to figure this out ourselves
---@field extra_arguments table<string>|nil Extra arguments passed to the `executable` (or neovide)
---@field terminal TerminalLauncherSettings|nil Settings for running via terminal

---@class TerminalLauncherSettings
---@field class_argument string|nil Argument to define the class name, usually something like "--class="
---@field run_argument   string|nil Argument to define the run argument, usually something like "-e"

---@class DebuggerSettings Settings for the integrated debugger
---@field enable boolean Enable the debugger
---@field custom_executable string|nil Use a custom executable for the debugger
---@field custom_arguments table<string>|nil Custom arguments for the debugger

---@class BabashkaSettings Settings for the integrated Babashka interpreter
---@field custom_executable string|nil Use a custom executable for babashka

---@class DefoldNvimConfig Settings for defold.nvim
---@field defold DefoldEditorSettings Settings for the Defold Game Engine
---@field launcher LauncherSettings Settings for the Neovim launcher run by Defold
---@field debugger DebuggerSettings Settings for the integrated debugger
---@field babashka BabashkaSettings Settings for the integrated Babashka interpreter
---@field force_plugin_enabled boolean Force the plugin to be always enabled (even if we can't find the game.project file)

---@type DefoldNvimConfig
local default_config = {
    defold = {
        set_default_editor = true,
        auto_fetch_dependencies = true,
        hot_reload_enabled = true,
        launcher = "neovide",
    },

    launcher = {
        type = "neovide",
        executable = nil,
        extra_arguments = nil,
        terminal = nil,
    },

    debugger = {
        enable = true,
        custom_executable = nil,
        custom_arguments = nil,
    },

    babashka = {
        custom_executable = nil,
    },

    force_plugin_enabled = false,
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

---@param opts DefoldNvimConfig|nil
function M.setup(opts)
    local babashka = require "defold.service.babashka"
    local log = require "defold.service.logger"

    M.config = vim.tbl_deep_extend("force", default_config, opts or {})

    -- persist config for babashka
    local config_path = babashka.config_path()
    vim.fn.writefile({
        vim.fn.json_encode {
            data_dir = vim.fn.stdpath "data",
            bb_path = babashka.bb_path(),
            plugin_config = M.config,
        },
    }, config_path)

    -- add setup defold command
    vim.api.nvim_create_user_command("SetupDefold", function()
        local debugger = require "defold.service.debugger"

        local ok = babashka.setup(M.config.babashka.custom_executable)

        if not ok then
            return
        end

        babashka.run_task "set-default-editor"

        if M.config.debugger.enable then
            debugger.setup(M.config.debugger.custom_executable, M.config.debugger.custom_arguments)
        end

        log.info "Defold setup successfully"
    end, { nargs = 0, desc = "Setup Defold to use Neovim as its default editor" })

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

                -- cant connect to client?
                local client = vim.lsp.get_client_by_id(ev.data.client_id)
                if not client then
                    return
                end

                local lsp_config = require "defold.config.lsp"

                log.debug(string.format("For %s, loaded lsp config %s", root, vim.inspect(lsp_config)))

                client.root_dir = root
                client.settings = vim.tbl_deep_extend("force", client.settings or {}, lsp_config)

                -- load plugin, if not already loaded
                M.load_plugin()
            end
        end,
    })

    vim.defer_fn(function()
        local debugger = require "defold.service.debugger"

        -- prepare plugin components before loading
        local ok = babashka.setup(M.config.babashka.custom_executable)

        if not ok then
            return
        end

        if M.config.defold.set_default_editor then
            babashka.run_task_json "set-default-editor"
        end

        if M.config.debugger.enable then
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

function M.load_plugin()
    if M.loaded then
        return
    end

    M.loaded = true

    local babashka = require "defold.service.babashka"
    local debugger = require "defold.service.debugger"
    local editor = require "defold.editor"
    local log = require "defold.service.logger"
    local project = require "defold.project"
    local snippets = require "defold.service.snippets"

    log.debug "============= defold.nvim: Loaded plugin"
    log.debug("Babashka Path: " .. babashka.bb_path())
    log.debug("Mobdap Path: " .. debugger.mobdap_path())
    log.debug("Config: " .. vim.inspect(M.config))

    -- register hot reload when saving lua files
    if M.config.defold.hot_reload_enabled then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.lua", "*.script", "*.gui_script" },
            callback = function()
                editor.send_command("hot-reload", true)
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

            editor.send_command(cmds[idx])
        end)
    end, { nargs = 0, desc = "Select a command to run" })

    -- add the ":DefoldSend cmd" command to send commands to the editor
    vim.api.nvim_create_user_command("DefoldSend", function(opt)
        editor.send_command(opt.args)
    end, { nargs = 1, desc = "Send a command to the Defold editor" })

    -- add the ":DefoldFetch" command to fetch dependencies & annoatations
    vim.api.nvim_create_user_command("DefoldFetch", function(opt)
        -- when a user runs DefoldFetch I recon they also expect us to update the dependencies
        editor.send_command("fetch-libraries", true)

        project.install_dependencies(opt.bang)
    end, { bang = true, nargs = 0, desc = "Fetch & create Defold project dependency annotations" })

    -- integrate the debugger into dap
    if M.config.debugger.enable then
        debugger.register_nvim_dap()
    end

    -- add snippets
    snippets.install()

    -- fetch dependencies
    if M.config.defold.auto_fetch_dependencies then
        project.install_dependencies(false)
    end
end

return M
