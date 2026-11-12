local M = {}

---@type boolean
M.loaded = false

---@return string
function M.plugin_root()
    local os = require "defold.service.os"
    return os.plugin_root()
end

local function update_lua_lsp_paths()
    local project = require "defold.project"
    local lsp = require "defold.config.lsp"
    local clients = vim.lsp.get_clients { name = "lua_ls" }

    local root = project.project_root()
    local lsp_config = lsp()

    for _, client in ipairs(clients) do
        if client.root_dir == root then
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, lsp_config)

            client:notify("workspace/didChangeConfiguration", {
                settings = client.settings,
            })
        end
    end
end

---@param opts? defold.Config
function M.setup(opts)
    local config = require "defold.config"

    if config.state.game_runner.mode == nil then
        local os = require "defold.service.os"

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

    if M.loaded then
        return
    end

    -- do filetype detection before the download
    vim.filetype.add(require("defold.config.filetype").minimal)

    local download = require "defold.download"
    if not download.is_ready() then
        download.download(M.setup)
        return
    end

    local log = require "defold.service.logger"

    if config.state.debug then
        local sidecar = require "defold.sidecar"
        local ok, err = pcall(sidecar.set_log_level, "debug")
        if not ok then
            log.error(string.format("Could not setup sidecar: %s", err))
        end
    end

    -- attach to lsp
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
            local ft = vim.filetype.match { buf = ev.buf }

            local project = require "defold.project"

            if ft == "lua" then
                local root = project.project_root()

                -- not a defold project?
                if not root then
                    return
                end

                -- cant connect to client?
                local client = vim.lsp.get_client_by_id(ev.data.client_id)
                if not client then
                    return
                end

                local lsp = require "defold.config.lsp"
                project.refresh_annotations()
                local lsp_config = lsp()

                log.debug(string.format("For %s, loaded lsp config %s", root, vim.inspect(lsp_config)))

                client.root_dir = root
                client.settings = vim.tbl_deep_extend("force", client.settings or {}, lsp_config)

                -- load plugin, if not already loaded
                M.load_plugin()
            end
        end,
    })

    vim.defer_fn(function()
        local project = require "defold.project"

        if project.is_defold_project() then
            project.ensure_nvim_server(config.state.launcher.socket_type)

            if config.state.debugger.enable then
                require("defold.debugger").setup()
            end
        end

        if config.state.defold.set_default_editor then
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

---Makes sure the native library `sidecar` gets loaded
---@param callback? fun() Callback called after Rust modules are ready
function M.download(callback)
    require("defold.download").download(callback)
end

---Deletes all defold.nvim managed resources, restart Neovim after calling this
function M.repair()
    require("defold.repair").schedule()
end

function M.load_plugin()
    if M.loaded then
        return
    end

    M.loaded = true

    local config = require "defold.config"

    -- register all filetypes
    vim.filetype.add(require("defold.config.filetype").full)

    local sidecar = require "defold.sidecar"
    local debugger = require "defold.debugger"
    local editor = require "defold.editor"
    local log = require "defold.service.logger"
    local project = require "defold.project"

    log.debug "============= defold.nvim: Loaded plugin"

    local project_root = project.project_root(false)

    log.debug("Project Root: " .. project_root)
    log.debug("Plugin Version: " .. require "defold.version")
    log.debug("Sidecar Version: " .. sidecar.version)

    local bridge_ok, bridge_path = pcall(sidecar.find_bridge_path, M.plugin_root())
    if bridge_ok then
        log.debug("Bridge Path: " .. bridge_path)
    end

    if config.state.debugger.enable then
        log.debug("Debugger Variant: " .. (config.state.debugger.force_variant or debugger.infer_variant()))
    end

    log.debug("Config: " .. vim.inspect(config.state))

    -- register hot reload when saving lua files
    if config.state.defold.hot_reload_enabled then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.lua", "*.script", "*.gui_script" },
            callback = function()
                local res = editor.send_command("hot-reload", true)

                if config.state.quickfix.enable then
                    editor.open_quickfix_from_command_result(res)
                end
            end,
        })
    end

    -- integrate with `:make`
    if config.state.setup_make and bridge_ok then
        local make_cmd = string.format(
            '"%s" build-game "%s" --min-severity %s',
            bridge_path,
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
        local cmds = {}
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
                table.insert(cmds, cmd)
                table.insert(options, cmd)
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

        project.install_dependencies(opt.bang)

        update_lua_lsp_paths()
    end, { bang = true, nargs = 0, desc = "Fetch & create Defold project dependency annotations" })

    -- integrate the debugger into dap
    debugger.register_nvim_dap()

    -- integrate completions into blink
    if config.state.completions.enable then
        local cmp = require "defold.cmp.blink"
        cmp.register()
    end

    -- add snippets
    require("defold.service.snippets").install()

    -- add icons
    require("defold.service.icons").install()

    -- when a project is first opened, try to figure out the engine version
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
            if project.refresh_annotations(update_lua_lsp_paths) then
                update_lua_lsp_paths()
            end
        end,
    })

    project.refresh_annotations(update_lua_lsp_paths)

    if config.state.defold.auto_fetch_dependencies then
        project.install_dependencies(false)
    end

    update_lua_lsp_paths()
end

---Sets Neovim as the default Defold editor
function M.setup_default_editor()
    local config = require "defold.config"
    local project = require "defold.project"
    local log = require "defold.service.logger"

    local port = project.editor_port()

    if not port then
        return
    end

    local sidecar = require "defold.sidecar"
    local ok, err = pcall(sidecar.set_default_editor, port, M.plugin_root(), config.state.launcher)

    if not ok then
        log.error(string.format("Could not set default editor because: %s", err))
    end
end

return M
