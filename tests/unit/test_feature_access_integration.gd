extends RefCounted

const LEDGER_FEATURES: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_feature_state_matrix(failures)
	_test_ledger_catalog_policy_and_equipment_boundary(failures)
	_test_required_page_validation_distinguishes_policy_hidden(failures)
	_test_main_reconfigures_policy_before_run_start(failures)
	return failures

func _test_required_page_validation_distinguishes_policy_hidden(failures: Array[String]) -> void:
	var equipment := load("res://data/ui/ledger_pages/equipment_inventory.tres") as LedgerPageDefinition
	var locked_catalog := LedgerPageCatalog.new()
	locked_catalog.pages = [
		load("res://data/ui/ledger_pages/stats.tres") as LedgerPageDefinition,
		load("res://data/ui/ledger_pages/current_upgrades.tres") as LedgerPageDefinition,
		equipment,
	]
	var player_policy := RunRulesSnapshot.from_settings(PartyForgeSettings.new()).feature_policy(LEDGER_FEATURES, [&"equipment_inventory"])
	var player_gate := LedgerFeatureGate.new(player_policy, LEDGER_FEATURES, [&"equipment_inventory"])
	var ledger_script := load("res://scripts/ui/ledger/character_ledger.gd") as Script
	TestAssertions.equal(ledger_script.call("required_page_errors", locked_catalog, player_gate), PackedStringArray(), "policy-hidden Equipment is not reported as structurally missing", failures)
	var missing_catalog := LedgerPageCatalog.new()
	missing_catalog.pages = [locked_catalog.pages[0], locked_catalog.pages[1]]
	TestAssertions.equal(ledger_script.call("required_page_errors", missing_catalog, player_gate), PackedStringArray(["PARTY_FORGE_LEDGER_ERROR page=equipment_inventory reason=required page is missing"]), "genuinely absent required Equipment definition retains a structural error", failures)

func _test_feature_state_matrix(failures: Array[String]) -> void:
	var player_settings := PartyForgeSettings.new()
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var unlock_all_settings := developer_settings.copy()
	unlock_all_settings.unlock_all_implemented_content = true
	var implemented_unlock := _city_unlock_id(&"equipment-registry", &"feature_unlock")
	TestAssertions.equal(implemented_unlock, &"equipment_inventory", "implemented unlock comes from the committed City artifact", failures)

	var player_gate := _gate_for(player_settings, implemented_unlock)
	var developer_gate := _gate_for(developer_settings, implemented_unlock)
	var unlock_all_gate := _gate_for(unlock_all_settings, implemented_unlock)
	var allocated_gate := _gate_for(player_settings, implemented_unlock, [implemented_unlock])
	var definition := _definition(&"equipment_inventory", implemented_unlock)
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
	definition.development_state = LedgerPageDefinition.State.AVAILABLE
	TestAssertions.equal(allocated_gate.resolve(definition), LedgerPageDefinition.State.AVAILABLE, "implemented content is available after exact passive unlock allocation", failures)
	_test_prefixed_unlocks_do_not_collide(player_settings, failures)

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
	var known_unlocks: Array[StringName] = [&"equipment_inventory"]
	var policy := RunRulesSnapshot.from_settings(developer_settings).feature_policy(LEDGER_FEATURES, known_unlocks)
	var gate := LedgerFeatureGate.new(policy, [&"equipment_inventory"], known_unlocks)
	TestAssertions.equal(gate.resolve(equipment), LedgerPageDefinition.State.AVAILABLE, "Unlock All activates completed Equipment content", failures)

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
	TestAssertions.truthy(definitions.has(&"equipment_inventory"), "Equipment remains cataloged when completed content is unlocked", failures)
	TestAssertions.truthy(pages.has(&"equipment_inventory"), "Equipment instantiates its completed page scene", failures)
	TestAssertions.equal((ledger.get_node("Overlay/Frame/Layout/Body/PageHost") as Control).get_child_count(), 3, "all implemented ledger pages instantiate", failures)
	TestAssertions.truthy(ledger.activate_page(&"equipment_inventory"), "direct Equipment activation succeeds", failures)
	TestAssertions.equal((ledger.get_node("Overlay/Frame/Layout/Status") as Label).text, "", "available Equipment activation has no unavailable explanation", failures)
	ledger.free()
	run_state.free()
	party.free()

