--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.1

  Graphics API documentation

  Graphics functions and constants.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.graphics
graphics = {}

---
graphics.BLEND_FACTOR_CONSTANT_ALPHA = nil

---
graphics.BLEND_FACTOR_CONSTANT_COLOR = nil

---
graphics.BLEND_FACTOR_DST_ALPHA = nil

---
graphics.BLEND_FACTOR_DST_COLOR = nil

---
graphics.BLEND_FACTOR_ONE = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_DST_ALPHA = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_DST_COLOR = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = nil

---
graphics.BLEND_FACTOR_ONE_MINUS_SRC_COLOR = nil

---
graphics.BLEND_FACTOR_SRC_ALPHA = nil

---
graphics.BLEND_FACTOR_SRC_ALPHA_SATURATE = nil

---
graphics.BLEND_FACTOR_SRC_COLOR = nil

---
graphics.BLEND_FACTOR_ZERO = nil

---
graphics.BUFFER_TYPE_COLOR0_BIT = nil

---May be nil if multitarget rendering isn't supported
graphics.BUFFER_TYPE_COLOR1_BIT = nil

---May be nil if multitarget rendering isn't supported
graphics.BUFFER_TYPE_COLOR2_BIT = nil

---May be nil if multitarget rendering isn't supported
graphics.BUFFER_TYPE_COLOR3_BIT = nil

---
graphics.BUFFER_TYPE_DEPTH_BIT = nil

---
graphics.BUFFER_TYPE_STENCIL_BIT = nil

---
graphics.COMPARE_FUNC_ALWAYS = nil

---
graphics.COMPARE_FUNC_EQUAL = nil

---
graphics.COMPARE_FUNC_GEQUAL = nil

---
graphics.COMPARE_FUNC_GREATER = nil

---
graphics.COMPARE_FUNC_LEQUAL = nil

---
graphics.COMPARE_FUNC_LESS = nil

---
graphics.COMPARE_FUNC_NEVER = nil

---
graphics.COMPARE_FUNC_NOTEQUAL = nil

---
graphics.COMPRESSION_TYPE_BASIS_ETC1S = nil

---
graphics.COMPRESSION_TYPE_BASIS_UASTC = nil

---
graphics.COMPRESSION_TYPE_DEFAULT = nil

---
graphics.COMPRESSION_TYPE_WEBP = nil

---
graphics.COMPRESSION_TYPE_WEBP_LOSSY = nil

---
graphics.FACE_TYPE_BACK = nil

---
graphics.FACE_TYPE_FRONT = nil

---
graphics.FACE_TYPE_FRONT_AND_BACK = nil

---
graphics.STATE_ALPHA_TEST = nil

---
graphics.STATE_ALPHA_TEST_SUPPORTED = nil

---
graphics.STATE_BLEND = nil

---
graphics.STATE_CULL_FACE = nil

---
graphics.STATE_DEPTH_TEST = nil

---
graphics.STATE_POLYGON_OFFSET_FILL = nil

---
graphics.STATE_SCISSOR_TEST = nil

---
graphics.STATE_STENCIL_TEST = nil

---
graphics.STENCIL_OP_DECR = nil

---
graphics.STENCIL_OP_DECR_WRAP = nil

---
graphics.STENCIL_OP_INCR = nil

---
graphics.STENCIL_OP_INCR_WRAP = nil

---
graphics.STENCIL_OP_INVERT = nil

---
graphics.STENCIL_OP_KEEP = nil

---
graphics.STENCIL_OP_REPLACE = nil

---
graphics.STENCIL_OP_ZERO = nil

---
graphics.TEXTURE_FILTER_DEFAULT = nil

---
graphics.TEXTURE_FILTER_LINEAR = nil

---
graphics.TEXTURE_FILTER_LINEAR_MIPMAP_LINEAR = nil

---
graphics.TEXTURE_FILTER_LINEAR_MIPMAP_NEAREST = nil

---
graphics.TEXTURE_FILTER_NEAREST = nil

---
graphics.TEXTURE_FILTER_NEAREST_MIPMAP_LINEAR = nil

---
graphics.TEXTURE_FILTER_NEAREST_MIPMAP_NEAREST = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_BGRA8U = nil

---
graphics.TEXTURE_FORMAT_DEPTH = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_LUMINANCE = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_LUMINANCE_ALPHA = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_R16F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_R32F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_R32UI = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RG16F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RG32F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB16F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB32F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA16F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA32F = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA32UI = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_16BPP = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_ASTC_4X4 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_BC3 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_BC7 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_ETC2 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_PVRTC_2BPPV1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGBA_PVRTC_4BPPV1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB_16BPP = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB_BC1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB_ETC1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB_PVRTC_2BPPV1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RGB_PVRTC_4BPPV1 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RG_BC5 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_RG_ETC2 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_R_BC4 = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_FORMAT_R_ETC2 = nil

---
graphics.TEXTURE_FORMAT_STENCIL = nil

---
graphics.TEXTURE_TYPE_2D = nil

---
graphics.TEXTURE_TYPE_2D_ARRAY = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_TYPE_3D = nil

---
graphics.TEXTURE_TYPE_CUBE_MAP = nil

---
graphics.TEXTURE_TYPE_IMAGE_2D = nil

---May be nil if the graphics driver doesn't support it
graphics.TEXTURE_TYPE_IMAGE_3D = nil

---
graphics.TEXTURE_USAGE_FLAG_COLOR = nil

---
graphics.TEXTURE_USAGE_FLAG_INPUT = nil

---
graphics.TEXTURE_USAGE_FLAG_MEMORYLESS = nil

---
graphics.TEXTURE_USAGE_FLAG_SAMPLE = nil

---
graphics.TEXTURE_USAGE_FLAG_STORAGE = nil

---
graphics.TEXTURE_WRAP_CLAMP_TO_BORDER = nil

---
graphics.TEXTURE_WRAP_CLAMP_TO_EDGE = nil

---
graphics.TEXTURE_WRAP_MIRRORED_REPEAT = nil

---
graphics.TEXTURE_WRAP_REPEAT = nil

return graphics