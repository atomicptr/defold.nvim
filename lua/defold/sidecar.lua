local M = {}

local ready = false

---@type string?
local library_path

---@type function[]
local callbacks = {}

local downloading = false

---@class defold.sidecar.GameProject
---@field title        string
---@field dependencies string[]
---@field library?     defold.sidecar.Library

---@class defold.sidecar.Library
---@field include_dirs string[]

---@class defold.sidecar.CommandResult
---@field success boolean
---@field issues  defold.sidecar.Issue[]
---@field status  integer
---@field target? { url: string }

---@class defold.sidecar.Issue
---@field message   string
---@field severity  defold.sidecar.IssueSeverity
---@field resource? string
---@field range?    defold.sidecar.Range

---@alias defold.sidecar.IssueSeverity "error"|"warning"|"info"
---@alias defold.sidecar.WorkerValue nil|boolean|number|string
---@alias defold.sidecar.WorkerCallback fun(result: defold.sidecar.WorkerValue, err?: string)
---@alias defold.sidecar.WorkerCall fun(fn: string, cb: defold.sidecar.WorkerCallback, ...: defold.sidecar.WorkerValue)

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
---@field id            string
---@field from_location string

---@class defold.Sidecar
---@field ensure                   fun(callback?: fun())
---@field is_ready                 fun(): boolean
---@field unpack                   fun(archive: string, target: string)
---@field move                     fun(source: string, target: string)
---@field hash                     fun(input: string): string
---@field install_dependency       fun(source: string, target: string)
---@field version                  string
---@field set_log_level            fun(level: "debug"|"info"|"error")
---@field read_game_project        fun(path: string): defold.sidecar.GameProject
---@field is_editor_port           fun(port: integer): boolean
---@field list_commands            fun(port: integer): table<string, string>
---@field send_command             fun(port: integer, cmd: string): defold.sidecar.CommandResult
---@field set_default_editor       fun(port: integer, bridge_path: string, launcher_config: defold.config.Launcher)
---@field bridge_path              string Selected executable, available after ensure completes.
---@field start_native_debugger    fun(url: string, port: integer, address?: string): integer
---@field worker_call              defold.sidecar.WorkerCall
---@field resolve_nvim_server_addr fun(game_root: string, socket_type: "fsock"|"netsock"|nil): string
---@field focus_neovim             fun(game_root: string)
---@field focus_game               fun(game_root: string)
---@field editor_version           fun(game_root: string): string
---@field project_id               fun(game_root: string): string
---@field list_dependency_dirs     fun(game_root: string): string[]
---@field fetch_defold_paths_for   fun(game_root: string, filepath: string): defold.sidecar.PathEntry[]
---@field fetch_gui_nodes_for      fun(game_root: string, filepath: string): defold.sidecar.GuiNodeEntry[]
---@field fetch_input_bindings     fun(game_root: string): string[]
---@field data_dir                 fun(): string
---@field cache_dir                fun(): string

---@param path string
local function load(path)
    local log = require "defold.service.logger"
    library_path = path

    if not package.loaded.defold_nvim_sidecar then
        log.debug(string.format("Loading plugin library: %s", path))

        local loader, err = package.loadlib(path, "luaopen_defold_nvim_sidecar")
        if not loader then
            log.fatal(err)
        end

        package.loaded.defold_nvim_sidecar = loader()
    else
        log.debug "Using the already loaded plugin library"
    end

    for name, value in pairs(package.loaded.defold_nvim_sidecar) do
        M[name] = value
    end
end

function M.is_ready()
    return ready
end

---Call a sidecar function in an isolated worker and send the result back to the main thread
---@param method   string
---@param callback defold.sidecar.WorkerCallback
---@param ...      defold.sidecar.WorkerValue
function M.worker_call(method, callback, ...)
    if not library_path then
        callback(nil, "Defold sidecar is not loaded")
        return
    end

    local ok, queued, err = pcall(function(...)
        -- workers have isolated lua states so we need to load sidecar ourselves
        ---@param library string
        ---@param name string
        ---@param ... defold.sidecar.WorkerValue
        ---@return boolean, defold.sidecar.WorkerValue
        local function invoke(library, name, ...)
            local success, result = pcall(function(...)
                local instance = assert(package.loadlib(library, "luaopen_defold_nvim_sidecar"))()
                return instance[name](...)
            end, ...)

            if not success then
                return false, tostring(result)
            end

            local kind = type(result)

            if kind ~= "nil" and kind ~= "boolean" and kind ~= "number" and kind ~= "string" then
                return false, "sidecar.worker_call supports only scalar results"
            end

            return true, result
        end

        local work = vim.uv.new_work(
            invoke,
            vim.schedule_wrap(function(success, result)
                if success then
                    callback(result)
                else
                    callback(nil, result)
                end
            end)
        )

        return work:queue(library_path, method, ...)
    end, ...)

    if not ok then
        callback(nil, tostring(queued))
    elseif not queued then
        callback(nil, err or "Could not queue sidecar call")
    end
