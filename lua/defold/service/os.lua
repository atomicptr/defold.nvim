local M = {}

local user_agent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

---Test if a command exists on the system
---@return boolean
function M.command_exists(cmd)
    return vim.fn.executable(cmd) == 1
end

function M.name()
    local os_name = vim.uv.os_uname().sysname:lower()

    if os_name == "darwin" then
        return "macos"
    elseif string.find(os_name, "windows") then
        return "windows"
    end

    return os_name
end

---Test if the OS is Linux
---@return boolean
function M.is_linux()
    return M.name() == "linux"
end

---Test if the OS is Windows
---@return boolean
function M.is_windows()
    return M.name() == "windows"
end

---Test if the OS is MacOS
---@return boolean
function M.is_macos()
    return M.name() == "macos"
end

function M.architecture()
    local machine = vim.uv.os_uname().machine

    if machine == "x86_64" then
        return "amd64"
    elseif
        machine == "aarch64"
        or machine == "aarch64_be"
        or machine == "arm64"
        or machine == "armv8b"
        or machine == "armv8l"
    then
        return "aarch64"
    else
        return "unknown"
    end
end

---Download file asynchronously at url and download it to to_path
---@param url          string
---@param to_path      string
---@param callback     fun(err?: string)
---@param on_progress? fun(bytes: integer)
function M.download(url, to_path, callback, on_progress)
    local log = require "defold.service.logger"
    local command

    if M.is_windows() then
        ---@param value string
        ---@return string
        local function quote(value)
            return string.format("'%s'", value:gsub("'", "''"))
        end

        command = {
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            string.format(
                "$ErrorActionPreference = 'Stop'; Invoke-WebRequest -Uri %s -UserAgent %s -OutFile %s",
                quote(url),
                quote(user_agent),
                quote(to_path)
            ),
        }
    elseif M.command_exists "curl" then
        command = { "curl", "-fLsS", "--user-agent", user_agent, "-o", to_path, url }
    elseif M.command_exists "wget" then
        command = { "wget", "-q", "--user-agent", user_agent, "-O", to_path, url }
    else
        callback "Could not find curl, wget or PowerShell"
        return
    end

    local timer = nil

    if on_progress then
        timer = vim.uv.new_timer()
    end

    local function finish(err)
        if err then
            log.debug(string.format("Download failed: %s: %s", url, err))
        else
            log.debug(string.format("Download completed: %s", to_path))
        end

        if timer then
            timer:stop()
            timer:close()
        end

        callback(err)
    end

    if timer then
        timer:start(
            0,
            100,
            vim.schedule_wrap(function()
                if not timer:is_closing() then
                    local stat = vim.uv.fs_stat(to_path)
                    if stat and on_progress then
                        on_progress(stat.size)
                    end
                end
            end)
        )
    end

    log.debug(string.format("Downloading %s to %s", url, to_path))

    local ok, err = pcall(
        vim.system,
        command,
        { text = true },
        vim.schedule_wrap(function(result)
            if result.code ~= 0 then
                finish(string.format("Download failed: %s (exit %d)", result.stderr or "", result.code))
                return
            end

            finish()
        end)
    )

    if not ok then
        finish(tostring(err))
    end
end

---Fetch JSON asynchronously.
---@param url      string
---@param callback fun(data: any, err?: string)
function M.fetch_json(url, callback)
    local tmp_path = vim.fn.tempname()
    M.download(url, tmp_path, function(err)
        if err then
            os.remove(tmp_path)
            callback(nil, err)
            return
        end

        local ok, data = pcall(function()
            return vim.json.decode(table.concat(vim.fn.readfile(tmp_path), "\n"))
        end)
        os.remove(tmp_path)
        if not ok then
            callback(nil, tostring(data))
            return
        end

        callback(data)
    end)
end

---Create a temp file and rename it onto the target on success
---@param target   string
---@param writer   fun(temporary: string, done: fun(err?: string))
---@param callback fun(err?: string)
function M.with_tempfile(target, writer, callback)
    local fd, temporary = vim.uv.fs_mkstemp(string.format("%s.XXXXXX", target))
    if not fd then
        callback(tostring(temporary))
        return
    end

    local completed = false

    local function done(err)
        if completed then
            return
        end

        completed = true

        if not err then
            local renamed, rename_err = vim.uv.fs_rename(temporary, target)
            if renamed then
                callback()
                return
            end

            err = tostring(rename_err)
        end

        local removed, cleanup_err, cleanup_code = vim.uv.fs_unlink(temporary)
        if not removed and cleanup_code ~= "ENOENT" then
            err = string.format("%s: cleanup failed: %s", err, cleanup_err)
        end

        callback(err)
    end

    local closed, close_err = vim.uv.fs_close(fd)
    if not closed then
        done(tostring(close_err))
        return
    end

    local ok, writer_err = pcall(writer, temporary, done)
    if not ok then
        if completed then
            error(writer_err, 0)
        end

        done(tostring(writer_err))
    end
end

---Copy a file, creating its destination directory.
---@param source string
---@param target string
function M.copy(source, target)
    local log = require "defold.service.logger"

    vim.fn.mkdir(vim.fs.dirname(target), "p")
    local ok, err = vim.uv.fs_copyfile(source, target)
    if not ok then
        log.fatal(tostring(err))
    end
end

---Write text
---@param path    string
---@param content string
function M.write(path, content)
    local log = require "defold.service.logger"

    local file, err = io.open(path, "w")
    if not file then
        return log.fatal(tostring(err))
    end

    local written, write_err = file:write(content)
    local closed, close_err = file:close()

    if not written or not closed then
        log.fatal(tostring(write_err or close_err))
    end
end

---@param path      string
---@param threshold number Seconds (fractional values allowed).
---@return boolean
function M.was_updated_within(path, threshold)
    local stat = vim.uv.fs_stat(path)
    if not stat then
        return false
    end

    local age = vim.fn.localtime() - stat.mtime.sec
    return age >= 0 and age < threshold
end

function M.file_exists(path)
    return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

---Find the root dir of our plugin
---@return string
function M.plugin_root()
    local log = require "defold.service.logger"

    local script_path = debug.getinfo(1, "S").source

    if string.sub(script_path, 1, 1) ~= "@" then
        log.error "Could not find plugin root"
        return ""
    end

    local res = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2)))))
    return res
end

---Returns `Data` directory
---@return string
function M.data_dir()
    if M.is_linux() then
        if vim.env.XDG_DATA_HOME then
            local dir = vim.fs.joinpath(vim.env.XDG_DATA_HOME, "defold.nvim")
            vim.fn.mkdir(dir, "p")
            return dir
        end
    end

    local dir = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim")
    vim.fn.mkdir(dir, "p")
    return dir
end

---Returns `Cache` directory
---@return string
function M.cache_dir()
    if M.is_linux() then
        if vim.env.XDG_CACHE_HOME then
            local dir = vim.fs.joinpath(vim.env.XDG_CACHE_HOME, "defold.nvim")
            vim.fn.mkdir(dir, "p")
            return dir
        end
    end

    local dir = vim.fs.joinpath(vim.fn.stdpath "cache", "defold.nvim")
    vim.fn.mkdir(dir, "p")
    return dir
end

---Read file to string
---@param path string
---@return string|nil
function M.read_to_string(path)
    local file = io.open(path, "r")

    if not file then
        local log = require "defold.service.logger"
        log.error(string.format("Could not open file for reading: %s", path))
        return nil
    end

    local content = file:read "*all"
    file:close()

    return content
end

return M
