--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.10.4

  Editor scripting documentation
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.editor
editor = {}

---Error message the signifies bundle abort that is not an error
editor.bundle.abort_message = nil

---prefs schema for common bundle variants
editor.bundle.common_variant_schema = nil

---prefs schema for desktop bundle variants
editor.bundle.desktop_variant_schema = nil

---A string, SHA1 of Defold editor
editor.editor_sha1 = nil

---A string, SHA1 of Defold engine
editor.engine_sha1 = nil

---Editor platform id.
---A `string`, either:
---- `"x86_64-win32"`
---- `"x86_64-macos"`
---- `"arm64-macos"`
---- `"x86_64-linux"`
editor.platform = nil

---`"global"`
editor.prefs.SCOPE.GLOBAL = nil

---`"project"`
editor.prefs.SCOPE.PROJECT = nil

---`"bottom"`
editor.ui.ALIGNMENT.BOTTOM = nil

---`"bottom-left"`
editor.ui.ALIGNMENT.BOTTOM_LEFT = nil

---`"bottom-right"`
editor.ui.ALIGNMENT.BOTTOM_RIGHT = nil

---`"center"`
editor.ui.ALIGNMENT.CENTER = nil

---`"left"`
editor.ui.ALIGNMENT.LEFT = nil

---`"right"`
editor.ui.ALIGNMENT.RIGHT = nil

---`"top"`
editor.ui.ALIGNMENT.TOP = nil

---`"top-left"`
editor.ui.ALIGNMENT.TOP_LEFT = nil

---`"top-right"`
editor.ui.ALIGNMENT.TOP_RIGHT = nil

---`"error"`
editor.ui.COLOR.ERROR = nil

---`"hint"`
editor.ui.COLOR.HINT = nil

---`"override"`
editor.ui.COLOR.OVERRIDE = nil

---`"text"`
editor.ui.COLOR.TEXT = nil

---`"warning"`
editor.ui.COLOR.WARNING = nil

---`"dialog"`
editor.ui.HEADING_STYLE.DIALOG = nil

---`"form"`
editor.ui.HEADING_STYLE.FORM = nil

---`"h1"`
editor.ui.HEADING_STYLE.H1 = nil

---`"h2"`
editor.ui.HEADING_STYLE.H2 = nil

---`"h3"`
editor.ui.HEADING_STYLE.H3 = nil

---`"h4"`
editor.ui.HEADING_STYLE.H4 = nil

---`"h5"`
editor.ui.HEADING_STYLE.H5 = nil

---`"h6"`
editor.ui.HEADING_STYLE.H6 = nil

---`"clear"`
editor.ui.ICON.CLEAR = nil

---`"minus"`
editor.ui.ICON.MINUS = nil

---`"open-resource"`
editor.ui.ICON.OPEN_RESOURCE = nil

---`"plus"`
editor.ui.ICON.PLUS = nil

---`"error"`
editor.ui.ISSUE_SEVERITY.ERROR = nil

---`"warning"`
editor.ui.ISSUE_SEVERITY.WARNING = nil

---`"horizontal"`
editor.ui.ORIENTATION.HORIZONTAL = nil

---`"vertical"`
editor.ui.ORIENTATION.VERTICAL = nil

---`"large"`
editor.ui.PADDING.LARGE = nil

---`"medium"`
editor.ui.PADDING.MEDIUM = nil

---`"none"`
editor.ui.PADDING.NONE = nil

---`"small"`
editor.ui.PADDING.SMALL = nil

---`"large"`
editor.ui.SPACING.LARGE = nil

---`"medium"`
editor.ui.SPACING.MEDIUM = nil

---`"none"`
editor.ui.SPACING.NONE = nil

---`"small"`
editor.ui.SPACING.SMALL = nil

---`"center"`
editor.ui.TEXT_ALIGNMENT.CENTER = nil

---`"justify"`
editor.ui.TEXT_ALIGNMENT.JUSTIFY = nil

---`"left"`
editor.ui.TEXT_ALIGNMENT.LEFT = nil

---`"right"`
editor.ui.TEXT_ALIGNMENT.RIGHT = nil

---A string, version name of Defold
editor.version = nil

---Editor's HTTP server local url
http.server.local_url = nil

---Editor's HTTP server port
http.server.port = nil

---Editor's HTTP server url
http.server.url = nil

---`"deflated"` compression method
zip.METHOD.DEFLATED = nil

---`"stored"` compression method, i.e. no compression
zip.METHOD.STORED = nil

---Run bob the builder program
---For the full documentation of the available commands and options, see the bob manual.
---@param options? table table of command line options for bob, without the leading dashes (`--`). You can use snake_case instead of kebab-case for option keys. Only long option names are supported (i.e. `output`, not `o`). Supported value types are strings, integers and booleans. If an option takes no arguments, use a boolean (i.e. `true`). If an option may be repeated, you can use an array of values.
---@param ...? string bob commands, e.g. `"resolve"` or `"build"`
function editor.bob(options, ...) end

---Open a URL in the default browser or a registered application
---@param url string http(s) or file URL
function editor.browse(url) end

