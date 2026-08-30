extends RefCounted

var _health_by_member: Dictionary = {}


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_runtime_truth_orders_complete_alert_set_without_truncating_members(failures)
	_test_ordered_party_revision_ignores_health_and_tracks_static_structure(failures)
	return failures


func _test_runtime_truth_orders_complete_alert_set_without_truncating_members(failures: Array[String]) -> void:
	var fixture := _twenty_four_member_fixture()
	var party := fixture.party as PartyManager
	var context := fixture.context as PlayerRunContext
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	TestAssertions.truthy(context.award_experience(1, 3).ok(), "leader experience fixture awards through the run context", failures)
	_health_by_member = {
		1: {"current": 25.0, "max": 100.0, "downed": false, "dead": false},
		2: {"current": 0.0, "max": 100.0, "downed": true, "dead": false},
		3: {"current": 0.0, "max": 100.0, "downed": false, "dead": true},
		4: {"current": 24.0, "max": 100.0, "downed": false, "dead": false},
		5: {"current": 1.0, "max": 100.0, "downed": false, "dead": false},
	}
	var view_model := _new_view_model(failures)
	if view_model == null:
		party.free()
		return
	var projection: CombatHudProjection = view_model.call("build", party, context, Callable(self, "_health_for"), experience, 125.0, null) as CombatHudProjection
	TestAssertions.equal(projection.members.size(), 24, "view model never truncates the party", failures)
	TestAssertions.equal(projection.members[0].member_id, party.members[0].member_id, "leader remains first according to PartyManager members", failures)
	TestAssertions.equal(projection.members[1].level, context.progression_for(2).level, "follower levels come from PlayerRunContext", failures)
	TestAssertions.equal(projection.experience, experience.experience, "ExperienceSystem remains leader experience authority", failures)
	TestAssertions.equal(projection.all_alerts.map(func(alert: CombatAlertProjection) -> StringName: return alert.stable_id), [&"downed:002", &"dead:003", &"critical:001", &"critical:004", &"critical:005"], "alerts use severity then party order then stable ID", failures)
	TestAssertions.truthy(projection.all_alerts.all(func(alert: CombatAlertProjection) -> bool: return alert.severity in [CombatAlertProjection.Severity.CRITICAL, CombatAlertProjection.Severity.DOWNED, CombatAlertProjection.Severity.DEAD]), "only production-backed alert severities are emitted", failures)
	TestAssertions.equal(projection.visible_alerts.size(), 3, "only three alerts expand", failures)
	TestAssertions.equal(projection.overflow_alert_count, projection.all_alerts.size() - 3, "overflow is exact", failures)
	TestAssertions.truthy(projection.visible_alerts[0].severity in [CombatAlertProjection.Severity.DEAD, CombatAlertProjection.Severity.DOWNED], "downed or dying sorts first", failures)
	party.free()


func _test_ordered_party_revision_ignores_health_and_tracks_static_structure(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(3))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "Leader"
	var view_model := _new_view_model(failures)
	if view_model == null:
		party.free()
		return
	var initial_revision: String = String(view_model.call("ordered_party_revision", party))
	_health_by_member = {1: {"current": 90.0, "max": 100.0, "downed": false, "dead": false}}
	var healthy_projection: CombatHudProjection = view_model.call("build", party, null, Callable(self, "_health_for"), null, 0.0, null) as CombatHudProjection
	var health_before := _health_for(1)
	_health_by_member[1] = {"current": 10.0, "max": 100.0, "downed": false, "dead": false}
	var critical_projection: CombatHudProjection = view_model.call("build", party, null, Callable(self, "_health_for"), null, 0.0, null) as CombatHudProjection
	TestAssertions.truthy(float((_health_for(1) as Dictionary)["current"]) != float((health_before as Dictionary)["current"]), "health fixture changes runtime values", failures)
	TestAssertions.truthy(healthy_projection.members[0].health != critical_projection.members[0].health, "health changes projection values", failures)
	TestAssertions.equal(String(view_model.call("ordered_party_revision", party)), initial_revision, "dynamic health does not change ordered party revision", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "revision fixture adds a member through PartyManager", failures)
	var added_member_revision: String = String(view_model.call("ordered_party_revision", party))
	TestAssertions.truthy(added_member_revision != initial_revision, "adding a member changes ordered party revision", failures)
	party.members[1].character_name = "Static Identity Changed"
	TestAssertions.truthy(String(view_model.call("ordered_party_revision", party)) != added_member_revision, "static member identity changes ordered party revision", failures)
	party.free()


func _twenty_four_member_fixture() -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.configure_identity(4242, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(23):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
	var profile := ProfileState.new_profile("profile-combat-hud", "Combat HUD", 1000)
	profile.inventory_columns = 5
	var context := PlayerRunContext.new()
	assert(context.configure(&"combat_hud_player", 0, profile, 4242, party, 100).is_empty())
	return {"party": party, "context": context}


func _health_for(member_id: int) -> Dictionary:
	return (_health_by_member.get(member_id, {"current": 100.0, "max": 100.0, "downed": false, "dead": false}) as Dictionary).duplicate()


func _new_view_model(failures: Array[String]) -> RefCounted:
	var script := load("res://scripts/ui/hud/combat_hud_view_model.gd") as Script
	TestAssertions.truthy(script != null, "combat HUD view model script exists", failures)
	return script.new() as RefCounted if script != null else null
