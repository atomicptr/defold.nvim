local M = {}

local callback = "v:lua.require'defold.cmp.native'.complete"

---@class defold.cmp.NativeState
---@field previous   string
---@field use_defold boolean?

---@type table<integer, defold.cmp.NativeState>
local states = {}

---@param findstart integer
---@param base      string
---@return integer|table
function M.complete(findstart, base)
    local completions = require "defold.completions"
    local context = completions.get_context()
    local state = states[vim.api.nvim_get_current_buf()]

    if state and findstart == 1 then
        state.use_defold = context ~= nil and context.in_string
    end

    if state and not state.use_defold then
        if state.previous == "" then
            return findstart == 1 and -3 or {}
        end

        if state.previous:sub(1, 6) == "v:lua." then
            return vim.api.nvim_eval(string.format("%s(%d, %s)", state.previous, findstart, vim.fn.string(base)))
        end

        return vim.fn.call(state.previous, { findstart, base })
    end

    if findstart == 1 then
        return context and (context.start_col - 1) or -3
    end

    local matches = {}

    if context then
        for _, item in ipairs(completions.get_completions(context)) do
            local word = item.insertText or (item.textEdit and item.textEdit.newText) or item.label

            if word:sub(1, #base) == base then
                table.insert(matches, {
                    word = word,
                    abbr = item.label,
                    kind = vim.lsp.protocol.CompletionItemKind[item.kind] or "Text",
                    dup = 1,
                })
            end
        end
    end

    return { words = matches, refresh = "always" }
end

function M.register()
    ---@param bufnr integer
    local function install(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or not require("defold.completions").is_buffer_supported(bufnr) then
            return
        end

        local previous = vim.bo[bufnr].completefunc

        if states[bufnr] or previous == callback then
            return
        end

        states[bufnr] = { previous = previous }
        vim.api.nvim_set_option_value("completefunc", callback, { buf = bufnr })
    end

    local group = vim.api.nvim_create_augroup("DefoldNativeCompletion", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
        group = group,
        ---@param event { buf: integer }
        callback = function(event)
            install(event.buf)
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        ---@param event { buf: integer }
        callback = function(event)
            states[event.buf] = nil
        end,
    })

    install(vim.api.nvim_get_current_buf())
end

return M
