@tool
class_name VarEditPlugin
extends EditorPlugin

const MainPanel = preload("res://addons/varedit/main.tscn")

var main_panel_instance

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	main_panel_instance = MainPanel.instantiate()
	main_panel_instance.editor_plugin = self
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	_make_visible(false)

func _exit_tree():
	if is_instance_valid(main_panel_instance):
		main_panel_instance.queue_free()

func _has_main_screen():
	return true

func _make_visible(visible: bool):
	if is_instance_valid(main_panel_instance):
		main_panel_instance.visible = visible

func _get_plugin_name():
	return "VarEdit"

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Variant", "EditorIcons")



