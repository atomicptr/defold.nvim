local M = {}

---Plugin setup is done
local setup_done = false

---Plugin got actually loaded
local plugin_loaded = false

---@return string
function M.plugin_root()
    local os = require "defold.os"
    return os.plugin_root()
end

---@param opts? defold.Config
function M.setup(opts)
    local config = require "defold.config"
    local log = require "defold.logger"

    if config.state.game_runner.mode == nil then
        local os = require "defold.os"

        -- Use editor commands on Windows instead of :make.
        config.state.game_runner.mode = os.is_windows() and "send" or "make"
    end

    config.apply(opts)

    if config.state.debug then
        config.state.launcher.debug = true
    end

    if not config.state.setup_make then
        config.state.game_runner.mode = "send"
    end

    -- only warn for user provided options, setup is re-run without them after downloading the sidecar
    local focus = config.state.focus
    if opts and opts.focus and focus.enable then
        if focus.type ~= "custom" and (focus.nvim_arguments or focus.game_arguments) then
            log.warn 'focus.nvim_arguments and focus.game_arguments are only used with focus.type = "custom"'
        end

        if focus.type == "auto" and focus.executable then
            log.warn 'focus.executable is ignored with focus.type = "auto"'
        end

        if focus.type == "custom" and (focus.executable or "") == "" then
            log.warn 'focus.type = "custom" requires focus.executable, falling back to "auto"'
        end
    end

    if setup_done or plugin_loaded then
        return
    end

    -- do filetype detection before the download
    vim.filetype.add(require("defold.filetype").minimal)

    local sidecar = require "defold.sidecar"
    if not sidecar.is_ready() then
        sidecar.ensure(M.setup)
        return
    end

    if config.state.debug then
        local ok, err = pcall(sidecar.set_log_level, "debug")
        if not ok then
            log.error(string.format("Could not setup sidecar: %s", err))
        end
    end

    require("defold.lsp").setup(M.load_plugin)

    setup_done = true

    vim.defer_fn(function()
        local project = require "defold.project"

        if project.is_defold_project() then
            project.ensure_nvim_server(config.state.launcher.socket_type)

            if config.state.debugger.enable then
                require("defold.debugger").setup()
            end
        end

        if config.state.defold.set_default_editor then
            project.setup_neovide()
            M.setup_default_editor()
        end

        if not config.state.force_plugin_enabled and not project.is_defold_project() then
            local root_dir = project.project_root()
            log.debug(string.format("Project was not loaded because: '%s' was not a Defold project", root_dir))
            return
        end

        M.load_plugin()
    end, 0)
end

function M.load_plugin()
    if plugin_loaded then
        return
    end

    plugin_loaded = true

    local config = require "defold.config"

    -- register all filetypes
    vim.filetype.add(require("defold.filetype").full)

    local sidecar = require "defold.sidecar"
    local debugger = require "defold.debugger"
    local editor = require "defold.editor"
    local log = require "defold.logger"
    local lsp = require "defold.lsp"
    local project = require "defold.project"

    log.debug "============= defold.nvim: Loaded plugin"

    local project_root = project.project_root(false)

    log.debug(string.format("Project Root: %s", project_root))
    log.debug(string.format("Plugin Version: %s", require "defold.version"))
    log.debug(string.format("Sidecar Version: %s", sidecar.version))

    log.debug(string.format("Bridge Path: %s", sidecar.bridge_path))

    if config.state.debugger.enable then
        log.debug(
            string.format("Debugger Variant: %s", config.state.debugger.force_variant or debugger.infer_variant())
        )
    end

    log.debug(string.format("Config: %s", vim.inspect(config.state)))

    -- register hot reload when saving lua files
    if config.state.defold.hot_reload_enabled then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.lua", "*.script", "*.gui_script" },
            callback = function(ev)
                if not project.is_buffer_in_project(ev.buf) then
                    return
                end

                local res = editor.send_command("hot-reload", true)

                if config.state.quickfix.enable then
                    editor.open_quickfix_from_command_result(res)
                end
            end,
        })
    end

    -- integrate with `:make`
    if config.state.setup_make then
        local make_cmd = string.format(
            '"%s" build-game "%s" --min-severity %s',
            sidecar.bridge_path,
            project.project_root(),
            config.state.quickfix.min_severity
        )

        if not config.state.game_runner.show_logs then
            make_cmd = make_cmd .. " --disable-logs"
        end

        log.debug(string.format("`:make` command: %s", make_cmd))

        vim.opt.makeprg = make_cmd
        vim.opt.errorformat = config.state.game_runner.errorformat
    end

    -- add the :Defold command for interacting with the editor
    vim.api.nvim_create_user_command("Defold", function()
        local options = {}

        local commands = editor.list_commands()

        if not commands then
            return
        end

        for _, cmd in ipairs(commands) do
            -- hide debugger related commands as they'd give the user the impression that these
            -- work with our debugger integration
            local is_debugger_command = string.find(cmd, "debugger")

            if not is_debugger_command then
                table.insert(options, cmd)
            end
        end

        vim.ui.select(options, {
            prompt = "Select a command to run:",
        }, function(choice)
            if not choice then
                return
            end

            editor.send_command(choice)
        end)
    end, { nargs = 0, desc = "Select a command to run" })

    -- add the ":DefoldSend cmd" command to send commands to the editor
    vim.api.nvim_create_user_command("DefoldSend", function(opt)
        local res = editor.send_command(opt.args)

        if config.state.quickfix.enable then
            editor.open_quickfix_from_command_result(res)
        end
    end, { nargs = 1, desc = "Send a command to the Defold editor" })

    -- add the ":DefoldRun" command to run the game
    vim.api.nvim_create_user_command("DefoldRun", function()
        editor.run_game()
    end, { nargs = 0, desc = "Run the game through Defold" })

    -- add the ":DefoldFetch" command to fetch dependencies & annoatations
    vim.api.nvim_create_user_command("DefoldFetch", function(opt)
        -- when a user runs DefoldFetch I recon they also expect us to update the dependencies
        editor.send_command("fetch-libraries", true)

        project.install_dependencies(opt.bang, lsp.update)
    end, { bang = true, nargs = 0, desc = "Fetch & create Defold project dependency annotations" })

    -- integrate the debugger into dap
    debugger.register_nvim_dap()

    -- integrate supported completion systems
    require("defold.completions").register()

    -- add snippets
    require("defold.snippets").install()

    -- add icons
    require("defold.icons").install()

    -- when a project is first opened, try to figure out the engine version
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
            project.refresh_annotations(lsp.update)
        end,
    })

    project.refresh_annotations(lsp.update)

    if config.state.defold.auto_fetch_dependencies then
        project.install_dependencies(false, lsp.update)
    end

    lsp.update()
end

---Sets Neovim as the default Defold editor
function M.setup_default_editor()
    local config = require "defold.config"
    local project = require "defold.project"
    local log = require "defold.logger"

    local port = project.editor_port()

    if not port then
        return
    end

    local sidecar = require "defold.sidecar"
    local ok, err =
        pcall(sidecar.set_default_editor, port, sidecar.bridge_path, config.state.launcher, config.state.focus)

    if not ok then
        log.error(string.format("Could not set default editor because: %s", err))
    elseif err then
        log.warn(string.format('Invalid focus config, falling back to "auto": %s', err))
    end
end

---Makes sure the required plugin components are installed and loaded
---@param callback? fun() Callback called when the plugin components are ready
function M.download(callback)
    require("defold.sidecar").ensure(callback)
end

---Deletes all defold.nvim managed resources, restart Neovim after calling this
function M.repair()
    require("defold.repair").schedule()
end

return M