func _test_main_reconfigures_policy_before_run_start(failures: Array[String]) -> void:
	var root_prefix := "user://tests/feature_access_integration-profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var locked_main := _started_main(root_prefix.path_join("locked"), PartyForgeSettings.new(), false, failures)
	if locked_main != null:
		var locked_ledger := locked_main.get_node("CharacterLedger") as CharacterLedger
		TestAssertions.truthy(not (locked_ledger.get("_definitions") as Dictionary).has(&"equipment_inventory"), "locked Player profile does not catalog or focus the Equipment page", failures)
		TestAssertions.truthy(not locked_main.call("_personal_loot_access_for", locked_main.get("active_run_context")), "locked Player profile cannot roll personal loot", failures)
		var locked_roll := locked_main.get("personal_loot_roll_service") as PersonalLootRollService
		locked_roll.loot_tuning.drop_basis_points[&"ordinary_melee"] = 10000
		var locked_decisions := locked_roll.resolve(_event_at_leader(locked_main), true)
		TestAssertions.equal((locked_decisions[0] as PersonalLootDecision).reason, &"feature_locked", "locked Player roll fails closed at the per-context resolver", failures)
		_cleanup_main(locked_main)

	var unlocked_main := _started_main(root_prefix.path_join("unlocked"), PartyForgeSettings.new(), true, failures)
	if unlocked_main != null:
		var unlocked_ledger := unlocked_main.get_node("CharacterLedger") as CharacterLedger
		TestAssertions.truthy((unlocked_ledger.get("_definitions") as Dictionary).has(&"equipment_inventory"), "permanent equipment unlock catalogs the completed ledger page", failures)
		TestAssertions.truthy((unlocked_ledger.get("_pages") as Dictionary).has(&"equipment_inventory"), "permanent equipment unlock instantiates the completed ledger page", failures)
		TestAssertions.truthy(unlocked_main.call("_personal_loot_access_for", unlocked_main.get("active_run_context")), "permanent equipment unlock plus Field Pack capacity enable personal loot", failures)
		var unlocked_roll := unlocked_main.get("personal_loot_roll_service") as PersonalLootRollService
		unlocked_roll.loot_tuning.drop_basis_points[&"ordinary_melee"] = 10000
		var unlocked_decisions := unlocked_roll.resolve(_event_at_leader(unlocked_main), true)
		TestAssertions.truthy((unlocked_decisions[0] as PersonalLootDecision).success, "permanent equipment unlock plus Field Pack enable the same per-context roll service", failures)
		_cleanup_main(unlocked_main)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	var developer_main := _started_main(root_prefix.path_join("developer"), developer_settings, false, failures)
	if developer_main != null:
		var developer_ledger := developer_main.get_node("CharacterLedger") as CharacterLedger
		TestAssertions.truthy((developer_ledger.get("_pages") as Dictionary).has(&"equipment_inventory"), "Developer Unlock All exposes the completed ledger page", failures)
		TestAssertions.truthy(developer_main.call("_personal_loot_access_for", developer_main.get("active_run_context")), "Developer Unlock All enables personal loot through the same resolver", failures)
		TestAssertions.equal((developer_main.call("active_profile") as ProfileState).permanent_feature_unlocks, [], "Developer Unlock All does not mutate permanent profile unlocks", failures)
		_cleanup_main(developer_main)
	ProfileTestSupport.remove_tree(root_prefix)

