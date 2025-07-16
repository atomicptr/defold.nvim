local os = require "defold.service.os"

local M = {}

---Send GET request to url
---@param url string
---@return string
function M.get(url)
    if not os.command_exists "curl" then
        vim.notify("Could not find command 'curl'", vim.log.levels.ERROR)
        return ""
    end

    return vim.fn.system(string.format("curl -s %s", url))
end

---Download file at url and download it to to_path
---@param url string
---@param to_path string
function M.download(url, to_path)
    if not os.command_exists "curl" then
        vim.notify("Could not find command 'curl'", vim.log.levels.ERROR)
        return
    end

    vim.fn.system(string.format("curl -L -s -o '%s' %s", to_path, url))
end

---Send POST request to url
---@param url string
---@return string
function M.post(url)
    if not os.command_exists "curl" then
        vim.notify("Could not find command 'curl'", vim.log.levels.ERROR)
        return ""
    end

    return vim.fn.system(string.format("curl -s -X POST %s", url))
end

return M
