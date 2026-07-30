extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var effect := StatUpgradeEffect.new()
	effect.stat_id = &"damage"
	effect.operation = StatModifier.Operation.INCREASED
	effect.value_per_rank = 0.08
	effect.required_action_tags = [&"projectile"]
	TestAssertions.near(effect.value_for_rank(0), 0.0, 0.001, "non-positive rank has no value", failures)
	TestAssertions.near(effect.value_for_rank(1), 0.08, 0.001, "rank one value", failures)
	effect.rank_values = [0.05, 0.12]
	TestAssertions.near(effect.value_for_rank(2), 0.12, 0.001, "rank-indexed value", failures)
	TestAssertions.near(effect.value_for_rank(3), 0.08, 0.001, "rank beyond indexed values uses per-rank value", failures)

	var definition := UpgradeDefinition.new()
	definition.id = &"fixture_projectile"
	definition.display_name = "Fixture Projectile"
	definition.summary = "Fixture summary"
	definition.scope = UpgradeDefinition.Scope.CHARACTER
	definition.max_rank = 3
	definition.selection_weight = 1.0
	definition.effects = [effect]
	TestAssertions.truthy(definition.is_single_recipient(), "character scope selects one member", failures)
	definition.scope = UpgradeDefinition.Scope.CLASS_SPECIFIC
	TestAssertions.truthy(definition.is_single_recipient(), "class-specific scope selects one member", failures)
	definition.scope = UpgradeDefinition.Scope.PARTY
	TestAssertions.truthy(not definition.is_single_recipient(), "party scope has no single recipient", failures)

	var fighter := ClassDefinition.new()
	fighter.id = &"fighter"
	fighter.capability_tags = [&"projectile", &"physical"]
	fighter.traits = [&"martial"]
	var member := PartyMemberState.new(7, fighter, true)
	definition.scope = UpgradeDefinition.Scope.CHARACTER
	definition.allowed_class_ids = [&"fighter"]
	definition.required_all_tags = [&"martial"]
	definition.required_any_tags = [&"projectile", &"area"]
	definition.excluded_tags = [&"caster"]
	TestAssertions.truthy(definition.is_member_eligible(member), "combined eligibility accepts matching member", failures)
	definition.allowed_class_ids = [&"ranger"]
	TestAssertions.truthy(not definition.is_member_eligible(member), "allowed classes reject another class", failures)
	definition.allowed_class_ids = []
	definition.required_all_tags = [&"divine"]
	TestAssertions.truthy(not definition.is_member_eligible(member), "required-all rejects missing tag", failures)
	definition.required_all_tags = []
	definition.required_any_tags = [&"area"]
	TestAssertions.truthy(not definition.is_member_eligible(member), "required-any rejects no match", failures)
	definition.required_any_tags = []
	definition.excluded_tags = [&"physical"]
	TestAssertions.truthy(not definition.is_member_eligible(member), "excluded tag rejects member", failures)
	TestAssertions.truthy(not definition.is_member_eligible(null), "null member is ineligible", failures)

	var owned_modifier := StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.08, &"fixture_projectile", "Fixture Projectile")
	owned_modifier.required_capability_tags = [&"physical"]
	owned_modifier.excluded_capability_tags = [&"caster"]
	owned_modifier.required_action_tags = [&"projectile"]
	owned_modifier.excluded_action_tags = [&"melee"]
	member._add_modifier_source(StatModifierSource.create(&"fixture_projectile", &"upgrade", "Fixture Projectile", member.member_id, [owned_modifier]))
	var copied_modifier := member.modifier_sources[0].modifiers[0]
	TestAssertions.equal(copied_modifier.required_capability_tags, [&"physical"], "owned source copies required capabilities", failures)
	TestAssertions.equal(copied_modifier.excluded_capability_tags, [&"caster"], "owned source copies excluded capabilities", failures)
	TestAssertions.equal(copied_modifier.required_action_tags, [&"projectile"], "owned source copies required actions", failures)
	TestAssertions.equal(copied_modifier.excluded_action_tags, [&"melee"], "owned source copies excluded actions", failures)
	return failures
