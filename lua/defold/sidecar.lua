local min_version = "0.8.3"

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

local function lib_name()
    local os = require "defold.service.os"

    if os.is_windows() then
        return "defold_nvim_sidecar"
    end

    return "libdefold_nvim_sidecar"
end

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

---Download latest sidecar release, install it at DATA_DIR/lib and return the lib path
---@return string|nil
local function download_release()
    local log = require "defold.service.logger"
    local os = require "defold.service.os"
    local github = require "defold.service.github"

    local filename = (github_file_name[os.name()] or {})[os.architecture()]

    if not filename then
        log.error(string.format("unsupported platform: %s using %s", os.name(), os.architecture()))
        return nil
    end

    local file, release = github.download_release(github_owner, github_repository, filename)
    if not file or not release then
        return nil
    end

    local lib_dir = vim.fs.joinpath(os.data_dir(), "lib")
    vim.fn.mkdir(lib_dir, "p")

    os.move(file, vim.fs.joinpath(lib_dir, lib_name() .. lib_extension()))

    -- write version to file
    os.write(version_path(), release.tag_name)

    return lib_dir
end

local function find_rust_lib_rootdir()
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
        return vim.fs.joinpath(plugin_root, "target", "debug")
    elseif
        -- check local release build second
        os.file_exists(vim.fs.joinpath(plugin_root, "release", "debug", file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, "release", "debug", file_name_alt))
    then
        return vim.fs.joinpath(plugin_root, "target", "release")
    elseif
        -- and the actual properly installed path last
        os.file_exists(vim.fs.joinpath(lib_dir, file_name))
        or os.file_exists(vim.fs.joinpath(lib_dir, file_name_alt))
    then
        local curr_version = version()

        if not curr_version then
            return download_release()
        end

        -- if current version is lower than the minimum version WE GOTTA UPDATE
        if vim.version.cmp(curr_version, min_version) < 0 then
            log.info(
                string.format("Sidecar minimum version %s exceeds our installed version %s", min_version, curr_version)
            )
            return download_release()
        end

        -- if the version path wasnt updated for a week dont check for new one
        if os.was_updated_within(version_path(), os.days(7)) then
            return lib_dir
        end

        local github = require "defold.service.github"
        local release = github.fetch_release(github_owner, github_repository)

        if not release then
            return lib_dir
        end

        -- if new release
        if vim.version.cmp(curr_version, release.tag_name) < 0 then
            log.info(string.format("Sidecar new release %s (current %s)", release.tag_name, curr_version))
            return download_release()
        end

        -- overwrite file again to delay next check
        os.write(version_path(), release.tag_name)

        return lib_dir
    else
        -- and if that also doesnt exist... download it
        return download_release()
    end
end

local plugin_rootdir = find_rust_lib_rootdir()

package.cpath = package.cpath
    .. ";"
    .. string.format("%s/lib?%s", plugin_rootdir, lib_extension())
    .. ";"
    .. string.format("%s/?%s", plugin_rootdir, lib_extension())

---@class defold.sidecar.GameProject
---@field title        string
---@field dependencies string[]

---@class defold.sidecar.CommandResult
---@field success boolean
---@field issues  defold.sidecar.Issue[]
---@field status  integer

---@class defold.sidecar.Issue
---@field message  string
---@field severity defold.sidecar.IssueSeverity
---@field resource string|nil
---@field range    defold.sidecar.Range|nil

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

---@class Sidecar
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
---@field install_dependencies     fun(game_root: string, force_redownload: boolean|nil)
---@field list_dependency_dirs     fun(game_root: string): string[]
---@field fetch_defold_paths_for   fun(game_root: string, filepath: string): defold.sidecar.PathEntry[]
---@field fetch_input_bindings     fun(game_root: string): string[]
---@field data_dir                 fun(): string
---@field cache_dir                fun(): string

---@type Sidecar
local rust_plugin = require "defold_nvim_sidecar"

return rust_plugin
