local M = {}

local default_ttl = 5 * 60
local png_signature = "\137PNG\r\n\26\n"

---@alias defold.preview.Callback fun(path: string|nil, err?: string)

---@class defold.preview.Options
---@field root_dir? string Project root, tries to find the current one when nil
---@field ttl?      number Cache lifetime in seconds (default: 300)

---@type table<string, defold.preview.Callback[]>
local pending = {}

---@param path string
---@return boolean
local function is_png(path)
    local fd = vim.uv.fs_open(path, "r", 0)
    if not fd then
        return false
    end

    local signature = vim.uv.fs_read(fd, #png_signature, 0)
    vim.uv.fs_close(fd)
    return signature == png_signature
end

---Get a cached scene preview as an absolute PNG path
---@param resource_path string Defold path relative to the project root
---@param callback      defold.preview.Callback
---@param opts?         defold.preview.Options
function M.get_file(resource_path, callback, opts)
    callback = vim.schedule_wrap(callback)
    opts = opts or {}

    local ttl = opts.ttl
    if ttl == nil then
        ttl = default_ttl
    end

    if type(ttl) ~= "number" or ttl ~= ttl or ttl < 0 or ttl == math.huge then
        callback(nil, "invalid ttl specified")
        return
    end

    local project = require "defold.project"
    local sidecar = require "defold.sidecar"
    local osm = require "defold.service.os"

    local root, resource, resolve_err = project.resolve_resource(resource_path, opts.root_dir)
    if not root or not resource then
        callback(nil, resolve_err)
        return
    end

    local ok, dir = pcall(function()
        local path = vim.fs.joinpath(osm.cache_dir(), "previews", sidecar.project_id(root))
        vim.fn.mkdir(path, "p")
        return vim.fs.abspath(path)
    end)

    if not ok then
        callback(nil, string.format("could not create preview cache: %s", tostring(dir)))
        return
    end

    local key = vim.fn.sha256(string.format("%s\n%s", root, resource))
    local target = vim.fs.joinpath(dir, string.format("%s.png", key))
    local stat = vim.uv.fs_stat(target)
    if stat and stat.type == "file" and osm.was_updated_within(target, ttl) and is_png(target) then
        callback(target, nil)
        return
    end

    if pending[target] then
        table.insert(pending[target], callback)
        return
    end

    local port = project.get_editor_port(root)
    if not port then
        callback(nil, "could not find Defold editor, is it running?")
        return
    end

    pending[target] = { callback }

    ---@param err? string
    local function finish(err)
        local waiting = pending[target]
        pending[target] = nil

        for _, done in ipairs(waiting) do
            done(not err and target or nil, err)
        end
    end

    local encoded = resource:gsub("([^%w%-%._~/])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)

    local url = string.format("http://127.0.0.1:%d/preview/%s", port, encoded)

    osm.with_tempfile(target, function(temporary, done)
        osm.download(url, temporary, function(err)
            if err then
                done(string.format("could not fetch Defold preview: %s", err))
                return
            end

            if not is_png(temporary) then
                done "Defold did not return an image preview for this resource"
                return
            end

            done()
        end)
    end, finish)
end

return M
