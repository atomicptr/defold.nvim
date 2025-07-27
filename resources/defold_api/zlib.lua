--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.10.3

  Zlib compression API documentation

  Functions for compression and decompression of string buffers.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.zlib
zlib = {}

---A lua error is raised is on error
---@param buf string buffer to deflate
---@return string buf deflated buffer
function zlib.deflate(buf) end

---A lua error is raised is on error
---@param buf string buffer to inflate
---@return string buf inflated buffer
function zlib.inflate(buf) end

return zlib