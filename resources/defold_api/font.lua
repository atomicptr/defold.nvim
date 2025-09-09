--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.0

  Font API documentation

  Functions, messages and properties used to manipulate font resources.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.font
font = {}

---Asynchronoously adds more glyphs to a .fontc resource
---@param path string|hash The path to the .fontc resource
---@param text string A string with unique unicode characters to be loaded
---@param callback? fun(self, request_id, result, errstring) (optional) A callback function that is called after the request is finished
---
---`self`
---object The current object.
---`request_id`
---number The request id
---`result`
---boolean True if request was succesful
---`errstring`
---string `nil` if the request was successful
---
---@return number request_id Returns the asynchronous request id
function font.add_glyphs(path, text, callback) end

---Removes glyphs from the font
---@param path string|hash The path to the .fontc resource
---@param text string A string with unique unicode characters to be removed
function font.remove_glyphs(path, text) end

return font