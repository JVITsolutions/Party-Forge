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
	_source = "%s · %s" % [projection.owner_label, projection.container_label]
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

func request_inspect() -> void:
	if item_id.is_empty(): return
	inspect_requested.emit(item_id, self)

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
	(get_node("Content/State/StateText") as Label).text = state
	var icon_name := "lock.svg" if _automatic else ("check.svg" if _selected else "alert-triangle.svg")
	(get_node("Content/State/StateIcon") as TextureRect).texture = load(ICON_ROOT + icon_name) as Texture2D
	(get_node("FocusFrame") as Control).visible = has_focus()
	disabled = _automatic or _pending
	focus_mode = Control.FOCUS_NONE if _automatic else Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if _automatic else Control.CURSOR_POINTING_HAND
	accessibility_name = "%s, %s, %s" % [_name, _rarity, _source]
	accessibility_description = "%s. %s." % [accessibility_name, "Automatic locked" if _automatic else ("Selected" if _selected else "Not selected; will be lost")]
	tooltip_text = "%s\n%s\n%s" % [_name, _source, state]
