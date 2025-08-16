local M = {}

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

    -- babashka uses macos and not darwin, so we'll do the same
    if os_name == "darwin" then
        return "macos"
    elseif string.find(os_name, "windows") then
        return "windows"
    end

    return os_name
end

function M.is_windows()
    return M.name() == "windows"
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
        M.exec(string.format('powershell -Command "Invoke-WebRequest -Uri %s -OutFile %s"', url, to_path))
        return
    end

    if M.command_exists "curl" then
        M.exec(string.format("curl -L -s -o '%s' %s", to_path, url))
        return
    end

    if M.command_exists "wget" then
        M.exec(string.format("wget -q -O '%s' %s", to_path, url))
        return
    end

    log.error "Could not find a command to download something like 'curl', 'wget' or 'powershell'"
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
    log.debug("Plugin root: " .. res)
    return res
end

return M
