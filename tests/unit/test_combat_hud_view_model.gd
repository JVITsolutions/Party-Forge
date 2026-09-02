extends RefCounted

var _health_by_member: Dictionary = {}


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_runtime_truth_orders_complete_alert_set_without_truncating_members(failures)
	_test_build_rejects_missing_or_mismatched_runtime_authorities(failures)
	_test_boss_projection_uses_live_health_and_rejects_unavailable_bosses(failures)
	_test_ordered_party_revision_ignores_health_and_tracks_static_structure(failures)
	return failures


func _test_runtime_truth_orders_complete_alert_set_without_truncating_members(failures: Array[String]) -> void:
	var fixture := _twenty_four_member_fixture()
	var party := fixture.party as PartyManager
	var context := fixture.context as PlayerRunContext
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	TestAssertions.truthy(context.award_experience(1, 3).ok(), "leader experience fixture awards through the run context", failures)
	TestAssertions.truthy(context.award_experience(2, 20).ok(), "follower experience fixture awards through the run context", failures)
	_health_by_member = {
		1: {"current": 25.0, "max": 100.0, "downed": false, "dead": false},
		2: {"current": 0.0, "max": 100.0, "downed": true, "dead": false},
		3: {"current": 0.0, "max": 100.0, "downed": false, "dead": true},
		4: {"current": 24.0, "max": 100.0, "downed": false, "dead": false},
		5: {"current": 1.0, "max": 100.0, "downed": false, "dead": false},
	}
	var view_model := _new_view_model(failures)
	if view_model == null:
		experience.free()
		party.free()
		return
	var projection: CombatHudProjection = view_model.call("build", party, context, Callable(self, "_health_for"), experience, 125.0, null) as CombatHudProjection
	TestAssertions.equal(projection.members.size(), 24, "view model never truncates the party", failures)
	TestAssertions.equal(projection.members[0].member_id, party.members[0].member_id, "leader remains first according to PartyManager members", failures)
	TestAssertions.equal(projection.members[1].level, context.progression_for(2).level, "follower levels come from PlayerRunContext", failures)
	TestAssertions.truthy(projection.members[1].level > 1, "follower runtime level is not synthesized as level one", failures)
	TestAssertions.equal(projection.experience, experience.experience, "ExperienceSystem remains leader experience authority", failures)
	TestAssertions.equal(projection.all_alerts.map(func(alert: CombatAlertProjection) -> StringName: return alert.stable_id), [&"downed:002", &"dead:003", &"critical:001", &"critical:004", &"critical:005"], "alerts use severity then party order then stable ID", failures)
	if not projection.has_method(&"highest_alert_severity"):
		TestAssertions.truthy(false, "view model projection exposes highest_alert_severity", failures)
		experience.free()
		party.free()
		return
	TestAssertions.equal(projection.highest_alert_severity(), CombatAlertProjection.Severity.DEAD, "summary derives highest severity from the complete ordered alert set", failures)
	TestAssertions.equal(projection.highest_severity_alert().stable_id, &"dead:003", "summary selects the highest alert without changing alert order", failures)
	TestAssertions.truthy(projection.all_alerts.all(func(alert: CombatAlertProjection) -> bool: return alert.severity in [CombatAlertProjection.Severity.CRITICAL, CombatAlertProjection.Severity.DOWNED, CombatAlertProjection.Severity.DEAD]), "only production-backed alert severities are emitted", failures)
	TestAssertions.equal(projection.visible_alerts.size(), 3, "only three alerts expand", failures)
	TestAssertions.equal(projection.overflow_alert_count, projection.all_alerts.size() - 3, "overflow is exact", failures)
	TestAssertions.truthy(projection.visible_alerts[0].severity in [CombatAlertProjection.Severity.DEAD, CombatAlertProjection.Severity.DOWNED], "downed or dying sorts first", failures)
	TestAssertions.equal(projection.validate(), PackedStringArray(), "happy-path runtime projection validates", failures)
	experience.free()
	party.free()


