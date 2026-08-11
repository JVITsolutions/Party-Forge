class_name CharacterLedger
extends CanvasLayer

const DEFAULT_PAGE_CATALOG: LedgerPageCatalog = preload("res://data/ui/ledger_pages/default_ledger_pages.tres")
const REQUIRED_PAGE_IDS: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]
const RESPONSIVE_LAYOUT := preload("res://scripts/ui/ledger/ledger_responsive_layout.gd")

var run: GameRun
var party: PartyManager
var catalog: GameCatalog
var provider: LedgerDataProvider
var context: LedgerPlayerContext
var _feature_policy: FeatureAccessPolicy

var _contexts: Dictionary = {}
var _definitions: Dictionary = {}
var _pages: Dictionary = {}
var _available_page_ids: Array[StringName] = []
var _member_buttons: Dictionary = {}
var _active_page_id: StringName
var _pause_lease := RunPauseLease.new()
var _responsive_mode := RESPONSIVE_LAYOUT.Mode.DESKTOP
var _viewport_size := Vector2(1920.0, 1080.0)
var _observed_viewport: Viewport
var _member_visibility_request_revision := 0
var _member_visibility_request_target_id := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_wire_close_control()
	_observed_viewport = get_viewport()
	if _observed_viewport != null and not _observed_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_observed_viewport.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _wire_close_control() -> void:
	var close_callback := Callable(self, "_on_close_pressed")
	if not _close_button().pressed.is_connected(close_callback):
		_close_button().pressed.connect(close_callback)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if (
		_observed_viewport != null
		and is_instance_valid(_observed_viewport)
		and _observed_viewport.size_changed.is_connected(_on_viewport_size_changed)
	):
		_observed_viewport.size_changed.disconnect(_on_viewport_size_changed)
	_observed_viewport = null
	if _pause_lease != null and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)
	_disconnect_provider()

func configure(
	game_run: GameRun,
	manager: PartyManager,
	game_catalog: GameCatalog,
	health_provider: Callable,
	initial_contexts: Array[LedgerPlayerContext] = [],
	feature_policy: FeatureAccessPolicy = null,
	progression_provider: Callable = Callable(),
	progression_context: PlayerRunContext = null,
) -> void:
	_wire_close_control()
	_invalidate_member_visibility_requests()
	if is_open():
		close()
	_disconnect_provider()
	_clear_dynamic_ui()
	run = game_run
	party = manager
	catalog = game_catalog
	_feature_policy = feature_policy if feature_policy != null else _player_simulation_policy()
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
	provider.configure(
		party,
		catalog,
		health_provider,
		progression_provider,
		progression_context,
		progression_context,
		catalog.equipment_catalog if catalog != null else null,
		catalog.item_foundation_catalog if catalog != null else null,
	)
	provider.data_changed.connect(_on_provider_data_changed)
	provider.party_changed.connect(_on_provider_party_changed)
	_build_pages()
	apply_viewport_size(_viewport_size)

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
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if active_page != null:
		active_page.dismiss_pinned_detail()
	_store_focus()
	if active_page != null:
		active_page.deactivate()
	_active_page_id = &""
	_invalidate_member_visibility_requests()
	_pause_lease.release(Engine.get_main_loop() as SceneTree)
	visible = false
	_status().text = ""

func is_open() -> bool:
	return visible

func refresh() -> void:
	if provider == null or context == null:
		return
	var focused_member_id := _member_id_for_control(get_viewport().gui_get_focus_owner()) if is_inside_tree() else 0
	context.ensure_valid_member(party)
	_rebuild_member_rail()
	var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
	if active_page != null:
		active_page.configure(provider, context)
		active_page.refresh()
		_wire_roster_page_focus_bridge()
	if focused_member_id > 0:
		_restore_member_focus_after_refresh(focused_member_id)

