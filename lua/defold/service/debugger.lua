local editor = require "defold.editor"
local os = require "defold.service.os"
local project = require "defold.project"

local mobdap_version = "0.1.2"
local mobdap_url = "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-%s-%s.%s"

local M = {}

local function local_mobdap_path()
    local meta_data_path = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "meta.json")
    local mobdap_path = vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "bin", "mobdap")

    if os.is_windows() then
        mobdap_path = mobdap_path .. ".exe"
    end

    local meta_data = nil

    if os.file_exists(meta_data_path) then
        local content = vim.fn.readfile(meta_data_path)
        meta_data = vim.fn.json_decode(table.concat(content))
    end

    if meta_data and meta_data.mobdap_version == mobdap_version and os.file_exists(mobdap_path) then
        return "/home/christopher/dev/clojure/mobdap/target/native-image/mobdap-0.1.1"
        -- return mobdap_path
    end

    meta_data = meta_data or {}

    vim.notify(string.format("defold.nvim: Downloading mobdap %s", mobdap_version))

    vim.fn.mkdir(vim.fs.dirname(mobdap_path), "p")

    local file_ending = "tar.gz"

    if os.is_windows() then
        file_ending = "zip"
    end

    local architecture = os.architecture()

    if architecture == "amd64" then
        architecture = "x86_64"
    end

    local url = string.format(mobdap_url, mobdap_version, os.name(), architecture, file_ending)

    local download_path = mobdap_path .. "." .. file_ending

    os.download(url, download_path)
    assert(os.file_exists(download_path))

    if not os.is_windows() then
        vim.fn.system(
            string.format("tar -xf '%s' --strip-components 2 -C '%s'", download_path, vim.fs.dirname(mobdap_path))
        )
        vim.fn.system(string.format("mv '%s-v%s' %s", mobdap_path, mobdap_version, mobdap_path))
        vim.fn.system(string.format("chmod +x '%s'", mobdap_path))
    else
        vim.fn.system(
            string.format(
                'powershell -Command "Expand-Archive -Path %s -DestinationPath %s"',
                download_path,
                vim.fs.dirname(mobdap_path)
            )
        )
    end

    if os.file_exists(download_path) then
        vim.fs.rm(download_path)
    end

    meta_data.mobdap_version = mobdap_version
    local json = vim.fn.json_encode(meta_data)
    vim.fn.writefile({ json }, meta_data_path)

    return mobdap_path
end

function M.setup()
    local_mobdap_path()
end

function M.register_nvim_dap()
    local dap = require "dap"

    dap.adapters.defold_nvim = {
        id = "defold_nvim",
        type = "executable",
        command = local_mobdap_path(),
        args = { "--debug" },
    }

    dap.configurations.lua = {
        {
            name = "defold.nvim: Debugger",
            type = "defold_nvim",
            request = "launch",

            rootdir = function()
                return vim.fs.root(0, { "game.project", ".git" })
            end,

            sourcedirs = function()
                local libs = { project.defold_api_path() }

                for _, lib in ipairs(project.dependency_api_paths()) do
                    table.insert(libs, lib)
                end

                return libs
            end,

            -- TODO: make this configurable or better read it from the collection if possible
            port = 18172,
        },
    }

    dap.listeners.after.event_mobdap_waiting_for_connection.defold_nvim_start_game = function(_, _)
        editor.send_command "build"
    end
end

return M
