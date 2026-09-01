class_name TerminalExtractionPanel
extends Control

signal item_toggle_requested(item_id: String)
signal inspect_requested(item_id: String, anchor: Control)
signal confirm_requested
signal unused_capacity_acknowledged
signal retry_resolution_requested

const ITEM_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_extraction_item_card.tscn")

enum PreflightDisposition { NONE, VALID, FAILURE }

var _projection: TerminalExtractionProjection
var _cards_by_id: Dictionary = {}
var _details_by_id: Dictionary = {}
var _detail_return_item_id := ""
var _detail_return_focus: Control
var _warning_return_focus: Control
var _pending := false
var _high_contrast := false
var _ui_scale_percent := 100
var _text_scale_percent := 100
var _preflight_disposition := PreflightDisposition.NONE
var _preflight_category := RunResolutionEvaluation.FailureCategory.NONE
var _preflight_reason := ""
var _controls_connected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_controls()
	_set_base_focus_enabled(false)
	_disable_focus_descendants(get_node("ItemTooltipDetail") as Control)
	_disable_focus_descendants(get_node("UnusedCapacityWarning") as Control)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _connect_controls() -> void:
	if _controls_connected:
		return
	_controls_connected = true
	(get_node("Frame/Content/Actions/Confirm") as Button).pressed.connect(_on_confirm)
	(get_node("Frame/Content/Actions/Retry") as Button).pressed.connect(_on_retry)
	(get_node("ItemTooltipDetail/Frame/Tooltip/Layout/Header/Close") as Button).pressed.connect(_close_detail)
	(get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Back") as Button).pressed.connect(_close_warning)
	(get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button).pressed.connect(_on_warning_acknowledged)
	for pair: Array in [
		[get_node("Frame/Content/Summary/AutomaticList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/AutomaticItems") as Control],
		[get_node("Frame/Content/Summary/SelectedList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/SelectedItems") as Control],
		[get_node("Frame/Content/Summary/LostList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/LostItems") as Control],
	]:
		var button := pair[0] as Button
		button.pressed.connect(_toggle_list.bind(button, pair[1] as Control))

func apply_visual_settings(settings: PartyForgeSettings) -> void:
	var resolved := settings if settings != null else PartyForgeSettings.new()
	_high_contrast = resolved.high_contrast
	_ui_scale_percent = maxi(resolved.ui_scale_percent, 1)
	_text_scale_percent = maxi(resolved.text_scale_percent, 1)
	theme = LivingForgeThemeCatalog.resolve(_high_contrast, _ui_scale_percent, _text_scale_percent)
	(get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel).theme = theme
	for card: Variant in _cards_by_id.values():
		(card as ForgeExtractionItemCard).apply_accessibility_variant(_high_contrast)
	_apply_responsive_layout()

func present(projection: TerminalExtractionProjection) -> void:
	_connect_controls()
	var prior_item_id := _focused_item_id()
	if prior_item_id.is_empty():
		prior_item_id = _detail_return_item_id
	var prior_index := _eligible_index(prior_item_id)
	_force_close_children(false)
	_clear_cards()
	_projection = projection.copy() if projection != null else null
	_pending = projection.pending if projection != null else false
	_preflight_disposition = PreflightDisposition.NONE
	_preflight_category = RunResolutionEvaluation.FailureCategory.NONE
	_preflight_reason = ""
	visible = true
	_collapse_summary_lists()
	if _projection == null:
		_show_invalid("Extraction information is unavailable.")
		return
	var title := get_node("Frame/Content/Header/Title") as Label
	title.text = "Choose up to %d items to extract" % _projection.capacity
	title.accessibility_name = title.text
	_build_cards(_projection.automatic_items, get_node("Frame/Content/Body/Sections/Automatic/Scroll/Items") as Container)
	_build_source_sections(_projection.eligible_source_sections())
	_set_summary_text()
	var automatic_region := get_node("Frame/Content/Body/Sections/Automatic") as Control
	automatic_region.visible = not _projection.automatic_items.is_empty()
	var empty := get_node("Frame/Content/Body/Sections/Eligible/Empty") as Label
	empty.visible = _projection.eligible_items.is_empty()
	(get_node("Frame/Content/Body/Sections/Eligible/Sections") as Control).visible = not _projection.eligible_items.is_empty()
	var changed := get_node("Frame/Content/ChangedNotice") as Label
	changed.text = "Changed items: %s. Review and confirm again." % ", ".join(_projection.changed_item_ids) if not _projection.changed_item_ids.is_empty() else ""
	changed.visible = not changed.text.is_empty()
	changed.accessibility_name = changed.text
	_apply_responsive_layout()
	_update_availability()
	_focus_after_rebuild(prior_item_id, prior_index)

func show_preflight(result: RunResolutionPreflightResult) -> void:
	if result == null:
		_preflight_disposition = PreflightDisposition.FAILURE
		_preflight_category = RunResolutionEvaluation.FailureCategory.INTERNAL
		_preflight_reason = "Resolution readiness is unavailable. Retry resolution."
	elif result.ok():
		_preflight_disposition = PreflightDisposition.VALID
		_preflight_category = RunResolutionEvaluation.FailureCategory.NONE
		_preflight_reason = ""
	else:
		_preflight_disposition = PreflightDisposition.FAILURE
		_preflight_category = result.failure_category
		_preflight_reason = result.player_reason
	_update_availability()

func set_pending(value: bool) -> void:
	_pending = value
	_update_availability()

func show_detail(item: TerminalExtractionItemProjection, anchor: Control) -> void:
	if item == null or anchor == null or not is_instance_valid(anchor):
		return
	_close_warning_without_focus()
	_detail_return_item_id = item.item_id
	_detail_return_focus = anchor
	_set_base_focus_enabled(false)
	var overlay := get_node("ItemTooltipDetail") as Control
	overlay.visible = true
	var tooltip := get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel
	tooltip.force_dismiss()
	tooltip.show_item(item.detail, item.comparisons, anchor, StringName("terminal-extraction:%s" % item.item_id))
	_disable_focus_descendants(overlay)
	var close := get_node("ItemTooltipDetail/Frame/Tooltip/Layout/Header/Close") as Button
	_wire_closed_ring([close])
	close.grab_focus()

func show_unused_capacity_warning(unused_slots: int, lost_count: int, return_focus: Control) -> void:
	_close_detail_without_focus()
	_warning_return_focus = return_focus
	_set_base_focus_enabled(false)
	var warning := get_node("UnusedCapacityWarning") as Control
	warning.visible = true
	var message := get_node("UnusedCapacityWarning/Frame/Padding/Layout/Message") as Label
	message.text = _unused_capacity_warning_text(unused_slots, lost_count)
	message.accessibility_name = message.text
	_disable_focus_descendants(warning)
	var back := get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Back") as Button
	var acknowledge := get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button
	_wire_closed_ring([back, acknowledge])
	back.grab_focus()

func _unused_capacity_warning_text(unused_slots: int, lost_count: int) -> String:
	var safe_unused_slots := maxi(unused_slots, 0)
	var safe_lost_count := maxi(lost_count, 0)
	return "You are leaving %d extraction %s unused. %d %s will be lost." % [
		safe_unused_slots,
		"slot" if safe_unused_slots == 1 else "slots",
		safe_lost_count,
		"item" if safe_lost_count == 1 else "items",
	]

func hide_panel() -> void:
	_force_close_children(false)
	_set_base_focus_enabled(false)
	visible = false
	_projection = null
	_clear_cards()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if (get_node("ItemTooltipDetail") as Control).visible:
		_close_detail()
	elif (get_node("UnusedCapacityWarning") as Control).visible:
		_close_warning()
	else:
		get_viewport().set_input_as_handled()

func _build_source_sections(sections: Array) -> void:
	var parent := get_node("Frame/Content/Body/Sections/Eligible/Sections") as VBoxContainer
	for index: int in sections.size():
		var source: Variant = sections[index]
		var section := VBoxContainer.new()
		section.name = "SourceSection_%02d" % index
		section.add_theme_constant_override(&"separation", 8)
		var heading := Label.new()
		heading.name = "Heading"
		heading.theme_type_variation = &"LivingForgeSectionLabel"
		heading.text = String(source.heading)
		heading.accessibility_name = "Item source: %s" % heading.text
		section.add_child(heading)
		var grid := GridContainer.new()
		grid.name = "Grid"
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override(&"h_separation", 12)
		grid.add_theme_constant_override(&"v_separation", 12)
		section.add_child(grid)
		parent.add_child(section)
		_build_cards(source.items, grid)

func _build_cards(items: Array[TerminalExtractionItemProjection], parent: Container) -> void:
	for item: TerminalExtractionItemProjection in items:
		var card := ITEM_CARD_SCENE.instantiate() as ForgeExtractionItemCard
		parent.add_child(card)
		card.present(item)
		card.apply_accessibility_variant(_high_contrast)
		card.item_toggle_requested.connect(_on_card_toggle)
		card.inspect_requested.connect(_on_card_inspect)
		card.focus_entered.connect(_ensure_card_visible.bind(card))
		var inspect := card.get_node("Content/Footer/Inspect") as Button
		inspect.focus_entered.connect(_ensure_card_visible.bind(card))
		_cards_by_id[item.item_id] = card
		_details_by_id[item.item_id] = item.copy()

func _clear_cards() -> void:
	for child: Node in (get_node("Frame/Content/Body/Sections/Automatic/Scroll/Items") as Container).get_children():
		child.free()
	for child: Node in (get_node("Frame/Content/Body/Sections/Eligible/Sections") as Container).get_children():
		child.free()
	_cards_by_id.clear()
	_details_by_id.clear()

func _set_summary_text() -> void:
	var automatic := get_node("Frame/Content/Summary/Automatic") as Label
	var selected := get_node("Frame/Content/Summary/Selected") as Label
	var lost := get_node("Frame/Content/Summary/Lost") as Label
	automatic.text = "Automatic %d" % _projection.automatic_count
	selected.text = "Selected %d / %d" % [_projection.selected_count, _projection.capacity]
	lost.text = "Will be lost %d" % _projection.lost_count
	for label: Label in [automatic, selected, lost]:
		label.accessibility_name = label.text
	(get_node("Frame/Content/Body/Sections/SummaryLists/AutomaticItems") as Label).text = _names(_projection.automatic_items)
	(get_node("Frame/Content/Body/Sections/SummaryLists/SelectedItems") as Label).text = _names_for_ids(_projection.selected_item_ids)
	(get_node("Frame/Content/Body/Sections/SummaryLists/LostItems") as Label).text = _names_for_ids(_projection.lost_item_ids)

func _update_availability() -> void:
	var focus_intent := _capture_availability_focus_intent()
	var projection_ok := _projection != null and _projection.valid and _projection.player_error.is_empty()
	var preflight_failed := _preflight_disposition == PreflightDisposition.FAILURE
	var confirm := get_node("Frame/Content/Actions/Confirm") as Button
	confirm.disabled = _pending or not projection_ok or preflight_failed
	confirm.text = "RESOLVING" if _pending else "CONFIRM EXTRACTION"
	var retry := get_node("Frame/Content/Actions/Retry") as Button
	retry.visible = preflight_failed and _preflight_category in [RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, RunResolutionEvaluation.FailureCategory.INTERNAL]
	retry.disabled = _pending
	var player_error := get_node("Frame/Content/PlayerError") as Label
	player_error.text = _preflight_reason if preflight_failed else (_projection.player_error if _projection != null else "Extraction information is unavailable.")
	player_error.visible = not player_error.text.is_empty()
	player_error.accessibility_name = player_error.text
	var pending_label := get_node("Frame/Content/Pending") as Label
	pending_label.visible = true
	pending_label.text = "RESOLVING · PLEASE WAIT" if _pending else ""
	pending_label.accessibility_name = pending_label.text
	var selection_can_recover := preflight_failed and _preflight_category == RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE
	for card_value: Variant in _cards_by_id.values():
		var card := card_value as ForgeExtractionItemCard
		card.set_pending(_pending)
		card.set_interaction_locked(not projection_ok or (preflight_failed and not selection_can_recover))
	if (get_node("ItemTooltipDetail") as Control).visible or (get_node("UnusedCapacityWarning") as Control).visible:
		_set_base_focus_enabled(false)
	else:
		_configure_base_focus_scope()
		_resolve_availability_focus(focus_intent, projection_ok and not _pending and (not preflight_failed or selection_can_recover))
		if _pending:
			call_deferred(&"_restore_automatic_origin")

func _configure_base_focus_scope() -> void:
	var prior_focus := get_viewport().gui_get_focus_owner() as Control if is_inside_tree() else null
	var restore_prior := prior_focus != null and (prior_focus == self or is_ancestor_of(prior_focus))
	_set_base_focus_enabled(false)
	var controls := _base_focus_ring_controls()
	_wire_closed_ring(controls)
	if restore_prior and _control_is_focusable(prior_focus):
		prior_focus.grab_focus()

func _base_focus_ring_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _projection != null:
		for item: TerminalExtractionItemProjection in _projection.eligible_items:
			var card := _cards_by_id.get(item.item_id) as ForgeExtractionItemCard
			if card == null:
				continue
			if not card.disabled:
				controls.append(card)
			var inspect := card.get_node("Content/Footer/Inspect") as Button
			if not inspect.disabled:
				controls.append(inspect)
	for control: Control in [get_node("Frame/Content/Actions/Retry") as Button, get_node("Frame/Content/Actions/Confirm") as Button]:
		if control.visible and not (control as Button).disabled:
			controls.append(control)
	for path: NodePath in [^"Frame/Content/Summary/AutomaticList", ^"Frame/Content/Summary/SelectedList", ^"Frame/Content/Summary/LostList"]:
		controls.append(get_node(path) as Button)
	if _projection != null:
		for item: TerminalExtractionItemProjection in _projection.automatic_items:
			var card := _cards_by_id.get(item.item_id) as ForgeExtractionItemCard
			if card != null:
				var inspect := card.get_node("Content/Footer/Inspect") as Button
				if not inspect.disabled:
					controls.append(inspect)
	return controls

func _capture_availability_focus_intent() -> Dictionary:
	if not is_inside_tree():
		return {}
	var owner := get_viewport().gui_get_focus_owner() as Control
	if owner == null or not (owner == self or is_ancestor_of(owner)):
		return {}
	var item_id := ""
	var cursor: Node = owner
	while cursor != null and cursor != self:
		if cursor.has_meta(&"item_id"):
			item_id = String(cursor.get_meta(&"item_id", ""))
			break
		cursor = cursor.get_parent()
	return {"control": owner, "item_id": item_id, "eligible_index": _eligible_index(item_id)}

func _resolve_availability_focus(intent: Dictionary, selection_editable: bool) -> void:
	var retry := get_node("Frame/Content/Actions/Retry") as Button
	if _control_is_focusable(retry):
		retry.grab_focus()
		return
	var prior := intent.get("control") as Control
	if _control_is_focusable(prior):
		prior.grab_focus()
		return
	if selection_editable:
		var item_id := String(intent.get("item_id", ""))
		if not item_id.is_empty():
			var exact := _cards_by_id.get(item_id) as Control
			if _restore_control_focus(exact):
				return
			var eligible := _eligible_card_controls()
			var prior_index := int(intent.get("eligible_index", -1))
			if prior_index >= 0 and not eligible.is_empty() and _restore_control_focus(eligible[clampi(prior_index, 0, eligible.size() - 1)]):
				return
	var confirm := get_node("Frame/Content/Actions/Confirm") as Button
	if _restore_control_focus(confirm):
		return
	for control: Control in _base_focus_ring_controls():
		if _restore_control_focus(control):
			return

func _control_is_focusable(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	return not (control is BaseButton and (control as BaseButton).disabled)

func _all_base_controls() -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in (get_node("Frame") as Control).find_children("*", "Button", true, false):
		result.append(node as Control)
	return result

func _set_base_focus_enabled(value: bool) -> void:
	if not value:
		for control: Control in _all_base_controls():
			control.focus_mode = Control.FOCUS_NONE
	else:
		_configure_base_focus_scope()

func _wire_closed_ring(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for index: int in controls.size():
		var current := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		current.focus_mode = Control.FOCUS_ALL
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(next)
		current.focus_neighbor_left = current.get_path_to(previous)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_neighbor_bottom = current.get_path_to(next)

func _disable_focus_descendants(scope: Control) -> void:
	for node: Node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if control.has_focus():
			control.release_focus()
		control.focus_mode = Control.FOCUS_NONE

func _ensure_card_visible(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	get_tree().create_timer(0.0, true, false, true).timeout.connect(_ensure_card_visible_now.bind(card.get_instance_id()), CONNECT_ONE_SHOT)

func _ensure_card_visible_now(card_instance_id: int) -> void:
	var card := instance_from_id(card_instance_id) as Control
	if card == null or not is_instance_valid(card) or not card.is_inside_tree():
		return
	var body_scroll := get_node("Frame/Content/Body") as ScrollContainer
	var automatic_scroll := get_node("Frame/Content/Body/Sections/Automatic/Scroll") as ScrollContainer
	if automatic_scroll.is_ancestor_of(card):
		if card.get_index() == 0:
			automatic_scroll.scroll_horizontal = 0
		else:
			automatic_scroll.ensure_control_visible(card)
		body_scroll.ensure_control_visible(card)
	elif body_scroll.is_ancestor_of(card):
		body_scroll.ensure_control_visible(card)

func _restore_automatic_origin() -> void:
	if not is_inside_tree():
		return
	var body := get_node("Frame/Content/Body") as ScrollContainer
	var automatic_scroll := get_node("Frame/Content/Body/Sections/Automatic/Scroll") as ScrollContainer
	automatic_scroll.scroll_horizontal = 0
	var items := get_node("Frame/Content/Body/Sections/Automatic/Scroll/Items") as Container
	if items.get_child_count() > 0:
		body.ensure_control_visible(items.get_child(0) as Control)

func _apply_responsive_layout() -> void:
	var width := 1280.0
	if is_inside_tree():
		width = get_viewport_rect().size.x
	var columns := 2 if _text_scale_percent >= 125 or width < 1500.0 else 4
	var ui_scale := float(_ui_scale_percent) / 100.0
	var text_scale := float(_text_scale_percent) / 100.0
	var card_width := maxf(248.0 * ui_scale, 248.0 + maxf(text_scale - 1.0, 0.0) * 104.0)
	var card_height := maxf(176.0 * ui_scale, 176.0 + maxf(text_scale - 1.0, 0.0) * 72.0)
	for card_value: Variant in _cards_by_id.values():
		var card := card_value as Control
		var content := card.get_node("Content") as Control
		var contained_width := content.get_combined_minimum_size().x + 32.0
		card.custom_minimum_size = Vector2(maxf(card_width, contained_width), card_height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if card.get_parent() is GridContainer else Control.SIZE_FILL
	for grid_node: Node in (get_node("Frame/Content/Body/Sections/Eligible/Sections") as Control).find_children("Grid", "GridContainer", true, false):
		(grid_node as GridContainer).columns = columns
	(get_node("Frame/Content/Body/Sections/Automatic/Scroll") as Control).custom_minimum_size.y = card_height + 16.0
	var inset := 16.0 if width <= 1280.0 else 32.0
	var frame := get_node("Frame") as Control
	frame.offset_left = inset
	frame.offset_top = 12.0
	frame.offset_right = -inset
	frame.offset_bottom = -12.0

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	if visible and not (get_node("ItemTooltipDetail") as Control).visible and not (get_node("UnusedCapacityWarning") as Control).visible:
		_configure_base_focus_scope()

func _focus_after_rebuild(prior_item_id: String, prior_index: int) -> void:
	if not prior_item_id.is_empty():
		var exact := _cards_by_id.get(prior_item_id) as Control
		if _restore_control_focus(exact):
			return
		var eligible := _eligible_card_controls()
		if prior_index >= 0 and not eligible.is_empty() and _restore_control_focus(eligible[clampi(prior_index, 0, eligible.size() - 1)]):
			return
	_focus_initial()

func _focus_initial() -> void:
	for card: Control in _eligible_card_controls():
		if _restore_control_focus(card):
			return
	for control: Control in _base_focus_controls_in_order():
		if _restore_control_focus(control):
			return

func _eligible_card_controls() -> Array[Control]:
	var result: Array[Control] = []
	if _projection != null:
		for item: TerminalExtractionItemProjection in _projection.eligible_items:
			var card := _cards_by_id.get(item.item_id) as Control
			if card != null:
				result.append(card)
	return result

func _base_focus_controls_in_order() -> Array[Control]:
	return _base_focus_ring_controls()

func _focused_item_id() -> String:
	if not is_inside_tree():
		return ""
	var owner := get_viewport().gui_get_focus_owner() as Control
	var cursor: Node = owner
	while cursor != null and cursor != self:
		if cursor.has_meta(&"item_id"):
			return String(cursor.get_meta(&"item_id", ""))
		cursor = cursor.get_parent()
	return ""

func _eligible_index(item_id: String) -> int:
	if _projection == null or item_id.is_empty():
		return -1
	var items := _projection.eligible_items
	for index: int in items.size():
		if items[index].item_id == item_id:
			return index
	return -1

func _restore_item_focus(item_id: String, fallback: Control) -> void:
	var card := _cards_by_id.get(item_id) as Control
	if _restore_control_focus(card):
		return
	if _restore_control_focus(fallback):
		return
	_focus_initial()

func _restore_control_focus(control: Control) -> bool:
	if not _control_is_focusable(control):
		return false
	control.grab_focus()
	return true

func _on_card_toggle(item_id: String) -> void:
	if not _pending:
		item_toggle_requested.emit(item_id)

func _on_card_inspect(item_id: String, anchor: Control) -> void:
	inspect_requested.emit(item_id, anchor)

func _on_confirm() -> void:
	var confirm := get_node("Frame/Content/Actions/Confirm") as Button
	if not confirm.disabled:
		confirm_requested.emit()

func _on_retry() -> void:
	var retry := get_node("Frame/Content/Actions/Retry") as Button
	if not retry.disabled:
		retry_resolution_requested.emit()

func _on_warning_acknowledged() -> void:
	if _pending:
		return
	unused_capacity_acknowledged.emit()
	_close_warning()

func _close_detail() -> void:
	var item_id := _detail_return_item_id
	var fallback := _detail_return_focus
	_close_detail_without_focus()
	_configure_base_focus_scope()
	_restore_item_focus(item_id, fallback)

func _close_detail_without_focus() -> void:
	(get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel).force_dismiss()
	var overlay := get_node("ItemTooltipDetail") as Control
	_disable_focus_descendants(overlay)
	overlay.visible = false
	_detail_return_item_id = ""
	_detail_return_focus = null

func _close_warning() -> void:
	var fallback := _warning_return_focus
	_close_warning_without_focus()
	_configure_base_focus_scope()
	if not _restore_control_focus(fallback):
		_focus_initial()

func _close_warning_without_focus() -> void:
	var warning := get_node("UnusedCapacityWarning") as Control
	_disable_focus_descendants(warning)
	warning.visible = false
	_warning_return_focus = null

func _force_close_children(_restore_focus: bool) -> void:
	_close_detail_without_focus()
	_close_warning_without_focus()

func _toggle_list(button: Button, target: Control) -> void:
	target.visible = not target.visible
	button.text = ("HIDE " if target.visible else "SHOW ") + String(button.get_meta(&"label", "LIST"))
	button.accessibility_name = "%s, %s" % [String(button.get_meta(&"label", "List")), "expanded" if target.visible else "collapsed"]
	_apply_responsive_layout()
	_configure_base_focus_scope()
	if target.visible:
		(get_node("Frame/Content/Body") as ScrollContainer).call_deferred(&"ensure_control_visible", target)

func _collapse_summary_lists() -> void:
	for pair: Array in [
		[get_node("Frame/Content/Summary/AutomaticList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/AutomaticItems") as Control],
		[get_node("Frame/Content/Summary/SelectedList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/SelectedItems") as Control],
		[get_node("Frame/Content/Summary/LostList") as Button, get_node("Frame/Content/Body/Sections/SummaryLists/LostItems") as Control],
	]:
		var button := pair[0] as Button
		var target := pair[1] as Control
		target.visible = false
		button.text = "SHOW " + String(button.get_meta(&"label", "LIST"))
		button.accessibility_name = "%s, collapsed" % String(button.get_meta(&"label", "List"))

func _show_invalid(reason: String) -> void:
	_preflight_disposition = PreflightDisposition.FAILURE
	_preflight_category = RunResolutionEvaluation.FailureCategory.INTERNAL
	_preflight_reason = reason
	_update_availability()

func _names(items: Array[TerminalExtractionItemProjection]) -> String:
	var result: Array[String] = []
	for item: TerminalExtractionItemProjection in items:
		result.append(item.consequence_label)
	return "None" if result.is_empty() else "\n".join(result)

func _names_for_ids(ids: Array[String]) -> String:
	var result: Array[String] = []
	for item_id: String in ids:
		var item := _details_by_id.get(item_id) as TerminalExtractionItemProjection
		result.append(item.consequence_label if item != null else "Unavailable item · %s" % item_id)
	return "None" if result.is_empty() else "\n".join(result)