---Immutably set a key to value in a table
---@param table table the table
---@param key any the key
---@param value any the value
---@return table table New table if it should be changed by assoc, or the input table otherwise
function editor.bundle.assoc(table, key, value) end

---Immutably set a value to a nested path in a table
---@param table table the table
---@param keys any[] ] the keys
---@param value any the value
---@return table table New table if it should be changed by assoc_in, or the input table otherwise
function editor.bundle.assoc_in(table, keys, value) end

---Helper function for creating a check box component
---@param config table config table
---@param set_config function config setter
---@param key string config key for the selected value
---@param text string check box label text
---@param rest_props? table extra props for `editor.ui.check_box`
---@return editor.component check_box UI component
function editor.bundle.check_box(config, set_config, key, text, rest_props) end

---Create a grid row for the common boolean settings
---@param config table config map with common boolean keys
---@param set_config function config setter
---@return editor.component[] row ] grid row
function editor.bundle.check_boxes_grid_row(config, set_config) end

---Create bundle command definition
---@param label string Command label, as presented in the UI
---@param id string Command id, e.g. `"bundle-my-platform"`, used for re-bundling
---@param fn function bundle function, will receive a `requested_dialog` boolean argument
---@param rest? table extra keys for the command definition, e.g. `active`
function editor.bundle.command(label, id, fn, rest) end

---Create a grid row for the common variant setting
---@param config table config map with `variant` key
---@param set_config function config setter
---@return editor.component[] row ] grid row
function editor.bundle.common_variant_grid_row(config, set_config) end

---Get bundle config, optionally showing a dialog to edit the config
---@param requested_dialog boolean whether the user explicitly requested a dialog
---@param prefs_key string preference key used for loading the bundle config
---@param dialog_component editor.component UI component for the dialog, will receive `config` and (optional) `errors` props
---@param errors_fn? function error checking predicate, takes config as an argument; if returns truthy value, it will be passed as a prop to `dialog_component`
---@return any config 
function editor.bundle.config(requested_dialog, prefs_key, dialog_component, errors_fn) end

---Helper function for constructing prefs schema for new bundle dialogs
---@param variant_schema editor.schema bundle variant schema
---@param properties? table|nil extra config properties
---@return editor.schema schema full bundle schema, defines a project-scoped object schema with the following keys:`variant`the provided variant schema`texture_compression string`either `enabled`, `disabled` or `editor``with_symbols boolean``build_report boolean``liveupdate boolean``contentless boolean`
function editor.bundle.config_schema(variant_schema, properties) end

---Create bob bundle
---@param config table bundle config
---@param output_directory string bundle output directory
---@param extra_bob_opts table extra bob opts, presumably produced from config
function editor.bundle.create(config, output_directory, extra_bob_opts) end

---Create a grid row for the desktop variant setting
---@param config table config table with `variant` key
---@param set_config function config setter
---@return editor.component[] row ] grid row
function editor.bundle.desktop_variant_grid_row(config, set_config) end

---Helper function for creating a bundle dialog component
---@param heading string dialog heading text
---@param config table config map with common boolean keys
---@param hint string|nil dialog hint text
---@param error string|nil dialog error text
---@param rows editor.component[] []] grid rows of UI elements, dialog content
---@return editor.component dialog UI component
function editor.bundle.dialog(heading, config, hint, error, rows) end

---Helper function for creating an external file field component
---@param config table config map with common boolean keys
---@param set_config function config setter
---@param key string config key for the set
---@param error? string error message
---@param rest_props? table extra props for `editor.ui.external_file_field`
---@return editor.component external_file_field UI component
function editor.bundle.external_file_field(config, set_config, key, error, rest_props) end

---Return a 2-element array that represents a single grid row in a bundle dialog
---@param text string|nil optional string label
---@param content editor.component|editor.component[] ] either a single UI component, or an array of components (will be laid out vertically)
---@return editor.component[] row ] a single grid row
function editor.bundle.grid_row(text, content) end

---Make stringifier function that first performs the label lookup in a provided table
---@param table table table from values to their corresponding string representation
---@return function to_string stringifier function
function editor.bundle.make_to_string_lookup(table) end

---Get bundle output directory, optionally showing a directory selection dialog
---@param requested_dialog boolean whether the user explicitly requested a dialog
---@param output_subdir string output subdir, usually a platform name
function editor.bundle.output_directory(requested_dialog, output_subdir) end

---Helper function for creating a select box component
---@param config table config table
---@param set_config function config setter
---@param key string config key for the selected value
---@param options any[] ] select box options
---@param to_string function option stringifier
---@param rest_props? table extra props for `editor.ui.select_box`
---@return editor.component select_box UI component
function editor.bundle.select_box(config, set_config, key, options, to_string, rest_props) end

---Helper function for creating a check box for an enum value of set config key
---@param config table config map with common boolean keys
---@param set_config function config setter
---@param key string config key for the set
---@param element string enum value in the set
---@param text string check box label text
---@param error? string error message
---@return editor.component check_box UI component
function editor.bundle.set_element_check_box(config, set_config, key, element, text, error) end

---Create a grid row for the texture compression setting
---@param config table config map with `texture_compression` key
---@param set_config function config setter
---@return editor.component[] row ] grid row
function editor.bundle.texture_compression_grid_row(config, set_config) end

