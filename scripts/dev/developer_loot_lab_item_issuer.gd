class_name DeveloperLootLabItemIssuer
extends RefCounted

const ISSUER_NAMESPACE := "developer-loot-lab-issued"

static func reissue(
	preview: ItemInstance,
	sequence: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemIssueResult:
	if preview == null:
		var failure := ItemIssueResult.new()
		failure.error = "PARTY_FORGE_LOOT_LAB_ISSUE_ERROR field=preview reason=missing"
		return failure
	var document := preview.to_dictionary()
	return ItemInstanceIssuer.issue(
		ISSUER_NAMESPACE,
		sequence,
		{"loot_lab_preview_origin": document["origin"]},
		int((document["origin"] as Dictionary).get("seed", 0)),
		{
			"affixes": document["affixes"],
			"base_damage_components": document["base_damage_components"],
			"base_definition_id": document["base_definition_id"],
			"item_level": document["item_level"],
			"rarity_id": document["rarity_id"],
		},
		equipment,
		foundation
	)
