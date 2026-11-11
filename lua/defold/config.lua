---@class defold.config.Editor Settings for the Defold Game Engine
---@field set_default_editor?      boolean Automatically set defold.nvim as the default editor in Defold
---@field auto_fetch_dependencies? boolean Automatically fetch dependencies on launch
---@field hot_reload_enabled?      boolean Enable hot reloading when saving scripts in Neovim

---@class defold.config.Launcher Settings for the Neovim launcher run by Defold
---@field type         "neovide"|"terminal" Neovim launcher run by Defold
---@field executable?  string               Executable to be used by the launcher, nil means we're trying to figure this out ourselves
---@field socket_type? "fsock"|"netsock"    Run Neovims RPC protocol over file socket or network. Nil means it will be picked automatic (fsock on Unix, network on Windows)
---@field run_arg?     string               (Custom Terminal only) Argument to specify how the command is run usually "-e"
---@field arguments?   table<string>        Extra arguments passed to the `executable` (or neovide)
---@field appname?     string               Sets `NVIM_APPNAME` to run the editor in a special configuration
---@field debug?       boolean              Enable debug settings for the bridge cli

---@class defold.config.Debugger Settings for the integrated debugger
---@field enable?        boolean                               Enable the debugger
---@field moonbug?       defold.config.debugger.MoonbugConfig  Config for `moonbug`
---@field mobdebug?      defold.config.debugger.MobdebugConfig Config for `mobdebug`
---@field force_variant? defold.debugger.Variant               Load variant no matter what is inferred from project

---@class defold.config.debugger.MoonbugConfig
---@field port? integer The port to run moonbug at

---@class defold.config.debugger.MobdebugConfig
---@field mobdap_executable? string   Use a custom executable for mobdap
---@field mobdap_arguments?  string[] Custom arguments for mobdap
---@field port?              integer  Custom port for the debugger (default: 18172)

---@class defold.config.Completions Settings for Defold completions
---@field enable? boolean Enable Defold completions

---@alias defold.snippets.NamingStyle "preserve"|"snake_case"|"Ada_Case"|"PascalCase"

---@class defold.config.Snippets Settings for Defold snippets
---@field enable?                 boolean                     Enable Defold snippets (default true)
---@field class_naming_style?     defold.snippets.NamingStyle Filename casing (default "PascalCase")
---@field namespace_naming_style? defold.snippets.NamingStyle Directory casing (default "preserve")
---@field use_namespaces?         boolean                     Prefix class names with project-relative directories (default true)

---@class defold.config.Quickfix Settings for the integrated Quickfix support
---@field enable?       boolean                      Enable quickfix mode (default true)
---@field min_severity? defold.sidecar.IssueSeverity Minimum severity to report Defold errors in quickfix (default "error")
---@field open_list?    boolean                      Opens the quickfix list after sending the command (default true)

---@class defold.config.GameRunner Settings for running the game through Defold
---@field mode?        "make"|"send" Decide whenever the game will be run through `:make` or through `:DefoldSend build` (default: make)
---@field show_logs?   boolean       Show logs when launching the game (only when `mode` is set to "make") (default: true)
---@field errorformat? string[]      The errorformat being used by quicklist (only used on `mode` "make")

---@class defold.Config Settings for defold.nvim
---@field defold?               defold.config.Editor      Settings for the Defold Game Engine
---@field launcher?             defold.config.Launcher    Settings for the Neovim launcher run by Defold
---@field debugger?             defold.config.Debugger    Settings for the integrated debugger
---@field completions?          defold.config.Completions Settings for Defold completions
---@field snippets?             defold.config.Snippets    Settings for Defold snippets
---@field quickfix?             defold.config.Quickfix    Settings for the integrated Quickfix support
---@field game_runner?          defold.config.GameRunner  Settings for running the game through Defold
---@field setup_make?           boolean                   Whenever or not defold.nvim sets up `:make`
---@field force_plugin_enabled? boolean                   Force the plugin to be always enabled (even if we can't find the game.project file)
---@field debug?                boolean                   Enable debug settings for the plugin

local M = {}

---@type defold.Config
M.state = {
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

        moonbug = {
            port = nil,
        },

        mobdebug = {
            mobdap_executable = nil,
            mobdap_arguments = nil,
            port = nil,
        },

        force_variant = nil,
    },

    completions = {
        enable = true,
    },

    snippets = {
        enable = true,
        class_naming_style = "PascalCase",
        namespace_naming_style = "preserve",
        use_namespaces = true,
    },

    quickfix = {
        enable = true,
        min_severity = "error",
        open_list = true,
    },

    game_runner = {
        mode = nil,
        show_logs = true,
        errorformat = {
            -- multi-line error, capture only message and location
            "%+EERROR:%*[^:]: %f:%l: %m",

            -- stack traces
            "%-Cstack traceback:",
            "%-C%\\s*%\\[C%\\]:-1: in function %m",
            "%-C%\\s*%\\[C%\\]: in function %m",
            "%-C%\\s*%f:%l: in function <%*[^>]>",
            "%-C%\\s*%f:%l: in function %m",
            "%-C%\\s*%f:%l: in main chunk",
            "%-C%\\s*%f:%l: %m",

            -- terminators
            "%Z%\\s*%f:%l: in function <%*[^>]>",
            "%Z%\\s*%f:%l: in function %m",
            "%Z%\\s*%f:%l: in main chunk",
            "%Z%\\s*%f:%l: %m",

            -- single-line
            "ERROR:%*[^:]: %f:%l: %m",
            "WARNING:%*[^:]: %f:%l: %m",

            -- ignore
            "%-GINFO:%.%#",
            "%-GDEBUG:%.%#",
            "%-GWARNING:%.%#",
            "%-G%s",
            "%-G%.%#",
        },
    },

    setup_make = true,
    force_plugin_enabled = false,
    debug = false,
}

---@param opts? defold.Config
function M.apply(opts)
    M.state = vim.tbl_deep_extend("force", M.state, opts or {})
end

return M