func _test_build_rejects_missing_or_mismatched_runtime_authorities(failures: Array[String]) -> void:
	var view_model := _new_view_model(failures)
	if view_model == null:
		return
	var missing_health := _two_member_fixture(5101)
	_health_by_member = {1: {"current": 100.0, "max": 100.0, "downed": false}}
	TestAssertions.equal(_build(view_model, missing_health), null, "missing health schema fails closed", failures)
	_cleanup_fixture(missing_health)

	var malformed_health := _two_member_fixture(5102)
	_health_by_member = {1: {"current": NAN, "max": 100.0, "downed": false, "dead": false}}
	TestAssertions.equal(_build(view_model, malformed_health), null, "non-finite health fails closed", failures)
	_cleanup_fixture(malformed_health)

	var missing_member := _two_member_fixture(5103)
	(missing_member.party as PartyManager).members.append(null)
	_health_by_member = {}
	TestAssertions.equal(_build(view_model, missing_member), null, "a null ordered party member fails closed instead of being skipped", failures)
	_cleanup_fixture(missing_member)

	var missing_progression := _two_member_fixture(5104)
	(missing_progression.context as PlayerRunContext).set("_progression_by_member", {})
	TestAssertions.equal(_build(view_model, missing_progression), null, "missing member progression fails closed", failures)
	_cleanup_fixture(missing_progression)

	var party_mismatch := _two_member_fixture(5105)
	var unrelated_party := PartyManager.new()
	var catalog := GameCatalog.load_defaults()
	unrelated_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.equal(_build(view_model, party_mismatch, null, unrelated_party), null, "context and party identity mismatch fails closed", failures)
	unrelated_party.free()
	_cleanup_fixture(party_mismatch)

	var experience_mismatch := _two_member_fixture(5106)
	var other_fixture := _two_member_fixture(5107)
	var other_experience := ExperienceSystem.new()
	other_experience.configure_context(other_fixture.context as PlayerRunContext, 1)
	TestAssertions.equal(_build(view_model, experience_mismatch, null, null, other_experience), null, "ExperienceSystem context mismatch fails closed", failures)
	other_experience.free()
	_cleanup_fixture(experience_mismatch)
	_cleanup_fixture(other_fixture)

	var leader_mismatch := _two_member_fixture(5108)
	var leader_experience := leader_mismatch.experience as ExperienceSystem
	leader_experience.leader_member_id = 2
	TestAssertions.equal(_build(view_model, leader_mismatch), null, "ExperienceSystem leader binding mismatch fails closed", failures)
	_cleanup_fixture(leader_mismatch)

	var blank_class_id := _two_member_fixture(5109)
	var blank_id_definition := (blank_class_id.party as PartyManager).members[0].class_definition.duplicate(true) as ClassDefinition
	blank_id_definition.id = &""
	(blank_class_id.party as PartyManager).members[0].class_definition = blank_id_definition
	TestAssertions.equal(_build(view_model, blank_class_id), null, "blank class ID fails closed", failures)
	_cleanup_fixture(blank_class_id)

	var blank_class_label := _two_member_fixture(5110)
	var blank_label_definition := (blank_class_label.party as PartyManager).members[0].class_definition.duplicate(true) as ClassDefinition
	blank_label_definition.display_name = ""
	(blank_class_label.party as PartyManager).members[0].character_name = ""
	(blank_class_label.party as PartyManager).members[0].class_definition = blank_label_definition
	TestAssertions.equal(_build(view_model, blank_class_label), null, "blank resolved member display fails closed", failures)
	_cleanup_fixture(blank_class_label)

	var missing_rank := _two_member_fixture(5111)
	(missing_rank.party as PartyManager).class_ranks.erase(&"fighter")
	TestAssertions.equal(_build(view_model, missing_rank), null, "missing authoritative class rank fails closed instead of clamping", failures)
	_cleanup_fixture(missing_rank)


func _test_boss_projection_uses_live_health_and_rejects_unavailable_bosses(failures: Array[String]) -> void:
	var view_model := _new_view_model(failures)
	if view_model == null:
		return
	var fixture := _two_member_fixture(5201)
	_health_by_member = {}
	var enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as EnemyActor
	enemy.configure(load("res://data/enemies/swarmer.tres") as EnemyDefinition)
	var health := enemy.get_node("HealthComponent") as HealthComponent
	health.current_health = health.max_health * 0.5
	var active_projection := _build(view_model, fixture, enemy)
	TestAssertions.equal(active_projection.boss_name, String(enemy.definition.id).capitalize(), "active EnemyActor derives the boss name from its authoritative ID", failures)
	TestAssertions.near(active_projection.boss_health, health.current_health, 0.001, "boss current health uses the live HealthComponent", failures)
	TestAssertions.near(active_projection.boss_max_health, health.max_health, 0.001, "boss maximum health uses the same live HealthComponent", failures)

	var null_projection := _build(view_model, fixture, null)
	TestAssertions.equal(null_projection.boss_name, "", "null boss is omitted", failures)
	var unsupported_boss := Node.new()
	var unsupported_projection := _build(view_model, fixture, unsupported_boss)
	TestAssertions.equal(unsupported_projection.boss_name, "", "unsupported boss node is omitted", failures)
	unsupported_boss.free()
	health.kill()
	var dead_projection := _build(view_model, fixture, enemy)
	TestAssertions.equal(dead_projection.boss_name, "", "dead boss is omitted", failures)
	enemy.free()

	var queued_enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as EnemyActor
	queued_enemy.configure(load("res://data/enemies/swarmer.tres") as EnemyDefinition)
	queued_enemy.queue_free()
	var queued_projection := _build(view_model, fixture, queued_enemy)
	TestAssertions.equal(queued_projection.boss_name, "", "queued boss is omitted before dereference", failures)
	queued_enemy.free()
	_cleanup_fixture(fixture)


