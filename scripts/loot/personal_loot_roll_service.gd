class_name PersonalLootRollService
extends RefCounted

const GENERATION_SEED_HEX_CHARACTERS := 13

var registry: RunContextRegistry
var reward_tuning: RewardDistributionTuning
var loot_tuning: PersonalLootTuning
var feature_access_provider: Callable
var force_success := false
var drop_multiplier := 1.0
var source_category_override: StringName = &""
var item_level_override := 0
var difficulty_id: StringName = &"normal"
var heat := 0.0

var _resolved_decisions: Dictionary = {}

func configure(
	context_registry: RunContextRegistry,
	distribution_tuning: RewardDistributionTuning,
	personal_tuning: PersonalLootTuning,
	access_provider: Callable,
	force_success_value: bool = false,
	drop_multiplier_value: float = 1.0,
	source_category_override_value: StringName = &"",
	item_level_override_value: int = 0,
	difficulty_id_value: StringName = &"normal",
	heat_value: float = 0.0,
) -> PackedStringArray:
	_clear_configuration()
	var errors := PackedStringArray()
	if context_registry == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=registry")
	if distribution_tuning == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=reward_tuning")
	else:
		errors.append_array(distribution_tuning.validate())
	if personal_tuning == null:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=loot_tuning")
	else:
		var tuning_errors := personal_tuning.validate()
		errors.append_array(tuning_errors)
		if tuning_errors.is_empty() and not personal_tuning.supports_difficulty(difficulty_id_value):
			errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=difficulty_id reason=unsupported difficulty %s" % difficulty_id_value)
	if not is_finite(heat_value) or heat_value < 0.0:
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=heat reason=must be finite and nonnegative")
	if not access_provider.is_valid():
		errors.append("PARTY_FORGE_PERSONAL_LOOT_ERROR field=feature_access_provider")
	if errors.is_empty():
		registry = context_registry
		reward_tuning = distribution_tuning
		loot_tuning = personal_tuning
		feature_access_provider = access_provider
		force_success = force_success_value
		drop_multiplier = clampf(drop_multiplier_value if is_finite(drop_multiplier_value) else 0.0, 0.0, 100.0)
		source_category_override = source_category_override_value if source_category_override_value in EnemyDefeatEvent.SOURCE_CATEGORIES else &""
		item_level_override = clampi(item_level_override_value, 0, ItemGenerationRequest.MAX_ITEM_LEVEL)
		difficulty_id = difficulty_id_value
		heat = heat_value
		_resolved_decisions.clear()
	return errors

func resolve(
	event: EnemyDefeatEvent,
	force_success_override: bool = false,
	drop_multiplier_override: float = NAN,
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
			var effective_force := force_success or force_success_override
			var effective_multiplier := drop_multiplier if is_nan(drop_multiplier_override) else drop_multiplier_override
			resolved = _resolve_context(context, event, effective_force, effective_multiplier)
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
	var effective_source := source_category_override if not source_category_override.is_empty() else event.source_category
	decision.source_category = effective_source
	var base_basis_points := int(loot_tuning.drop_basis_points.get(effective_source, 0))
	var normalized_multiplier := drop_multiplier if is_finite(drop_multiplier) else 0.0
	normalized_multiplier = clampf(normalized_multiplier, 0.0, 10000.0)
	decision.basis_points = clampi(roundi(float(base_basis_points) * normalized_multiplier), 0, 10000)
	var player_stage := StringName("personal_drop:%s" % context.run_player_id)
	decision.roll_basis_points = floori(
		ItemDeterministicRandom.unit(event.run_seed, event.defeat_sequence, player_stage, 0) * 10000.0
	)
	decision.generation_seed = _generation_seed(event, context.run_player_id)
	decision.generation_sequence = event.defeat_sequence
	var item_level_event := event
	if effective_source != event.source_category:
		item_level_event = EnemyDefeatEvent.create(event.run_seed, event.defeat_sequence, event.enemy_sequence, event.enemy_id, effective_source, event.world_position, event.encounter_seconds)
	decision.item_level = item_level_override if item_level_override > 0 else EncounterItemLevelPolicy.resolve(item_level_event, difficulty_id, heat, loot_tuning)

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

func _clear_configuration() -> void:
	registry = null
	reward_tuning = null
	loot_tuning = null
	feature_access_provider = Callable()
	_resolved_decisions.clear()