end

---@param callback? fun() Called after the sidecar and bridge are ready
function M.ensure(callback)
    local log = require "defold.service.logger"

    if ready then
        if callback then
            local ok, err = pcall(callback)
            if not ok then
                log.error(tostring(err))
            end
        end

        return
    end

    local os = require "defold.service.os"
    local download = require "defold.download"

    if callback then
        table.insert(callbacks, callback)
    end

    if not downloading then
        downloading = true

        local was_repaired = false

        local function finish(err)
            downloading = false
            local waiting = callbacks
            callbacks = {}

            if err then
                log.error(string.format("Installation failed: %s", err))
                return
            end

            ready = true
            log.debug "Installation is ready"

            if was_repaired then
                log.info "Repair successful"
            end

            for _, done in ipairs(waiting) do
                local ok, callback_err = pcall(done)
                if not ok then
                    log.error(tostring(callback_err))
                end
            end
        end

        local ok, err = pcall(function()
            was_repaired = require("defold.repair").apply_pending() or false

            local version = string.format("v%s", require "defold.version")
            local prefixes = {
                linux = { amd64 = "linux-x86" },
                macos = { amd64 = "macos-x86", aarch64 = "macos-arm" },
                windows = { amd64 = "windows-x86" },
            }

            local platform = (prefixes[os.name()] or {})[os.architecture()]
            if not platform then
                finish(string.format("Unsupported platform: %s/%s", os.name(), os.architecture()))
                return
            end

            local filename = "libdefold_nvim_sidecar.so"

            if os.is_windows() then
                filename = "defold_nvim_sidecar.dll"
            elseif os.is_macos() then
                filename = "libdefold_nvim_sidecar.dylib"
            end

            local root = os.plugin_root()
            local data = os.data_dir()

            download.ensure({
                name = "Defold sidecar",
                owner = "atomicptr",
                repo = "defold.nvim",
                version = version,
                asset = string.format("%s-%s", platform, filename),

                path = vim.fs.joinpath(data, "lib", filename),
                version_path = vim.fs.joinpath(data, "meta", "sidecar_version"),

                local_paths = {
                    vim.fs.joinpath(root, "target", "debug", filename),
                },
            }, function(path, sidecar_err)
                if not path then
                    finish(sidecar_err)
                    return
                end

                local loaded, load_err = pcall(load, path)
                if not loaded then
                    finish(tostring(load_err))
                    return
                end

                data = M.data_dir()

                local bridge = "defold-nvim-bridge"

                if os.is_windows() then
                    bridge = bridge .. ".exe"
                end

                download.ensure({
                    name = "Defold bridge",
                    owner = "atomicptr",
                    repo = "defold.nvim",
                    version = version,
                    asset = string.format("%s-defold-nvim-bridge", platform),
                    executable = true,

                    path = vim.fs.joinpath(data, "bin", bridge),
                    version_path = vim.fs.joinpath(data, "meta", "defold-nvim-bridge_version"),

                    local_paths = {
                        vim.fs.joinpath(root, "target", "debug", bridge),
                    },
                }, function(bridge_path, bridge_err)
                    M.bridge_path = bridge_path
                    finish(bridge_err)
                end)
            end)
        end)

        if not ok then
            finish(tostring(err))
        end
    end

    if not callback and #vim.api.nvim_list_uis() == 0 then
        if not vim.wait(120000, function()
            return not downloading
        end) then
            log.fatal "Installation timed out"
        end

        if not ready then
            log.fatal "Installation failed"
        end
    end
end

---@type defold.Sidecar
return M
