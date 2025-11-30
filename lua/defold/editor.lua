local M = {}

---List all available Defold commands
---@param port integer|nil
---@return table|nil
function M.list_commands(port)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local res = sidecar.list_commands(port)

    if res.error then
        log.error(string.format("Could not fetch commands from Defold, because: %s", res.error))
        return nil
    end

    return res
end

---Sends a command to the Defold editor
---@param port integer|nil
---@param command string
---@param dont_report_error boolean|nil
function M.send_command(port, command, dont_report_error)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local res = sidecar.send_command(port, command)

    if not res.error then
        return
    end

    if dont_report_error then
        return
    end

    log.error(string.format("Could execute comannd '%s', because: %s", command, res.error or "Something went wrong!"))
end

return M
