class_name ItemFoundationCatalog
extends Resource

@export var rarities: Array[ItemRarityDefinition] = []
@export var affixes: Array[ItemAffixDefinition] = []

func rarity(id: StringName) -> ItemRarityDefinition:
	for definition: ItemRarityDefinition in rarities:
		if definition != null and definition.id == id:
			return definition
	return null

func affix(id: StringName) -> ItemAffixDefinition:
	for definition: ItemAffixDefinition in affixes:
		if definition != null and definition.id == id:
			return definition
	return null

func functional_rarity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: ItemRarityDefinition in rarities:
		if definition != null and definition.functional:
			ids.append(definition.id)
	return ids

func validate(stat_catalog: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_rarities: Dictionary = {}
	for definition: ItemRarityDefinition in rarities:
		if definition == null:
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=<null> reason=definition missing")
			continue
		if seen_rarities.has(definition.id):
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=duplicate id" % definition.id)
		else:
			seen_rarities[definition.id] = true
		for reason: String in definition.validate():
			errors.append("PARTY_FORGE_ITEM_RARITY_ERROR id=%s reason=%s" % [definition.id, reason])
	var seen_affixes: Dictionary = {}
	for definition: ItemAffixDefinition in affixes:
		if definition == null:
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=<null> reason=definition missing")
			continue
		if seen_affixes.has(definition.id):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=duplicate id" % definition.id)
		else:
			seen_affixes[definition.id] = true
		for reason: String in definition.validate(stat_catalog):
			errors.append("PARTY_FORGE_ITEM_AFFIX_ERROR id=%s reason=%s" % [definition.id, reason])
	return errors
