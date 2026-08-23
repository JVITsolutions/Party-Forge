extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning := load("res://data/progression/reward_distribution.tres") as RewardDistributionTuning
	var badge := (load("res://scenes/ui/developer_mode_badge.tscn") as PackedScene).instantiate() as DeveloperModeBadge

	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	badge.configure(RunRulesSnapshot.from_settings(player_settings), tuning)
	TestAssertions.truthy(not badge.visible, "Player Mode hides reward tuning badge", failures)
	TestAssertions.equal(badge.summary_text(), "", "Player Mode exposes no reward tuning diagnostics", failures)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.show_ground_chest_diagnostics = true
	badge.configure(RunRulesSnapshot.from_settings(developer_settings), tuning)
	TestAssertions.truthy(badge.visible, "Developer Mode shows reward tuning badge", failures)
	TestAssertions.equal(
		badge.summary_text(),
		"DEV MODE | XP SHARE 18.0m | SQUAD LINK 14.0m",
		"Developer Mode shows exact reward distances",
		failures,
	)
	TestAssertions.equal(
		(badge.get_node("Anchor/Margin/Label") as Label).text,
		"DEV MODE | XP SHARE 18.0m | SQUAD LINK 14.0m",
		"visible badge label shows exact reward distances",
		failures,
	)
	badge.update_ground_chest_diagnostics({"live": 2, "peak": 3})
	var loot_diagnostics := badge.diagnostics_text()
	TestAssertions.truthy("SESSION LOOT DIAGNOSTICS" in loot_diagnostics, "Developer Mode can show ground-loot diagnostics", failures)
	TestAssertions.truthy(badge.has_method("update_combat_diagnostics"), "Developer badge exposes combat diagnostics projection", failures)
	if not badge.has_method("update_combat_diagnostics"):
		badge.free()
		return failures
	badge.call("update_combat_diagnostics", {
		"requested_instances": 1,
		"processed_instances": 1,
		"fractional_chance": 0.05,
		"fractional_draw": 0.70,
		"fractional_success": false,
		"fractional_draw_consumed": true,
		"total_overkill": 0.0,
		"ceiling_truncated": false,
	})
	var normal_diagnostics := badge.diagnostics_text()
	TestAssertions.truthy("SESSION LOOT DIAGNOSTICS" in normal_diagnostics and "COMBAT DIAGNOSTICS" in normal_diagnostics, "combat diagnostics compose without overwriting ground-loot diagnostics", failures)
	TestAssertions.truthy("requested=1 processed=1" in normal_diagnostics, "normal bundle reports requested and processed instance counts", failures)
	TestAssertions.truthy("chance=5%" in normal_diagnostics and "outcome=MISS" in normal_diagnostics, "normal bundle reports its remainder outcome", failures)
	badge.call("update_combat_diagnostics", {
		"requested_instances": 2,
		"processed_instances": 2,
		"fractional_chance": 0.05,
		"fractional_draw": 0.04,
		"fractional_success": true,
		"fractional_draw_consumed": true,
		"total_overkill": 0.0,
		"ceiling_truncated": false,
	})
	var multi_diagnostics := badge.diagnostics_text()
	TestAssertions.truthy("requested=2 processed=2" in multi_diagnostics and "outcome=SUCCESS" in multi_diagnostics, "105 percent bundle reports its successful remainder", failures)
	badge.call("update_combat_diagnostics", {
		"requested_instances": 3,
		"processed_instances": 3,
		"fractional_chance": 0.0,
		"fractional_draw": -1.0,
		"fractional_success": false,
		"fractional_draw_consumed": false,
		"total_overkill": 80.0,
		"ceiling_truncated": false,
	})
	TestAssertions.truthy("OVERKILL 80" in badge.diagnostics_text(), "lethal bundle reports total overkill", failures)
	badge.call("update_combat_diagnostics", {
		"requested_instances": 10001,
		"processed_instances": 10000,
		"fractional_chance": 0.0,
		"fractional_draw": -1.0,
		"fractional_success": false,
		"fractional_draw_consumed": false,
		"total_overkill": 0.0,
		"ceiling_truncated": true,
	})
	TestAssertions.truthy("requested=10001 processed=10000" in badge.diagnostics_text() and "TRUNCATED" in badge.diagnostics_text(), "ceiling-limited bundle is explicitly marked truncated", failures)
	badge.configure(RunRulesSnapshot.from_settings(player_settings), tuning)
	badge.call("update_combat_diagnostics", {"requested_instances": 12, "processed_instances": 12})
	TestAssertions.truthy(not badge.visible, "Production mode stays hidden after combat diagnostics", failures)
	TestAssertions.equal(badge.diagnostics_text(), "", "Production mode exposes no combat diagnostics", failures)
	badge.free()
	return failures
