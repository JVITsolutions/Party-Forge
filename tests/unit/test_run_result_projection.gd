extends RefCounted

const FIXTURE_PATH := "res://tests/unit/test_run_recap_projection.gd"
const VIEW_MODEL_PATH := "res://scripts/ui/run_result/run_result_view_model.gd"
const PROJECTION_PATH := "res://scripts/ui/run_result/run_result_projection.gd"
const PROJECTION_RESULT_PATH := "res://scripts/ui/run_result/run_result_projection_result.gd"

class OptionalWarningCapture:
	extends Logger
	var messages := PackedStringArray()

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		messages.append(rationale if not rationale.is_empty() else code)

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture_type := load(FIXTURE_PATH) as Script
	var view_model_type := load(VIEW_MODEL_PATH) as Script
	var projection_type := load(PROJECTION_PATH) as Script
	var projection_result_type := load(PROJECTION_RESULT_PATH) as Script
	TestAssertions.truthy(view_model_type != null, "truth-only run result view model exists", failures)
	TestAssertions.truthy(projection_type != null, "typed run result projection exists", failures)
	TestAssertions.truthy(projection_result_type != null, "typed run result projection result exists", failures)
	if fixture_type == null or view_model_type == null or projection_type == null or projection_result_type == null:
		return failures

	var fixture_helper: Variant = fixture_type.new()
	var custom_order: Array[int] = [3, 1, 2]
	var fixture: Dictionary = fixture_helper.call(&"_fixture", 3, 3, RunTerminalSnapshot.Outcome.VICTORY, custom_order)
	var view_model: Variant = view_model_type.new()
	var empty_provider: Variant = fixture_helper.call(&"provider", &"empty", 1, &"empty", 5)
	var failed_provider: Variant = fixture_helper.call(&"provider", &"failed_optional", 2, &"failure", 4)
	var invalid_provider: Variant = fixture_helper.call(&"provider", &"invalid_optional", 3, &"invalid", 5)
	var build_alpha: Variant = fixture_helper.call(&"provider", &"alpha_build_test", 10, &"section", 2)
	var build_zeta: Variant = fixture_helper.call(&"provider", &"zeta_build_test", 10, &"section", 2)
	var highlight_early: Variant = fixture_helper.call(&"provider", &"highlight_early_test", 1, &"section", 5)
	var highlight_late: Variant = fixture_helper.call(&"provider", &"highlight_late_test", 9, &"section", 5)
	var providers: Array = [highlight_late, failed_provider, build_zeta, empty_provider, highlight_early, invalid_provider, build_alpha]
	var warning_capture := OptionalWarningCapture.new()
	OS.add_logger(warning_capture)
	var built: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, providers)
	OS.remove_logger(warning_capture)
	TestAssertions.truthy(built != null and bool(built.call(&"ok")), "valid current truth builds one finalized projection", failures)
	if built == null or not bool(built.call(&"ok")):
		return failures
	var projection: Variant = built.get("projection")
	var expected_ids: Array[StringName] = [&"outcome", &"party", &"alpha_build_test", &"zeta_build_test", &"loot", &"highlight_early_test", &"highlight_late_test"]
	TestAssertions.equal(projection.call(&"section_ids"), expected_ids, "providers sort by semantic kind, display order, then provider ID", failures)
	providers.reverse()
	var reversed: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, providers)
	TestAssertions.truthy(bool(reversed.call(&"ok")) and reversed.get("projection").call(&"section_ids") == expected_ids, "reversed provider input produces identical stable IDs", failures)
	var captured_warning := ""
	var captured_invalid_warning := ""
	for message: String in warning_capture.messages:
		if message.contains("RUN_RECAP_PROVIDER_OMITTED id=failed_optional"):
			captured_warning = message
		if message.contains("RUN_RECAP_PROVIDER_OMITTED id=invalid_optional"):
			captured_invalid_warning = message
	TestAssertions.equal(captured_warning, "RUN_RECAP_PROVIDER_OMITTED id=failed_optional error=test provider failed exactly", "failed optional provider logs stable ID and exact returned error", failures)
	TestAssertions.equal(captured_invalid_warning, "RUN_RECAP_PROVIDER_OMITTED id=invalid_optional error=provider section is unavailable", "invalid optional provider logs stable ID and exact typed error", failures)
	var core_only: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [])
	TestAssertions.truthy(bool(core_only.call(&"ok")) and core_only.get("projection").call(&"section_ids") == [&"outcome", &"party", &"loot"], "production core has no build, consequence, telemetry, or highlight provider", failures)
	var mutating_provider: Variant = fixture_helper.call(&"provider", &"mutating_provider", 0, &"mutate", 5)
	var observing_provider: Variant = fixture_helper.call(&"provider", &"observing_provider", 1, &"observe", 5)
	var isolated_providers: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [mutating_provider, observing_provider])
	TestAssertions.truthy(bool(isolated_providers.call(&"ok")), "each optional provider receives a fresh defensive resolution copy", failures)
	if bool(isolated_providers.call(&"ok")):
		TestAssertions.equal(isolated_providers.get("projection").call(&"section_ids"), [&"outcome", &"party", &"loot", &"observing_provider"], "mutating provider cannot alter later provider or core truth", failures)
	for unsupported_id: StringName in [&"build", &"build_history", &"telemetry", &"consequence"]:
		TestAssertions.truthy(unsupported_id not in projection.call(&"section_ids"), "unsupported %s section is absent" % unsupported_id, failures)
	TestAssertions.equal(int(projection.get("terminal_state")), 2, "valid build is typed FINALIZED", failures)
	TestAssertions.truthy(bool(projection.get("restart_run_allowed")) and bool(projection.get("return_to_forge_allowed")) and bool(projection.get("quit_application_allowed")), "finalized projection alone exposes consequence actions", failures)
	TestAssertions.truthy(not bool(projection.get("retry_terminal_save_allowed")) and not bool(projection.get("retry_resolution_allowed")) and not bool(projection.get("retry_projection_allowed")), "finalized projection exposes no stale retry action", failures)
	var sections: Array = projection.get("sections")
	TestAssertions.equal(_entry_value(sections[0], "Outcome"), "Victory", "outcome comes from exact terminal event", failures)
	TestAssertions.equal(_entry_value(sections[0], "Duration"), "01:30", "duration is bounded deterministic terminal truth", failures)
	TestAssertions.equal(sections[1].get("entries").size(), 3, "every ordered party member is projected", failures)
	TestAssertions.equal(_labels(sections[1]), ["Mira", "Zara", "Asha"], "party preserves terminal snapshot order instead of sorting by ID or name", failures)
	TestAssertions.equal(_entry_value(sections[1], "Mira"), "Mage · Level 9", "party projects exact class and final level", failures)
	TestAssertions.equal(_entry_value(sections[1], "Zara"), "Leader · Fighter · Level 7", "party projects exact leader role, class, and final level", failures)
	TestAssertions.equal(_entry_value(sections[1], "Asha"), "Ranger · Level 8", "party projects exact trailing class and final level", failures)
	var loot_section: Variant
	for section: Variant in sections:
		if section.get("section_id") == &"loot": loot_section = section
	TestAssertions.truthy(loot_section != null, "required loot section is present", failures)
	if loot_section != null:
		var allowed_loot_labels := ["Automatic retention", "Selected extraction", "Lost", "Protected displaced gear"]
		for entry: Variant in loot_section.get("entries"):
			TestAssertions.truthy(String(entry.get("label")) in allowed_loot_labels, "loot emits only exact allowed truth labels", failures)
		TestAssertions.equal(_label_count(loot_section, "Automatic retention"), 2, "every verified automatic ID is projected", failures)
		TestAssertions.equal(_label_count(loot_section, "Selected extraction"), 2, "every verified selected ID is projected", failures)
		TestAssertions.equal(_label_count(loot_section, "Lost"), 3, "every proven absent lost ID is projected", failures)
		TestAssertions.equal(_label_count(loot_section, "Protected displaced gear"), 2, "every exact accepted protected ID is projected", failures)
	var forbidden_claims := ["Damage", "Kills", "Build", "Upgrade", "Telemetry", "Highlight", "Value", "Profile delta"]
	for section: Variant in sections:
		for entry: Variant in section.get("entries"):
			for forbidden: String in forbidden_claims:
				TestAssertions.truthy(not String(entry.get("label")).contains(forbidden), "unsupported claim label %s is absent" % forbidden, failures)
	var escaped_sections: Array = projection.get("sections")
	escaped_sections.clear()
	TestAssertions.equal(projection.call(&"section_ids"), expected_ids, "projection sections are defensive", failures)

	var duplicate_a: Variant = fixture_helper.call(&"provider", &"duplicate", 0, &"empty", 5)
	var duplicate_b: Variant = fixture_helper.call(&"provider", &"duplicate", 1, &"section", 5)
	var duplicate_result: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [duplicate_b, duplicate_a])
	TestAssertions.truthy(not bool(duplicate_result.call(&"ok")) and String(duplicate_result.get("error")).contains("duplicate"), "duplicate optional provider IDs reject deterministically", failures)
	var reversed_duplicate: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [duplicate_a, duplicate_b])
	TestAssertions.equal(String(reversed_duplicate.get("error")), String(duplicate_result.get("error")), "reversed duplicate-provider inputs return the identical exact error", failures)
	for reserved_id: StringName in [&"outcome", &"party", &"loot"]:
		var reserved: Variant = fixture_helper.call(&"provider", reserved_id, -99, &"section", 5)
		var reserved_result: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [reserved])
		TestAssertions.truthy(not bool(reserved_result.call(&"ok")) and String(reserved_result.get("error")) == "optional provider ID %s is reserved" % reserved_id, "reserved core provider ID %s rejects exactly" % reserved_id, failures)
	var blank: Variant = fixture_helper.call(&"provider", &"", 0, &"empty", 5)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [blank]).call(&"ok")), "blank provider identity rejects", failures)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [RefCounted.new()]).call(&"ok")), "malformed non-provider shape fails closed", failures)

	_test_core_loot_fail_closed(view_model, fixture, failures)
	_test_typed_state_constructors(view_model, fixture, failures)
	_test_finalized_projection_validation(projection_type, projection, failures)
	return failures

