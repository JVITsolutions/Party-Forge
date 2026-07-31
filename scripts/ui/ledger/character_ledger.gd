class_name CharacterLedger
extends CanvasLayer

const DEFAULT_PAGE_CATALOG: LedgerPageCatalog = preload("res://data/ui/ledger_pages/default_ledger_pages.tres")
const REQUIRED_PAGE_IDS: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]

var run: GameRun
var party: PartyManager
var catalog: GameCatalog
var provider: LedgerDataProvider
var context: LedgerPlayerContext

var _contexts: Dictionary = {}
var _definitions: Dictionary = {}
var _pages: Dictionary = {}
var _available_page_ids: Array[StringName] = []
var _member_buttons: Dictionary = {}
var _active_page_id: StringName
var _pause_lease := RunPauseLease.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if _pause_lease != null and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)
	_disconnect_provider()

func configure(
	game_run: GameRun,
	manager: PartyManager,
	game_catalog: GameCatalog,
	health_provider: Callable,
	initial_contexts: Array[LedgerPlayerContext] = []
) -> void:
	if is_open():
		close()
	_disconnect_provider()
	_clear_dynamic_ui()
	run = game_run
	party = manager
	catalog = game_catalog
	_contexts.clear()
	for supplied_context: LedgerPlayerContext in initial_contexts:
		if supplied_context == null:
			continue
		if _contexts.has(supplied_context.local_player_id):
			push_error("PARTY_FORGE_LEDGER_ERROR player=%d reason=duplicate player context" % supplied_context.local_player_id)
			continue
		_contexts[supplied_context.local_player_id] = supplied_context
	if _contexts.is_empty():
		_contexts[0] = LedgerPlayerContext.new(0)
	context = _contexts.get(0) as LedgerPlayerContext
	provider = LedgerDataProvider.new()
	provider.configure(party, catalog, health_provider)
	provider.data_changed.connect(_on_provider_data_changed)
	provider.party_changed.connect(_on_provider_party_changed)
	_build_pages()

func open_for_player(local_player_id: int = 0) -> bool:
	if run == null or not is_instance_valid(run) or party == null or not is_instance_valid(party):
		return false
	if run.current_state() not in [
		RunStateMachine.State.RUNNING,
		RunStateMachine.State.LEVEL_UP,
		RunStateMachine.State.BOSS,
	]:
		return false
	if party.members.is_empty() or not _contexts.has(local_player_id):
		return false
	context = _contexts[local_player_id] as LedgerPlayerContext
	if context == null:
		return false
	context.opened_by_player_id = local_player_id
	for page_value: Variant in _pages.values():
		(page_value as CharacterLedgerPage).configure(provider, context)
	context.ensure_valid_member(party)
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	visible = true
	refresh()
	if not activate_page(context.active_page_id):
		if _available_page_ids.is_empty() or not activate_page(_available_page_ids[0]):
			close()
			return false
	_focus_remembered_or_default()
	return true

func close() -> void:
	if not is_open():
		return
	_store_focus()
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if active_page != null:
		active_page.deactivate()
	_active_page_id = &""
	_pause_lease.release(Engine.get_main_loop() as SceneTree)
	visible = false
	_status().text = ""

func is_open() -> bool:
	return visible

func refresh() -> void:
	if provider == null or context == null:
		return
	context.ensure_valid_member(party)
	_rebuild_member_rail()
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if active_page != null:
		active_page.configure(provider, context)
		active_page.refresh()

func activate_page(page_id: StringName) -> bool:
	var definition := _definitions.get(page_id) as LedgerPageDefinition
	if definition == null:
		_status().text = "Page unavailable: %s" % page_id
		return false
	if definition.development_state == LedgerPageDefinition.State.COMING_SOON:
		var explanation := definition.unavailable_text if not definition.unavailable_text.is_empty() else "Coming Soon"
		_status().text = "%s: %s" % [definition.label, explanation]
		if _status().is_inside_tree():
			_status().grab_focus()
		return false
	var next_page := _pages.get(page_id) as CharacterLedgerPage
	if next_page == null:
		_status().text = "Page unavailable: %s" % definition.label
		return false
	var previous_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if previous_page != null and previous_page != next_page:
		previous_page.deactivate()
	context.active_page_id = page_id
	_active_page_id = page_id
	_status().text = ""
	next_page.configure(provider, context)
	next_page.activate()
	if is_open():
		_focus_page_or_member()
	return true

func select_member(member_id: int) -> bool:
	if party == null or context == null or party.member_by_id(member_id) == null:
		return false
	context.selected_member_id = member_id
	_sync_member_selection()
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if active_page != null:
		active_page.refresh()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"character_ledger"):
		if is_open():
			close()
		else:
			open_for_player()
		_mark_input_handled()
		return
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"ledger_previous_page"):
		_cycle_page(-1)
		_mark_input_handled()
		return
	if event.is_action_pressed(&"ledger_next_page"):
		_cycle_page(1)
		_mark_input_handled()

