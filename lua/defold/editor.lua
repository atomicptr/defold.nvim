local M = {}

---List all available Defold commands
---@return string[]
function M.list_commands()
    local log = require "defold.logger"
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
    local log = require "defold.logger"
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

    log.error(string.format("Could not execute command '%s', because: %s", command, tostring(res)))
end

local severity_map = {
    information = { rank = 1, type = "I" },
    warning = { rank = 2, type = "W" },
    error = { rank = 3, type = "E" },
}

---@param severity? defold.sidecar.IssueSeverity
---@return { rank: integer, type: string }
local function issue_severity(severity)
    return severity_map[severity or "error"] or severity_map.error
end

---Opens the Neovim Quickfix list from a command result
---If there are no issues this is a no-op
---@param result        defold.sidecar.CommandResult|nil
---@param min_severity?  defold.sidecar.IssueSeverity
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

    local project = require "defold.project"
    local root = project.project_root()
    local min_severity_value = issue_severity(min_severity or config.state.quickfix.min_severity).rank
    local items = {}

    for _, issue in ipairs(result.issues) do
        local severity = issue_severity(issue.severity)
        if severity.rank >= min_severity_value then
            local filepath = issue.resource

            if filepath then
                filepath = filepath:gsub("^/+", "")
                if root then
                    filepath = vim.fs.joinpath(root, filepath)
                end
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
                type = severity.type,
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
