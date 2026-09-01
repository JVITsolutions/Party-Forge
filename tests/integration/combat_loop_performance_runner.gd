extends SceneTree

const VIEWPORT_SIZE := Vector2i(1280, 720)
const PARTY_COUNT := 24
const AUTOMATIC_ITEM_COUNT := 4
const ELIGIBLE_ITEM_COUNT := 32
const FRAME_SAMPLE_COUNT := 300
const CASE_DEADLINE_MS := 60000
const SETTLE_DEADLINE_MS := 5000
const RESULT_FIXTURE_PATH := "res://tests/unit/test_run_recap_projection.gd"

const CASES: Array[Dictionary] = [
	{"id": "default", "ui_scale": 100, "text_scale": 100},
	{"id": "ui150_text150", "ui_scale": 150, "text_scale": 150},
	{"id": "ui80_text150", "ui_scale": 80, "text_scale": 150},
]


class TestRun:
	extends Node
	var _started_usec := Time.get_ticks_usec()

	func elapsed_time() -> float:
		return float(Time.get_ticks_usec() - _started_usec) / 1000000.0


class CountingCompleteProvider:
	extends RefCounted
	var call_count := 0

	func provider_id() -> StringName:
		return &"performance_complete"

	func display_order() -> int:
		return 0

	func project(_snapshot: RunTerminalSnapshot, _resolution: RunResolutionResult) -> RunRecapProviderResult:
		call_count += 1
		var entry := RunRecapEntryProjection.create(
			"Accepted revision",
			"Complete",
			"The complete test provider ran from accepted terminal truth.",
		)
		var entries: Array[RunRecapEntryProjection] = [entry]
		var section := RunRecapSectionProjection.create(
			provider_id(),
			"PERFORMANCE COMPLETION",
			RunRecapSectionProjection.SemanticKind.HIGHLIGHT,
			entries,
			"One complete provider-backed entry",
		)
		return RunRecapProviderResult.success(section)


var _failures: Array[String] = []
var _case_evidence: Array[Dictionary] = []
var _fixture_sequence := 17000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_assert(DisplayServer.get_name().to_lower() != "headless", "performance qualification runs in a real window")
	_assert(RenderingServer.get_current_rendering_method() == "gl_compatibility", "performance qualification uses OpenGL Compatibility")
	root.content_scale_size = Vector2i.ZERO
	root.size = VIEWPORT_SIZE
	var viewport_ready := await _wait_until(
		func() -> bool: return root.size == VIEWPORT_SIZE and (root.get_visible_rect().size.round() as Vector2i) == VIEWPORT_SIZE,
		"the window to reach 1280x720",
		SETTLE_DEADLINE_MS,
	)
	_assert(viewport_ready, "performance viewport resolves to the declared 1280x720 geometry")
	for case: Dictionary in CASES:
		await _exercise_case(case)
	_finish()


