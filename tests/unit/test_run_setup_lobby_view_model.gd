extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog_truth_and_selected_compatibility(failures)
	_test_safe_failures_never_expose_technical_detail(failures)
	return failures

func _test_catalog_truth_and_selected_compatibility(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var compatibility := LoadoutCompatibilityProjection.success(&"fighter", [], [], [], [], "state")
	var projection := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"mage", compatibility, "", false)
	var fighter := _class(projection, &"fighter")
	var mage := _class(projection, &"mage")
	TestAssertions.equal(projection.state, RunSetupLobbyProjection.State.READY, "valid selected compatibility makes the lobby ready", failures)
	TestAssertions.equal(fighter.display_name, "Fighter", "class display name comes from the catalog", failures)
	TestAssertions.equal(fighter.role_label, "Frontline", "class role is humanized from the catalog enum", failures)
	TestAssertions.equal(fighter.trait_display_names, ["Martial", "Vanguard"], "class traits resolve by catalog trait display names", failures)
	TestAssertions.equal(fighter.starting_action_label, "Fighter Cleave", "primary attack ID is humanized because attacks have no display name", failures)
	TestAssertions.equal(fighter.compatibility, RunSetupClassProjection.Compatibility.COMPATIBLE, "compatibility appears on the selected class", failures)
	TestAssertions.equal(mage.compatibility, RunSetupClassProjection.Compatibility.UNKNOWN, "previewed non-selected class has no selected compatibility", failures)
	for property: Dictionary in fighter.get_property_list():
		var property_name := String(property.get("name", "")).to_lower()
		TestAssertions.truthy(not ("playstyle" in property_name or "party_fit" in property_name or "synergy" in property_name), "class projection does not invent unsupported product fields: %s" % property_name, failures)

func _test_safe_failures_never_expose_technical_detail(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var technical_detail := "PARTY_FORGE_INTERNAL stack trace database password"
	var cases: Array[RunSetupLobbyProjection] = [
		RunSetupLobbyViewModel.build(null, catalog, &"fighter", &"fighter", null, technical_detail, false),
		RunSetupLobbyViewModel.build(_malformed_profile(), catalog, &"fighter", &"fighter", null, technical_detail, false),
		RunSetupLobbyViewModel.build(profile, catalog, &"missing", &"missing", null, technical_detail, false),
		RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.failure(technical_detail), technical_detail, false),
		RunSetupLobbyViewModel.build(profile, _damaged_catalog(), &"fighter", &"fighter", null, technical_detail, false),
	]
	for index: int in cases.size():
		var projection := cases[index]
		TestAssertions.equal(projection.state, RunSetupLobbyProjection.State.UNAVAILABLE, "safe failure %d is unavailable" % index, failures)
		TestAssertions.truthy(not projection.status_copy.is_empty(), "safe failure %d has player-facing copy" % index, failures)
		TestAssertions.truthy(not projection.status_copy.contains(technical_detail), "safe failure %d hides technical detail" % index, failures)
		TestAssertions.equal(projection.seats.size(), 4, "safe failure %d preserves the stable seat board" % index, failures)

func _completed_profile() -> ProfileState:
	var profile := ProfileState.new_profile("play-lobby-profile", "Lobby Tester", 1000)
	profile.prologue_state = ProfileState.PrologueState.COMPLETED
	return profile

func _malformed_profile() -> ProfileState:
	var profile := _completed_profile()
	profile.profile_id = ""
	return profile

func _damaged_catalog() -> GameCatalog:
	var catalog := GameCatalog.new()
	catalog.classes.append(null)
	return catalog

func _class(projection: RunSetupLobbyProjection, id: StringName) -> RunSetupClassProjection:
	for item: RunSetupClassProjection in projection.classes:
		if item.id == id:
			return item
	return RunSetupClassProjection.new()