func apply_viewport_size(size: Vector2) -> void:
	_viewport_size = size
	_responsive_mode = RESPONSIVE_LAYOUT.mode_for_size(size)
	var compact := _responsive_mode == RESPONSIVE_LAYOUT.Mode.COMPACT
	_body().vertical = compact
	_party_entries().columns = 3 if compact else 1
	_party_column().custom_minimum_size = Vector2(0.0, 136.0) if compact else Vector2(260.0, 0.0)
	_page_host().custom_minimum_size = Vector2(0.0, 220.0) if compact else Vector2(600.0, 420.0)
	_body().split_offset = 132 if compact else 280
	var frame := _frame()
	frame.offset_left = 16.0 if compact else 48.0
	frame.offset_top = 12.0 if compact else 36.0
	frame.offset_right = -16.0 if compact else -48.0
	frame.offset_bottom = -12.0 if compact else -36.0
	for page_value: Variant in _pages.values():
		(page_value as CharacterLedgerPage).apply_compact(compact)
	_configure_member_focus_neighbors()
	_wire_roster_page_focus_bridge()

func activate_page(page_id: StringName) -> bool:
	var definition := _definitions.get(page_id) as LedgerPageDefinition
	if definition == null:
		_status().text = "Page unavailable: %s" % page_id
		return false
	if definition.development_state == LedgerPageDefinition.State.COMING_SOON:
		_show_unavailable(definition, true)
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
	_configure_member_focus_neighbors()
	_wire_roster_page_focus_bridge()
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
	_configure_member_focus_neighbors()
	_wire_roster_page_focus_bridge()
	_request_member_visibility(member_id)
	_ensure_member_visible(member_id)
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
	var scroll_axis := event.get_action_strength(&"tooltip_scroll_down") - event.get_action_strength(&"tooltip_scroll_up")
	var focused := get_viewport().gui_get_focus_owner() as Control if is_inside_tree() else null
	if absf(scroll_axis) >= 0.15 and focused != null and _party_scroll().is_ancestor_of(focused):
		_party_scroll().scroll_vertical += int(roundf(scroll_axis * 96.0))
		_mark_input_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		var active_page := _active_page()
		if active_page != null and active_page.dismiss_pinned_detail():
			_mark_input_handled()
			return
		close()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		var active_page := _active_page()
		if active_page != null and active_page.pin_active_detail():
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
	var gate := LedgerFeatureGate.new(_feature_policy, _catalog_feature_ids(), _catalog_unlock_ids())
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
		page.apply_compact(_responsive_mode == RESPONSIVE_LAYOUT.Mode.COMPACT)
		page.deactivate()
		_page_host().add_child(page)
		_pages[definition.id] = page
		_available_page_ids.append(definition.id)
	for error: String in required_page_errors(DEFAULT_PAGE_CATALOG, gate):
		push_error(error)

static func required_page_errors(catalog: LedgerPageCatalog, gate: LedgerFeatureGate) -> PackedStringArray:
	var errors := PackedStringArray()
	for required_id: StringName in REQUIRED_PAGE_IDS:
		var definition: LedgerPageDefinition
		if catalog != null:
			for candidate: LedgerPageDefinition in catalog.pages:
				if candidate != null and candidate.id == required_id:
					definition = candidate
					break
		if definition == null or not definition.validate().is_empty():
			errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=required page is missing" % required_id)
			continue
		if gate == null or gate.resolve(definition) == LedgerPageDefinition.State.HIDDEN:
			continue
	return errors

func _player_simulation_policy() -> FeatureAccessPolicy:
	return RunRulesSnapshot.from_settings(PartyForgeSettings.new()).feature_policy(_catalog_feature_ids(), _catalog_unlock_ids())

func _catalog_feature_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: LedgerPageDefinition in DEFAULT_PAGE_CATALOG.pages:
		if definition != null and not definition.feature_id.is_empty() and definition.feature_id not in result:
			result.append(definition.feature_id)
	return result

func _catalog_unlock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: LedgerPageDefinition in DEFAULT_PAGE_CATALOG.pages:
		if definition != null and not definition.unlock_id.is_empty() and definition.unlock_id not in result:
			result.append(definition.unlock_id)
	return result

