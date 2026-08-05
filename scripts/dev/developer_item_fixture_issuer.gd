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
	var rarity_ids := foundation.functional_rarity_ids()
	if rarity_ids.size() != 5:
		return _failure("functional rarity count must equal 5")
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
			return _failure("functional rarity %s is missing" % rarity_id)
		var issued := ItemInstanceIssuer.issue(
			ISSUER_NAMESPACE,
			index,
			SOURCE,
			index,
			{
				"affixes": _fixture_affixes(index, rarity.minimum_affixes, foundation),
				"base_definition_id": String(definition.id),
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
	for affix_index: int in affix_count:
		var definition: ItemAffixDefinition = foundation.affixes[
			(definition_index + affix_index) % foundation.affixes.size()
		]
		var tier_count := definition.maximum_tier - definition.minimum_tier + 1
		var tier := definition.minimum_tier + ((definition_index + affix_index) % tier_count)
		var bounds := definition.roll_bounds(tier)
		var explicit_roll := clampf((bounds.x + bounds.y) * 0.5, bounds.x, bounds.y)
		var required_tags: Array[String] = []
		for tag: StringName in definition.required_tags:
			required_tags.append(String(tag))
		result.append({
			"affix_kind": definition.affix_kind,
			"definition_id": String(definition.id),
			"rolls": [{
				"operation": definition.operation,
				"required_tags": required_tags,
				"stat_id": String(definition.stat_id),
				"value": explicit_roll,
			}],
			"tier": tier,
		})
	return result

static func _failure(reason: String) -> Dictionary:
	return {
		"items": [] as Array[ItemInstance],
		"definition_ids": [] as Array[String],
		"error": "PARTY_FORGE_DEVELOPER_ITEM_FIXTURE_ERROR reason=%s" % reason,
	}
