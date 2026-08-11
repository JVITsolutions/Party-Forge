extends RefCounted

const ISSUER_PATH := "res://scripts/dev/developer_loot_lab_item_issuer.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(ISSUER_PATH), "Loot Lab item issuer script exists", failures)
	if not ResourceLoader.exists(ISSUER_PATH):
		return failures
	var issuer_script := load(ISSUER_PATH) as Script
	TestAssertions.truthy(issuer_script != null, "Loot Lab item issuer script loads", failures)
	if issuer_script == null:
		return failures

	var preview := _preview_item(failures)
	if preview == null:
		return failures
	var issued: ItemIssueResult = issuer_script.call(
		"reissue",
		preview,
		7,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(issued.ok(), "valid preview is reissued for sandbox ownership", failures)
	if issued.ok():
		TestAssertions.truthy(issued.item.instance_id != preview.instance_id, "reissuance never preserves the preview instance ID", failures)
		TestAssertions.equal(String(issued.item.origin.get("issuer_namespace", "")), "developer-loot-lab-issued", "reissued item uses the isolated durable namespace", failures)
		TestAssertions.equal(int(issued.item.origin.get("sequence", -1)), 7, "reissued item uses the requested durable sequence", failures)
		TestAssertions.equal(issued.item.base_definition_id, preview.base_definition_id, "reissuance preserves the selected base", failures)
		TestAssertions.equal(issued.item.rarity_id, preview.rarity_id, "reissuance preserves rarity", failures)
		TestAssertions.equal(issued.item.item_level, preview.item_level, "reissuance preserves item level", failures)
		TestAssertions.equal(issued.item.to_dictionary()["affixes"], preview.to_dictionary()["affixes"], "reissuance preserves exact affix rolls", failures)
		TestAssertions.equal(issued.item.to_dictionary()["base_damage_components"], preview.to_dictionary()["base_damage_components"], "reissuance preserves exact weapon damage", failures)
		TestAssertions.equal((issued.item.origin["source"] as Dictionary)["loot_lab_preview_origin"], preview.to_dictionary()["origin"], "durable provenance embeds the exact preview origin", failures)

	var repeated: ItemIssueResult = issuer_script.call(
		"reissue",
		preview,
		8,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(repeated.ok() and repeated.item.instance_id != issued.item.instance_id, "distinct durable sequences produce unique item IDs", failures)
	var missing: ItemIssueResult = issuer_script.call(
		"reissue",
		null,
		0,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(not missing.ok() and missing.error.contains("field=preview"), "missing preview is rejected explicitly", failures)
	var bad_sequence: ItemIssueResult = issuer_script.call(
		"reissue",
		preview,
		-1,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(not bad_sequence.ok() and bad_sequence.error.contains("sequence"), "invalid durable sequence is rejected", failures)
	return failures

func _preview_item(failures: Array[String]) -> ItemInstance:
	var request := ItemGenerationRequest.create(424242, 7, 750, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rarity_rare_unlocked"]
	var generated := ItemGenerationService.generate(
		request,
		"loot-lab-preview:test",
		7,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.truthy(generated.ok(), "preview fixture generates", failures)
	return generated.item if generated.ok() else null
