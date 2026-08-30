extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_copy_owned_members_and_alerts(failures)
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
