extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog_truth_and_selected_compatibility(failures)
	_test_preview_never_invalidates_selected_readiness(failures)
	_test_all_selected_compatibility_branches(failures)
	_test_compatibility_copy_whitelists_safe_values(failures)
	_test_safe_failures_use_handoff_copy_and_hide_technical_detail(failures)
	_test_restart_intent_preselection_and_unresolved_state(failures)
	return failures


func _test_restart_intent_preselection_and_unresolved_state(failures: Array[String]) -> void:
	const INTENT_PATH := "res://scripts/ui/run_setup/run_setup_restart_intent.gd"
	TestAssertions.truthy(ResourceLoader.exists(INTENT_PATH), "restart intent resource exists", failures)
	var view_model_source := FileAccess.get_file_as_string("res://scripts/ui/run_setup/run_setup_lobby_view_model.gd")
	var intent_source := FileAccess.get_file_as_string(INTENT_PATH) if FileAccess.file_exists(INTENT_PATH) else ""
	for contract: String in ["class_name RunSetupRestartIntent", "static func create", "func copy", "func valid"]:
		TestAssertions.truthy(contract in intent_source, "restart intent exposes %s" % contract, failures)
	TestAssertions.truthy("restart_intent_value" in view_model_source, "lobby view model accepts typed restart intent", failures)
	TestAssertions.truthy("RESTART_SELECTION_REQUIRED_COPY" in view_model_source, "lobby owns explicit unresolved restart copy", failures)
	if not ResourceLoader.exists(INTENT_PATH) or not ("restart_intent_value" in view_model_source):
		return
	var intent_script := load(INTENT_PATH) as GDScript
	var valid_intent: Variant = intent_script.call(&"create", "play-lobby-profile", &"mage", "")
	TestAssertions.truthy(bool(valid_intent.call(&"valid")), "exact prior profile/class creates a valid restart intent", failures)
	var valid_copy: Variant = valid_intent.call(&"copy")
	TestAssertions.truthy(valid_copy != valid_intent and valid_copy.get("profile_id") == "play-lobby-profile" and valid_copy.get("class_id") == &"mage", "restart intent copy preserves exact identity defensively", failures)
	var profile := _completed_profile()
	var catalog := GameCatalog.load_defaults()
	var compatible := LoadoutCompatibilityProjection.success(&"mage", [], [], [], [], "state")
	var view_model_script := load("res://scripts/ui/run_setup/run_setup_lobby_view_model.gd") as GDScript
	var selected := view_model_script.callv(&"build", [profile, catalog, &"", &"fighter", compatible, "", false, valid_intent]) as RunSetupLobbyProjection
	TestAssertions.equal(selected.selected_class_id, &"mage", "valid restart intent preselects exact prior class", failures)
	TestAssertions.equal(selected.state, RunSetupLobbyProjection.State.READY, "valid restart intent reaches ready lobby without starting", failures)
	var invalid_intent: Variant = intent_script.call(&"create", "missing-profile", &"missing-class", "Previous run selection is unavailable.")
	var unresolved := view_model_script.callv(&"build", [profile, catalog, &"fighter", &"fighter", null, "", false, invalid_intent]) as RunSetupLobbyProjection
	TestAssertions.equal(unresolved.selected_class_id, &"", "invalid restart intent cannot retain an unrelated selected class", failures)
	TestAssertions.equal(unresolved.state, RunSetupLobbyProjection.State.NO_SELECTION, "invalid restart intent stays in unresolved selection", failures)
	TestAssertions.equal(unresolved.status_copy, "Previous run selection is unavailable.", "invalid restart intent exposes its explicit safe reason", failures)

func _test_catalog_truth_and_selected_compatibility(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var compatibility := LoadoutCompatibilityProjection.success(&"fighter", [], [], [], [], "state")
	var projection := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"mage", compatibility, "Selected Fighter is ready.", false)
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