func _test_core_loot_fail_closed(view_model: Variant, fixture: Dictionary, failures: Array[String]) -> void:
	var automatic_missing: ProfileState = fixture.profile.copy()
	(automatic_missing.leader_loadout["slots"] as Dictionary).erase("9")
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, automatic_missing, []).call(&"ok")), "automatic claim fails if refreshed leader loadout lacks the exact ID", failures)

	var selected_missing: ProfileState = fixture.profile.copy()
	(selected_missing.stash_tabs[0]["slots"] as Dictionary).erase("0")
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, selected_missing, []).call(&"ok")), "selected claim fails if refreshed stash lacks the exact ID", failures)

	var protected_missing: ProfileState = fixture.profile.copy()
	(protected_missing.terminal_recovery_overflow["slots"] as Dictionary).erase("0")
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, protected_missing, []).call(&"ok")), "protected claim fails if refreshed Recovery Overflow lacks the accepted ID", failures)

	var resurrected: ProfileState = fixture.profile.copy()
	var lost_id := String(fixture.lost_ids[0])
	var lost_item: ItemInstance = fixture.snapshot.resolution_source.item_state.registry().item(lost_id)
	(resurrected.item_records["items"] as Array).append(lost_item.to_dictionary())
	(resurrected.stash_tabs[0]["slots"] as Dictionary)["2"] = lost_id
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, resurrected, []).call(&"ok")), "lost claim fails if the ID survives anywhere in refreshed durable truth", failures)

	var wrong_profile: ProfileState = fixture.profile.copy()
	wrong_profile.profile_id = "wrong-profile"
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, fixture.resolution, wrong_profile, []).call(&"ok")), "mismatched refreshed profile rejects the complete recap", failures)
	var failed_resolution := RunResolutionResult.failure("not accepted")
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, failed_resolution, fixture.profile, []).call(&"ok")), "unaccepted resolution cannot create partial success", failures)

	var accepted: RunExtractionProjection = fixture.resolution.accepted_extraction
	var duplicate_automatic := RunExtractionProjection.create(
		[fixture_helper_id("automatic"), fixture_helper_id("automatic")], accepted.eligible_items,
		accepted.selected_item_ids, accepted.lost_item_ids, accepted.capacity, [],
	)
	var duplicate_resolution := RunResolutionResult.success(fixture.profile, false, duplicate_automatic, fixture.resolution.protected_displaced_item_ids)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, duplicate_resolution, fixture.profile, []).call(&"ok")), "duplicate IDs inside one loot bucket reject", failures)

	var overlapping := RunExtractionProjection.create(
		accepted.automatic_item_ids, accepted.eligible_items,
		[accepted.automatic_item_ids[0], accepted.selected_item_ids[1]], accepted.lost_item_ids, accepted.capacity, [],
	)
	var overlap_resolution := RunResolutionResult.success(fixture.profile, false, overlapping, fixture.resolution.protected_displaced_item_ids)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, overlap_resolution, fixture.profile, []).call(&"ok")), "IDs crossing automatic and selected categories reject", failures)

	var protected_overlap: Array[String] = fixture.resolution.protected_displaced_item_ids
	protected_overlap[0] = accepted.automatic_item_ids[0]
	var protected_overlap_resolution := RunResolutionResult.success(fixture.profile, false, accepted, protected_overlap)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, protected_overlap_resolution, fixture.profile, []).call(&"ok")), "IDs crossing protected and retained categories reject", failures)

	var unrelated_overflow_profile: ProfileState = fixture.profile.copy()
	var no_protected := RunResolutionResult.success(unrelated_overflow_profile, false, accepted, [])
	var no_protected_build: Variant = view_model.call(&"build", fixture.snapshot, no_protected, unrelated_overflow_profile, [])
	TestAssertions.truthy(bool(no_protected_build.call(&"ok")), "unrelated Recovery Overflow contents do not invalidate an empty typed protected set", failures)
	if bool(no_protected_build.call(&"ok")):
		TestAssertions.equal(_label_count(_section(no_protected_build.get("projection"), &"loot"), "Protected displaced gear"), 0, "empty typed protected IDs omit the protected claim despite unrelated overflow", failures)
	var unrelated_ids: Array[String] = ["unrelated-protected-id"]
	var unrelated_protected := RunResolutionResult.success(fixture.profile, false, accepted, unrelated_ids)
	TestAssertions.truthy(not bool(view_model.call(&"build", fixture.snapshot, unrelated_protected, fixture.profile, []).call(&"ok")), "invalid or unrelated typed protected IDs reject rather than infer a claim", failures)

