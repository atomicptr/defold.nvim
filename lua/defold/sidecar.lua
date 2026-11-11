local M = {}

---@type uv.luv_work_ctx_t|nil
local bridge_work = nil

local github_owner = "atomicptr"
local github_repository = "defold.nvim"
local github_file_name = {
    linux = {
        amd64 = "linux-x86-libdefold_nvim_sidecar.so",
    },
    macos = {
        amd64 = "macos-x86-libdefold_nvim_sidecar.dylib",
        aarch64 = "macos-arm-libdefold_nvim_sidecar.dylib",
    },
    windows = {
        amd64 = "windows-x86-defold_nvim_sidecar.dll",
    },
}

---@return string
local function lib_name()
    local os = require "defold.service.os"

    if os.is_windows() then
        return "defold_nvim_sidecar"
    end

    return "libdefold_nvim_sidecar"
end

---@return string
local function lib_extension()
    local os = require "defold.service.os"

    if os.is_windows() then
        return ".dll"
    elseif os.is_macos() then
        return ".dylib"
    else
        return ".so"
    end
end

---@return string
local function version_path()
    local os = require "defold.service.os"

    local meta_dir = vim.fs.joinpath(os.data_dir(), "meta")
    vim.fn.mkdir(meta_dir, "p")

    return vim.fs.joinpath(meta_dir, "sidecar_version")
end

---@return string|nil
local function version()
    local os = require "defold.service.os"
    if not os.file_exists(version_path()) then
        return nil
    end

    local file = io.open(version_path(), "r")
    if not file then
        return nil
    end

    local data = file:read "*a"
    file:close()

    return data
end

---@return string
local function plugin_version()
    local ok, plugin_ver = pcall(require, "defold.version")
    if not ok then
        -- no defold.version file found means we're <0.9.4, lets try reading version path or just assume
        -- the user is at 0.9.3
        return version() or "0.9.3"
    end

    return plugin_ver
end

---Download the plugins sidecar release
---@param tag string
---@param callback fun(dir: string|nil, err?: string)
local function download_release(tag, callback)
    local os = require "defold.service.os"
    local log = require "defold.service.logger"

    local filename = (github_file_name[os.name()] or {})[os.architecture()]
    if not filename then
        callback(nil, string.format("Unsupported platform: %s/%s", os.name(), os.architecture()))
        return
    end

    log.info("Downloading sidecar " .. tag .. "…")

    require("defold.service.github").download_release(
        github_owner,
        github_repository,
        filename,
        tag,
        function(file, release, err)
            if not file or not release then
                callback(nil, err or "Invalid GitHub release")
                return
            end

            local ok, result = pcall(function()
                local dir = vim.fs.joinpath(os.data_dir(), "lib")
                vim.fn.mkdir(dir, "p")

                local target = vim.fs.joinpath(dir, lib_name() .. lib_extension())

                assert(vim.uv.fs_copyfile(file, target .. ".tmp"))
                assert(vim.uv.fs_rename(target .. ".tmp", target))
                assert(vim.fn.writefile({ release.tag_name }, version_path()) == 0)

                return dir
            end)

            vim.fn.delete(file)

            if ok then
                log.info("Sidecar " .. tag .. " installed")
            end

            callback(ok and result or nil, not ok and tostring(result) or nil)
        end
    )
end

---@param callback fun(dir: string|nil, err?: string)
local function find_rust_lib_rootdir(callback)
    local os = require "defold.service.os"
    local log = require "defold.service.logger"

    local file_name = string.format("defold_nvim_sidecar%s", lib_extension())
    local file_name_alt = string.format("libdefold_nvim_sidecar%s", lib_extension())

    local plugin_root = os.plugin_root()
    local lib_dir = vim.fs.joinpath(os.data_dir(), "lib")

    if
        -- check local debug build first
        os.file_exists(vim.fs.joinpath(plugin_root, "target", "debug", file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, "target", "debug", file_name_alt))
    then
        return callback(vim.fs.joinpath(plugin_root, "target", "debug"))
    elseif
        -- check local release build second
        os.file_exists(vim.fs.joinpath(plugin_root, "target", "release", file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, "target", "release", file_name_alt))
    then
        return callback(vim.fs.joinpath(plugin_root, "target", "release"))
    elseif
        -- and the actual properly installed path last
        os.file_exists(vim.fs.joinpath(lib_dir, file_name))
        or os.file_exists(vim.fs.joinpath(lib_dir, file_name_alt))
    then
        local curr_version = version()

        if not curr_version then
            return download_release(plugin_version(), callback)
        end

        if vim.version.cmp(curr_version, plugin_version()) ~= 0 then
            log.info(
                string.format("Sidecar version (current: %s) outdated, updating to %s", curr_version, plugin_version())
            )

            return download_release(plugin_version(), callback)
        end

        return callback(lib_dir)
    else
        -- and if that also doesnt exist... download it
        return download_release(plugin_version(), callback)
    end
