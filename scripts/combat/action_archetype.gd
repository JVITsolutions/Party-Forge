class_name ActionArchetype
extends RefCounted

const PRIMARY_TAGS: Array[StringName] = [&"melee", &"ranged", &"caster"]

static func primary_tag(attack: AttackDefinition) -> StringName:
	if attack == null:
		return &""
	var found: Array[StringName] = []
	var tags := attack.normalized_action_tags()
	for tag: StringName in PRIMARY_TAGS:
		if tag in tags:
			found.append(tag)
	return found[0] if found.size() == 1 else &""

static func stat_id(attack: AttackDefinition) -> StringName:
	var tag := primary_tag(attack)
	return StringName("%s_damage" % tag) if not tag.is_empty() else &""

static func validate_player_damage_action(attack: AttackDefinition) -> PackedStringArray:
	if attack == null or attack.is_healing():
		return PackedStringArray()
	var count := 0
	var tags := attack.normalized_action_tags()
	for tag: StringName in PRIMARY_TAGS:
		if tag in tags:
			count += 1
	if count == 1:
		return PackedStringArray()
	return PackedStringArray([
		"PARTY_FORGE_DAMAGE_ERROR attack=%s reason=expected exactly one primary archetype" % attack.id,
	])
