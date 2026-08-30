class_name TerminalExtractionPanel
extends Control

signal item_toggle_requested(item_id: String)
signal inspect_requested(item_id: String, anchor: Control)
signal confirm_requested
signal unused_capacity_acknowledged
signal retry_resolution_requested

const ITEM_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_extraction_item_card.tscn")

var _projection: TerminalExtractionProjection
var _cards_by_id: Dictionary = {}
var _details_by_id: Dictionary = {}
var _detail_return_item_id := ""
var _detail_return_focus: Control
var _warning_return_focus: Control
var _pending := false
var _high_contrast := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_controls()

func _connect_controls() -> void:
	var confirm := get_node("Frame/Content/Actions/Confirm") as Button
	var retry := get_node("Frame/Content/Actions/Retry") as Button
	var detail_close := get_node("ItemTooltipDetail/Frame/Close") as Button
	var warning_back := get_node("UnusedCapacityWarning/Frame/Actions/Back") as Button
	var warning_ack := get_node("UnusedCapacityWarning/Frame/Actions/Acknowledge") as Button
	if not confirm.pressed.is_connected(_on_confirm): confirm.pressed.connect(_on_confirm)
	if not retry.pressed.is_connected(_on_retry): retry.pressed.connect(_on_retry)
	if not detail_close.pressed.is_connected(_close_detail): detail_close.pressed.connect(_close_detail)
	if not warning_back.pressed.is_connected(_close_warning): warning_back.pressed.connect(_close_warning)
	if not warning_ack.pressed.is_connected(_on_warning_acknowledged): warning_ack.pressed.connect(_on_warning_acknowledged)
	for pair: Array in [
		[get_node("Frame/Content/Summary/AutomaticList") as Button, get_node("Frame/Content/SummaryLists/AutomaticItems") as Control],
		[get_node("Frame/Content/Summary/SelectedList") as Button, get_node("Frame/Content/SummaryLists/SelectedItems") as Control],
		[get_node("Frame/Content/Summary/LostList") as Button, get_node("Frame/Content/SummaryLists/LostItems") as Control],
	]:
		var button := pair[0] as Button
		var target := pair[1] as Control
		if not button.pressed.is_connected(_toggle_list.bind(button, target)):
			button.pressed.connect(_toggle_list.bind(button, target))

func apply_visual_settings(settings: PartyForgeSettings) -> void:
	var resolved := settings if settings != null else PartyForgeSettings.new()
	_high_contrast = resolved.high_contrast
	theme = LivingForgeThemeCatalog.resolve(_high_contrast, resolved.ui_scale_percent, resolved.text_scale_percent)
	for card: Variant in _cards_by_id.values():
		(card as ForgeExtractionItemCard).apply_accessibility_variant(_high_contrast)

func present(projection: TerminalExtractionProjection) -> void:
	_connect_controls()
	_force_close_children(false)
	_clear_cards()
	_projection = projection.copy() if projection != null else null
	_pending = projection.pending if projection != null else false
	visible = true
	if _projection == null:
		_show_invalid("Extraction information is unavailable.")
		return
	(get_node("Frame/Content/Header/Title") as Label).text = "Choose up to %d items to extract" % _projection.capacity
	(get_node("Frame/Content/Header/Title") as Label).accessibility_name = (get_node("Frame/Content/Header/Title") as Label).text
	(get_node("Frame/Content/Summary/Automatic") as Label).text = "Automatic %d" % _projection.automatic_count
	(get_node("Frame/Content/Summary/Selected") as Label).text = "Selected %d / %d" % [_projection.selected_count, _projection.capacity]
	(get_node("Frame/Content/Summary/Lost") as Label).text = "Will be lost %d" % _projection.lost_count
	(get_node("Frame/Content/SummaryLists/AutomaticItems") as Label).text = _names(_projection.automatic_items)
	(get_node("Frame/Content/SummaryLists/SelectedItems") as Label).text = _names_for_ids(_projection.selected_item_ids)
	(get_node("Frame/Content/SummaryLists/LostItems") as Label).text = _names_for_ids(_projection.lost_item_ids)
	_build_cards(_projection.automatic_items, get_node("Frame/Content/Body/Automatic/Items") as Container)
	_build_cards(_projection.eligible_items, get_node("Frame/Content/Body/Eligible/Scroll/Grid") as Container)
	var empty := get_node("Frame/Content/Body/Eligible/Empty") as Label
	empty.visible = _projection.eligible_items.is_empty()
	(get_node("Frame/Content/Body/Eligible/Scroll") as Control).visible = not _projection.eligible_items.is_empty()
	var player_error := get_node("Frame/Content/PlayerError") as Label
	player_error.text = _projection.player_error
	player_error.visible = not player_error.text.is_empty()
	var changed := get_node("Frame/Content/ChangedNotice") as Label
	changed.text = "Changed items: %s. Review and confirm again." % ", ".join(_projection.changed_item_ids) if not _projection.changed_item_ids.is_empty() else ""
	changed.visible = not changed.text.is_empty()
	_update_actions()
	_configure_focus_graph()
	_focus_initial()