end

---@class defold.sidecar.GameProject
---@field title        string
---@field dependencies string[]

---@class defold.sidecar.CommandResult
---@field success boolean
---@field issues  defold.sidecar.Issue[]
---@field status  integer

---@class defold.sidecar.Issue
---@field message   string
---@field severity  defold.sidecar.IssueSeverity
---@field resource? string
---@field range?    defold.sidecar.Range

---@alias defold.sidecar.IssueSeverity "error"|"warning"|"info"

---@class defold.sidecar.Range
---@field start defold.sidecar.Position
---@field end   defold.sidecar.Position

---@class defold.sidecar.Position
---@field line      integer
---@field character integer

---@class defold.sidecar.PathEntry
---@field collection_name? string
---@field game_object_id?  string
---@field component_id?    string
---@field from_location?   string
---@field is_component     boolean
---@field same_game_object boolean

---@class defold.sidecar.GuiNodeEntry
---@field id string
---@field from_location string

---@class defold.Sidecar
---@field ensure                   fun(callback: fun(err?: string))
---@field version                  string
---@field set_log_level            fun(level: "debug"|"info"|"error")
---@field read_game_project        fun(path: string): defold.sidecar.GameProject
---@field is_editor_port           fun(port: integer): boolean
---@field list_commands            fun(port: integer): table<string, string>
---@field send_command             fun(port: integer, cmd: string): defold.sidecar.CommandResult
---@field set_default_editor       fun(port: integer, plugin_root: string, launcher_config: defold.config.Launcher)
---@field find_bridge_path         fun(plugin_root: string|nil): string
---@field resolve_nvim_server_addr fun(game_root: string, socket_type: "fsock"|"netsock"|nil): string
---@field focus_neovim             fun(game_root: string)
---@field focus_game               fun(game_root: string)
---@field mobdap_install           fun(): string
---@field annotation_dir           fun(game_root: string, version: string|nil): string
---@field editor_version           fun(game_root: string): string
---@field project_id               fun(game_root: string): string
---@field install_dependencies     fun(game_root: string, force_redownload: boolean|nil)
---@field list_dependency_dirs     fun(game_root: string): string[]
---@field fetch_defold_paths_for   fun(game_root: string, filepath: string): defold.sidecar.PathEntry[]
---@field fetch_gui_nodes_for      fun(game_root: string, filepath: string): defold.sidecar.GuiNodeEntry[]
---@field fetch_input_bindings     fun(game_root: string): string[]
---@field data_dir                 fun(): string
---@field cache_dir                fun(): string

---@param library string
---@param root    string
---@return string
local function install_bridge(library, root)
    local success, result = pcall(function()
        local loader, load_err = package.loadlib(library, "luaopen_defold_nvim_sidecar")
        assert(loader, load_err)
        return loader().find_bridge_path(root)
    end)
    return success and "" or tostring(result)
end

---Load sidecar, then make sure bridge is also downloaded
---@param callback fun(err?: string)
function M.ensure(callback)
    find_rust_lib_rootdir(function(dir, err)
        if not dir then
            callback(err)
            return
        end

        local path = vim.fs.joinpath(dir, lib_name() .. lib_extension())

        local ok, exports = pcall(function()
            if not package.loaded.defold_nvim_sidecar then
                local loader, load_err = package.loadlib(path, "luaopen_defold_nvim_sidecar")
                assert(loader, load_err)
                package.loaded.defold_nvim_sidecar = loader()
            end
            return package.loaded.defold_nvim_sidecar
        end)

        if not ok then
            callback(tostring(exports))
            return
        end

        for name, value in pairs(exports) do
            M[name] = value
        end

        bridge_work = vim.uv.new_work(
            install_bridge,
            vim.schedule_wrap(function(worker_err)
                bridge_work = nil
                callback(worker_err ~= "" and worker_err or nil)
            end)
        )

        bridge_work:queue(path, require("defold.service.os").plugin_root())
    end)
end

---@type defold.Sidecar
return M
