local M = {}

---@class defold.github.Asset
---@field name string
---@field browser_download_url string

---@class defold.github.Release
---@field tag_name string
---@field assets defold.github.Asset[]

---Fetch a GitHub release asynchronously (latest when tag is nil).
---@param owner string
---@param repository string
---@param tag string|nil
---@param callback fun(release: defold.github.Release|nil, err?: string)
function M.fetch_release(owner, repository, tag, callback)
    local url = string.format("https://api.github.com/repos/%s/%s/releases/latest", owner, repository)

    if tag then
        tag = tag:find "^v" and tag or "v" .. tag
        url = string.format("https://api.github.com/repos/%s/%s/releases/tags/%s", owner, repository, tag)
    end

    require("defold.service.os").fetch_json(url, callback)
end

---Download a release asset asynchronously.
---@param owner string
---@param repository string
---@param name string
---@param tag string|nil
---@param callback fun(file: string|nil, release: defold.github.Release|nil, err?: string)
function M.download_release(owner, repository, name, tag, callback)
    M.fetch_release(owner, repository, tag, function(release, err)
        if not release then
            callback(nil, nil, err)
            return
        end

        for _, asset in ipairs(release.assets or {}) do
            if asset.name == name then
                local tmp = vim.fn.tempname()

                require("defold.service.os").download(asset.browser_download_url, tmp, function(download_err)
                    if download_err then
                        os.remove(tmp)
                        callback(nil, nil, download_err)
                    else
                        callback(tmp, release)
                    end
                end)

                return
            end
        end

        callback(nil, nil, "Could not find release asset: " .. name)
    end)
end

return M