func _add_tab(definition: LedgerPageDefinition) -> void:
	var button := Button.new()
	button.name = "Tab_%s" % definition.id
	button.text = definition.label
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("page_id", definition.id)
	button.pressed.connect(_on_tab_pressed.bind(definition.id))
	button.focus_entered.connect(_on_tab_focused.bind(definition.id))
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
	var entries := get_node_or_null("Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries")
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
	_refresh_party_count()
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
		button.focus_entered.connect(_on_member_focused.bind(int(row.member_id)))
		entries.add_child(button)
		_member_buttons[int(row.member_id)] = button
		_bind_member_button(button, row)
	_sync_member_selection()
	_configure_member_focus_neighbors()
	_wire_roster_page_focus_bridge()
	_request_member_visibility(context.selected_member_id)

func _refresh_party_count() -> void:
	var current := party.members.size() if party != null else 0
	var maximum := party.capacity() if party != null else 0
	_party_count().text = "Party Members: %d / %d" % [current, maximum]

func _configure_member_focus_neighbors() -> void:
	var buttons: Array[Button] = []
	for child: Node in _party_entries().get_children():
		var button := child as Button
		if button != null and button.visible:
			buttons.append(button)
	var columns := maxi(_party_entries().columns, 1)
	for index: int in buttons.size():
		var button := buttons[index]
		var row := floori(float(index) / float(columns))
		var column := index % columns
		_set_neighbor(button, &"focus_neighbor_left", buttons[index - 1] if columns > 1 and index > 0 else null)
		_set_neighbor(button, &"focus_neighbor_right", buttons[index + 1] if column + 1 < columns and index + 1 < buttons.size() else null)
		_set_neighbor(button, &"focus_neighbor_top", buttons[index - columns] if row > 0 else null)
		_set_neighbor(button, &"focus_neighbor_bottom", buttons[index + columns] if index + columns < buttons.size() else null)

func _set_neighbor(control: Control, property_name: StringName, target: Control) -> void:
	control.set(property_name, control.get_path_to(target) if target != null else NodePath())

func _ensure_member_visible(member_id: int) -> void:
	var button := _member_buttons.get(member_id) as Button
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree():
		return
	_party_scroll().ensure_control_visible(button)

func _request_member_visibility(member_id: int) -> int:
	_member_visibility_request_revision += 1
	_member_visibility_request_target_id = member_id
	var request_revision := _member_visibility_request_revision
	call_deferred("_apply_member_visibility_request", member_id, request_revision)
	return request_revision

func _apply_member_visibility_request(member_id: int, request_revision: int) -> bool:
	if request_revision != _member_visibility_request_revision:
		return false
	_ensure_member_visible(member_id)
	return true

func _invalidate_member_visibility_requests() -> void:
	_member_visibility_request_revision += 1
	_member_visibility_request_target_id = 0

func _member_id_for_control(control: Control) -> int:
	if control == null or not control.has_meta("member_id"):
		return 0
	var member_id := int(control.get_meta("member_id", 0))
	return member_id if _member_buttons.get(member_id) == control else 0

func _restore_member_focus_after_refresh(previous_member_id: int) -> void:
	var member_id := previous_member_id if _member_buttons.has(previous_member_id) else context.selected_member_id
	var button := _member_buttons.get(member_id) as Button
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree():
		return
	button.grab_focus()
	_request_member_visibility(member_id)
	_ensure_member_visible(member_id)

func _wire_roster_page_focus_bridge() -> void:
	if context == null:
		return
	_wire_closed_focus_cycle()
	var member_button := _member_buttons.get(context.selected_member_id) as Button
	var active_page := _active_page()
	var page_target := active_page.initial_focus() if active_page != null else null
	if member_button != null and page_target != null:
		_set_neighbor(member_button, &"focus_neighbor_right", page_target)
		_set_neighbor(page_target, &"focus_neighbor_left", member_button)
		_set_neighbor(page_target, &"focus_neighbor_top", null)
		if _responsive_mode == RESPONSIVE_LAYOUT.Mode.COMPACT:
			var visible_buttons := _visible_member_buttons()
			var member_index := visible_buttons.find(member_button)
			var columns := maxi(_party_entries().columns, 1)
			var last_row := floori(float(visible_buttons.size() - 1) / float(columns))
			if member_index >= 0 and floori(float(member_index) / float(columns)) == last_row:
				_set_neighbor(member_button, &"focus_neighbor_bottom", page_target)
				_set_neighbor(page_target, &"focus_neighbor_top", member_button)
	_wire_directional_focus_graph()

