local M = {}

---@alias defold.download.Callback fun(path: string|nil, err?: string)

---@class defold.download.Options
---@field name         string                                Display name for progress messages.
---@field owner        string                                GitHub repository owner.
---@field repo         string                                GitHub repository name.
---@field asset        string                                Exact release asset filename.
---@field path         string|(fun(version: string): string) Destination, optionally derived from the release tag.
---@field version_path string                                File storing the installed release tag.
---@field version?     string                                Exact release tag; nil selects the latest release.
---@field executable?  boolean                               Set executable permissions on Unix.
---@field archive?     boolean                               Unpack the downloaded asset before installation.
---@field entry?       string                                Relative path to install from the unpacked archive.
---@field local_paths? string[]                              Prefer an existing local build over downloading.
---@field install?     fun(source: string, target: string)   Override the default installation step.

---@class defold.download.Asset
---@field name                 string
---@field browser_download_url string
---@field size?                integer

---@class defold.download.Release
---@field tag_name string
---@field assets   defold.download.Asset[]

---@type table<string, defold.download.Callback[]>
local pending = {}

---Fetch a GitHub release asynchronously (latest when tag is nil).
---@param owner      string
---@param repository string
---@param tag        string|nil
---@param callback   fun(release: defold.download.Release|nil, err?: string)
local function fetch_release(owner, repository, tag, callback)
    local os = require "defold.os"
    local url = string.format("https://api.github.com/repos/%s/%s/releases/latest", owner, repository)

    if tag then
        url = string.format("https://api.github.com/repos/%s/%s/releases/tags/%s", owner, repository, tag)
    end

    os.fetch_json(url, function(release, err)
        if err then
            callback(nil, err)
            return
        end

        if type(release) ~= "table" or type(release.tag_name) ~= "string" or type(release.assets) ~= "table" then
            callback(nil, "Invalid release information from GitHub")
            return
        end

        callback(release)
    end)
end

---@param id       string
---@param title    string
---@param message  string
---@param status   "running"|"success"|"failed"
---@param percent? integer
local function progress(id, title, message, status, percent)
    vim.api.nvim_echo({ { message } }, false, {
        id = id,
        kind = "progress",
        source = "defold.nvim",
        title = title,
        status = status,
        percent = percent,
    })
end

---@param a string|nil
---@param b string
---@return boolean
local function same_version(a, b)
    return a ~= nil and vim.trim(a):gsub("^v", "") == vim.trim(b):gsub("^v", "")
end

---@param path    string
---@param version string
local function save_version(path, version)
    local os = require "defold.os"

    vim.fn.mkdir(vim.fs.dirname(path), "p")
    os.with_tempfile(path, function(temporary, done)
        os.write(temporary, string.format("%s\n", version))
        done()
    end, function(err)
        assert(not err, err)
    end)
end

---@param destination string|(fun(version: string): string)
---@param version     string
---@return string
local function resolve_path(destination, version)
    if type(destination) == "function" then
        return destination(version)
    end

    return destination
end

---@param opts    defold.download.Options
---@param dir     string
---@param target  string
---@param version string
local function install(opts, dir, target, version)
    local os = require "defold.os"
    local log = require "defold.logger"
    local sidecar = require "defold.sidecar"

    local source = vim.fs.joinpath(dir, opts.asset)

    if opts.archive then
        local archive = source

        source = vim.fs.joinpath(dir, "unpacked")
        sidecar.unpack(archive, source)

        if opts.entry then
            source = vim.fs.joinpath(source, opts.entry)
        end
    end

    vim.fn.mkdir(vim.fs.dirname(target), "p")

    if opts.install then
        opts.install(source, target)
    elseif opts.archive then
        sidecar.move(source, target)
    else
        os.with_tempfile(target, function(temporary, done)
            os.copy(source, temporary)
            done()
        end, function(err)
            assert(not err, err)
        end)
    end

    if opts.executable and not os.is_windows() then
        assert(vim.uv.fs_chmod(target, 448))
    end

    save_version(opts.version_path, version)
    log.info(string.format("%s installed: %s", opts.name, target))
end

