class_name ItemAffixDefinition
extends Resource

const VALID_AFFIX_KINDS: PackedStringArray = ["implicit", "prefix", "suffix", "special"]
const VALID_OPERATIONS: Array[int] = [
	StatModifier.Operation.FLAT,
	StatModifier.Operation.INCREASED,
	StatModifier.Operation.REDUCED,
	StatModifier.Operation.MORE,
	StatModifier.Operation.LESS,
]

@export var id: StringName
@export var display_name: String
@export_enum("implicit", "prefix", "suffix", "special") var affix_kind := "prefix"
@export_range(1, 100, 1) var minimum_tier := 1
@export_range(1, 100, 1) var maximum_tier := 1
@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var minimum_roll_by_tier: Array[float] = []
@export var maximum_roll_by_tier: Array[float] = []
@export var required_tags: Array[StringName] = []

func roll_bounds(tier: int) -> Vector2:
	var index := tier - minimum_tier
	if tier < minimum_tier or tier > maximum_tier:
		return Vector2(INF, -INF)
	if index < 0 or index >= minimum_roll_by_tier.size() or index >= maximum_roll_by_tier.size():
		return Vector2(INF, -INF)
	return Vector2(minimum_roll_by_tier[index], maximum_roll_by_tier[index])

func validate(stat_catalog: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("affix id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("affix %s display name is empty" % id)
	if affix_kind not in VALID_AFFIX_KINDS:
		errors.append("affix %s kind %s is unsupported" % [id, affix_kind])
	if minimum_tier < 1 or maximum_tier < 1:
		errors.append("affix %s tier range must begin at one or above" % id)
	if minimum_tier > maximum_tier:
		errors.append("affix %s minimum tier exceeds maximum" % id)
	if stat_id.is_empty():
		errors.append("affix %s stat id is empty" % id)
	elif stat_catalog == null:
		errors.append("affix %s stat catalog is missing" % id)
	elif stat_catalog.definition(stat_id) == null:
		errors.append("affix %s references unknown stat %s" % [id, stat_id])
	if operation not in VALID_OPERATIONS:
		errors.append("affix %s operation %d is unsupported" % [id, operation])
	var tier_count := maximum_tier - minimum_tier + 1
	if tier_count < 0:
		tier_count = 0
	if minimum_roll_by_tier.size() != tier_count:
		errors.append("affix %s requires one minimum roll per tier" % id)
	if maximum_roll_by_tier.size() != tier_count:
		errors.append("affix %s requires one maximum roll per tier" % id)
	var comparable_tiers := mini(tier_count, mini(minimum_roll_by_tier.size(), maximum_roll_by_tier.size()))
	for index: int in comparable_tiers:
		var minimum_roll := minimum_roll_by_tier[index]
		var maximum_roll := maximum_roll_by_tier[index]
		if not is_finite(minimum_roll) or not is_finite(maximum_roll):
			errors.append("affix %s tier %d roll bounds must be finite" % [id, minimum_tier + index])
			continue
		if minimum_roll > maximum_roll:
			errors.append("affix %s tier %d minimum roll exceeds maximum" % [id, minimum_tier + index])
		if index > 0 and minimum_roll <= maximum_roll_by_tier[index - 1]:
			errors.append("affix %s tier %d roll range overlaps or descends" % [id, minimum_tier + index])
	return errors
