--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.10.4

  Camera API documentation

  Functions for interacting with camera components.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.camera
camera = {}

---get aspect ratio
---@param camera url|number|nil camera id
---@return number aspect_ratio the aspect ratio.
function camera.get_aspect_ratio(camera) end

---This function returns a table with all the camera URLs that have been
---registered in the render context.
---@return table cameras a table with all camera URLs
function camera.get_cameras() end

---get enabled
---@param camera url|number|nil camera id
---@return boolean flag true if the camera is enabled
function camera.get_enabled(camera) end

---get far z
---@param camera url|number|nil camera id
---@return number far_z the far z.
function camera.get_far_z(camera) end

---get field of view
---@param camera url|number|nil camera id
---@return number fov the field of view.
function camera.get_fov(camera) end

---get near z
---@param camera url|number|nil camera id
---@return number near_z the near z.
function camera.get_near_z(camera) end

---get orthographic zoom
---@param camera url|number|nil camera id
---@return number orthographic_zoom the zoom level when the camera uses orthographic projection.
function camera.get_orthographic_zoom(camera) end

---get projection matrix
---@param camera url|number|nil camera id
---@return matrix4 projection the projection matrix.
function camera.get_projection(camera) end

---get view matrix
---@param camera url|number|nil camera id
---@return matrix4 view the view matrix.
function camera.get_view(camera) end

---set aspect ratio
---@param camera url|number|nil camera id
---@param aspect_ratio number the aspect ratio.
function camera.set_aspect_ratio(camera, aspect_ratio) end

---set far z
---@param camera url|number|nil camera id
---@param far_z number the far z.
function camera.set_far_z(camera, far_z) end

---set field of view
---@param camera url|number|nil camera id
---@param fov number the field of view.
function camera.set_fov(camera, fov) end

---set near z
---@param camera url|number|nil camera id
---@param near_z number the near z.
function camera.set_near_z(camera, near_z) end

---set orthographic zoom
---@param camera url|number|nil camera id
---@param orthographic_zoom number the zoom level when the camera uses orthographic projection.
function camera.set_orthographic_zoom(camera, orthographic_zoom) end

return camera