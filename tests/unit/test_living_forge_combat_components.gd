extends RefCounted

const CARD_SCENE := "res://scenes/ui/living_forge/components/forge_party_member_card.tscn"
const MARKER_SCENE := "res://scenes/ui/living_forge/components/forge_party_member_marker.tscn"
const ALERT_SCENE := "res://scenes/ui/living_forge/components/forge_alert_card.tscn"
const BOARD_SCENE := "res://scenes/dev/living_forge_combat_state_board.tscn"
const INTEGRATION_RUNNER := "res://tests/integration/living_forge_combat_state_board_runner.gd"
const PROVENANCE_PATH := "res://docs/third_party/living-forge-ui-assets.md"
const OWNED_ICON_SHA256 := {
	"res://assets/ui/living_forge/icons/party-forge/downed.svg": "daf927351a383bb5b67efbca9ac7ecc5563848ae385770219393576db0628d77",
	"res://assets/ui/living_forge/icons/party-forge/dead.svg": "9dfdb42b80c6c80ce320de4bdbec8c1826114c2d77afa6f589a1e37e76366784",
	"res://assets/ui/living_forge/icons/party-forge/leader-crown.svg": "e5210e97b6644114be3d4baf5966910ede0812fc566534b15271889e7bb88652",
}
const EXPECTED_CAPTURE_FILES: Array[String] = [
	"living-forge-combat-rich-states-normal.png",
	"living-forge-combat-compact-alerts-normal.png",
	"living-forge-combat-focus-hover-normal.png",
	"living-forge-combat-all-states-high-contrast.png",
	"living-forge-combat-focus-hover-high-contrast.png",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resources_and_manifest_contract(failures)
	_test_owned_icon_provenance(failures)
	_test_rich_member_contract(failures)
	_test_compact_member_contract(failures)
	_test_alert_contract(failures)
	_test_fail_closed_binding_lifetime(failures)
	_test_high_contrast_semantic_parity(failures)
	_test_danger_cues_remain_distinct(failures)
	_test_health_boundary_and_state_precedence(failures)
	_test_component_scripts_are_bounded(failures)
	return failures


func _test_owned_icon_provenance(failures: Array[String]) -> void:
	var document := FileAccess.get_file_as_string(PROVENANCE_PATH)
	TestAssertions.truthy(document.contains("generator=Party Forge authored SVG") and document.contains("license=project-owned"), "combat icon provenance records exact generator and licence markers", failures)
	for path: String in OWNED_ICON_SHA256:
		var expected := String(OWNED_ICON_SHA256[path])
		TestAssertions.truthy(FileAccess.file_exists(path), "owned combat icon exists: %s" % path, failures)
		if FileAccess.file_exists(path):
			TestAssertions.equal(FileAccess.get_sha256(path), expected, "%s bytes match recorded SHA-256" % path, failures)
		TestAssertions.truthy(document.contains(path.trim_prefix("res://")) and document.contains(expected), "%s provenance records exact path and hash" % path, failures)


func _test_resources_and_manifest_contract(failures: Array[String]) -> void:
	for path: String in [CARD_SCENE, MARKER_SCENE, ALERT_SCENE, BOARD_SCENE]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path, failures)
	TestAssertions.truthy(ResourceLoader.exists(INTEGRATION_RUNNER), "combat state-board runner exists", failures)
	if not ResourceLoader.exists(INTEGRATION_RUNNER):
		return
	var runner_script := load(INTEGRATION_RUNNER) as Script
	TestAssertions.truthy(runner_script != null, "combat state-board runner loads", failures)
	if runner_script == null:
		return
	var constants := runner_script.get_script_constant_map()
	TestAssertions.equal(int(constants.get("MANIFEST_SCHEMA_VERSION", 0)), 2, "combat evidence manifest is schema 2", failures)
	TestAssertions.equal(constants.get("EXPECTED_CAPTURE_FILES", []), EXPECTED_CAPTURE_FILES, "combat evidence declares five exact filenames including high-contrast interaction proof", failures)


