local M = {}

---Returns the game project root (or nil if we can't find it)
---@param report_error boolean?
---@return string?
function M.project_root(report_error)
    local root = vim.fs.root(0, { "game.project" })

    if not root then
        if not report_error then
            return nil
        end

        local log = require "defold.service.logger"
        log.error "Could not find game.project file, not a Defold project?"
        return nil
    end

    return root
end

---Returns true if we are in a defold project
---@return boolean
function M.is_defold_project()
    local root_dir = M.project_root()
    return vim.fn.filereadable(root_dir .. "/game.project") == 1
end

M._editor_port = nil

---Find defold editor port for current project
---@return integer|nil
function M.editor_port()
    local sidecar = require "defold.sidecar"

    if M._editor_port and sidecar.is_editor_port(M._editor_port) then
        return M._editor_port
    end

    if not M.is_defold_project() then
        return nil
    end

    local os = require "defold.service.os"

    local root = M.project_root()
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

    local editor_port = tonumber(port_string)
    log.debug(string.format("Found editor port at: %s", editor_port))

    if not sidecar.is_editor_port(editor_port) then
        log.error(string.format("Found editor port %s but the editor doesn't respond", editor_port))
        return nil
    end

    M._editor_port = editor_port
    return editor_port
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
        return {}
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

    local ok, res = pcall(sidecar.install_dependencies, root_dir, force_redownload or false)
    if not ok then
        log.error(string.format("Could not install dependencies because: %s", res))
        return
    end
end

return M
