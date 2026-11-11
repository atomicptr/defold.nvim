local M = {}

local user_agent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

---@param command string
---@return string
function M.exec(command)
    local log = require "defold.service.logger"

    log.debug("Exec: " .. command)
    local res = vim.fn.system(command)
    log.debug("Result => " .. res)
    return res
end

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
---@param url string
---@param to_path string
---@param callback fun(err?: string)
function M.download(url, to_path, callback)
    local command

    if M.is_windows() then
        ---@param value string
        ---@return string
        local function quote(value)
            return "'" .. value:gsub("'", "''") .. "'"
        end

        command = {
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "$ErrorActionPreference = 'Stop'; Invoke-WebRequest -Uri " .. quote(url) .. " -UserAgent " .. quote(
                user_agent
            ) .. " -OutFile " .. quote(to_path),
        }
    elseif M.command_exists "curl" then
        command = { "curl", "-fLsS", "--user-agent", user_agent, "-o", to_path, url }
    elseif M.command_exists "wget" then
        command = { "wget", "-q", "--user-agent", user_agent, "-O", to_path, url }
    else
        callback "Could not find curl, wget or PowerShell"
        return
    end

    local ok, err = pcall(
        vim.system,
        command,
        { text = true },
        vim.schedule_wrap(function(result)
            callback(
                result.code ~= 0 and ("Download failed: " .. (result.stderr or "") .. " (exit " .. result.code .. ")")
                    or nil
            )
        end)
    )
    if not ok then
        callback(tostring(err))
    end
end

---Fetch JSON asynchronously.
---@param url string
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
        callback(ok and data or nil, not ok and tostring(data) or nil)
    end)
end

---Move file from location a to b
---@param from_path string
---@param to_path string
function M.move(from_path, to_path)
    if M.is_windows() then
        M.exec(string.format("powershell.exe -Command \"Move-Item -Path '%s' -Destination '%s'\"", from_path, to_path))
        return
    end

    M.exec(string.format("mv '%s' '%s'", from_path, to_path))
end

---Make application executable
---@param path any
function M.make_executable(path)
    if M.is_windows() then
        return
    end
    M.exec(string.format("chmod +x '%s'", path))
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

---Writes (and overwrites if present) `content` to `path`
---@param path string
---@param content string
function M.write(path, content)
    local file = io.open(path, "w")

    if not file then
        local log = require "defold.service.logger"
        log.error(string.format("Could not open file for writing: %s", path))
        return
    end

    file:write(content)
    file:close()
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

---Checks if a file was updated within `threshold`
---@param path string
---@param threshold integer time in seconds
---@return boolean
function M.was_updated_within(path, threshold)
    local stat = vim.uv.fs_stat(path)
    if not stat then
        return false -- doesnt exist, wasnt updated
    end

    local current_time = os.time()
    local last_modified = stat.mtime.sec

    return (current_time - last_modified) <= threshold
end

---@param n integer
---@return integer
function M.hours(n)
    return n * 60 * 60
end

---@param n integer
---@return integer
function M.days(n)
    return n * M.hours(24)
end

return M
