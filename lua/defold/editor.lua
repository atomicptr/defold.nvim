local M = {}

---List all available Defold commands
---@return string[]
function M.list_commands()
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local port = project.editor_port()

    if not port then
        log.error "Could not find Defold editor, is it running?"
        return {}
    end

    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.list_commands, port)

    if not ok then
        log.error(string.format("Could not fetch commands from Defold, because: %s", res))
        return {}
    end

    return res
end

---Sends a command to the Defold editor
---@param command string
---@param dont_report_error boolean|nil
---@return CommandResult|nil
function M.send_command(command, dont_report_error)
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local port = project.editor_port()

    if not port then
        if dont_report_error then
            return nil
        end

        log.error "Could not find Defold editor, is it running?"
        return nil
    end

    local sidecar = require "defold.sidecar"

    ---@type boolean, CommandResult|nil
    local ok, res = pcall(sidecar.send_command, port, command)
    if ok then
        return res
    end

    log.debug(string.format("Command '%s' Result: %s", command, vim.inspect(res)))

    if dont_report_error then
        return
    end

    log.error(
        string.format(
            "Could not execute comannd '%s', because: %s",
            command,
            string.format("%d: Something went wrong!", (res and res.status) or 0)
        )
    )
end

---@param severity IssueSeverity
---@return integer
local function issue_severity_value(severity)
    if severity == "info" then
        return 1
    elseif severity == "warning" then
        return 2
    elseif severity == "error" then
        return 3
    end

    return 3 -- unknown will also be treated as error
end

---Opens the Neovim Quickfix list from a command result
---If there are no issues this is a no-op
---@param result CommandResult|nil
---@param min_severity? IssueSeverity
---@param open_quickfix? boolean
function M.open_quickfix_from_command_result(result, min_severity, open_quickfix)
    -- nothing to do
    if result == nil then
        return
    end

    -- default to true
    if open_quickfix == nil then
        open_quickfix = true
    end

    ---@type Issue[]
    local issues = {}

    local min_severity_value = issue_severity_value(min_severity or "error")

    for _, issue in ipairs(result.issues) do
        if issue_severity_value(issue.severity) >= min_severity_value then
            table.insert(issues, issue)
        end
    end

    -- nothing to do
    if #issues == 0 then
        return
    end

    local items = {}

    ---@type table<IssueSeverity, string>
    local severity_map = {
        error = "E",
        warning = "W",
        info = "I",
    }

    for _, issue in ipairs(issues) do
        local filepath = issue.resource:sub(1, 1) == "/" and issue.resource:sub(2) or issue.resource

        table.insert(items, {
            filename = filepath,
            lnum = issue.range.start.line + 1,
            col = issue.range.start.character + 1,
            text = issue.message,
            type = severity_map[issue.severity] or "E",
        })
    end

    vim.fn.setqflist({}, "r", {
        title = "Defold Errors",
        items = items,
    })

    if open_quickfix then
        vim.cmd "copen"
    end
end

---Runs the game through Defold
---@param config DefoldNvimConfig
---@param mode? "make"|"build"|nil
function M.run_game(config, mode)
    mode = mode or config.game_runner.mode

    if mode == "make" then
        vim.cmd "make"
        return
    end

    local res = M.send_command "build"

    if config.quickfix.enable then
        M.open_quickfix_from_command_result(res, config.quickfix.min_severity, config.quickfix.open_list)
    end
end

return M
