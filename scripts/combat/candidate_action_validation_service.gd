class_name CandidateActionValidationService
extends RefCounted

## Validates every action a member would own against one candidate source set.
## Callers must run this before committing sources, activations, revisions, or caches.
static func validate(
	class_definition: ClassDefinition,
	member_id: int,
	stat_catalog: StatCatalog,
	damage_types: DamageTypeCatalog,
	base_values: Dictionary,
	capabilities: Array[StringName],
	final_sources: Array[StatModifierSource],
	revision: int,
	tuning: AttributeProjectionTuning,
	weapon: ActiveWeaponDamageSnapshot = null,
) -> String:
	if class_definition == null or class_definition.primary_attack == null:
		return "action validation failed action=<primary> detail=primary action is unavailable"
	if weapon != null and (weapon.member_id != member_id or weapon.revision != revision):
		return "action validation failed action=<weapon> detail=active weapon member or revision mismatch"
	for attack: AttackDefinition in class_definition.owned_actions():
		var action_id := String(attack.id) if not attack.id.is_empty() else "<empty>"
		var authored_errors := attack.validate(damage_types)
		if not authored_errors.is_empty():
			return "action validation failed action=%s detail=%s" % [action_id, authored_errors[0]]
		var action_resolution := MemberStatResolutionService.resolve(
			member_id,
			stat_catalog,
			base_values,
			capabilities,
			final_sources,
			DamageResolver.action_tags_for(attack, weapon),
			revision,
			tuning,
		)
		if not action_resolution.ok():
			return "action stat resolution failed action=%s detail=%s" % [action_id, action_resolution.error]
		var projection_error := _validate_projection(attack, action_resolution.final_stats, damage_types, weapon)
		if not projection_error.is_empty():
			return "action validation failed action=%s detail=%s" % [action_id, projection_error]
	return ""


static func _validate_projection(
	attack: AttackDefinition,
	action_stats: ResolvedStatSnapshot,
	damage_types: DamageTypeCatalog,
	weapon: ActiveWeaponDamageSnapshot = null,
) -> String:
	if action_stats == null:
		return "Missing resolved character stats."
	var estimate := ActionCombatEstimateService.estimate_from_snapshot(
		attack,
		action_stats,
		damage_types,
		weapon,
	)
	if estimate == null or not estimate.available:
		return estimate.unavailable_reason if estimate != null else "candidate action is unavailable"
	return ""
