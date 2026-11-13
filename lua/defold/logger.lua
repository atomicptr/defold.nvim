local M = {}

M.notify_level = vim.log.levels.INFO

local function level2string(level)
    if level == vim.log.levels.DEBUG then
        return "DEBUG"
    elseif level == vim.log.levels.INFO then
        return "INFO"
    elseif level == vim.log.levels.WARN then
        return "WARN"
    elseif level == vim.log.levels.ERROR then
        return "ERROR"
    end

    return "???"
end

local function log(level, message)
    -- if important enough, log to notification system
    if level >= M.notify_level then
        vim.notify(string.format("defold.nvim: %s", message), level)
    end

    -- Persistence is best-effort and must never mask the original error.
    local file
    pcall(function()
        local osm = require "defold.os"
        local logdir = vim.fs.joinpath(osm.cache_dir(), "logs")
        vim.fn.mkdir(logdir, "p")

        local log_file = vim.fs.joinpath(logdir, "plugin.log")
        local timestamp = os.date "%Y-%m-%d %H:%M:%S"
        local log_message = string.format("[%s] %s: %s\n", level2string(level), timestamp, message)

        file = io.open(log_file, "a")
        if file then
            file:write(log_message)
        end
    end)

    if file then
        pcall(function()
            file:close()
        end)
    end
end

function M.debug(message)
    log(vim.log.levels.DEBUG, message)
end

function M.info(message)
    log(vim.log.levels.INFO, message)
end

function M.warn(message)
    log(vim.log.levels.WARN, message)
end

function M.error(message)
    log(vim.log.levels.ERROR, message)
end

function M.fatal(message)
    M.error(message)
    error(message, 2)
end

return M
