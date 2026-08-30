extends RefCounted

const REPORTER_PATH := "res://scripts/world/access/warehouse_presentation_reporter.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(REPORTER_PATH), "Warehouse presentation reporter exists", failures)
	if not ResourceLoader.exists(REPORTER_PATH):
		return failures
	var reporter_script := load(REPORTER_PATH) as Script
	var emissions: Array = []
	var reporter: Variant = reporter_script.new(func(marker: String, warning: bool) -> void:
		emissions.append([marker, warning])
	)
	var player := _settings(PartyForgeSettings.Mode.PLAYER_SIMULATION, true)
	var candidate := WarehousePresentationResult.new(
		WarehousePresentationResult.State.LOCKED,
		WarehousePresentationResult.Outcome.CANDIDATE,
		&"candidate_locked",
	)
	reporter.observe(player, candidate)
	reporter.observe(player, candidate.copy())
	TestAssertions.equal(emissions.size(), 1, "repeated candidate tuples emit once", failures)
	if emissions.size() == 1:
		TestAssertions.equal((emissions[0] as Array)[1], false, "ordinary candidate observation is informational", failures)

	var changed := WarehousePresentationResult.new(
		WarehousePresentationResult.State.HIDDEN,
		WarehousePresentationResult.Outcome.CANDIDATE,
		&"candidate_hidden",
	)
	reporter.observe(player, changed)
	TestAssertions.equal(emissions.size(), 2, "changed candidate tuple re-emits", failures)

	player.use_city_access_snapshot = false
	reporter.observe(player, changed)
	player.use_city_access_snapshot = true
	reporter.observe(player, changed)
	TestAssertions.equal(emissions.size(), 3, "flag-off observation clears deduplication without emitting", failures)

	var developer := _settings(PartyForgeSettings.Mode.DEVELOPER_MODE, true)
	reporter.observe(developer, changed)
	reporter.observe(player, changed)
	TestAssertions.equal(emissions.size(), 4, "non-Player observation clears deduplication without emitting", failures)

	var failed := WarehousePresentationResult.new(
		WarehousePresentationResult.State.HIDDEN,
		WarehousePresentationResult.Outcome.CANDIDATE_FAILED,
		StringName("raw\\secret/path"),
	)
	reporter.observe(player, failed)
	var diverged := WarehousePresentationResult.new(
		WarehousePresentationResult.State.LOCKED,
		WarehousePresentationResult.Outcome.DIVERGED,
		&"candidate_cannot_grant_authority",
	)
	reporter.observe(player, diverged)
	TestAssertions.equal(emissions.size(), 6, "failed and diverged tuples each emit", failures)
	for index: int in [4, 5]:
		if index >= emissions.size():
			continue
		var marker := String((emissions[index] as Array)[0])
		TestAssertions.equal((emissions[index] as Array)[1], true, "failed or diverged result emits as warning", failures)
		TestAssertions.truthy(not marker.contains("raw") and not marker.contains("secret"), "diagnostic excludes raw strings", failures)
		TestAssertions.truthy(not marker.contains("/") and not marker.contains("\\"), "diagnostic excludes path separators", failures)
	return failures


func _settings(mode: PartyForgeSettings.Mode, enabled: bool) -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.mode = mode
	result.use_city_access_snapshot = enabled
	return result
