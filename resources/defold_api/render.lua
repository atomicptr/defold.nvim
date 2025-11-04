--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.2

  Rendering API documentation

  Rendering functions, messages and constants. The "render" namespace is
  accessible only from render scripts.
  The rendering API was originally built on top of OpenGL ES 2.0, and it uses a subset of the
  OpenGL computer graphics rendering API for rendering 2D and 3D computer
  graphics. Our current target is OpenGLES 3.0 with fallbacks to 2.0 on some platforms.
  [icon:attention] It is possible to create materials and write shaders that
  require features not in OpenGL ES 2.0, but those will not work cross platform.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.render
render = {}

---Clear buffers in the currently enabled render target with specified value. If the render target has been created with multiple
---color attachments, all buffers will be cleared with the same value.
---@param buffers table table with keys specifying which buffers to clear and values set to clear values. Available keys are:
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---- `graphics.BUFFER_TYPE_DEPTH_BIT`
---- `graphics.BUFFER_TYPE_STENCIL_BIT`
---
function render.clear(buffers) end

---Constant buffers are used to set shader program variables and are optionally passed to the `render.draw()` function.
---The buffer's constant elements can be indexed like an ordinary Lua table, but you can't iterate over them with pairs() or ipairs().
---@return constant_buffer buffer new constant buffer
function render.constant_buffer() end

---Deletes a render target created by a render script.
---You cannot delete a render target resource.
---@param render_target render_target render target to delete
function render.delete_render_target(render_target) end

---If a material is currently enabled, disable it.
---The name of the material must be specified in the ".render" resource set
---in the "game.project" setting.
function render.disable_material() end

---Disables a render state.
---@param state constant state to disable
---
---- `graphics.STATE_DEPTH_TEST`
---- `graphics.STATE_STENCIL_TEST`
---- `graphics.STATE_BLEND`
---- `graphics.STATE_ALPHA_TEST` ( not available on iOS and Android)
---- `graphics.STATE_CULL_FACE`
---- `graphics.STATE_POLYGON_OFFSET_FILL`
---
function render.disable_state(state) end

---Disables a texture that has previourly been enabled.
---@param binding number|string|hash texture binding, either by texture unit, string or hash that should be disabled
function render.disable_texture(binding) end

---Dispatches the currently enabled compute program. The dispatch call takes three arguments x,y,z which constitutes
---the 'global working group' of the compute dispatch. Together with the 'local working group' specified in the compute shader
---as a layout qualifier, these two sets of parameters forms the number of invocations the compute shader will execute.
---An optional constant buffer can be provided to override the default constants. If no constants buffer is provided, a default
---system constants buffer is used containing constants as defined in the compute program.
---@param x number global work group size X
---@param y number global work group size Y
---@param z number global work group size Z
---@param options? table optional table with properties:
---
---`constants`
---constant_buffer optional constants to use while rendering
---
function render.dispatch_compute(x, y, z, options) end

---Draws all objects that match a specified predicate. An optional constant buffer can be
---provided to override the default constants. If no constants buffer is provided, a default
---system constants buffer is used containing constants as defined in materials and set through
---go.set (or particlefx.set_constant) on visual components.
---@param predicate number predicate to draw for
---@param options? { frustum?:matrix4, frustum_planes?:number, constants?:constant_buffer, sort_order?:integer } optional table with properties:
---
---`frustum`
---matrix4 A frustum matrix used to cull renderable items. (E.g. `local frustum = proj * view`). default=nil
---`frustum_planes`
---int Determines which sides of the frustum will be used. Default is render.FRUSTUM_PLANES_SIDES.
---
---
---- render.FRUSTUM_PLANES_SIDES : The left, right, top and bottom sides of the frustum.
---- render.FRUSTUM_PLANES_ALL : All 6 sides of the frustum.
---
---
---`constants`
---constant_buffer optional constants to use while rendering
---`sort_order`
---int How to sort draw order for world-ordered entries. Default uses the renderer's preferred world sorting (back-to-front).
---
function render.draw(predicate, options) end

