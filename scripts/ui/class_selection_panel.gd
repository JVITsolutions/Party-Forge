class_name ClassSelectionPanel
extends Control

signal class_preview_requested(class_id: StringName)
signal class_selection_requested(class_id: StringName)
signal start_requested(class_id: StringName)
signal settings_requested
signal armoury_requested(class_id: StringName)
signal back_requested
signal class_selected(class_id: StringName) # Task 8 compatibility alias.
signal legacy_run_confirmed # Declarative HUD bridge removed by Task 8.

const CLASS_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_class_card.tscn")
const SEAT_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_seat_card.tscn")
const DEFAULT_OPTIONS := {
	&"high_contrast": false,
	&"ui_scale_percent": 100,
	&"text_scale_percent": 100,
	&"reduced_motion": false,
	&"armoury_available": false,
	&"safe_cancellation_available": false,
}

var _definitions_by_id: Dictionary = {}
var _projection: RunSetupLobbyProjection
var _stable_projection: RunSetupLobbyProjection
var _previewed_class_id: StringName = &""
var _pending_initial_focus: Control
var _pending_origin: Control
var _focus_context: Control
var _compatibility_gate_active := false
var _compatibility_class_id: StringName = &""
var _options := DEFAULT_OPTIONS.duplicate(true)
var _layout_mode := RunSetupResponsiveLayout.Mode.DESKTOP
var _actions_initialized := false
var _input_tracker := ActiveInputDevice.new()
var _card_geometry_settle_queued := false
var _card_geometry_settle_passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(is_open())
	_ensure_action_buttons()
	if _projection == null:
		_projection = _empty_projection()
	_render()
	apply_viewport_size(get_viewport_rect().size)
	if is_open() and _should_claim_implicit_focus():
		_focus_initial(null)


func configure(catalog_value: Variant) -> void:
	_definitions_by_id.clear()
	var definitions: Array[ClassDefinition] = []
	if catalog_value is GameCatalog:
		definitions.assign((catalog_value as GameCatalog).classes)
	elif catalog_value is Array:
		for value: Variant in catalog_value as Array:
			if value is ClassDefinition:
				definitions.append(value as ClassDefinition)
	for definition: ClassDefinition in definitions:
		if definition != null and not definition.id.is_empty():
			_definitions_by_id[definition.id] = definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ClassDefinition
	if _projection == null or _projection.classes.is_empty():
		_projection = _catalog_projection(catalog_value, definitions)
		_previewed_class_id = _projection.previewed_class_id
	_render()


func present(next_projection: RunSetupLobbyProjection) -> void:
	if next_projection == null:
		return
	var was_pending := _is_pending_state(_state())
	var recovery_origin := _pending_origin if was_pending and _pending_origin != null and is_instance_valid(_pending_origin) else null
	_focus_context = recovery_origin
	_options = _options_from(next_projection)
	_projection = next_projection.copy()
	_previewed_class_id = _resolved_preview_id(_projection.previewed_class_id)
	if not _is_pending_state(_projection.state):
		_stable_projection = _projection.copy()
	_render()
	if recovery_origin != null:
		_pending_initial_focus = recovery_origin
		_restore_focus(recovery_origin)
		_pending_origin = null


func open(preferred_focus: Control = null) -> void:
	visible = true
	set_process_input(true)
	_render_preview_and_details()
	_rebuild_focus_graph()
	_refresh_prompt_presentation()
	_focus_initial(preferred_focus)


func close() -> void:
	visible = false
	set_process_input(false)
	_pending_initial_focus = null
	_pending_origin = null
	_focus_context = null
	_apply_action_matrix()
	_rebuild_focus_graph()
	_compatibility_gate_active = false
	_compatibility_class_id = &""
	if _preview() != null:
		_preview().clear()
	if is_inside_tree():
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner != null and is_ancestor_of(focus_owner):
			focus_owner.release_focus()


func is_open() -> bool:
	return visible


func selected_class_id() -> StringName:
	return _projection.selected_class_id if _projection != null else &""


func previewed_class_id() -> StringName:
	return _previewed_class_id


func active_prompt_mode() -> StringName:
	return _input_tracker.device_kind


func selection_focus(class_id: StringName) -> Control:
	return _class_grid().get_node_or_null("Class_%s" % class_id) as Control


func action_focus(action_id: StringName) -> Control:
	return _action_bar().button_for(action_id)


func set_pending(state: Variant, origin: Control) -> void:
	var requested_state := _pending_state_from(state)
	if requested_state < 0:
		var restore_target := origin if origin != null else _pending_origin
		if _stable_projection != null:
			_focus_context = restore_target
			_projection = _stable_projection.copy()
			_render()
		_pending_initial_focus = restore_target
		_restore_focus(_pending_initial_focus)
		_pending_origin = null
		return
	if _projection == null:
		_projection = _empty_projection()
	if not _is_pending_state(_projection.state):
		_stable_projection = _projection.copy()
	_pending_origin = origin
	_focus_context = origin
	_pending_initial_focus = origin
	_projection = _projection.copy()
	_projection.state = requested_state as RunSetupLobbyProjection.State
	_render()
	if origin != null and is_instance_valid(origin):
		origin.focus_mode = Control.FOCUS_ALL
		_pending_initial_focus = origin
		_restore_focus(origin)


