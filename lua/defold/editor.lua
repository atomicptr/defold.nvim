local os = require "defold.service.os"
local http = require "defold.service.http"

local M = {}

M.port = nil

---Extract the port from lsof/ss output
---@return number|nil
local function extract_port(output)
    local parts = vim.fn.split(output, " ")

    local pattern = ":(%d+)"

    for _, part in ipairs(parts) do
        local _, _, port = part:find(pattern)

        if port then
            return tonumber(port)
        end
    end
end

---Find the port Defold is currently running at
---@return number|nil
local function find_port()
    local found_command = false

    if os.command_exists "lsof" then
        found_command = true

        local output = vim.fn.system "lsof -nP -iTCP -sTCP:LISTEN |grep java"
        local port = extract_port(output)
        if port then
            return port
        end
    end

    if os.command_exists "ss" then
        found_command = true

        local output = vim.fn.system "ss -tplH4 |grep java"
        local port = extract_port(output)
        if port then
            return port
        end
    end

    if not found_command then
        vim.notify(
            "Could not find 'lsof' or 'ss' and therefore can't determine which port Defold is running at, install one of these",
            vim.log.levels.ERROR
        )
        return nil
    end

    vim.notify("Could not determine Defold port, make sure it's running", vim.log.levels.WARN)
    return nil
end

local function command_url(port, command)
    return string.format("http://127.0.0.1:%s/command/%s", port, string.lower(command))
end

---List all available Defold commands
---@return table
function M.list_commands()
    if not M.port then
        M.port = find_port()
    end

    if not M.port then
        return {}
    end

    local url = command_url(M.port, "")
    local res = http.get(url)

    if res == "" then
        vim.notify(
            string.format("Could not fetch commands from Defold at '%s', maybe the editor isn't running?", url),
            vim.log.levels.ERROR
        )
        return {}
    end

    return vim.json.decode(res)
end

---Sends a command to the Defold editor
---@param command string
function M.send_command(command)
    local failed = false

    while true do
        if not M.port then
            M.port = find_port()
        end

        if not M.port then
            return
        end

        local url = command_url(M.port, command)
        local res = http.post(url)

        -- command was accepted
        if string.find(res, "202") then
            return
        elseif not failed then
            -- command failed, lets try again with new port
            M.port = nil
            failed = true
        else
            -- command failed twice lets show an error message
            vim.notify(
                string.format("Sending command '%s' via '%s' failed: %s", command, url, res),
                vim.log.levels.ERROR
            )
            return
        end
    end
end

return M
