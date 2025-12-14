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

local function find_rust_lib_rootdir()
    local os = require "defold.service.os"
    local plugin_root = os.plugin_root()

    local file_name = string.format("defold_nvim_sidecar%s", lib_extension())
    local file_name_alt = string.format("libdefold_nvim_sidecar%s", lib_extension())

    if
        os.file_exists(vim.fs.joinpath(plugin_root, file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, file_name_alt))
    then
        return plugin_root
    elseif
        os.file_exists(vim.fs.joinpath(plugin_root, "target", "debug", file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, "target", "debug", file_name_alt))
    then
        return vim.fs.joinpath(plugin_root, "target", "debug")
    elseif
        os.file_exists(vim.fs.joinpath(plugin_root, "release", "debug", file_name))
        or os.file_exists(vim.fs.joinpath(plugin_root, "release", "debug", file_name_alt))
    then
        return vim.fs.joinpath(plugin_root, "target", "release")
    else
        -- TODO: add auto download
        error "Error: Could not find rust lib"
    end
end

local plugin_rootdir = find_rust_lib_rootdir()

package.cpath = package.cpath
    .. ";"
    .. string.format("%s/lib?%s", plugin_rootdir, lib_extension())
    .. ";"
    .. string.format("%s/?%s", plugin_rootdir, lib_extension())

---@class GameProject
---@field title string
---@field dependencies string[]

---@class Sidecar
---@field version string
---@field sha3 function(input: string): string
---@field read_game_project function(path: string): GameProject
---@field find_editor_port function(): integer
---@field list_commands function(port: integer|nil): table<string, string>
---@field send_command function(port: integer|nil, cmd: string)
---@field set_default_editor function(plugin_root: string, launch_config: string)
---@field focus_neovim function(game_root: string)
---@field focus_game function(game_root: string)

---@type Sidecar
local rust_plugin = require "defold_nvim_sidecar"

return rust_plugin
