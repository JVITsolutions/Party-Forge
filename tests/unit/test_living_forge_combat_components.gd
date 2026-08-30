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
]


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resources_and_manifest_contract(failures)
	_test_owned_icon_provenance(failures)
	_test_rich_member_contract(failures)
	_test_compact_member_contract(failures)
	_test_alert_contract(failures)
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
	TestAssertions.equal(constants.get("EXPECTED_CAPTURE_FILES", []), EXPECTED_CAPTURE_FILES, "combat evidence declares four exact filenames before board implementation", failures)


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
	_assert_member_state(card, &"critical", "CRITICAL", LivingForgeTokens.color(&"warning", false), failures)
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
	TestAssertions.equal((marker.get_node("Surface/Content/Identity/Class") as Label).text, "MAGE  ·  L4", "compact marker keeps class and level readable", failures)
	TestAssertions.equal((marker.get_node("Surface/Content/Health/Value") as Label).text, "10 / 100", "compact marker keeps numeric health readable", failures)
	TestAssertions.equal(marker.accessibility_name, "Inspect Brom, Mage, Level 4, 10 of 100 health", "compact marker has an explicit member action name", failures)
	TestAssertions.truthy(marker.accessibility_description.contains("State: Critical"), "compact critical marker exposes its semantic state accessibly", failures)
	_assert_member_state(marker, &"critical", "CRITICAL", LivingForgeTokens.color(&"warning", false), failures)
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
	for index: int in alerts.size():
		alert.call(&"present_alert", alerts[index])
		TestAssertions.equal((alert.get_node("Surface/StateText") as Label).text, expected_text[index], "%s alert has visible severity text" % expected_text[index], failures)
		TestAssertions.truthy((alert.get_node("Surface/StateIcon") as TextureRect).visible and (alert.get_node("Surface/StateIcon") as TextureRect).texture != null, "%s alert has a visible icon" % expected_text[index], failures)
		var geometry := alert.get_node("Surface/StateShape/Geometry") as Polygon2D
		TestAssertions.truthy(geometry.visible and geometry.polygon.size() >= 3, "%s alert has distinct non-color shape geometry" % expected_text[index], failures)
		TestAssertions.equal((alert.get_node("Surface/Content/Summary") as Label).text, alerts[index].summary, "%s alert presents authoritative summary" % expected_text[index], failures)
		TestAssertions.equal((alert.get_node("Surface/Content/Detail") as Label).text, alerts[index].detail, "%s alert presents authoritative detail" % expected_text[index], failures)
		TestAssertions.truthy(alert.accessibility_name.contains(expected_text[index].capitalize()) and alert.accessibility_name.contains(alerts[index].summary), "%s alert accessibility names severity and member truth" % expected_text[index], failures)
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


func _member_scenarios() -> Array[Dictionary]:
	return [
		{"member_id": 1, "name": "Aria", "class_id": &"fighter", "class_label": "Fighter", "level": 7, "rank": 3, "health": 90.0, "leader": true, "downed": false, "dead": false, "state": &"normal", "text": "READY", "color_role": &"valid"},
		{"member_id": 2, "name": "Brom", "class_id": &"mage", "class_label": "Mage", "level": 4, "rank": 2, "health": 20.0, "leader": false, "downed": false, "dead": false, "state": &"critical", "text": "CRITICAL", "color_role": &"warning"},
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