func show_preflight(result: RunResolutionPreflightResult) -> void:
	var label := get_node("Frame/Content/PlayerError") as Label
	if result == null:
		label.text = "Resolution readiness is unavailable. Retry resolution."
		label.visible = true
		(get_node("Frame/Content/Actions/Confirm") as Button).disabled = true
		return
	label.text = result.player_reason
	label.visible = not label.text.is_empty()
	label.accessibility_name = label.text
	var retry := get_node("Frame/Content/Actions/Retry") as Button
	retry.visible = result.failure_category == RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY or result.failure_category == RunResolutionEvaluation.FailureCategory.INTERNAL
	(get_node("Frame/Content/Actions/Confirm") as Button).disabled = not result.ok()

func set_pending(value: bool) -> void:
	_pending = value
	var status := get_node("Frame/Content/Pending") as Label
	status.visible = value
	status.text = "RESOLVING · PLEASE WAIT" if value else ""
	for card: Variant in _cards_by_id.values(): (card as ForgeExtractionItemCard).set_pending(value)
	_update_actions()

func show_detail(item: TerminalExtractionItemProjection, anchor: Control) -> void:
	if item == null or anchor == null or not is_instance_valid(anchor): return
	_detail_return_item_id = item.item_id
	_detail_return_focus = anchor
	var overlay := get_node("ItemTooltipDetail") as Control
	overlay.visible = true
	var tooltip := get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel
	tooltip.force_dismiss()
	tooltip.show_item(item.detail, item.comparisons, anchor, StringName("terminal-extraction:%s" % item.item_id))
	(get_node("ItemTooltipDetail/Frame/Close") as Button).grab_focus()

func show_unused_capacity_warning(unused_slots: int, lost_count: int, return_focus: Control) -> void:
	_warning_return_focus = return_focus
	var warning := get_node("UnusedCapacityWarning") as Control
	warning.visible = true
	var message := get_node("UnusedCapacityWarning/Frame/Message") as Label
	message.text = "You are leaving %d extraction slots unused. %d items will be lost." % [maxi(unused_slots, 0), maxi(lost_count, 0)]
	message.accessibility_name = message.text
	(get_node("UnusedCapacityWarning/Frame/Actions/Back") as Button).grab_focus()

func hide_panel() -> void:
	_force_close_children(false)
	visible = false
	_projection = null
	_clear_cards()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"): return
	if (get_node("ItemTooltipDetail") as Control).visible:
		_close_detail()
	elif (get_node("UnusedCapacityWarning") as Control).visible:
		_close_warning()
	else:
		# Terminal state has no route back to combat. Consume Cancel.
		get_viewport().set_input_as_handled()

func _build_cards(items: Array[TerminalExtractionItemProjection], parent: Container) -> void:
	for item: TerminalExtractionItemProjection in items:
		var card := ITEM_CARD_SCENE.instantiate() as ForgeExtractionItemCard
		parent.add_child(card)
		card.present(item)
		card.apply_accessibility_variant(_high_contrast)
		card.item_toggle_requested.connect(_on_card_toggle)
		card.inspect_requested.connect(_on_card_inspect)
		card.focus_entered.connect(_ensure_card_visible.bind(card))
		_cards_by_id[item.item_id] = card
		_details_by_id[item.item_id] = item.copy()

func _ensure_card_visible(card: Control) -> void:
	if card == null or not is_instance_valid(card): return
	var scroll := get_node("Frame/Content/Body/Eligible/Scroll") as ScrollContainer
	scroll.call_deferred(&"ensure_control_visible", card)

func _clear_cards() -> void:
	for path: NodePath in [^"Frame/Content/Body/Automatic/Items", ^"Frame/Content/Body/Eligible/Scroll/Grid"]:
		var parent := get_node(path) as Container
		for child: Node in parent.get_children(): child.free()
	_cards_by_id.clear()
	_details_by_id.clear()

func _on_card_toggle(item_id: String) -> void:
	if _pending: return
	item_toggle_requested.emit(item_id)

func _on_card_inspect(item_id: String, anchor: Control) -> void:
	inspect_requested.emit(item_id, anchor)

func _on_confirm() -> void:
	if _pending or (get_node("Frame/Content/Actions/Confirm") as Button).disabled: return
	confirm_requested.emit()

