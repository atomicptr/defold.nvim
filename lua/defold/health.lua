local M = {}

function M.check()
    local os = require "defold.os"
    local project = require "defold.project"
    local config = require "defold.config"
    local platform = os.name()

    vim.health.start "Environment"
    vim.health.info(string.format("Platform: %s / %s", platform, os.architecture()))
    vim.health.info(string.format("Plugin root: %s", os.plugin_root()))
    vim.health.info(string.format("Plugin data: %s", os.data_dir()))
    vim.health.info(string.format("Plugin cache: %s", os.cache_dir()))

    vim.health.start "Runtime tools"

    local sidecar_ok, sidecar = pcall(require, "defold.sidecar")
    ---@cast sidecar defold.Sidecar
    if sidecar_ok and not sidecar.is_ready() then
        vim.health.warn "Installation is not finished yet. Retry after it completes."
        return
    end

    if sidecar_ok then
        vim.health.ok(string.format("Sidecar version: %s", sidecar.version))

        local data_dir_ok, data_dir = pcall(sidecar.data_dir)
        if data_dir_ok then
            vim.health.info(string.format("Sidecar data: %s", data_dir))
        end

        local cache_dir_ok, cache_dir = pcall(sidecar.cache_dir)
        if cache_dir_ok then
            vim.health.info(string.format("Sidecar cache: %s", cache_dir))
        end
    else
        vim.health.error(string.format("Sidecar unavailable: %s", sidecar))
    end

    local bridge_path = sidecar_ok and sidecar.bridge_path or nil
    if bridge_path and os.file_exists(bridge_path) then
        vim.health.ok(string.format("Bridge executable: %s", bridge_path))

        local bridge_version_ok, bridge_version, bridge_exit = pcall(function()
            local output = vim.fn.system { bridge_path, "version" }
            return output, vim.v.shell_error
        end)

        if bridge_version_ok and bridge_exit == 0 then
            vim.health.ok(string.format("Bridge version: %s", vim.trim(bridge_version)))
        else
            vim.health.error(string.format("Could not query bridge version: %s", bridge_version))
        end
    else
        vim.health.error(string.format("Bridge not found: %s", bridge_path or "not installed"))
    end

    vim.health.start "Project"

    local root = project.project_root()
    if not root then
        vim.health.warn "Could not find a Defold project"
    else
        vim.health.ok(string.format("Project root: %s", root))

        if sidecar_ok then
            local port = project.editor_port()
            if port then
                vim.health.ok(string.format("Editor port: %d", port))
                local ok, version = pcall(sidecar.editor_version, root)
                if ok then
                    vim.health.ok(string.format("Editor version: %s", version))
                else
                    vim.health.warn(string.format("Could not query editor version: %s", tostring(version)))
                end
            else
                vim.health.warn "Could not find editor port, is the editor running?"
            end
        end
    end

    vim.health.start "Launcher"
    vim.health.info(string.format("Launcher type: %s", config.state.launcher.type))

    local socket_type = config.state.launcher.socket_type
    if not socket_type then
        local default_socket = (platform == "linux" or platform == "macos") and "fsock" or "netsock"
        socket_type = string.format("%s (automatic)", default_socket)
    end

    vim.health.info(string.format("Socket type: %s", socket_type))

    if sidecar_ok and root then
        local ok, address = pcall(sidecar.resolve_nvim_server_addr, root, config.state.launcher.socket_type)
        if ok then
            vim.health.ok(string.format("Server address: %s", address))
        else
            vim.health.error(string.format("Could not determine server address: %s", tostring(address)))
        end
    end

    vim.health.start "Debugger"

    if config.state.debugger.enable then
        local debugger = require "defold.debugger"
        local variant = config.state.debugger.force_variant or debugger.infer_variant()

        vim.health.ok "Debugger is enabled"
        vim.health.info(string.format("Variant: %s", variant))

        if variant == "native" then
            local port = require("defold.debugger.native").port()
            vim.health.info(port and string.format("Attach port: %d", port) or "Debugger port not discovered")
        elseif variant == "moonbug" then
            if config.state.debugger.moonbug.port then
                vim.health.info(string.format("Moonbug port: %d", config.state.debugger.moonbug.port))
            end
        elseif variant == "mobdebug" then
            vim.health.info(string.format("Mobdap executable: %s", require("defold.debugger.mobdebug").get_path()))

            if config.state.debugger.mobdebug.mobdap_executable then
                vim.health.info(
                    string.format("Custom executable: %s", config.state.debugger.mobdebug.mobdap_executable)
                )
            end

            if config.state.debugger.mobdebug.mobdap_arguments then
                vim.health.info(
                    string.format("Arguments: %s", table.concat(config.state.debugger.mobdebug.mobdap_arguments, " "))
                )
            end

            if config.state.debugger.mobdebug.port then
                vim.health.info(string.format("Port: %s", config.state.debugger.mobdebug.port))
            end
        end
    else
        vim.health.info "Debugger is disabled"
    end

    if sidecar_ok and root then
        vim.health.start "Dependencies"

        local ok, deps = pcall(function()
            project.refresh_annotations()
            return project.dependency_api_paths()
        end)
        if not ok then
            vim.health.warn(string.format("Could not find dependencies: %s", tostring(deps)))
        elseif #deps == 0 then
            vim.health.info "No dependency API paths found"
        else
            for _, dep in ipairs(deps) do
                local dirname = vim.fs.basename(dep)

                if vim.fs.basename(vim.fs.dirname(dep)) == "defold" then
                    vim.health.ok(string.format("Defold annotations %s: %s", dirname, dep))
                else
                    for _, lib in ipairs(vim.fn.readdir(dep)) do
                        vim.health.ok(string.format("Extension %s: %s", lib, vim.fs.joinpath(dep, lib)))
                    end
                end
            end
        end
    end
end

return M