func _build_pages() -> void:
	var gate := LedgerFeatureGate.new(false)
	var seen: Dictionary = {}
	for error: String in DEFAULT_PAGE_CATALOG.validate():
		push_error(error)
	for definition: LedgerPageDefinition in DEFAULT_PAGE_CATALOG.pages:
		if definition == null:
			continue
		if seen.has(definition.id):
			continue
		seen[definition.id] = true
		if not definition.validate().is_empty():
			continue
		var state := gate.resolve(definition)
		if state == LedgerPageDefinition.State.HIDDEN:
			continue
		_definitions[definition.id] = definition
		_add_tab(definition)
		if state != LedgerPageDefinition.State.AVAILABLE:
			continue
		if definition.page_scene == null:
			push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=required page scene is missing" % definition.id)
			continue
		var page := definition.page_scene.instantiate() as CharacterLedgerPage
		if page == null:
			push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=page scene has invalid root" % definition.id)
			continue
		page.configure(provider, context)
		page.deactivate()
		_page_host().add_child(page)
		_pages[definition.id] = page
		_available_page_ids.append(definition.id)
	for required_id: StringName in REQUIRED_PAGE_IDS:
		if not _definitions.has(required_id):
			push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=required page is missing" % required_id)

func _add_tab(definition: LedgerPageDefinition) -> void:
	var button := Button.new()
	button.name = "Tab_%s" % definition.id
	button.text = definition.label
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("page_id", definition.id)
	button.pressed.connect(_on_tab_pressed.bind(definition.id))
	_tabs().add_child(button)

func _clear_dynamic_ui() -> void:
	var tabs_node := get_node_or_null("Overlay/Frame/Layout/Tabs")
	if tabs_node != null:
		for child: Node in tabs_node.get_children():
			child.free()
	var host := get_node_or_null("Overlay/Frame/Layout/Body/PageHost")
	if host != null:
		for child: Node in host.get_children():
			child.free()
	var entries := get_node_or_null("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries")
	if entries != null:
		for child: Node in entries.get_children():
			child.free()
	_definitions.clear()
	_pages.clear()
	_available_page_ids.clear()
	_member_buttons.clear()
	_active_page_id = &""

func _disconnect_provider() -> void:
	if provider == null:
		return
	if provider.data_changed.is_connected(_on_provider_data_changed):
		provider.data_changed.disconnect(_on_provider_data_changed)
	if provider.party_changed.is_connected(_on_provider_party_changed):
		provider.party_changed.disconnect(_on_provider_party_changed)
	provider.configure(null, null, Callable())
	provider = null

func _rebuild_member_rail() -> void:
	var entries := _party_entries()
	for child: Node in entries.get_children():
		child.free()
	_member_buttons.clear()
	for row: Dictionary in provider.member_rows():
		var button := Button.new()
		button.name = "Member_%d" % int(row.member_id)
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("member_id", int(row.member_id))
		button.pressed.connect(_on_member_pressed.bind(int(row.member_id)))
		entries.add_child(button)
		_member_buttons[int(row.member_id)] = button
		_bind_member_button(button, row)
	_sync_member_selection()

func _refresh_member_button(member_id: int) -> void:
	var button := _member_buttons.get(member_id) as Button
	if button == null:
		return
	for row: Dictionary in provider.member_rows():
		if int(row.member_id) == member_id:
			_bind_member_button(button, row)
			return

func _bind_member_button(button: Button, row: Dictionary) -> void:
	var character_name := String(row.get("character_name", "")).strip_edges()
	if character_name.is_empty():
		character_name = "Member %d" % int(row.member_id)
	button.text = "%s\n%s  %.0f/%.0f" % [
		character_name,
		String(row.class_name),
		float(row.health_current),
		float(row.health_maximum),
	]
	button.tooltip_text = "%s, %s, rank %d" % [character_name, String(row.role_name), int(row.class_rank)]

func _sync_member_selection() -> void:
	if context == null:
		return
	for member_id: Variant in _member_buttons:
		var button := _member_buttons[member_id] as Button
		button.button_pressed = int(member_id) == context.selected_member_id

func _on_tab_pressed(page_id: StringName) -> void:
	activate_page(page_id)

func _on_member_pressed(member_id: int) -> void:
	select_member(member_id)

func _on_provider_data_changed(member_id: int) -> void:
	if not is_open() or context == null:
		return
	if member_id > 0:
		_refresh_member_button(member_id)
	if member_id == 0 or member_id == context.selected_member_id:
		var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
		if active_page != null:
			active_page.refresh()

func _on_provider_party_changed() -> void:
	if is_open():
		refresh()

func _cycle_page(direction: int) -> void:
	var next_page_id := _next_available_page_id(direction)
	if next_page_id.is_empty():
		return
	activate_page(next_page_id)

func _next_available_page_id(direction: int) -> StringName:
	if _available_page_ids.is_empty() or direction == 0:
		return &""
	var current_index := _available_page_ids.find(_active_page_id)
	if current_index < 0:
		current_index = 0
	else:
		current_index = posmod(current_index + direction, _available_page_ids.size())
	return _available_page_ids[current_index]

func _store_focus() -> void:
	if context == null or not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		context.last_focus_path = get_path_to(focused)

func _focus_remembered_or_default() -> void:
	if context != null and not context.last_focus_path.is_empty():
		var remembered := get_node_or_null(context.last_focus_path) as Control
		if remembered != null and remembered.is_visible_in_tree():
			remembered.grab_focus()
			return
	_focus_page_or_member()

func _focus_page_or_member() -> void:
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	var target := active_page.initial_focus() if active_page != null else null
	if target != null and target.is_inside_tree() and target.is_visible_in_tree():
		target.grab_focus()
		return
	var member_button := _member_buttons.get(context.selected_member_id) as Button if context != null else null
	if member_button != null and member_button.is_inside_tree():
		member_button.grab_focus()

func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _tabs() -> HBoxContainer:
	return get_node("Overlay/Frame/Layout/Tabs") as HBoxContainer

func _party_entries() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as GridContainer

func _page_host() -> Control:
	return get_node("Overlay/Frame/Layout/Body/PageHost") as Control

func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Status") as Label
