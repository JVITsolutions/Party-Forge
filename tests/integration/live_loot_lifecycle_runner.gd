extends SceneTree

const PROFILE_ROOT := "user://tests/live_loot_lifecycle_profiles"
const SETTINGS_PATH := "user://tests/live_loot_lifecycle_settings.cfg"

var _failures: Array[String] = []

func _initialize() -> void:
	if "--check-only" in OS.get_cmdline_args():
		quit(0)
		return
	call_deferred(&"_run")

func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	if not _runtime_terminal_contract_available():
		ProfileTestSupport.remove_tree(PROFILE_ROOT)
		_cleanup_settings()
		_finish()
		return
	for outcome: RunTerminalSnapshot.Outcome in [RunTerminalSnapshot.Outcome.VICTORY, RunTerminalSnapshot.Outcome.DEFEAT]:
		await _verify_terminal_capture_preserves_live_loot(outcome)
	await _verify_resolution_projection_and_finalize_retention()
	var subsequent := _started_main("subsequent")
	if subsequent != null:
		_assert((subsequent.get("ground_item_registry") as GroundItemRegistry).all_records().is_empty(), "subsequent run starts with zero ground records")
		_assert(_active_chest_count(subsequent) == 0, "subsequent run starts with zero projected chests")
		_assert(_diagnostics_text(subsequent) == _zero_diagnostics_text(), "subsequent run immediately presents fresh zero diagnostics after prior activity")
		_cleanup_main(subsequent)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_finish()

func _verify_terminal_capture_preserves_live_loot(outcome: RunTerminalSnapshot.Outcome) -> void:
	var label := "victory" if outcome == RunTerminalSnapshot.Outcome.VICTORY else "defeat"
	var main := _started_main(label)
	if main == null:
		return
	var fixture := _create_live_loot(main, label)
	if fixture.is_empty():
		_cleanup_main(main)
		return
	var registry := fixture.registry as GroundItemRegistry
	var live_count := registry.all_records().size()
	_assert_terminal_api(main, label)
	if outcome == RunTerminalSnapshot.Outcome.VICTORY:
		main.call(&"_show_victory")
	else:
		main.call(&"_show_defeat")
	await process_frame
	_assert(registry.all_records().size() == live_count, "%s terminal capture retains authoritative live loot while choosing extraction" % label)
	_assert(_active_chest_count(main) == live_count, "%s terminal capture retains projected live loot while choosing extraction" % label)
	_assert(main.get("ground_item_registry") == registry, "%s terminal capture retains the live loot graph while choosing extraction" % label)
	var flow: Variant = main.get("_terminal_flow")
	_assert(flow != null and int(flow.call(&"state")) == RunTerminalFlow.State.CHOOSING_EXTRACTION, "%s terminal capture enters the typed extraction-choice state" % label)
	var extraction := main.get_node_or_null("HUD/TerminalExtraction") as TerminalExtractionPanel
	_assert(extraction != null and extraction.visible, "%s terminal capture presents the extraction picker" % label)
	if extraction != null and extraction.has_signal(&"confirm_requested"):
		var pending_observed := {"registry": false, "projection": false}
		flow.resolution_pending.connect(func() -> void:
			pending_observed.registry = registry.all_records().size() == live_count
			pending_observed.projection = _active_chest_count(main) == live_count
		, CONNECT_ONE_SHOT)
		extraction.confirm_requested.emit()
		await process_frame
		_assert(bool(pending_observed.registry), "%s pending resolution retains authoritative live loot" % label)
		_assert(bool(pending_observed.projection), "%s pending resolution retains projected live loot" % label)
		_assert(registry.all_records().is_empty() and _active_chest_count(main) == 0, "%s accepted recap/finalize clears live loot only after pending resolution" % label)
	_cleanup_main(main)