---Check if `editor.tx.add()` (as well as `editor.tx.clear()` and `editor.tx.remove()`) transaction with this property won't throw an error
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return boolean value 
function editor.can_add(node, property) end

---Check if you can get this property so `editor.get()` won't throw an error
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return boolean value 
function editor.can_get(node, property) end

---Check if `editor.tx.reorder()` transaction with this property won't throw an error
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return boolean value 
function editor.can_reorder(node, property) end

---Check if `editor.tx.reset()` transaction with this property won't throw an error
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return boolean value 
function editor.can_reset(node, property) end

---Check if `editor.tx.set()` transaction with this property won't throw an error
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return boolean value 
function editor.can_set(node, property) end

---Create an editor command
---@param opts table A table with the following keys:`label string`required, user-visible command name`locations string[]`required, a non-empty list of locations where the command is displayed in the editor, values are either `"Edit"`, `"View"`, `"Project"`, `"Debug"` (the editor menubar), `"Assets"` (the assets pane), or `"Outline"` (the outline pane)`query table`optional, a query that both controls the command availability and provides additional information to the command handler functions; a table with the following keys:`selection table`current selection, a table with the following keys:`type string`either `"resource"` (selected resource) or `"outline"` (selected outline node)`cardinality string`either `"one"` (will use first selected item) or `"many"` (will use all selected items)`argument table`the command argument`id string`optional, keyword identifier that may be used for assigning a shortcut to a command; should be a dot-separated identifier string, e.g. `"my-extension.do-stuff"``active function`optional function that additionally checks if a command is active in the current context; will receive opts table with values populated by the query; should be fast to execute since the editor might invoke it in response to UI interactions (on key typed, mouse clicked)`run function`optional function that is invoked when the user decides to execute the command; will receive opts table with values populated by the query
---@return editor.command command 
function editor.command(opts) end

---Create a directory if it does not exist, and all non-existent parent directories.
---Throws an error if the directory can't be created.
---@param resource_path string Resource path (starting with `/`)
function editor.create_directory(resource_path) end

---Create resources (including non-existent parent directories).
---Throws an error if any of the provided resource paths already exist
---@param resources string[] ] Array of resource paths (strings starting with `/`) or resource definitions, lua tables with the following keys:`1 string`required, resource path (starting with `/`)`2 string`optional, created resource content
function editor.create_resources(resources) end

---Delete a directory if it exists, and all existent child directories and files.
---Throws an error if the directory can't be deleted.
---@param resource_path string Resource path (starting with `/`)
function editor.delete_directory(resource_path) end

---Execute a shell command.
---Any shell command arguments should be provided as separate argument strings to this function. If the exit code of the process is not zero, this function throws error. By default, the function returns `nil`, but it can be configured to capture the output of the shell command as string and return it — set `out` option to `"capture"` to do it.By default, after this shell command is executed, the editor will reload resources from disk.
---@param command string Shell command name to execute
---@param ...? string Optional shell command arguments
---@param options? { reload_resources?:boolean, out?:string, err?:string } Optional options table. Supported entries:                                                                                                                                          boolean `reload_resources`: make the editor reload the resources from disk after the command is executed, default `true`                                                                                                                                            string `out`: standard output mode, either:                                                                                                                                                      `"pipe"`: the output is piped to the editor console (this is the default behavior).                                                                                                                                                        `"capture"`: capture and return the output to the editor script with trailing newlines trimmed.                                                                                                                                                        `"discard"`: the output is discarded completely.                                                                                                                                                                                                                                              string `err`: standard error output mode, either:                                                                                                                                                      `"pipe"`: the error output is piped to the editor console (this is the default behavior).                                                                                                                                                        `"stdout"`: the error output is redirected to the standard output of the process.                                                                                                                                                        `"discard"`: the error output is discarded completely.                                                                                                                                                                                            
---@return nil|string result If `out` option is set to `"capture"`, returns the output as string with trimmed trailing newlines. Otherwise, returns `nil`.
function editor.execute(command, ..., options) end

---Query information about file system path
---@param path string External file path, resolved against project root if relative
---@return { path:string, exists:boolean, is_file:boolean, is_directory:boolean } attributes A table with the following keys:                                                  `path string`                                                  resolved file path                                                  `exists boolean`                                                  whether there is a file system entry at the path                                                  `is_file boolean`                                                  whether the path corresponds to a file                                                  `is_directory boolean`                                                  whether the path corresponds to a directory                                                
function editor.external_file_attributes(path) end

---Get a value of a node property inside the editor.
---Some properties might be read-only, and some might be unavailable in different contexts, so you should use `editor.can_get()` before reading them and `editor.can_set()` before making the editor set them.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return any value property value
function editor.get(node, property) end

---Open a file in a registered application
---@param path string file path
function editor.open_external_file(path) end

---Get preference value
---The schema for the preference value should be defined beforehand.
---@param key string dot-separated preference key path
---@return any value current pref value or default if a schema for the key path exists, nil otherwise
function editor.prefs.get(key) end

---Check if preference value is explicitly set
---The schema for the preference value should be defined beforehand.
---@param key string dot-separated preference key path
---@return boolean value flag indicating if the value is explicitly set
function editor.prefs.is_set(key) end

