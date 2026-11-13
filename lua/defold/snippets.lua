local M = {}

local styles = {
    preserve = true,
    snake_case = true,
    Ada_Case = true,
    PascalCase = true,
}

---@param name  string
---@param style defold.snippets.NamingStyle
---@return string? name
---@return string? error
local function format_name(name, style)
    if not styles[style] then
        return nil, string.format("Unknown Defold snippet naming style: %s", tostring(style))
    end

    if style ~= "preserve" then
        local separated = name:gsub("(%u)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2")
        local words = {}

        for token in separated:gmatch "[%a%d]+" do
            local word = token:lower()
            if style ~= "snake_case" then
                word = string.format("%s%s", word:sub(1, 1):upper(), word:sub(2))
            end

            table.insert(words, word)
        end

        name = table.concat(words, style == "PascalCase" and "" or "_")
    end

    if not name:match "^[%a_][%w_]*$" then
        return nil, string.format("Cannot generate a class name from: %s", name)
    end

    return name
end

---Build a class name from a project-relative filename and explicit naming options.
---@param relative string
---@param options  defold.config.Snippets
---@return string? name
---@return string? error
function M.class_name_from_relative(relative, options)
    local parts = {}

    for part in string.format("%s/", relative):gmatch "(.-)/" do
        table.insert(parts, part)
    end

    local basename = table.remove(parts):gsub("%.[^.]+$", "")
    local class_name, err = format_name(basename, options.class_naming_style)
    if not class_name then
        return nil, err
    end

    if not options.use_namespaces then
        return class_name
    end

    for index, part in ipairs(parts) do
        local namespace, namespace_err = format_name(part, options.namespace_naming_style)
        if not namespace then
            return nil, namespace_err
        end

        parts[index] = namespace
    end

    table.insert(parts, class_name)
    return table.concat(parts, ".")
end

---Build the configured class name for a file in the loaded project
---@param bufnr? integer
---@return string
function M.class_name_from_buffer(bufnr)
    local config = require "defold.config"
    local project = require "defold.project"
    local log = require "defold.logger"

    local root = project.project_root()
    if not root then
        log.fatal "No Defold project found"
    end

    local filename = vim.api.nvim_buf_get_name(bufnr or 0)
    local relative = vim.fs.relpath(root, filename)
    if not relative then
        log.fatal "Buffer is outside the Defold project"
    end

    local class_name, err = M.class_name_from_relative(relative, config.state.snippets)
    if not class_name then
        log.fatal(err)
    end

    return class_name
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
    local os = require "defold.os"
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
