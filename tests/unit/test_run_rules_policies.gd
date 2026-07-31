extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var saved := PartyForgeSettings.new()
	saved.unlock_all_implemented_content = true
	saved.god_mode = true
	saved.party_capacity_override = 24
	saved.enemy_density_percent = 1000
	var player := RunRulesSnapshot.from_settings(saved)
	TestAssertions.truthy(not player.developer_mode_active(), "Player Simulation remains production mode", failures)
	TestAssertions.truthy(not player.god_mode(), "Player Simulation neutralizes God Mode", failures)
	TestAssertions.equal(player.party_capacity(), 4, "Player Simulation uses production cap", failures)
	TestAssertions.equal(player.enemy_density_percent(), 100, "Player Simulation uses normal density", failures)
	var missing := RunRulesSnapshot.from_settings(null)
	TestAssertions.truthy(not missing.developer_mode_active(), "missing settings fail safely to Player Simulation", failures)
	saved.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var developer := RunRulesSnapshot.from_settings(saved)
	saved.party_capacity_override = 1
	TestAssertions.equal(developer.party_capacity(), 24, "snapshot is unaffected by later settings mutation", failures)
	TestAssertions.equal(developer.combat_policy().minimum_party_health(), 1.0, "God Mode exposes one-health floor", failures)
	TestAssertions.truthy(developer.capacity_policy().can_add(23), "capacity allows slot 24", failures)
	TestAssertions.truthy(not developer.capacity_policy().can_add(24), "capacity rejects slot 25", failures)
	var gate := developer.feature_policy([&"equipment", &"preview", &"implemented"], [&"implemented_unlock"])
	TestAssertions.equal(gate.resolve(&"equipment", FeatureAccessPolicy.State.COMING_SOON), FeatureAccessPolicy.State.COMING_SOON, "Coming Soon never unlocks", failures)
	TestAssertions.equal(gate.resolve(&"preview", FeatureAccessPolicy.State.DEVELOPER_PREVIEW), FeatureAccessPolicy.State.AVAILABLE, "Developer Preview opens in Developer Mode", failures)
	TestAssertions.equal(gate.resolve(&"implemented", FeatureAccessPolicy.State.AVAILABLE, &"implemented_unlock"), FeatureAccessPolicy.State.AVAILABLE, "Unlock All bypasses progression", failures)
	TestAssertions.equal(gate.resolve(&"unknown", FeatureAccessPolicy.State.AVAILABLE), FeatureAccessPolicy.State.HIDDEN, "unknown feature fails closed", failures)
	return failures
