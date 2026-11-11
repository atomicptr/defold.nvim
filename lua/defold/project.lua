local M = {}

---@class defold.project.AnnotationState
---@field version? string
---@field path? string
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

---@param on_change? fun()
---@return boolean changed
function M.refresh_annotations(on_change)
    local sidecar = require "defold.sidecar"
    local log = require "defold.service.logger"
    local os = require "defold.service.os"

    local root = M.project_root()
    if not root then
        return false
    end

    if M._annotations_state then
        M._annotations_state.on_change = on_change or M._annotations_state.on_change
        return false
    end

    local dir = vim.fs.joinpath(os.data_dir(), sidecar.project_id(root))
    vim.fn.mkdir(dir, "p")
    local file = vim.fs.joinpath(dir, "editor_version")
    M._annotations_state = { on_change = on_change }

    local function refresh()
        local version = M._annotations_state.version
        if not version then
            local ok, detected = pcall(sidecar.editor_version, root)
            if ok then
                version = detected
                M._annotations_state.version = version
                local saved, err = pcall(vim.fn.writefile, { version }, file)
                if not saved or err ~= 0 then
                    log.error("Could not save Defold editor version: " .. tostring(err))
                end
            else
                local read, lines = pcall(vim.fn.readfile, file)
                version = read and lines[1] or nil
                if version and not version:match "^%d+%.%d+%.%d+$" then
                    version = nil
                end
            end
        end

        local changed = false
        local ok, path = pcall(sidecar.annotation_dir, root, version)
        if ok then
            changed = M._annotations_state.path ~= path
            M._annotations_state.path = path
        else
            log.error("Could not update Defold annotations: " .. tostring(path))
        end

        if not M._annotations_state.version or not ok then
            vim.defer_fn(function()
                if refresh() and M._annotations_state.on_change then
                    M._annotations_state.on_change()
                end
            end, 5000)
        end

        return changed
    end

    return refresh()
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
function M.install_dependencies(force_redownload)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local root_dir = M.project_root(true)

    if not root_dir then
        return {}
    end

    M.refresh_annotations()

    local ok, res = pcall(sidecar.install_dependencies, root_dir, force_redownload or false)
    if not ok then
        log.error(string.format("Could not install dependencies because: %s", res))
        return
    end
end

return M