func _on_retry() -> void:
	if _pending: return
	retry_resolution_requested.emit()

func _on_warning_acknowledged() -> void:
	if _pending: return
	unused_capacity_acknowledged.emit()
	_close_warning()

func _close_detail() -> void:
	(get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel).force_dismiss()
	(get_node("ItemTooltipDetail") as Control).visible = false
	_restore_item_focus(_detail_return_item_id, _detail_return_focus)
	_detail_return_item_id = ""
	_detail_return_focus = null

func _close_warning() -> void:
	(get_node("UnusedCapacityWarning") as Control).visible = false
	_restore_control_focus(_warning_return_focus)
	_warning_return_focus = null

func _force_close_children(restore_focus: bool) -> void:
	(get_node("ItemTooltipDetail/Frame/Tooltip") as ItemTooltipPanel).force_dismiss()
	(get_node("ItemTooltipDetail") as Control).visible = false
	(get_node("UnusedCapacityWarning") as Control).visible = false
	if restore_focus:
		_restore_item_focus(_detail_return_item_id, _detail_return_focus)
	_detail_return_item_id = ""
	_detail_return_focus = null
	_warning_return_focus = null

func _restore_item_focus(item_id: String, fallback: Control) -> void:
	var card := _cards_by_id.get(item_id) as Control
	if _restore_control_focus(card): return
	if _restore_control_focus(fallback): return
	_focus_initial()

func _restore_control_focus(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: return false
	control.grab_focus()
	return true

func _update_actions() -> void:
	var confirm := get_node("Frame/Content/Actions/Confirm") as Button
	confirm.disabled = _pending or _projection == null or not _projection.valid or not _projection.player_error.is_empty()
	confirm.text = "RESOLVING" if _pending else "CONFIRM EXTRACTION"

func _show_invalid(reason: String) -> void:
	var label := get_node("Frame/Content/PlayerError") as Label
	label.text = reason
	label.visible = true
	(get_node("Frame/Content/Actions/Confirm") as Button).disabled = true

func _configure_focus_graph() -> void:
	var cards: Array[Control] = []
	if _projection != null:
		for item: TerminalExtractionItemProjection in _projection.eligible_items:
			var card := _cards_by_id.get(item.item_id) as Control
			if card != null: cards.append(card)
	var footer: Array[Control] = [get_node("Frame/Content/Actions/Retry") as Control, get_node("Frame/Content/Actions/Confirm") as Control]
	footer = footer.filter(func(control: Control) -> bool: return control.visible and not (control as BaseButton).disabled)
	for index: int in cards.size():
		var previous := cards[index - 1] if index > 0 else (footer[-1] if not footer.is_empty() else cards[-1])
		var next := cards[index + 1] if index + 1 < cards.size() else (footer[0] if not footer.is_empty() else cards[0])
		cards[index].focus_previous = cards[index].get_path_to(previous)
		cards[index].focus_next = cards[index].get_path_to(next)
		cards[index].focus_neighbor_left = cards[index].get_path_to(previous)
		cards[index].focus_neighbor_right = cards[index].get_path_to(next)
	if not cards.is_empty():
		for index: int in footer.size():
			var previous := cards[-1] if index == 0 else footer[index - 1]
			footer[index].focus_previous = footer[index].get_path_to(previous)
			footer[index].focus_next = footer[index].get_path_to(cards[0] if index + 1 == footer.size() else footer[index + 1])
			footer[index].focus_neighbor_left = footer[index].get_path_to(previous)
			footer[index].focus_neighbor_top = footer[index].get_path_to(cards[-1])

func _focus_initial() -> void:
	if _projection != null:
		for item: TerminalExtractionItemProjection in _projection.eligible_items:
			var card := _cards_by_id.get(item.item_id) as Control
			if _restore_control_focus(card): return
	_restore_control_focus(get_node("Frame/Content/Actions/Confirm") as Control)

func _toggle_list(button: Button, target: Control) -> void:
	target.visible = not target.visible
	button.text = ("HIDE " if target.visible else "SHOW ") + String(button.get_meta(&"label", "LIST"))
	button.accessibility_name = "%s, %s" % [String(button.get_meta(&"label", "List")), "expanded" if target.visible else "collapsed"]

func _names(items: Array[TerminalExtractionItemProjection]) -> String:
	var result: Array[String] = []
	for item: TerminalExtractionItemProjection in items: result.append(item.name)
	return "None" if result.is_empty() else " · ".join(result)

func _names_for_ids(ids: Array[String]) -> String:
	var result: Array[String] = []
	for item_id: String in ids:
		var item := _details_by_id.get(item_id) as TerminalExtractionItemProjection
		result.append(item.name if item != null else item_id)
	return "None" if result.is_empty() else " · ".join(result)
