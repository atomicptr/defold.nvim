local M = {}

---List all available Defold commands
---@return table|nil
function M.list_commands()
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local port = project.editor_port()

    if not port then
        log.error "Could not find Defold editor, is it running?"
        return
    end

    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.list_commands, port)

    if not ok then
        log.error(string.format("Could not fetch commands from Defold, because: %s", res))
        return nil
    end

    ---@cast res table<string, string>
    return res
end

---Sends a command to the Defold editor
---@param command string
---@param dont_report_error boolean|nil
function M.send_command(command, dont_report_error)
    local log = require "defold.service.logger"
    local project = require "defold.project"

    local port = project.editor_port()

    if not port then
        if dont_report_error then
            return
        end

        log.error "Could not find Defold editor, is it running?"
        return
    end

    local sidecar = require "defold.sidecar"

    local _, err = pcall(sidecar.send_command, port, command)

    if not err then
        return
    end

    if dont_report_error then
        return
    end

    log.error(string.format("Could not execute comannd '%s', because: %s", command, err or "Something went wrong!"))
end

return M
