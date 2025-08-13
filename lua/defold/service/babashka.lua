local os = require "defold.service.os"
local log = require "defold.service.logger"

local bb_version = "1.12.207"
local bb_url = "https://github.com/babashka/babashka/releases/download/v%s/babashka-%s-%s-%s.%s"

local M = {}

M.custom_executable = nil

---@return string|nil
function M.local_bb_path()
    local meta_data_path = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "meta.json")
    local bb_path = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "bin", "bb")

    if os.is_windows() then
        bb_path = bb_path .. ".exe"
    end

    local meta_data = nil

    if os.file_exists(meta_data_path) then
        local content = vim.fn.readfile(meta_data_path)
        meta_data = vim.fn.json_decode(table.concat(content))
    end

    if meta_data and meta_data.bb_version == bb_version and os.file_exists(bb_path) then
        return bb_path
    end

    meta_data = meta_data or {}

    log.info(string.format("defold.nvim: Downloading babashka %s", bb_version))

    vim.fn.mkdir(vim.fs.dirname(bb_path), "p")

    local file_ending = "tar.gz"

    if os.is_windows() then
        file_ending = "zip"
    end

    local url = string.format(bb_url, bb_version, bb_version, os.name(), os.architecture(), file_ending)

    local download_path = bb_path .. "." .. file_ending

    os.download(url, download_path)

    if not os.file_exists(download_path) then
        log.error(string.format("Unable to download '%s' to '%s', something went wrong", url, download_path))
        return nil
    end

    if not os.is_windows() then
        os.exec(string.format("tar -xf '%s' -C '%s'", download_path, vim.fs.dirname(bb_path)))
        os.make_executable(bb_path)
    else
        os.exec(
            string.format(
                'powershell -Command "Expand-Archive -Path %s -DestinationPath %s"',
                download_path,
                vim.fs.dirname(bb_path)
            )
        )
    end

    if os.file_exists(download_path) then
        vim.fs.rm(download_path)
    end

    if not os.file_exists(bb_path) then
        log.error(
            string.format(
                "Could not install '%s' (downloaded from: '%s', unpacked from '%s'), something went wrong",
                bb_path,
                url,
                download_path
            )
        )
        return nil
    end

    meta_data.bb_version = bb_version
    local json = vim.fn.json_encode(meta_data)
    vim.fn.writefile({ json }, meta_data_path)

    return bb_path
end

---@return string|nil
function M.bb_path()
    if M.custom_executable then
        return M.custom_executable
    end

    if os.command_exists "bb" then
        return vim.fn.exepath "bb"
    end

    return M.local_bb_path()
end

function M.bb_edn_path()
    local plugin_root = os.plugin_root()
    return vim.fs.joinpath(plugin_root, "bb.edn")
end

function M.config_path()
    return vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "config.json")
end

---@param custom_executable string|nil
---@return boolean
function M.setup(custom_executable)
    M.custom_executable = custom_executable

    -- make sure bb is available
    M.bb_path()

    local res = M.run_task_json("setup", {})
    if res.status ~= 200 then
        log.error "Could not initialize babashka, check error logs"
        return false
    end

    return true
end

function M.run_task(task, args)
    log.debug(string.format("Run Babashka task: %s %s", task, vim.inspect(args)))

    local args_to_send = {}

    table.insert(args_to_send, M.config_path())

    for _, arg in ipairs(args or {}) do
        table.insert(args_to_send, arg)
    end

    local params = table.concat(args_to_send, " ")
    local cmd = string.format("%s --config '%s' run %s %s", M.bb_path(), M.bb_edn_path(), task, params)
    return os.exec(cmd)
end

function M.run_task_json(task, args)
    local res = M.run_task(task, args)
    return vim.json.decode(res)
end

return M
