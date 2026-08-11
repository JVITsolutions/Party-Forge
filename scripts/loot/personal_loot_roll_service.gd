class_name PersonalLootRollService
extends RefCounted

const GENERATION_SEED_HEX_CHARACTERS := 15

var registry: RunContextRegistry
var reward_tuning: RewardDistributionTuning
var loot_tuning: PersonalLootTuning
var feature_access_provider: Callable

var _resolved_decisions: Dictionary = {}

func configure(
	context_registry: RunContextRegistry,
	distribution_tuning: RewardDistributionTuning,
	personal_tuning: PersonalLootTuning,
	access_provider: Callable,
) -> PackedStringArray:
	var errors := PackedStringArray()
	if context_registry == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=registry")
	if distribution_tuning == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=reward_tuning")
	else:
		errors.append_array(distribution_tuning.validate())
	if personal_tuning == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=loot_tuning")
	if not access_provider.is_valid():
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=feature_access_provider")
	if errors.is_empty():
		registry = context_registry
		reward_tuning = distribution_tuning
		loot_tuning = personal_tuning
		feature_access_provider = access_provider
		_resolved_decisions.clear()
	return errors

func resolve(
	event: EnemyDefeatEvent,
	force_success: bool = false,
	drop_multiplier: float = 1.0,
) -> Array[PersonalLootDecision]:
	var decisions: Array[PersonalLootDecision] = []
	if not _is_configured() or event == null or not event.validate().is_empty():
		return decisions
	var contexts := registry.all_contexts()
	contexts.sort_custom(func(left: PlayerRunContext, right: PlayerRunContext) -> bool:
		if left.player_slot_index == right.player_slot_index:
			return String(left.run_player_id) < String(right.run_player_id)
		return left.player_slot_index < right.player_slot_index
	)
	for context: PlayerRunContext in contexts:
		var replay_key := "%d|%s" % [event.defeat_sequence, context.run_player_id]
		var resolved := _resolved_decisions.get(replay_key) as PersonalLootDecision
		if resolved == null:
			resolved = _resolve_context(context, event, force_success, drop_multiplier)
			_resolved_decisions[replay_key] = resolved.copy()
		decisions.append(resolved.copy())
	return decisions

func _resolve_context(
	context: PlayerRunContext,
	event: EnemyDefeatEvent,
	force_success: bool,
	drop_multiplier: float,
) -> PersonalLootDecision:
	var decision := PersonalLootDecision.new()
	_copy_identity_and_event_facts(decision, context, event)
	var base_basis_points := int(loot_tuning.drop_basis_points.get(event.source_category, 0))
	var normalized_multiplier := drop_multiplier if is_finite(drop_multiplier) else 0.0
	normalized_multiplier = clampf(normalized_multiplier, 0.0, 10000.0)
	decision.basis_points = clampi(roundi(float(base_basis_points) * normalized_multiplier), 0, 10000)
	var player_stage := StringName("personal_drop:%s" % context.run_player_id)
	decision.roll_basis_points = floori(
		ItemDeterministicRandom.unit(event.run_seed, event.defeat_sequence, player_stage, 0) * 10000.0
	)
	decision.generation_seed = _generation_seed(event, context.run_player_id)
	decision.generation_sequence = event.defeat_sequence
	decision.item_level = EncounterItemLevelPolicy.resolve(event, &"normal", 0.0, loot_tuning)

	decision.eligible = _resolve_eligibility(context, event, decision)
	decision.success = decision.eligible and (
		force_success or decision.roll_basis_points < decision.basis_points
	)
	if not decision.eligible:
		return decision
	if force_success:
		decision.reason = &"forced_success"
	elif decision.basis_points == 0:
		decision.reason = &"no_drop_chance"
	elif decision.success:
		decision.reason = &"roll_succeeded"
	else:
		decision.reason = &"roll_failed"
	return decision

func _resolve_eligibility(
	context: PlayerRunContext,
	event: EnemyDefeatEvent,
	decision: PersonalLootDecision,
) -> bool:
	if not bool(feature_access_provider.call(context)):
		decision.reason = &"feature_locked"
		return false
	var leader_id := _leader_member_id(context)
	if leader_id <= 0 or not context.member_is_available(leader_id):
		decision.reason = &"leader_unavailable"
		return false
	var leader_position := context.member_position(leader_id)
	if not bool(leader_position.get("valid", false)):
		decision.reason = &"leader_unavailable"
		return false
	var world_position := leader_position.get("position", Vector3.ZERO) as Vector3
	if world_position.distance_to(event.world_position) > reward_tuning.leader_event_share_radius:
		decision.reason = &"leader_out_of_range"
		return false
	return true

func _leader_member_id(context: PlayerRunContext) -> int:
	if context.party == null:
		return 0
	for member: PartyMemberState in context.party.members:
		if member != null and member.is_leader:
			return member.member_id
	return 0

func _copy_identity_and_event_facts(
	decision: PersonalLootDecision,
	context: PlayerRunContext,
	event: EnemyDefeatEvent,
) -> void:
	decision.run_player_id = context.run_player_id
	decision.profile_id = context.profile_id
	decision.player_slot = context.player_slot_index
	decision.run_seed = event.run_seed
	decision.defeat_sequence = event.defeat_sequence
	decision.enemy_sequence = event.enemy_sequence
	decision.enemy_id = event.enemy_id
	decision.source_category = event.source_category
	decision.world_position = event.world_position
	decision.encounter_seconds = event.encounter_seconds

func _generation_seed(event: EnemyDefeatEvent, run_player_id: StringName) -> int:
	var digest := ("%d|%d|%s|item" % [
		event.run_seed,
		event.defeat_sequence,
		run_player_id,
	]).sha256_text()
	return maxi(digest.substr(0, GENERATION_SEED_HEX_CHARACTERS).hex_to_int(), 1)

func _is_configured() -> bool:
	return (
		registry != null
		and reward_tuning != null
		and loot_tuning != null
		and feature_access_provider.is_valid()
	)
