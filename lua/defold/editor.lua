local babashka = require "defold.service.babashka"

local M = {}

---List all available Defold commands
---@return table
function M.list_commands()
    local res = babashka.run_task_json "list-commands"

    if not res then
        vim.notify("Could not fetch commands from Defold, maybe the editor isn't running?", vim.log.levels.ERROR)
        return {}
    end

    if res.error then
        vim.notify(string.format("Could not fetch commands from Defold, because: %s", res.error), vim.log.levels.ERROR)
        return {}
    end

    return res
end

---Sends a command to the Defold editor
---@param command string
function M.send_command(command)
    local res = babashka.run_task_json("send-command", { command })

    if res.status == 202 then
        return
    end

    vim.notify(string.format("Could execute comannd '%s', because: %s", command, res.error), vim.log.levels.ERROR)
end

return M
