extends RefCounted

const FIGHTER_PATH := "res://data/progression/class_growth/fighter.tres"
const TUNING_PATH := "res://data/progression/default_experience.tres"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_thresholds_growth_and_copy_ownership(failures)
	_test_fractional_carry_and_nonpositive_no_op(failures)
	_test_milestone_determinism(failures)
	_test_invalid_growth_fails_without_state(failures)
	_test_cumulative_source(failures)
	_test_snapshot_round_trip_and_rejections(failures)
	return failures

func _test_thresholds_growth_and_copy_ownership(failures: Array[String]) -> void:
	var fighter := load(FIGHTER_PATH) as ClassGrowthDefinition
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var initial := CharacterProgressionState.fresh(1, tuning)
	var award := CharacterProgressionService.preview_award(initial, fighter, tuning, 94, 100, 1337, &"player_one", 1)
	TestAssertions.truthy(award.ok(), "valid XP award succeeds", failures)
	TestAssertions.equal(initial.level, 1, "preview does not mutate input", failures)
	TestAssertions.equal(award.next_state.level, 4, "94 XP reaches level four", failures)
	TestAssertions.equal(award.next_state.experience, 0, "exact multi-level thresholds preserve zero overflow", failures)
	TestAssertions.equal(award.gained_levels, [2, 3, 4], "all earned levels are ordered", failures)
	TestAssertions.equal(award.next_state.experience_required, 62, "next requirement is stored for level four", failures)
	TestAssertions.equal(award.next_state.core_attribute_gains[&"strength"], 2, "fighter gains strength at levels two and four", failures)
	TestAssertions.equal(award.next_state.core_attribute_gains[&"constitution"], 1, "fighter gains constitution at level three", failures)
	award.next_state.core_attribute_gains[&"strength"] = 99
	award.next_state.guaranteed_growth_history.append(&"charisma")
	TestAssertions.equal(initial.core_attribute_gains[&"strength"], 0, "next-state attributes are copy owned", failures)
	TestAssertions.equal(initial.guaranteed_growth_history, [], "next-state history is copy owned", failures)

func _test_fractional_carry_and_nonpositive_no_op(failures: Array[String]) -> void:
	var fighter := load(FIGHTER_PATH) as ClassGrowthDefinition
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var initial := CharacterProgressionState.fresh(1, tuning)
	var first := CharacterProgressionService.preview_award(initial, fighter, tuning, 1, 150, 1337, &"player_one", 1)
	TestAssertions.equal(first.next_state.experience, 1, "150 percent grants one whole XP first", failures)
	TestAssertions.near(first.next_state.fractional_experience, 0.5, 0.001, "150 percent stores fractional carry", failures)
	var second := CharacterProgressionService.preview_award(first.next_state, fighter, tuning, 1, 150, 1337, &"player_one", 1)
	TestAssertions.equal(second.next_state.experience, 3, "second award consumes fractional carry", failures)
	TestAssertions.near(second.next_state.fractional_experience, 0.0, 0.001, "consumed carry returns to zero", failures)

	for base_amount: int in [-10, 0]:
		var no_op := CharacterProgressionService.preview_award(initial, fighter, tuning, base_amount, 100, 1337, &"player_one", 1)
		TestAssertions.truthy(no_op.ok(), "nonpositive XP %d succeeds" % base_amount, failures)
		TestAssertions.truthy(no_op.next_state != initial, "nonpositive XP %d still returns a copy" % base_amount, failures)
		TestAssertions.equal(no_op.next_state.to_snapshot(), initial.to_snapshot(), "nonpositive XP %d is a no-op" % base_amount, failures)
		TestAssertions.equal(no_op.gained_levels, [], "nonpositive XP %d gains no levels" % base_amount, failures)

func _test_milestone_determinism(failures: Array[String]) -> void:
	var fighter := load(FIGHTER_PATH) as ClassGrowthDefinition
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var initial := CharacterProgressionState.fresh(1, tuning)
	var first := CharacterProgressionService.preview_award(initial, fighter, tuning, 156, 100, 1337, &"player_one", 1)
	TestAssertions.equal(first.next_state.level, 5, "level five threshold is reached", failures)
	TestAssertions.equal(first.milestone_outcomes.size(), 1, "level five creates one milestone", failures)
	TestAssertions.truthy(first.milestone_outcomes.has(5), "level five milestone is keyed by level", failures)
	var repeat := CharacterProgressionService.preview_award(initial, fighter, tuning, 156, 100, 1337, &"player_one", 1)
	TestAssertions.equal(repeat.milestone_outcomes, first.milestone_outcomes, "identical stable identity reproduces milestone", failures)

	CharacterProgressionService.preview_award(CharacterProgressionState.fresh(2, tuning), fighter, tuning, 100000, 100, 90210, &"other_player", 2)
	var after_other := CharacterProgressionService.preview_award(initial, fighter, tuning, 156, 100, 1337, &"player_one", 1)
	TestAssertions.equal(after_other.milestone_outcomes, first.milestone_outcomes, "other context and member cannot perturb deterministic outcome", failures)

	var long_a := CharacterProgressionService.preview_award(initial, fighter, tuning, 100000, 100, 1337, &"player_one", 1)
	var long_b := CharacterProgressionService.preview_award(initial, fighter, tuning, 100000, 100, 1337, &"player_two", 1)
	TestAssertions.truthy(long_a.milestone_outcomes != long_b.milestone_outcomes, "changed stable identity changes milestone stream", failures)