func _exercise_case(case: Dictionary) -> void:
	var case_id := String(case["id"])
	var case_started_usec := Time.get_ticks_usec()
	var case_deadline_usec := case_started_usec + CASE_DEADLINE_MS * 1000
	var fixture := _hud_fixture(PARTY_COUNT)
	var settings := PartyForgeSettings.new()
	settings.ui_scale_percent = int(case["ui_scale"])
	settings.text_scale_percent = int(case["text_scale"])
	settings.normalize()

	var party := fixture.party as PartyManager
	var experience := fixture.experience as ExperienceSystem
	var run := fixture.run as TestRun
	root.add_child(party)
	root.add_child(experience)
	root.add_child(run)
	for actor: Node3D in fixture.actors as Array[Node3D]:
		root.add_child(actor)
	for member_id: int in range(1, PARTY_COUNT + 1):
		(fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)

	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	root.add_child(hud)
	hud.configure(run, party, experience, fixture.context as PlayerRunContext, settings)
	var party_header := hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var metrics := CombatHudResponsiveLayout.resolve(VIEWPORT_SIZE, settings.ui_scale_percent, settings.text_scale_percent, PARTY_COUNT, party_header.get_global_rect().size.y)
	var hud_ready := await _wait_until(
		func() -> bool:
			return (
				hud.current_projection != null
				and hud.current_projection.members.size() == PARTY_COUNT
				and hud.current_projection.all_alerts.size() == PARTY_COUNT
				and _member_control_ids(hud).size() == metrics.visible_member_count
				and _compact_controls_within_bounds(hud)
				and (hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button).visible
			),
		"%s HUD projection, compact controls, and overflow alerts" % case_id,
		_remaining_case_wait_ms(case_deadline_usec),
	)
	_assert(hud_ready, "%s reaches its complete 24-member HUD state before the deadline" % case_id)
	_assert(_member_control_ids(hud).size() == metrics.visible_member_count and _compact_controls_within_bounds(hud), "%s measured Party-header reservation matches the contained real compact rows" % case_id)

	var extraction := _long_extraction_projection()
	hud.show_terminal_extraction(extraction)
	var extraction_panel := hud.get_node("TerminalExtraction") as TerminalExtractionPanel
	var extraction_ready := await _wait_until(
		func() -> bool:
			return (
				_extraction_cards(extraction_panel).size() == AUTOMATIC_ITEM_COUNT + ELIGIBLE_ITEM_COUNT
				and _compact_controls_within_bounds(hud)
			),
		"%s long extraction cards and settled compact bounds" % case_id,
		_remaining_case_wait_ms(case_deadline_usec),
	)
	_assert(extraction_ready, "%s projects every long extraction item with settled compact bounds before the deadline" % case_id)

	var provider := CountingCompleteProvider.new()
	var result_fixtures: Variant = (load(RESULT_FIXTURE_PATH) as Script).new()
	var result_view_model := RunResultViewModel.new()
	var accepted_fixture: Dictionary = result_fixtures.call(&"_fixture", PARTY_COUNT, 30, RunTerminalSnapshot.Outcome.VICTORY)
	var accepted_revision := result_view_model.build(
		accepted_fixture.snapshot,
		accepted_fixture.resolution,
		accepted_fixture.profile,
		[provider],
	)
	_assert(accepted_revision.ok(), "%s builds one complete accepted result revision" % case_id)
	_assert(provider.call_count == 1, "%s complete provider runs exactly once for the accepted revision" % case_id)
	var calls_after_first_build := provider.call_count
	var result_panel := hud.get_node("RunResultPanel") as RunResultPanel
	var first_result_projection := accepted_revision.projection.with_visual_settings(settings) if accepted_revision.ok() else null
	result_panel.present(first_result_projection)
	var first_result_ready := await _wait_until(
		func() -> bool: return result_panel.visible and _provider_row_count(result_panel) == 1,
		"%s first accepted result revision in the live panel" % case_id,
		_remaining_case_wait_ms(case_deadline_usec),
	)
	_assert(first_result_ready, "%s presents the complete provider section through the live result panel" % case_id)

	var initial_alert_count := hud.current_projection.all_alerts.size() if hud.current_projection != null else -1
	var initial_overflow_count := hud.current_projection.overflow_alert_count if hud.current_projection != null else -1
	var stable_member_ids := _member_control_ids(hud)
	_assert(stable_member_ids.size() == metrics.visible_member_count, "%s exposes the calculated compact member count" % case_id)
	_assert(_compact_controls_within_bounds(hud), "%s visible compact controls remain within calculated bounds" % case_id)
	var timer := hud.get_node("Margin/CombatStatus/RunTime") as Label
	var timer_before := timer.text
	var baseline_controls := _live_control_count(hud)
	var peak_controls := baseline_controls
	var baseline_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var peak_memory := baseline_memory
	var frame_samples_ms: Array[float] = []
	var pulsed_health := fixture.health_by_member[PARTY_COUNT] as HealthComponent
	for frame_index: int in FRAME_SAMPLE_COUNT:
		if frame_index == FRAME_SAMPLE_COUNT / 2:
			result_panel.present(first_result_projection)
		if frame_index % 2 == 0:
			pulsed_health.apply_damage(0.25)
		else:
			pulsed_health.heal(0.25)
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		frame_samples_ms.append(float(Time.get_ticks_usec() - frame_started_usec) / 1000.0)
		peak_controls = maxi(peak_controls, _live_control_count(hud))
		peak_memory = maxi(peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		if frame_index == FRAME_SAMPLE_COUNT / 2:
			_assert(_provider_row_count(result_panel) == 1, "%s same-revision live re-presentation retains the provider section" % case_id)
			_assert(provider.call_count == 1, "%s same-revision live re-presentation does not rebuild the provider" % case_id)
		if Time.get_ticks_usec() > case_deadline_usec:
			break
	var final_controls := _live_control_count(hud)
	var final_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_assert(frame_samples_ms.size() == FRAME_SAMPLE_COUNT, "%s captures all 300 rendered health/timer frame samples before its declared deadline" % case_id)
	_assert(_member_control_ids(hud) == stable_member_ids, "%s preserves exact real party-control instance IDs across 300 health/timer frames" % case_id)
	_assert(timer.text != timer_before, "%s advances the production run timer during the frame sample" % case_id)
	_assert(provider.call_count == 1, "%s does not rerun the accepted-revision provider from frame processing" % case_id)
	var calls_after_sample_and_represent := provider.call_count
	_assert(peak_controls == baseline_controls and final_controls == baseline_controls, "%s live control count stays bounded without growth" % case_id)
	_assert(_compact_controls_within_bounds(hud), "%s compact controls remain bounded after the frame sample" % case_id)

	var second_fixture: Dictionary = result_fixtures.call(&"_fixture", PARTY_COUNT, 30, RunTerminalSnapshot.Outcome.DEFEAT)
	var second_revision := result_view_model.build(
		second_fixture.snapshot,
		second_fixture.resolution,
		second_fixture.profile,
		[provider],
	)
	_assert(second_revision.ok(), "%s builds a distinct second accepted result revision" % case_id)
	_assert(provider.call_count == 2, "%s complete provider runs exactly once for each of two accepted revisions" % case_id)
	var second_result_projection := second_revision.projection.with_visual_settings(settings) if second_revision.ok() else null
	result_panel.present(second_result_projection)
	var second_result_ready := await _wait_until(
		func() -> bool:
			return (
				result_panel.visible
				and _provider_row_count(result_panel) == 1
				and "DEFEAT" in (result_panel.get_node("Frame/Content/Header/OutcomeHeadline") as Label).text
			),
		"%s second accepted result revision in the live panel" % case_id,
		_remaining_case_wait_ms(case_deadline_usec),
	)
	_assert(second_result_ready, "%s presents the distinct second accepted revision through the live result panel" % case_id)
	_assert(provider.call_count == 2, "%s live second-revision presentation does not invoke the provider again" % case_id)

	var before_alert_only_ids := _member_control_ids(hud)
	var alert_changed_health := fixture.health_by_member[PARTY_COUNT - 1] as HealthComponent
	alert_changed_health.heal(80.0)
	var alert_refresh_ready := await _wait_until(
		func() -> bool: return hud.current_projection != null and hud.current_projection.all_alerts.size() == initial_alert_count - 1,
		"%s alert-only projection refresh" % case_id,
		_remaining_case_wait_ms(case_deadline_usec),
	)
	_assert(alert_refresh_ready, "%s accepts the alert-only revision before the deadline" % case_id)
	_assert(_member_control_ids(hud) == before_alert_only_ids, "%s alert-only change does not replace party controls" % case_id)

	var cards := _extraction_cards(extraction_panel)
	_assert(cards.size() == AUTOMATIC_ITEM_COUNT + ELIGIBLE_ITEM_COUNT, "%s keeps the complete long extraction list live" % case_id)
	if not cards.is_empty():
		var final_card := cards[-1]
		var body := extraction_panel.get_node("Frame/Content/Body") as ScrollContainer
		body.ensure_control_visible(final_card)
		var final_reachable := await _wait_until(
			func() -> bool: return body.get_global_rect().encloses(final_card.get_global_rect()),
			"%s final extraction card reachability" % case_id,
			_remaining_case_wait_ms(case_deadline_usec),
		)
		_assert(final_reachable, "%s final long-list extraction item is reachable inside the bounded scroll region" % case_id)

	var elapsed_ms := float(Time.get_ticks_usec() - case_started_usec) / 1000.0
	_assert(elapsed_ms <= CASE_DEADLINE_MS, "%s completes setup, waits, sampling, and accepted revisions within the declared case deadline" % case_id)
	var sorted_samples := frame_samples_ms.duplicate()
	sorted_samples.sort()
	var evidence := {
		"schema_version": 1,
		"case_id": case_id,
		"viewport": {"width": VIEWPORT_SIZE.x, "height": VIEWPORT_SIZE.y},
		"party_count": PARTY_COUNT,
		"item_count": AUTOMATIC_ITEM_COUNT + ELIGIBLE_ITEM_COUNT,
		"alert_count": initial_alert_count,
		"alert_overflow_count": initial_overflow_count,
		"settings": {"ui_scale_percent": settings.ui_scale_percent, "text_scale_percent": settings.text_scale_percent},
		"renderer": _renderer_metadata(),
		"hardware": _hardware_metadata(),
		"member_control_instance_ids": stable_member_ids,
		"compact_bounds": {
			"calculated_visible_count": metrics.visible_member_count,
			"actual_visible_count": stable_member_ids.size(),
			"viewport_contained": _compact_controls_within_bounds(hud),
		},
		"provider": {
			"accepted_revisions": 2,
			"calls_after_first_build": calls_after_first_build,
			"calls_after_300_frames_and_represent": calls_after_sample_and_represent,
			"calls": provider.call_count,
			"live_panel_section_rows": _provider_row_count(result_panel),
		},
		"frame_sample": {
			"required": FRAME_SAMPLE_COUNT,
			"captured": frame_samples_ms.size(),
			"average_ms": _average(frame_samples_ms),
			"p95_ms": _percentile(sorted_samples, 0.95),
			"peak_ms": sorted_samples[-1] if not sorted_samples.is_empty() else -1.0,
		},
		"live_controls": {"baseline": baseline_controls, "peak": peak_controls, "final": final_controls},
		"memory_static_bytes": {"baseline": baseline_memory, "peak": peak_memory, "final": final_memory},
		"deadline_ms": CASE_DEADLINE_MS,
		"deadline_met": elapsed_ms <= CASE_DEADLINE_MS,
		"elapsed_ms": elapsed_ms,
	}
	_case_evidence.append(evidence)
	print("COMBAT_LOOP_PERFORMANCE_CASE: %s" % JSON.stringify(evidence))

	hud.hide_terminal_extraction()
	hud.free()
	_cleanup_fixture(fixture)


func _hud_fixture(count: int) -> Dictionary:
	_fixture_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(count))
	party.configure_identity(_fixture_sequence, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(count - 1):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
	var context := PlayerRunContext.new()
	var profile := ProfileState.new_profile("performance-profile-%d" % _fixture_sequence, "Performance", 1000)
	assert(context.configure(StringName("performance-player-%d" % _fixture_sequence), 0, profile, _fixture_sequence, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	for member_id: int in range(1, count + 1):
		var actor := Node3D.new()
		actor.name = "PerformanceMember%02d" % member_id
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		actor.add_child(health)
		health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		assert(context.bind_actor(member_id, actor))
		actors.append(actor)
		health_by_member[member_id] = health
	return {
		"party": party,
		"context": context,
		"experience": experience,
		"actors": actors,
		"health_by_member": health_by_member,
		"run": TestRun.new(),
	}


func _long_extraction_projection() -> TerminalExtractionProjection:
	var automatic: Array[TerminalExtractionItemProjection] = []
	for index: int in AUTOMATIC_ITEM_COUNT:
		automatic.append(_extraction_item("automatic-%02d" % index, true, false, false, 1, index))
	var eligible: Array[TerminalExtractionItemProjection] = []
	var lost: Array[String] = []
	for index: int in ELIGIBLE_ITEM_COUNT:
		var item_id := "eligible-%02d" % index
		var member_id := 2 + (index % 6) if index < 24 else 0
		eligible.append(_extraction_item(item_id, false, false, true, member_id, index))
		lost.append(item_id)
	return TerminalExtractionProjection.create(automatic, eligible, 6, [], lost, [], "", true)


func _extraction_item(item_id: String, automatic: bool, selected: bool, lost: bool, member_id: int, source_slot: int) -> TerminalExtractionItemProjection:
	var class_label := "Fighter" if member_id > 0 else ""
	var container_id := StringName("run-equipment-%03d" % member_id) if member_id > 0 else &"run-inventory"
	var owner_label := "Fighter · Member %d" % member_id if member_id > 0 else "Run Inventory"
	var container_label := "Fighter Equipment" if member_id > 0 else "Run Inventory"
	return TerminalExtractionItemProjection.create_with_source(
		item_id,
		"Forge Item %s" % item_id,
		"Common",
		&"common",
		owner_label,
		container_label,
		automatic,
		selected,
		lost,
		{"name": "Forge Item %s" % item_id, "instance_id": item_id},
		[],
		member_id,
		class_label,
		container_id,
		source_slot,
	)


func _member_control_ids(hud: HUD) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in get_nodes_in_group(&"combat_hud_member"):
		var control := node as Control
		if control != null and hud.is_ancestor_of(control) and not control.is_queued_for_deletion():
			result[str(int(control.get_meta(&"member_id", 0)))] = control.get_instance_id()
	return result


func _compact_controls_within_bounds(hud: HUD) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	var window := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow") as GridContainer
	var window_rect := window.get_global_rect()
	var prior_rects: Array[Rect2] = []
	var controls: Array[Control] = []
	for node: Node in get_nodes_in_group(&"combat_hud_member"):
		var control := node as Control
		if control != null and hud.is_ancestor_of(control) and control.is_visible_in_tree():
			controls.append(control)
	if controls.is_empty():
		return false
	for control: Control in controls:
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not viewport_rect.encloses(rect) or not window_rect.encloses(rect):
			return false
		for prior: Rect2 in prior_rects:
			if prior.intersection(rect).has_area():
				return false
		prior_rects.append(rect)
	return true


func _extraction_cards(panel: TerminalExtractionPanel) -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in panel.find_children("*", "Control", true, false):
		if node is ForgeExtractionItemCard and not node.is_queued_for_deletion():
			result.append(node as Control)
	return result


func _live_control_count(scope: Node) -> int:
	var count := 0
	for node: Node in scope.find_children("*", "Control", true, false):
		if not node.is_queued_for_deletion():
			count += 1
	return count


func _provider_row_count(panel: RunResultPanel) -> int:
	var count := 0
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.get_meta(&"recap_section_id", &"") == &"performance_complete" and not node.is_queued_for_deletion():
			count += 1
	return count


func _remaining_case_wait_ms(case_deadline_usec: int) -> int:
	var remaining_ms := ceili(float(case_deadline_usec - Time.get_ticks_usec()) / 1000.0)
	return clampi(remaining_ms, 1, SETTLE_DEADLINE_MS)


func _wait_until(condition: Callable, description: String, deadline_ms: int) -> bool:
	var deadline_usec := Time.get_ticks_usec() + maxi(deadline_ms, 1) * 1000
	while Time.get_ticks_usec() <= deadline_usec:
		if bool(condition.call()):
			return true
		await process_frame
	_failures.append("timeout waiting for %s after %d ms" % [description, deadline_ms])
	return false


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return -1.0
	return sorted_values[clampi(ceili(float(sorted_values.size()) * clampf(fraction, 0.0, 1.0)) - 1, 0, sorted_values.size() - 1)]


func _renderer_metadata() -> Dictionary:
	return {
		"method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"window_mode": DisplayServer.window_get_mode(),
	}


func _hardware_metadata() -> Dictionary:
	var memory := OS.get_memory_info()
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"physical_memory_bytes": int(memory.get("physical", 0)),
	}


func _cleanup_fixture(fixture: Dictionary) -> void:
	for actor: Node3D in fixture.actors as Array[Node3D]:
		if is_instance_valid(actor):
			actor.free()
	for key: String in ["run", "experience", "party"]:
		var node := fixture[key] as Node
		if node != null and is_instance_valid(node):
			node.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_assert(_case_evidence.size() == CASES.size(), "all three settings cases emit complete performance evidence")
	if _failures.is_empty():
		print("COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS cases=3 frames=%d party=24 items=%d" % [FRAME_SAMPLE_COUNT * CASES.size(), AUTOMATIC_ITEM_COUNT + ELIGIBLE_ITEM_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_LOOP_PERFORMANCE_FAILURE: %s" % failure)
	print("COMBAT_LOOP_PERFORMANCE_SUMMARY: FAIL failures=%d cases=%d" % [_failures.size(), _case_evidence.size()])
	quit(1)