func _wire_closed_focus_cycle() -> void:
	var controls: Array[Control] = []
	for child: Node in _party_entries().get_children():
		var member_button := child as Button
		if member_button != null and member_button.visible and member_button.focus_mode != Control.FOCUS_NONE:
			controls.append(member_button)
	for child: Node in _tabs().get_children():
		var tab_button := child as Button
		if tab_button != null and tab_button.visible and tab_button.focus_mode != Control.FOCUS_NONE:
			controls.append(tab_button)
	controls.append(_close_button())
	var active_page := _active_page()
	if active_page != null:
		for page_control: Control in active_page.focus_controls():
			if page_control != null and page_control.visible and page_control.focus_mode != Control.FOCUS_NONE:
				controls.append(page_control)
	if controls.size() < 2:
		return
	for index: int in controls.size():
		var current := controls[index]
		current.focus_previous = current.get_path_to(controls[posmod(index - 1, controls.size())])
		current.focus_next = current.get_path_to(controls[(index + 1) % controls.size()])

func _wire_directional_focus_graph() -> void:
	var roster := _visible_member_buttons()
	var tabs: Array[Button] = []
	for child: Node in _tabs().get_children():
		var tab := child as Button
		if tab != null and tab.visible and tab.focus_mode != Control.FOCUS_NONE:
			tabs.append(tab)
	var page_controls: Array[Control] = []
	var active_page := _active_page()
	if active_page != null:
		for control: Control in active_page.focus_controls():
			if control != null and control.visible and control.focus_mode != Control.FOCUS_NONE:
				page_controls.append(control)
	var close_button := _close_button()
	var first_tab := tabs[0] if not tabs.is_empty() else close_button
	var last_tab := tabs[-1] if not tabs.is_empty() else close_button
	var first_page := page_controls[0] if not page_controls.is_empty() else close_button
	var last_page := page_controls[-1] if not page_controls.is_empty() else close_button
	var first_roster := roster[0] if not roster.is_empty() else close_button
	var selected_roster := _member_buttons.get(context.selected_member_id) as Button
	if selected_roster == null:
		selected_roster = first_roster
	for button: Button in roster:
		if button.focus_neighbor_left.is_empty():
			_set_neighbor(button, &"focus_neighbor_left", close_button)
		if button.focus_neighbor_right.is_empty():
			_set_neighbor(button, &"focus_neighbor_right", first_page)
		if button.focus_neighbor_top.is_empty():
			_set_neighbor(button, &"focus_neighbor_top", close_button)
		if button.focus_neighbor_bottom.is_empty():
			_set_neighbor(button, &"focus_neighbor_bottom", first_tab)
	for index: int in tabs.size():
		var tab := tabs[index]
		_set_neighbor(tab, &"focus_neighbor_left", tabs[index - 1] if index > 0 else close_button)
		_set_neighbor(tab, &"focus_neighbor_right", tabs[index + 1] if index + 1 < tabs.size() else close_button)
		_set_neighbor(tab, &"focus_neighbor_top", selected_roster)
		_set_neighbor(tab, &"focus_neighbor_bottom", first_page)
	_set_neighbor(close_button, &"focus_neighbor_left", last_tab)
	_set_neighbor(close_button, &"focus_neighbor_right", first_roster)
	_set_neighbor(close_button, &"focus_neighbor_top", last_page)
	_set_neighbor(close_button, &"focus_neighbor_bottom", first_tab)
	if not page_controls.is_empty():
		var active_tab := first_tab
		for tab: Button in tabs:
			if StringName(tab.get_meta("page_id", &"")) == _active_page_id:
				active_tab = tab
				break
		if page_controls[0].focus_neighbor_top.is_empty():
			_set_neighbor(page_controls[0], &"focus_neighbor_top", active_tab)
		_set_neighbor(page_controls[0], &"focus_neighbor_left", selected_roster)
		_set_neighbor(page_controls[-1], &"focus_neighbor_bottom", close_button)
		_set_neighbor(page_controls[-1], &"focus_neighbor_right", close_button)