---array schema
---@param opts { item:editor.schema, default?:any[], scope?:string } Required opts: `item schema`array item schema  Optional opts: `default item[]`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.array(opts) end

---boolean schema
---@param opts? { default?:boolean, scope?:string } Optional opts: `default boolean`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.boolean(opts) end

---enum value schema
---@param opts { values:(nil|boolean|number|string)[], default?:any, scope?:string } Required opts: `values any[]`allowed values, must be scalar (nil, boolean, number or string)  Optional opts: `default any`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.enum(opts) end

---integer schema
---@param opts? { default?:integer, scope?:string } Optional opts: `default integer`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.integer(opts) end

---keyword schema
---A keyword is a short string that is interned within the editor runtime, useful e.g. for identifiers
---@param opts? { default?:string, scope?:string } Optional opts: `default string`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.keyword(opts) end

---floating-point number schema
---@param opts? { default?:number, scope?:string } Optional opts: `default number`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.number(opts) end

---heterogeneous object schema
---@param opts { properties:table<string, editor.schema>, default?:table<string, editor.schema>, scope?:string } Required opts: `properties table<string, schema>`a table from property key (string) to value schema  Optional opts: `default table`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.object(opts) end

---homogeneous object schema
---@param opts { key:editor.schema, val:editor.schema, default?:table, scope?:string } Required opts: `key schema`table key schema`val schema`table value schema  Optional opts: `default table`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.object_of(opts) end

---password schema
---A password is a string that is encrypted when stored in a preference file
---@param opts? table Optional opts: `default string`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.password(opts) end

---set schema
---Set is represented as a lua table with `true` values
---@param opts { item:editor.schema, default?:table<editor.schema, boolean>, scope?:string } Required opts: `item schema`set item schema  Optional opts: `default table<item, true>`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.set(opts) end

---string schema
---@param opts? { default?:string, scope?:string } Optional opts: `default string`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.string(opts) end

---tuple schema
---A tuple is a fixed-length array where each item has its own defined type
---@param opts { items:editor.schema[], default?:any[], scope?:string } Required opts: `items schema[]`schemas for the items  Optional opts: `default any[]`default value`scope string`preference scope; either: `editor.prefs.SCOPE.GLOBAL`: same preference value is used in every project on this computer`editor.prefs.SCOPE.PROJECT`: a separate preference value per project
---@return editor.schema value Prefs schema
function editor.prefs.schema.tuple(opts) end

---Set preference value
---The schema for the preference value should be defined beforehand.
---@param key string dot-separated preference key path
---@param value any new pref value to set
function editor.prefs.set(key, value) end

---Query information about a project resource
---@param resource_path string Resource path (starting with `/`)
---@return { exists:boolean, is_file:boolean, is_directory:boolean } value A table with the following keys:`exists boolean`whether a resource identified by the path exists in the project`is_file boolean`whether the resource represents a file with some content`is_directory boolean`whether the resource represents a directory
function editor.resource_attributes(resource_path) end

---Persist any unsaved changes to disk
function editor.save() end

---Change the editor state in a single, undoable transaction
---@param txs editor.transaction_step[] ] An array of transaction steps created using `editor.tx.*` functions
function editor.transact(txs) end

---Create a transaction step that will add a child item to a node's list property when transacted with `editor.transact()`.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@param value any Added item for the property, a table from property key to either a valid `editor.tx.set()`-able value, or an array of valid `editor.tx.add()`-able values
function editor.tx.add(node, property, value) end

---Create a transaction step that will remove all items from node's list property when transacted with `editor.transact()`.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return editor.transaction_step tx A transaction step
function editor.tx.clear(node, property) end

---Create a transaction step that will remove a child node from the node's list property when transacted with `editor.transact()`.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@param child_node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@return editor.transaction_step tx A transaction step
function editor.tx.remove(node, property, child_node) end

---Create a transaction step that reorders child nodes in a node list defined by the property if supported (see `editor.can_reorder()`)
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@param child_nodes table array of child nodes (the same as returned by `editor.get(node, property)`) in new order
---@return editor.transaction_step tx A transaction step
function editor.tx.reorder(node, property, child_nodes) end

---Create a transaction step that will reset an overridden property to its default value when transacted with `editor.transact()`.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@return editor.transaction_step tx A transaction step
function editor.tx.reset(node, property) end

---Create transaction step that will set the node's property to a supplied value when transacted with `editor.transact()`.
---@param node string|userdata Either resource path (e.g. `"/main/game.script"`), or internal node id passed to the script by the editor
---@param property string Either `"path"`, `"text"`, or a property from the Outline view (hover the label to see its editor script name)
---@param value any A new value for the property
---@return editor.transaction_step tx A transaction step
function editor.tx.set(node, property, value) end