func _test_rich_member_contract(failures: Array[String]) -> void:
	var card := _instantiate(CARD_SCENE)
	if card == null:
		return
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(card)
	card.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	var member := PartyMemberHudProjection.create(7, "Aria", &"fighter", "Fighter", 7, 3, 20.0, 100.0, true, false, false)
	var activation_ids: Array[int] = []
	var inspect_ids: Array[int] = []
	var ledger_ids: Array[int] = []
	card.connect(&"activated", func(member_id: int) -> void: activation_ids.append(member_id))
	card.connect(&"inspect_requested", func(member_id: int) -> void: inspect_ids.append(member_id))
	card.connect(&"ledger_requested", func(member_id: int) -> void: ledger_ids.append(member_id))
	card.call(&"present", member)
	TestAssertions.equal((card.get_node("Surface/Content/Identity/Name") as Label).text, "Aria", "rich card presents member name", failures)
	TestAssertions.equal((card.get_node("Surface/Content/Identity/Class") as Label).text, "FIGHTER", "rich card presents class", failures)
	TestAssertions.equal((card.get_node("Surface/Content/Meta") as Label).text, "LEVEL 7  ·  RANK 3", "rich card presents level and class rank", failures)
	TestAssertions.equal((card.get_node("Surface/Content/Health/Value") as Label).text, "20 / 100", "rich card presents readable health values", failures)
	TestAssertions.truthy((card.get_node("Surface/LeaderCue") as Control).visible, "rich leader state has a visible crown and text cue", failures)
	TestAssertions.equal(card.accessibility_name, "Inspect Aria, Fighter, Level 7, 20 of 100 health", "member action is explicit", failures)
	_assert_member_state(card, &"critical", "CRITICAL", LivingForgeTokens.color(&"error", false), failures)
	_assert_exact_semantic_color_role(card, &"error", false, true, failures)
	TestAssertions.equal(activation_ids, [], "present emits no activation", failures)

	card.call(&"_on_focus_entered")
	TestAssertions.truthy((card.get_node("FocusFrame") as Control).visible, "rich card renders keyboard/controller focus state", failures)
	card.call(&"_on_mouse_entered")
	card.call(&"present", member.copy())
	TestAssertions.truthy((card.get_node("FocusFrame") as Control).visible, "re-presentation preserves authored focus state until real focus exits", failures)
	TestAssertions.truthy((card.get_node("HoverPlate") as Control).visible, "re-presentation preserves hover", failures)
	TestAssertions.equal(activation_ids, [], "focused and hovered re-presentation emits no activation", failures)
	card.call(&"_on_mouse_exited")

	card.pressed.emit()
	card.call(&"request_inspect")
	card.call(&"request_ledger")
	TestAssertions.equal(activation_ids, [7], "rich card activation emits the stable member ID exactly once", failures)
	TestAssertions.equal(inspect_ids, [7], "rich card Inspect emits the stable member ID exactly once", failures)
	TestAssertions.equal(ledger_ids, [7], "rich card Ledger emits the stable member ID exactly once", failures)
	card.call(&"set_interaction_disabled", true)
	card.pressed.emit()
	card.call(&"request_inspect")
	card.call(&"request_ledger")
	TestAssertions.equal(activation_ids, [7], "disabled rich card emits no activation", failures)
	TestAssertions.equal(inspect_ids, [7], "disabled rich card emits no Inspect", failures)
	TestAssertions.equal(ledger_ids, [7], "disabled rich card emits no Ledger", failures)
	TestAssertions.truthy(card.disabled and card.accessibility_name.contains("Unavailable"), "disabled rich card is explicit and accessible", failures)
	TestAssertions.truthy(not card.has_focus() and card.focus_mode == Control.FOCUS_NONE, "disabled rich card cannot retain or accept focus", failures)
	card.call(&"set_interaction_disabled", false)
	TestAssertions.truthy(not (card.get_node("FocusFrame") as Control).visible, "re-enabled rich card does not resurrect stale focus", failures)

	for scenario: Dictionary in _member_scenarios():
		var projection := PartyMemberHudProjection.create(
			int(scenario.member_id), String(scenario.name), StringName(scenario.class_id), String(scenario.class_label),
			int(scenario.level), int(scenario.rank), float(scenario.health), 100.0, bool(scenario.leader),
			bool(scenario.downed), bool(scenario.dead),
		)
		card.call(&"present", projection)
		_assert_member_state(card, StringName(scenario.state), String(scenario.text), LivingForgeTokens.color(StringName(scenario.color_role), false), failures)
	card.call(&"apply_accessibility_variant", true)
	_assert_member_state(card, &"dead", "DEAD", LivingForgeTokens.color(&"error", true), failures)
	card.free()


