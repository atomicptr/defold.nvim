local M = {}

---List all available Defold commands
---@return table|nil
function M.list_commands()
    local babashka = require "defold.service.babashka"
    local log = require "defold.service.logger"

    local res = babashka.run_task_json "list-commands"

    if not res then
        log.error "Could not fetch commands from Defold, maybe the editor isn't running?"
        return nil
    end

    if res.error then
        log.error(string.format("Could not fetch commands from Defold, because: %s", res.error))
        return nil
    end

    return res
end

---Sends a command to the Defold editor
---@param command string
---@param dont_report_error boolean|nil
function M.send_command(command, dont_report_error)
    local babashka = require "defold.service.babashka"
    local log = require "defold.service.logger"

    local res = babashka.run_task_json("send-command", { command })

    if res.status == 202 then
        return
    end

    if dont_report_error or false then
        return
    end

    log.error(string.format("Could execute comannd '%s', because: %s", command, res.error or "Something went wrong!"))
end

return M