---Button with a label and/or an icon
---@param props table Optional props: `on_pressed function`button press callback, will be invoked without arguments when the user presses the button`text string`the text`text_alignment string`text alignment within paragraph bounds; either: `editor.ui.TEXT_ALIGNMENT.LEFT``editor.ui.TEXT_ALIGNMENT.CENTER``editor.ui.TEXT_ALIGNMENT.RIGHT``editor.ui.TEXT_ALIGNMENT.JUSTIFY``icon string`predefined icon name; either: `editor.ui.ICON.OPEN_RESOURCE``editor.ui.ICON.PLUS``editor.ui.ICON.MINUS``editor.ui.ICON.CLEAR``enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.button(props) end

---Check box with a label
---@param props table Optional props: `value boolean`determines if the checkbox should appear checked`on_value_changed function`change callback, will receive the new value`text string`the text`text_alignment string`text alignment within paragraph bounds; either: `editor.ui.TEXT_ALIGNMENT.LEFT``editor.ui.TEXT_ALIGNMENT.CENTER``editor.ui.TEXT_ALIGNMENT.RIGHT``editor.ui.TEXT_ALIGNMENT.JUSTIFY``issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.check_box(props) end

---Convert a function to a UI component.
---The wrapped function may call any hooks functions (`editor.ui.use_*`), but on any function invocation, the hooks calls must be the same, and in the same order. This means that hooks should not be used inside loops and conditions or after a conditional return statement.
---The following props are supported automatically:`grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@param fn function function, will receive a single table of props when called
---@return function value decorated component function that may be invoked with a props table create component
function editor.ui.component(fn) end

---Dialog component, a top-level window component that can't be used as a child of other components
---@param props table Required props: `title string`OS dialog window title  Optional props: `header component`top part of the dialog, defaults to `editor.ui.heading({text = props.title})``content component`content of the dialog`buttons component[]`array of `editor.ui.dialog_button(...)` components, footer of the dialog. Defaults to a single Close button
---@return editor.component value UI component
function editor.ui.dialog(props) end

---Dialog button shown in the footer of a dialog
---@param props table Required props: `text string`button text  Optional props: `result any`value returned by `editor.ui.show_dialog(...)` if this button is pressed`default boolean`if set, pressing `Enter` in the dialog will trigger this button`cancel boolean`if set, pressing `Escape` in the dialog will trigger this button`enabled boolean`determines if the button can be interacted with
---@return editor.component value UI component
function editor.ui.dialog_button(props) end

---Input component for selecting files from the file system
---@param props table Optional props: `value string`file or directory path; resolved against project root if relative`on_value_changed function`value change callback, will receive the absolute path of a selected file/folder or nil if the field was cleared; even though the selector dialog allows selecting only files, it's possible to receive directories and non-existent file system entries using text field input`title string`OS window title`filters table[]`File filters, an array of filter tables, where each filter has following keys:`description string`string explaining the filter, e.g. `"Text files (*.txt)"``extensions string[]`array of file extension patterns, e.g. `"*.txt"`, `"*.*"` or `"game.project"``issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.external_file_field(props) end

---Layout container that places its children in a 2D grid
---@param props table Optional props: `children component[][]`array of arrays of child components`rows table[]`array of row option tables, separate configuration for each row:`grow boolean`determines if the row should grow to fill available space`columns table[]`array of column option tables, separate configuration for each column:`grow boolean`determines if the column should grow to fill available space`padding string, number`empty space from the edges of the container to its children; either: `editor.ui.PADDING.NONE``editor.ui.PADDING.SMALL``editor.ui.PADDING.MEDIUM``editor.ui.PADDING.LARGE`non-negative number, pixels`spacing string, number`empty space between child components, defaults to `editor.ui.SPACING.MEDIUM`; either: `editor.ui.SPACING.NONE``editor.ui.SPACING.SMALL``editor.ui.SPACING.MEDIUM``editor.ui.SPACING.LARGE`non-negative number, pixels`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.grid(props) end

---A text heading
---@param props table Optional props: `text string`the text`text_alignment string`text alignment within paragraph bounds; either: `editor.ui.TEXT_ALIGNMENT.LEFT``editor.ui.TEXT_ALIGNMENT.CENTER``editor.ui.TEXT_ALIGNMENT.RIGHT``editor.ui.TEXT_ALIGNMENT.JUSTIFY``color string`semantic color, defaults to `editor.ui.COLOR.TEXT`; either: `editor.ui.COLOR.TEXT``editor.ui.COLOR.HINT``editor.ui.COLOR.OVERRIDE``editor.ui.COLOR.WARNING``editor.ui.COLOR.ERROR``word_wrap boolean`determines if the lines of text are word-wrapped when they don't fit in the assigned bounds, defaults to true`style string`heading style, defaults to `editor.ui.HEADING_STYLE.H3`; either: `editor.ui.HEADING_STYLE.H1``editor.ui.HEADING_STYLE.H2``editor.ui.HEADING_STYLE.H3``editor.ui.HEADING_STYLE.H4``editor.ui.HEADING_STYLE.H5``editor.ui.HEADING_STYLE.H6``editor.ui.HEADING_STYLE.DIALOG``editor.ui.HEADING_STYLE.FORM``alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.heading(props) end

