--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.1

  Camera API documentation

  Camera functions, messages and constants.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.camera
camera = {}

---Gets the effective aspect ratio of the camera. If auto aspect ratio is enabled,
---returns the aspect ratio calculated from the current render target dimensions.
---Otherwise returns the manually set aspect ratio.
---@param camera url|number|nil camera id
---@return number aspect_ratio the effective aspect ratio.
function camera.get_aspect_ratio(camera) end

---Returns whether auto aspect ratio is enabled. When enabled, the camera automatically
---calculates aspect ratio from render target dimensions. When disabled, uses the
---manually set aspect ratio value.
---@param camera url|number|nil camera id
---@return boolean auto_aspect_ratio true if auto aspect ratio is enabled
function camera.get_auto_aspect_ratio(camera) end

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

---get orthographic zoom mode
---@param camera url|number|nil camera id
---@return number mode one of camera.ORTHO_MODE_FIXED, camera.ORTHO_MODE_AUTO_FIT or
---camera.ORTHO_MODE_AUTO_COVER
function camera.get_orthographic_mode(camera) end

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

---Sets the manual aspect ratio for the camera. This value is only used when
---auto aspect ratio is disabled. To disable auto aspect ratio and use this
---manual value, call camera.set_auto_aspect_ratio(camera, false).
---@param camera url|number|nil camera id
---@param aspect_ratio number the manual aspect ratio value.
function camera.set_aspect_ratio(camera, aspect_ratio) end

---Enables or disables automatic aspect ratio calculation. When enabled (true),
---the camera automatically calculates aspect ratio from render target dimensions.
---When disabled (false), uses the manually set aspect ratio value.
---@param camera url|number|nil camera id
---@param auto_aspect_ratio boolean true to enable auto aspect ratio
function camera.set_auto_aspect_ratio(camera, auto_aspect_ratio) end

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

---set orthographic zoom mode
---@param camera url|number|nil camera id
---@param mode number camera.ORTHO_MODE_FIXED, camera.ORTHO_MODE_AUTO_FIT or camera.ORTHO_MODE_AUTO_COVER
function camera.set_orthographic_mode(camera, mode) end

---set orthographic zoom
---@param camera url|number|nil camera id
---@param orthographic_zoom number the zoom level when the camera uses orthographic projection.
function camera.set_orthographic_zoom(camera, orthographic_zoom) end

---Computes zoom so the original display area covers the entire window while preserving aspect ratio.
---Equivalent to using max(window_width/width, window_height/height).
camera.ORTHO_MODE_AUTO_COVER = nil

---Computes zoom so the original display area (game.project width/height) fits inside the window
---while preserving aspect ratio. Equivalent to using min(window_width/width, window_height/height).
camera.ORTHO_MODE_AUTO_FIT = nil

---Uses the manually set orthographic zoom value (camera.set_orthographic_zoom).
camera.ORTHO_MODE_FIXED = nil

return camera