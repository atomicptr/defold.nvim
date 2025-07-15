local M = {}

function M.get(url)
    return vim.fn.system(string.format("curl -s %s", url))
end

function M.post(url)
    return vim.fn.system(string.format("curl -s -X POST %s", url))
end

return M