func _verify_resolution_projection_and_finalize_retention() -> void:
	var main := _started_main("faults")
	if main == null:
		return
	var fixture := _create_live_loot(main, "faults")
	if fixture.is_empty():
		_cleanup_main(main)
		return
	var registry := fixture.registry as GroundItemRegistry
	var live_count := registry.all_records().size()
	var existing_flow: Variant = main.get("_terminal_flow")
	_assert(existing_flow != null, "fault-injection fixture exposes the terminal flow")
	if existing_flow == null:
		_cleanup_main(main)
		return
	var profile := main.call(&"active_profile") as ProfileState
	var context := main.get("active_run_context") as PlayerRunContext
	var root_path := String(main.get("profile_root"))
	if not main.has_method(&"_on_terminal"):
		_assert(false, "fault-injection fixture exposes Main terminal orchestration")
	else:
		var resolution_script := _fail_first_resolution_script()
		_assert(resolution_script != null, "fault-injection resolver compiles at runtime")
		if resolution_script == null:
			_cleanup_main(main)
			return
		var injected_resolution: Variant = resolution_script.new()
		var injected_flow := RunTerminalFlow.new(RunTerminalRecoveryService.new(), injected_resolution)
		main.set("_terminal_flow", injected_flow)
		# Use the real flow's service boundary with a runtime failure in the
		# confirmed resolution path. The disposable graph must remain untouched.
		main.call(&"_on_terminal", RunTerminalSnapshot.Outcome.VICTORY)
		await process_frame
		var flow: Variant = main.get("_terminal_flow")
		var begun: Variant = flow.call(&"begin", RunTerminalSnapshot.Outcome.VICTORY, 90.0, context, profile, root_path) if int(flow.call(&"state")) == RunTerminalFlow.State.IDLE else RunTerminalBeginResult.ready(flow.call(&"snapshot"))
		if _result_ok(begun):
			var projection: Variant = flow.call(&"extraction_projection")
			var selected := _eligible_ids(projection)
			var confirmed: Variant = flow.call(&"confirm_extraction", selected, profile)
			_assert(_result_ok(confirmed), "fault-injection fixture confirms the canonical extraction")
			if _result_ok(confirmed):
				var failed_resolution: Variant = flow.call(&"resolve", String(profile.profile_id), root_path)
				_assert(not _result_ok(failed_resolution), "injected resolution failure enters the retryable interruption")
				_assert(registry.all_records().size() == live_count, "injected resolution failure retains authoritative live loot")
				_assert(_active_chest_count(main) == live_count, "injected resolution failure retains projected live loot")
				var retry_resolution: Variant = flow.call(&"resolve", String(profile.profile_id), root_path)
				_assert(_result_ok(retry_resolution), "resolution retry accepts the same durable request")
				if _result_ok(retry_resolution):
					_assert(bool(flow.call(&"mark_projection_interrupted", "injected recap projection failure")), "injected projection failure becomes retryable")
					_assert(registry.all_records().size() == live_count, "injected projection failure retains authoritative live loot")
					_assert(_active_chest_count(main) == live_count, "injected projection failure retains projected live loot")
					var retry_profile_result := ProfileStore.new().load_profile(String(profile.profile_id), root_path)
					var restored: Variant = flow.call(&"retry_projection", retry_profile_result.profile) if retry_profile_result.ok() else null
					_assert(_result_ok(restored), "projection retry restores the accepted durable result")
					if _result_ok(restored):
						# Corrupting the durable receipt is an independent runtime
						# finalize fault; it must not authorize cleanup.
						var store := ProfileStore.new()
						var durable := store.load_profile(String(profile.profile_id), root_path)
						if durable.ok():
							var broken := durable.profile.copy()
							broken.terminal_resolution = {}
							store.save_profile(broken, root_path)
						_assert(not bool(flow.call(&"finalize")), "injected finalize failure retains the interrupted terminal state")
						_assert(registry.all_records().size() == live_count, "injected finalize failure retains authoritative live loot")
						_assert(_active_chest_count(main) == live_count, "injected finalize failure retains projected live loot")
						if durable.ok():
							store.save_profile(durable.profile, root_path)
							_assert(_invoke_terminal_acceptance(main), "accepted durable resolution reaches Main recap acceptance")
							_assert(int(flow.call(&"state")) == RunTerminalFlow.State.FINALIZED, "valid recap and durable finalize reach the finalized terminal state")
							_assert(registry.all_records().is_empty(), "accepted durable resolution and valid recap clear live loot")
	_cleanup_main(main)

func _assert_terminal_api(main: Node, label: String) -> void:
	for method_name: StringName in [&"_on_terminal", &"_on_terminal_extraction_confirmed", &"_on_terminal_resolution_accepted", &"_on_retry_resolution_requested", &"_on_retry_projection_requested"]:
		_assert(main.has_method(method_name), "%s exposes terminal method %s" % [label, method_name])

func _runtime_terminal_contract_available() -> bool:
	# Narrow RED guard for a half-applied Main binding: avoid turning an
	# expected Task12 failure into parser/leak noise before runtime can load.
	var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	for method_name: String in [
		"func _on_terminal(", "func _on_terminal_extraction_confirmed(",
		"func _on_terminal_resolution_accepted(", "func _on_retry_resolution_requested(",
		"func _on_retry_projection_requested(",
	]:
		if not main_source.contains(method_name):
			_assert(false, "Task12 terminal Main binding includes %s" % method_name)
			return false
	var packed := load("res://scenes/game/main.tscn") as PackedScene
	if packed == null:
		_assert(false, "Task12 terminal runtime scene loads")
		return false
	var main := packed.instantiate() as Node
	if main == null:
		_assert(false, "Task12 terminal runtime Main instantiates")
		return false
	var available := true
	for method_name: StringName in [&"_on_terminal", &"_on_terminal_extraction_confirmed", &"_on_terminal_resolution_accepted", &"_on_retry_resolution_requested", &"_on_retry_projection_requested"]:
		if not main.has_method(method_name):
			_assert(false, "Task12 terminal runtime exposes %s" % method_name)
			available = false
	main.free()
	return available