func _visible_member_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in _party_entries().get_children():
		var button := child as Button
		if button != null and button.visible and button.focus_mode != Control.FOCUS_NONE:
			result.append(button)
	return result

func _refresh_member_button(member_id: int) -> void:
	var button := _member_buttons.get(member_id) as Button
	if button == null:
		return
	for row: Dictionary in provider.member_rows():
		if int(row.member_id) == member_id:
			_bind_member_button(button, row)
			_sync_member_selection()
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
	button.set_meta("base_text", button.text)
	button.tooltip_text = "%s, %s, rank %d" % [character_name, String(row.role_name), int(row.class_rank)]

func _sync_member_selection() -> void:
	if context == null:
		return
	for member_id: Variant in _member_buttons:
		var button := _member_buttons[member_id] as Button
		var selected := int(member_id) == context.selected_member_id
		button.button_pressed = selected
		var base_text := String(button.get_meta("base_text", button.text))
		button.text = "[Selected] %s" % base_text if selected else base_text

func _on_tab_pressed(page_id: StringName) -> void:
	activate_page(page_id)

func _on_tab_focused(page_id: StringName) -> void:
	var definition := _definitions.get(page_id) as LedgerPageDefinition
	if definition != null and definition.development_state == LedgerPageDefinition.State.COMING_SOON:
		_show_unavailable(definition, false)

func _on_member_pressed(member_id: int) -> void:
	select_member(member_id)

func _on_close_pressed() -> void:
	close()

func _on_member_focused(member_id: int) -> void:
	_request_member_visibility(member_id)
	_ensure_member_visible(member_id)

func _on_provider_data_changed(member_id: int) -> void:
	if not is_open() or context == null:
		return
	if member_id > 0:
		_refresh_member_button(member_id)
	if member_id == 0 or member_id == context.selected_member_id:
		var active_page := _pages.get(_active_page_id) as CharacterLedgerPage
		if active_page != null:
			active_page.refresh()
			_wire_roster_page_focus_bridge()

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

func _show_unavailable(definition: LedgerPageDefinition, focus_status: bool) -> void:
	var explanation := definition.unavailable_text if not definition.unavailable_text.is_empty() else "Coming Soon"
	_status().text = "%s: %s" % [definition.label, explanation]
	if focus_status and _status().is_inside_tree():
		_status().grab_focus()

func _on_viewport_size_changed() -> void:
	if _observed_viewport == null:
		return
	apply_viewport_size(_observed_viewport.get_visible_rect().size)

func _store_focus() -> void:
	if context == null or not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		context.last_focus_path = get_path_to(focused)

func _focus_remembered_or_default() -> Control:
	if context != null and not context.last_focus_path.is_empty():
		var remembered := get_node_or_null(context.last_focus_path) as Control
		if remembered != null and remembered.visible:
			if remembered.is_inside_tree() and remembered.is_visible_in_tree():
				remembered.grab_focus()
			var remembered_member_id := _member_id_for_control(remembered)
			if remembered_member_id > 0:
				_request_member_visibility(remembered_member_id)
				_ensure_member_visible(remembered_member_id)
			elif context != null:
				_ensure_member_visible(context.selected_member_id)
			return remembered
	_focus_page_or_member()
	if context != null:
		_ensure_member_visible(context.selected_member_id)
	return get_viewport().gui_get_focus_owner() if is_inside_tree() else null

func _focus_page_or_member() -> void:
	var active_page := _active_page()
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

func _frame() -> PanelContainer:
	return get_node("Overlay/Frame") as PanelContainer

func _body() -> SplitContainer:
	return get_node("Overlay/Frame/Layout/Body") as SplitContainer

func _party_column() -> VBoxContainer:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn") as VBoxContainer

func _party_count() -> Label:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyCount") as Label

func _party_scroll() -> ScrollContainer:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyScroll") as ScrollContainer

func _party_entries() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries") as GridContainer

func _page_host() -> Control:
	return get_node("Overlay/Frame/Layout/Body/PageHost") as Control

func _active_page() -> CharacterLedgerPage:
	return _pages.get(_active_page_id) as CharacterLedgerPage

func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Status") as Label

func _close_button() -> Button:
	return get_node("Overlay/Frame/Layout/Close") as Button
