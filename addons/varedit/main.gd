@tool
extends Panel
class_name VarEditMainPanel

@onready var top_bar: HBoxContainer = get_node("%TopBar")
@onready var tab_bar: TabBar = get_node("%TabBar")
@onready var view_option_button: OptionButton = get_node("%ViewOptionButton")
@onready var tree_container: VBoxContainer = get_node("%TreeContainer")
@onready var tree: Tree = get_node("%Tree")
@onready var tree_path_filter_mode: OptionButton = get_node("%TreePathMode")
@onready var tree_path_filter: LineEdit = get_node("%TreePathFilter")
@onready var code_edit: CodeEdit = get_node("%CodeEdit")
@onready var welcome: Control = get_node("%Welcome")
@onready var title_container: VBoxContainer = get_node("%TitleContainer")
@onready var title: Label = get_node("%Title")
@onready var version_label: Label = get_node("%VersionLabel")
@onready var open_button: Button = get_node("%OpenButton")
@onready var open_user_button: Button = get_node("%OpenUser")
@onready var open_github_button: Button = get_node("%OpenGithub")
@onready var reload_check_button: CheckButton = get_node("%ReloadCheckButton")
@onready var error_dialog: AcceptDialog = get_node("%ErrorDialog")
@onready var new_tab_button: Button = get_node("%NewTabButton")
@onready var recent_scroll_container: ScrollContainer = get_node("%RecentScrollContainer")
@onready var recent_list: ItemList = get_node("%RecentList")
@onready var welcome_split: HBoxContainer = get_node("%WelcomeSplit")

var open_files = []

var types = {
	TYPE_NIL: "Nil",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_RECT2: "Rect2",
	TYPE_RECT2I: "Rect2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_TRANSFORM2D: "Transform2D",
	TYPE_VECTOR4: "Vector4",
	TYPE_VECTOR4I: "Vector4i",
	TYPE_PLANE: "Plane",
	TYPE_QUATERNION: "Quaternion",
	TYPE_AABB: "AABB",
	TYPE_BASIS: "Basis",
	TYPE_TRANSFORM3D: "Transform3D",
	TYPE_PROJECTION: "Projection",
	TYPE_COLOR: "Color",
	TYPE_STRING_NAME: "StringName",
	TYPE_NODE_PATH: "NodePath",
	TYPE_RID: "RID",
	TYPE_OBJECT: "Object",
	TYPE_CALLABLE: "Callable",
	TYPE_SIGNAL: "Signal",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_ARRAY: "Array",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
}

var type_icons = {}
var file_icon
var compressed_icon

var _version = ""
func set_version(version: String):
	_version = version
	if version_label != null:
		version_label.text = version

var is_inside_plugin = false

func _ready():

	if !is_inside_plugin:
		return

	var main_control = get_parent().get_parent()

	for type in types:
		var name = types[type]
		type_icons[type] = main_control.get_theme_icon(name, "EditorIcons")

	view_option_button.set_item_icon(0, main_control.get_theme_icon("Tree", "EditorIcons"))
	view_option_button.set_item_icon(1, main_control.get_theme_icon("Script", "EditorIcons"))
	new_tab_button.icon = main_control.get_theme_icon("Add", "EditorIcons")
	open_button.icon = main_control.get_theme_icon("File", "EditorIcons")
	open_user_button.icon = main_control.get_theme_icon("Folder", "EditorIcons")
	file_icon = main_control.get_theme_icon("Object", "EditorIcons")
	compressed_icon = main_control.get_theme_icon("ResourcePreloader", "EditorIcons")

	var dpi = DisplayServer.screen_get_dpi()
	var scale = 1;
	if dpi >= 192:
		scale = 2 # around 200%

	# scale some elements that are dpi dependent
	title_container.remove_theme_constant_override("separation")
	title_container.add_theme_constant_override("separation", -16 * scale)
	title.label_settings.font_size = 48 * scale
	version_label.label_settings.font_size = 16 * scale
	recent_scroll_container.custom_minimum_size = Vector2(256, 240) * scale
	welcome_split.remove_theme_constant_override("separation")
	welcome_split.add_theme_constant_override("separation", 40 * scale)

	tab_bar.connect("tab_changed", Callable(self, "select_file"))
	tab_bar.connect("tab_close_pressed", Callable(self, "close_file"))
	tree_path_filter_mode.connect("item_selected", Callable(self, "filter_mode_changed"))
	tree_path_filter.connect("text_changed", Callable(self, "filter_changed"))

	recent_list.connect("item_activated", Callable(self, "_on_recent_activated"))

	tab_bar.clear_tabs()
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY

	tree.set_column_title(0, "Key")
	tree.set_column_clip_content(0, true)
	tree.set_column_title(1, "Value")
	tree.set_column_expand(1, true)
	tree.column_titles_visible = true

	tree.connect("item_activated", Callable(self, "tree_item_activated"))
	open_button.connect("pressed", Callable(self, "_on_open_clicked"))
	open_user_button.connect("pressed", Callable(self, "_on_user_clicked"))
	open_github_button.connect("pressed", Callable(self, "_on_open_github_clicked"))
	new_tab_button.connect("pressed", Callable(self, "_on_new_tab_clicked"))

	load_recent_list()

	top_bar.visible = false
	welcome.visible = true

	error_dialog.visible = false

	open_dialog = FileDialog.new()
	open_dialog.connect("file_selected", _on_file_selected)
	add_child(open_dialog)
	open_dialog.visible = false


func load_recent_list():
	recent_list.clear()
	var settings = EditorInterface.get_editor_settings()
	if not settings.has_setting("varedit/recent_files"):
		return
	var recent = settings.get_setting("varedit/recent_files")
	for item in recent:
		recent_list.add_item(item)

