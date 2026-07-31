class_name ClassSelectionPanel
extends PanelContainer

signal class_selected(class_id: StringName)
signal settings_requested

var grid: GridContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grid()
	_ensure_settings_wired()

func configure(definitions: Array[ClassDefinition]) -> void:
	var target_grid := _grid()
	for child: Node in target_grid.get_children():
		target_grid.remove_child(child)
		child.free()
	for definition: ClassDefinition in definitions:
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Class_%s" % definition.id
		button.text = "%s\n%s" % [definition.display_name, _role_label(definition.role)]
		button.custom_minimum_size = Vector2(220.0, 72.0)
		button.add_theme_color_override("font_color", definition.color)
		button.add_theme_color_override("font_hover_color", definition.color.lightened(0.2))
		button.pressed.connect(_emit_selection.bind(definition.id))
		target_grid.add_child(button)

func _grid() -> GridContainer:
	if grid == null:
		grid = get_node("Content/Scroll/Grid") as GridContainer
	return grid

func _emit_selection(class_id: StringName) -> void:
	class_selected.emit(class_id)

func _emit_settings_requested() -> void:
	settings_requested.emit()

func _ensure_settings_wired() -> void:
	var settings := get_node_or_null("Content/Actions/Settings") as Button
	if settings == null or settings.pressed.is_connected(_emit_settings_requested):
		return
	settings.pressed.connect(_emit_settings_requested)

func _role_label(role: ClassDefinition.Role) -> String:
	match role:
		ClassDefinition.Role.FRONTLINE:
			return "Frontline"
		ClassDefinition.Role.MIDLINE:
			return "Midline"
		ClassDefinition.Role.BACKLINE:
			return "Backline"
		ClassDefinition.Role.SUPPORT:
			return "Support"
		_:
			return "Unknown"