func _test_preview_never_invalidates_selected_readiness(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var compatibility := LoadoutCompatibilityProjection.success(&"fighter", [], [], [], [], "state")
	for preview_id: StringName in [&"", &"missing"]:
		var projection := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", preview_id, compatibility, "Selected Fighter is ready.", false)
		TestAssertions.equal(projection.state, RunSetupLobbyProjection.State.READY, "invalid preview %s preserves selected readiness" % preview_id, failures)
		TestAssertions.equal(projection.selected_class_id, &"fighter", "invalid preview %s preserves selected class" % preview_id, failures)
		TestAssertions.equal(projection.previewed_class_id, &"fighter", "invalid preview %s falls back safely to selected class" % preview_id, failures)
		TestAssertions.equal(_class(projection, &"fighter").compatibility, RunSetupClassProjection.Compatibility.COMPATIBLE, "invalid preview %s retains selected compatibility" % preview_id, failures)
		_assert_seat_board(projection, "invalid preview %s" % preview_id, failures)

func _test_all_selected_compatibility_branches(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var safe_copy := "Selected loadout cannot be checked right now."
	var unknown := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", null, safe_copy, false)
	TestAssertions.equal(unknown.state, RunSetupLobbyProjection.State.CHECKING, "missing compatibility is checking", failures)
	TestAssertions.equal(_class(unknown, &"fighter").compatibility, RunSetupClassProjection.Compatibility.UNKNOWN, "missing compatibility is unknown on selected class", failures)
	TestAssertions.equal(_class(unknown, &"fighter").compatibility_copy, {}, "missing compatibility has no copied detail", failures)
	_assert_seat_board(unknown, "unknown compatibility", failures)

	var unavailable := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.failure("PARTY_FORGE_INTERNAL trace"), safe_copy, false)
	TestAssertions.equal(unavailable.state, RunSetupLobbyProjection.State.UNAVAILABLE, "invalid compatibility is unavailable", failures)
	TestAssertions.equal(unavailable.status_copy, safe_copy, "invalid compatibility uses supplied safe copy", failures)
	TestAssertions.equal(_class(unavailable, &"fighter").compatibility, RunSetupClassProjection.Compatibility.UNAVAILABLE, "invalid compatibility is unavailable on selected class", failures)
	TestAssertions.equal(_class(unavailable, &"fighter").compatibility_copy, {}, "invalid compatibility has no copied technical detail", failures)
	_assert_seat_board(unavailable, "unavailable compatibility", failures)

	var compatible := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.success(&"fighter", [], [], [], [], "state"), safe_copy, false)
	TestAssertions.equal(compatible.state, RunSetupLobbyProjection.State.READY, "empty incompatible list is ready", failures)
	TestAssertions.equal(_class(compatible, &"fighter").compatibility, RunSetupClassProjection.Compatibility.COMPATIBLE, "empty incompatible list is compatible", failures)
	TestAssertions.equal(_class(compatible, &"fighter").compatibility_copy, {"incompatible_item_count": 0, "summary": "Ready to begin your run."}, "compatible output exposes only curated zero-count values", failures)
	_assert_seat_board(compatible, "compatible", failures)

	var incompatible_items: Array[Dictionary] = [{"instance_id": "item-1", "source_container_id": "leader-loadout", "source_slot": 0, "nested": {"reason": "slot"}}]
	var needs_attention := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.success(&"fighter", [], incompatible_items, [], [], "state"), safe_copy, false)
	(incompatible_items[0]["nested"] as Dictionary)["reason"] = "changed source"
	var copied_detail := _class(needs_attention, &"fighter").compatibility_copy
	copied_detail["summary"] = "changed returned"
	TestAssertions.equal(needs_attention.state, RunSetupLobbyProjection.State.NEEDS_ATTENTION, "nonempty incompatible list needs attention", failures)
	TestAssertions.equal(_class(needs_attention, &"fighter").compatibility, RunSetupClassProjection.Compatibility.NEEDS_ATTENTION, "nonempty incompatible list is needs-attention on selected class", failures)
	TestAssertions.equal(_class(needs_attention, &"fighter").compatibility_copy, {"incompatible_item_count": 1, "summary": "Review your equipped items before starting."}, "incompatible data reduces to curated count and summary", failures)
	_assert_seat_board(needs_attention, "needs attention", failures)

	var mismatch := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.success(&"mage", [], [], [], [], "state"), safe_copy, false)
	TestAssertions.equal(mismatch.state, RunSetupLobbyProjection.State.UNAVAILABLE, "wrong-class compatibility is unavailable", failures)
	TestAssertions.equal(mismatch.status_copy, safe_copy, "wrong-class compatibility uses supplied safe copy", failures)
	TestAssertions.equal(mismatch.selected_class_id, &"fighter", "wrong-class compatibility preserves selected ID", failures)
	TestAssertions.equal(_class(mismatch, &"fighter").compatibility, RunSetupClassProjection.Compatibility.UNKNOWN, "wrong-class compatibility is never applied to selected class", failures)
	TestAssertions.equal(_class(mismatch, &"fighter").compatibility_copy, {}, "wrong-class compatibility contributes no child data", failures)
	_assert_seat_board(mismatch, "mismatched compatibility", failures)