---Draws all 3d debug graphics such as lines drawn with "draw_line" messages and physics visualization.
---@param options? { frustum?:matrix4, frustum_planes?:number } optional table with properties:
---
---`frustum`
---matrix4 A frustum matrix used to cull renderable items. (E.g. `local frustum = proj * view`). May be nil.
---`frustum_planes`
---int Determines which sides of the frustum will be used. Default is render.FRUSTUM_PLANES_SIDES.
---
---
---- render.FRUSTUM_PLANES_SIDES : The left, right, top and bottom sides of the frustum.
---- render.FRUSTUM_PLANES_ALL : All sides of the frustum.
---
function render.draw_debug3d(options) end

---If another material was already enabled, it will be automatically disabled
---and the specified material is used instead.
---The name of the material must be specified in the ".render" resource set
---in the "game.project" setting.
---@param material_id string|hash material id to enable
function render.enable_material(material_id) end

---Enables a particular render state. The state will be enabled until disabled.
---@param state constant state to enable
---
---- `graphics.STATE_DEPTH_TEST`
---- `graphics.STATE_STENCIL_TEST`
---- `graphics.STATE_BLEND`
---- `graphics.STATE_ALPHA_TEST` ( not available on iOS and Android)
---- `graphics.STATE_CULL_FACE`
---- `graphics.STATE_POLYGON_OFFSET_FILL`
---
function render.enable_state(state) end

---Sets the specified texture handle for a render target attachment or a regular texture
---that should be used for rendering. The texture can be bound to either a texture unit
---or to a sampler name by a hash or a string.
---A texture can be bound to multiple units and sampler names at the same time,
---the actual binding will be applied to the shaders when a shader program is bound.
---When mixing binding using both units and sampler names, you might end up in situations
---where two different textures will be applied to the same bind location in the shader.
---In this case, the texture set to the named sampler will take precedence over the unit.
---Note that you can bind multiple sampler names to the same texture, in case you want to reuse
---the same texture for differnt use-cases. It is however recommended that you use the same name
---everywhere for the textures that should be shared across different materials.
---@param binding number|string|hash texture binding, either by texture unit, string or hash for the sampler name that the texture should be bound to
---@param handle_or_name number|string|hash render target or texture handle that should be bound, or a named resource in the "Render Resource" table in the currently assigned .render file
---@param buffer_type? constant optional buffer type from which to enable the texture. Note that this argument only applies to render targets. Defaults to `graphics.BUFFER_TYPE_COLOR0_BIT`. These values are supported:
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---
---If The render target has been created as depth and/or stencil textures, these buffer types can be used:
---
---- `graphics.BUFFER_TYPE_DEPTH_BIT`
---- `graphics.BUFFER_TYPE_STENCIL_BIT`
---
---If the render target has been created with multiple color attachments, these buffer types can be used
---to enable those textures as well. Currently 4 color attachments are supported:
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---- `graphics.BUFFER_TYPE_COLOR1_BIT`
---- `graphics.BUFFER_TYPE_COLOR2_BIT`
---- `graphics.BUFFER_TYPE_COLOR3_BIT`
---
function render.enable_texture(binding, handle_or_name, buffer_type) end

---Returns the logical window height that is set in the "game.project" settings.
---Note that the actual window pixel size can change, either by device constraints
---or user input.
---@return number height specified window height
function render.get_height() end

---Returns the specified buffer height from a render target.
---@param render_target render_target render target from which to retrieve the buffer height
---@param buffer_type constant which type of buffer to retrieve the height from
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---- `graphics.BUFFER_TYPE_DEPTH_BIT`
---- `graphics.BUFFER_TYPE_STENCIL_BIT`
---
---@return number height the height of the render target buffer texture
function render.get_render_target_height(render_target, buffer_type) end

