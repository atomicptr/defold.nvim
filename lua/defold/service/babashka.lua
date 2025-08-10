local os = require "defold.service.os"

local bb_version = "1.12.207"
local bb_url = "https://github.com/babashka/babashka/releases/download/v%s/babashka-%s-%s-%s.%s"

local M = {}

M.custom_executable = nil

---@return string|nil
local function local_bb()
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

    vim.notify(string.format("defold.nvim: Downloading babashka %s", bb_version))

    vim.fn.mkdir(vim.fs.dirname(bb_path), "p")

    local file_ending = "tar.gz"

    if os.is_windows() then
        file_ending = "zip"
    end

    local url = string.format(bb_url, bb_version, bb_version, os.name(), os.architecture(), file_ending)

    local download_path = bb_path .. "." .. file_ending

    os.download(url, download_path)

    if not os.file_exists(download_path) then
        vim.notify(
            string.format("defold.nvim: Unable to download '%s' to '%s', something went wrong", url, download_path),
            vim.log.levels.ERROR
        )
        return nil
    end

    if not os.is_windows() then
        vim.fn.system(string.format("tar -xf '%s' -C '%s'", download_path, vim.fs.dirname(bb_path)))
        vim.fn.system(string.format("chmod +x '%s'", bb_path))
    else
        vim.fn.system(
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
        vim.notify(
            string.format(
                "defold.nvim: Could not install '%s' (downloaded from: '%s', unpacked from '%s'), something went wrong",
                bb_path,
                url,
                download_path
            ),
            vim.log.levels.ERROR
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

    return local_bb()
end

function M.bb_edn_path()
    local plugin_root = os.plugin_root()
    return vim.fs.joinpath(plugin_root, "bb.edn")
end

---@class BabashkaConfig
---@field set_editor boolean
---@field custom_executable string|nil

---@param opts BabashkaConfig
---@return string
function M.setup(opts)
    M.custom_executable = opts.custom_executable

    -- make sure bb is available
    local bb = M.bb_path()

    if opts.set_editor then
        M.run_task_json("set-default-editor", { bb })
    end

    return bb
end

function M.run_task(task, args)
    local params = table.concat(args or {}, " ")
    local cmd = string.format("%s --config '%s' run %s %s", M.bb_path(), M.bb_edn_path(), task, params)
    return vim.fn.system(cmd)
end

function M.run_task_json(task, args)
    local res = M.run_task(task, args)
    return vim.json.decode(res)
end

return M