func _test_compatibility_copy_whitelists_safe_values(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var technical_reason := "PARTY_FORGE_EQUIPMENT_ERROR item=sword reason=source slot is invalid"
	var mutable_reference := RefCounted.new()
	var raw_items: Array[Dictionary] = [{
		"instance_id": "item-private-001",
		"source_container_id": "leader-loadout-private",
		"source_slot": 7,
		"reasons": [technical_reason],
		"nested": {"arbitrary_key": mutable_reference},
	}]
	var compatibility := LoadoutCompatibilityProjection.success(&"fighter", [], raw_items, [], [], "state")
	var projection := RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", compatibility, "Selected loadout needs review.", false)
	var detail := _class(projection, &"fighter").compatibility_copy
	TestAssertions.equal(projection.state, RunSetupLobbyProjection.State.NEEDS_ATTENTION, "raw incompatible entries still derive needs-attention from list emptiness", failures)
	TestAssertions.equal(_class(projection, &"fighter").compatibility, RunSetupClassProjection.Compatibility.NEEDS_ATTENTION, "raw incompatible entries retain selected compatibility state", failures)
	TestAssertions.equal(detail, {"incompatible_item_count": 1, "summary": "Review your equipped items before starting."}, "compatibility projection is a curated whitelist", failures)
	_assert_curated_compatibility_value(detail, technical_reason, "compatibility output", failures)

func _test_safe_failures_use_handoff_copy_and_hide_technical_detail(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var profile := _completed_profile()
	var technical_detail := "PARTY_FORGE_INTERNAL stack trace database password"
	var safe_copy := "Class selection cannot be prepared right now."
	var cases: Array[RunSetupLobbyProjection] = [
		RunSetupLobbyViewModel.build(null, catalog, &"fighter", &"fighter", null, safe_copy, false),
		RunSetupLobbyViewModel.build(_malformed_profile(), catalog, &"fighter", &"fighter", null, safe_copy, false),
		RunSetupLobbyViewModel.build(profile, catalog, &"missing", &"missing", null, safe_copy, false),
		RunSetupLobbyViewModel.build(profile, catalog, &"fighter", &"fighter", LoadoutCompatibilityProjection.failure(technical_detail), safe_copy, false),
		RunSetupLobbyViewModel.build(profile, _damaged_catalog(), &"fighter", &"fighter", null, safe_copy, false),
	]
	for index: int in cases.size():
		var projection := cases[index]
		TestAssertions.equal(projection.state, RunSetupLobbyProjection.State.UNAVAILABLE, "safe failure %d is unavailable" % index, failures)
		TestAssertions.equal(projection.status_copy, safe_copy, "safe failure %d uses exact player-facing handoff copy" % index, failures)
		_assert_no_technical_detail(projection, technical_detail, "safe failure %d" % index, failures)
		_assert_seat_board(projection, "safe failure %d" % index, failures)
		if index in [0, 1, 2, 4]:
			TestAssertions.equal(projection.selected_class_id, &"", "safe failure %d clears unavailable selection ID" % index, failures)
			TestAssertions.equal(projection.previewed_class_id, &"", "safe failure %d clears unavailable preview ID" % index, failures)
			TestAssertions.equal(projection.classes, [] as Array[RunSetupClassProjection], "safe failure %d has no unusable class data" % index, failures)
		else:
			TestAssertions.equal(projection.selected_class_id, &"fighter", "invalid compatibility %d retains selected ID" % index, failures)
			TestAssertions.equal(projection.previewed_class_id, &"fighter", "invalid compatibility %d retains preview ID" % index, failures)
			TestAssertions.equal(_class(projection, &"fighter").compatibility, RunSetupClassProjection.Compatibility.UNAVAILABLE, "invalid compatibility has unavailable selected child" , failures)

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

func _assert_seat_board(projection: RunSetupLobbyProjection, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(projection.seats.size(), 4, "%s has exactly four seats" % label, failures)
	if projection.seats.size() != 4:
		return
	TestAssertions.equal(projection.seats[0].state, RunSetupSeatProjection.State.ACTIVE, "%s P1 is active" % label, failures)
	TestAssertions.truthy(projection.seats[0].focusable, "%s P1 is focusable" % label, failures)
	for index: int in range(1, 4):
		TestAssertions.equal(projection.seats[index].state, RunSetupSeatProjection.State.COMING_SOON, "%s P%d is coming soon" % [label, index + 1], failures)
		TestAssertions.truthy(not projection.seats[index].focusable, "%s P%d is not focusable" % [label, index + 1], failures)

func _assert_no_technical_detail(projection: RunSetupLobbyProjection, technical_detail: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not projection.status_copy.contains(technical_detail), "%s status hides technical detail" % label, failures)
	for class_projection: RunSetupClassProjection in projection.classes:
		TestAssertions.truthy(not class_projection.display_name.contains(technical_detail), "%s class display hides technical detail" % label, failures)
		TestAssertions.truthy(not class_projection.role_label.contains(technical_detail), "%s class role hides technical detail" % label, failures)
		TestAssertions.truthy(not class_projection.starting_action_label.contains(technical_detail), "%s action hides technical detail" % label, failures)
		TestAssertions.truthy(not JSON.stringify(class_projection.compatibility_copy).contains(technical_detail), "%s compatibility copy hides technical detail" % label, failures)

func _assert_curated_compatibility_value(value: Variant, technical_reason: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not value is Object, "%s contains no object or reference" % label, failures)
	if value is String:
		TestAssertions.truthy(not (value as String).contains(technical_reason), "%s hides technical strings" % label, failures)
		return
	if value is Array:
		for item: Variant in value as Array:
			_assert_curated_compatibility_value(item, technical_reason, label, failures)
		return
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			var key_text := String(key)
			TestAssertions.truthy(key_text in ["incompatible_item_count", "summary"], "%s rejects raw/arbitrary key %s" % [label, key_text], failures)
			TestAssertions.truthy(key_text not in ["instance_id", "source_container_id", "source_slot", "reasons"], "%s rejects source identity/reason key %s" % [label, key_text], failures)
			_assert_curated_compatibility_value((value as Dictionary)[key], technical_reason, label, failures)
