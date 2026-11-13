local M = {}

---@class defold.completions.Item: lsp.CompletionItem
---@field icon? string Optional presentation metadata

---Whetever a buffer is supported for defold.nvim completions
---@param bufnr? integer
---@return boolean
function M.is_buffer_supported(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if vim.bo[bufnr].filetype ~= "lua" then
        return false
    end

    local script = require "defold.script"
    local kind = script.detect_kind_from_buffer(bufnr)

    return (kind == script.kinds.SCRIPT or kind == script.kinds.GUI_SCRIPT)
        and require("defold.project").is_buffer_in_project(bufnr)
end

---Find the open quoted string, or fall back to the current completion token
---@param line string
---@param col  integer Insertion position (UTF-8 bytes)
---@return integer start_col Replacement start
---@return boolean in_string
function M.get_start_col(line, col)
    local prefix = line:sub(1, col - 1)
    local quote, start_col
    local i = 1

    while i <= #prefix do
        local char = prefix:sub(i, i)

        if quote then
            if char == "\\" then
                i = i + 1
            elseif char == quote then
                quote, start_col = nil, nil
            end
        elseif prefix:sub(i, i + 1) == "--" then
            break
        elseif char == '"' or char == "'" then
            quote, start_col = char, i + 1
        end

        i = i + 1
    end

    if start_col then
        return start_col, true
    end

    local token = prefix:match "[^%s\"'()%[%],=]+$" or ""
    return col - #token, false
end

---@class defold.completions.Context
---@field bufnr     integer
---@field row       integer
---@field col       integer Insertion position (UTF-8 bytes)
---@field start_col integer Replacement start (UTF-8 bytes)
---@field line      string
---@field in_string boolean

---@param bufnr? integer
---@param row?   integer
---@param col?   integer Insertion position (UTF-8 bytes)
---@return defold.completions.Context?
function M.get_context(bufnr, row, col)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if not M.is_buffer_supported(bufnr) then
        return nil
    end

    if row == nil or col == nil then
        local cursor = vim.api.nvim_win_get_cursor(0)
        row, col = cursor[1], cursor[2] + 1
    end

    if row < 1 or col < 1 then
        return nil
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

    if not line or col > #line + 1 then
        return nil
    end

    local start_col, in_string = M.get_start_col(line, col)
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row - 1, col - 1 } })

    if ok and node then
        while node and node:type() ~= "string" do
            if node:type() == "comment" then
                return nil
            end

            node = node:parent()
        end

        if node then
            in_string = true
            local start_row, string_col = node:range()
            start_row, string_col = start_row + 1, string_col + 1

            if start_row == row then
                local opening = line:sub(string_col):match "^%[=*%["
                start_col = string_col + (opening and #opening or 1)
            else
                start_col = 1
            end
        elseif not in_string then
            return nil
        end
    end

    return {
        bufnr = bufnr,
        row = row,
        col = col,
        start_col = math.min(start_col, col),
        line = line,
        in_string = in_string,
    }
end

---@return string[]
function M.get_trigger_characters()
    return { '"', "'", "/", ":", "#" }
end

---@param entry                 defold.sidecar.PathEntry
---@param omit_collection_name? boolean
---@return defold.completions.Item
local function completion_item_from_entry(entry, omit_collection_name)
    local kinds = vim.lsp.protocol.CompletionItemKind

    local collection_name = not omit_collection_name and entry.collection_name or nil
    local path = ""

    if entry.game_object_id and collection_name then
        path = string.format("%s:", collection_name)
    end

    if entry.game_object_id then
        path = string.format("%s/%s", path, entry.game_object_id)
    end

    if entry.component_id then
        path = string.format("%s#%s", path, entry.component_id)
    end

    local label = path

    if entry.from_location then
        label = string.format("%s (%s)", label, entry.from_location)
    end

    ---@type defold.completions.Item
    return {
        label = label,
        insertText = path,
        filterText = path,
        kind = (entry.same_game_object and kinds.Property)
            or (entry.is_component and kinds.Variable)
            -- game object
            or kinds.Struct,
        icon = entry.is_component and "󰒓" or "",
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        sortText = string.format(
            "%s|%s:/%s#%s",
            entry.same_game_object and "a" or "b",
            collection_name or "a",
            entry.game_object_id or "a",
            entry.component_id or "a"
        ),
    }
end

---@param filename string
---@param root     string
---@return defold.completions.Item[]
local function get_script_completions(filename, root)
    local sidecar = require "defold.sidecar"
    local log = require "defold.logger"

    local path_entries_ok, path_entries = pcall(sidecar.fetch_defold_paths_for, root, filename)
    if not path_entries_ok then
        log.error(string.format("could not fetch defold paths: %s", path_entries))
        return {}
    end

    ---@type defold.completions.Item[]
    local items = {}

    ---@cast path_entries defold.sidecar.PathEntry[]

    for _, entry in ipairs(path_entries) do
        local item = completion_item_from_entry(entry)

        table.insert(items, item)

        -- if item has a collection name, add also the version without it
        if entry.collection_name then
            table.insert(items, completion_item_from_entry(entry, true))
        end
    end

    return items
end

---@param filename string
---@param root     string
---@return defold.completions.Item[]
local function get_gui_completions(filename, root)
    local kinds = vim.lsp.protocol.CompletionItemKind
    local sidecar = require "defold.sidecar"
    local log = require "defold.logger"

    local nodes_ok, nodes = pcall(sidecar.fetch_gui_nodes_for, root, filename)
    if not nodes_ok then
        log.error(string.format("could not fetch GUI nodes: %s", nodes))
        return {}
    end

    ---@type defold.completions.Item[]
    local items = {}

    ---@cast nodes defold.sidecar.GuiNodeEntry[]
    for _, node in ipairs(nodes) do
        table.insert(items, {
            label = node.id .. " (" .. node.from_location .. ")",
            insertText = node.id,
            filterText = node.id,
            kind = kinds.Property,
            icon = "",
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        })
    end

    return items
end

---@param root string
---@return defold.completions.Item[]
local function get_input_binding_completions(root)
    local kinds = vim.lsp.protocol.CompletionItemKind

    local sidecar = require "defold.sidecar"
    local log = require "defold.logger"

    local bindings_ok, bindings = pcall(sidecar.fetch_input_bindings, root)
    if not bindings_ok then
        log.error(string.format("could not fetch input bindings: %s", bindings))
        return {}
    end

    ---@type defold.completions.Item[]
    local items = {}

    for _, binding in ipairs(bindings) do
        table.insert(items, {
            label = binding,
            kind = kinds.Property,
            icon = "󱇰",
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        })
    end

    return items
end

---@param context defold.completions.Context
---@return defold.completions.Item[]
function M.get_completions(context)
    if not M.is_buffer_supported(context.bufnr) then
        return {}
    end

    local filename = vim.api.nvim_buf_get_name(context.bufnr)
    local script = require "defold.script"
    local kind = script.detect_kind_from_buffer(context.bufnr)
    local root = require("defold.project").project_root()

    if not root then
        return {}
    end

    local items = kind == script.kinds.SCRIPT and get_script_completions(filename, root)
        or get_gui_completions(filename, root)
    vim.list_extend(items, get_input_binding_completions(root))

    for _, item in ipairs(items) do
        item.textEdit = {
            newText = item.insertText or item.label,
            range = {
                start = { line = context.row - 1, character = context.start_col - 1 },
                ["end"] = { line = context.row - 1, character = context.col - 1 },
            },
        }
    end

    return items
end

---Register automatic integrations, only keep the first matching one (unless disabled)
function M.register()
    local opts = require("defold.config").state.completions

    if not opts.enable then
        return
    end

    if opts.blink_cmp.enable then
        local ok, blink = pcall(require, "blink.cmp")

        if ok then
            require("defold.cmp.blink-cmp").register(blink)
            return
        end
    end

    if opts.nvim_cmp.enable then
        local ok, cmp = pcall(require, "cmp")

        if ok then
            require("defold.cmp.nvim-cmp").register(cmp)
            return
        end
    end

    if opts.native.enable then
        require("defold.cmp.native").register()
    end
end

return M
