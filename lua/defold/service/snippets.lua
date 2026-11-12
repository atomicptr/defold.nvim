local M = {}

local styles = {
    preserve = true,
    snake_case = true,
    Ada_Case = true,
    PascalCase = true,
}

---@param name string
---@param style defold.snippets.NamingStyle
---@return string
local function format_name(name, style)
    local log = require "defold.service.logger"

    if not styles[style] then
        log.fatal(string.format("Unknown Defold snippet naming style: %s", tostring(style)))
    end

    if style ~= "preserve" then
        local separated = name:gsub("(%u)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2")
        local words = {}

        for word in separated:gmatch "[%a%d]+" do
            word = word:lower()
            if style ~= "snake_case" then
                word = word:sub(1, 1):upper() .. word:sub(2)
            end

            table.insert(words, word)
        end

        name = table.concat(words, style == "PascalCase" and "" or "_")
    end

    if not name:match "^[%a_][%w_]*$" then
        log.fatal(string.format("Cannot generate a class name from: %s", name))
    end

    return name
end

---Build the configured class name for a file in the loaded project
---@param bufnr? integer
---@return string
function M.class_name_from_buffer(bufnr)
    local config = require "defold.config"
    local project = require "defold.project"
    local log = require "defold.service.logger"

    local root = project.project_root()
    if not root then
        log.fatal "No Defold project found"
    end

    local filename = vim.api.nvim_buf_get_name(bufnr or 0)
    local relative = vim.fs.relpath(root, filename)
    if not relative then
        log.fatal "Buffer is outside the Defold project"
    end

    local parts = vim.split(relative, "/", { plain = true })
    local basename = table.remove(parts):gsub("%.[^.]+$", "")
    local class_name = format_name(basename, config.state.snippets.class_naming_style)

    if not config.state.snippets.use_namespaces then
        return class_name
    end

    for index, part in ipairs(parts) do
        parts[index] = format_name(part, config.state.snippets.namespace_naming_style)
    end

    table.insert(parts, class_name)
    return table.concat(parts, ".")
end

function M.install()
    local config = require "defold.config"

    if not config.state.snippets.enable then
        return
    end

    local ok, luasnip = pcall(require, "luasnip")
    if not ok then
        return
    end

    local script = require "defold.script"
    local project = require "defold.project"
    local os = require "defold.service.os"
    local snippets = {}

    luasnip.env_namespace("DEFOLD", {
        vars = { CLASS_NAME = M.class_name_from_buffer },
    })

    for _, kind in pairs(script.kinds) do
        local path = vim.fs.joinpath(os.plugin_root(), "snippets", kind .. ".json")
        local definitions = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))

        ---@return boolean
        local function available()
            return config.state.snippets.enable == true
                and script.detect_kind_from_buffer() == kind
                and project.is_buffer_in_project()
        end

        for name, definition in pairs(definitions) do
            table.insert(
                snippets,
                luasnip.parser.parse_snippet({
                    trig = definition.prefix,
                    name = name,
                    dscr = definition.description,
                    condition = available,
                    show_condition = available,
                }, table.concat(definition.body, "\n"))
            )
        end
    end

    -- replace our earlier snippets if installation runs again
    luasnip.add_snippets("lua", snippets, { key = "defold" })
end

return M
