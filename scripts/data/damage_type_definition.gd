class_name DamageTypeDefinition
extends Resource

enum MitigationRule { ARMOR, RESISTANCE }

@export var id: StringName
@export var display_name: String
@export var keyword_id: StringName
@export var presentation_color := Color.WHITE
@export var offense_stat_id: StringName
@export var defense_stat_id: StringName
@export var mitigation_rule := MitigationRule.RESISTANCE

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=<empty> reason=missing id")
	if display_name.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=missing display name" % id)
	if keyword_id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=missing keyword id" % id)
	if mitigation_rule not in [MitigationRule.ARMOR, MitigationRule.RESISTANCE]:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s rule=%d reason=unsupported mitigation rule" % [id, mitigation_rule])
	var offense := stats.definition(offense_stat_id) if stats != null else null
	var defense := stats.definition(defense_stat_id) if stats != null else null
	if offense == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=unknown offense stat" % [id, offense_stat_id])
	if defense == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=unknown defense stat" % [id, defense_stat_id])
	elif mitigation_rule == MitigationRule.RESISTANCE and defense.value_format != StatDefinition.ValueFormat.RATIO_PERCENT:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=resistance rule requires ratio stat" % [id, defense_stat_id])
	return errors