---Returns the specified buffer width from a render target.
---@param render_target render_target render target from which to retrieve the buffer width
---@param buffer_type constant which type of buffer to retrieve the width from
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---- `graphics.BUFFER_TYPE_COLOR[x]_BIT` (x: [0..3], if supported!)
---- `graphics.BUFFER_TYPE_DEPTH_BIT`
---- `graphics.BUFFER_TYPE_STENCIL_BIT`
---
---@return number width the width of the render target buffer texture
function render.get_render_target_width(render_target, buffer_type) end

---Returns the logical window width that is set in the "game.project" settings.
---Note that the actual window pixel size can change, either by device constraints
---or user input.
---@return number width specified window width (number)
function render.get_width() end

---Returns the actual physical window height.
---Note that this value might differ from the logical height that is set in the
---"game.project" settings.
---@return number height actual window height
function render.get_window_height() end

---Returns the actual physical window width.
---Note that this value might differ from the logical width that is set in the
---"game.project" settings.
---@return number width actual window width
function render.get_window_width() end

---This function returns a new render predicate for objects with materials matching
---the provided material tags. The provided tags are combined into a bit mask
---for the predicate. If multiple tags are provided, the predicate matches materials
---with all tags ANDed together.
---The current limit to the number of tags that can be defined is `64`.
---@param tags (string|hash)[] table of tags that the predicate should match. The tags can be of either hash or string type
---@return number predicate new predicate
function render.predicate(tags) end

---Creates a new render target according to the supplied
---specification table.
---The table should contain keys specifying which buffers should be created
---with what parameters. Each buffer key should have a table value consisting
---of parameters. The following parameter keys are available:
---Key
---Values
---`format`
---`graphics.TEXTURE_FORMAT_LUMINANCE``graphics.TEXTURE_FORMAT_RGB``graphics.TEXTURE_FORMAT_RGBA``graphics.TEXTURE_FORMAT_DEPTH``graphics.TEXTURE_FORMAT_STENCIL``graphics.TEXTURE_FORMAT_RGBA32F``graphics.TEXTURE_FORMAT_RGBA16F`
---`width`
---number
---`height`
---number
---`min_filter` (optional)
---`graphics.TEXTURE_FILTER_LINEAR``graphics.TEXTURE_FILTER_NEAREST`
---`mag_filter` (optional)
---`graphics.TEXTURE_FILTER_LINEAR``graphics.TEXTURE_FILTER_NEAREST`
---`u_wrap`     (optional)
---`graphics.TEXTURE_WRAP_CLAMP_TO_BORDER``graphics.TEXTURE_WRAP_CLAMP_TO_EDGE``graphics.TEXTURE_WRAP_MIRRORED_REPEAT``graphics.TEXTURE_WRAP_REPEAT`
---`v_wrap`     (optional)
---`graphics.TEXTURE_WRAP_CLAMP_TO_BORDER``graphics.TEXTURE_WRAP_CLAMP_TO_EDGE``graphics.TEXTURE_WRAP_MIRRORED_REPEAT``graphics.TEXTURE_WRAP_REPEAT`
---`flags`      (optional)
---`render.TEXTURE_BIT` (only applicable to depth and stencil buffers)
---The render target can be created to support multiple color attachments. Each attachment can have different format settings and texture filters,
---but attachments must be added in sequence, meaning you cannot create a render target at slot 0 and 3.
---Instead it has to be created with all four buffer types ranging from [0..3] (as denoted by graphics.BUFFER_TYPE_COLORX_BIT where 'X' is the attachment you want to create).
---It is not guaranteed that the device running the script can support creating render targets with multiple color attachments. To check if the device can support multiple attachments,
---you can check if the `render` table contains any of the `BUFFER_TYPE_COLOR1_BIT`, `BUFFER_TYPE_COLOR2_BIT` or `BUFFER_TYPE_COLOR3_BIT` constants:
---`function init(self)
---    if graphics.BUFFER_TYPE_COLOR1_BIT == nil then
---        -- this devices does not support multiple color attachments
---    end
---end
---`
---@param name string render target name
---@param parameters table<number, { format:number, width:number, height:number, min_filter?:number, mag_filter?:number, u_wrap?:number, v_wrap?:number, flags?:number}> table of buffer parameters, see the description for available keys and values
---@return render_target render_target new render target
function render.render_target(name, parameters) end

