local M = {}

function M.extract(file, extract_to)
    vim.fn.system(string.format("unzip -o %s -d %s", file, extract_to))
end

return M
