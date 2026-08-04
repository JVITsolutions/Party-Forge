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
	badge.free()
	return failures
