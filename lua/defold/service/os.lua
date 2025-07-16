local M = {}

---Test if a command exists on the system
---@return boolean
function M.command_exists(cmd)
    return vim.fn.executable(cmd) == 1
end

function M.name()
    return vim.loop.os_uname().sysname:lower()
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

return M
