---@class defold.cmp.BlinkSource : blink.cmp.Source
local M = {}
M.__index = M

local registered = false

---@return defold.cmp.BlinkSource
function M.new()
    return setmetatable({}, M)
end

---@return boolean
function M:enabled()
    return require("defold.completions").get_context() ~= nil
end

---@return string[]
function M:get_trigger_characters()
    return require("defold.completions").get_trigger_characters()
end

---@param ctx      blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
function M:get_completions(ctx, callback)
    local completions = require "defold.completions"

    local context = completions.get_context(ctx.bufnr, ctx.cursor[1], ctx.cursor[2] + 1)
    local items = context and completions.get_completions(context) or {}

    for _, item in ipairs(items) do
        item.kind_icon = item.icon
        item.icon = nil
    end

    callback {
        items = items,
        is_incomplete_backward = true,
        is_incomplete_forward = true,
    }
end

---@param cmp { add_source_provider: fun(id: string, config: blink.cmp.SourceProviderConfig), add_filetype_source: fun(filetype: string, id: string) }
function M.register(cmp)
    if registered then
        return
    end

    cmp.add_source_provider("defold", {
        name = "Defold",
        module = "defold.cmp.blink-cmp",
    })

    cmp.add_filetype_source("lua", "defold")

    registered = true
end

return M
