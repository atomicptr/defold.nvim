local M = {}

---@param icon string
---@param name string
---@return table
local function blue_icon(icon, name)
    return {
        icon = icon,
        color = "#4CB1FF",
        cterm_color = "63",
        name = name,
    }
end

---@param icon string
---@param name string
---@return table
local function yellow_icon(icon, name)
    return {
        icon = icon,
        color = "#E6B711",
        cterm_color = "221",
        name = name,
    }
end

---@param icon string
---@param name string
---@return table
local function green_icon(icon, name)
    return {
        icon = icon,
        color = "#2FA909",
        cterm_color = "70",
        name = name,
    }
end

function M.install()
    local ok, icons = pcall(require, "nvim-web-devicons")
    if not ok then
        return
    end

    icons.set_icon {
        ["game.project"] = green_icon("󰐱", "DefoldGameProject"),
        input_binding = green_icon("󱇰", "DefoldInputBinding"),

        -- scene objects
        go = blue_icon("", "DefoldGameObject"),
        collection = blue_icon("", "DefoldCollection"),

        -- script types
        script = yellow_icon("󰒓", "DefoldScript"),
        render_script = yellow_icon("󰒓", "DefoldRenderScript"),
        gui_script = yellow_icon("󰒓", "DefoldGuiScript"),

        -- shaders
        vp = yellow_icon("", "DefoldVertexProgram"),
        fp = yellow_icon("", "DefoldFragmentProgram"),
        material = green_icon("", "DefoldMaterial"),

        -- other
        atlas = green_icon("", "DefoldAtlas"),
        sprite = blue_icon("", "DefoldSprite"),
        tilemap = blue_icon("", "DefoldTilemap"),
        tilesource = green_icon("󱡔", "DefoldTilesource"),
        particlefx = blue_icon("", "DefoldParticleFX"),
        sound = green_icon("", "DefoldSound"),
        font = yellow_icon("", "DefoldFont"),
        gui = blue_icon("", "DefoldGui"),
    }
end

return M
