require("defold").setup {}

if vim.version.cmp(vim.version(), { 0, 12, 0 }) >= 0 then
    vim.api.nvim_create_autocmd("PackChanged", {
        callback = function(ev)
            if ev.data.spec.name ~= "defold.nvim" then
                return
            end

            if ev.data.kind == "install" or ev.data.kind == "update" then
                require("defold").download()
            end
        end,
    })
end
