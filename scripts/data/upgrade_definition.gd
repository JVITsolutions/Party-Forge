class_name UpgradeDefinition
extends Resource

enum Scope { CHARACTER, CLASS_SPECIFIC, PARTY, TRAIT }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName
@export var display_name: String
@export var summary: String
@export_multiline var description: String
@export var tooltip_keyword_ids: Array[StringName] = []
@export var scope := Scope.CHARACTER
@export var allowed_class_ids: Array[StringName] = []
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var max_rank := 1
@export var selection_weight := 1.0
@export var rarity := Rarity.COMMON
@export var effects: Array[UpgradeEffectDefinition] = []

func is_single_recipient() -> bool:
	return scope in [Scope.CHARACTER, Scope.CLASS_SPECIFIC]

func is_member_eligible(member: PartyMemberState) -> bool:
	if member == null or member.class_definition == null:
		return false
	if not allowed_class_ids.is_empty() and member.class_definition.id not in allowed_class_ids:
		return false
	var tags := member.capability_tags
	for tag: StringName in required_all_tags:
		if tag not in tags:
			return false
	if not required_any_tags.is_empty() and not required_any_tags.any(func(tag: StringName) -> bool: return tag in tags):
		return false
	return not excluded_tags.any(func(tag: StringName) -> bool: return tag in tags)
