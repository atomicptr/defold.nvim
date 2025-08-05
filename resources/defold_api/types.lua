--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.10.4

  Types API documentation

  Functions for checking Defold userdata types.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.types
types = {}

---Check if passed type is hash.
---@param var any Variable to check type
---@return boolean result True if passed type is hash
function types.is_hash(var) end

---Check if passed type is matrix4.
---@param var any Variable to check type
---@return boolean result True if passed type is matrix4
function types.is_matrix4(var) end

---Check if passed type is quaternion.
---@param var any Variable to check type
---@return boolean result True if passed type is quaternion
function types.is_quat(var) end

---Check if passed type is URL.
---@param var any Variable to check type
---@return boolean result True if passed type is URL
function types.is_url(var) end

---Check if passed type is vector.
---@param var any Variable to check type
---@return boolean result True if passed type is vector
function types.is_vector(var) end

---Check if passed type is vector3.
---@param var any Variable to check type
---@return boolean result True if passed type is vector3
function types.is_vector3(var) end

---Check if passed type is vector4.
---@param var any Variable to check type
---@return boolean result True if passed type is vector4
function types.is_vector4(var) end

return types