func push_file_to_recent_list(path: String):
	var settings = EditorInterface.get_editor_settings()
	var recent = []
	if settings.has_setting("varedit/recent_files"):
		recent = settings.get_setting("varedit/recent_files")

	var new_recent = [path]
	for item in recent:
		# make sure we don't have duplicates
		if item != path:
			new_recent.push_back(item)
		if len(new_recent) >= 100:
			break

	settings.set_setting("varedit/recent_files", new_recent)
	load_recent_list()

func _on_recent_activated(index: int):
	open_file(recent_list.get_item_text(index))

func show_error(message: String):
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(640, 320))

var open_dialog: FileDialog

func _on_open_clicked():
	open_dialog.title = "Open a Variant File"
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_USERDATA
	open_dialog.current_file = ""
	open_dialog.popup_centered(Vector2i(640, 800))

func _on_file_selected(file: String) -> void:
	open_file(file)

func _on_user_clicked():
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://"), true)

func _on_open_github_clicked():
	OS.shell_open("https://github.com/jacobcoughenour/varedit")

func _on_new_tab_clicked():
	_on_open_clicked()

var last_refresh = 0.0

func _process(delta):
	if !is_inside_plugin:
		return

	if open_files.is_empty():
		#welcome.visible = true
		tree_container.visible = false
		code_edit.visible = false
		return

	welcome.visible = false
	tree_container.visible = view_option_button.selected == 0
	code_edit.visible = view_option_button.selected == 1

	if reload_check_button.button_pressed:
		last_refresh += delta
		if last_refresh > 1.5:
			reload()
			last_refresh = 0.0


func open_file(path: String):

	# switch to existingn tab if file already open
	var index = 0
	for tab in open_files:
		var tab_path = tab["path"]
		if tab_path == path:
			tab_bar.current_tab = index
			return
		index += 1

	var file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	var error = FileAccess.get_open_error()
	var is_compressed = true
	if error != OK:
		file = FileAccess.open(path, FileAccess.READ)
		error = FileAccess.get_open_error()
		is_compressed = false

	if error != OK:
		show_error("Failed to load file: " + str(error))
		return

	var data = file.get_var(false)
	if data == null:
		show_error("File is missing Variant data or is corrupt.")
		return

	var name = path.split("\\")[-1]
	open_files.push_back({
		"name": name,
		"path": path,
		"data": data,
		"is_compressed": is_compressed
	})
	push_file_to_recent_list(path)
	tab_bar.add_tab(name, compressed_icon if is_compressed else file_icon)
	tab_bar.current_tab = tab_bar.tab_count - 1
	file_changed(false)

func reload():
	if len(open_files) == 0:
		return

	var cur = open_files[tab_bar.current_tab]
	var file = FileAccess.open(cur.path, FileAccess.READ)
	var data = file.get_var(false)

	cur.data = data

	file_changed(true)

func select_file(index: int):
	file_changed(false)

func close_file(index: int):
	tab_bar.remove_tab(index)
	open_files.remove_at(index)
	file_changed(false)

func filter_mode_changed(val: int):
	file_changed(false)

func filter_changed(val: String):
	file_changed(false)

func tree_item_activated():
	var item = tree.get_selected()
	var path = item.get_metadata(0)
	# reset to starts with mode
	tree_path_filter_mode.selected = 0
	tree_path_filter.text = path
	filter_changed(path)

func file_changed(preserve_scroll: bool):
	if len(open_files) == 0:
		top_bar.visible = false
		welcome.visible = true
		return
	top_bar.visible = true

	var cx = code_edit.scroll_horizontal
	var cy = code_edit.scroll_vertical

	var cur = open_files[tab_bar.current_tab]

	tree.clear()
	var root = tree.create_item()
	var regex = RegEx.new()
	regex.compile(tree_path_filter.text)
	populate(root, "root", cur.data, "", tree_path_filter.text, regex)
	code_edit.text = JSON.stringify(cur.data, "\t")

	if preserve_scroll:
		code_edit.scroll_horizontal = cx
		code_edit.scroll_vertical = cy

func apply_filter(path: String, filter: String, regex: RegEx):
	# starts with filter
	if tree_path_filter_mode.selected == 0:
		return len(filter) == 0 or path.find(filter) == 0 or filter.find(path) == 0
	# glob filter
	if tree_path_filter_mode.selected == 1:
		return len(filter) == 0 or path.match(filter)
	# regex filter
	if tree_path_filter_mode.selected == 2:
		if len(filter) == 0:
			return true
		if !regex.is_valid():
			return false
		var matches = regex.search(path)
		if matches == null:
			return false
		return matches.strings.has(path)
	# exact filter
	return path == filter

func populate(item: TreeItem, key: Variant, data: Variant, full_path: String, filter: String, regex: RegEx):
	item.set_text(0, str(key))
	item.set_editable(1, true)

	var type = typeof(data)

	if (type_icons.has(type)):
		item.set_icon(0, type_icons[type])

	item.set_tooltip_text(0, "[%s] %s" % [types[type], full_path])
	item.set_metadata(0, full_path)

	match type:
		TYPE_DICTIONARY:
			for k in data:
				var path = k if full_path == "" else full_path + "." + str(k)
				if apply_filter(path, filter, regex):
					var child = item.create_child()
					populate(child, k, data[k], path, filter, regex)
		TYPE_ARRAY:
			for i in len(data):
				var path = full_path + "[%d]" % i
				if apply_filter(path, filter, regex):
					var child = item.create_child()
					populate(child, "[%d]" % i, data[i], path, filter, regex)
		_:
			item.set_text(1, str(data))

	item.collapsed = false
