local M = {}

---@class defold.icons.Icon
---@field icon  string
---@field color string
---@field name  string Highlight group name

---@type table<string, defold.icons.Icon>
local completion_icons = {}

---@param entries table<string, defold.config.Icon|false>
---@param colors  table<string, string>
---@return table<string, defold.icons.Icon>
local function resolve(entries, colors)
    local log = require "defold.logger"

    local result = {}

    for key, entry in pairs(entries) do
        if type(entry) == "table" then
            local color = colors[entry.color] or entry.color

            if not (entry.icon and entry.name and color and color:match "^#%x%x%x%x%x%x$") then
                log.error(string.format("icons: invalid icon config for %s: %s", key, vim.inspect(entry)))
            else
                result[key] = { icon = entry.icon, color = color, name = entry.name }
            end
        end
    end

    return result
end

---@param icons defold.icons.Icon[]
local function install_highlights(icons)
    local function set_highlights()
        for _, icon in ipairs(icons) do
            vim.api.nvim_set_hl(0, icon.name, { fg = icon.color, default = true })
        end
    end

    set_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("DefoldIcons", { clear = true }),
        callback = set_highlights,
    })
end

---@param icons table<string, defold.icons.Icon>
local function install_devicons(icons)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        devicons.set_icon(icons)
    end
end

---@param icons table<string, defold.icons.Icon>
---@return boolean installed
local function install_mini_icons(icons)
    local mini = rawget(_G, "MiniIcons")
    if mini == nil then
        return false
    end

    local config = vim.deepcopy(mini.config)

    for key, icon in pairs(icons) do
        -- keys including a "." (like game.project) are file names, everything else is treated as an extension
        local category = key:find(".", 1, true) and "file" or "extension"

        -- icons configured by the user in mini.icons take precedence
        if config[category][key] == nil then
            config[category][key] = { glyph = icon.icon, hl = icon.name }
        end
    end

    mini.setup(config)

    return true
end

---Icon and highlight group for a completion item, nil when disabled
---@param key? string Key in `icons.completions`
---@return string|nil icon
---@return string|nil hl
function M.completion_icon(key)
    local icon = completion_icons[key]

    if not icon then
        return nil, nil
    end

    return icon.icon, icon.name
end

function M.install()
    local icons_config = require("defold.config").state.icons

    if not icons_config or not icons_config.enable then
        return
    end

    local files = resolve(icons_config.files, icons_config.colors)
    completion_icons = resolve(icons_config.completions, icons_config.colors)

    local highlights = vim.tbl_values(completion_icons)

    install_devicons(files)

    if install_mini_icons(files) then
        vim.list_extend(highlights, vim.tbl_values(files))
    end

    install_highlights(highlights)
end

return M