---Specifies the arithmetic used when computing pixel values that are written to the frame
---buffer. In RGBA mode, pixels can be drawn using a function that blends the source RGBA
---pixel values with the destination pixel values already in the frame buffer.
---Blending is initially disabled.
---`source_factor` specifies which method is used to scale the source color components.
---`destination_factor` specifies which method is used to scale the destination color
---components.
---Source color components are referred to as (Rs,Gs,Bs,As).
---Destination color components are referred to as (Rd,Gd,Bd,Ad).
---The color specified by setting the blendcolor is referred to as (Rc,Gc,Bc,Ac).
---The source scale factor is referred to as (sR,sG,sB,sA).
---The destination scale factor is referred to as (dR,dG,dB,dA).
---The color values have integer values between 0 and (kR,kG,kB,kA), where kc = 2mc - 1 and mc is the number of bitplanes for that color. I.e for 8 bit color depth, color values are between `0` and `255`.
---Available factor constants and corresponding scale factors:
---Factor constant
---Scale factor (fR,fG,fB,fA)
---`graphics.BLEND_FACTOR_ZERO`
---(0,0,0,0)
---`graphics.BLEND_FACTOR_ONE`
---(1,1,1,1)
---`graphics.BLEND_FACTOR_SRC_COLOR`
---(Rs/kR,Gs/kG,Bs/kB,As/kA)
---`graphics.BLEND_FACTOR_ONE_MINUS_SRC_COLOR`
---(1,1,1,1) - (Rs/kR,Gs/kG,Bs/kB,As/kA)
---`graphics.BLEND_FACTOR_DST_COLOR`
---(Rd/kR,Gd/kG,Bd/kB,Ad/kA)
---`graphics.BLEND_FACTOR_ONE_MINUS_DST_COLOR`
---(1,1,1,1) - (Rd/kR,Gd/kG,Bd/kB,Ad/kA)
---`graphics.BLEND_FACTOR_SRC_ALPHA`
---(As/kA,As/kA,As/kA,As/kA)
---`graphics.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA`
---(1,1,1,1) - (As/kA,As/kA,As/kA,As/kA)
---`graphics.BLEND_FACTOR_DST_ALPHA`
---(Ad/kA,Ad/kA,Ad/kA,Ad/kA)
---`graphics.BLEND_FACTOR_ONE_MINUS_DST_ALPHA`
---(1,1,1,1) - (Ad/kA,Ad/kA,Ad/kA,Ad/kA)
---`graphics.BLEND_FACTOR_CONSTANT_COLOR`
---(Rc,Gc,Bc,Ac)
---`graphics.BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR`
---(1,1,1,1) - (Rc,Gc,Bc,Ac)
---`graphics.BLEND_FACTOR_CONSTANT_ALPHA`
---(Ac,Ac,Ac,Ac)
---`graphics.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA`
---(1,1,1,1) - (Ac,Ac,Ac,Ac)
---`graphics.BLEND_FACTOR_SRC_ALPHA_SATURATE`
---(i,i,i,1) where i = min(As, kA - Ad) /kA
---The blended RGBA values of a pixel comes from the following equations:
---- Rd = min(kR, Rs * sR + Rd * dR)
---- Gd = min(kG, Gs * sG + Gd * dG)
---- Bd = min(kB, Bs * sB + Bd * dB)
---- Ad = min(kA, As * sA + Ad * dA)
---Blend function `(graphics.BLEND_FACTOR_SRC_ALPHA, graphics.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA)` is useful for
---drawing with transparency when the drawn objects are sorted from farthest to nearest.
---It is also useful for drawing antialiased points and lines in arbitrary order.
---@param source_factor number source factor
---@param destination_factor number destination factor
function render.set_blend_func(source_factor, destination_factor) end