---Layout container that places its children in a horizontal row one after another
---@param props table Optional props: `children component[]`array of child components`padding string, number`empty space from the edges of the container to its children; either: `editor.ui.PADDING.NONE``editor.ui.PADDING.SMALL``editor.ui.PADDING.MEDIUM``editor.ui.PADDING.LARGE`non-negative number, pixels`spacing string, number`empty space between child components, defaults to `editor.ui.SPACING.MEDIUM`; either: `editor.ui.SPACING.NONE``editor.ui.SPACING.SMALL``editor.ui.SPACING.MEDIUM``editor.ui.SPACING.LARGE`non-negative number, pixels`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.horizontal(props) end

---An icon from a predefined set
---@param props table Required props: `icon string`predefined icon name; either: `editor.ui.ICON.OPEN_RESOURCE``editor.ui.ICON.PLUS``editor.ui.ICON.MINUS``editor.ui.ICON.CLEAR`  Optional props: `alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.icon(props) end

---Integer input component based on a text field, reports changes on commit (`Enter` or focus loss)
---@param props table Optional props: `value any`value`on_value_changed function`value change callback, will receive the new value`issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.integer_field(props) end

---Label intended for use with input components
---@param props table Optional props: `text string`the text`text_alignment string`text alignment within paragraph bounds; either: `editor.ui.TEXT_ALIGNMENT.LEFT``editor.ui.TEXT_ALIGNMENT.CENTER``editor.ui.TEXT_ALIGNMENT.RIGHT``editor.ui.TEXT_ALIGNMENT.JUSTIFY``color string`semantic color, defaults to `editor.ui.COLOR.TEXT`; either: `editor.ui.COLOR.TEXT``editor.ui.COLOR.HINT``editor.ui.COLOR.OVERRIDE``editor.ui.COLOR.WARNING``editor.ui.COLOR.ERROR``tooltip string`tooltip message, shown on hover`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.label(props) end

---Number input component based on a text field, reports changes on commit (`Enter` or focus loss)
---@param props table Optional props: `value any`value`on_value_changed function`value change callback, will receive the new value`issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.number_field(props) end

---Open a resource, either in the editor or in a third-party app
---@param resource_path string Resource path (starting with `/`)
function editor.ui.open_resource(resource_path) end

---A paragraph of text
---@param props table Optional props: `text string`the text`text_alignment string`text alignment within paragraph bounds; either: `editor.ui.TEXT_ALIGNMENT.LEFT``editor.ui.TEXT_ALIGNMENT.CENTER``editor.ui.TEXT_ALIGNMENT.RIGHT``editor.ui.TEXT_ALIGNMENT.JUSTIFY``color string`semantic color, defaults to `editor.ui.COLOR.TEXT`; either: `editor.ui.COLOR.TEXT``editor.ui.COLOR.HINT``editor.ui.COLOR.OVERRIDE``editor.ui.COLOR.WARNING``editor.ui.COLOR.ERROR``word_wrap boolean`determines if the lines of text are word-wrapped when they don't fit in the assigned bounds, defaults to true`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.paragraph(props) end

---Input component for selecting project resources
---@param props table Optional props: `value string`resource path (must start with `/`)`on_value_changed function`value change callback, will receive either resource path of a selected resource or nil when the field is cleared; even though the resource selector dialog allows filtering on resource extensions, it's possible to receive resources with other extensions and non-existent resources using text field input`title string`dialog title, defaults to `"Select Resource"``extensions string[]`if specified, restricts selectable resources in the dialog to specified file extensions; e.g. `{"collection", "go"}``issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.resource_field(props) end

---Layout container that optionally shows scroll bars if child contents overflow the assigned bounds
---@param props table Required props: `content component`content component  Optional props: `grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.scroll(props) end

---Dropdown select box with an array of options
---@param props table Optional props: `value any`selected value`on_value_changed function`change callback, will receive the selected value`options any[]`array of selectable options`to_string function`function that converts an item to a string, defaults to `tostring``issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.select_box(props) end

---Thin line for visual content separation, by default horizontal and aligned to center
---@param props table Optional props: `orientation string`separator line orientation, `editor.ui.ORIENTATION.VERTICAL` or `editor.ui.ORIENTATION.HORIZONTAL`; either: `editor.ui.ORIENTATION.VERTICAL``editor.ui.ORIENTATION.HORIZONTAL``alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.separator(props) end

---Show a modal dialog and await a result
---@param dialog editor.component a component that resolves to `editor.ui.dialog(...)`
---@return any value dialog result, the value used as a `result` prop in a `editor.ui.dialog_button({...})` selected by the user, or `nil` if the dialog was closed and there was no `cancel = true` dialog button with `result` prop set
function editor.ui.show_dialog(dialog) end

---Show a modal OS directory selection dialog and await a result
---@param opts? table `path string`initial file or directory path used by the dialog; resolved against project root if relative`title string`OS window title
---@return string|nil value either absolute directory path or nil if user canceled directory selection
function editor.ui.show_external_directory_dialog(opts) end

---Show a modal OS file selection dialog and await a result
---@param opts? table `path string`initial file or directory path used by the dialog; resolved against project root if relative`title string`OS window title`filters table[]`File filters, an array of filter tables, where each filter has following keys:`description string`string explaining the filter, e.g. `"Text files (*.txt)"``extensions string[]`array of file extension patterns, e.g. `"*.txt"`, `"*.*"` or `"game.project"`
---@return string|nil value either absolute file path or nil if user canceled file selection
function editor.ui.show_external_file_dialog(opts) end

---Show a modal resource selection dialog and await a result
---@param opts? table `extensions string[]`if specified, restricts selectable resources in the dialog to specified file extensions; e.g. `{"collection", "go"}``selection string`either `"single"` or `"multiple"`, defaults to `"single"``title string`dialog title, defaults to `"Select Resource"`
---@return string|string[]|nil value |nil] if user made no selection, returns `nil`. Otherwise, if selection mode is `"single"`, returns selected resource path; otherwise returns a non-empty array of selected resource paths.
function editor.ui.show_resource_dialog(opts) end

---String input component based on a text field, reports changes on commit (`Enter` or focus loss)
---@param props table Optional props: `value any`value`on_value_changed function`value change callback, will receive the new value`issue table`issue related to the input; table with the following keys (all required):`severity string`either `editor.ui.ISSUE_SEVERITY.WARNING` or `editor.ui.ISSUE_SEVERITY.ERROR``message string`issue message, will be shown in a tooltip`tooltip string`tooltip message, shown on hover`enabled boolean`determines if the input component can be interacted with`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.string_field(props) end

