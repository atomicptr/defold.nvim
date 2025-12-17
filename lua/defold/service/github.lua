local M = {}

---@param owner string
---@param repository string
---@param current_version string|nil
---@return boolean
function M.is_update_available(owner, repository, current_version)
    local log = require "defold.service.logger"
    local sidecar = require "defold.sidecar"

    local ok, res = pcall(sidecar.fetch_github_release, owner, repository)
    if not ok then
        log.error(string.format("Could not check if github repo update is available because: %s", res))
        return false
    end

    -- no release exists?
    if not res.tag_name then
        return false
    end

    -- we dont have a version specified yet so everything is new
    if current_version == nil then
        return true
    end

    return vim.version.lt(current_version, res.tag_name)
end

return M