func _started_main(root: String, settings: PartyForgeSettings, permanently_unlocked: bool, failures: Array[String]) -> Node:
	ProfileTestSupport.remove_tree(root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.set("profile_root", root)
	main.call("_ready")
	var manager := main.get("profile_manager") as ProfileManager
	manager.create_profile("Test Profile")
	if permanently_unlocked:
		var profile := manager.active_profile()
		profile.permanent_feature_unlocks = ["equipment_inventory", "inventory"]
		profile.inventory_columns = 1
		TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "permanent Equipment Registry and Field Pack fixture saves", failures)
		TestAssertions.equal(manager.refresh_profile(profile.profile_id), "", "permanent-unlock fixture refreshes", failures)
	(main.get_node("SettingsScreen") as SettingsScreen).close()
	main.set("saved_settings", settings.copy())
	if not main.call("select_leader_class", &"fighter"):
		TestAssertions.truthy(false, "feature-access fixture starts", failures)
		main.free()
		return null
	return main

func _event_at_leader(main: Node) -> EnemyDefeatEvent:
	var leader := main.get("leader") as PartyActor
	return EnemyDefeatEvent.create(1337, 991, 991, &"swarmer", &"ordinary_melee", leader.position, 30.0)

func _cleanup_main(main: Node) -> void:
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()

func _test_prefixed_unlocks_do_not_collide(settings: PartyForgeSettings, failures: Array[String]) -> void:
	var unprefixed := _city_unlock_id(&"equipment-registry", &"feature_unlock")
	var registry := PassiveEffectRegistry.new()
	var prefixed: Array[StringName] = [
		registry.unlock_id(PassiveTreeEffect.new(&"mode_unlock", &"set", true, {"modeId": "battle"})),
		registry.unlock_id(PassiveTreeEffect.new(&"city_service_unlock", &"set", true, {"serviceId": "crafting"})),
		registry.unlock_id(PassiveTreeEffect.new(&"region_unlock", &"set", true, {"regionId": "north-road"})),
	]
	var known_unlocks := prefixed.duplicate()
	known_unlocks.append(unprefixed)
	var policy := RunRulesSnapshot.from_settings(settings).feature_policy(LEDGER_FEATURES, known_unlocks, prefixed)
	TestAssertions.equal(policy.resolve(&"equipment_inventory", FeatureAccessPolicy.State.AVAILABLE, unprefixed), FeatureAccessPolicy.State.HIDDEN, "prefixed mode/service/region unlocks cannot activate an unprefixed feature", failures)
	TestAssertions.truthy(unprefixed not in prefixed, "passive unlock namespaces remain distinct", failures)
	TestAssertions.equal(prefixed, [&"mode:battle", &"service:crafting", &"region:north-road"], "future mode/service/region contracts retain exact namespaces without inventing effects on current City nodes", failures)

func _gate_for(settings: PartyForgeSettings, implemented_unlock: StringName, unlocked: Array[StringName] = []) -> LedgerFeatureGate:
	var implemented_unlocks: Array[StringName] = [implemented_unlock]
	var policy := RunRulesSnapshot.from_settings(settings).feature_policy(LEDGER_FEATURES, implemented_unlocks, unlocked)
	return LedgerFeatureGate.new(policy, LEDGER_FEATURES, implemented_unlocks)

func _city_unlock_id(node_id: StringName, effect_id: StringName) -> StringName:
	var catalog_result := PassiveTreeCatalog.load_defaults()
	if not catalog_result.ok():
		return &""
	for effect: PassiveTreeEffect in catalog_result.tree.node(node_id).effects:
		if effect.effect_id == effect_id:
			return PassiveEffectRegistry.new().unlock_id(effect)
	return &""

func _definition(feature_id: StringName, unlock_id: StringName = &"") -> LedgerPageDefinition:
	var result := LedgerPageDefinition.new()
	result.id = feature_id
	result.feature_id = feature_id
	result.unlock_id = unlock_id
	result.label = String(feature_id)
	result.page_scene = PackedScene.new()
	return result
