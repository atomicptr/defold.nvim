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
---@return defold.sidecar.CommandResult|nil
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

    ---@type boolean, defold.sidecar.CommandResult|nil
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

---@param severity defold.sidecar.IssueSeverity
---@return integer
local function issue_severity_value(severity)
    if severity == "information" then
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
---@param result defold.sidecar.CommandResult|nil
---@param min_severity? defold.sidecar.IssueSeverity
---@param open_quickfix? boolean
function M.open_quickfix_from_command_result(result, min_severity, open_quickfix)
    local config = require "defold.config"

    -- nothing to do
    if result == nil then
        return
    end

    -- Use configured defaults unless the caller provides an override.
    if open_quickfix == nil then
        open_quickfix = config.state.quickfix.open_list
    end

    local min_severity_value = issue_severity_value(min_severity or config.state.quickfix.min_severity)
    local items = {}

    ---@type table<defold.sidecar.IssueSeverity, string>
    local severity_map = {
        error = "E",
        warning = "W",
        info = "I",
    }

    for _, issue in ipairs(result.issues) do
        if issue_severity_value(issue.severity) >= min_severity_value then
            local filepath = issue.resource

            if filepath and filepath:sub(1, 1) == "/" then
                filepath = filepath:sub(2)
            end

            local lnum = 1
            local col = 1

            if issue.range then
                lnum = issue.range.start.line + 1
                col = issue.range.start.character + 1
            end

            table.insert(items, {
                filename = filepath,
                lnum = lnum,
                col = col,
                text = issue.message,
                type = severity_map[issue.severity] or "E",
            })
        end
    end

    if #items == 0 then
        return
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
---@param mode? "make"|"send"
function M.run_game(mode)
    local config = require "defold.config"

    mode = mode or config.state.game_runner.mode

    if mode == "make" then
        vim.cmd "make"
        return
    end

    local res = M.send_command "build"

    if config.state.quickfix.enable then
        M.open_quickfix_from_command_result(res)
    end
end

return M
