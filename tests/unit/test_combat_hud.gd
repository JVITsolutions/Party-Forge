extends RefCounted


class TestRun:
	extends Node
	var seconds := 125.0
	func elapsed_time() -> float:
		return seconds


var _fixture_sequence := 7000


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_contract(failures)
	_test_party_scale_and_signal_updates(failures)
	_test_alert_surface_and_complete_tray(failures)
	_test_fail_closed_status_and_pluralization(failures)
	_test_pause_safe_inspector_and_ledger_routes(failures)
	return failures


func _test_scene_contract(failures: Array[String]) -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as CanvasLayer if hud_scene != null else null
	TestAssertions.truthy(hud != null, "combat HUD scene instantiates", failures)
	if hud == null:
		return
	for path: NodePath in [
		^"Margin/CombatStatus/LeaderCard",
		^"Margin/CombatStatus/Experience",
		^"Margin/CombatStatus/RunTime",
		^"Margin/CombatStatus/PartyRegion/RichRoster",
		^"Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow",
		^"Margin/CombatStatus/PartyRegion/CompactRoster/PagePrevious",
		^"Margin/CombatStatus/PartyRegion/CompactRoster/PageNext",
		^"Margin/CombatStatus/AlertRegion/ExpandedAlerts",
		^"Margin/CombatStatus/AlertRegion/Overflow",
		^"Margin/CombatStatus/BossRegion",
		^"Margin/CombatStatus/HudUnavailable",
		^"CombatAlertTray",
		^"CombatMemberInspectPanel",
	]:
		TestAssertions.truthy(hud.get_node_or_null(path) != null, "HUD exposes stable path %s" % path, failures)
	for obsolete: NodePath in [
		^"Margin/Status/PartyEntries/Party1",
		^"Margin/Status/PartyEntries/Party2",
		^"Margin/Status/PartyEntries/Party3",
		^"Margin/Status/PartyEntries/Party4",
	]:
		TestAssertions.equal(hud.get_node_or_null(obsolete), null, "fixed-four node is removed: %s" % obsolete, failures)
	var scene_source := FileAccess.get_file_as_string("res://scenes/ui/hud.tscn")
	var script_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	TestAssertions.truthy("Tactics" not in scene_source and "Gambit" not in scene_source and "tactics" not in script_source.to_lower(), "HUD exposes no tactics data or control", failures)
	TestAssertions.truthy("Objective" not in scene_source, "unsupported objective decoration is absent", failures)
	hud.free()


