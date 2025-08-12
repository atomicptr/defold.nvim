local editor = require "defold.editor"
local os = require "defold.service.os"
local project = require "defold.project"
local babashka = require "defold.service.babashka"
local log = require "defold.service.logger"

local mobdap_version = "0.1.4"
local mobdap_url = "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-%s-%s.%s"

local M = {}

M.custom_executable = nil
M.custom_arguments = nil

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
        return mobdap_path
    end

    meta_data = meta_data or {}

    log.info(string.format("Downloading mobdap %s", mobdap_version))

    vim.fn.mkdir(vim.fs.dirname(mobdap_path), "p")

    local file_ending = "tar.gz"

    if os.is_windows() then
        file_ending = "zip"
    end

    local architecture = os.architecture()

    if architecture == "aarch64" then
        architecture = "arm64"
    end

    local url = string.format(mobdap_url, mobdap_version, os.name(), architecture, file_ending)

    local download_path = mobdap_path .. "." .. file_ending

    os.download(url, download_path)

    if not os.file_exists(download_path) then
        log.error(string.format("Unable to download '%s' to '%s', something went wrong", url, download_path))
        return nil
    end

    if not os.is_windows() then
        os.exec(string.format("tar -xf '%s' --strip-components 2 -C '%s'", download_path, vim.fs.dirname(mobdap_path)))
        os.move(string.format("%s-%s", mobdap_path, mobdap_version), mobdap_path)
        os.make_executable(mobdap_path)
    else
        os.exec(
            string.format(
                'powershell -Command "Expand-Archive -Path %s -DestinationPath %s"',
                download_path,
                vim.fs.dirname(mobdap_path)
            )
        )
        os.move(
            string.format(
                "%s-%s.exe",
                vim.fs.joinpath(vim.fn.stdpath "data", "defold.nvim", "bin", "mobdap"),
                mobdap_version
            ),
            mobdap_path
        )
    end

    if os.file_exists(download_path) then
        vim.fs.rm(download_path)
    end

    if not os.file_exists(mobdap_path) then
        log.error(
            string.format(
                "Could not install '%s' (downloaded from: '%s', unpacked from '%s'), something went wrong",
                mobdap_path,
                url,
                download_path
            )
        )
        return nil
    end

    meta_data.mobdap_version = mobdap_version
    local json = vim.fn.json_encode(meta_data)
    vim.fn.writefile({ json }, meta_data_path)

    return mobdap_path
end

---@return string|nil
function M.mobdap_path()
    if M.custom_executable then
        return M.custom_executable
    end

    if os.command_exists "mobdap" then
        return vim.fn.exepath "mobdap"
    end

    return local_mobdap_path()
end

---@param custom_executable string|nil
---@param custom_arguments table<string>|nil
function M.setup(custom_executable, custom_arguments)
    M.custom_executable = custom_executable
    M.custom_arguments = custom_arguments

    M.mobdap_path()
end

function M.register_nvim_dap()
    local ok, dap = pcall(require, "dap")

    if not ok then
        log.error "Debugger enabled but could not find plugin: mfussenegger/nvim-dap"
        return
    end

    dap.adapters.defold_nvim = {
        id = "defold_nvim",
        type = "executable",
        command = M.mobdap_path(),
        args = M.custom_arguments,
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
        log.debug "debugger: connected"

        editor.send_command "build"
    end

    dap.listeners.after.event_stopped.defold_nvim_switch_focus_on_stop = function(_, _)
        log.debug "debugger: event stopped"

        local rootdir = vim.fs.root(0, { "game.project", ".git" })
        babashka.run_task_json("focus-neovim", { rootdir })
    end

    dap.listeners.after.continue.defold_nvim_switch_focus_on_continue = function(_, _)
        log.debug "debugger: continued"

        local rootdir = vim.fs.root(0, { "game.project", ".git" })
        babashka.run_task_json("focus-game", { rootdir })
    end
end

return M
