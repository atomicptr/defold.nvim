local M = {}

---@alias defold.health.Level "ok"|"info"|"warn"|"error"

---@class defold.health.Row
---@field level  defold.health.Level
---@field key?   string
---@field value  string

-- vim.health.info has no prefix, we add the icon ourselves
local prefixes = {
    ok = "✅ OK ",
    info = "ℹ️ INFO ",
    warn = "⚠️ WARNING ",
    error = "❌ ERROR ",
}

---Section that aligns the values of its key-value rows
---@param name string
local function section(name)
    ---@type defold.health.Row[]
    local rows = {}

    local s = {}

    ---@param level defold.health.Level
    ---@param key   string
    ---@param value any
    function s.pair(level, key, value)
        table.insert(rows, { level = level, key = key, value = tostring(value) })
    end

    ---@param level   defold.health.Level
    ---@param message string
    function s.message(level, message)
        table.insert(rows, { level = level, value = message })
    end

    function s.report()
        local function label(row)
            return string.format("%s%s: ", prefixes[row.level], row.key)
        end

        local width = 0
        for _, row in ipairs(rows) do
            if row.key then
                width = math.max(width, vim.fn.strdisplaywidth(label(row)))
            end
        end

        vim.health.start(name)

        for _, row in ipairs(rows) do
            local message = row.value

            if row.key then
                local padding = string.rep(" ", width - vim.fn.strdisplaywidth(label(row)))
                message = string.format("%s: %s%s", row.key, padding, row.value)
            end

            if row.level == "info" then
                message = prefixes.info .. message
            end

            vim.health[row.level](message)
        end
    end

    return s
end

function M.check()
    local os = require "defold.os"
    local project = require "defold.project"
    local config = require "defold.config"
    local platform = os.name()

    local environment = section "Environment"
    environment.pair("info", "Platform", string.format("%s / %s", platform, os.architecture()))
    environment.pair("info", "Plugin root", os.plugin_root())
    environment.pair("info", "Plugin data", os.data_dir())
    environment.pair("info", "Plugin logs", os.logs_dir())
    environment.pair("info", "Plugin cache", os.cache_dir())
    environment.report()

    local tools = section "Runtime tools"

    local sidecar_ok, sidecar = pcall(require, "defold.sidecar")
    ---@cast sidecar defold.Sidecar
    if sidecar_ok and not sidecar.is_ready() then
        tools.message("warn", "Installation is not finished yet. Retry after it completes.")
        tools.report()
        return
    end

    if sidecar_ok then
        tools.pair("ok", "Sidecar version", sidecar.version)
    else
        tools.message("error", string.format("Sidecar unavailable: %s", sidecar))
    end

    local bridge_path = sidecar_ok and sidecar.bridge_path or nil
    if bridge_path and os.file_exists(bridge_path) then
        tools.pair("ok", "Bridge executable", bridge_path)

        local bridge_version_ok, bridge_version, bridge_exit = pcall(function()
            local output = vim.fn.system { bridge_path, "version" }
            return output, vim.v.shell_error
        end)

        if bridge_version_ok and bridge_exit == 0 then
            tools.pair("ok", "Bridge version", vim.trim(bridge_version))
        else
            tools.message("error", string.format("Could not query bridge version: %s", bridge_version))
        end
    else
        tools.message("error", string.format("Bridge not found: %s", bridge_path or "not installed"))
    end

    tools.report()

    local project_section = section "Project"

    local root = project.project_root()
    if not root then
        project_section.message("warn", "Could not find a Defold project")
    else
        project_section.pair("ok", "Project root", root)

        if sidecar_ok then
            local ok, paths = pcall(sidecar.project_paths, root)
            if ok then
                project_section.pair("info", "Project data", paths.data)
                project_section.pair("info", "Project cache", paths.cache)
            else
                project_section.message(
                    "error",
                    string.format("Could not resolve project directories: %s", tostring(paths))
                )
            end

            local port = project.editor_port()
            if port then
                project_section.pair("ok", "Editor port", port)
                local version_ok, version = pcall(sidecar.editor_version, root)
                if version_ok then
                    project_section.pair("ok", "Editor version", version)
                else
                    project_section.message(
                        "warn",
                        string.format("Could not query editor version: %s", tostring(version))
                    )
                end
            else
                project_section.message("warn", "Could not find editor port, is the editor running?")
            end
        end
    end

    project_section.report()

    local launcher = section "Launcher"
    launcher.pair("info", "Launcher type", config.state.launcher.type)

    local socket_type = config.state.launcher.socket_type
    if not socket_type then
        local default_socket = (platform == "linux" or platform == "macos") and "fsock" or "netsock"
        socket_type = string.format("%s (automatic)", default_socket)
    end

    launcher.pair("info", "Socket type", socket_type)

    if sidecar_ok and root then
        local ok, address = pcall(sidecar.resolve_nvim_server_addr, root, config.state.launcher.socket_type)
        if ok then
            launcher.pair("ok", "Server address", address)
        else
            launcher.message("error", string.format("Could not determine server address: %s", tostring(address)))
        end
    end

    launcher.report()

    local debugger_section = section "Debugger"

    if config.state.debugger.enable then
        local debugger = require "defold.debugger"
        local mobdebug = config.state.debugger.mobdebug
        local variant = config.state.debugger.force_variant or debugger.infer_variant()

        debugger_section.message("ok", "Debugger is enabled")
        debugger_section.pair("info", "Variant", variant)

        if variant == "native" then
            local port = require("defold.debugger.native").port()
            if port then
                debugger_section.pair("info", "Attach port", port)
            else
                debugger_section.message("info", "Debugger port not discovered")
            end
        elseif variant == "moonbug" then
            if config.state.debugger.moonbug.port then
                debugger_section.pair("info", "Moonbug port", config.state.debugger.moonbug.port)
            end
        elseif variant == "mobdebug" then
            debugger_section.pair("info", "Mobdap executable", require("defold.debugger.mobdebug").get_path())

            if mobdebug.mobdap_executable then
                debugger_section.pair("info", "Custom executable", mobdebug.mobdap_executable)
            end

            if mobdebug.mobdap_arguments then
                debugger_section.pair("info", "Arguments", table.concat(mobdebug.mobdap_arguments, " "))
            end

            if mobdebug.port then
                debugger_section.pair("info", "Port", mobdebug.port)
            end
        end
    else
        debugger_section.message("info", "Debugger is disabled")
    end

    debugger_section.report()

    if sidecar_ok and root then
        local dependencies = section "Dependencies"

        local ok, deps = pcall(project.dependency_api_paths)
        if not ok then
            dependencies.message("warn", string.format("Could not find dependencies: %s", tostring(deps)))
        elseif #deps == 0 then
            dependencies.message("info", "No dependency API paths found")
        else
            for _, dep in ipairs(deps) do
                local dirname = vim.fs.basename(dep)

                if vim.fs.basename(vim.fs.dirname(dep)) == "annotations" then
                    dependencies.pair("ok", string.format("Defold annotations %s", dirname), dep)
                else
                    for _, lib in ipairs(vim.fn.readdir(dep)) do
                        dependencies.pair("ok", string.format("Extension %s", lib), vim.fs.joinpath(dep, lib))
                    end
                end
            end
        end

        dependencies.report()
    end
end

return M