---Ensure a GitHub release artifact is installed, local files have precedence
---@param opts     defold.download.Options
---@param callback defold.download.Callback
function M.ensure(opts, callback)
    local os = require "defold.os"
    local log = require "defold.logger"

    for _, path in ipairs(opts.local_paths or {}) do
        if os.file_exists(path) then
            log.debug(string.format("Using local %s: %s", opts.name, path))
            callback(path)
            return
        end
    end

    local key = string.format("%s:%s", opts.version_path, opts.version or "latest")

    if pending[key] then
        log.debug(string.format("Waiting for installation: %s", opts.name))
        table.insert(pending[key], callback)
        return
    end

    local read, lines = pcall(vim.fn.readfile, opts.version_path)

    local installed = nil
    if read then
        installed = lines[1]
    end

    local target = nil
    if type(opts.path) == "string" then
        target = opts.path
    elseif opts.version or installed then
        local resolved, value = pcall(opts.path, opts.version or installed)
        if not resolved then
            callback(nil, tostring(value))
            return
        end

        target = value
    end

    if target and os.file_exists(target) then
        local up_to_date
        if opts.version then
            up_to_date = type(opts.path) == "function" or same_version(installed, opts.version)
        else
            up_to_date = os.was_updated_within(opts.version_path, 8 * 60 * 60)
        end

        if up_to_date then
            log.debug(string.format("Using cached %s: %s", opts.name, target))
            callback(target)
            return
        end
    end

    pending[key] = { callback }

    local id = string.format("defold.nvim:%s", key)

    ---@param err? string
    local function finish(err)
        local result = target
        if err then
            result = nil
            log.debug(string.format("Installation failed (%s): %s", opts.name, err))
            progress(id, opts.name, string.format("Installation failed: %s", err), "failed")
        else
            progress(id, opts.name, "Installed", "success", 100)
        end

        local waiting = pending[key]
        pending[key] = nil

        for _, done in ipairs(waiting) do
            local ok, callback_err = pcall(done, result, err)
            if not ok then
                log.error(tostring(callback_err))
            end
        end
    end

    progress(id, opts.name, "Checking release", "running")

    log.debug(string.format("Checking release for %s: %s", opts.name, opts.version or "latest"))
    fetch_release(opts.owner, opts.repo, opts.version, function(release, release_err)
        if not release then
            if not opts.version and installed and target and os.file_exists(target) then
                log.warn(
                    string.format("Could not check release. Using installed %s: %s", opts.name, tostring(release_err))
                )

                -- Throttle failed checks too, without changing the installed version.
                local now = vim.fn.localtime()
                local updated, update_err = vim.uv.fs_utime(opts.version_path, now, now)
                if not updated then
                    log.warn(string.format("Could not update release check time: %s", tostring(update_err)))
                end

                finish()
            else
                local version = opts.version or "latest"
                finish(
                    string.format(
                        "Could not fetch %s release %s: %s",
                        opts.name,
                        version,
                        release_err or "Release not available"
                    )
                )
            end

            return
        end

        log.debug(string.format("Selected release for %s: %s", opts.name, release.tag_name))

        local path_ok, value = pcall(resolve_path, opts.path, release.tag_name)
        if not path_ok then
            finish(tostring(value))
            return
        end

        target = value

        if os.file_exists(target) and (type(opts.path) == "function" or same_version(installed, release.tag_name)) then
            log.debug(string.format("Using installed %s: %s", opts.name, target))

            local saved, save_err = pcall(save_version, opts.version_path, release.tag_name)
            if not saved then
                finish(tostring(save_err))
                return
            end

            finish()
            return
        end

        local asset
        for _, item in ipairs(release.assets or {}) do
            if item.name == opts.asset then
                asset = item
                break
            end
        end
        if not asset then
            finish(
                string.format(
                    "Could not find release asset %s in %s. Builds may still be in progress. Retry later.",
                    opts.asset,
                    release.tag_name
                )
            )
            return
        end

        log.info(string.format("Installing %s %s", opts.name, release.tag_name))
        log.debug(string.format("Selected asset for %s: %s", opts.name, asset.name))
        log.debug(string.format("Installation destination for %s: %s", opts.name, target))

        local initial_percent
        if asset.size and asset.size > 0 then
            initial_percent = 0
        end

        progress(id, opts.name, "Downloading", "running", initial_percent)
        local last_percent = -1

        os.with_tempdir(function(dir, done)
            os.download(asset.browser_download_url, vim.fs.joinpath(dir, opts.asset), function(download_err)
                if download_err then
                    done(download_err)
                    return
                end

                progress(id, opts.name, "Installing", "running", 100)

                local ok, install_err = pcall(install, opts, dir, target, release.tag_name)
                done(not ok and tostring(install_err) or nil)
            end, function(bytes)
                if asset.size and asset.size > 0 then
                    local percent = math.min(99, math.floor(bytes * 100 / asset.size))
                    if percent ~= last_percent then
                        last_percent = percent
                        progress(id, opts.name, "Downloading", "running", percent)
                    end
                end
            end)
        end, finish)
    end)
end

return M
