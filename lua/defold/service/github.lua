local M = {}

---Fetch the latest github release of owner/repository
---@param owner string
---@param repository string
---@return table|nil
function M.fetch_release(owner, repository)
    local os = require "defold.service.os"
    local log = require "defold.service.logger"
    local url = string.format("https://api.github.com/repos/%s/%s/releases/latest", owner, repository)
    local release = os.fetch_json(url)

    if not release then
        log.error(string.format("Unable to fetch github release %s/%s", owner, repository))
        return nil
    end

    log.debug(string.format("Fetched %s/%s version: %s", owner, repository, release.tag_name))
    return release
end

---Fetch latest github release and download asset with `name`. Returns path to file or nil on error
---@param owner string
---@param repository string
---@param name string
---@return string|nil
---@return table|nil
function M.download_release(owner, repository, name)
    local osm = require "defold.service.os"
    local log = require "defold.service.logger"
    local release = M.fetch_release(owner, repository)

    if not release then
        log.error(string.format("Unable to download github release %s/%s file: %s", owner, repository, name))
        return nil, nil
    end

    for _, asset in ipairs(release.assets) do
        if asset.name == name then
            local tmp = os.tmpname()
            osm.download(asset.browser_download_url, tmp)
            return tmp, release
        end
    end

    log.error(string.format("Unable to find github release %s/%s file: %s", owner, repository, name))
    return nil, nil
end

return M