func _test_typed_state_constructors(view_model: Variant, fixture: Dictionary, failures: Array[String]) -> void:
	var pending: Variant = view_model.call(&"pending", fixture.snapshot)
	TestAssertions.truthy(bool(pending.call(&"ok")), "pending constructor returns typed projection result", failures)
	var pending_projection: Variant = pending.get("projection")
	TestAssertions.equal(int(pending_projection.get("terminal_state")), 0, "pending constructor sets PENDING", failures)
	TestAssertions.equal(pending_projection.call(&"section_ids"), [], "pending never exposes a partial recap", failures)
	TestAssertions.truthy(not _any_action_allowed(pending_projection), "pending disables every result action", failures)

	var save_failed: Variant = view_model.call(&"terminal_save_interrupted", fixture.snapshot, "Terminal record could not be saved.")
	var save_projection: Variant = save_failed.get("projection")
	TestAssertions.equal(int(save_projection.get("interruption_kind")), 0, "save failure has exact TERMINAL_STATE_SAVE kind", failures)
	TestAssertions.truthy(bool(save_projection.get("retry_terminal_save_allowed")) and not bool(save_projection.get("retry_resolution_allowed")), "save failure exposes only Retry Save Terminal State", failures)

	var unsafe_resolution: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, "Resolution was interrupted.", null)
	var unsafe_projection: Variant = unsafe_resolution.get("projection")
	TestAssertions.equal(int(unsafe_projection.get("interruption_kind")), 1, "resolution failure has exact RESOLUTION kind", failures)
	TestAssertions.truthy(bool(unsafe_projection.get("retry_resolution_allowed")) and not bool(unsafe_projection.get("protect_displaced_gear_allowed")), "ordinary resolution failure exposes only stage-accurate retry", failures)
	TestAssertions.truthy(not bool(unsafe_projection.get("open_armoury_allowed")) and not bool(unsafe_projection.get("return_to_forge_allowed")) and not bool(unsafe_projection.get("quit_application_allowed")), "unsafe interruption exposes no navigation", failures)

	var automatic_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space.")
	var automatic_preflight := RunResolutionPreflightResult.from_evaluation(automatic_evaluation)
	var durable := _durable_safety(fixture.snapshot, ["displaced-a", "displaced-b"])
	var guarded: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, automatic_preflight.player_reason, {"durable": durable, "preflight": automatic_preflight})
	var guarded_projection: Variant = guarded.get("projection")
	TestAssertions.truthy(bool(guarded_projection.get("protect_displaced_gear_allowed")) and int(guarded_projection.get("displaced_gear_count")) == 2, "typed automatic-only preflight exposes exact protection count", failures)
	TestAssertions.truthy(bool(guarded_projection.get("open_armoury_allowed")) and bool(guarded_projection.get("return_to_forge_allowed")) and bool(guarded_projection.get("quit_application_allowed")), "typed durable safety alone authorizes interrupted navigation", failures)
	TestAssertions.truthy(not bool(guarded_projection.get("restart_run_allowed")), "Restart is absent from guarded interruption", failures)

	var reducible_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "reducible blocked", RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE, "Selected extraction can be reduced.")
	var reducible := RunResolutionPreflightResult.from_evaluation(reducible_evaluation)
	var negative_safety_cases: Array = [
		{"name": "non automatic-only category", "safety": {"durable": durable, "preflight": reducible}, "navigation": true},
		{"name": "malformed recovery dictionary", "safety": {"durable": {"safe": true}, "preflight": {"automatic_only_blocked": true}}, "navigation": false},
		{"name": "unsafe durable record", "safety": {"durable": RunTerminalRecoverySafetyResult.failure("unsafe"), "preflight": automatic_preflight}, "navigation": false},
		{"name": "missing displaced IDs", "safety": {"durable": _durable_safety(fixture.snapshot, []), "preflight": automatic_preflight}, "navigation": true},
	]
	for test_case: Dictionary in negative_safety_cases:
		var denied: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, automatic_preflight.player_reason, test_case.safety).get("projection")
		TestAssertions.truthy(not bool(denied.get("protect_displaced_gear_allowed")), "Protect hides for %s" % test_case.name, failures)
		var navigation_allowed := bool(denied.get("open_armoury_allowed")) and bool(denied.get("return_to_forge_allowed")) and bool(denied.get("quit_application_allowed"))
		TestAssertions.equal(navigation_allowed, bool(test_case.navigation), "typed durable navigation is independent from Protect predicate for %s" % test_case.name, failures)

	var projection_failed: Variant = view_model.call(&"projection_interrupted", fixture.snapshot, fixture.resolution, "Results could not be built.")
	var retry_projection: Variant = projection_failed.get("projection")
	TestAssertions.equal(int(retry_projection.get("interruption_kind")), 2, "projection failure has exact PROJECTION kind", failures)
	TestAssertions.truthy(bool(retry_projection.get("retry_projection_allowed")) and not bool(retry_projection.get("retry_resolution_allowed")), "projection failure exposes only Retry Results", failures)
	TestAssertions.equal(retry_projection.call(&"section_ids"), [], "projection interruption never leaks accepted but unvalidated recap claims", failures)

