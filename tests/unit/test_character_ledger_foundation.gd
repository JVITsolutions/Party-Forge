extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_page_validation_and_order(failures)
	_test_gate_states(failures)
	_test_context_fallback(failures)
	_test_pause_lease(failures)
	_test_input_actions(failures)
	return failures

func _test_page_validation_and_order(failures: Array[String]) -> void:
	var stats := LedgerPageDefinition.new()
	stats.id = &"stats"
	stats.label = "Stats"
	stats.display_order = 20
	stats.development_state = LedgerPageDefinition.State.AVAILABLE
	stats.page_scene = PackedScene.new()
	var upgrades := LedgerPageDefinition.new()
	upgrades.id = &"upgrades"
	upgrades.label = "Current Upgrades"
	upgrades.display_order = 10
	upgrades.development_state = LedgerPageDefinition.State.AVAILABLE
	upgrades.page_scene = PackedScene.new()
	var catalog := LedgerPageCatalog.new()
	catalog.pages = [stats, upgrades]
	var ordered := catalog.valid_pages(LedgerFeatureGate.new())
	TestAssertions.equal(ordered.map(func(page: LedgerPageDefinition) -> StringName: return page.id), [&"upgrades", &"stats"], "ledger pages sort deterministically", failures)
	catalog.pages.append(stats)
	TestAssertions.truthy(Array(catalog.validate()).any(func(message: String) -> bool: return "duplicate page id stats" in message), "duplicate page IDs are grep-friendly", failures)

func _test_gate_states(failures: Array[String]) -> void:
	var definition := LedgerPageDefinition.new()
	definition.id = &"equipment_inventory"
	definition.label = "Equipment & Inventory"
	definition.development_state = LedgerPageDefinition.State.DEVELOPER_PREVIEW
	var player_gate := LedgerFeatureGate.new(false)
	var developer_gate := LedgerFeatureGate.new(true)
	TestAssertions.equal(player_gate.resolve(definition), LedgerPageDefinition.State.HIDDEN, "player gate hides developer preview", failures)
	TestAssertions.equal(developer_gate.resolve(definition), LedgerPageDefinition.State.AVAILABLE, "developer gate exposes implemented preview", failures)
	definition.feature_id = &"equipment"
	TestAssertions.equal(LedgerFeatureGate.new(true, [&"equipment"]).resolve(definition), LedgerPageDefinition.State.AVAILABLE, "known feature preserves developer preview", failures)
	TestAssertions.equal(LedgerFeatureGate.new(true).resolve(definition), LedgerPageDefinition.State.HIDDEN, "unknown feature hides page conservatively", failures)
	definition.feature_id = &""
	definition.unlock_id = &"equipment_mastery"
	TestAssertions.equal(LedgerFeatureGate.new(true).resolve(definition), LedgerPageDefinition.State.HIDDEN, "unknown unlock hides page conservatively", failures)
	definition.unlock_id = &""
	for state: int in [LedgerPageDefinition.State.HIDDEN, LedgerPageDefinition.State.COMING_SOON, LedgerPageDefinition.State.AVAILABLE]:
		definition.development_state = state
		TestAssertions.equal(player_gate.resolve(definition), state, "ordinary page state %d remains stable" % state, failures)

func _test_context_fallback(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 999
	TestAssertions.equal(context.ensure_valid_member(party, party.members[1].member_id), party.members[1].member_id, "preferred available member wins fallback", failures)
	context.selected_member_id = 999
	TestAssertions.equal(context.ensure_valid_member(party), party.members[0].member_id, "missing selection falls back to controlled or first member", failures)
	party.free()

func _test_pause_lease(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var lease := RunPauseLease.new()
	lease.acquire(tree)
	lease.acquire(tree)
	TestAssertions.truthy(tree.paused, "lease pauses an active run", failures)
	lease.release(tree)
	lease.release(tree)
	TestAssertions.truthy(not tree.paused, "lease restores an active run", failures)
	tree.paused = true
	lease.acquire(tree)
	lease.release(tree)
	TestAssertions.truthy(tree.paused, "lease preserves an existing pause", failures)
	tree.paused = false

func _test_input_actions(failures: Array[String]) -> void:
	for action: StringName in [&"character_ledger", &"pause_menu", &"ledger_previous_page", &"ledger_next_page"]:
		TestAssertions.truthy(InputMap.has_action(action), "InputMap exposes %s" % action, failures)
	var ledger_events := InputMap.action_get_events(&"character_ledger")
	TestAssertions.truthy(ledger_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_TAB), "Tab opens the ledger", failures)
	TestAssertions.truthy(ledger_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_I), "I opens the ledger", failures)
	TestAssertions.truthy(ledger_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK), "controller Back opens the ledger", failures)
	var pause_events := InputMap.action_get_events(&"pause_menu")
	TestAssertions.truthy(pause_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_ESCAPE), "Escape opens pause", failures)
	TestAssertions.truthy(pause_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START), "controller Start opens pause", failures)
	var previous_events := InputMap.action_get_events(&"ledger_previous_page")
	TestAssertions.truthy(previous_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER), "left shoulder selects previous ledger page", failures)
	var next_events := InputMap.action_get_events(&"ledger_next_page")
	TestAssertions.truthy(next_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER), "right shoulder selects next ledger page", failures)
