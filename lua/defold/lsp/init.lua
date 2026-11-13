local M = {}

local servers = {
    require "defold.lsp.lua_ls",
}

---@param client vim.lsp.Client
local function server_for(client)
    for _, server in ipairs(servers) do
        if server.matches(client) then
            return server
        end
    end
end

---@param client vim.lsp.Client
---@param server table
local function configure(client, server)
    client.settings = vim.tbl_deep_extend("force", client.settings or {}, server.settings())

    client:notify("workspace/didChangeConfiguration", {
        settings = client.settings,
    })
end

function M.update()
    local project = require "defold.project"

    for _, client in ipairs(vim.lsp.get_clients()) do
        local server = server_for(client)

        local in_project = vim.iter(vim.tbl_keys(client.attached_buffers)):any(function(bufnr)
            return project.is_buffer_in_project(bufnr)
        end)

        if server and in_project then
            configure(client, server)
        end
    end
end

---@param on_attach fun()
function M.setup(on_attach)
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
            local project = require "defold.project"

            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            if not client or not project.is_buffer_in_project(ev.buf) then
                return
            end

            local server = server_for(client)
            if not server then
                return
            end

            project.refresh_annotations(M.update)
            configure(client, server)

            on_attach()
        end,
    })
end

return M