func _entry_value(section: Variant, label: String) -> String:
	for entry: Variant in section.get("entries"):
		if String(entry.get("label")) == label:
			return String(entry.get("value"))
	return ""

func _labels(section: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in section.get("entries"):
		result.append(String(entry.get("label")))
	return result

func _label_count(section: Variant, label: String) -> int:
	var result := 0
	if section == null: return result
	for entry: Variant in section.get("entries"):
		if String(entry.get("label")) == label: result += 1
	return result

func _section(projection: Variant, section_id: StringName) -> Variant:
	for section: Variant in projection.get("sections"):
		if section.get("section_id") == section_id: return section
	return null

func fixture_helper_id(kind: String) -> String:
	return "run-results-%s" % kind

func _durable_safety(snapshot: RunTerminalSnapshot, displaced_ids: Array[String]) -> RunTerminalRecoverySafetyResult:
	var empty: Array[String] = []
	var record_result := RunTerminalRecoveryRecord.create(
		RunTerminalRecoveryRecord.Stage.CHOOSING_EXTRACTION, snapshot,
		empty, "", displaced_ids, "", null, "",
	)
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)

func _test_finalized_projection_validation(projection_type: Script, projection: Variant, failures: Array[String]) -> void:
	var sections: Array = projection.get("sections")
	var members: Array = projection.get("party_members")
	var actions := {"restart_run": true, "return_to_forge": true, "quit_application": true}
	var duplicated := sections.duplicate()
	duplicated.append(sections[0])
	TestAssertions.truthy(not bool(projection_type.call(&"create", 2, projection.get("snapshot"), duplicated, members, -1, "", actions).call(&"valid")), "finalized projection rejects duplicate core sections", failures)
	var out_of_order: Array = [sections[1], sections[0]]
	for index: int in range(2, sections.size()): out_of_order.append(sections[index])
	TestAssertions.truthy(not bool(projection_type.call(&"create", 2, projection.get("snapshot"), out_of_order, members, -1, "", actions).call(&"valid")), "finalized projection rejects out-of-order core sections", failures)
	var outcome: Variant = sections[0]
	var wrong_kind := RunRecapSectionProjection.create(&"outcome", outcome.get("title"), RunRecapSectionProjection.SemanticKind.PARTY, outcome.get("entries"), outcome.get("summary"))
	var wrong_kind_sections := sections.duplicate()
	wrong_kind_sections[0] = wrong_kind
	TestAssertions.truthy(not bool(projection_type.call(&"create", 2, projection.get("snapshot"), wrong_kind_sections, members, -1, "", actions).call(&"valid")), "finalized projection rejects wrong core semantic kind", failures)
	var forged_outcome_entries: Array = [RunRecapEntryProjection.create("Outcome", "Defeat"), RunRecapEntryProjection.create("Duration", "99:99")]
	var forged_outcome := RunRecapSectionProjection.create(&"outcome", outcome.get("title"), RunRecapSectionProjection.SemanticKind.OUTCOME, forged_outcome_entries, "forged")
	var forged_sections := sections.duplicate()
	forged_sections[0] = forged_outcome
	TestAssertions.truthy(not bool(projection_type.call(&"create", 2, projection.get("snapshot"), forged_sections, members, -1, "", actions).call(&"valid")), "finalized projection rejects core content that contradicts snapshot truth", failures)
	TestAssertions.truthy(not bool(projection_type.call(&"create", 2, projection.get("snapshot"), sections, [], -1, "", actions).call(&"valid")), "finalized projection rejects empty typed party members", failures)

func _any_action_allowed(projection: Variant) -> bool:
	for field: StringName in [
		&"retry_terminal_save_allowed", &"retry_resolution_allowed", &"retry_projection_allowed",
		&"protect_displaced_gear_allowed", &"open_armoury_allowed", &"restart_run_allowed",
		&"return_to_forge_allowed", &"quit_application_allowed",
	]:
		if bool(projection.get(field)):
			return true
	return false
