class_name ItemInstanceIssuer
extends RefCounted

static func issue(
	issuer_namespace: String,
	sequence: Variant,
	source: Variant,
	seed: Variant,
	item_data: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemIssueResult:
	var result := ItemIssueResult.new()
	if issuer_namespace.strip_edges().is_empty():
		result.error = "PARTY_FORGE_ITEM_ISSUE_ERROR field=issuer_namespace reason=must be a non-empty string"
		return result
	if not _is_nonnegative_json_integer(sequence):
		result.error = "PARTY_FORGE_ITEM_ISSUE_ERROR field=sequence reason=must be a non-negative JSON-safe integer"
		return result
	if not item_data is Dictionary:
		result.error = "PARTY_FORGE_ITEM_ISSUE_ERROR field=item_data reason=must be a dictionary"
		return result
	var data := item_data as Dictionary
	var document := {
		"affixes": data.get("affixes"),
		"base_definition_id": data.get("base_definition_id"),
		"instance_id": "item-%s-%016d" % [issuer_namespace.sha256_text(), int(sequence)],
		"item_level": data.get("item_level"),
		"origin": {
			"issuer_namespace": issuer_namespace,
			"seed": seed,
			"sequence": int(sequence),
			"source": source,
		},
		"rarity_id": data.get("rarity_id"),
		"schema_version": ItemInstance.SCHEMA_VERSION,
	}
	var decoded := ItemInstanceCodec.decode(document, equipment, foundation)
	if not decoded.ok():
		result.error = decoded.error
		return result
	result.error = ItemInstanceCodec.validate(decoded.item, equipment, foundation)
	if not result.error.is_empty():
		return result
	result.item = decoded.item
	return result

static func _is_nonnegative_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= ItemInstanceCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= 0.0 and number <= float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX)
