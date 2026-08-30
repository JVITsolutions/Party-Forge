class_name CombatAlertTray
extends CanvasLayer

signal inspect_requested(member_id: int, return_focus: Control)
signal ledger_requested(member_id: int, return_focus: Control)
signal closed(return_focus: Control)
signal alerts_resolved(message: String)

const ALERT_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_alert_card.tscn")

var _pause_lease := RunPauseLease.new()
var _return_focus: WeakRef
var _cards_by_id: Dictionary = {}
var _alerts: Array[CombatAlertProjection] = []
var _high_contrast := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var close_button := get_node("Overlay/Frame/Layout/Close") as Button
	if not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	for card_value: Variant in _cards_by_id.values():
		(card_value as ForgeAlertCard).apply_accessibility_variant(high_contrast)


func open(all_alerts: Array[CombatAlertProjection], return_focus: Control) -> void:
	var was_open := visible
	var focused := _focus_descriptor()
	var prior_index := _index_for_stable_id(StringName(focused.get("stable_id", &"")))
	var next_alerts: Array[CombatAlertProjection] = []
	for alert: CombatAlertProjection in all_alerts:
		if alert != null and alert.validate().is_empty():
			next_alerts.append(alert.copy())
	if next_alerts.is_empty():
		if was_open:
			alerts_resolved.emit("All alerts resolved.")
			close()
		return
	if not was_open:
		_return_focus = weakref(return_focus) if return_focus != null else null
		_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
		visible = true
	_present(next_alerts)
	if was_open:
		_restore_refresh_focus(focused, prior_index)
	else:
		_focus_card(mini(CombatHudProjection.MAX_VISIBLE_ALERTS, _alerts.size() - 1), &"root")


func close() -> void:
	if not visible:
		return
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)
	var target := _return_focus.get_ref() as Control if _return_focus != null else null
	_return_focus = null
	if _focus_is_valid(target):
		target.grab_focus()
	closed.emit(target)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _present(next_alerts: Array[CombatAlertProjection]) -> void:
	var wanted: Dictionary = {}
	for alert: CombatAlertProjection in next_alerts:
		wanted[alert.stable_id] = true
	for stable_value: Variant in _cards_by_id.keys():
		var stable_id := StringName(stable_value)
		if wanted.has(stable_id):
			continue
		var stale := _cards_by_id[stable_id] as ForgeAlertCard
		_cards_by_id.erase(stable_id)
		stale.free()
	var list := _alert_list()
	for index: int in next_alerts.size():
		var alert := next_alerts[index]
		var card := _cards_by_id.get(alert.stable_id) as ForgeAlertCard
		if card == null:
			card = ALERT_CARD_SCENE.instantiate() as ForgeAlertCard
			_cards_by_id[alert.stable_id] = card
			list.add_child(card)
			card.inspect_requested.connect(_on_card_inspect_requested.bind(card))
			card.ledger_requested.connect(_on_card_ledger_requested.bind(card))
		card.set_meta(&"stable_alert_id", alert.stable_id)
		card.set_meta(&"member_id", alert.member_id)
		card.present_alert(alert)
		card.apply_accessibility_variant(_high_contrast)
		list.move_child(card, index)
	_alerts.clear()
	for alert: CombatAlertProjection in next_alerts:
		_alerts.append(alert.copy())
	(get_node("Overlay/Frame/Layout/Count") as Label).text = "%d CURRENT ALERTS" % _alerts.size()
	_configure_focus_neighbors()


func _restore_refresh_focus(descriptor: Dictionary, prior_index: int) -> void:
	var stable_id := StringName(descriptor.get("stable_id", &""))
	if _cards_by_id.has(stable_id):
		_focus_card(_index_for_stable_id(stable_id), StringName(descriptor.get("action", &"root")))
		return
	if not _alerts.is_empty():
		_focus_card(clampi(prior_index, 0, _alerts.size() - 1), &"root")
		return
	var close_button := get_node("Overlay/Frame/Layout/Close") as Button
	if close_button.is_inside_tree():
		close_button.grab_focus()


func _focus_descriptor() -> Dictionary:
	var owner := get_viewport().gui_get_focus_owner() as Control if is_inside_tree() else null
	if owner == null or not is_ancestor_of(owner):
		return {"stable_id": &"", "action": &"root"}
	var cursor: Node = owner
	while cursor != null and cursor.get_parent() != _alert_list():
		cursor = cursor.get_parent()
	var card := cursor as ForgeAlertCard
	if card == null:
		return {"stable_id": &"", "action": &"root"}
	var action: StringName = &"root"
	if owner == card.get_node("Surface/Content/Actions/Inspect"):
		action = &"inspect"
	elif owner == card.get_node("Surface/Content/Actions/Ledger"):
		action = &"ledger"
	return {"stable_id": StringName(card.get_meta("stable_alert_id", &"")), "action": action}


func _focus_card(index: int, action: StringName) -> void:
	if index < 0 or index >= _alerts.size():
		var close_button := get_node("Overlay/Frame/Layout/Close") as Button
		if close_button.is_inside_tree():
			close_button.grab_focus()
		return
	var alert := _alerts[index]
	var card := _cards_by_id.get(alert.stable_id) as ForgeAlertCard
	if card == null:
		return
	var target: Control = card
	if action == &"inspect":
		var inspect := card.get_node("Surface/Content/Actions/Inspect") as Button
		if inspect.visible and not inspect.disabled:
			target = inspect
	elif action == &"ledger":
		var ledger := card.get_node("Surface/Content/Actions/Ledger") as Button
		if ledger.visible and not ledger.disabled:
			target = ledger
	_scroll().ensure_control_visible(card)
	if target.is_inside_tree():
		target.grab_focus()


func _configure_focus_neighbors() -> void:
	var cards: Array[Control] = []
	for alert: CombatAlertProjection in _alerts:
		var card := _cards_by_id.get(alert.stable_id) as Control
		if card != null:
			cards.append(card)
	var close_button := get_node("Overlay/Frame/Layout/Close") as Button
	for index: int in cards.size():
		var card := cards[index]
		card.focus_neighbor_top = card.get_path_to(cards[index - 1] if index > 0 else close_button)
		card.focus_neighbor_bottom = card.get_path_to(cards[index + 1] if index + 1 < cards.size() else close_button)
	if not cards.is_empty():
		close_button.focus_neighbor_top = close_button.get_path_to(cards[-1])
		close_button.focus_neighbor_bottom = close_button.get_path_to(cards[0])


func _index_for_stable_id(stable_id: StringName) -> int:
	for index: int in _alerts.size():
		if _alerts[index].stable_id == stable_id:
			return index
	return 0


func _on_card_inspect_requested(member_id: int, card: ForgeAlertCard) -> void:
	var action := card.get_node("Surface/Content/Actions/Inspect") as Control
	inspect_requested.emit(member_id, action)


func _on_card_ledger_requested(member_id: int, card: ForgeAlertCard) -> void:
	var action := card.get_node("Surface/Content/Actions/Ledger") as Control
	ledger_requested.emit(member_id, action)


func _focus_is_valid(target: Control) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	)


func _alert_list() -> VBoxContainer:
	return get_node("Overlay/Frame/Layout/Scroll/Alerts") as VBoxContainer


func _scroll() -> ScrollContainer:
	return get_node("Overlay/Frame/Layout/Scroll") as ScrollContainer
