extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const LEGACY_SCHEMA_ONE_ITEM := "{\"affixes\":[{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":3.0}],\"tier\":1},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_reach\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"attack_range\",\"value\":0.2}],\"tier\":2}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"item-explicit-round-trip\",\"item_level\":28,\"origin\":{\"issuer_namespace\":\"profile:profile-a\",\"seed\":4402,\"sequence\":42,\"source\":\"quest_reward\"},\"rarity_id\":\"legendary\",\"schema_version\":1}"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null, "equipment catalog loads for item codec", failures)
	TestAssertions.truthy(foundation != null, "foundation catalog loads for item codec", failures)
	if equipment == null or foundation == null:
		return failures
	_assert_schema_one_migration(equipment, foundation, failures)
	_assert_immutable_round_trip(equipment, foundation, failures)
	_assert_retained_fixture_boundaries(equipment, foundation, failures)
	_assert_multi_effect_codec(equipment, foundation, failures)
	_assert_attribute_and_typed_damage_records_round_trip(equipment, foundation, failures)
	_assert_strict_rejections(equipment, foundation, failures)
	_assert_deterministic_issuer(equipment, foundation, failures)
	return failures

func _assert_immutable_round_trip(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var item := _make_item()
	var decode_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var document := item.to_dictionary()
	TestAssertions.equal(document.get("base_damage_components"), [
		{"damage_type_id": "fire", "minimum_damage": 1.0, "maximum_damage": 2.0},
		{"damage_type_id": "physical", "minimum_damage": 3.0, "maximum_damage": 5.0},
	], "base damage components serialize in stable damage-type order", failures)
	if not document.has("base_damage_components"):
		return
	var decoded := ItemInstanceCodec.decode(document, equipment, decode_foundation)
	TestAssertions.truthy(decoded.ok(), "schema-two item round trip succeeds", failures)
	if not decoded.ok():
		failures.append("explicit item round trip error: %s" % decoded.error)
		return
	TestAssertions.equal(decoded.item.to_dictionary(), document, "schema-two fixture preserves exact item values", failures)
	TestAssertions.equal(ItemInstanceCodec.encode(decoded.item), JSON.stringify(document), "schema-two fixture round trips byte-equivalently", failures)

	var stout_index := decode_foundation.affixes.find(decode_foundation.affix(&"stout"))
	decode_foundation.affixes[stout_index] = decode_foundation.affixes[stout_index].duplicate(true) as ItemAffixDefinition
	var changed_affix := decode_foundation.affixes[stout_index]
	changed_affix.tiers[0].minimum_rolls[0] = 999.0
	TestAssertions.equal(decoded.item.affixes[0].rolls[0].value, 3.0, "decode catalog changes do not rewrite issued rolls", failures)

	var copied := decoded.item.copy()
	copied.affixes[0].rolls[0].value = 2.0
	copied.affixes[0].rolls[0].required_tags.append(&"copy_only")
	((copied.get("base_damage_components") as Array)[0] as RefCounted).set("minimum_damage", 999.0)
	copied.origin["seed"] = "changed"
	TestAssertions.equal(decoded.item.affixes[0].rolls[0].value, 3.0, "item copy owns nested rolls", failures)
	TestAssertions.equal(decoded.item.affixes[0].rolls[0].required_tags, [], "item copy owns required tags", failures)
	TestAssertions.equal(((decoded.item.get("base_damage_components") as Array)[0] as RefCounted).get("minimum_damage"), 1.0, "item copy owns base damage components", failures)
	TestAssertions.equal(decoded.item.origin["seed"], 4402, "item copy owns origin", failures)

	var serialized := decoded.item.to_dictionary()
	(serialized["affixes"] as Array)[0]["rolls"][0]["value"] = 1.0
	(serialized["base_damage_components"] as Array)[0]["minimum_damage"] = 777.0
	(serialized["origin"] as Dictionary)["seed"] = "dictionary-change"
	TestAssertions.equal(decoded.item.affixes[0].rolls[0].value, 3.0, "serialized document owns nested rolls", failures)
	TestAssertions.equal(((decoded.item.get("base_damage_components") as Array)[0] as RefCounted).get("minimum_damage"), 1.0, "serialized document owns base damage components", failures)
	TestAssertions.equal(decoded.item.origin["seed"], 4402, "serialized document owns origin", failures)

func _assert_schema_one_migration(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var decoded := ItemInstanceCodec.decode(JSON.parse_string(LEGACY_SCHEMA_ONE_ITEM), equipment, foundation)
	TestAssertions.truthy(decoded.ok(), "literal schema-one item decodes", failures)
	if not decoded.ok():
		failures.append("literal schema-one migration error: %s" % decoded.error)
		return
	TestAssertions.equal(decoded.item.schema_version, 2, "schema-one item migrates to in-memory schema two", failures)
	TestAssertions.equal(decoded.item.get("base_damage_components"), [], "schema-one migration invents no base damage", failures)
	var encoded := JSON.parse_string(ItemInstanceCodec.encode(decoded.item)) as Dictionary
	TestAssertions.equal(encoded.get("schema_version"), 2, "migrated item re-encodes as schema two", failures)
	TestAssertions.equal(encoded.get("base_damage_components"), [], "migrated item re-encodes an explicit empty base damage array", failures)

func _assert_retained_fixture_boundaries(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var retained: Array[Dictionary] = [
		{"id": "stout", "kind": "prefix", "stat": "constitution", "operation": StatModifier.Operation.FLAT, "tiers": [[1.0, 3.0], [4.0, 6.0], [7.0, 10.0]]},
		{"id": "keen", "kind": "prefix", "stat": "dexterity", "operation": StatModifier.Operation.FLAT, "tiers": [[1.0, 3.0], [4.0, 6.0], [7.0, 10.0]]},
		{"id": "wise", "kind": "prefix", "stat": "wisdom", "operation": StatModifier.Operation.FLAT, "tiers": [[1.0, 3.0], [4.0, 6.0], [7.0, 10.0]]},
		{"id": "of_embers", "kind": "suffix", "stat": "fire_damage", "operation": StatModifier.Operation.INCREASED, "tiers": [[0.05, 0.1], [0.11, 0.2], [0.21, 0.3]]},
		{"id": "of_rime", "kind": "suffix", "stat": "cold_damage", "operation": StatModifier.Operation.INCREASED, "tiers": [[0.05, 0.1], [0.11, 0.2], [0.21, 0.3]]},
		{"id": "of_reach", "kind": "suffix", "stat": "attack_range", "operation": StatModifier.Operation.INCREASED, "tiers": [[0.05, 0.1], [0.11, 0.2], [0.21, 0.3]]},
		{"id": "tempered_edge", "kind": "implicit", "stat": "physical_damage", "operation": StatModifier.Operation.INCREASED, "tiers": [[0.05, 0.1], [0.11, 0.2], [0.21, 0.3]]},
	]
	for fixture: Dictionary in retained:
		for tier_index: int in 3:
			var boundaries := fixture["tiers"] as Array
			for boundary: Variant in boundaries[tier_index] as Array:
				var document := _literal_schema_one_fixture_document(fixture, tier_index + 1, float(boundary))
				var decoded := ItemInstanceCodec.decode(document, equipment, foundation)
				TestAssertions.truthy(decoded.ok(), "%s tier %d historical boundary %s remains accepted" % [fixture["id"], tier_index + 1, boundary], failures)
				if decoded.ok():
					TestAssertions.equal(decoded.item.schema_version, 2, "%s tier %d boundary migrates to schema two" % [fixture["id"], tier_index + 1], failures)
					TestAssertions.equal(decoded.item.get("base_damage_components"), [], "%s tier %d boundary invents no base damage" % [fixture["id"], tier_index + 1], failures)

func _assert_multi_effect_codec(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var definition := ItemAffixDefinition.new()
	definition.id = &"two_effect_fixture"
	definition.display_name = "Two Effect Fixture"
	definition.affix_kind = "prefix"
	definition.modifier_family_ids = [&"two_effect_fixture"]
	var constitution := ItemModifierEffectDefinition.new()
	constitution.stat_id = &"constitution"
	constitution.operation = StatModifier.Operation.FLAT
	var fire := ItemModifierEffectDefinition.new()
	fire.stat_id = &"fire_damage"
	fire.operation = StatModifier.Operation.INCREASED
	definition.effects = [constitution, fire]
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_rolls = [1.0, 0.05]
	tier.maximum_rolls = [3.0, 0.1]
	definition.tiers = [tier]
	var custom_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	custom_foundation.affixes.append(definition)
	var document := _document()
	document["affixes"] = [{
		"affix_kind": "prefix",
		"definition_id": "two_effect_fixture",
		"rolls": [
			{"operation": StatModifier.Operation.FLAT, "required_tags": [], "stat_id": "constitution", "value": 2.0},
			{"operation": StatModifier.Operation.INCREASED, "required_tags": [], "stat_id": "fire_damage", "value": 0.075},
		],
		"tier": 1,
	}]
	var decoded := ItemInstanceCodec.decode(document, equipment, custom_foundation)
	TestAssertions.truthy(decoded.ok(), "two-effect affix accepts two ordered rolls", failures)
	if decoded.ok():
		TestAssertions.equal(decoded.item.to_dictionary(), document, "two-effect affix preserves ordered rolls", failures)
	var missing_roll := document.duplicate(true)
	missing_roll["affixes"][0]["rolls"].resize(1)
	_assert_decode_error(
		missing_roll,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls reason=must contain one roll per authored effect",
		equipment,
		custom_foundation,
		"missing authored effect roll",
		failures
	)
	var reversed := document.duplicate(true)
	reversed["affixes"][0]["rolls"].reverse()
	_assert_decode_error(
		reversed,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls[0].stat_id reason=must match definition stat constitution",
		equipment,
		custom_foundation,
		"reversed authored effect rolls",
		failures
	)


func _assert_attribute_and_typed_damage_records_round_trip(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var documents: Array[Dictionary] = [
		_task9_item_document(
			"task9-attribute-circlet",
			"emberweave_circlet",
			"stout",
			"prefix",
			"constitution",
			StatModifier.Operation.FLAT,
			3.0,
			0,
		),
		_task9_item_document(
			"task9-fire-wand",
			"emberweave_wand",
			"of_embers",
			"suffix",
			"fire_damage",
			StatModifier.Operation.INCREASED,
			0.1,
			1,
		),
	]
	var documents_before := JSON.stringify(documents)
	for document: Dictionary in documents:
		var document_before := JSON.stringify(document)
		var decoded := ItemInstanceCodec.decode(document, equipment, foundation)
		TestAssertions.truthy(decoded.ok(), "%s Task 9 record decodes" % document["instance_id"], failures)
		if not decoded.ok():
			continue
		TestAssertions.equal(decoded.item.to_dictionary(), document, "%s Task 9 dictionary is exact" % document["instance_id"], failures)
		TestAssertions.equal(ItemInstanceCodec.encode(decoded.item), document_before, "%s Task 9 record is byte-equivalent" % document["instance_id"], failures)
		TestAssertions.equal(JSON.stringify(document), document_before, "%s Task 9 decode leaves its input immutable" % document["instance_id"], failures)
	TestAssertions.equal(JSON.stringify(documents), documents_before, "Task 9 codec batch leaves every serialized item dictionary unchanged", failures)


func _assert_strict_rejections(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var unsupported_schema := _document()
	unsupported_schema["schema_version"] = 3
	_assert_decode_error(
		unsupported_schema,
		"PARTY_FORGE_ITEM_ERROR field=schema_version reason=must equal supported schema 1 or 2",
		equipment,
		foundation,
		"unsupported schema three",
		failures
	)
	var duplicate_damage := _document()
	duplicate_damage["base_damage_components"] = [
		{"damage_type_id": "physical", "minimum_damage": 3.0, "maximum_damage": 5.0},
		{"damage_type_id": "physical", "minimum_damage": 7.0, "maximum_damage": 11.0},
	]
	_assert_decode_error(
		duplicate_damage,
		"PARTY_FORGE_ITEM_ERROR field=base_damage_components[1].damage_type_id reason=duplicate damage type physical",
		equipment,
		foundation,
		"duplicate base damage type",
		failures
	)
	var malformed_damage := _document()
	malformed_damage["base_damage_components"] = [{"damage_type_id": "physical", "minimum_damage": 3.0}]
	_assert_decode_error(
		malformed_damage,
		"PARTY_FORGE_ITEM_ERROR field=base_damage_components[0] reason=missing fields maximum_damage",
		equipment,
		foundation,
		"malformed base damage component",
		failures
	)
	_assert_decode_error(
		_mutated_document("instance_id", ""),
		"PARTY_FORGE_ITEM_ERROR field=instance_id reason=must be a non-empty string",
		equipment,
		foundation,
		"empty instance id",
		failures
	)
	_assert_decode_error(
		_mutated_document("instance_id", 17),
		"PARTY_FORGE_ITEM_ERROR field=instance_id reason=must be a non-empty string",
		equipment,
		foundation,
		"invalid instance id type",
		failures
	)
	_assert_decode_error(
		_mutated_document("base_definition_id", "missing_base"),
		"PARTY_FORGE_ITEM_ERROR field=base_definition_id reason=unknown equipment base missing_base",
		equipment,
		foundation,
		"unknown base",
		failures
	)
	_assert_decode_error(
		_mutated_document("item_level", 0),
		"PARTY_FORGE_ITEM_ERROR field=item_level reason=must be a positive JSON-safe integer",
		equipment,
		foundation,
		"nonpositive item level",
		failures
	)
	var unsupported_foundation := foundation.duplicate(true) as ItemFoundationCatalog
	var mythic_index := unsupported_foundation.rarities.find(unsupported_foundation.rarity(&"mythic"))
	unsupported_foundation.rarities[mythic_index] = unsupported_foundation.rarities[mythic_index].duplicate(true) as ItemRarityDefinition
	unsupported_foundation.rarity(&"mythic").instance_supported = false
	_assert_decode_error(
		_mutated_document("rarity_id", "mythic"),
		"PARTY_FORGE_ITEM_ERROR field=rarity_id reason=rarity mythic does not support item instances",
		equipment,
		unsupported_foundation,
		"unsupported item-instance rarity",
		failures
	)

	var unknown_affix := _document()
	unknown_affix["affixes"][0]["definition_id"] = "missing_affix"
	_assert_decode_error(
		unknown_affix,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].definition_id reason=unknown affix missing_affix",
		equipment,
		foundation,
		"unknown affix",
		failures
	)
	var wrong_kind := _document()
	wrong_kind["affixes"][0]["affix_kind"] = "suffix"
	_assert_decode_error(
		wrong_kind,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].affix_kind reason=must match definition kind prefix",
		equipment,
		foundation,
		"affix kind mismatch",
		failures
	)
	var bad_tier := _document()
	bad_tier["affixes"][0]["tier"] = 4
	_assert_decode_error(
		bad_tier,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].tier reason=must be in definition range 1..3",
		equipment,
		foundation,
		"affix tier out of range",
		failures
	)
	var wrong_stat := _document()
	wrong_stat["affixes"][0]["rolls"][0]["stat_id"] = "dexterity"
	_assert_decode_error(
		wrong_stat,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls[0].stat_id reason=must match definition stat constitution",
		equipment,
		foundation,
		"wrong roll stat",
		failures
	)
	var wrong_operation := _document()
	wrong_operation["affixes"][0]["rolls"][0]["operation"] = StatModifier.Operation.INCREASED
	_assert_decode_error(
		wrong_operation,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls[0].operation reason=must match definition operation 0",
		equipment,
		foundation,
		"wrong roll operation",
		failures
	)
	var nonfinite := _document()
	nonfinite["affixes"][0]["rolls"][0]["value"] = NAN
	_assert_decode_error(
		nonfinite,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls[0].value reason=must be a finite number",
		equipment,
		foundation,
		"nonfinite roll",
		failures
	)
	var outside_bounds := _document()
	outside_bounds["affixes"][0]["rolls"][0]["value"] = 3.01
	_assert_decode_error(
		outside_bounds,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0].rolls[0].value reason=must be within issued bounds 1..3",
		equipment,
		foundation,
		"roll outside definition bounds",
		failures
	)
	var duplicate_affix := _document()
	duplicate_affix["affixes"].append((duplicate_affix["affixes"] as Array)[0].duplicate(true))
	_assert_decode_error(
		duplicate_affix,
		"PARTY_FORGE_ITEM_ERROR field=affixes[2].definition_id reason=duplicate affix stout",
		equipment,
		foundation,
		"duplicate affix ids",
		failures
	)

	var unexpected := _document()
	unexpected["surplus"] = true
	_assert_decode_error(
		unexpected,
		"PARTY_FORGE_ITEM_ERROR field=document reason=unexpected fields surplus",
		equipment,
		foundation,
		"unexpected item field",
		failures
	)
	var rolled_modifiers := _document()
	var first_affix: Dictionary = rolled_modifiers["affixes"][0]
	first_affix["rolled_modifiers"] = first_affix["rolls"]
	first_affix.erase("rolls")
	_assert_decode_error(
		rolled_modifiers,
		"PARTY_FORGE_ITEM_ERROR field=affixes[0] reason=missing fields rolls; unexpected fields rolled_modifiers",
		equipment,
		foundation,
		"rolled modifiers is not an alias",
		failures
	)
	var non_json := _document()
	non_json["origin"]["seed"] = Vector2.ONE
	_assert_decode_error(
		non_json,
		"PARTY_FORGE_ITEM_ERROR field=origin.seed reason=must be JSON-safe",
		equipment,
		foundation,
		"non JSON origin value",
		failures
	)

func _assert_deterministic_issuer(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var item_data := _issue_data()
	var surplus_item_data := item_data.duplicate(true)
	surplus_item_data["surplus"] = true
	var surplus := ItemInstanceIssuer.issue("profile:profile-a", 42, "quest_reward", 4402, surplus_item_data, equipment, foundation)
	TestAssertions.truthy(not surplus.ok(), "surplus issuer item data fails", failures)
	TestAssertions.equal(surplus.item, null, "surplus issuer item data has no item", failures)
	TestAssertions.equal(surplus.error, "PARTY_FORGE_ITEM_ISSUE_ERROR field=item_data reason=unexpected fields surplus", "surplus issuer item data error is exact", failures)
	var missing_item_data := item_data.duplicate(true)
	missing_item_data.erase("base_definition_id")
	var missing := ItemInstanceIssuer.issue("profile:profile-a", 42, "quest_reward", 4402, missing_item_data, equipment, foundation)
	TestAssertions.truthy(not missing.ok(), "missing issuer item data fails", failures)
	TestAssertions.equal(missing.item, null, "missing issuer item data has no item", failures)
	TestAssertions.equal(missing.error, "PARTY_FORGE_ITEM_ISSUE_ERROR field=item_data reason=missing fields base_definition_id", "missing issuer item data error is exact", failures)

	var first := ItemInstanceIssuer.issue("profile:profile-a", 42, "quest_reward", 4402, item_data, equipment, foundation)
	var repeated := ItemInstanceIssuer.issue("profile:profile-a", 42, "quest_reward", 4402, item_data, equipment, foundation)
	var other_namespace := ItemInstanceIssuer.issue("profile:profile-b", 42, "quest_reward", 4402, item_data, equipment, foundation)
	var other_sequence := ItemInstanceIssuer.issue("profile:profile-a", 43, "quest_reward", 4402, item_data, equipment, foundation)
	TestAssertions.truthy(first.ok(), "valid item issuance succeeds", failures)
	if not first.ok():
		failures.append("valid item issuance error: %s" % first.error)
		return
	TestAssertions.equal(repeated.item.instance_id, first.item.instance_id, "same namespace and sequence keep stable id", failures)
	TestAssertions.truthy(other_namespace.item.instance_id != first.item.instance_id, "different namespace changes item id", failures)
	TestAssertions.truthy(other_sequence.item.instance_id != first.item.instance_id, "different sequence changes item id", failures)
	TestAssertions.equal(
		first.item.instance_id,
		"item-%s-%016d" % ["profile:profile-a".sha256_text(), 42],
		"issuer uses opaque deterministic id format",
		failures
	)
	TestAssertions.equal(
		first.item.origin,
		{"issuer_namespace": "profile:profile-a", "seed": 4402, "sequence": 42, "source": "quest_reward"},
		"origin preserves exact issuance values",
		failures
	)

	var negative := ItemInstanceIssuer.issue("profile:profile-a", -1, "quest_reward", 4402, item_data, equipment, foundation)
	TestAssertions.truthy(not negative.ok(), "negative issuance sequence fails", failures)
	TestAssertions.equal(negative.item, null, "negative issuance has no item", failures)
	TestAssertions.equal(negative.error, "PARTY_FORGE_ITEM_ISSUE_ERROR field=sequence reason=must be a non-negative JSON-safe integer", "negative issuance error is exact", failures)
	var empty_namespace := ItemInstanceIssuer.issue("", 42, "quest_reward", 4402, item_data, equipment, foundation)
	TestAssertions.truthy(not empty_namespace.ok(), "empty issuer namespace fails", failures)
	TestAssertions.equal(empty_namespace.item, null, "empty issuer namespace has no item", failures)
	TestAssertions.equal(empty_namespace.error, "PARTY_FORGE_ITEM_ISSUE_ERROR field=issuer_namespace reason=must be a non-empty string", "empty issuer namespace error is exact", failures)

	var item_before_move := first.item.to_dictionary()
	var source_slots: Dictionary = {0: first.item}
	var destination_slots: Dictionary = {}
	var moved_item := source_slots[0] as ItemInstance
	source_slots.erase(0)
	destination_slots[3] = moved_item
	TestAssertions.truthy(not source_slots.has(0), "move clears source slot", failures)
	TestAssertions.equal(destination_slots[3], first.item, "move transfers the same item value", failures)
	TestAssertions.equal((destination_slots[3] as ItemInstance).instance_id, item_before_move["instance_id"], "moving item keeps instance id", failures)
	TestAssertions.equal((destination_slots[3] as ItemInstance).to_dictionary(), item_before_move, "moving item keeps exact values", failures)

func _assert_decode_error(
	document: Variant,
	expected_error: String,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	label: String,
	failures: Array[String]
) -> void:
	var decoded := ItemInstanceCodec.decode(document, equipment, foundation)
	TestAssertions.truthy(not decoded.ok(), "%s is rejected" % label, failures)
	TestAssertions.equal(decoded.item, null, "%s has no decoded item" % label, failures)
	TestAssertions.equal(decoded.error, expected_error, "%s error is exact" % label, failures)

func _make_item() -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = "item-explicit-round-trip"
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"legendary"
	var component_script := load("res://scripts/items/item_base_damage_component.gd") as Script if ResourceLoader.exists("res://scripts/items/item_base_damage_component.gd") else null
	if component_script != null:
		var components := item.get("base_damage_components") as Array
		components.append(component_script.call("create", &"physical", 3.0, 5.0))
		components.append(component_script.call("create", &"fire", 1.0, 2.0))
	item.affixes = [_make_affix(&"stout", "prefix", 1, &"constitution", StatModifier.Operation.FLAT, 3.0), _make_affix(&"of_reach", "suffix", 2, &"attack_range", StatModifier.Operation.INCREASED, 0.2)]
	item.origin = {"issuer_namespace": "profile:profile-a", "seed": 4402, "sequence": 42, "source": "quest_reward"}
	return item

func _make_affix(
	definition_id: StringName,
	affix_kind: String,
	tier: int,
	stat_id: StringName,
	operation: int,
	value: float
) -> ItemAffixInstance:
	var roll := ItemModifierRoll.new()
	roll.stat_id = stat_id
	roll.operation = operation
	roll.value = value
	roll.required_tags = []
	var affix := ItemAffixInstance.new()
	affix.definition_id = definition_id
	affix.affix_kind = affix_kind
	affix.tier = tier
	affix.rolls = [roll]
	return affix

func _document() -> Dictionary:
	return _make_item().to_dictionary()

func _mutated_document(field: String, value: Variant) -> Dictionary:
	var document := _document()
	document[field] = value
	return document

func _issue_data() -> Dictionary:
	var document := _document()
	document.erase("schema_version")
	document.erase("instance_id")
	document.erase("origin")
	return document


func _task9_item_document(
	instance_id: String,
	base_definition_id: String,
	affix_id: String,
	affix_kind: String,
	stat_id: String,
	operation: int,
	value: float,
	sequence: int,
) -> Dictionary:
	return {
		"affixes": [{
			"affix_kind": affix_kind,
			"definition_id": affix_id,
			"rolls": [{
				"operation": operation,
				"required_tags": [],
				"stat_id": stat_id,
				"value": value,
			}],
			"tier": 1,
		}],
		"base_definition_id": base_definition_id,
		"base_damage_components": [],
		"instance_id": instance_id,
		"item_level": 1,
		"origin": {
			"issuer_namespace": "run:task9-equipment-profile:9909:task9_equipment_player",
			"seed": 9909 + sequence,
			"sequence": sequence,
			"source": "task_9_equipment_attribute_application",
		},
		"rarity_id": "common",
		"schema_version": ItemInstance.SCHEMA_VERSION,
	}

func _literal_schema_one_fixture_document(fixture: Dictionary, tier: int, value: float) -> Dictionary:
	return {
		"affixes": [{
			"affix_kind": fixture["kind"],
			"definition_id": fixture["id"],
			"rolls": [{
				"operation": fixture["operation"],
				"required_tags": [],
				"stat_id": fixture["stat"],
				"value": value,
			}],
			"tier": tier,
		}],
		"base_definition_id": "forge_vanguard_sword",
		"instance_id": "historical-%s-tier-%d-%s" % [fixture["id"], tier, str(value).replace(".", "-")],
		"item_level": 1000,
		"origin": {
			"issuer_namespace": "historical-fixture-boundary",
			"seed": 4402,
			"sequence": tier,
			"source": "literal_schema_one",
		},
		"rarity_id": "legendary",
		"schema_version": 1,
	}
