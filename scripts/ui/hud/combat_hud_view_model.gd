class_name CombatHudViewModel
extends RefCounted

const CRITICAL_HEALTH_RATIO := 0.25


func build(
	party: PartyManager,
	context: PlayerRunContext,
	health_provider: Callable,
	experience: ExperienceSystem,
	elapsed_seconds: float,
	boss: Node,
) -> CombatHudProjection:
	var members: Array[PartyMemberHudProjection] = []
	var alerts: Array[CombatAlertProjection] = []
	var party_order: Dictionary = {}
	if party != null:
		for index: int in party.members.size():
			var member := party.members[index]
			if member == null or member.class_definition == null:
				continue
			party_order[member.member_id] = index
			var health := _health_for(member.member_id, health_provider)
			var level := _level_for(member.member_id, context)
			members.append(PartyMemberHudProjection.create(
				member.member_id,
				_display_name_for(member),
				member.class_definition.id,
				member.class_definition.display_name,
				level,
				maxi(1, party.get_class_rank(member.class_definition.id)),
				float(health["current"]),
				float(health["max"]),
				member.is_leader,
				bool(health["downed"]),
				bool(health["dead"]),
			))
			_append_health_alert(alerts, member, health)
	alerts.sort_custom(func(left: CombatAlertProjection, right: CombatAlertProjection) -> bool:
		return _alert_less(left, right, party_order)
	)
	var boss_values := _boss_values(boss)
	return CombatHudProjection.create(
		members,
		alerts,
		maxf(0.0, elapsed_seconds),
		experience.experience if experience != null else 0,
		experience.experience_for_next_level() if experience != null else 0,
		String(boss_values["name"]),
		float(boss_values["health"]),
		float(boss_values["max_health"]),
	)


func ordered_party_revision(party: PartyManager) -> String:
	var rows: Array[Dictionary] = []
	if party == null:
		return JSON.stringify(rows)
	for index: int in party.members.size():
		var member := party.members[index]
		if member == null:
			continue
		var definition := member.class_definition
		rows.append({
			"order": index,
			"member_id": member.member_id,
			"is_leader": member.is_leader,
			"character_name": member.character_name,
			"class_id": String(definition.id) if definition != null else "",
			"class_label": definition.display_name if definition != null else "",
			"class_rank": party.get_class_rank(definition.id) if definition != null else 0,
		})
	return JSON.stringify(rows)


func _health_for(member_id: int, health_provider: Callable) -> Dictionary:
	var value: Variant = health_provider.call(member_id) if health_provider.is_valid() else {}
	var source := value as Dictionary if value is Dictionary else {}
	var maximum := maxf(1.0, float(source.get("max", source.get("max_health", 1.0))))
	return {
		"current": clampf(float(source.get("current", maximum)), 0.0, maximum),
		"max": maximum,
		"downed": bool(source.get("downed", false)),
		"dead": bool(source.get("dead", false)),
	}


func _level_for(member_id: int, context: PlayerRunContext) -> int:
	var progression := context.progression_for(member_id) if context != null else null
	return maxi(1, progression.level) if progression != null else 1


func _display_name_for(member: PartyMemberState) -> String:
	return member.character_name if not member.character_name.strip_edges().is_empty() else member.class_definition.display_name


func _append_health_alert(alerts: Array[CombatAlertProjection], member: PartyMemberState, health: Dictionary) -> void:
	var display_name := _display_name_for(member)
	if bool(health["dead"]):
		alerts.append(CombatAlertProjection.create(
			StringName("dead:%03d" % member.member_id), member.member_id, &"downed_or_dying",
			"%s is dead" % display_name, "No longer active", CombatAlertProjection.Severity.DEAD, true, true,
		))
	elif bool(health["downed"]):
		alerts.append(CombatAlertProjection.create(
			StringName("downed:%03d" % member.member_id), member.member_id, &"downed_or_dying",
			"%s is downed" % display_name, "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true,
		))
	elif float(health["current"]) / float(health["max"]) <= CRITICAL_HEALTH_RATIO:
		alerts.append(CombatAlertProjection.create(
			StringName("critical:%03d" % member.member_id), member.member_id, &"critical_health",
			"%s is critical" % display_name, "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false,
		))


func _alert_less(left: CombatAlertProjection, right: CombatAlertProjection, party_order: Dictionary) -> bool:
	var left_priority := _alert_priority(left)
	var right_priority := _alert_priority(right)
	if left_priority != right_priority:
		return left_priority < right_priority
	var left_order := int(party_order.get(left.member_id, left.member_id))
	var right_order := int(party_order.get(right.member_id, right.member_id))
	if left_order != right_order:
		return left_order < right_order
	return String(left.stable_id) < String(right.stable_id)


func _alert_priority(alert: CombatAlertProjection) -> int:
	return 0 if alert.severity in [CombatAlertProjection.Severity.DEAD, CombatAlertProjection.Severity.DOWNED] else 1


func _boss_values(boss: Node) -> Dictionary:
	if boss is EnemyActor:
		var enemy := boss as EnemyActor
		if enemy.definition != null and not enemy.is_dead:
			return {
				"name": enemy.definition.display_name,
				"health": maxf(0.0, enemy.current_health),
				"max_health": maxf(1.0, enemy.definition.max_health),
			}
	return {"name": "", "health": 0.0, "max_health": 0.0}
