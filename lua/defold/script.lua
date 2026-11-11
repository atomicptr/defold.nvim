local M = {}

---@enum defold.script.Kind
M.kinds = {
    MODULE = "module",
    SCRIPT = "script",
    GUI_SCRIPT = "gui_script",
    RENDER_SCRIPT = "render_script",
    EDITOR_SCRIPT = "editor_script",
}

local extensions = {
    lua = M.kinds.MODULE,
    script = M.kinds.SCRIPT,
    gui_script = M.kinds.GUI_SCRIPT,
    render_script = M.kinds.RENDER_SCRIPT,
    editor_script = M.kinds.EDITOR_SCRIPT,
}

---@param bufnr? integer
---@return defold.script.Kind?
function M.detect_kind_from_buffer(bufnr)
    return extensions[vim.fs.ext(vim.api.nvim_buf_get_name(bufnr or 0))]
end

return M