---Sets the current render camera to be used for rendering. If a render camera
---has been set by the render script, the renderer will be using its projection and view matrix
---during rendering. If a projection and/or view matrix has been set by the render script,
---they will not be used until the current render camera has been reset by calling `render.set_camera()`.
---If the 'use_frustum' flag in the options table has been set to true, the renderer will automatically use the
---camera frustum for frustum culling regardless of what frustum is being passed into the render.draw() function.
---Note that the frustum plane option in render.draw can still be used together with the camera.
---@param camera url|number|nil camera id to use, or nil to reset
---@param options? { use_frustum?:boolean } optional table with properties:
---
---`use_frustum`
---boolean If true, the renderer will use the cameras view-projection matrix for frustum culling (default: false)
---
function render.set_camera(camera, options) end

---Specifies whether the individual color components in the frame buffer is enabled for writing (`true`) or disabled (`false`). For example, if `blue` is `false`, nothing is written to the blue component of any pixel in any of the color buffers, regardless of the drawing operation attempted. Note that writing are either enabled or disabled for entire color components, not the individual bits of a component.
---The component masks are all initially `true`.
---@param red boolean red mask
---@param green boolean green mask
---@param blue boolean blue mask
---@param alpha boolean alpha mask
function render.set_color_mask(red, green, blue, alpha) end

---The name of the compute program must be specified in the ".render" resource set
---in the "game.project" setting. If nil (or no arguments) are passed to this function,
---the current compute program will instead be disabled.
---@param compute string|hash|nil compute id to use, or nil to disable
function render.set_compute(compute) end

---Specifies whether front- or back-facing polygons can be culled
---when polygon culling is enabled. Polygon culling is initially disabled.
---If mode is `graphics.FACE_TYPE_FRONT_AND_BACK`, no polygons are drawn, but other
---primitives such as points and lines are drawn. The initial value for
---`face_type` is `graphics.FACE_TYPE_BACK`.
---@param face_type number face type
---
---- `graphics.FACE_TYPE_FRONT`
---- `graphics.FACE_TYPE_BACK`
---- `graphics.FACE_TYPE_FRONT_AND_BACK`
---
function render.set_cull_face(face_type) end

---Specifies the function that should be used to compare each incoming pixel
---depth value with the value present in the depth buffer.
---The comparison is performed only if depth testing is enabled and specifies
---the conditions under which a pixel will be drawn.
---Function constants:
---- `graphics.COMPARE_FUNC_NEVER` (never passes)
---- `graphics.COMPARE_FUNC_LESS` (passes if the incoming depth value is less than the stored value)
---- `graphics.COMPARE_FUNC_LEQUAL` (passes if the incoming depth value is less than or equal to the stored value)
---- `graphics.COMPARE_FUNC_GREATER` (passes if the incoming depth value is greater than the stored value)
---- `graphics.COMPARE_FUNC_GEQUAL` (passes if the incoming depth value is greater than or equal to the stored value)
---- `graphics.COMPARE_FUNC_EQUAL` (passes if the incoming depth value is equal to the stored value)
---- `graphics.COMPARE_FUNC_NOTEQUAL` (passes if the incoming depth value is not equal to the stored value)
---- `graphics.COMPARE_FUNC_ALWAYS` (always passes)
---The depth function is initially set to `graphics.COMPARE_FUNC_LESS`.
---@param func number depth test function, see the description for available values
function render.set_depth_func(func) end

---Specifies whether the depth buffer is enabled for writing. The supplied mask governs
---if depth buffer writing is enabled (`true`) or disabled (`false`).
---The mask is initially `true`.
---@param depth boolean depth mask
function render.set_depth_mask(depth) end