func _test_invalid_growth_fails_without_state(failures: Array[String]) -> void:
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var invalid_growth := ClassGrowthDefinition.new()
	invalid_growth.guaranteed_cycle = [&"damage"]
	invalid_growth.milestone_weights = {&"strength": 0.0}
	var failed := CharacterProgressionService.preview_award(
		CharacterProgressionState.fresh(1, tuning), invalid_growth, tuning, 20, 100, 1337, &"player_one", 1,
	)
	TestAssertions.truthy(not failed.ok(), "invalid growth fails", failures)
	TestAssertions.equal(failed.next_state, null, "invalid growth has no next state", failures)
	TestAssertions.truthy(not failed.error.is_empty(), "invalid growth returns an error", failures)

func _test_cumulative_source(failures: Array[String]) -> void:
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var state := CharacterProgressionState.fresh(7, tuning)
	var expected := 1
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		state.core_attribute_gains[attribute_id] = expected
		expected += 1
	var source := CharacterProgressionService.source_for(7, state)
	TestAssertions.truthy(source != null, "valid cumulative source builds", failures)
	TestAssertions.equal(source.id, &"character_growth_7", "cumulative source ID is stable", failures)
	TestAssertions.equal(source.source_type, &"character_growth", "cumulative source type is stable", failures)
	TestAssertions.equal(source.label, "Class Growth", "cumulative source label is stable", failures)
	TestAssertions.equal(source.owner_member_id, 7, "cumulative source owner is the member", failures)
	TestAssertions.equal(source.modifiers.size(), ClassGrowthDefinition.CORE_ATTRIBUTE_IDS.size(), "source includes all six attributes", failures)
	for index: int in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS.size():
		var attribute_id := ClassGrowthDefinition.CORE_ATTRIBUTE_IDS[index]
		var modifier := source.modifiers[index]
		TestAssertions.equal(modifier.stat_id, attribute_id, "%s modifier targets its attribute" % attribute_id, failures)
		TestAssertions.equal(modifier.operation, StatModifier.Operation.FLAT, "%s modifier is flat" % attribute_id, failures)
		TestAssertions.near(modifier.value, float(index + 1), 0.001, "%s modifier stores cumulative gain" % attribute_id, failures)
		TestAssertions.equal(modifier.source_id, &"character_growth_7", "%s modifier uses stable source ID" % attribute_id, failures)
		TestAssertions.equal(modifier.source_label, "Class Growth", "%s modifier uses growth label" % attribute_id, failures)
	TestAssertions.equal(CharacterProgressionService.source_for(8, state), null, "source rejects mismatched member", failures)

func _test_snapshot_round_trip_and_rejections(failures: Array[String]) -> void:
	var fighter := load(FIGHTER_PATH) as ClassGrowthDefinition
	var tuning := load(TUNING_PATH) as ExperienceTuning
	var award := CharacterProgressionService.preview_award(
		CharacterProgressionState.fresh(1, tuning), fighter, tuning, 160, 150, 1337, &"player_one", 1,
	)
	var snapshot := award.next_state.to_snapshot()
	var restored := CharacterProgressionState.from_snapshot(snapshot, tuning)
	TestAssertions.truthy(restored != null, "valid snapshot restores", failures)
	if restored != null:
		TestAssertions.equal(restored.to_snapshot(), snapshot, "snapshot round trip is exact", failures)
		TestAssertions.truthy(JSON.parse_string(JSON.stringify(snapshot)) is Dictionary, "snapshot uses JSON-safe primitives", failures)

	var bad_member := snapshot.duplicate(true)
	bad_member["member_id"] = "1"
	TestAssertions.equal(CharacterProgressionState.from_snapshot(bad_member, tuning), null, "snapshot rejects mismatched member ID type", failures)
	var bad_level := snapshot.duplicate(true)
	bad_level["level"] = 0
	TestAssertions.equal(CharacterProgressionState.from_snapshot(bad_level, tuning), null, "snapshot rejects nonpositive level", failures)
	var bad_xp := snapshot.duplicate(true)
	bad_xp["experience"] = int(bad_xp["experience_required"])
	TestAssertions.equal(CharacterProgressionState.from_snapshot(bad_xp, tuning), null, "snapshot rejects XP outside current threshold", failures)
	var unknown_attribute := snapshot.duplicate(true)
	unknown_attribute["core_attribute_gains"]["luck"] = 1
	TestAssertions.equal(CharacterProgressionState.from_snapshot(unknown_attribute, tuning), null, "snapshot rejects unknown attribute", failures)
	var bad_milestone := snapshot.duplicate(true)
	bad_milestone["milestone_outcomes"]["6"] = "strength"
	TestAssertions.equal(CharacterProgressionState.from_snapshot(bad_milestone, tuning), null, "snapshot rejects non-five milestone level", failures)
