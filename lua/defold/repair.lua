local M = {}

local function marker_path()
    return vim.fs.joinpath(vim.fn.stdpath "data", "repair-defold.nvim")
end

function M.schedule()
    local log = require "defold.service.logger"
    local os = require "defold.service.os"
    local sidecar = require "defold.sidecar"

    local paths = { os.data_dir(), os.cache_dir(), vim.fs.joinpath(vim.uv.os_tmpdir(), "defold.nvim") }

    if sidecar.data_dir then
        table.insert(paths, sidecar.data_dir())
    end

    if sidecar.cache_dir then
        table.insert(paths, sidecar.cache_dir())
    end

    if vim.fn.writefile(paths, marker_path()) ~= 0 then
        log.fatal "Could not schedule defold.nvim repair"
    end

    vim.notify("defold.nvim: Repair scheduled, please restart ALL Neovim instances to continue", vim.log.levels.WARN)
end

function M.apply_pending()
    local log = require "defold.service.logger"
    local os = require "defold.service.os"

    if not os.file_exists(marker_path()) then
        return
    end

    -- Windows locks loaded DLLs, so for a cleanup we must be on a fresh startup
    if package.loaded.defold_nvim_sidecar then
        log.fatal "Restart Neovim to repair Defold.nvim"
    end

    for _, path in ipairs(vim.fn.readfile(marker_path())) do
        if os.file_exists(path) and vim.fn.delete(path, "rf") ~= 0 then
            log.fatal(string.format "Could not remove %s, close Neovim and try again")
        end
    end

    if vim.fn.delete(marker_path()) ~= 0 then
        log.fatal "Could not clear Defold repair marker"
    end

    return true
end

return M