func _create_live_loot(main: Node, label: String) -> Dictionary:
	var registry := main.get("ground_item_registry") as GroundItemRegistry
	var controller := main.get("ground_item_world_controller") as Node
	_assert(registry != null and controller != null, "%s constructs one live ground-loot graph" % label)
	if registry == null or controller == null:
		return {}
	var event := EnemyDefeatEvent.create(1337, 700 + label.length(), 700 + label.length(), &"swarmer", &"ordinary_melee", (main.get("leader") as PartyActor).position, 30.0)
	var report := (main.get("personal_loot_drop_coordinator") as PersonalLootDropCoordinator).resolve_defeat(event)
	main.call(&"_record_personal_loot_report", report)
	_assert(registry.all_records().size() == 1, "%s fixture creates one authoritative ground record" % label)
	_assert(_active_chest_count(main) == 1, "%s fixture projects one live chest" % label)
	controller.status_changed.emit("GROUND_ITEM_PICKUP_INVENTORY_FULL")
	return {"registry": registry}

func _invoke_terminal_acceptance(main: Node) -> bool:
	if not main.has_method(&"_on_terminal_resolution_accepted"):
		return false
	var flow := main.get("_terminal_flow") as RunTerminalFlow
	var accepted := flow.accepted_result() if flow != null else null
	if accepted == null:
		return false
	main.call(&"_on_terminal_resolution_accepted", accepted)
	return true

func _result_ok(result: Variant) -> bool:
	return result != null and result.has_method(&"ok") and bool(result.call(&"ok"))

func _eligible_ids(projection: Variant) -> Array[String]:
	var ids: Array[String] = []
	if projection == null:
		return ids
	for selection: ExtractionSelection in projection.get("eligible_items"):
		ids.append(selection.item_id)
	return ids

func _fail_first_resolution_script() -> Script:
	var script := GDScript.new()
	script.source_code = """extends \"res://scripts/extraction/run_resolution_service.gd\"
var calls := 0
func resolve_terminal_source(profile_id: String, source: RunResolutionSource, request: RunResolutionRequest, root: String = ProfileStore.DEFAULT_ROOT) -> RunResolutionResult:
    calls += 1
    if calls == 1:
        return RunResolutionResult.failure(\"PARTY_FORGE_RUN_RESOLUTION_ERROR field=resolution reason=injected resolution interruption\")
    return super.resolve_terminal_source(profile_id, source, request, root)
"""
	return script if script.reload() == OK else null

func _started_main(suffix: String) -> Node:
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	settings.set("force_personal_drops", true)
	settings.set("personal_drop_source_category_override", &"ordinary_specialist")
	settings.set("personal_drop_item_level_override", 777)
	settings.set("show_ground_chest_diagnostics", true)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as Node
	main.profile_root = PROFILE_ROOT.path_join(suffix)
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	var manager := main.profile_manager as ProfileManager
	if manager.active_profile() == null:
		manager.create_profile("Lifecycle %s" % suffix)
	main.saved_settings = settings.copy()
	if not main.select_leader_class(&"fighter"):
		_assert(false, "%s run starts" % suffix)
		main.free()
		return null
	_assert(_diagnostics_text(main) == _zero_diagnostics_text(), "%s run immediately presents complete zero diagnostics" % suffix)
	var roll := main.personal_loot_roll_service as PersonalLootRollService
	var decision := roll.resolve(EnemyDefeatEvent.create(1337, 600, 600, &"swarmer", &"ordinary_melee", main.leader.position, 30.0))[0] as PersonalLootDecision
	_assert(decision.success and decision.source_category == &"ordinary_specialist" and decision.item_level == 777, "%s applies deterministic source and item-level overrides only through the immutable Developer snapshot" % suffix)
	return main

func _active_chest_count(main: Node) -> int:
	var controller := main.get_node("GroundItemWorldController") as Node
	return (controller.get("_chest_by_drop") as Dictionary).size()

func _diagnostics_text(main: Node) -> String:
	return String((main.get_node("DeveloperModeBadge") as DeveloperModeBadge).diagnostics_text())

func _zero_diagnostics_text() -> String:
	return "SESSION LOOT DIAGNOSTICS\nLIVE 0 | PEAK 0\nROLL SUCCESS none\nROLL MISS none\nINELIGIBLE 0 | REASONS none | SOURCES none\nGENERATION FAILURES 0\nDIAGNOSTIC STAGES none\nDIAGNOSTIC CODES none\nCOLLECTION none\nPROJECTION pending=0 last=0 peak=0 limit=32"

func _cleanup_main(main: Node) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.free()

func _cleanup_settings() -> void:
	for path: String in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH, "%s.bak" % SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	if _failures.is_empty():
		print("LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVE_LOOT_LIFECYCLE_INTEGRATION: %s" % failure)
	print("LIVE_LOOT_LIFECYCLE_INTEGRATION: FAIL (%d failures)" % _failures.size())
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