func _test_party_scale_and_signal_updates(failures: Array[String]) -> void:
	for count: int in [1, 6, 7, 12, 20, 24]:
		var fixture := _fixture(count)
		var hud := _configured_hud(fixture)
		TestAssertions.truthy(hud != null, "HUD configures for party size %d" % count, failures)
		if hud == null:
			_cleanup_fixture(fixture)
			continue
		var rich := hud.get_node("Margin/CombatStatus/PartyRegion/RichRoster") as Control
		var compact := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control
		TestAssertions.equal(rich.visible, count <= 6, "party %d uses rich mode exactly" % count, failures)
		TestAssertions.equal(compact.visible, count >= 7, "party %d uses compact mode exactly" % count, failures)
		var reached := _collect_member_ids_across_pages(hud)
		TestAssertions.equal(reached.size(), count, "party %d reaches every stable member ID" % count, failures)
		for member_id: int in range(1, count + 1):
			TestAssertions.truthy(reached.has(member_id), "party %d reaches member %d" % [count, member_id], failures)
		var live_members := _member_controls(hud)
		var visible_bound := count if count <= 6 else CombatHudResponsiveLayout.resolve(Vector2i(1920, 1080), 100, 100, count).visible_member_count
		TestAssertions.truthy(live_members.size() <= visible_bound, "party %d keeps bounded live member controls" % count, failures)
		if count == 1:
			TestAssertions.truthy((hud.get_node("Margin/CombatStatus/PartyRegion/NoFollowers") as Label).visible, "one-member party presents intentional no-followers state", failures)
		if count == 24:
			_focus_page_containing(hud, 24)
			var member_control := _member_control(hud, 24)
			TestAssertions.truthy(member_control != null, "final compact member has a real control", failures)
			if member_control != null:
				var instance_id := member_control.get_instance_id()
				var health := fixture.health_by_member[24] as HealthComponent
				health.apply_damage(80.0)
				var refreshed := _member_control(hud, 24)
				TestAssertions.equal(refreshed.get_instance_id() if refreshed != null else 0, instance_id, "health refresh preserves the real member control", failures)
				var bar := refreshed.get_node("Surface/Content/Health/Bar") as Range if refreshed != null else null
				TestAssertions.near(bar.value if bar != null else -1.0, 20.0, 0.001, "health signal refresh updates the real health bar", failures)
				hud.call("_process", 0.016)
				TestAssertions.equal((_member_control(hud, 24) as Control).get_instance_id(), instance_id, "timer frame does not rebuild party controls", failures)
		_cleanup_hud(hud)
		_cleanup_fixture(fixture)

	var late_fixture := _fixture(1, false)
	var late_hud := _configured_hud(late_fixture)
	TestAssertions.truthy(late_hud != null, "HUD accepts an initially unbound actor fail-closed", failures)
	if late_hud != null:
		var actor := _bind_health_actor(late_fixture.context, 1, 100.0)
		late_fixture.actors.append(actor)
		late_fixture.health_by_member[1] = actor.get_node("HealthComponent") as HealthComponent
		var late_leader := late_hud.get_node("Margin/CombatStatus/LeaderCard") as Control
		TestAssertions.equal(int(late_leader.get_meta("member_id", 0)), 1, "future actor_bound refreshes the leader anchor without polling", failures)
		_cleanup_hud(late_hud)
	_cleanup_fixture(late_fixture)

	var rebound_fixture := _fixture(1)
	var rebound_hud := _configured_hud(rebound_fixture)
	var leader := rebound_hud.get_node("Margin/CombatStatus/LeaderCard") as Control
	var leader_instance := leader.get_instance_id()
	var old_health := rebound_fixture.health_by_member[1] as HealthComponent
	var replacement := _bind_health_actor(rebound_fixture.context, 1, 240.0)
	(rebound_fixture.actors as Array).append(replacement)
	var new_health := replacement.get_node("HealthComponent") as HealthComponent
	(rebound_fixture.health_by_member as Dictionary)[1] = new_health
	old_health.apply_damage(80.0)
	var bar := leader.get_node("Surface/Content/Health/Bar") as Range
	TestAssertions.equal(leader.get_instance_id(), leader_instance, "actor rebind preserves the leader control instance", failures)
	TestAssertions.near(bar.value, 240.0, 0.001, "old actor health is disconnected after actor rebind", failures)
	new_health.apply_damage(40.0)
	TestAssertions.near(bar.value, 200.0, 0.001, "replacement actor health refreshes the bound control", failures)
	_cleanup_hud(rebound_hud)
	_cleanup_fixture(rebound_fixture)


func _test_alert_surface_and_complete_tray(failures: Array[String]) -> void:
	var fixture := _fixture(7)
	for member_id: int in range(1, 8):
		var health := fixture.health_by_member[member_id] as HealthComponent
		if member_id <= 2:
			health.kill()
		elif member_id <= 4:
			health.apply_damage(100.0)
		else:
			health.apply_damage(80.0)
	var hud := _configured_hud(fixture)
	TestAssertions.truthy(hud != null, "overflow-alert HUD configures", failures)
	if hud == null:
		_cleanup_fixture(fixture)
		return
	var expanded := hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	TestAssertions.equal(expanded.get_child_count(), 3, "exactly three alerts expand", failures)
	TestAssertions.equal(overflow.text, "+4 alerts", "overflow count is exact", failures)
	var projection := hud.get("current_projection") as CombatHudProjection
	TestAssertions.equal(projection.all_alerts.size(), 7, "HUD retains the complete Task 2 alert projection", failures)
	overflow.pressed.emit()
	var tray := hud.get_node("CombatAlertTray") as CanvasLayer
	TestAssertions.truthy(tray.visible, "overflow opens the complete alert tray", failures)
	TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "alert tray owns a pause lease", failures)
	var tray_list := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	TestAssertions.equal(tray_list.get_child_count(), projection.all_alerts.size(), "tray receives every sorted alert without reconstruction", failures)
	var focused_card := tray_list.get_child(4) as Control
	var focused_instance := focused_card.get_instance_id()
	tray.call("open", projection.all_alerts, overflow)
	var stable_id: StringName = focused_card.get_meta("stable_alert_id", &"")
	var preserved := _tray_card(tray, stable_id)
	TestAssertions.equal(preserved.get_instance_id() if preserved != null else 0, focused_instance, "alert refresh preserves the stable alert control instance", failures)

	var external_pause := RunPauseLease.new()
	tray.call("close")
	external_pause.acquire(Engine.get_main_loop() as SceneTree)
	overflow.pressed.emit()
	tray.call("close")
	TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "closing tray preserves another pause owner", failures)
	external_pause.release(Engine.get_main_loop() as SceneTree)
	_cleanup_hud(hud)
	_cleanup_fixture(fixture)


