local M = {}

---@class defold.project.AnnotationState
---@field version?   string
---@field path?      string
---@field on_change? fun()

---@type defold.project.AnnotationState?
M._annotations_state = nil

---@type string?
M._project_root = nil

---@type integer?
M._editor_port = nil

---Returns the game project root (or nil if we can't find it)
---@param report_error boolean?
---@return string?
function M.project_root(report_error)
    if M._project_root then
        return M._project_root
    end

    local root = vim.fs.root(0, { "game.project" })

    if not root then
        if not report_error then
            return nil
        end

        local log = require "defold.service.logger"
        log.error "Could not find game.project file, not a Defold project?"
        return nil
    end

    M._project_root = root
    return root
end

---Check if the buffer is in the current project
---@param bufnr? integer
---@return boolean
function M.is_buffer_in_project(bufnr)
    local root = M.project_root()
    local filename = vim.api.nvim_buf_get_name(bufnr or 0)

    return root ~= nil and filename ~= "" and vim.fs.relpath(root, filename) ~= nil
end

---Returns true if we are in a defold project
---@return boolean
function M.is_defold_project()
    local root_dir = M.project_root()

    if not root_dir then
        return false
    end

    return require("defold.service.os").file_exists(vim.fs.joinpath(root_dir, "game.project"))
end

---@return boolean
local function is_server_registered(server_addr)
    for _, addr in ipairs(vim.fn.serverlist()) do
        if addr == server_addr then
            return true
        end
    end

    return false
end

---@param socket_type "fsock"|"netsock"|nil
---@return string|nil
function M.ensure_nvim_server(socket_type)
    local log = require "defold.service.logger"

    for _, arg in ipairs(vim.v.argv) do
        -- if neovim was started with `--listen` flag we don't need to try to start a new server
        if arg == "--listen" then
            log.debug "Neovim was started with `--listen`, no need to start a server"
            return nil
        end
    end

    local root = M.project_root()
    if not root then
        return nil
    end

    local sidecar = require "defold.sidecar"

    local ok_addr, addr = pcall(sidecar.resolve_nvim_server_addr, root, socket_type)
    if not ok_addr then
        log.error(string.format("Could not resolve Neovim server address because: %s", addr))
        return nil
    end

    if is_server_registered(addr) then
        log.debug(string.format("Neovim is running with server: %s", addr))
        return addr
    end

    local ok_server, server = pcall(vim.fn.serverstart, addr)
    if ok_server then
        log.debug(string.format("Started new Neovim server at: %s", server))
        return server
    end

    return nil
end

---Find the Defold editor port for the current project
---@return integer|nil
function M.editor_port()
    local sidecar = require "defold.sidecar"
    local os = require "defold.service.os"

    local root = M.project_root()
    if not root then
        return nil
    end

    if M._editor_port and sidecar.is_editor_port(M._editor_port) then
        return M._editor_port
    end

    local editor_port_file = vim.fs.joinpath(root, ".internal", "editor.port")

    -- no editor available
    if not os.file_exists(editor_port_file) then
        return nil
    end

    local port_string = os.read_to_string(editor_port_file)
    if not port_string then
        return nil
    end

    local log = require "defold.service.logger"

    M._editor_port = tonumber(port_string)
    log.debug(string.format("Found editor port at: %s", M._editor_port))

    if not M._editor_port or not sidecar.is_editor_port(M._editor_port) then
        log.error(string.format("Found editor port %s but the editor doesn't respond", M._editor_port))
        return nil
    end

    return M._editor_port
end

---@param on_change? fun() Called after annotations become available or change
function M.refresh_annotations(on_change)
    local sidecar = require "defold.sidecar"
    local log = require "defold.service.logger"
    local os = require "defold.service.os"
    local download = require "defold.download"

    local root = M.project_root()
    if not root then
        return
    end

    if M._annotations_state then
        M._annotations_state.on_change = on_change or M._annotations_state.on_change
        return
    end

    local dir = vim.fs.joinpath(os.data_dir(), sidecar.project_id(root))
    vim.fn.mkdir(dir, "p")

    local file = vim.fs.joinpath(dir, "editor_version")

    M._annotations_state = { on_change = on_change }

    local function refresh()
        local version = M._annotations_state.version

        if not version then
            local detected, value = pcall(sidecar.editor_version, root)

            if detected then
                version = value
                M._annotations_state.version = version

                local saved, err = pcall(os.write, file, version .. "\n")
                if not saved then
                    log.error(string.format("Could not cache Defold editor version: %s", tostring(err)))
                end
            else
                local read, lines = pcall(vim.fn.readfile, file)
                if read then
                    version = lines[1]
                end
                if version and not version:match "^%d+%.%d+%.%d+$" then
                    version = nil
                end
            end
        end

        local data = sidecar.data_dir()

        download.ensure({
            name = "Defold Annotations",
            owner = "defold",
            repo = "defold",
            asset = "ref-doc.zip",
            version = version,

            path = function(tag)
                local parsed = tag:match "^v?(%d+%.%d+%.%d+)$"
                if not parsed then
                    log.fatal(string.format("Invalid Defold version: %s", tag))
                end

                return vim.fs.joinpath(data, "deps", "defold", parsed)
            end,
            version_path = vim.fs.joinpath(data, "meta", "defold_annotations_version"),

            archive = true,
            install = function(source, target)
                local staging = vim.fs.joinpath(vim.fs.dirname(source), "annotations")

                local files = vim.fs.find(function(name)
                    return name:match "%.lua$"
                end, {
                    path = source,
                    type = "file",
                    limit = math.huge,
                })
                if #files == 0 then
                    log.fatal "No Lua files in Defold documentation archive"
                end

                for _, path in ipairs(files) do
                    os.copy(path, vim.fs.joinpath(staging, vim.fs.basename(path)))
                end

                local moved, err = pcall(sidecar.move, staging, target)
                if not moved then
                    vim.fn.delete(target, "rf")
                    log.fatal(tostring(err))
                end
            end,
        }, function(path, err)
            if path then
                local changed = M._annotations_state.path ~= path
                M._annotations_state.path = path

                if changed and M._annotations_state.on_change then
                    M._annotations_state.on_change()
                end
            else
                log.error(string.format("Installation failed (Defold annotations): %s", tostring(err)))
            end

            if not M._annotations_state.version or not path then
                vim.defer_fn(refresh, 5000)
            end
        end)
    end

    refresh()
end

---Install managed Neovide only when the configured launcher needs it.
function M.setup_neovide()
    local os = require "defold.service.os"

    ---@type defold.config.Launcher
    local launcher = require("defold.config").state.launcher

    if launcher.type ~= "neovide" or launcher.executable or os.command_exists "neovide" then
        return
    end

    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local data = sidecar.data_dir()

    local entry = "neovide"
    local asset = "neovide-linux-x86_64.tar.gz"

    if os.is_windows() then
        entry = "neovide.exe"
        asset = "neovide.exe.zip"
    elseif os.is_macos() then
        local architecture = "x86_64"
        if os.architecture() == "aarch64" then
            architecture = "aarch64"
        end

        entry = "Neovide.app"
        asset = string.format("Neovide-%s-apple-darwin.dmg", architecture)
    end

    require("defold.download").ensure({
        name = "Neovide",
        owner = "neovide",
        repo = "neovide",
        asset = asset,

        path = vim.fs.joinpath(data, "bin", entry),
        version_path = vim.fs.joinpath(data, "meta", "neovide_version"),

        archive = true,
        entry = entry,
        executable = not os.is_macos(),
    }, function(_, err)
        if err then
            log.error(string.format("Installation failed (Neovide): %s", err))
        end
    end)
end

function M.dependency_api_paths()
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local root_dir = M.project_root(true)

    if not root_dir then
        return {}
    end

    local ok, res = pcall(sidecar.list_dependency_dirs, root_dir)
    if not ok then
        log.error(string.format("Could not get dependency paths because: %s", res))
        res = {}
    end

    if M._annotations_state and M._annotations_state.path then
        table.insert(res, 1, M._annotations_state.path)
    end

    return res
end

---@param force_redownload boolean
---@param on_complete?     fun()
function M.install_dependencies(force_redownload, on_complete)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"
    local os = require "defold.service.os"

    local root = M.project_root(true)
    if not root then
        return
    end

    if M._installing_dependencies then
        log.warn "Dependency installation is already in progress"
        return
    end

    M._installing_dependencies = true

    local function finish(err)
        M._installing_dependencies = false

        if err then
            log.error(string.format("Installation failed (dependencies): %s", err))
        elseif on_complete then
            on_complete()
        end
    end

    local ok, err = pcall(function()
        M.refresh_annotations()

        local dependencies = sidecar.read_game_project(vim.fs.joinpath(root, "game.project")).dependencies
        log.debug(string.format("Checking %d dependencies for %s", #dependencies, root))

        local dir = vim.fs.joinpath(sidecar.data_dir(), "deps", "project", sidecar.project_id(root))
        local wanted = {}

        for _, url in ipairs(dependencies) do
            wanted[sidecar.hash(url):sub(1, 8)] = true
        end

        if force_redownload then
            log.info(string.format("Reinstalling project dependencies: %s", root))
            if os.file_exists(dir) then
                assert(vim.fn.delete(dir, "rf") == 0, "Could not clear dependency cache")
            end
        end

        vim.fn.mkdir(dir, "p")

        local index, failed = 1, false
        local function next_dependency()
            local target
            while dependencies[index] do
                target = vim.fs.joinpath(dir, sidecar.hash(dependencies[index]):sub(1, 8))
                if not os.file_exists(target) then
                    break
                end

                log.debug(string.format("Using cached dependency: %s at %s", dependencies[index], target))
                index = index + 1
            end

            local url = dependencies[index]
            if not url then
                if failed then
                    finish "One or more dependencies failed"
                    return
                end

                for _, name in ipairs(vim.fn.readdir(dir)) do
                    local path = vim.fs.joinpath(dir, name)
                    if not wanted[name] and vim.fn.isdirectory(path) == 1 then
                        log.debug(string.format("Removing unused dependency: %s", path))
                        assert(
                            vim.fn.delete(path, "rf") == 0,
                            string.format("Could not remove unused dependency: %s", path)
                        )
                    end
                end

                log.debug(string.format("Project dependencies are ready: %s", root))
                finish()
                return
            end

            index = index + 1

            local temp = vim.fn.tempname()
            local archive = vim.fs.joinpath(temp, "dependency.zip")
            local function downloaded(download_err)
                local installed, install_err = false, download_err

                if not download_err then
                    installed, install_err = pcall(function()
                        local source = vim.fs.joinpath(temp, "unpacked")
                        sidecar.unpack(archive, source)
                        sidecar.install_dependency(source, target)
                        log.info(string.format("Dependency installed: %s", url))
                    end)
                end

                if not installed then
                    failed = true

                    log.error(string.format("Installation failed (%s): %s", url, tostring(install_err)))

                    if vim.fn.delete(target, "rf") ~= 0 then
                        log.warn(string.format("Could not remove incomplete dependency: %s", target))
                    end
                end

                log.debug(string.format("Removing temporary dependency files: %s", temp))

                if vim.fn.delete(temp, "rf") ~= 0 then
                    log.warn(string.format("Could not remove temporary dependency: %s", temp))
                end

                local advanced, advance_err = pcall(next_dependency)

                if not advanced then
                    finish(tostring(advance_err))
                end
            end

            local started, start_err = pcall(function()
                vim.fn.mkdir(temp, "p")

                log.info(string.format("Installing dependency: %s", url))
                log.debug(string.format("Dependency destination: %s", target))

                os.download(url, archive, downloaded)
            end)

            if not started then
                downloaded(tostring(start_err))
            end
        end

        next_dependency()
    end)

    if not ok then
        finish(tostring(err))
    end
end

return M
