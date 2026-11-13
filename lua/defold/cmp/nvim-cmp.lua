local M = {}

local registered = false

---@return boolean
function M:is_available()
    return require("defold.completions").get_context() ~= nil
end

---@return "utf-8"
function M:get_position_encoding_kind()
    return "utf-8"
end

---@return string[]
function M:get_trigger_characters()
    return require("defold.completions").get_trigger_characters()
end

---@param params   cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionList)
function M:complete(params, callback)
    local completions = require "defold.completions"
    local cursor = params.context.cursor
    local context = completions.get_context(params.context.bufnr, cursor.row, cursor.col)
    local items = context and completions.get_completions(context) or {}

    for _, item in ipairs(items) do
        item.icon = nil
    end

    callback { items = items, isIncomplete = true }
end

---@param cmp { register_source: fun(name: string, source: table): integer, get_config: fun(): cmp.ConfigSchema, setup: cmp.Setup }
function M.register(cmp)
    if registered then
        return
    end

    cmp.register_source("defold", M)

    ---@param bufnr integer
    local function activate(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or not require("defold.completions").is_buffer_supported(bufnr) then
            return
        end

        vim.api.nvim_buf_call(bufnr, function()
            local config = cmp.get_config()

            for _, source in ipairs(config.sources or {}) do
                if source.name == "defold" then
                    return
                end
            end

            config = vim.tbl_extend("force", {}, config)
            config.sources = vim.deepcopy(config.sources or {})

            table.insert(config.sources, { name = "defold" })

            cmp.setup.buffer(config)
        end)
    end

    local group = vim.api.nvim_create_augroup("DefoldNvimCmp", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
        group = group,
        ---@param event { buf: integer }
        callback = function(event)
            activate(event.buf)
        end,
    })

    registered = true

    activate(vim.api.nvim_get_current_buf())
end

return M
