local M = {}

function M.check()
    vim.health.start "System"

    local os = require "defold.service.os"
    local project = require "defold.project"
    local config = require "defold.config"

    vim.health.info(string.format("OS: %s / %s", os.name(), os.architecture()))
    vim.health.info(string.format("Plugin Root: %s", os.plugin_root()))
    vim.health.info(string.format("Data Dir: %s", os.data_dir()))
    vim.health.info(string.format("Cache Dir: %s", os.cache_dir()))

    vim.health.start "Sidecar"

    local sidecar_ok, sidecar = pcall(require, "defold.sidecar")
    ---@cast sidecar defold.Sidecar
    if sidecar_ok and not require("defold.download").is_ready() then
        vim.health.warn "Rust modules are not ready yet; retry after installation finishes"
        return
    end

    if sidecar_ok then
        vim.health.ok(string.format("Sidecar Loaded Version: %s", sidecar.version))

        local data_dir_ok, data_dir = pcall(sidecar.data_dir)
        if data_dir_ok then
            vim.health.info(string.format("Sidecar Data Dir: %s", data_dir))
        end

        local cache_dir_ok, cache_dir = pcall(sidecar.cache_dir)
        if cache_dir_ok then
            vim.health.info(string.format("Sidecar Cache Dir: %s", cache_dir))
        end
    else
        vim.health.error(string.format("Sidecar Not Available: %s", sidecar))
    end

    vim.health.start "Bridge"

    local bridge_path_ok, bridge_path = pcall(function()
        assert(sidecar_ok, "Sidecar not available")
        return sidecar.find_bridge_path(os.plugin_root())
    end)
    if bridge_path_ok then
        vim.health.ok(string.format("Bridge Path: %s", bridge_path))

        local bridge_version_ok, bridge_version = pcall(function()
            return vim.fn.system { bridge_path, "version" }
        end)

        if bridge_version_ok then
            vim.health.ok(string.format("Bridge Version: %s", vim.trim(bridge_version)))
        else
            vim.health.error(string.format("Bridge Version: Could not get version: %s", bridge_version))
        end
    else
        vim.health.error(string.format("Bridge Not Found: %s", bridge_path))
    end

    vim.health.start "Defold"
    local root = project.project_root()
    if not root then
        vim.health.warn "Could not find a Defold project"
    else
        vim.health.start("Defold: " .. root)
        vim.health.ok("Project Root: " .. root)

        if sidecar_ok then
            local port = project.editor_port()
            if port then
                vim.health.ok(string.format("Editor Port found at: %d", port))
                local ok, version = pcall(sidecar.editor_version, root)
                if ok then
                    vim.health.ok("Editor Version: " .. version)
                else
                    vim.health.warn("Could not query editor version: " .. tostring(version))
                end
            else
                vim.health.warn "Could not find editor port, is the editor running?"
            end

            local ok, deps = pcall(function()
                project.refresh_annotations()
                return project.dependency_api_paths()
            end)
            if not ok then
                vim.health.warn("Could not find dependencies: " .. tostring(deps))
            else
                for _, dep in ipairs(deps) do
                    local dirname = vim.fs.basename(dep)

                    if vim.fs.basename(vim.fs.dirname(dep)) == "defold" then
                        vim.health.ok(string.format("Defold %s: %s", dirname, dep))
                    else
                        for _, lib in ipairs(vim.fn.readdir(dep)) do
                            vim.health.ok(string.format("Ext %s: %s", lib, vim.fs.joinpath(dep, lib)))
                        end
                    end
                end
            end
        end
    end

    vim.health.start "Debugger"

    if config.state.debugger.enable then
        local debugger = require "defold.debugger"
        local variant = config.state.debugger.force_variant or debugger.infer_variant()

        vim.health.ok "Debugger is enabled"
        vim.health.info(string.format("Variant: %s", variant))

        if variant == "moonbug" then
            if config.state.debugger.moonbug.port then
                vim.health.info(string.format("Moonbug Port: %d", config.state.debugger.moonbug.port))
            end
        elseif variant == "mobdebug" then
            vim.health.info(string.format("Mobdap Path: %s", debugger.get_mobdap_path()))

            if config.state.debugger.mobdebug.mobdap_executable then
                vim.health.info(
                    string.format("Mobdap Custom Executable: %s", config.state.debugger.mobdebug.mobdap_executable)
                )
            end

            if config.state.debugger.mobdebug.mobdap_arguments then
                vim.health.info(
                    string.format(
                        "Mobdap Custom Arguments: %s",
                        table.concat(config.state.debugger.mobdebug.mobdap_arguments, " ")
                    )
                )
            end

            if config.state.debugger.mobdebug.port then
                vim.health.info(string.format("Port: %s", config.state.debugger.mobdebug.port))
            end
        end
    else
        vim.health.warn "Debugger is disabled"
    end

    vim.health.start "Launcher"

    vim.health.info(string.format("Launcher Type: %s", config.state.launcher.type))
    vim.health.info(string.format("Socket Type: %s", config.state.launcher.socket_type))

    if sidecar_ok and root then
        local ok, address = pcall(sidecar.resolve_nvim_server_addr, root, config.state.launcher.socket_type)
        if ok then
            vim.health.ok("Server Address: " .. address)
        else
            vim.health.error "Could not determine server address"
        end
    end
end

return M
