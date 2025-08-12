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
    local log_file = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "plugin.log")
    local timestamp = os.date "%Y-%m-%d %H:%M:%S"
    local level_str = level2string(level)

    local log_message = string.format("[%s] %s: %s\n", level_str, timestamp, message)

    -- if important enough, log to notification system
    if level >= M.notify_level then
        vim.notify(string.format("defold.nvim: %s", message), level)
    end

    -- log message to log file
    local file = io.open(log_file, "a")
    if file then
        file:write(log_message)
        file:close()
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

return M
