local M = {}

---@type {ready: boolean, downloading: boolean, callbacks: table<fun(), boolean>}
local download_state = {
    ready = false,
    downloading = false,
    callbacks = {},
}

---Whether all native modules are ready for this session.
---@return boolean
function M.is_ready()
    return download_state.ready
end

---@param callback? fun() Callback called after rust modules are ready
function M.download(callback)
    local log = require "defold.service.logger"

    if callback then
        download_state.callbacks[callback] = true
    end

    if not download_state.downloading then
        local was_repaired = false

        download_state.downloading = true
        download_state.ready = false

        ---@param err? string
        local function finish(err)
            download_state.downloading = false
            local callbacks = download_state.callbacks
            download_state.callbacks = {}

            if err then
                log.error("Native installation failed: " .. err)
                return
            end

            download_state.ready = true

            if was_repaired then
                log.info "Repair successful"
            end

            for cb in pairs(callbacks) do
                local ok, callback_err = pcall(cb)
                if not ok then
                    log.error(tostring(callback_err))
                end
            end
        end

        local ok, err = pcall(function()
            was_repaired = require("defold.repair").apply_pending() or false
            require("defold.sidecar").ensure(finish)
        end)

        if not ok then
            finish(tostring(err))
        end
    end

    if not callback and #vim.api.nvim_list_uis() == 0 then
        assert(
            vim.wait(120000, function()
                return not download_state.downloading
            end),
            "Rust binaries installation timed out"
        )
        assert(download_state.ready, "Rust binaries installation failed")
    end
end

return M