func _test_compact_member_contract(failures: Array[String]) -> void:
	var marker := _instantiate(MARKER_SCENE)
	if marker == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(marker)
	marker.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	var member := PartyMemberHudProjection.create(12, "Brom", &"mage", "Mage", 4, 2, 10.0, 100.0, false, false, false)
	var activation_ids: Array[int] = []
	marker.connect(&"activated", func(member_id: int) -> void: activation_ids.append(member_id))
	marker.call(&"present", member)
	TestAssertions.equal((marker.get_node("Surface/Content/Identity/Name") as Label).text, "BROM", "compact marker keeps member identity readable", failures)
	TestAssertions.equal((marker.get_node("Surface/Content/Identity/Class") as Label).text, "MAGE · L4 · R2", "compact marker keeps class, level, and rank visibly readable", failures)
	TestAssertions.equal(marker.custom_minimum_size, Vector2(280.0, 84.0), "compact marker uses the Task 1 supported 280x84 basis", failures)
	TestAssertions.equal((marker.get_node("Surface/Content/Health/Value") as Label).text, "10 / 100", "compact marker keeps numeric health readable", failures)
	TestAssertions.equal(marker.accessibility_name, "Inspect Brom, Mage, Level 4, 10 of 100 health", "compact marker has an explicit member action name", failures)
	TestAssertions.truthy(marker.accessibility_description.contains("State: Critical"), "compact critical marker exposes its semantic state accessibly", failures)
	_assert_member_state(marker, &"critical", "CRITICAL", LivingForgeTokens.color(&"error", false), failures)
	_assert_exact_semantic_color_role(marker, &"error", false, true, failures)
	marker.call(&"_on_focus_entered")
	marker.call(&"_on_mouse_entered")
	marker.call(&"present", member.copy())
	TestAssertions.truthy((marker.get_node("FocusFrame") as Control).visible, "compact re-presentation preserves focus presentation", failures)
	TestAssertions.truthy((marker.get_node("HoverPlate") as Control).visible, "compact re-presentation preserves hover", failures)
	TestAssertions.equal(activation_ids, [], "compact re-presentation emits no activation", failures)
	for scenario: Dictionary in _member_scenarios():
		var projection := PartyMemberHudProjection.create(
			int(scenario.member_id), String(scenario.name), StringName(scenario.class_id), String(scenario.class_label),
			int(scenario.level), int(scenario.rank), float(scenario.health), 100.0, bool(scenario.leader),
			bool(scenario.downed), bool(scenario.dead),
		)
		marker.call(&"present", projection)
		_assert_member_state(marker, StringName(scenario.state), String(scenario.text), LivingForgeTokens.color(StringName(scenario.color_role), false), failures)
	marker.call(&"apply_accessibility_variant", true)
	_assert_member_state(marker, &"dead", "DEAD", LivingForgeTokens.color(&"error", true), failures)
	marker.free()


func _test_health_boundary_and_state_precedence(failures: Array[String]) -> void:
	var card := _instantiate(CARD_SCENE)
	if card == null:
		return
	var boundary_scenarios: Array[Dictionary] = [
		{"health": 25.01, "downed": false, "dead": false, "state": &"normal"},
		{"health": 25.0, "downed": false, "dead": false, "state": &"critical"},
		{"health": 10.0, "downed": true, "dead": false, "state": &"downed"},
		{"health": 10.0, "downed": true, "dead": true, "state": &"dead"},
		{"health": 90.0, "downed": false, "dead": false, "state": &"normal"},
	]
	for index: int in boundary_scenarios.size():
		var scenario := boundary_scenarios[index]
		var projection := PartyMemberHudProjection.create(
			100 + index, "Boundary", &"fighter", "Fighter", 7, 3,
			float(scenario.health), 100.0, false, bool(scenario.downed), bool(scenario.dead),
		)
		card.call(&"present", projection)
		TestAssertions.equal(card.call(&"semantic_state_id"), StringName(scenario.state), "state precedence is dead > downed > critical > normal at step %d" % index, failures)
	TestAssertions.equal((card.get_node("Surface/Content/StateCue/StateText") as Label).text, "READY", "normal re-presentation clears stale danger copy", failures)
	TestAssertions.truthy(card.accessibility_name.ends_with("health") and card.accessibility_description.contains("State: Normal"), "normal re-presentation clears stale danger accessibility state", failures)
	card.free()