---Set or remove listener. Currenly only only two type of events can arrived:
---`render.CONTEXT_EVENT_CONTEXT_LOST` - when rendering context lost. Rending paused and all graphics resources become invalid.
---`render.CONTEXT_EVENT_CONTEXT_RESTORED` - when rendering context was restored. Rendering still paused and graphics resources still
---invalid but can be reloaded.
---@param callback fun(self, event_type)|nil A callback that receives all render related events.
---Pass `nil` if want to remove listener.
---
---`self`
---object The render script
---`event_type`
---string Rendering event. Possible values: `render.CONTEXT_EVENT_CONTEXT_LOST`, `render.CONTEXT_EVENT_CONTEXT_RESTORED`
---
function render.set_listener(callback) end

---Sets the scale and units used to calculate depth values.
---If `graphics.STATE_POLYGON_OFFSET_FILL` is enabled, each fragment's depth value
---is offset from its interpolated value (depending on the depth value of the
---appropriate vertices). Polygon offset can be used when drawing decals, rendering
---hidden-line images etc.
---`factor` specifies a scale factor that is used to create a variable depth
---offset for each polygon. The initial value is `0`.
---`units` is multiplied by an implementation-specific value to create a
---constant depth offset. The initial value is `0`.
---The value of the offset is computed as `factor` × `DZ` + `r` × `units`
---`DZ` is a measurement of the depth slope of the polygon which is the change in z (depth)
---values divided by the change in either x or y coordinates, as you traverse a polygon.
---The depth values are in window coordinates, clamped to the range [0, 1].
---`r` is the smallest value that is guaranteed to produce a resolvable difference.
---It's value is an implementation-specific constant.
---The offset is added before the depth test is performed and before the
---value is written into the depth buffer.
---@param factor number polygon offset factor
---@param units number polygon offset units
function render.set_polygon_offset(factor, units) end

---Sets the projection matrix to use when rendering.
---@param matrix matrix4 projection matrix
function render.set_projection(matrix) end

---Sets a render target. Subsequent draw operations will be to the
---render target until it is replaced by a subsequent call to set_render_target.
---This function supports render targets created by a render script, or a render target resource.
---@param render_target render_target render target to set. render.RENDER_TARGET_DEFAULT to set the default render target
---@param options? { transient?:number[] } optional table with behaviour parameters
---
---`transient`
---table Transient frame buffer types are only valid while the render target is active, i.e becomes undefined when a new target is set by a subsequent call to set_render_target.
--- Default is all non-transient. Be aware that some hardware uses a combined depth stencil buffer and when this is the case both are considered non-transient if exclusively selected!
--- A buffer type defined that doesn't exist in the render target is silently ignored.
---
---
---- `graphics.BUFFER_TYPE_COLOR0_BIT`
---- `graphics.BUFFER_TYPE_DEPTH_BIT`
---- `graphics.BUFFER_TYPE_STENCIL_BIT`
---
function render.set_render_target(render_target, options) end

---Sets the render target size for a render target created from
---either a render script, or from a render target resource.
---@param render_target render_target render target to set size for
---@param width number new render target width
---@param height number new render target height
function render.set_render_target_size(render_target, width, height) end

---Stenciling is similar to depth-buffering as it enables and disables drawing on a
---per-pixel basis. First, GL drawing primitives are drawn into the stencil planes.
---Second, geometry and images are rendered but using the stencil planes to mask out
---where to draw.
---The stencil test discards a pixel based on the outcome of a comparison between the
---reference value `ref` and the corresponding value in the stencil buffer.
---`func` specifies the comparison function. See the table below for values.
---The initial value is `graphics.COMPARE_FUNC_ALWAYS`.
---`ref` specifies the reference value for the stencil test. The value is clamped to
---the range [0, 2n-1], where n is the number of bitplanes in the stencil buffer.
---The initial value is `0`.
---`mask` is ANDed with both the reference value and the stored stencil value when the test
---is done. The initial value is all `1`'s.
---Function constant:
---- `graphics.COMPARE_FUNC_NEVER` (never passes)
---- `graphics.COMPARE_FUNC_LESS` (passes if (ref & mask) < (stencil & mask))
---- `graphics.COMPARE_FUNC_LEQUAL` (passes if (ref & mask) <= (stencil & mask))
---- `graphics.COMPARE_FUNC_GREATER` (passes if (ref & mask) > (stencil & mask))
---- `graphics.COMPARE_FUNC_GEQUAL` (passes if (ref & mask) >= (stencil & mask))
---- `graphics.COMPARE_FUNC_EQUAL` (passes if (ref & mask) = (stencil & mask))
---- `graphics.COMPARE_FUNC_NOTEQUAL` (passes if (ref & mask) != (stencil & mask))
---- `graphics.COMPARE_FUNC_ALWAYS` (always passes)
---@param func number stencil test function, see the description for available values
---@param ref number reference value for the stencil test
---@param mask number mask that is ANDed with both the reference value and the stored stencil value when the test is done
function render.set_stencil_func(func, ref, mask) end

