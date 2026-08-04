class_name CharacterProgressionService
extends RefCounted

static func preview_award(
	current: CharacterProgressionState,
	growth: ClassGrowthDefinition,
	tuning: ExperienceTuning,
	base_amount: int,
	multiplier_percent: int,
	run_seed: int,
	run_player_id: StringName,
	member_id: int,
) -> CharacterProgressionAward:
	if current == null:
		return CharacterProgressionAward.failure("null current state")
	if member_id <= 0 or current.member_id != member_id:
		return CharacterProgressionAward.failure("member mismatch")
	if tuning == null or not tuning.validate().is_empty():
		return CharacterProgressionAward.failure("invalid experience tuning")
	if growth == null or not growth.validate().is_empty():
		return CharacterProgressionAward.failure("invalid class growth")

	var award := CharacterProgressionAward.new()
	var next := current.copy()
	var scaled := float(maxi(base_amount, 0)) * float(clampi(multiplier_percent, 100, 1000)) / 100.0 + next.fractional_experience
	var whole := floori(scaled)
	next.fractional_experience = scaled - float(whole)
	next.experience += whole
	while next.experience >= tuning.requirement_for_level(next.level):
		next.experience -= tuning.requirement_for_level(next.level)
		next.level += 1
		next.experience_required = tuning.requirement_for_level(next.level)
		award.gained_levels.append(next.level)
		var guaranteed := growth.guaranteed_attribute_for_level(next.level)
		_increment_attribute(next, award, guaranteed)
		next.guaranteed_growth_history.append(guaranteed)
		if next.level % 5 == 0:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%d|%s|%d|%d" % [run_seed, run_player_id, member_id, next.level])
			var milestone := growth.milestone_attribute_for_roll(rng.randf())
			_increment_attribute(next, award, milestone)
			next.milestone_outcomes[next.level] = milestone
			award.milestone_outcomes[next.level] = milestone
	award.next_state = next
	return award

static func source_for(member_id: int, state: CharacterProgressionState) -> StatModifierSource:
	if state == null or member_id <= 0 or state.member_id != member_id:
		return null
	var source_id := StringName("character_growth_%d" % member_id)
	var modifiers: Array[StatModifier] = []
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		modifiers.append(StatModifier.create(
			attribute_id,
			StatModifier.Operation.FLAT,
			float(state.core_attribute_gains.get(attribute_id, 0)),
			source_id,
			"Class Growth",
		))
	return StatModifierSource.create(source_id, &"character_growth", "Class Growth", member_id, modifiers)

static func _increment_attribute(state: CharacterProgressionState, award: CharacterProgressionAward, attribute_id: StringName) -> void:
	state.core_attribute_gains[attribute_id] = int(state.core_attribute_gains.get(attribute_id, 0)) + 1
	award.attribute_delta[attribute_id] = int(award.attribute_delta.get(attribute_id, 0)) + 1
