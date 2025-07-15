local M = {}

function M.kebab_case_to_pascal_case(text)
    assert(type(text) == "string")

    local parts = {}

    for _, part in ipairs(vim.fn.split(text, "-")) do
        table.insert(parts, string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2))
    end

    return table.concat(parts)
end

return M
