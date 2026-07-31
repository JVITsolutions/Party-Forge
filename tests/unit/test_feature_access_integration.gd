extends RefCounted

const LEDGER_FEATURES: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]
const IMPLEMENTED_UNLOCKS: Array[StringName] = [&"advanced_stats"]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_feature_state_matrix(failures)
	_test_ledger_catalog_policy_and_equipment_boundary(failures)
	_test_main_reconfigures_policy_before_run_start(failures)
	return failures

func _test_feature_state_matrix(failures: Array[String]) -> void:
	var player_settings := PartyForgeSettings.new()
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var unlock_all_settings := developer_settings.copy()
	unlock_all_settings.unlock_all_implemented_content = true

	var player_gate := _gate_for(player_settings)
	var developer_gate := _gate_for(developer_settings)
	var unlock_all_gate := _gate_for(unlock_all_settings)
	var definition := _definition(&"stats", &"advanced_stats")
	var cases: Array[Dictionary] = [
		{
			"state": LedgerPageDefinition.State.HIDDEN,
			"player": LedgerPageDefinition.State.HIDDEN,
			"developer": LedgerPageDefinition.State.HIDDEN,
			"unlock_all": LedgerPageDefinition.State.HIDDEN,
			"label": "Hidden",
		},
		{
			"state": LedgerPageDefinition.State.COMING_SOON,
			"player": LedgerPageDefinition.State.COMING_SOON,
			"developer": LedgerPageDefinition.State.COMING_SOON,
			"unlock_all": LedgerPageDefinition.State.COMING_SOON,
			"label": "Coming Soon",
		},
		{
			"state": LedgerPageDefinition.State.DEVELOPER_PREVIEW,
			"player": LedgerPageDefinition.State.HIDDEN,
			"developer": LedgerPageDefinition.State.AVAILABLE,
			"unlock_all": LedgerPageDefinition.State.AVAILABLE,
			"label": "Developer Preview",
		},
		{
			"state": LedgerPageDefinition.State.AVAILABLE,
			"player": LedgerPageDefinition.State.HIDDEN,
			"developer": LedgerPageDefinition.State.HIDDEN,
			"unlock_all": LedgerPageDefinition.State.AVAILABLE,
			"label": "Available with progression unlock",
		},
	]
	for test_case: Dictionary in cases:
		definition.development_state = int(test_case.state)
		TestAssertions.equal(player_gate.resolve(definition), int(test_case.player), "%s resolves in Player Simulation" % test_case.label, failures)
		TestAssertions.equal(developer_gate.resolve(definition), int(test_case.developer), "%s resolves in Developer Mode" % test_case.label, failures)
		TestAssertions.equal(unlock_all_gate.resolve(definition), int(test_case.unlock_all), "%s resolves with Unlock All" % test_case.label, failures)

func _test_ledger_catalog_policy_and_equipment_boundary(failures: Array[String]) -> void:
	var stats := load("res://data/ui/ledger_pages/stats.tres") as LedgerPageDefinition
	var upgrades := load("res://data/ui/ledger_pages/current_upgrades.tres") as LedgerPageDefinition
	var equipment := load("res://data/ui/ledger_pages/equipment_inventory.tres") as LedgerPageDefinition
	TestAssertions.equal(stats.feature_id, stats.id, "Stats has a stable feature ID", failures)
	TestAssertions.equal(upgrades.feature_id, upgrades.id, "Current Upgrades has a stable feature ID", failures)
	TestAssertions.equal(equipment.feature_id, equipment.id, "Equipment and Inventory has a stable feature ID", failures)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	var policy := RunRulesSnapshot.from_settings(developer_settings).feature_policy(LEDGER_FEATURES)
	var gate := LedgerFeatureGate.new(policy, [&"equipment_inventory"])
	TestAssertions.equal(gate.resolve(equipment), LedgerPageDefinition.State.COMING_SOON, "Unlock All cannot activate Equipment Coming Soon", failures)

	var tree := Engine.get_main_loop() as SceneTree
	var ledger := (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var run_state := GameRun.new()
	ledger.configure(run_state, party, catalog, Callable(), [], policy)
	var pages := ledger.get("_pages") as Dictionary
	var definitions := ledger.get("_definitions") as Dictionary
	TestAssertions.truthy(definitions.has(&"equipment_inventory"), "Equipment remains visible as a Coming Soon tab", failures)
	TestAssertions.truthy(not pages.has(&"equipment_inventory"), "Equipment never instantiates a page scene", failures)
	TestAssertions.equal((ledger.get_node("Overlay/Frame/Layout/Body/PageHost") as Control).get_child_count(), 2, "only implemented ledger pages instantiate", failures)
	TestAssertions.truthy(not ledger.activate_page(&"equipment_inventory"), "direct Equipment activation is rejected", failures)
	TestAssertions.truthy("Coming Soon" in (ledger.get_node("Overlay/Frame/Layout/Status") as Label).text, "direct rejection explains Coming Soon", failures)
	ledger.free()
	run_state.free()
	party.free()

func _test_main_reconfigures_policy_before_run_start(failures: Array[String]) -> void:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.call("_ready")
	var ledger := main.get_node("CharacterLedger") as CharacterLedger
	var neutral_policy := ledger.get("_feature_policy") as FeatureAccessPolicy
	TestAssertions.equal(neutral_policy.resolve(&"stats", FeatureAccessPolicy.State.DEVELOPER_PREVIEW), FeatureAccessPolicy.State.HIDDEN, "front end ledger starts with neutral Player Simulation access", failures)
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	main.set("saved_settings", developer_settings)
	var state_at_run_start: Array[int] = [-1]
	(main.get_node("GameRun") as GameRun).state_changed.connect(func(state: int) -> void:
		if state != RunStateMachine.State.RUNNING:
			return
		var active_policy := ledger.get("_feature_policy") as FeatureAccessPolicy
		state_at_run_start[0] = active_policy.resolve(&"stats", FeatureAccessPolicy.State.DEVELOPER_PREVIEW)
	)
	TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "Developer Mode fixture starts", failures)
	TestAssertions.equal(state_at_run_start[0], FeatureAccessPolicy.State.AVAILABLE, "active snapshot configures ledger before GameRun starts", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()

func _gate_for(settings: PartyForgeSettings) -> LedgerFeatureGate:
	var policy := RunRulesSnapshot.from_settings(settings).feature_policy(LEDGER_FEATURES, IMPLEMENTED_UNLOCKS)
	return LedgerFeatureGate.new(policy, LEDGER_FEATURES, IMPLEMENTED_UNLOCKS)

func _definition(feature_id: StringName, unlock_id: StringName = &"") -> LedgerPageDefinition:
	var result := LedgerPageDefinition.new()
	result.id = feature_id
	result.feature_id = feature_id
	result.unlock_id = unlock_id
	result.label = String(feature_id)
	result.page_scene = PackedScene.new()
	return result