func begin_compatibility_gate(class_id: StringName, origin: Control = null) -> Control:
	_compatibility_gate_active = true
	_compatibility_class_id = class_id
	var resolved_origin := origin if origin != null else selection_focus(class_id)
	set_pending(RunSetupLobbyProjection.State.CHECKING, resolved_origin)
	return resolved_origin


func end_compatibility_gate(restore_focus := true) -> void:
	var target := _pending_origin
	if target == null or not is_instance_valid(target):
		target = selection_focus(_compatibility_class_id)
	_compatibility_gate_active = false
	_compatibility_class_id = &""
	if not restore_focus:
		_pending_origin = null
		_pending_initial_focus = null
		_focus_context = null
		if _stable_projection != null:
			_projection = _stable_projection.copy()
			_render()
		return
	set_pending(false, target)
	_pending_initial_focus = target


func compatibility_gate_active() -> bool:
	return _compatibility_gate_active


func show_status(message: String) -> void:
	_status().text = message
	_status().visible = not message.strip_edges().is_empty()


func clear_status() -> void:
	show_status("")


func confirm_run_started() -> void: # Task 8 compatibility alias.
	close()
	legacy_run_confirmed.emit()


func apply_viewport_size(viewport_size: Vector2) -> void:
	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	_layout_mode = RunSetupResponsiveLayout.mode_for_size(safe_size)
	var content := get_node_or_null("Content") as Control
	if content == null:
		return
	var content_width := RunSetupResponsiveLayout.content_width_for_size(safe_size)
	content.offset_left = -content_width * 0.5
	content.offset_right = content_width * 0.5
	var compact := _layout_mode == RunSetupResponsiveLayout.Mode.COMPACT
	var margin := get_node("Content/Margin") as MarginContainer
	margin.offset_top = 8.0 if compact else 16.0
	margin.offset_bottom = -8.0 if compact else -16.0
	var layout := get_node("Content/Margin/Layout") as VBoxContainer
	layout.add_theme_constant_override(&"separation", 8 if compact else 12)
	var header := get_node("Content/Margin/Layout/Header") as HBoxContainer
	header.custom_minimum_size.y = 40.0 if compact else 56.0
	var title := header.get_node("Title") as Label
	if compact and int(_options.get(&"text_scale_percent", 100)) > 100:
		title.add_theme_font_size_override(&"font_size", 32)
	else:
		title.remove_theme_font_size_override(&"font_size")
	_left_column().add_theme_constant_override(&"separation", 4 if compact else 12)
	_seat_grid().columns = 4 if compact else 2
	_seat_grid().add_theme_constant_override(&"h_separation", 4 if compact else 8)
	var text_scale := int(_options.get(&"text_scale_percent", 100))
	_class_grid().columns = (1 if compact else 2) if text_scale >= 125 else (2 if compact else 3)
	var desktop_left_width := minf(840.0, maxf(720.0, content_width - 872.0))
	_left_column().custom_minimum_size = Vector2(620.0 if compact else desktop_left_width, 0.0)
	_hero_stage().custom_minimum_size = Vector2(260.0, 340.0) if compact else Vector2(400.0, 520.0)
	_details().custom_minimum_size = Vector2(260.0 if compact else 400.0, 0.0)
	for child: Node in _seat_grid().get_children():
		var seat := child as Control
		if seat == null:
			continue
		seat.custom_minimum_size = Vector2(144.0, 80.0) if compact else Vector2(300.0, 104.0)
		if seat.has_method(&"set_compact_presentation"):
			seat.call(&"set_compact_presentation", compact)
		_apply_compact_seat_density(seat, compact)
		var identity := seat.get_node_or_null("Content/Identity") as Label
		if identity != null:
			identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
			identity.custom_minimum_size.x = 88.0 if compact else 0.0
		var ready := seat.get_node_or_null("Content/Ready") as Label
		if ready != null:
			ready.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
			ready.custom_minimum_size.x = 88.0 if compact else 0.0
		var future := seat.get_node_or_null("Content/FuturePlate") as Control
		if future != null:
			future.custom_minimum_size.x = 0.0 if compact else 256.0
		var availability := seat.find_child("Availability", true, false) as Label
		if availability != null:
			availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
			availability.custom_minimum_size.x = 24.0 if compact else 0.0
	for child: Node in _class_grid().get_children():
		_apply_card_geometry(child as ForgeClassCard, compact)
	_rebuild_focus_graph()
	_refresh_prompt_presentation()