---The stencil mask controls the writing of individual bits in the stencil buffer.
---The least significant `n` bits of the parameter `mask`, where `n` is the number of
---bits in the stencil buffer, specify the mask.
---Where a `1` bit appears in the mask, the corresponding
---bit in the stencil buffer can be written. Where a `0` bit appears in the mask,
---the corresponding bit in the stencil buffer is never written.
---The mask is initially all `1`'s.
---@param mask number stencil mask
function render.set_stencil_mask(mask) end

---The stencil test discards a pixel based on the outcome of a comparison between the
---reference value `ref` and the corresponding value in the stencil buffer.
---To control the test, call render.set_stencil_func.
---This function takes three arguments that control what happens to the stored stencil
---value while stenciling is enabled. If the stencil test fails, no change is made to the
---pixel's color or depth buffers, and `sfail` specifies what happens to the stencil buffer
---contents.
---Operator constants:
---- `graphics.STENCIL_OP_KEEP` (keeps the current value)
---- `graphics.STENCIL_OP_ZERO` (sets the stencil buffer value to 0)
---- `graphics.STENCIL_OP_REPLACE` (sets the stencil buffer value to `ref`, as specified by render.set_stencil_func)
---- `graphics.STENCIL_OP_INCR` (increments the stencil buffer value and clamp to the maximum representable unsigned value)
---- `graphics.STENCIL_OP_INCR_WRAP` (increments the stencil buffer value and wrap to zero when incrementing the maximum representable unsigned value)
---- `graphics.STENCIL_OP_DECR` (decrements the current stencil buffer value and clamp to 0)
---- `graphics.STENCIL_OP_DECR_WRAP` (decrements the current stencil buffer value and wrap to the maximum representable unsigned value when decrementing zero)
---- `graphics.STENCIL_OP_INVERT` (bitwise inverts the current stencil buffer value)
---`dppass` and `dpfail` specify the stencil buffer actions depending on whether subsequent
---depth buffer tests succeed (dppass) or fail (dpfail).
---The initial value for all operators is `graphics.STENCIL_OP_KEEP`.
---@param sfail number action to take when the stencil test fails
---@param dpfail number the stencil action when the stencil test passes
---@param dppass number the stencil action when both the stencil test and the depth test pass, or when the stencil test passes and either there is no depth buffer or depth testing is not enabled
function render.set_stencil_op(sfail, dpfail, dppass) end

---Sets the view matrix to use when rendering.
---@param matrix matrix4 view matrix to set
function render.set_view(matrix) end

---Set the render viewport to the specified rectangle.
---@param x number left corner
---@param y number bottom corner
---@param width number viewport width
---@param height number viewport height
function render.set_viewport(x, y, width, height) end

---
render.FRUSTUM_PLANES_ALL = nil

---
render.FRUSTUM_PLANES_SIDES = nil

---
render.RENDER_TARGET_DEFAULT = nil

---Depth sort far-to-near (default; good for transparent passes).
render.SORT_BACK_TO_FRONT = nil

---Depth sort near-to-far (good for opaque passes to reduce overdraw).
render.SORT_FRONT_TO_BACK = nil

---No per-call sorting; draw entries in insertion order.
render.SORT_NONE = nil

return render