---A hook that caches the result of a computation between re-renders.
---See `editor.ui.component` for hooks caveats and rules. If any of the arguments to `use_memo` change during a component refresh (checked with `==`), the value will be recomputed.
---@param compute function function that will be used to compute the cached value
---@param ...? any args to the computation function
---@return any ... values all returned values of the compute function
function editor.ui.use_memo(compute, ...) end

---A hook that adds local state to the component.
---See `editor.ui.component` for hooks caveats and rules. If any of the arguments to `use_state` change during a component refresh (checked with `==`), the current state will be reset to the initial one.
---@param init any|function local state initializer, either initial data structure or function that produces the data structure
---@param ...? any used when `init` is a function, the args are passed to the initializer function
---@return any state current local state, starts with initial state, then may be changed using the returned `set_state` function
---@return function set_state function that changes the local state and causes the component to refresh. The function may be used in 2 ways:                                                    to set the state to some other data structure: pass the data structure as a value                           to replace the state using updater function: pass a function to `set_state` — it will be invoked with the current state, as well as with the rest of the arguments passed to `set_state` after the updater function. The state will be set to the value returned from the updater function                         
function editor.ui.use_state(init, ...) end

---Layout container that places its children in a vertical column one after another
---@param props table Optional props: `children component[]`array of child components`padding string, number`empty space from the edges of the container to its children; either: `editor.ui.PADDING.NONE``editor.ui.PADDING.SMALL``editor.ui.PADDING.MEDIUM``editor.ui.PADDING.LARGE`non-negative number, pixels`spacing string, number`empty space between child components, defaults to `editor.ui.SPACING.MEDIUM`; either: `editor.ui.SPACING.NONE``editor.ui.SPACING.SMALL``editor.ui.SPACING.MEDIUM``editor.ui.SPACING.LARGE`non-negative number, pixels`alignment string`alignment of the component content within its assigned bounds, defaults to `editor.ui.ALIGNMENT.TOP_LEFT`; either: `editor.ui.ALIGNMENT.TOP_LEFT``editor.ui.ALIGNMENT.TOP``editor.ui.ALIGNMENT.TOP_RIGHT``editor.ui.ALIGNMENT.LEFT``editor.ui.ALIGNMENT.CENTER``editor.ui.ALIGNMENT.RIGHT``editor.ui.ALIGNMENT.BOTTOM_LEFT``editor.ui.ALIGNMENT.BOTTOM``editor.ui.ALIGNMENT.BOTTOM_RIGHT``grow boolean`determines if the component should grow to fill available space in a `horizontal` or `vertical` layout container`row_span integer`how many rows the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.`column_span integer`how many columns the component spans inside a grid container, must be positive. This prop is only useful for components inside a `grid` container.
---@return editor.component value UI component
function editor.ui.vertical(props) end

---Perform an HTTP request
---@param url string request URL
---@param opts? table Additional request options, a table with the following keys:`method string`request method, defaults to `"GET"``headers table`request headers, a table with string keys and values`body string`request body`as string`response body converter, either `"string"` or `"json"`
---@return table response HTTP response, a table with the following keys:`status integer`response code`headers table`response headers, a table where each key is a lower-cased string, and each value is either a string or an array of strings if the header was repeated`body string, any, nil`response body, present only when `as` option was provided, either a string or a parsed json value
function http.request(url, opts) end

---Create HTTP response that will stream the content of a file defined by the path
---@param path string External file path, resolved against project root if relative
---@param status? integer HTTP status code, an integer, default 200
---@param headers? table<string, string> HTTP response headers, a table from lower-case header names to header values
---@return http.response response HTTP response value, userdata
function http.server.external_file_response(path, status, headers) end

---Create HTTP response with a JSON value
---@param value any Any Lua value that may be represented as JSON
---@param status? integer HTTP status code, an integer, default 200
---@param headers? table<string, string> HTTP response headers, a table from lower-case header names to header values
---@return http.response response HTTP response value, userdata
function http.server.json_response(value, status, headers) end