func _input(event: InputEvent) -> void:
	if not is_open() or not _input_tracker.observe(event):
		return
	_refresh_prompt_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"ui_cancel") or not _back_enabled():
		return
	back_requested.emit()
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		apply_viewport_size(size)


func _render() -> void:
	if get_node_or_null("Content") == null:
		return
	_sync_seats()
	_sync_class_cards()
	_ensure_action_buttons()
	_apply_options()
	_apply_action_matrix()
	_status().text = _projection.status_copy if _projection != null else ""
	_status().visible = not _status().text.strip_edges().is_empty()
	_render_preview_and_details()
	_rebuild_focus_graph()


func _apply_options() -> void:
	var high_contrast := bool(_options.get(&"high_contrast", false))
	theme = LivingForgeThemeCatalog.resolve(high_contrast, int(_options.get(&"ui_scale_percent", 100)), int(_options.get(&"text_scale_percent", 100)))
	if _preview() != null:
		_preview().set_reduced_motion(bool(_options.get(&"reduced_motion", false)))
	for node: Node in find_children("*", "", true, false):
		if node.has_method(&"apply_accessibility_variant"):
			node.call(&"apply_accessibility_variant", high_contrast)
	_sync_authoritative_preview_cue()


func _sync_seats() -> void:
	var seats := _seat_grid()
	for child: Node in seats.get_children():
		seats.remove_child(child)
		child.free()
	if _projection == null:
		return
	for projection: RunSetupSeatProjection in _projection.seats:
		var seat := SEAT_CARD_SCENE.instantiate() as ForgeSeatCard
		seat.name = "Seat_%d" % projection.seat_number
		seat.present({
			"seat_number": projection.seat_number,
			"available": projection.state == RunSetupSeatProjection.State.ACTIVE,
			"profile_name": projection.label,
			"status": "READY",
			"accessibility_description": "%s. %s" % [projection.label, "Active player seat." if projection.state == RunSetupSeatProjection.State.ACTIVE else "Local co-op Coming Soon. Unavailable."],
		})
		seats.add_child(seat)
	apply_viewport_size(_effective_viewport_size())


func _sync_class_cards() -> void:
	var grid := _class_grid()
	var wanted_ids: Array[StringName] = []
	if _projection != null:
		for item: RunSetupClassProjection in _projection.classes:
			wanted_ids.append(item.id)
	var existing_ids: Array[StringName] = []
	for child: Node in grid.get_children():
		var card := child as ForgeClassCard
		if card != null:
			existing_ids.append(card.class_id)
	if existing_ids != wanted_ids:
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.free()
		for item: RunSetupClassProjection in _projection.classes:
			var card := CLASS_CARD_SCENE.instantiate() as ForgeClassCard
			card.name = "Class_%s" % item.id
			card.preview_requested.connect(_on_class_preview_requested)
			card.selection_requested.connect(_on_class_selection_requested)
			grid.add_child(card)
	for item: RunSetupClassProjection in _projection.classes:
		var card := selection_focus(item.id) as ForgeClassCard
		if card == null:
			continue
		var selected := item.id == _projection.selected_class_id
		card.present({
			"class_id": item.id, "name": item.display_name.to_upper(), "role": item.role_label, "playstyle": "",
			"selected": selected,
			"compatible": selected and item.compatibility == RunSetupClassProjection.Compatibility.COMPATIBLE,
			"needs_attention": selected and item.compatibility == RunSetupClassProjection.Compatibility.NEEDS_ATTENTION,
			"pending": selected and _state() == RunSetupLobbyProjection.State.CHECKING,
			"disabled": false, "locked": _state() == RunSetupLobbyProjection.State.STARTING,
			"accessibility_description": "%s class. %s." % [item.display_name, item.role_label],
		})
		card.set_previewed(item.id == _previewed_class_id)
		card.set_interaction_locked(_state() == RunSetupLobbyProjection.State.STARTING)
		_apply_card_geometry(card, _layout_mode == RunSetupResponsiveLayout.Mode.COMPACT)


