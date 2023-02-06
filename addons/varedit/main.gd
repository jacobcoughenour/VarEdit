@tool
extends Panel

var editor_plugin: VarEditPlugin

@onready var tab_bar: TabBar = get_node("%TabBar")
@onready var view_option_button: OptionButton = get_node("%ViewOptionButton")
@onready var tree: Tree = get_node("%Tree")
@onready var code_edit: CodeEdit = get_node("%CodeEdit")
@onready var default_label: Label = get_node("%DefaultLabel")
@onready var reload_check_button: CheckButton = get_node("%ReloadCheckButton")

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

# Called when the node enters the scene tree for the first time.
func _ready():

	var main_control = editor_plugin.get_editor_interface().get_editor_main_screen()

	for type in types:
		var name = types[type]
		type_icons[type] = main_control.get_theme_icon(name, "EditorIcons")

	view_option_button.set_item_icon(0, main_control.get_theme_icon("Tree", "EditorIcons"))
	view_option_button.set_item_icon(1, main_control.get_theme_icon("Script", "EditorIcons"))

	get_window().connect("files_dropped", Callable(self, "_on_files_dropped"))
	tab_bar.connect("tab_changed", Callable(self, "select_file"))
	tab_bar.connect("tab_close_pressed", Callable(self, "close_file"))

	tab_bar.clear_tabs()
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY

	tree.set_column_title(0, "Key")
	tree.set_column_clip_content(0, true)
	tree.set_column_title(1, "Value")
	tree.set_column_expand(1, true)
	tree.column_titles_visible = true

func _on_files_dropped(files):
	for file in files:
		open_file(file)

var last_refresh = 0.0

func _process(delta):

	if open_files.is_empty():
		default_label.visible = true
		tree.visible = false
		code_edit.visible = false
		return

	default_label.visible = false
	tree.visible = view_option_button.selected == 0
	code_edit.visible = view_option_button.selected == 1

	if reload_check_button.button_pressed:
		last_refresh += delta
		if last_refresh > 5:
			reload()
			last_refresh = 0.0


func open_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	var data = file.get_var(false)
	var name = path.split("\\")[-1]
	open_files.push_back({
		"name": name,
		"path": path,
		"data": data,
	})
	tab_bar.add_tab(name)
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

func file_changed(preserve_scroll: bool):
	if len(open_files) == 0:
		return

	var cx = code_edit.scroll_horizontal
	var cy = code_edit.scroll_vertical

	var cur = open_files[tab_bar.current_tab]

	tree.clear()
	var root = tree.create_item()
	populate(root, "root", cur.data, "")
	code_edit.text = JSON.stringify(cur.data, "\t")

	if preserve_scroll:
		code_edit.scroll_horizontal = cx
		code_edit.scroll_vertical = cy

func populate(item: TreeItem, key: Variant, data: Variant, full_path: String):
	item.set_text(0, str(key))

	item.set_editable(1, true)

	var type = typeof(data)

	if (type_icons.has(type)):
		item.set_icon(0, type_icons[type])

	item.set_tooltip_text(0, "[%s] %s" % [types[type], full_path])

	match type:
		TYPE_DICTIONARY:
			for k in data:
				var child = item.create_child()
				populate(child, k, data[k], k if full_path == "" else full_path + "." + k)
		TYPE_ARRAY:
			for i in len(data):
				var child = item.create_child()
				populate(child, "[%d]" % i, data[i], full_path + "[%d]" % i)
		_:
			item.set_text(1, str(data))

	item.collapsed = false
