class_name ItemRarityDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var functional := true
@export var minimum_affixes := 0
@export var maximum_affixes := 0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("rarity id is empty")
	if display_name.strip_edges().is_empty():
		errors.append("rarity %s display name is empty" % id)
	if minimum_affixes < 0:
		errors.append("rarity %s minimum affixes is negative" % id)
	if maximum_affixes < 0:
		errors.append("rarity %s maximum affixes is negative" % id)
	if minimum_affixes > maximum_affixes:
		errors.append("rarity %s minimum affixes exceeds maximum" % id)
	return errors
