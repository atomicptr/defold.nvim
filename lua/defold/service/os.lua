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
    local os_name = vim.loop.os_uname().sysname:lower()

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
    local machine = vim.loop.os_uname().machine

    if machine == "x86_64" then
        return "amd64"
    elseif machine == "aarch64_be" or machine == "aarch64" or machine == "armv8b" or machine == "armv8l" then
        return "aarch64"
    else
        return "unknown"
    end
end

---Download file at url and download it to to_path
---@param url string
---@param to_path string
function M.download(url, to_path)
    local log = require "defold.service.logger"

    log.debug(string.format("Downloading '%s' to '%s'", url, to_path))

    if M.is_windows() then
        M.exec(
            string.format(
                'powershell -Command "Invoke-WebRequest -Uri \\"%s\\" -UserAgent \\"%s\\" -OutFile \\"%s\\""',
                url,
                user_agent,
                to_path
            )
        )
        return
    end

    if M.command_exists "curl" then
        M.exec(string.format("curl -L -s --user-agent '%s' -o '%s' %s", user_agent, to_path, url))
        return
    end

    if M.command_exists "wget" then
        M.exec(string.format("wget -q --user-agent '%s' -O '%s' %s", user_agent, to_path, url))
        return
    end

    log.error "Could not find a command to download something like 'curl', 'wget' or 'powershell'"
end

---Fetch json via url and return it as a lua table. Returns nil on error
---@param url string
---@return table|nil
function M.fetch_json(url)
    local log = require "defold.service.logger"

    log.debug(string.format("Fetching JSON from '%s'", url))

    local tmp_path = os.tmpname()
    M.download(url, tmp_path)

    local file = io.open(tmp_path, "r")
    if not file then
        log.error "Failed to open downloaded json file"
        os.remove(tmp_path)
        return nil
    end

    local data = file:read "*a"
    file:close()
    os.remove(tmp_path)

    return vim.json.decode(data)
end

---Move file from location a to b
---@param from_path string
---@param to_path string
function M.move(from_path, to_path)
    if M.is_windows() then
        M.exec(
            string.format(
                'powershell.exe -Command "Move-Item -Path \\"%s\\" -Destination \\"%s\\""',
                from_path,
                to_path
            )
        )
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

return M
