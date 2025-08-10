local M = {}

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
    if M.is_windows() then
        vim.fn.system(string.format('powershell -Command "Invoke-WebRequest -Uri %s -OutFile %s"', url, to_path))
        return
    end

    if not M.command_exists "curl" then
        vim.notify("Could not find command 'curl'", vim.log.levels.ERROR)
        return
    end

    vim.fn.system(string.format("curl -L -s -o '%s' %s", to_path, url))
end

function M.file_exists(path)
    return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

---Find the root dir of our plugin
---@return string
function M.plugin_root()
    local script_path = debug.getinfo(1, "S").source

    if not string.sub(script_path, 1, 1) == "@" then
        vim.notify("Could not find bb.edn", vim.log.levels.ERROR)
        return ""
    end

    return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(string.sub(script_path, 2)))))
end

return M
