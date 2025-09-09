--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.0

  Known types and aliases used in the Defold API
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class editor.bundle
editor.bundle = {}

---@class editor.prefs
editor.prefs = {}

---@class editor.prefs.SCOPE
editor.prefs.SCOPE = {}

---@class editor.prefs.schema
editor.prefs.schema = {}

---@class editor.tx
editor.tx = {}

---@class editor.ui
editor.ui = {}

---@class editor.ui.ALIGNMENT
editor.ui.ALIGNMENT = {}

---@class editor.ui.COLOR
editor.ui.COLOR = {}

---@class editor.ui.HEADING_STYLE
editor.ui.HEADING_STYLE = {}

---@class editor.ui.ICON
editor.ui.ICON = {}

---@class editor.ui.ISSUE_SEVERITY
editor.ui.ISSUE_SEVERITY = {}

---@class editor.ui.ORIENTATION
editor.ui.ORIENTATION = {}

---@class editor.ui.PADDING
editor.ui.PADDING = {}

---@class editor.ui.SPACING
editor.ui.SPACING = {}

---@class editor.ui.TEXT_ALIGNMENT
editor.ui.TEXT_ALIGNMENT = {}

---@class http.server
http.server = {}

---@class matrix4
---@field c0 vector4
---@field c1 vector4
---@field c2 vector4
---@field c3 vector4
---@field m00 number
---@field m01 number
---@field m02 number
---@field m03 number
---@field m10 number
---@field m11 number
---@field m12 number
---@field m13 number
---@field m20 number
---@field m21 number
---@field m22 number
---@field m23 number
---@field m30 number
---@field m31 number
---@field m32 number
---@field m33 number

---@class on_input.action
---@field dx? number The change in x value of a pointer device, if present.
---@field dy? number The change in y value of a pointer device, if present.
---@field gamepad? integer The change in screen space y value of a pointer device, if present.
---@field pressed? boolean If the input was pressed this frame. This is not present for mouse movement.
---@field released? boolean If the input was released this frame. This is not present for mouse movement.
---@field repeated? boolean If the input was repeated this frame. This is similar to how a key on a keyboard is repeated when you hold it down. This is not present for mouse movement.
---@field screen_dx? number The change in screen space x value of a pointer device, if present.
---@field screen_dy? number The index of the gamepad device that provided the input.
---@field screen_x? number The screen space x value of a pointer device, if present.
---@field screen_y? number The screen space y value of a pointer device, if present.
---@field text? string The text entered with the `text` action, if present
---@field touch? on_input.touch[] List of touch input, one element per finger, if present.
---@field value? number The amount of input given by the user. This is usually 1 for buttons and 0-1 for analogue inputs. This is not present for mouse movement.
---@field x? number The x value of a pointer device, if present.
---@field y? number The y value of a pointer device, if present.

---@class on_input.touch
---@field acc_x? number Accelerometer x value (if present).
---@field acc_y? number Accelerometer y value (if present).
---@field acc_z? number Accelerometer z value (if present).
---@field dx number The change in x value.
---@field dy number The change in y value.
---@field id number A number identifying the touch input during its duration.
---@field pressed boolean True if the finger was pressed this frame.
---@field released boolean True if the finger was released this frame.
---@field screen_dx? number The change in screen space x value of a pointer device, if present.
---@field screen_dy? number The index of the gamepad device that provided the input.
---@field screen_x? number The screen space x value of a pointer device, if present.
---@field screen_y? number The screen space y value of a pointer device, if present.
---@field tap_count integer Number of taps, one for single, two for double-tap, etc
---@field x number The x touch location.
---@field y number The y touch location.

---@class physics.raycast_response
---@field fraction number The fraction of the hit measured along the ray, where 0 is the start of the ray and 1 is the end
---@field group hash The collision group of the hit collision object as a hashed name
---@field id hash The instance id of the hit collision object
---@field normal vector3 The normal of the surface of the collision object where it was hit
---@field position vector3 The world position of the hit
---@field request_id number The id supplied when the ray cast was requested

---@class resource.animation
---@field flip_horizontal? boolean Optional flip the animation horizontally, the default value is false
---@field flip_vertical? boolean Optional flip the animation vertically, the default value is false
---@field fps? integer Optional fps of the animation, the default value is 30
---@field frame_end integer Index to the last geometry of the animation (non-inclusive). Indices are lua based and must be in the range of 1 .. in atlas.
---@field frame_start integer Index to the first geometry of the animation. Indices are lua based and must be in the range of 1 .. in atlas.
---@field height integer The height of the animation
---@field id string The id of the animation, used in e.g sprite.play_animation
---@field playback? constant Optional playback mode of the animation, the default value is go.PLAYBACK_ONCE_FORWARD
---@field width integer The width of the animation

---@class resource.atlas
---@field animations resource.animation[] A list of the animations in the atlas
---@field geometries resource.geometry[] A list of the geometries that should map to the texture data
---@field texture string|hash The path to the texture resource, e.g "/main/my_texture.texturec"

---@class resource.geometry
---@field height number The height of the image the sprite geometry represents
---@field id string The name of the geometry. Used when matching animations between multiple atlases
---@field indices number[] A list of the indices of the geometry in the form { i0, i1, i2, ..., in }. Each tripe in the list represents a triangle.
---@field pivot_x number The pivot x value of the image in unit coords. (0,0) is upper left corner, (1,1) is bottom right. Default is 0.5.
---@field pivot_y number The pivot y value of the image in unit coords. (0,0) is upper left corner, (1,1) is bottom right. Default is 0.5.
---@field rotated boolean Whether the image is rotated 90 degrees counter-clockwise in the atlas. This affects UV coordinate generation for proper rendering. Default is false.
---@field uvs number[] A list of the uv coordinates in texture space of the geometry in the form of { u0, v0, u1, v1, ..., un, vn }
---@field vertices number[] A list of the vertices in texture space of the geometry in the form { px0, py0, px1, py1, ..., pxn, pyn }
---@field width number The width of the image the sprite geometry represents

---@class socket.dns
socket.dns = {}

---@class tilemap.tiles
tilemap.tiles = {}

---@class url
---@field fragment hash
---@field path hash
---@field socket hash

---@class vector3
---@field x number
---@field y number
---@field z number
---@operator add(vector3): vector3
---@operator mul(number): vector3
---@operator sub(vector3): vector3
---@operator unm: vector3

---@class vector4
---@field w number
---@field x number
---@field y number
---@field z number
---@operator add(vector4): vector4
---@operator mul(number): vector4
---@operator sub(vector4): vector4
---@operator unm: vector4

---@class zip
zip = {}

---@class zip.METHOD
zip.METHOD = {}

---@class zip.ON_CONFLICT
zip.ON_CONFLICT = {}

---@alias array table
---@alias b2Body userdata
---@alias b2BodyType number
---@alias b2World userdata
---@alias bool boolean
---@alias buffer_data userdata
---@alias buffer_stream userdata
---@alias constant number
---@alias constant_buffer userdata
---@alias editor.command userdata
---@alias editor.component userdata
---@alias editor.schema userdata
---@alias editor.tiles userdata
---@alias editor.transaction_step userdata
---@alias float number
---@alias hash userdata
---@alias http.response userdata
---@alias http.route userdata
---@alias node userdata
---@alias quaternion vector4
---@alias render_predicate userdata
---@alias render_target string|userdata
---@alias resource_data userdata
---@alias socket_client userdata
---@alias socket_master userdata
---@alias socket_unconnected userdata
---@alias vector userdata