func _test_ordered_party_revision_ignores_health_and_tracks_static_structure(failures: Array[String]) -> void:
	var fixture := _two_member_fixture(5301, 3)
	var party := fixture.party as PartyManager
	var context := fixture.context as PlayerRunContext
	var experience := fixture.experience as ExperienceSystem
	var catalog := GameCatalog.load_defaults()
	party.members[0].character_name = "Leader"
	var view_model := _new_view_model(failures)
	if view_model == null:
		_cleanup_fixture(fixture)
		return
	var initial_revision: String = String(view_model.call("ordered_party_revision", party))
	TestAssertions.equal(String(view_model.call("ordered_party_revision", party)), initial_revision, "repeated revision calls are deterministic", failures)
	_health_by_member = {1: {"current": 90.0, "max": 100.0, "downed": false, "dead": false}}
	var healthy_projection: CombatHudProjection = view_model.call("build", party, context, Callable(self, "_health_for"), experience, 0.0, null) as CombatHudProjection
	var health_before := _health_for(1)
	_health_by_member[1] = {"current": 10.0, "max": 100.0, "downed": false, "dead": false}
	var critical_projection: CombatHudProjection = view_model.call("build", party, context, Callable(self, "_health_for"), experience, 0.0, null) as CombatHudProjection
	TestAssertions.truthy(float((_health_for(1) as Dictionary)["current"]) != float((health_before as Dictionary)["current"]), "health fixture changes runtime values", failures)
	TestAssertions.truthy(healthy_projection.members[0].health != critical_projection.members[0].health, "health changes projection values", failures)
	TestAssertions.equal(String(view_model.call("ordered_party_revision", party)), initial_revision, "dynamic health does not change ordered party revision", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "revision fixture adds a member through PartyManager", failures)
	var added_member_revision: String = String(view_model.call("ordered_party_revision", party))
	TestAssertions.truthy(added_member_revision != initial_revision, "adding a member changes ordered party revision", failures)
	var first_member := party.members[0]
	party.members[0] = party.members[1]
	party.members[1] = first_member
	var reordered_revision: String = String(view_model.call("ordered_party_revision", party))
	TestAssertions.truthy(reordered_revision != added_member_revision, "explicit party reorder changes ordered party revision", failures)
	party.members[0].class_definition = catalog.class_by_id(&"cleric")
	var class_revision: String = String(view_model.call("ordered_party_revision", party))
	TestAssertions.truthy(class_revision != reordered_revision, "class identity changes ordered party revision", failures)
	TestAssertions.truthy(party.rank_up(&"fighter"), "revision fixture ranks up an existing class", failures)
	TestAssertions.truthy(String(view_model.call("ordered_party_revision", party)) != class_revision, "class rank changes ordered party revision", failures)
	_cleanup_fixture(fixture)


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


func _two_member_fixture(seed: int, capacity: int = 2) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(capacity))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	var context := PlayerRunContext.new()
	assert(context.configure(&"combat_hud_%d" % seed, 0, ProfileState.new_profile("profile-combat-hud-%d" % seed, "Combat HUD", 1000), seed, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	return {"party": party, "context": context, "experience": experience}


func _build(
	view_model: RefCounted,
	fixture: Dictionary,
	boss: Node = null,
	party_override: PartyManager = null,
	experience_override: ExperienceSystem = null,
) -> CombatHudProjection:
	var party := party_override if party_override != null else fixture.party as PartyManager
	var experience := experience_override if experience_override != null else fixture.experience as ExperienceSystem
	return view_model.call("build", party, fixture.context as PlayerRunContext, Callable(self, "_health_for"), experience, 125.0, boss) as CombatHudProjection


func _cleanup_fixture(fixture: Dictionary) -> void:
	var experience := fixture.get("experience") as ExperienceSystem
	if experience != null and is_instance_valid(experience):
		experience.free()
	var party := fixture.get("party") as PartyManager
	if party != null and is_instance_valid(party):
		party.free()


func _health_for(member_id: int) -> Dictionary:
	return (_health_by_member.get(member_id, {"current": 100.0, "max": 100.0, "downed": false, "dead": false}) as Dictionary).duplicate()


func _new_view_model(failures: Array[String]) -> RefCounted:
	var script := load("res://scripts/ui/hud/combat_hud_view_model.gd") as Script
	TestAssertions.truthy(script != null, "combat HUD view model script exists", failures)
	return script.new() as RefCounted if script != null else null
