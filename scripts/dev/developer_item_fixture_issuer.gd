class_name DeveloperItemFixtureIssuer
extends RefCounted

const OWNER_ID := "developer-item-sandbox"
const ISSUER_NAMESPACE := "sandbox:developer-item-sandbox"
const SOURCE := "developer_item_fixture"
const EXPECTED_DEFINITION_COUNT := 99

static func issue_all(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> Dictionary:
	if equipment == null:
		return _failure("equipment catalog is missing")
	if foundation == null:
		return _failure("item foundation catalog is missing")
	if equipment.definitions.size() != EXPECTED_DEFINITION_COUNT:
		return _failure("equipment definition count must equal %d" % EXPECTED_DEFINITION_COUNT)
	var rarity_ids := foundation.ordinary_rarity_ids()
	if rarity_ids.size() != 5:
		return _failure("ordinary rarity count must equal 5")
	if foundation.affixes.size() < 4:
		return _failure("fixture affix catalog must contain at least 4 definitions")
	var items: Array[ItemInstance] = []
	var definition_ids: Array[String] = []
	for index: int in equipment.definitions.size():
		var definition := equipment.definitions[index]
		if definition == null:
			return _failure("equipment definition %d is missing" % index)
		var rarity_id: StringName = rarity_ids[index % rarity_ids.size()]
		var rarity := foundation.rarity(rarity_id)
		if rarity == null:
			return _failure("ordinary rarity %s is missing" % rarity_id)
		if rarity.patterns.is_empty():
			return _failure("ordinary rarity %s has no affix pattern" % rarity_id)
		var issued := ItemInstanceIssuer.issue(
			ISSUER_NAMESPACE,
			index,
			SOURCE,
			index,
			{
				"affixes": _fixture_affixes(index, rarity.patterns[0].explicit_count(), foundation),
				"base_definition_id": String(definition.id),
				"base_damage_components": [],
				"item_level": 1 + (index % 100),
				"rarity_id": String(rarity_id),
			},
			equipment,
			foundation
		)
		if not issued.ok():
			return _failure("issuance %d failed: %s" % [index, issued.error])
		items.append(issued.item)
		definition_ids.append(String(definition.id))
	return {
		"items": items,
		"definition_ids": definition_ids,
		"error": "",
	}

static func _fixture_affixes(
	definition_index: int,
	affix_count: int,
	foundation: ItemFoundationCatalog
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var explicit_definitions: Array[ItemAffixDefinition] = []
	for definition: ItemAffixDefinition in foundation.affixes:
		if definition != null and definition.affix_kind in ["prefix", "suffix"]:
			explicit_definitions.append(definition)
	if explicit_definitions.is_empty():
		return result
	for affix_index: int in affix_count:
		var definition: ItemAffixDefinition = explicit_definitions[
			(definition_index + affix_index) % explicit_definitions.size()
		]
		if definition.tiers.is_empty():
			continue
		var tier_definition := definition.tiers[(definition_index + affix_index) % definition.tiers.size()]
		var rolls: Array[Dictionary] = []
		for effect_index: int in definition.effects.size():
			var effect := definition.effects[effect_index]
			var bounds := tier_definition.roll_bounds(effect_index)
			var explicit_roll := clampf((bounds.x + bounds.y) * 0.5, bounds.x, bounds.y)
			var required_tags: Array[String] = []
			for tag: StringName in effect.required_tags:
				required_tags.append(String(tag))
			rolls.append({
				"operation": effect.operation,
				"required_tags": required_tags,
				"stat_id": String(effect.stat_id),
				"value": explicit_roll,
			})
		result.append({
			"affix_kind": definition.affix_kind,
			"definition_id": String(definition.id),
			"rolls": rolls,
			"tier": tier_definition.tier,
		})
	return result

static func _failure(reason: String) -> Dictionary:
	return {
		"items": [] as Array[ItemInstance],
		"definition_ids": [] as Array[String],
		"error": "PARTY_FORGE_DEVELOPER_ITEM_FIXTURE_ERROR reason=%s" % reason,
	}
