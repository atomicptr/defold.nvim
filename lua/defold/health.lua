local M = {}

function M.check()
    vim.health.start "System"

    local os = require "defold.service.os"

    vim.health.info(string.format("OS: %s / %s", os.name(), os.architecture()))
    vim.health.info(string.format("Plugin Root: %s", os.plugin_root()))
    vim.health.info(string.format("Data Dir: %s", os.data_dir()))
    vim.health.info(string.format("Cache Dir: %s", os.cache_dir()))

    vim.health.start "Sidecar"

    local sidecar_ok, sidecar = pcall(require, "defold.sidecar")
    ---@cast sidecar Sidecar
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

    local bridge_path_ok, bridge_path = pcall(sidecar.find_bridge_path, require("defold").plugin_root())
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

    vim.health.start "mobdap"

    local debugger = require "defold.service.debugger"
    local mobdap_path = debugger.mobdap_path()

    if mobdap_path ~= nil then
        vim.health.ok(string.format("mobdap Path: %s", mobdap_path))
    else
        vim.health.warn(string.format("mobdap not available: %s, debugger disabled", mobdap_path))
    end

    vim.health.start "Defold"

    local project = require "defold.project"

    if project.is_defold_project() then
        vim.health.ok "Current project is Defold project"

        local project_root = project.project_root(false)

        if project_root then
            vim.health.ok(string.format("Project Root: %s", project_root))
        end
    else
        vim.health.warn "Current project is NOT a Defold project"
    end

    local editor_port = project.editor_port()

    if editor_port ~= nil then
        vim.health.ok(string.format("Editor Port found at: %d", editor_port))
    else
        vim.health.warn "Could not find editor port, is the editor running?"
    end

    ---@type {config: DefoldNvimConfig}
    local defold = require "defold"

    vim.health.start "Launcher"

    vim.health.info(string.format("Launcher Type: %s", defold.config.launcher.type))
    vim.health.info(string.format("Socket Type: %s", defold.config.launcher.socket_type))

    if sidecar_ok then
        local server_addr_ok, server_addr =
            pcall(sidecar.resolve_nvim_server_addr, project.project_root(), defold.config.launcher.socket_type)
        if server_addr_ok then
            vim.health.ok(string.format("Server Address: %s", server_addr))
        else
            vim.health.error(string.format "Could not determine server address")
        end
    end
end

return M
