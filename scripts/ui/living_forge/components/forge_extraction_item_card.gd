class_name ForgeExtractionItemCard
extends Button

signal item_toggle_requested(item_id: String)
signal inspect_requested(item_id: String, anchor: Control)

const ICON_ROOT := "res://assets/ui/living_forge/icons/tabler-3.46.0/"

var item_id := ""
var _automatic := false
var _selected := false
var _lost := false
var _high_contrast := false
var _pending := false
var _interaction_locked := false
var _name := "Unknown Item"
var _rarity := "Unknown"
var _source := "Source unavailable"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not pressed.is_connected(_on_pressed): pressed.connect(_on_pressed)
	if not focus_entered.is_connected(_render): focus_entered.connect(_render)
	if not focus_exited.is_connected(_render): focus_exited.connect(_render)
	if not mouse_entered.is_connected(_render): mouse_entered.connect(_render)
	if not mouse_exited.is_connected(_render): mouse_exited.connect(_render)
	gui_input.connect(_on_gui_input)
	var inspect := get_node("Content/Footer/Inspect") as Button
	var inspect_pressed := _request_inspect_from.bind(inspect)
	if not inspect.pressed.is_connected(inspect_pressed): inspect.pressed.connect(inspect_pressed)

func present(projection: TerminalExtractionItemProjection) -> void:
	if projection == null:
		item_id = ""
		set_meta(&"item_id", "")
		visible = false
		return
	visible = true
	item_id = projection.item_id
	set_meta(&"item_id", item_id)
	_name = projection.name
	_rarity = projection.rarity_name
	_source = _source_copy(projection)
	_automatic = projection.automatic
	_selected = projection.selected
	_lost = projection.lost
	_render()

func set_selected(value: bool) -> void:
	if _automatic: return
	_selected = value
	_lost = not value
	_render()

func set_pending(value: bool) -> void:
	_pending = value
	_render()

func set_interaction_locked(value: bool) -> void:
	_interaction_locked = value
	_render()

func request_inspect() -> void:
	_request_inspect_from(self)

func _request_inspect_from(anchor: Control) -> void:
	if item_id.is_empty() or anchor == null or not is_instance_valid(anchor): return
	inspect_requested.emit(item_id, anchor)

func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_render()

func _on_pressed() -> void:
	if _automatic or disabled or item_id.is_empty(): return
	item_toggle_requested.emit(item_id)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and (event as InputEventMouseButton).pressed:
		request_inspect()
		accept_event()
	elif has_focus() and (event.is_action_pressed(&"tooltip_hold") or event.is_action_pressed(&"tooltip_pin")):
		request_inspect()
		accept_event()

func _render() -> void:
	(get_node("Content/Name") as Label).text = _name
	(get_node("Content/Rarity") as Label).text = _rarity
	(get_node("Content/Source") as Label).text = _source
	var state := "AUTOMATIC · LOCKED" if _automatic else ("SELECTED" if _selected else "WILL BE LOST")
	(get_node("Content/Footer/State/StateText") as Label).text = state
	var icon_name := "lock.svg" if _automatic else ("check.svg" if _selected else "alert-triangle.svg")
	var semantic_role := &"disabled" if _automatic else (&"valid" if _selected else &"warning")
	var semantic_color := LivingForgeTokens.color(semantic_role, _high_contrast)
	var state_icon := get_node("Content/Footer/State/StateIcon") as TextureRect
	state_icon.texture = load(ICON_ROOT + icon_name) as Texture2D
	state_icon.self_modulate = semantic_color
	(get_node("Content/Footer/State/StateText") as Label).add_theme_color_override(&"font_color", semantic_color)
	(get_node("FocusFrame") as Control).visible = has_focus()
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 4
	focus_style.border_width_top = 4
	focus_style.border_width_right = 4
	focus_style.border_width_bottom = 4
	focus_style.border_color = LivingForgeTokens.color(&"focus_outline", _high_contrast)
	focus_style.corner_radius_top_left = 7
	focus_style.corner_radius_top_right = 7
	focus_style.corner_radius_bottom_left = 7
	focus_style.corner_radius_bottom_right = 7
	(get_node("FocusFrame") as Panel).add_theme_stylebox_override(&"panel", focus_style)
	disabled = _automatic or _pending or _interaction_locked
	focus_mode = Control.FOCUS_NONE if _automatic else Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if _automatic else Control.CURSOR_POINTING_HAND
	var inspect := get_node("Content/Footer/Inspect") as Button
	inspect.disabled = _pending or item_id.is_empty()
	inspect.focus_mode = Control.FOCUS_NONE if inspect.disabled else Control.FOCUS_ALL
	inspect.accessibility_name = "Inspect %s details" % _name
	accessibility_name = "%s, %s, %s" % [_name, _rarity, _source]
	accessibility_description = "%s. %s." % [accessibility_name, "Automatic locked" if _automatic else ("Selected" if _selected else "Not selected; will be lost")]
	tooltip_text = ""

func _source_copy(projection: TerminalExtractionItemProjection) -> String:
	var labels: Array[String] = []
	var owner := projection.owner_label.strip_edges()
	var container := projection.container_label.strip_edges()
	if not owner.is_empty():
		labels.append(owner)
	if not container.is_empty() and container != owner:
		labels.append(container)
	labels.append("Slot %d" % projection.source_slot)
	return " · ".join(labels)