func _test_fail_closed_status_and_pluralization(failures: Array[String]) -> void:
	var plural_fixture := _fixture(4)
	for member_id: int in range(1, 5):
		(plural_fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	var plural_hud := _configured_hud(plural_fixture)
	var overflow := plural_hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	TestAssertions.equal(overflow.text, "+1 alert", "one overflow alert uses singular accessible copy", failures)
	TestAssertions.equal(overflow.accessibility_name, "Open 1 additional combat alert", "one overflow alert accessibility is singular", failures)
	_cleanup_hud(plural_hud)
	_cleanup_fixture(plural_fixture)

	var mismatch := _fixture(1)
	var foreign := _fixture(1)
	var mismatch_hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	(Engine.get_main_loop() as SceneTree).root.add_child(mismatch_hud)
	mismatch_hud.configure(mismatch.run, mismatch.party, mismatch.experience, foreign.context, mismatch.settings)
	_assert_unavailable(mismatch_hud, "party context", "authority mismatch remains visibly fail closed", failures)
	_cleanup_hud(mismatch_hud)
	_cleanup_fixture(mismatch)
	_cleanup_fixture(foreign)

	var invalid_identity := _fixture(1)
	invalid_identity.party.members[0].member_id = 0
	var invalid_hud := _configured_hud(invalid_identity)
	_assert_unavailable(invalid_hud, "identity", "invalid member identity remains visibly fail closed", failures)
	_cleanup_hud(invalid_hud)
	_cleanup_fixture(invalid_identity)

	var missing_health := _fixture(1, false)
	var missing_hud := _configured_hud(missing_health)
	_assert_unavailable(missing_hud, "health", "missing member health remains visibly fail closed", failures)
	_cleanup_hud(missing_hud)
	_cleanup_fixture(missing_health)


func _assert_unavailable(hud: HUD, reason_fragment: String, message: String, failures: Array[String]) -> void:
	var unavailable := hud.get_node_or_null("Margin/CombatStatus/HudUnavailable") as Label
	TestAssertions.truthy(unavailable != null and unavailable.visible, message, failures)
	if unavailable != null:
		TestAssertions.truthy(unavailable.text.begins_with("HUD unavailable:") and reason_fragment in unavailable.text.to_lower(), "%s has a concise reason" % message, failures)


func _test_pause_safe_inspector_and_ledger_routes(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var fixture := _fixture(2)
	var hud := _configured_hud(fixture)
	TestAssertions.truthy(hud != null, "route HUD configures", failures)
	if hud == null:
		_cleanup_fixture(fixture)
		return
	var member_control := _member_control(hud, 2)
	TestAssertions.truthy(member_control != null, "route fixture owns member two control", failures)
	if member_control != null:
		var inspect_intents: Array = []
		hud.connect("inspect_requested", func(member_id: int, return_focus: Control) -> void: inspect_intents.append([member_id, return_focus]))
		member_control.pressed.emit()
		TestAssertions.equal(inspect_intents.size(), 1, "member activation emits one Inspect intent", failures)
		if inspect_intents.size() == 1:
			TestAssertions.equal(inspect_intents[0][0], 2, "Inspect carries exact member ID", failures)
			TestAssertions.equal(inspect_intents[0][1], member_control, "Inspect carries initiating real control", failures)
		TestAssertions.truthy(bool(hud.call("open_inspector_for_member", 2, member_control)), "read-only inspector opens exact member", failures)
		var inspector := hud.get_node("CombatMemberInspectPanel") as CanvasLayer
		TestAssertions.truthy(inspector.visible and tree.paused, "inspector is a paused HUD child", failures)
		var member_two := (hud.get("current_projection") as CombatHudProjection).members[1]
		TestAssertions.truthy(member_two.display_name in (inspector.get_node("Overlay/Frame/Layout/Identity") as Label).text, "inspector shows exact member identity", failures)
		inspector.call("close")
		TestAssertions.truthy(not tree.paused, "inspector close restores the prior pause state", failures)

	var game_run := GameRun.new()
	game_run.configure_seed(_fixture_sequence + 1)
	tree.root.add_child(game_run)
	game_run.start_run()
	var ledger := (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	ledger.configure(game_run, fixture.party, GameCatalog.load_defaults(), Callable(self, "_ledger_health").bind(fixture), [], null, Callable(fixture.context, "progression_for"), fixture.context)
	TestAssertions.truthy(ledger.has_method("open_for_member"), "Ledger exposes exact-member route", failures)
	if ledger.has_method("open_for_member") and member_control != null:
		TestAssertions.truthy(bool(ledger.call("open_for_member", 2, &"stats", member_control)), "Ledger opens exact member and stats page", failures)
		TestAssertions.equal(ledger.context.selected_member_id, 2, "Ledger selects exact member", failures)
		TestAssertions.equal(ledger.context.active_page_id, &"stats", "Ledger selects exact requested page", failures)
		ledger.close()
	var other_owner := RunPauseLease.new()
	other_owner.acquire(tree)
	if ledger.has_method("open_for_member"):
		ledger.call("open_for_member", 1, &"stats", member_control)
		ledger.close()
		TestAssertions.truthy(tree.paused, "Ledger close does not unpause another owner", failures)
	other_owner.release(tree)
	ledger.free()
	game_run.free()
	_cleanup_hud(hud)
	_cleanup_fixture(fixture)
	tree.paused = false


func _fixture(count: int, bind_actors: bool = true) -> Dictionary:
	_fixture_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(count))
	party.configure_identity(_fixture_sequence, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(count - 1):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
	var profile := ProfileState.new_profile("profile-hud-%d" % _fixture_sequence, "HUD", 1000)
	var context := PlayerRunContext.new()
	assert(context.configure(StringName("hud-player-%d" % _fixture_sequence), 0, profile, _fixture_sequence, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var result := {
		"party": party,
		"context": context,
		"experience": experience,
		"run": TestRun.new(),
		"settings": PartyForgeSettings.new(),
		"actors": [],
		"health_by_member": {},
	}
	if bind_actors:
		for member_id: int in range(1, count + 1):
			var actor := _bind_health_actor(context, member_id, 100.0)
			(result.actors as Array).append(actor)
			(result.health_by_member as Dictionary)[member_id] = actor.get_node("HealthComponent") as HealthComponent
	return result


func _bind_health_actor(context: PlayerRunContext, member_id: int, maximum: float) -> Node3D:
	var actor := Node3D.new()
	actor.name = "Actor%d" % member_id
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	actor.add_child(health)
	health.configure(maximum, member_id == 1, 8.0, 0.5, member_id == 1)
	assert(context.bind_actor(member_id, actor))
	return actor


func _configured_hud(fixture: Dictionary) -> HUD:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	if hud == null:
		return null
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	if not hud.has_method("configure") or hud.get_node_or_null("Margin/CombatStatus") == null:
		hud.free()
		return null
	hud.call("configure", fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	return hud


func _collect_member_ids_across_pages(hud: HUD) -> Dictionary:
	var reached: Dictionary = {}
	var leader := hud.get_node_or_null("Margin/CombatStatus/LeaderCard") as Control
	if leader != null and int(leader.get_meta("member_id", 0)) > 0:
		reached[int(leader.get_meta("member_id", 0))] = true
	if hud.get_node_or_null("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") == null:
		for control: Control in _member_controls(hud):
			reached[int(control.get_meta("member_id", 0))] = true
		return reached
	var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	while true:
		for control: Control in _member_controls(hud):
			reached[int(control.get_meta("member_id", 0))] = true
		if not next.visible or next.disabled:
			break
		next.pressed.emit()
	return reached


func _focus_page_containing(hud: HUD, member_id: int) -> void:
	var next := hud.get_node_or_null("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	while _member_control(hud, member_id) == null and next != null and not next.disabled:
		next.pressed.emit()


func _member_controls(hud: HUD) -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in hud.find_children("*", "Control", true, false):
		if node is Control and node.is_in_group(&"combat_hud_member"):
			result.append(node as Control)
	return result


func _member_control(hud: HUD, member_id: int) -> Control:
	for control: Control in _member_controls(hud):
		if int(control.get_meta("member_id", 0)) == member_id:
			return control
	return null


func _tray_card(tray: CanvasLayer, stable_id: StringName) -> Control:
	var list := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	for child: Node in list.get_children():
		if StringName(child.get_meta("stable_alert_id", &"")) == stable_id:
			return child as Control
	return null


func _ledger_health(member_id: int, fixture: Dictionary) -> Dictionary:
	var health := (fixture.health_by_member as Dictionary).get(member_id) as HealthComponent
	if health == null:
		return {}
	return {"current": health.current_health, "maximum": health.max_health, "is_downed": health.is_downed, "is_dead": health.is_dead, "component": health}


func _cleanup_hud(hud: HUD) -> void:
	if hud != null and is_instance_valid(hud):
		hud.free()
	(Engine.get_main_loop() as SceneTree).paused = false


func _cleanup_fixture(fixture: Dictionary) -> void:
	var experience := fixture.get("experience") as ExperienceSystem
	if experience != null and is_instance_valid(experience):
		experience.free()
	var party := fixture.get("party") as PartyManager
	if party != null and is_instance_valid(party):
		party.free()
	for actor: Node3D in fixture.get("actors", []) as Array:
		if actor != null and is_instance_valid(actor):
			actor.free()
	var run := fixture.get("run") as Node
	if run != null and is_instance_valid(run):
		run.free()