func _apply_card_geometry(card: ForgeClassCard, compact: bool) -> void:
	if card == null:
		return
	var text_scale := int(_options.get(&"text_scale_percent", 100))
	var scaled_height := maxf(0.0, roundf(float(text_scale - 100) * 0.9))
	var base_height := (128.0 if compact else 144.0) + scaled_height
	card.custom_minimum_size = Vector2(0.0, base_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := card.get_node("Content") as HBoxContainer
	var preview := card.get_node("PreviewIndicator") as Control
	content.anchor_top = 0.0
	content.anchor_bottom = 0.0
	content.offset_left = 8.0
	content.offset_top = 4.0
	content.offset_right = -148.0 if preview.visible else -8.0
	content.add_theme_constant_override(&"separation", 4)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	var portrait := card.get_node("Content/Portrait") as TextureRect
	portrait.custom_minimum_size = Vector2(24.0, 32.0)
	var identity := card.get_node("Content/Identity") as Control
	identity.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var name := card.get_node("Content/Identity/Name") as Label
	var role := card.get_node("Content/Identity/Role") as Label
	name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name.clip_text = false
	name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	name.custom_minimum_size = Vector2.ZERO
	role.custom_minimum_size = Vector2.ZERO
	var identity_band_height := 76.0 + maxf(0.0, roundf(float(text_scale - 100) * 0.86))
	content.offset_bottom = content.offset_top + identity_band_height
	_set_card_band(preview, -136.0, 4.0, -8.0, 32.0, Vector2(128.0, 28.0))
	var bottom_inset := -2.0 if text_scale > 100 else -8.0
	var selection := card.get_node("SelectionNotch") as Control
	_set_card_band(selection, 8.0, -32.0, 128.0, bottom_inset, Vector2(120.0, 24.0))
	var compatibility := card.get_node("CompatibilityBadge") as Control
	_set_card_band(compatibility, -112.0, -32.0, -8.0, bottom_inset, Vector2(104.0, 24.0))
	(card.get_node("CompatibilityBadge/Text") as Label).text = "READY"
	var attention := card.get_node("AttentionBadge") as Control
	attention.anchor_top = 1.0
	attention.anchor_bottom = 1.0
	_set_card_band(attention, -120.0, -32.0, -8.0, bottom_inset, Vector2(112.0, 24.0))
	(card.get_node("AttentionBadge/Text") as Label).text = "REVIEW"
	(card.get_node("FocusFrame") as Control).custom_minimum_size = Vector2.ZERO
	(card.get_node("LockOverlay") as Control).custom_minimum_size = Vector2.ZERO
	_fit_card_text(card, compact, text_scale)
	_queue_card_geometry_settle()


func _fit_card_text(card: ForgeClassCard, compact: bool, text_scale: int) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var identity := card.get_node("Content/Identity") as Control
	if identity == null or identity.size.x <= 0.0:
		return false
	var content := card.get_node("Content") as Control
	var base_height := (128.0 if compact else 144.0) + maxf(0.0, roundf(float(text_scale - 100) * 0.9))
	var identity_min_height := identity.size.y
	if identity_min_height <= 0.0:
		return false
	# A newly inserted HBox can report a transient, width-zero minimum before
	# its first layout pass. Never let that transient value grow a card by
	# hundreds of pixels; the deferred pass will measure the laid-out column.
	if identity_min_height > base_height + 64.0:
		return false
	var identity_band_height := 76.0 + maxf(0.0, roundf(float(text_scale - 100) * 0.86))
	var content_height := maxf(identity_band_height, identity_min_height)
	content.offset_bottom = content.offset_top + content_height
	var required_height := maxf(base_height, content.offset_bottom + 46.0)
	var changed := not is_equal_approx(card.custom_minimum_size.y, required_height)
	card.custom_minimum_size = Vector2(card.custom_minimum_size.x, required_height)
	return changed


func _queue_card_geometry_settle() -> void:
	if _card_geometry_settle_queued or not is_inside_tree():
		return
	_card_geometry_settle_queued = true
	_card_geometry_settle_passes = 0
	get_tree().process_frame.connect(Callable(self, &"_settle_card_geometry"), CONNECT_ONE_SHOT)


func _schedule_card_geometry_settle_pass() -> void:
	if _card_geometry_settle_queued or not is_inside_tree():
		return
	_card_geometry_settle_queued = true
	get_tree().process_frame.connect(Callable(self, &"_settle_card_geometry"), CONNECT_ONE_SHOT)


func _settle_card_geometry() -> void:
	_card_geometry_settle_queued = false
	if not is_inside_tree():
		_card_geometry_settle_passes = 0
		return
	var changed := false
	var compact := _layout_mode == RunSetupResponsiveLayout.Mode.COMPACT
	var text_scale := int(_options.get(&"text_scale_percent", 100))
	for child: Node in _class_grid().get_children():
		var card := child as ForgeClassCard
		if card != null:
			changed = _fit_card_text(card, compact, text_scale) or changed
	if changed or _card_geometry_settle_passes < 6:
		_card_geometry_settle_passes += 1
		_schedule_card_geometry_settle_pass()
	else:
		_card_geometry_settle_passes = 0


func _set_card_band(control: Control, left: float, top: float, right: float, bottom: float, minimum: Vector2) -> void:
	control.custom_minimum_size = minimum
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _apply_compact_seat_density(seat: Control, compact: bool) -> void:
	if seat == null or not compact:
		return
	var content := seat.get_node_or_null("Content") as VBoxContainer
	if content != null:
		content.add_theme_constant_override(&"separation", 4)
	var seat_panel := seat as PanelContainer
	if seat_panel != null:
		var seat_style := seat_panel.get_theme_stylebox(&"panel").duplicate() as StyleBox
		_set_style_content_margin(seat_style, 4.0)
		seat_panel.add_theme_stylebox_override(&"panel", seat_style)
	var future := seat.get_node_or_null("Content/FuturePlate") as PanelContainer
	if future != null:
		var future_style := future.get_theme_stylebox(&"panel").duplicate() as StyleBox
		_set_style_content_margin(future_style, 4.0)
		future.add_theme_stylebox_override(&"panel", future_style)
		var stack := future.get_node_or_null("CompactFutureStack") as VBoxContainer
		if stack != null:
			stack.add_theme_constant_override(&"separation", 0)


func _set_style_content_margin(style: StyleBox, margin: float) -> void:
	if style == null:
		return
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin


func _sync_authoritative_preview_cue() -> void:
	if get_node_or_null("Content") == null:
		return
	var preview_description := String((ForgeClassCard.STATE_CUES[&"previewed"] as Dictionary).get("accessibility_description", "Class preview shown."))
	for child: Node in _class_grid().get_children():
		var card := child as ForgeClassCard
		if card == null:
			continue
		var authoritative := card.class_id == _previewed_class_id
		(card.get_node("PreviewIndicator") as Control).visible = authoritative
		_apply_card_geometry(card, _layout_mode == RunSetupResponsiveLayout.Mode.COMPACT)
		if authoritative:
			if not card.accessibility_description.contains(preview_description):
				card.accessibility_description = "%s %s" % [card.accessibility_description.strip_edges(), preview_description]
		else:
			card.accessibility_description = card.accessibility_description.replace(preview_description, "").replace("  ", " ").strip_edges()


func _ensure_action_buttons() -> void:
	if _action_bar() == null or _actions_initialized:
		return
	_action_bar().present([
		{"id": &"back", "label": "Back", "enabled": true, "kind": &"secondary", "accessibility_description": "Return to the previous screen."},
		{"id": &"settings", "label": "Settings", "enabled": true, "kind": &"secondary", "accessibility_description": "Open settings."},
		{"id": &"armoury", "label": "Armoury", "enabled": false, "kind": &"secondary", "accessibility_description": "Review the selected class loadout."},
		{"id": &"select", "label": "Select Class", "enabled": true, "kind": &"secondary", "accessibility_description": "Select the previewed class."},
		{"id": &"start", "label": "Start Run", "enabled": false, "kind": &"primary", "accessibility_description": "Start with the selected class."},
	])
	_action_bar().action_requested.connect(_on_action_requested)
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var button := action_focus(action_id) as Button
		if button != null:
			button.focus_exited.connect(_on_action_focus_exited.bind(button))
	_actions_initialized = true


func _apply_action_matrix() -> void:
	if not _actions_initialized:
		return
	var state := _state()
	_set_action_enabled(&"back", state != RunSetupLobbyProjection.State.STARTING or bool(_options.get(&"safe_cancellation_available", false)))
	_set_action_enabled(&"settings", state not in [RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.STARTING])
	_set_action_enabled(&"armoury", bool(_options.get(&"armoury_available", false)) and state not in [RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.STARTING])
	_set_action_enabled(&"select", _can_select(_previewed_class_id))
	_set_action_enabled(&"start", _can_start())
	_refresh_prompt_presentation()


func _refresh_prompt_presentation() -> void:
	var prompt := get_node_or_null("Content/Margin/Layout/Footer/InputPrompt") as ForgeInputPrompt
	if prompt == null:
		return
	var device_kind := active_prompt_mode()
	var binding_label := prompt.label_for_action(&"ui_accept", device_kind)
	var action_copy := "Start Run" if _action_enabled(&"start") else ("Select Class" if _action_enabled(&"select") else "Confirm")
	prompt.present_contextual(&"ui_accept", device_kind, binding_label, action_copy)
	var active_seat := _seat_grid().get_node_or_null("Seat_1") as ForgeSeatCard
	if active_seat != null:
		active_seat.present_prompt_device(device_kind, _layout_mode == RunSetupResponsiveLayout.Mode.COMPACT)


func _set_action_enabled(action_id: StringName, enabled: bool) -> void:
	var button := action_focus(action_id) as Button
	if button == null:
		return
	var retains_focus_context := button == _pending_origin or button == _focus_context
	button.disabled = not enabled and not retains_focus_context
	button.set_meta(&"action_enabled", enabled)
	button.theme_type_variation = &"LivingForgeUnavailableButton" if not enabled else (&"LivingForgeStartButton" if action_id == &"start" else &"LivingForgeSecondaryButton")


func _render_preview_and_details() -> void:
	var item := _class_projection(_previewed_class_id)
	if item == null:
		_details_name().text = "CHOOSE A CLASS"
		_details_role().text = "Preview a class to inspect it."
		_details_traits().text = "—"
		_details_action().text = "—"
		_details_compatibility().text = "SELECT A CLASS"
		if _preview() != null:
			_preview().show_fallback(&"", "Preview unavailable.")
		return
	_details_name().text = item.display_name.to_upper()
	_details_role().text = item.role_label
	_details_traits().text = ", ".join(item.trait_display_names) if not item.trait_display_names.is_empty() else "No class traits listed."
	_details_action().text = item.starting_action_label
	_details_compatibility().text = _compatibility_copy(item)
	var definition := _definitions_by_id.get(item.id) as ClassDefinition
	if _preview() != null:
		if definition == null:
			_preview().show_fallback(item.id, "Preview unavailable.")
		else:
			_preview().show_class(definition)


func _compatibility_copy(item: RunSetupClassProjection) -> String:
	if item.id != selected_class_id():
		return "PREVIEW ONLY · SELECT TO CHECK"
	match item.compatibility:
		RunSetupClassProjection.Compatibility.COMPATIBLE: return "COMPATIBLE · READY"
		RunSetupClassProjection.Compatibility.NEEDS_ATTENTION: return "NEEDS ATTENTION · START OPENS REVIEW"
		RunSetupClassProjection.Compatibility.UNAVAILABLE: return "UNAVAILABLE · CHOOSE ANOTHER CLASS OR REVIEW ARMOURY"
		_: return "CHECKING COMPATIBILITY"


func _on_class_preview_requested(class_id: StringName) -> void:
	if _class_projection(class_id) == null or _state() == RunSetupLobbyProjection.State.STARTING:
		return
	_previewed_class_id = class_id
	for child: Node in _class_grid().get_children():
		var card := child as ForgeClassCard
		if card != null:
			card.set_previewed(card.class_id == class_id)
	_sync_authoritative_preview_cue()
	_render_preview_and_details()
	_apply_action_matrix()
	_rebuild_focus_graph()
	class_preview_requested.emit(class_id)


func _on_class_selection_requested(class_id: StringName) -> void:
	if _can_select(class_id):
		class_selection_requested.emit(class_id)
		class_selected.emit(class_id)


func _on_action_requested(action_id: StringName) -> void:
	match action_id:
		&"back":
			if _back_enabled(): back_requested.emit()
		&"settings":
			if not (action_focus(&"settings") as Button).disabled: settings_requested.emit()
		&"armoury":
			if not (action_focus(&"armoury") as Button).disabled: armoury_requested.emit(_armoury_target_id())
		&"select": _on_class_selection_requested(_previewed_class_id)
		&"start":
			if _can_start(): start_requested.emit(selected_class_id())


func _can_select(class_id: StringName) -> bool:
	if class_id.is_empty() or _class_projection(class_id) == null:
		return false
	match _state():
		RunSetupLobbyProjection.State.NO_SELECTION, RunSetupLobbyProjection.State.READY, RunSetupLobbyProjection.State.NEEDS_ATTENTION, RunSetupLobbyProjection.State.ERROR:
			return true
		RunSetupLobbyProjection.State.UNAVAILABLE:
			return class_id != selected_class_id()
		_:
			return false


func _can_start() -> bool:
	if selected_class_id().is_empty() or _state() not in [RunSetupLobbyProjection.State.READY, RunSetupLobbyProjection.State.NEEDS_ATTENTION]:
		return false
	var selected := _class_projection(selected_class_id())
	return selected != null and selected.compatibility in [RunSetupClassProjection.Compatibility.COMPATIBLE, RunSetupClassProjection.Compatibility.NEEDS_ATTENTION]


func _back_enabled() -> bool:
	return _action_enabled(&"back")


func _action_enabled(action_id: StringName) -> bool:
	var button := action_focus(action_id) as Button
	return button != null and bool(button.get_meta(&"action_enabled", false))


func _on_action_focus_exited(button: Button) -> void:
	if button == null or button != _focus_context or bool(button.get_meta(&"action_enabled", false)):
		return
	call_deferred(&"_expire_focus_context", button)


func _expire_focus_context(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button != _focus_context or button.has_focus():
		return
	_focus_context = null
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	_rebuild_focus_graph()


func _armoury_target_id() -> StringName:
	return selected_class_id() if not selected_class_id().is_empty() else _previewed_class_id


func _rebuild_focus_graph() -> void:
	var all_controls: Array[Button] = []
	for child: Node in _class_grid().get_children():
		if child is Button:
			all_controls.append(child as Button)
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var action := action_focus(action_id) as Button
		if action != null:
			all_controls.append(action)
	for control: Button in all_controls:
		control.focus_next = NodePath()
		control.focus_previous = NodePath()
		control.focus_neighbor_left = NodePath()
		control.focus_neighbor_right = NodePath()
		control.focus_neighbor_top = NodePath()
		control.focus_neighbor_bottom = NodePath()
	var available: Array[Button] = []
	for control: Button in all_controls:
		var action_authority := bool(control.get_meta(&"action_enabled", false)) if control.has_meta(&"action_id") else not control.disabled
		var retains_focus_context := control == _pending_origin or control == _focus_context
		if control.visible and (action_authority or retains_focus_context):
			if retains_focus_context and control.disabled:
				control.disabled = false
			control.focus_mode = Control.FOCUS_ALL
			available.append(control)
		else:
			control.focus_mode = Control.FOCUS_NONE
	if available.is_empty():
		return
	for index: int in available.size():
		var current := available[index]
		current.focus_next = current.get_path_to(available[(index + 1) % available.size()])
		current.focus_previous = current.get_path_to(available[posmod(index - 1, available.size())])
	_rebuild_directional_focus()


func _rebuild_directional_focus() -> void:
	var cards: Array[Button] = []
	for child: Node in _class_grid().get_children():
		var card := child as Button
		if card != null and card.focus_mode == Control.FOCUS_ALL:
			cards.append(card)
	var actions: Array[Button] = []
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var action := action_focus(action_id) as Button
		if action != null and action.focus_mode == Control.FOCUS_ALL:
			actions.append(action)
	if cards.is_empty():
		return
	var preview := _preview()
	if preview != null:
		preview.focus_mode = Control.FOCUS_ALL
		preview.focus_neighbor_left = preview.get_path_to(preview)
		preview.focus_neighbor_right = preview.get_path_to(preview)
	var columns := maxi(_class_grid().columns, 1)
	for index: int in cards.size():
		var card := cards[index]
		var column := index % columns
		_set_neighbor(card, &"focus_neighbor_left", cards[index - 1] if column > 0 else card)
		_set_neighbor(card, &"focus_neighbor_right", preview if preview != null else card)
		_set_neighbor(card, &"focus_neighbor_top", cards[index - columns] if index >= columns else card)
		if index + columns < cards.size():
			_set_neighbor(card, &"focus_neighbor_bottom", cards[index + columns])
		elif not actions.is_empty():
			_set_neighbor(card, &"focus_neighbor_bottom", actions[mini(column, actions.size() - 1)])
		else:
			_set_neighbor(card, &"focus_neighbor_bottom", card)
	if preview != null:
		var preview_card := selection_focus(_previewed_class_id)
		_set_neighbor(preview, &"focus_neighbor_top", preview_card if preview_card != null else cards[0])
		_set_neighbor(preview, &"focus_neighbor_bottom", actions[0] if not actions.is_empty() else (preview_card if preview_card != null else cards[0]))
	for index: int in actions.size():
		_set_neighbor(actions[index], &"focus_neighbor_left", actions[index - 1] if index > 0 else actions[index])
		_set_neighbor(actions[index], &"focus_neighbor_right", actions[index + 1] if index + 1 < actions.size() else actions[index])
		var target_index := clampi(cards.size() - actions.size() + index, 0, cards.size() - 1)
		_set_neighbor(actions[index], &"focus_neighbor_top", cards[target_index])
		_set_neighbor(actions[index], &"focus_neighbor_bottom", actions[index])


func _set_neighbor(control: Control, property_name: StringName, target: Control) -> void:
	control.set(property_name, control.get_path_to(target))


func _focus_initial(preferred_focus: Control) -> void:
	var target := preferred_focus if _is_focus_candidate(preferred_focus) else null
	if target == null:
		target = selection_focus(selected_class_id())
	if not _is_focus_candidate(target):
		for child: Node in _class_grid().get_children():
			if _is_focus_candidate(child as Control):
				target = child as Control
				break
	if target == null:
		for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
			if _is_focus_candidate(action_focus(action_id)):
				target = action_focus(action_id)
				break
	_pending_initial_focus = target
	_restore_focus(target)


func _restore_focus(target: Control) -> void:
	if target != null and is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
		_settle_restored_focus(target)
		call_deferred(&"_settle_restored_focus", target)
		_pending_initial_focus = null


func _settle_restored_focus(target: Control) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree():
		return
	if get_viewport().gui_get_focus_owner() != target or not _class_grid().is_ancestor_of(target):
		return
	var scroll := _nearest_scroll_container(_class_grid())
	if scroll != null:
		scroll.ensure_control_visible(target)


func _nearest_scroll_container(control: Control) -> ScrollContainer:
	var ancestor := control.get_parent() if control != null else null
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null


func _is_focus_candidate(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.visible and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and (control as BaseButton).disabled)


func _should_claim_implicit_focus() -> bool:
	if not is_inside_tree():
		return true
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner == null or is_ancestor_of(focus_owner)


func _options_from(source: RunSetupLobbyProjection) -> Dictionary:
	var result := DEFAULT_OPTIONS.duplicate(true)
	for key: StringName in DEFAULT_OPTIONS:
		if source.has_meta(key):
			var value: Variant = source.get_meta(key)
			if typeof(value) == typeof(DEFAULT_OPTIONS[key]):
				result[key] = value
	result[&"ui_scale_percent"] = maxi(int(result[&"ui_scale_percent"]), 1)
	result[&"text_scale_percent"] = maxi(int(result[&"text_scale_percent"]), 1)
	return result


func _pending_state_from(state: Variant) -> int:
	if state is int and int(state) in [RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.STARTING]:
		return int(state)
	if state is bool and bool(state):
		return RunSetupLobbyProjection.State.STARTING
	return -1


func _is_pending_state(state: int) -> bool:
	return state in [RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.STARTING]


func _state() -> int:
	return _projection.state if _projection != null else RunSetupLobbyProjection.State.NO_SELECTION


func _resolved_preview_id(requested_id: StringName) -> StringName:
	if _class_projection_in(_projection, requested_id) != null:
		return requested_id
	if _projection != null and _class_projection_in(_projection, _projection.selected_class_id) != null:
		return _projection.selected_class_id
	if _projection != null and not _projection.classes.is_empty():
		return _projection.classes[0].id
	return &""


func _class_projection(class_id: StringName) -> RunSetupClassProjection:
	return _class_projection_in(_projection, class_id)


func _class_projection_in(source: RunSetupLobbyProjection, class_id: StringName) -> RunSetupClassProjection:
	if source != null:
		for item: RunSetupClassProjection in source.classes:
			if item.id == class_id:
				return item
	return null


func _catalog_projection(catalog_value: Variant, definitions: Array[ClassDefinition]) -> RunSetupLobbyProjection:
	var classes: Array[RunSetupClassProjection] = []
	var catalog := catalog_value as GameCatalog if catalog_value is GameCatalog else null
	for definition: ClassDefinition in definitions:
		if definition == null:
			continue
		var traits: Array[String] = []
		if catalog != null:
			for trait_id: StringName in definition.traits:
				var trait_definition := catalog.trait_by_id(trait_id)
				if trait_definition != null:
					traits.append(trait_definition.display_name)
		classes.append(RunSetupClassProjection.create(definition.id, definition.display_name, _role_label(definition.role), definition.color, traits, _action_label(definition), RunSetupClassProjection.Compatibility.UNKNOWN, {}))
	var preview_id := classes[0].id if not classes.is_empty() else &""
	return RunSetupLobbyProjection.create(_default_seats(), classes, &"", preview_id, RunSetupLobbyProjection.State.NO_SELECTION, "Choose a class to begin your run.")


func _empty_projection() -> RunSetupLobbyProjection:
	return RunSetupLobbyProjection.create(_default_seats(), [], &"", &"", RunSetupLobbyProjection.State.NO_SELECTION, "Choose a class to begin your run.")


func _default_seats() -> Array[RunSetupSeatProjection]:
	return [RunSetupSeatProjection.active(1, "P1"), RunSetupSeatProjection.coming_soon(2), RunSetupSeatProjection.coming_soon(3), RunSetupSeatProjection.coming_soon(4)]


func _role_label(role: ClassDefinition.Role) -> String:
	return ClassDefinition.Role.keys()[role].capitalize() if role >= 0 and role < ClassDefinition.Role.size() else "Unknown"


func _action_label(definition: ClassDefinition) -> String:
	return String(definition.primary_attack.id).replace("_", " ").capitalize() if definition.primary_attack != null else "Unavailable"


func _effective_viewport_size() -> Vector2:
	return size if size.x > 0.0 and size.y > 0.0 else Vector2(1920.0, 1080.0)


func _seat_grid() -> GridContainer:
	return get_node("Content/Margin/Layout/Body/LeftColumn/Seats") as GridContainer


func _class_grid() -> GridContainer:
	return get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll/Grid") as GridContainer


func _left_column() -> Control:
	return get_node("Content/Margin/Layout/Body/LeftColumn") as Control


func _hero_stage() -> Control:
	return get_node("Content/Margin/Layout/Body/HeroStage") as Control


func _details() -> ScrollContainer:
	return get_node("Content/Margin/Layout/Body/Details") as ScrollContainer


func _preview() -> CharacterEquipmentPreview:
	return get_node_or_null("Content/Margin/Layout/Body/HeroStage/Preview") as CharacterEquipmentPreview


func _action_bar() -> ForgeActionBar:
	return get_node_or_null("Content/Margin/Layout/Footer/ActionBar") as ForgeActionBar


func _status() -> Label:
	return get_node("Content/Margin/Layout/Status") as Label


func _details_name() -> Label:
	return get_node("Content/Margin/Layout/Body/Details/DetailContent/ClassName") as Label


func _details_role() -> Label:
	return get_node("Content/Margin/Layout/Body/Details/DetailContent/Role") as Label


func _details_traits() -> Label:
	return get_node("Content/Margin/Layout/Body/Details/DetailContent/Traits") as Label


func _details_action() -> Label:
	return get_node("Content/Margin/Layout/Body/Details/DetailContent/StartingAction") as Label


func _details_compatibility() -> Label:
	return get_node("Content/Margin/Layout/Body/Details/DetailContent/Compatibility") as Label
