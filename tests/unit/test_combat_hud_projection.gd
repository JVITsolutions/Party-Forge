extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_copy_owned_members_and_alerts(failures)
	var summary_probe := CombatHudProjection.create([], [], 0.0, 0, 0, "", 0.0, 0.0)
	if _summary_accessors_exist(summary_probe, failures):
		_test_projection_summary_accessors(failures)
		_test_alert_count_summary_accessor(failures)
		_test_highest_alert_severity_summary_accessor(failures)
		_test_highest_severity_alert_summary_accessor(failures)
	_test_projection_validation(failures)
	return failures


func _test_copy_owned_members_and_alerts(failures: Array[String]) -> void:
	var members: Array[PartyMemberHudProjection] = []
	for member_id: int in range(1, 25):
		members.append(PartyMemberHudProjection.create(member_id, "Member %d" % member_id, &"fighter", "Fighter", member_id, 1, 50.0, 100.0, member_id == 1, false, false))
	var alerts: Array[CombatAlertProjection] = [
		CombatAlertProjection.create(&"dead:003", 3, &"downed_or_dying", "Member 3 is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
		CombatAlertProjection.create(&"critical:001", 1, &"critical_health", "Member 1 is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"downed:004", 4, &"downed_or_dying", "Member 4 is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		CombatAlertProjection.create(&"critical:005", 5, &"critical_health", "Member 5 is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false),
	]
	var projection := CombatHudProjection.create(members, alerts, 61.0, 4, 10, "", 0.0, 0.0)
	TestAssertions.equal(projection.members.size(), 24, "all twenty-four members are retained", failures)
	TestAssertions.equal(projection.all_alerts.size(), 4, "complete ordered alert set is retained", failures)
	TestAssertions.equal(projection.visible_alerts.map(func(alert: CombatAlertProjection) -> StringName: return alert.stable_id), [&"dead:003", &"critical:001", &"downed:004"], "visible alerts are exactly the first three", failures)
	TestAssertions.equal(projection.overflow_alert_count, 1, "overflow count is derived from the complete alert set", failures)
	var copied := projection.copy()
	copied.members[0].display_name = "Changed"
	copied.all_alerts[0].summary = "Changed"
	TestAssertions.equal(projection.members[0].display_name, "Member 1", "copy owns nested members", failures)
	TestAssertions.equal(projection.all_alerts[0].summary, "Member 3 is dead", "copy owns nested alerts", failures)
	TestAssertions.equal(projection.validate(), PackedStringArray(), "valid projection has no errors", failures)


func _test_projection_summary_accessors(failures: Array[String]) -> void:
	var leader_member := PartyMemberHudProjection.create(1, "Mira", &"fighter", "Fighter", 4, 1, 72.0, 100.0, true, false, false)
	var follower_member := PartyMemberHudProjection.create(2, "Rowan", &"ranger", "Ranger", 3, 1, 40.0, 100.0, false, false, false)
	var alerts: Array[CombatAlertProjection] = [
		CombatAlertProjection.create(&"critical:001", 1, &"critical_health", "Mira is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"critical:002", 2, &"critical_health", "Rowan is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false),
		CombatAlertProjection.create(&"downed:003", 2, &"downed_or_dying", "Rowan is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		CombatAlertProjection.create(&"dead:004", 2, &"downed_or_dying", "Rowan is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
	]
	var projection := CombatHudProjection.create([leader_member, follower_member], alerts, 0.0, 0, 0, "", 0.0, 0.0)
	if not _summary_accessors_exist(projection, failures):
		return
	var leader: PartyMemberHudProjection = projection.leader()
	TestAssertions.equal([leader.member_id, leader.display_name, leader.health, leader.max_health], [1, "Mira", 72.0, 100.0], "summary exposes defensive leader truth", failures)
	TestAssertions.equal([
		projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL),
		projection.alert_count_for(CombatAlertProjection.Severity.DOWNED),
		projection.alert_count_for(CombatAlertProjection.Severity.DEAD),
	], [2, 1, 1], "summary counts every exact severity", failures)
	TestAssertions.equal(projection.highest_alert_severity(), CombatAlertProjection.Severity.DEAD, "dead outranks downed and critical", failures)
	TestAssertions.equal(projection.highest_severity_alert().stable_id, &"dead:004", "highest summary selects the first exact highest-severity alert", failures)
	leader.display_name = "mutated"
	TestAssertions.equal(projection.leader().display_name, "Mira", "leader accessor returns a defensive copy", failures)
	var highest_alert: CombatAlertProjection = projection.highest_severity_alert()
	highest_alert.summary = "mutated"
	TestAssertions.equal(projection.highest_severity_alert().summary, "Rowan is dead", "highest alert accessor returns a defensive copy", failures)

	var empty_alert_projection := CombatHudProjection.create([leader_member], [], 0.0, 0, 0, "", 0.0, 0.0)
	TestAssertions.equal(empty_alert_projection.highest_alert_severity(), -1, "empty alerts expose no severity", failures)
	TestAssertions.equal(empty_alert_projection.highest_severity_alert(), null, "empty alerts expose no highest alert", failures)
	TestAssertions.equal([
		empty_alert_projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL),
		empty_alert_projection.alert_count_for(CombatAlertProjection.Severity.DOWNED),
		empty_alert_projection.alert_count_for(CombatAlertProjection.Severity.DEAD),
	], [0, 0, 0], "empty alerts have zero counts", failures)


func _test_alert_count_summary_accessor(failures: Array[String]) -> void:
	var projection := CombatHudProjection.create([], [], 0.0, 0, 0, "", 0.0, 0.0)
	if not _summary_accessors_exist(projection, failures):
		return
	TestAssertions.equal(projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL), 0, "summary count accessor handles an empty alert set", failures)


func _test_highest_alert_severity_summary_accessor(failures: Array[String]) -> void:
	var projection := CombatHudProjection.create([], [], 0.0, 0, 0, "", 0.0, 0.0)
	if not _summary_accessors_exist(projection, failures):
		return
	TestAssertions.equal(projection.highest_alert_severity(), -1, "summary severity accessor handles an empty alert set", failures)


func _test_highest_severity_alert_summary_accessor(failures: Array[String]) -> void:
	var projection := CombatHudProjection.create([], [], 0.0, 0, 0, "", 0.0, 0.0)
	if not _summary_accessors_exist(projection, failures):
		return
	TestAssertions.equal(projection.highest_severity_alert(), null, "summary alert accessor handles an empty alert set", failures)


func _summary_accessors_exist(projection: CombatHudProjection, failures: Array[String]) -> bool:
	var all_present := true
	for method_name: StringName in [&"leader", &"alert_count_for", &"highest_alert_severity", &"highest_severity_alert"]:
		var present := projection.has_method(method_name)
		TestAssertions.truthy(present, "projection exposes summary accessor %s" % method_name, failures)
		all_present = all_present and present
	return all_present


func _test_projection_validation(failures: Array[String]) -> void:
	var valid_member := PartyMemberHudProjection.create(1, "Member 1", &"fighter", "Fighter", 1, 1, 50.0, 100.0, true, false, false)
	var second_member := PartyMemberHudProjection.create(2, "Member 2", &"fighter", "Fighter", 1, 1, 50.0, 100.0, false, false, false)
	var valid_alert := CombatAlertProjection.create(&"critical:001", 1, &"critical_health", "Member 1 is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false)
	TestAssertions.truthy(PartyMemberHudProjection.create(0, "Member 0", &"fighter", "Fighter", 1, 1, 50.0, 100.0, false, false, false) == null, "non-positive member identifiers are rejected", failures)
	TestAssertions.truthy(PartyMemberHudProjection.create(3, "Member 3", &"fighter", "Fighter", 1, 1, -1.0, 100.0, false, false, false) == null, "negative health is rejected", failures)
	TestAssertions.truthy(PartyMemberHudProjection.create(3, "Member 3", &"fighter", "Fighter", 1, 1, 101.0, 100.0, false, false, false) == null, "health over the maximum is rejected", failures)
	TestAssertions.truthy(PartyMemberHudProjection.create(3, "Member 3", &"fighter", "Fighter", 1, 1, 0.0, 0.0, false, false, false) == null, "non-positive maximum health is rejected", failures)

	var duplicate_members: Array[PartyMemberHudProjection] = [valid_member, PartyMemberHudProjection.create(1, "Member 1B", &"fighter", "Fighter", 1, 1, 50.0, 100.0, false, false, false)]
	var duplicate_member_projection := CombatHudProjection.create(duplicate_members, [], 0.0, 0, 0, "", 0.0, 0.0)
	TestAssertions.truthy(_has_error(duplicate_member_projection.validate(), "duplicate member_id"), "duplicate member identifiers are rejected", failures)

	var duplicate_alerts: Array[CombatAlertProjection] = [valid_alert, CombatAlertProjection.create(&"critical:001", 2, &"critical_health", "Member 2 is critical", "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false)]
	var duplicate_alert_projection := CombatHudProjection.create([valid_member, second_member], duplicate_alerts, 0.0, 0, 0, "", 0.0, 0.0)
	TestAssertions.truthy(_has_error(duplicate_alert_projection.validate(), "duplicate alert stable_id"), "duplicate alert identifiers are rejected across the complete alert set", failures)

	var invalid_xp := CombatHudProjection.create([valid_member], [], -1.0, 11, 10, "", 0.0, 0.0)
	TestAssertions.truthy(_has_error(invalid_xp.validate(), "experience"), "invalid elapsed and experience ranges are rejected", failures)
	var invalid_boss := CombatHudProjection.create([valid_member], [], 0.0, 0, 0, "Forge Guardian", 101.0, 100.0)
	TestAssertions.truthy(_has_error(invalid_boss.validate(), "boss_health"), "invalid boss health ranges are rejected", failures)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