func _test_alert_contract(failures: Array[String]) -> void:
	var alert := _instantiate(ALERT_SCENE)
	if alert == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(alert)
	alert.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	var activation_ids: Array[int] = []
	var inspect_ids: Array[int] = []
	var ledger_ids: Array[int] = []
	alert.connect(&"activated", func(member_id: int) -> void: activation_ids.append(member_id))
	alert.connect(&"inspect_requested", func(member_id: int) -> void: inspect_ids.append(member_id))
	alert.connect(&"ledger_requested", func(member_id: int) -> void: ledger_ids.append(member_id))
	var alerts: Array[CombatAlertProjection] = [
		CombatAlertProjection.create(&"critical:7", 7, &"critical_health", "Aria is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"downed:8", 8, &"downed_or_dying", "Brom is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		CombatAlertProjection.create(&"dead:9", 9, &"downed_or_dying", "Cyra is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
	]
	var expected_text := ["CRITICAL", "DOWNED", "DEAD"]
	var expected_role: Array[StringName] = [&"error", &"error", &"error"]
	for index: int in alerts.size():
		alert.call(&"present_alert", alerts[index])
		TestAssertions.equal((alert.get_node("Surface/StateText") as Label).text, expected_text[index], "%s alert has visible severity text" % expected_text[index], failures)
		TestAssertions.truthy((alert.get_node("Surface/StateIcon") as TextureRect).visible and (alert.get_node("Surface/StateIcon") as TextureRect).texture != null, "%s alert has a visible icon" % expected_text[index], failures)
		var geometry := alert.get_node("Surface/StateShape/Geometry") as Polygon2D
		TestAssertions.truthy(geometry.visible and geometry.polygon.size() >= 3, "%s alert has distinct non-color shape geometry" % expected_text[index], failures)
		TestAssertions.equal((alert.get_node("Surface/Content/Summary") as Label).text, alerts[index].summary, "%s alert presents authoritative summary" % expected_text[index], failures)
		TestAssertions.equal((alert.get_node("Surface/Content/Detail") as Label).text, alerts[index].detail, "%s alert presents authoritative detail" % expected_text[index], failures)
		TestAssertions.truthy(alert.accessibility_name.contains(expected_text[index].capitalize()) and alert.accessibility_name.contains(alerts[index].summary), "%s alert accessibility names severity and member truth" % expected_text[index], failures)
		_assert_exact_alert_color_role(alert, expected_role[index], false, failures)
		_assert_alert_actions(alert, alerts[index].can_inspect, alerts[index].can_open_ledger, failures)
	TestAssertions.equal(activation_ids, [], "alert presentation emits no activation", failures)
	alert.call(&"_on_focus_entered")
	alert.call(&"_on_mouse_entered")
	alert.call(&"present_alert", alerts[2].copy())
	TestAssertions.truthy((alert.get_node("FocusFrame") as Control).visible, "alert re-presentation preserves focus presentation", failures)
	TestAssertions.truthy((alert.get_node("HoverPlate") as Control).visible, "alert re-presentation preserves hover", failures)
	TestAssertions.equal(activation_ids, [], "alert focused/hovered re-presentation remains non-activating", failures)
	alert.pressed.emit()
	alert.call(&"request_inspect")
	alert.call(&"request_ledger")
	TestAssertions.equal(activation_ids, [9], "alert activation emits the stable member ID", failures)
	TestAssertions.equal(inspect_ids, [9], "alert Inspect emits the stable member ID", failures)
	TestAssertions.equal(ledger_ids, [9], "alert Ledger emits the stable member ID", failures)
	alert.call(&"apply_accessibility_variant", true)
	TestAssertions.equal(alert.call(&"semantic_state_id"), &"dead", "high contrast preserves alert semantics", failures)
	TestAssertions.equal(_icon_tint(alert.get_node("Surface/StateIcon") as TextureRect), LivingForgeTokens.color(&"error", true), "high contrast resolves the same dead semantic token role", failures)
	_assert_exact_alert_color_role(alert, &"error", true, failures)
	var unavailable := CombatAlertProjection.create(&"dead:10", 10, &"downed_or_dying", "Dara is dead", "No routes available", CombatAlertProjection.Severity.DEAD, false, false)
	alert.call(&"present_alert", unavailable)
	alert.pressed.emit()
	alert.call(&"request_inspect")
	alert.call(&"request_ledger")
	TestAssertions.truthy(alert.disabled and alert.accessibility_name.contains("Unavailable"), "route-less alert is visibly and accessibly disabled", failures)
	TestAssertions.equal(activation_ids, [9], "disabled alert emits no activation", failures)
	TestAssertions.equal(inspect_ids, [9], "disabled alert emits no Inspect", failures)
	TestAssertions.equal(ledger_ids, [9], "disabled alert emits no Ledger", failures)
	alert.free()


func _test_fail_closed_binding_lifetime(failures: Array[String]) -> void:
	for scene_path: String in [CARD_SCENE, MARKER_SCENE]:
		var member_control := _instantiate(scene_path)
		if member_control == null:
			continue
		(Engine.get_main_loop() as SceneTree).root.add_child(member_control)
		var member := PartyMemberHudProjection.create(31, "Nulla", &"fighter", "Fighter", 5, 4, 75.0, 100.0, true, false, false)
		var activation_ids: Array[int] = []
		var inspect_ids: Array[int] = []
		var ledger_ids: Array[int] = []
		member_control.connect(&"activated", func(member_id: int) -> void: activation_ids.append(member_id))
		member_control.connect(&"inspect_requested", func(member_id: int) -> void: inspect_ids.append(member_id))
		member_control.connect(&"ledger_requested", func(member_id: int) -> void: ledger_ids.append(member_id))
		member_control.call(&"present", member)
		member_control.call(&"_on_focus_entered")
		member_control.call(&"_on_mouse_entered")
		member_control.call(&"present", null)
		_assert_member_binding_cleared(member_control, failures)
		member_control.pressed.emit()
		member_control.call(&"request_inspect")
		member_control.call(&"request_ledger")
		TestAssertions.equal([activation_ids, inspect_ids, ledger_ids], [[], [], []], "%s null binding emits no intent" % scene_path, failures)
		member_control.call(&"present", member.copy())
		TestAssertions.truthy(not member_control.disabled and member_control.focus_mode == Control.FOCUS_ALL, "%s valid rebind restores availability when caller allows interaction" % scene_path, failures)
		TestAssertions.equal((member_control.get_node("Surface/Content/Identity/Name") as Label).text, "NULLA" if scene_path == MARKER_SCENE else "Nulla", "%s valid rebind restores authoritative identity" % scene_path, failures)
		TestAssertions.truthy(not (member_control.get_node("FocusFrame") as Control).visible and not (member_control.get_node("HoverPlate") as Control).visible, "%s valid rebind does not resurrect stale focus or hover" % scene_path, failures)
		member_control.call(&"set_interaction_disabled", true)
		member_control.call(&"present", null)
		member_control.call(&"present", member.copy())
		TestAssertions.truthy(member_control.disabled and member_control.focus_mode == Control.FOCUS_NONE, "%s valid rebind preserves explicit caller disablement" % scene_path, failures)
		member_control.free()

	var alert := _instantiate(ALERT_SCENE)
	if alert == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(alert)
	var projection := CombatAlertProjection.create(&"dead:41", 41, &"downed_or_dying", "Nulla is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true)
	var alert_activations: Array[int] = []
	var alert_inspects: Array[int] = []
	var alert_ledgers: Array[int] = []
	alert.connect(&"activated", func(member_id: int) -> void: alert_activations.append(member_id))
	alert.connect(&"inspect_requested", func(member_id: int) -> void: alert_inspects.append(member_id))
	alert.connect(&"ledger_requested", func(member_id: int) -> void: alert_ledgers.append(member_id))
	alert.call(&"present_alert", projection)
	alert.call(&"_on_focus_entered")
	alert.call(&"_on_mouse_entered")
	alert.call(&"present_alert", null)
	_assert_alert_binding_cleared(alert, failures)
	alert.pressed.emit()
	alert.call(&"request_inspect")
	alert.call(&"request_ledger")
	TestAssertions.equal([alert_activations, alert_inspects, alert_ledgers], [[], [], []], "null alert binding emits no intent", failures)
	alert.call(&"present_alert", projection.copy())
	TestAssertions.truthy(not alert.disabled and alert.focus_mode == Control.FOCUS_ALL, "valid alert rebind restores root availability", failures)
	_assert_alert_actions(alert, true, true, failures)
	TestAssertions.equal((alert.get_node("Surface/Content/Summary") as Label).text, projection.summary, "valid alert rebind restores authoritative summary", failures)
	TestAssertions.truthy(not (alert.get_node("FocusFrame") as Control).visible and not (alert.get_node("HoverPlate") as Control).visible, "valid alert rebind does not resurrect stale focus or hover", failures)
	if alert.has_method(&"set_interaction_disabled"):
		alert.call(&"set_interaction_disabled", true)
		alert.call(&"present_alert", null)
		alert.call(&"present_alert", projection.copy())
		TestAssertions.truthy(alert.disabled and alert.focus_mode == Control.FOCUS_NONE, "valid alert rebind preserves explicit caller disablement", failures)
	else:
		TestAssertions.truthy(false, "alert exposes separate caller-controlled interaction disablement", failures)
	alert.free()


func _test_high_contrast_semantic_parity(failures: Array[String]) -> void:
	for scene_path: String in [CARD_SCENE, MARKER_SCENE]:
		var control := _instantiate(scene_path)
		if control == null:
			continue
		(Engine.get_main_loop() as SceneTree).root.add_child(control)
		for scenario: Dictionary in _member_scenarios():
			var projection := PartyMemberHudProjection.create(
				int(scenario.member_id), String(scenario.name), StringName(scenario.class_id), String(scenario.class_label),
				int(scenario.level), int(scenario.rank), float(scenario.health), 100.0, bool(scenario.leader),
				bool(scenario.downed), bool(scenario.dead),
			)
			control.call(&"apply_accessibility_variant", false)
			control.call(&"present", projection)
			var normal_snapshot := _member_semantic_snapshot(control)
			control.call(&"apply_accessibility_variant", true)
			TestAssertions.equal(_member_semantic_snapshot(control), normal_snapshot, "%s %s high contrast changes colors only" % [scene_path, scenario.state], failures)
			if StringName(scenario.state) == &"critical":
				_assert_exact_semantic_color_role(control, &"error", true, true, failures)
		control.free()

	var alert := _instantiate(ALERT_SCENE)
	if alert == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(alert)
	var alerts: Array[CombatAlertProjection] = [
		CombatAlertProjection.create(&"critical:51", 51, &"critical_health", "Ari is critical", "25 of 100 health", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"downed:52", 52, &"downed_or_dying", "Bea is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		CombatAlertProjection.create(&"dead:53", 53, &"downed_or_dying", "Cai is dead", "No longer active", CombatAlertProjection.Severity.DEAD, false, true),
	]
	for projection: CombatAlertProjection in alerts:
		alert.call(&"apply_accessibility_variant", false)
		alert.call(&"present_alert", projection)
		var normal_snapshot := _alert_semantic_snapshot(alert)
		alert.call(&"apply_accessibility_variant", true)
		TestAssertions.equal(_alert_semantic_snapshot(alert), normal_snapshot, "%s alert high contrast changes colors only" % alert.call(&"semantic_state_id"), failures)
		_assert_exact_alert_color_role(alert, &"error", true, failures)
	alert.free()


func _test_danger_cues_remain_distinct(failures: Array[String]) -> void:
	for scene_path: String in [CARD_SCENE, MARKER_SCENE]:
		var control := _instantiate(scene_path)
		if control == null:
			continue
		var cue_ids: Dictionary = {}
		for scenario: Dictionary in _member_scenarios().slice(1):
			var projection := PartyMemberHudProjection.create(
				int(scenario.member_id), String(scenario.name), StringName(scenario.class_id), String(scenario.class_label),
				int(scenario.level), int(scenario.rank), float(scenario.health), 100.0, false,
				bool(scenario.downed), bool(scenario.dead),
			)
			control.call(&"present", projection)
			var snapshot := _member_semantic_snapshot(control)
			cue_ids["%s|%s|%s" % [snapshot.state_text, snapshot.icon, snapshot.shape]] = true
		TestAssertions.equal(cue_ids.size(), 3, "%s critical/downed/dead retain distinct text, icon, and shape identities", failures)
		control.free()

	var alert := _instantiate(ALERT_SCENE)
	if alert == null:
		return
	var projections: Array[CombatAlertProjection] = [
		CombatAlertProjection.create(&"critical:61", 61, &"critical_health", "Ari is critical", "25 of 100 health", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"downed:62", 62, &"downed_or_dying", "Bea is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		CombatAlertProjection.create(&"dead:63", 63, &"downed_or_dying", "Cai is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
	]
	var alert_cue_ids: Dictionary = {}
	for projection: CombatAlertProjection in projections:
		alert.call(&"present_alert", projection)
		var snapshot := _alert_semantic_snapshot(alert)
		alert_cue_ids["%s|%s|%s" % [snapshot.state_text, snapshot.icon, snapshot.shape]] = true
	TestAssertions.equal(alert_cue_ids.size(), 3, "critical/downed/dead alerts retain distinct text, icon, and shape identities", failures)
	alert.free()


func _test_component_scripts_are_bounded(failures: Array[String]) -> void:
	for path: String in [CARD_SCENE, MARKER_SCENE, ALERT_SCENE]:
		var component := _instantiate(path)
		if component == null:
			continue
		var method_names: Array[StringName] = []
		for method: Dictionary in component.get_script().get_script_method_list():
			method_names.append(StringName(method.get("name", &"")))
		TestAssertions.truthy(&"_process" not in method_names, "%s uses no per-frame process loop" % path, failures)
		component.free()


func _assert_member_state(control: Control, expected_state: StringName, expected_text: String, expected_color: Color, failures: Array[String]) -> void:
	TestAssertions.equal(control.call(&"semantic_state_id"), expected_state, "%s exposes stable semantic state" % expected_state, failures)
	var state_text := control.get_node("Surface/Content/StateCue/StateText") as Label
	var state_icon := control.get_node("Surface/Content/StateCue/StateIcon") as TextureRect
	var geometry := control.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	TestAssertions.equal(state_text.text, expected_text, "%s has visible state text", failures)
	TestAssertions.truthy(state_icon.visible and state_icon.texture != null, "%s has a visible semantic icon", failures)
	TestAssertions.truthy(geometry.visible and geometry.polygon.size() >= 3, "%s has non-color shape geometry", failures)
	TestAssertions.equal(_icon_tint(state_icon), expected_color, "%s icon resolves the expected semantic color token", failures)


func _assert_exact_semantic_color_role(control: Control, role: StringName, high_contrast: bool, includes_health: bool, failures: Array[String]) -> void:
	var expected := LivingForgeTokens.color(role, high_contrast)
	var state_text := control.get_node("Surface/Content/StateCue/StateText") as Label
	var state_icon := control.get_node("Surface/Content/StateCue/StateIcon") as TextureRect
	var geometry := control.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	var surface_style := (control.get_node("Surface") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
	TestAssertions.equal(_icon_tint(state_icon), expected, "%s icon uses exact %s token" % [control.name, role], failures)
	TestAssertions.equal(state_text.get_theme_color(&"font_color"), expected, "%s state text uses exact %s token" % [control.name, role], failures)
	TestAssertions.equal(geometry.color, expected, "%s state shape uses exact %s token" % [control.name, role], failures)
	TestAssertions.truthy(surface_style != null and surface_style.border_color == expected, "%s semantic edge uses exact %s token" % [control.name, role], failures)
	if includes_health:
		var fill := (control.get_node("Surface/Content/Health/Bar") as ProgressBar).get_theme_stylebox(&"fill") as StyleBoxFlat
		TestAssertions.truthy(fill != null and fill.bg_color == expected, "%s health fill uses exact %s token" % [control.name, role], failures)


func _assert_exact_alert_color_role(alert: Control, role: StringName, high_contrast: bool, failures: Array[String]) -> void:
	var expected := LivingForgeTokens.color(role, high_contrast)
	var state_text := alert.get_node("Surface/StateText") as Label
	var state_icon := alert.get_node("Surface/StateIcon") as TextureRect
	var geometry := alert.get_node("Surface/StateShape/Geometry") as Polygon2D
	var surface_style := (alert.get_node("Surface") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
	TestAssertions.equal(_icon_tint(state_icon), expected, "%s alert icon uses exact %s token" % [alert.call(&"semantic_state_id"), role], failures)
	TestAssertions.equal(state_text.get_theme_color(&"font_color"), expected, "%s alert text uses exact %s token" % [alert.call(&"semantic_state_id"), role], failures)
	TestAssertions.equal(geometry.color, expected, "%s alert shape uses exact %s token" % [alert.call(&"semantic_state_id"), role], failures)
	TestAssertions.truthy(surface_style != null and surface_style.border_color == expected, "%s alert edge uses exact %s token" % [alert.call(&"semantic_state_id"), role], failures)


func _assert_alert_actions(alert: Control, inspect_allowed: bool, ledger_allowed: bool, failures: Array[String]) -> void:
	var inspect := alert.get_node_or_null("Surface/Content/Actions/Inspect") as Button
	var ledger := alert.get_node_or_null("Surface/Content/Actions/Ledger") as Button
	TestAssertions.truthy(inspect != null and ledger != null, "alert exposes distinct Inspect and Ledger button nodes", failures)
	if inspect == null or ledger == null:
		return
	TestAssertions.equal(inspect.visible, inspect_allowed, "Inspect visibility follows authoritative availability", failures)
	TestAssertions.equal(ledger.visible, ledger_allowed, "Ledger visibility follows authoritative availability", failures)
	TestAssertions.equal(inspect.disabled, not inspect_allowed, "Inspect disabled state follows authoritative availability", failures)
	TestAssertions.equal(ledger.disabled, not ledger_allowed, "Ledger disabled state follows authoritative availability", failures)
	TestAssertions.equal(inspect.focus_mode, Control.FOCUS_ALL if inspect_allowed else Control.FOCUS_NONE, "Inspect focusability follows authoritative availability", failures)
	TestAssertions.equal(ledger.focus_mode, Control.FOCUS_ALL if ledger_allowed else Control.FOCUS_NONE, "Ledger focusability follows authoritative availability", failures)
	TestAssertions.truthy(not inspect_allowed or inspect.accessibility_name.begins_with("Inspect "), "enabled Inspect has an explicit accessibility name", failures)
	TestAssertions.truthy(not ledger_allowed or ledger.accessibility_name.begins_with("Open ledger for "), "enabled Ledger has an explicit accessibility name", failures)


func _assert_member_binding_cleared(control: Control, failures: Array[String]) -> void:
	TestAssertions.equal((control.get_node("Surface/Content/Identity/Name") as Label).text, "", "%s null binding clears name" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/Identity/Class") as Label).text, "", "%s null binding clears class/level/rank" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/Meta") as Label).text, "", "%s null binding clears metadata" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/Health/Value") as Label).text, "", "%s null binding clears numeric health" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/Health/Bar") as ProgressBar).value, 0.0, "%s null binding clears health value" % control.name, failures)
	TestAssertions.truthy(not (control.get_node("Surface/LeaderCue") as Control).visible, "%s null binding clears leader cue" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/StateCue/StateText") as Label).text, "", "%s null binding clears status text" % control.name, failures)
	TestAssertions.truthy((control.get_node("Surface/Content/StateCue/StateIcon") as TextureRect).texture == null, "%s null binding clears status icon" % control.name, failures)
	TestAssertions.equal((control.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D).polygon, PackedVector2Array(), "%s null binding clears status shape" % control.name, failures)
	TestAssertions.equal(control.accessibility_name, "Party member unavailable", "%s null binding resets accessibility name" % control.name, failures)
	TestAssertions.truthy(control.disabled and control.focus_mode == Control.FOCUS_NONE, "%s null binding is explicitly disabled and excluded from focus" % control.name, failures)
	TestAssertions.truthy(not (control.get_node("FocusFrame") as Control).visible and not (control.get_node("HoverPlate") as Control).visible, "%s null binding clears focus and hover presentation" % control.name, failures)


func _assert_alert_binding_cleared(alert: Control, failures: Array[String]) -> void:
	TestAssertions.equal((alert.get_node("Surface/Content/Summary") as Label).text, "", "null alert binding clears summary", failures)
	TestAssertions.equal((alert.get_node("Surface/Content/Detail") as Label).text, "", "null alert binding clears detail", failures)
	TestAssertions.equal((alert.get_node("Surface/StateText") as Label).text, "", "null alert binding clears severity text", failures)
	TestAssertions.truthy((alert.get_node("Surface/StateIcon") as TextureRect).texture == null, "null alert binding clears severity icon", failures)
	TestAssertions.equal((alert.get_node("Surface/StateShape/Geometry") as Polygon2D).polygon, PackedVector2Array(), "null alert binding clears severity shape", failures)
	TestAssertions.equal(alert.accessibility_name, "Combat alert unavailable", "null alert binding resets accessibility name", failures)
	TestAssertions.truthy(alert.disabled and alert.focus_mode == Control.FOCUS_NONE, "null alert binding is explicitly disabled and excluded from focus", failures)
	TestAssertions.truthy(not (alert.get_node("FocusFrame") as Control).visible and not (alert.get_node("HoverPlate") as Control).visible, "null alert binding clears focus and hover presentation", failures)
	_assert_alert_actions(alert, false, false, failures)


func _member_semantic_snapshot(control: Control) -> Dictionary:
	var icon := control.get_node("Surface/Content/StateCue/StateIcon") as TextureRect
	var geometry := control.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	return {
		"state_id": control.call(&"semantic_state_id"),
		"state_text": (control.get_node("Surface/Content/StateCue/StateText") as Label).text,
		"icon": icon.texture.resource_path if icon.texture != null else "",
		"shape": geometry.polygon,
		"disabled": control.disabled,
		"focus_mode": control.focus_mode,
		"leader_visible": (control.get_node("Surface/LeaderCue") as Control).visible,
		"leader_text": (control.get_node("Surface/LeaderCue/Text") as Label).text,
		"accessibility_name": control.accessibility_name,
		"accessibility_description": control.accessibility_description,
	}


func _alert_semantic_snapshot(alert: Control) -> Dictionary:
	var icon := alert.get_node("Surface/StateIcon") as TextureRect
	var geometry := alert.get_node("Surface/StateShape/Geometry") as Polygon2D
	var inspect := alert.get_node_or_null("Surface/Content/Actions/Inspect") as Button
	var ledger := alert.get_node_or_null("Surface/Content/Actions/Ledger") as Button
	return {
		"state_id": alert.call(&"semantic_state_id"),
		"state_text": (alert.get_node("Surface/StateText") as Label).text,
		"icon": icon.texture.resource_path if icon.texture != null else "",
		"shape": geometry.polygon,
		"disabled": alert.disabled,
		"focus_mode": alert.focus_mode,
		"inspect_present": inspect != null,
		"inspect_visible": inspect.visible if inspect != null else false,
		"inspect_disabled": inspect.disabled if inspect != null else true,
		"inspect_focus_mode": inspect.focus_mode if inspect != null else Control.FOCUS_NONE,
		"inspect_accessibility_name": inspect.accessibility_name if inspect != null else "",
		"inspect_accessibility_description": inspect.accessibility_description if inspect != null else "",
		"ledger_present": ledger != null,
		"ledger_visible": ledger.visible if ledger != null else false,
		"ledger_disabled": ledger.disabled if ledger != null else true,
		"ledger_focus_mode": ledger.focus_mode if ledger != null else Control.FOCUS_NONE,
		"ledger_accessibility_name": ledger.accessibility_name if ledger != null else "",
		"ledger_accessibility_description": ledger.accessibility_description if ledger != null else "",
		"accessibility_name": alert.accessibility_name,
		"accessibility_description": alert.accessibility_description,
	}


func _member_scenarios() -> Array[Dictionary]:
	return [
		{"member_id": 1, "name": "Aria", "class_id": &"fighter", "class_label": "Fighter", "level": 7, "rank": 3, "health": 90.0, "leader": true, "downed": false, "dead": false, "state": &"normal", "text": "READY", "color_role": &"valid"},
		{"member_id": 2, "name": "Brom", "class_id": &"mage", "class_label": "Mage", "level": 4, "rank": 2, "health": 20.0, "leader": false, "downed": false, "dead": false, "state": &"critical", "text": "CRITICAL", "color_role": &"error"},
		{"member_id": 3, "name": "Cyra", "class_id": &"rogue", "class_label": "Rogue", "level": 5, "rank": 2, "health": 0.0, "leader": false, "downed": true, "dead": false, "state": &"downed", "text": "DOWNED", "color_role": &"error"},
		{"member_id": 4, "name": "Dara", "class_id": &"bard", "class_label": "Bard", "level": 6, "rank": 4, "health": 0.0, "leader": false, "downed": false, "dead": true, "state": &"dead", "text": "DEAD", "color_role": &"error"},
	]


func _instantiate(path: String) -> Control:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Control if packed != null else null


func _icon_tint(icon: TextureRect) -> Color:
	var material := icon.material as ShaderMaterial
	return material.get_shader_parameter(&"icon_color") as Color if material != null else Color.TRANSPARENT
