class_name RewardDistributionService
extends RefCounted

var registry: RunContextRegistry
var tuning: RewardDistributionTuning
var _resolved_pairs: Dictionary = {}

func configure(context_registry: RunContextRegistry, distribution_tuning: RewardDistributionTuning) -> PackedStringArray:
	var errors := PackedStringArray()
	if context_registry == null:
		errors.append("PARTY_FORGE_REWARD_ERROR field=registry")
	if distribution_tuning == null:
		errors.append("PARTY_FORGE_REWARD_ERROR field=tuning")
	elif not distribution_tuning.validate().is_empty():
		errors.append_array(distribution_tuning.validate())
	if errors.is_empty():
		registry = context_registry
		tuning = distribution_tuning
		_resolved_pairs.clear()
	return errors

func distribute(packet: RewardPacket) -> Dictionary:
	var report := {
		"awarded_members": PackedStringArray(),
		"skipped_contexts": PackedStringArray(),
		"errors": PackedStringArray(),
	}
	if registry == null or tuning == null or packet == null or not packet.validate().is_empty():
		_append_report_value(report, "errors", "PARTY_FORGE_REWARD_ERROR reason=invalid distribution request")
		return report
	for context: PlayerRunContext in registry.all_contexts():
		var pair_key := "%s|%s" % [packet.packet_id, context.run_player_id]
		if _resolved_pairs.has(pair_key):
			continue
		_resolved_pairs[pair_key] = true
		var leader_id := context.party.members[0].member_id if context.party != null and not context.party.members.is_empty() else 0
		var leader_position := context.member_position(leader_id)
		if not context.member_is_available(leader_id) or not bool(leader_position.get("valid", false)):
			_append_report_value(report, "skipped_contexts", String(context.run_player_id))
			continue
		var leader_world_position := leader_position.position as Vector3
		if leader_world_position.distance_to(packet.world_position) > tuning.leader_event_share_radius:
			_append_report_value(report, "skipped_contexts", String(context.run_player_id))
			continue
		_award(context, leader_id, packet, report)
		for member: PartyMemberState in context.party.members:
			if member.is_leader or not context.member_is_available(member.member_id):
				continue
			var follower_position := context.member_position(member.member_id)
			if bool(follower_position.get("valid", false)) and (follower_position.position as Vector3).distance_to(leader_world_position) <= tuning.follower_squad_link_radius:
				_award(context, member.member_id, packet, report)
	return report

func has_resolved(packet_id: StringName, run_player_id: StringName) -> bool:
	return _resolved_pairs.has("%s|%s" % [packet_id, run_player_id])

func _award(context: PlayerRunContext, member_id: int, packet: RewardPacket, report: Dictionary) -> void:
	var award := context.award_experience(member_id, packet.experience)
	if award.ok():
		_append_report_value(report, "awarded_members", "%s:%d" % [context.run_player_id, member_id])
	else:
		_append_report_value(report, "errors", award.error)

func _append_report_value(report: Dictionary, key: String, value: String) -> void:
	var values := report.get(key, PackedStringArray()) as PackedStringArray
	values.append(value)
	report[key] = values