---Create HTTP response that will stream the content of a resource defined by the resource path
---@param resource_path string Resource path (starting with `/`)
---@param status? integer HTTP status code, an integer, default 200
---@param headers? table<string, string> HTTP response headers, a table from lower-case header names to header values
---@return http.response response HTTP response value, userdata
function http.server.resource_response(resource_path, status, headers) end

---Create HTTP response
---@param status? integer HTTP status code, an integer, default 200
---@param headers? table<string, string> HTTP response headers, a table from lower-case header names to header values
---@param body? string HTTP response body
---@return http.response response HTTP response value, userdata
function http.server.response(status, headers, body) end

---Create route definition for the editor's HTTP server
---@param path string HTTP URI path, starts with `/`; may include path patterns (`{name}` for a single segment and `{*name}` for the rest of the request path) that will be extracted from the path and provided to the handler as a part of the request
---@param method? string HTTP request method, default `"GET"`
---@param as? string Request body converter, either `"string"` or `"json"`; the body will be discarded if not specified
---@param handler function Request handler function, will receive request argument, a table with the following keys:`path string`full matched path, a string starting with `/``method string`HTTP request method, e.g. `"POST"``headers table<string,(string|string[])>`HTTP request headers, a table from lower-case header names to header values`query string`optional query string`body string, any`optional request body, depends on the `as` argument Handler function should return either a single response value, or 0 or more arguments to the `http.server.response()` function
---@return http.route route HTTP server route
function http.server.route(path, method, as, handler) end

---Decode JSON string to Lua value
---@param json string json data
---@param options? { decode_null_as_userdata?:boolean } A table with the following keys:`all boolean`if `true`, decodes all json values in a string and returns an array
function json.decode(json, options) end

---Encode Lua value to JSON string
---@param value any any Lua value that may be represented as JSON
function json.encode(value) end

---Pretty-print a Lua value
---@param value any any Lua value to pretty-print
function pprint(value) end

---Remove all tiles
---@param tiles editor.tiles unbounded 2d grid of tiles
---@return editor.tiles tiles unbounded 2d grid of tiles
function tilemap.tiles.clear(tiles) end

---Get full information from a tile at a particular coordinate
---@param tiles editor.tiles unbounded 2d grid of tiles
---@param x integer x coordinate of a tile
---@param y integer y coordinate of a tile
---@return table info full tile information table with the following keys:`index integer`1-indexed tile index of a tilemap's tilesource`h_flip boolean`horizontal flip`v_flip boolean`vertical flip`rotate_90 boolean`whether the tile is rotated 90 degrees clockwise
function tilemap.tiles.get_info(tiles, x, y) end

---Get a tile index at a particular coordinate
---@param tiles editor.tiles unbounded 2d grid of tiles
---@param x integer x coordinate of a tile
---@param y integer y coordinate of a tile
---@return integer tile_index 1-indexed tile index of a tilemap's tilesource
function tilemap.tiles.get_tile(tiles, x, y) end

---Create an iterator over all tiles in a tiles data structure
---When iterating using for loop, each iteration returns x, y and tile index of a tile in a tile map
---@param tiles editor.tiles unbounded 2d grid of tiles
---@return function iter iterator
function tilemap.tiles.iterator(tiles) end

---Create a new unbounded 2d grid data structure for storing tilemap layer tiles
---@return editor.tiles tiles unbounded 2d grid of tiles
function tilemap.tiles.new() end

---Remove a tile at a particular coordinate
---@param tiles editor.tiles unbounded 2d grid of tiles
---@param x integer x coordinate of a tile
---@param y integer y coordinate of a tile
---@return editor.tiles tiles unbounded 2d grid of tiles
function tilemap.tiles.remove(tiles, x, y) end

---Set a tile at a particular coordinate
---@param tiles editor.tiles unbounded 2d grid of tiles
---@param x integer x coordinate of a tile
---@param y integer y coordinate of a tile
---@param tile_or_info integer|table Either 1-indexed tile index of a tilemap's tilesource or full tile information table with the following keys:`index integer`1-indexed tile index of a tilemap's tilesource`h_flip boolean`horizontal flip`v_flip boolean`vertical flip`rotate_90 boolean`whether the tile is rotated 90 degrees clockwise
---@return editor.tiles tiles unbounded 2d grid of tiles
function tilemap.tiles.set(tiles, x, y, tile_or_info) end

---Create a ZIP archive
---@param output_path string output zip file path, resolved against project root if relative
---@param opts? { method?:string, level?:integer } compression options, a table with the following keys:`method string`compression method, either `zip.METHOD.DEFLATED` (default) or `zip.METHOD.STORED``level integer`compression level, an integer between 0 and 9, only useful when the compression method is `zip.METHOD.DEFLATED`; defaults to 6
---@param entries string|table entries to compress, either a string (relative path to file or folder to include) or a table with the following keys:`1 string`required; source file or folder path to include, resolved against project root if relative`2 string`optional; target file or folder path in the zip archive. May be omitted if source is a relative path that does not go above the project directory.`method string`compression method, either `zip.METHOD.DEFLATED` (default) or `zip.METHOD.STORED``level integer`compression level, an integer between 0 and 9, only useful when the compression method is `zip.METHOD.DEFLATED`; defaults to 6
function zip.pack(output_path, opts, entries) end

return editor