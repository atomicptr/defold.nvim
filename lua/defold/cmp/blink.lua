---@class defold.cmp.BlinkSource : blink.cmp.Source
---@field opts defold.cmp.BlinkSourceOptions
local M = {}
M.__index = M

---@class defold.cmp.BlinkSourceOptions

---@param opts defold.cmp.BlinkSourceOptions
---@return defold.cmp.BlinkSource
function M.new(opts)
    opts = opts or {}

    local self = setmetatable({}, M)
    self.opts = opts

    return self
end

---@return boolean
function M:enabled()
    if vim.bo.filetype ~= "lua" then
        return false
    end

    local node = vim.treesitter.get_node()

    -- if treesitter isn't working just return true
    if not node then
        return true
    end

    -- make sure we're in a string node
    return node:type() == "string"
end

---@return string[]
function M:get_trigger_characters()
    return { '"', "'", "/", ":", "#" }
end

---@param entry defold.sidecar.PathEntry
---@return lsp.CompletionItem
local function completion_item_from_entry(entry)
    local blink_types = require "blink.cmp.types"

    local path = ""

    if entry.game_object_id and entry.collection_name then
        path = path .. entry.collection_name .. ":"
    end

    if entry.game_object_id then
        path = path .. "/" .. entry.game_object_id
    end

    if entry.component_id then
        path = path .. "#" .. entry.component_id
    end

    local label = path

    if entry.from_location then
        label = label .. " (" .. entry.from_location .. ")"
    end

    ---@type lsp.CompletionItem
    return {
        label = label,
        insertText = path,
        filterText = path,
        kind = (entry.same_game_object and blink_types.CompletionItemKind.Property)
            or (entry.is_component and blink_types.CompletionItemKind.Variable)
            -- game object
            or blink_types.CompletionItemKind.Struct,
        kind_icon = entry.is_component and "󰒓" or "",
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        sortText = string.format(
            "%s|%s:/%s#%s",
            entry.same_game_object and "a" or "b",
            entry.collection_name or "a",
            entry.game_object_id or "a",
            entry.component_id or "a"
        ),
    }
end

---@param filename string
---@return lsp.CompletionItem[]
local function get_script_completions(filename)
    local sidecar = require "defold.sidecar"
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local path_entries_ok, path_entries = pcall(sidecar.fetch_defold_paths_for, project.project_root(), filename)
    if not path_entries_ok then
        log.error(string.format("could not fetch defold paths: %s", path_entries))
        return {}
    end

    ---@type lsp.CompletionItem[]
    local items = {}

    ---@cast path_entries defold.sidecar.PathEntry[]

    for _, entry in ipairs(path_entries) do
        local item = completion_item_from_entry(entry)

        table.insert(items, item)

        -- if item has a collection name, add also the version without it
        if entry.collection_name then
            entry.collection_name = nil
            table.insert(items, completion_item_from_entry(entry))
        end
    end

    return items
end

---@return lsp.CompletionItem[]
local function get_input_binding_completions()
    local blink_types = require "blink.cmp.types"

    local sidecar = require "defold.sidecar"
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local bindings_ok, bindings = pcall(sidecar.fetch_input_bindings, project.project_root())
    if not bindings_ok then
        log.error(string.format("could not fetch input bindings: %s", bindings))
        return {}
    end

    ---@type lsp.CompletionItem[]
    local items = {}

    for _, binding in ipairs(bindings) do
        table.insert(items, {
            label = binding,
            kind = blink_types.CompletionItemKind.Property,
            kind_icon = "󱇰",
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        })
    end

    return items
end

---@param ctx      blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
function M:get_completions(ctx, callback)
    local filename = vim.api.nvim_buf_get_name(ctx.bufnr)
    local ext = vim.fs.ext(filename)

    ---@type lsp.CompletionItem[]
    local items = {}

    if ext == "script" then
        items = vim.list_extend(items, get_script_completions(filename))
        items = vim.list_extend(items, get_input_binding_completions())
    elseif ext == "gui_script" then
        -- TODO: add support for .gui_script stuff
        items = vim.list_extend(items, get_input_binding_completions())
    end

    callback {
        items = items,
        is_incomplete_backward = true,
        is_incomplete_forward = true,
    }
end

function M.register()
    local log = require "defold.service.logger"

    local cmp_ok, cmp = pcall(require, "blink.cmp")
    if not cmp_ok then
        log.warn "completions enabled but could not find plugin: saghen/blink.cmp"
        return
    end

    cmp.add_source_provider("defold", {
        name = "Defold",
        module = "defold.cmp.blink",
    })

    cmp.add_filetype_source("lua", "defold")
end

return M
