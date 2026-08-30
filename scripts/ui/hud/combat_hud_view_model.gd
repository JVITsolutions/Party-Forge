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
	var authorities := _runtime_authorities(party, context, health_provider, experience)
	if authorities.is_empty() or not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return null
	var health_by_member := authorities["health_by_member"] as Dictionary
	var level_by_member := authorities["level_by_member"] as Dictionary
	var rank_by_member := authorities["rank_by_member"] as Dictionary
	var members: Array[PartyMemberHudProjection] = []
	var alerts: Array[CombatAlertProjection] = []
	var party_order: Dictionary = {}
	if party != null:
		for index: int in party.members.size():
			var member := party.members[index]
			party_order[member.member_id] = index
			var health := health_by_member[member.member_id] as Dictionary
			var level := int(level_by_member[member.member_id])
			var member_projection := PartyMemberHudProjection.create(
				member.member_id,
				_display_name_for(member),
				member.class_definition.id,
				member.class_definition.display_name,
				level,
				int(rank_by_member[member.member_id]),
				float(health["current"]),
				float(health["max"]),
				member.is_leader,
				bool(health["downed"]),
				bool(health["dead"]),
			)
			if member_projection == null:
				return null
			members.append(member_projection)
			if not _append_health_alert(alerts, member, health):
				return null
	alerts.sort_custom(func(left: CombatAlertProjection, right: CombatAlertProjection) -> bool:
		return _alert_less(left, right, party_order)
	)
	var boss_values := _boss_values(boss)
	var projection := CombatHudProjection.create(
		members,
		alerts,
		elapsed_seconds,
		experience.experience,
		experience.experience_for_next_level(),
		String(boss_values["name"]),
		float(boss_values["health"]),
		float(boss_values["max_health"]),
	)
	return projection if projection != null and projection.validate().is_empty() else null


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


func _runtime_authorities(
	party: PartyManager,
	context: PlayerRunContext,
	health_provider: Callable,
	experience: ExperienceSystem,
) -> Dictionary:
	if (
		party == null
		or not is_instance_valid(party)
		or context == null
		or context.party != party
		or not health_provider.is_valid()
		or experience == null
		or not is_instance_valid(experience)
		or experience.run_context != context
	):
		return {}
	var health_by_member: Dictionary = {}
	var level_by_member: Dictionary = {}
	var rank_by_member: Dictionary = {}
	var member_ids: Dictionary = {}
	var leader_member_id := 0
	for member: PartyMemberState in party.members:
		if member == null or member.class_definition == null or member.member_id <= 0 or member_ids.has(member.member_id):
			return {}
		if (
			member.class_definition.id.is_empty()
			or member.class_definition.display_name.strip_edges().is_empty()
			or _display_name_for(member).strip_edges().is_empty()
		):
			return {}
		var class_rank := party.get_class_rank(member.class_definition.id)
		if class_rank <= 0:
			return {}
		member_ids[member.member_id] = true
		if member.is_leader:
			if leader_member_id != 0:
				return {}
			leader_member_id = member.member_id
		var progression := context.progression_for(member.member_id)
		if progression == null or progression.member_id != member.member_id or progression.level <= 0:
			return {}
		var health := _validated_health_for(member.member_id, health_provider)
		if health.is_empty():
			return {}
		health_by_member[member.member_id] = health
		level_by_member[member.member_id] = progression.level
		rank_by_member[member.member_id] = class_rank
	if leader_member_id == 0 or experience.leader_member_id != leader_member_id:
		return {}
	var leader_progression := context.progression_for(leader_member_id)
	if (
		leader_progression == null
		or experience.experience != leader_progression.experience
		or experience.experience_for_next_level() != leader_progression.experience_required
	):
		return {}
	return {
		"health_by_member": health_by_member,
		"level_by_member": level_by_member,
		"rank_by_member": rank_by_member,
	}


func _validated_health_for(member_id: int, health_provider: Callable) -> Dictionary:
	var value: Variant = health_provider.call(member_id)
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	for key: String in ["current", "max", "downed", "dead"]:
		if not source.has(key):
			return {}
	if (
		not _is_finite_number(source["current"])
		or not _is_finite_number(source["max"])
		or typeof(source["downed"]) != TYPE_BOOL
		or typeof(source["dead"]) != TYPE_BOOL
	):
		return {}
	var current := float(source["current"])
	var maximum := float(source["max"])
	if maximum <= 0.0 or current < 0.0 or current > maximum or (bool(source["downed"]) and bool(source["dead"])):
		return {}
	return {
		"current": current,
		"max": maximum,
		"downed": bool(source["downed"]),
		"dead": bool(source["dead"]),
	}


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _display_name_for(member: PartyMemberState) -> String:
	return member.character_name if not member.character_name.strip_edges().is_empty() else member.class_definition.display_name


func _append_health_alert(alerts: Array[CombatAlertProjection], member: PartyMemberState, health: Dictionary) -> bool:
	var display_name := _display_name_for(member)
	var alert: CombatAlertProjection = null
	if bool(health["dead"]):
		alert = CombatAlertProjection.create(
			StringName("dead:%03d" % member.member_id), member.member_id, &"downed_or_dying",
			"%s is dead" % display_name, "No longer active", CombatAlertProjection.Severity.DEAD, true, true,
		)
	elif bool(health["downed"]):
		alert = CombatAlertProjection.create(
			StringName("downed:%03d" % member.member_id), member.member_id, &"downed_or_dying",
			"%s is downed" % display_name, "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true,
		)
	elif float(health["current"]) / float(health["max"]) <= CRITICAL_HEALTH_RATIO:
		alert = CombatAlertProjection.create(
			StringName("critical:%03d" % member.member_id), member.member_id, &"critical_health",
			"%s is critical" % display_name, "Health is low", CombatAlertProjection.Severity.CRITICAL, true, false,
		)
	if alert == null:
		return not bool(health["dead"]) and not bool(health["downed"]) and float(health["current"]) / float(health["max"]) > CRITICAL_HEALTH_RATIO
	alerts.append(alert)
	return true


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
	if boss == null or not is_instance_valid(boss) or boss.is_queued_for_deletion() or not boss is EnemyActor:
		return {"name": "", "health": 0.0, "max_health": 0.0}
	var enemy := boss as EnemyActor
	if enemy.definition == null:
		return {"name": "", "health": 0.0, "max_health": 0.0}
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if (
		health == null
		or not is_instance_valid(health)
		or health.is_queued_for_deletion()
		or health.is_dead
		or not is_finite(health.current_health)
		or not is_finite(health.max_health)
		or health.max_health <= 0.0
		or health.current_health < 0.0
		or health.current_health > health.max_health
	):
		return {"name": "", "health": 0.0, "max_health": 0.0}
	return {
		"name": String(enemy.definition.id).capitalize(),
		"health": health.current_health,
		"max_health": health.max_health,
	}
