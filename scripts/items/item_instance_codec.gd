class_name ItemInstanceCodec
extends RefCounted

const JSON_SAFE_INTEGER_MAX := 9007199254740991
const ITEM_SCHEMA_ONE_FIELDS: Array[String] = ["affixes", "base_definition_id", "instance_id", "item_level", "origin", "rarity_id", "schema_version"]
const ITEM_SCHEMA_TWO_FIELDS: Array[String] = ["affixes", "base_damage_components", "base_definition_id", "instance_id", "item_level", "origin", "rarity_id", "schema_version"]
const BASE_DAMAGE_COMPONENT_FIELDS: Array[String] = ["damage_type_id", "minimum_damage", "maximum_damage"]
const AFFIX_FIELDS: Array[String] = ["affix_kind", "definition_id", "rolls", "tier"]
const ROLL_FIELDS: Array[String] = ["operation", "required_tags", "stat_id", "value"]
const ORIGIN_FIELDS: Array[String] = ["issuer_namespace", "seed", "sequence", "source"]

static func encode(item: ItemInstance) -> String:
	if item == null:
		return ""
	return JSON.stringify(item.to_dictionary())

static func decode(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemInstanceDecodeResult:
	var result := ItemInstanceDecodeResult.new()
	result.error = _validate_document(document, equipment, foundation)
	if not result.error.is_empty():
		return result
	var data := document as Dictionary
	var item := ItemInstance.new()
	item.schema_version = ItemInstance.SCHEMA_VERSION
	item.instance_id = data["instance_id"] as String
	item.base_definition_id = StringName(data["base_definition_id"] as String)
	item.item_level = int(data["item_level"])
	item.rarity_id = StringName(data["rarity_id"] as String)
	if int(data["schema_version"]) == ItemInstance.SCHEMA_VERSION:
		for component_value: Variant in data["base_damage_components"] as Array:
			var component_data := component_value as Dictionary
			item.base_damage_components.append(ItemBaseDamageComponent.create(
				StringName(component_data["damage_type_id"] as String),
				float(component_data["minimum_damage"]),
				float(component_data["maximum_damage"])
			))
	for affix_value: Variant in data["affixes"] as Array:
		var affix_data := affix_value as Dictionary
		var affix := ItemAffixInstance.new()
		affix.definition_id = StringName(affix_data["definition_id"] as String)
		affix.affix_kind = affix_data["affix_kind"] as String
		affix.tier = int(affix_data["tier"])
		for roll_value: Variant in affix_data["rolls"] as Array:
			var roll_data := roll_value as Dictionary
			var roll := ItemModifierRoll.new()
			roll.stat_id = StringName(roll_data["stat_id"] as String)
			roll.operation = int(roll_data["operation"])
			roll.value = float(roll_data["value"])
			for tag_value: Variant in roll_data["required_tags"] as Array:
				roll.required_tags.append(StringName(tag_value as String))
			affix.rolls.append(roll)
		item.affixes.append(affix)
	item.origin = ItemInstance._json_copy(data["origin"] as Dictionary) as Dictionary
	result.item = item
	return result

static func validate(
	item: ItemInstance,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> String:
	if item == null:
		return _field_error("item", "must not be null")
	return _validate_document(item.to_dictionary(), equipment, foundation)

static func _validate_document(
	document: Variant,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> String:
	if not document is Dictionary:
		return _field_error("document", "must be a dictionary")
	var data := document as Dictionary
	if not data.has("schema_version"):
		return _field_error("document", "missing fields schema_version")
	if not _is_json_int(data["schema_version"], 1, ItemInstance.SCHEMA_VERSION):
		return _field_error("schema_version", "must equal supported schema 1 or %d" % ItemInstance.SCHEMA_VERSION)
	var schema_version := int(data["schema_version"])
	var expected_fields := ITEM_SCHEMA_ONE_FIELDS if schema_version == 1 else ITEM_SCHEMA_TWO_FIELDS
	var fields_error := _exact_fields(data, expected_fields, "document")
	if not fields_error.is_empty():
		return fields_error
	if not _is_nonempty_string(data["instance_id"]):
		return _field_error("instance_id", "must be a non-empty string")
	if not _is_nonempty_string(data["base_definition_id"]):
		return _field_error("base_definition_id", "must be a non-empty string")
	if equipment == null:
		return _field_error("base_definition_id", "equipment catalog is missing")
	var base_id := StringName(data["base_definition_id"] as String)
	if equipment.definition(base_id) == null:
		return _field_error("base_definition_id", "unknown equipment base %s" % base_id)
	if not _is_json_int(data["item_level"], 1, JSON_SAFE_INTEGER_MAX):
		return _field_error("item_level", "must be a positive JSON-safe integer")
	if not _is_nonempty_string(data["rarity_id"]):
		return _field_error("rarity_id", "must be a non-empty string")
	if foundation == null:
		return _field_error("rarity_id", "item foundation catalog is missing")
	var rarity_id := StringName(data["rarity_id"] as String)
	var rarity := foundation.rarity(rarity_id)
	if rarity == null:
		return _field_error("rarity_id", "unknown rarity %s" % rarity_id)
	if not rarity.instance_supported:
		return _field_error("rarity_id", "rarity %s does not support item instances" % rarity_id)
	if schema_version == ItemInstance.SCHEMA_VERSION:
		var base_damage_error := _validate_base_damage_components(data["base_damage_components"])
		if not base_damage_error.is_empty():
			return base_damage_error
	if not data["affixes"] is Array:
		return _field_error("affixes", "must be an array")
	var seen_affixes: Dictionary = {}
	for affix_index: int in (data["affixes"] as Array).size():
		var affix_error := _validate_affix((data["affixes"] as Array)[affix_index], affix_index, foundation, seen_affixes)
		if not affix_error.is_empty():
			return affix_error
	return _validate_origin(data["origin"])

static func _validate_affix(
	value: Variant,
	index: int,
	foundation: ItemFoundationCatalog,
	seen_affixes: Dictionary
) -> String:
	var path := "affixes[%d]" % index
	if not value is Dictionary:
		return _field_error(path, "must be a dictionary")
	var data := value as Dictionary
	var fields_error := _exact_fields(data, AFFIX_FIELDS, path)
	if not fields_error.is_empty():
		return fields_error
	if not _is_nonempty_string(data["definition_id"]):
		return _field_error("%s.definition_id" % path, "must be a non-empty string")
	var definition_id := StringName(data["definition_id"] as String)
	if seen_affixes.has(definition_id):
		return _field_error("%s.definition_id" % path, "duplicate affix %s" % definition_id)
	seen_affixes[definition_id] = true
	var definition := foundation.affix(definition_id)
	if definition == null:
		return _field_error("%s.definition_id" % path, "unknown affix %s" % definition_id)
	if typeof(data["affix_kind"]) != TYPE_STRING or data["affix_kind"] != definition.affix_kind:
		return _field_error("%s.affix_kind" % path, "must match definition kind %s" % definition.affix_kind)
	if definition.tiers.is_empty():
		return _field_error("%s.tier" % path, "definition has no authored tiers")
	var minimum_tier := definition.tiers[0].tier
	var maximum_tier := definition.tiers[definition.tiers.size() - 1].tier
	if not _is_json_int(data["tier"], minimum_tier, maximum_tier) or definition.tier_definition(int(data["tier"])) == null:
		return _field_error("%s.tier" % path, "must be in definition range %d..%d" % [minimum_tier, maximum_tier])
	if not data["rolls"] is Array or (data["rolls"] as Array).size() != definition.effects.size():
		return _field_error("%s.rolls" % path, "must contain one roll per authored effect")
	for effect_index: int in definition.effects.size():
		var error := _validate_roll(
			(data["rolls"] as Array)[effect_index],
			"%s.rolls[%d]" % [path, effect_index],
			definition.effects[effect_index],
			definition.roll_bounds(int(data["tier"]), effect_index)
		)
		if not error.is_empty():
			return error
	return ""

static func _validate_roll(
	value: Variant,
	path: String,
	effect: ItemModifierEffectDefinition,
	bounds: Vector2
) -> String:
	if not value is Dictionary:
		return _field_error(path, "must be a dictionary")
	var data := value as Dictionary
	var fields_error := _exact_fields(data, ROLL_FIELDS, path)
	if not fields_error.is_empty():
		return fields_error
	if typeof(data["stat_id"]) != TYPE_STRING or StringName(data["stat_id"] as String) != effect.stat_id:
		return _field_error("%s.stat_id" % path, "must match definition stat %s" % effect.stat_id)
	if not _is_json_int(data["operation"], effect.operation, effect.operation):
		return _field_error("%s.operation" % path, "must match definition operation %d" % effect.operation)
	if not data["value"] is float and not data["value"] is int:
		return _field_error("%s.value" % path, "must be a finite number")
	var roll_value := float(data["value"])
	if not is_finite(roll_value):
		return _field_error("%s.value" % path, "must be a finite number")
	if (roll_value < bounds.x and not is_equal_approx(roll_value, bounds.x)) or (roll_value > bounds.y and not is_equal_approx(roll_value, bounds.y)):
		return _field_error("%s.value" % path, "must be within issued bounds %s..%s" % [_number_text(bounds.x), _number_text(bounds.y)])
	if not data["required_tags"] is Array:
		return _field_error("%s.required_tags" % path, "must be an array of strings")
	var actual_tags: Array[StringName] = []
	for tag_value: Variant in data["required_tags"] as Array:
		if typeof(tag_value) != TYPE_STRING:
			return _field_error("%s.required_tags" % path, "must be an array of strings")
		actual_tags.append(StringName(tag_value as String))
	if actual_tags != effect.required_tags:
		return _field_error("%s.required_tags" % path, "must match definition required tags")
	return ""

static func _validate_base_damage_components(value: Variant) -> String:
	if not value is Array:
		return _field_error("base_damage_components", "must be an array")
	var seen_types: Dictionary = {}
	for index: int in (value as Array).size():
		var path := "base_damage_components[%d]" % index
		var component_value: Variant = (value as Array)[index]
		if not component_value is Dictionary:
			return _field_error(path, "must be a dictionary")
		var data := component_value as Dictionary
		var fields_error := _exact_fields(data, BASE_DAMAGE_COMPONENT_FIELDS, path)
		if not fields_error.is_empty():
			return fields_error
		if typeof(data["damage_type_id"]) != TYPE_STRING:
			return _field_error("%s.damage_type_id" % path, "must be a non-empty string")
		for field: String in ["minimum_damage", "maximum_damage"]:
			if not data[field] is float and not data[field] is int:
				return _field_error("%s.%s" % [path, field], "must be a finite number")
		var component := ItemBaseDamageComponent.create(
			StringName(data["damage_type_id"] as String),
			float(data["minimum_damage"]),
			float(data["maximum_damage"])
		)
		var component_error := component.validate(GameCatalog.DAMAGE_TYPES)
		if not component_error.is_empty():
			return component_error.replace(
				"PARTY_FORGE_ITEM_BASE_DAMAGE_ERROR field=",
				"PARTY_FORGE_ITEM_ERROR field=%s." % path
			)
		if seen_types.has(component.damage_type_id):
			return _field_error("%s.damage_type_id" % path, "duplicate damage type %s" % component.damage_type_id)
		seen_types[component.damage_type_id] = true
	return ""

static func _validate_origin(value: Variant) -> String:
	if not value is Dictionary:
		return _field_error("origin", "must be a dictionary")
	var data := value as Dictionary
	var fields_error := _exact_fields(data, ORIGIN_FIELDS, "origin")
	if not fields_error.is_empty():
		return fields_error
	if not _is_nonempty_string(data["issuer_namespace"]):
		return _field_error("origin.issuer_namespace", "must be a non-empty string")
	if not _is_json_int(data["sequence"], 0, JSON_SAFE_INTEGER_MAX):
		return _field_error("origin.sequence", "must be a non-negative JSON-safe integer")
	for field: String in ["seed", "source"]:
		if not _is_json_value(data[field]):
			return _field_error("origin.%s" % field, "must be JSON-safe")
	return ""

static func _exact_fields(data: Dictionary, expected: Array[String], path: String) -> String:
	var missing: Array[String] = []
	for field: String in expected:
		if not data.has(field):
			missing.append(field)
	var unexpected: Array[String] = []
	for key: Variant in data:
		if typeof(key) != TYPE_STRING:
			unexpected.append(String(key))
		elif key as String not in expected:
			unexpected.append(key as String)
	unexpected.sort()
	if missing.is_empty() and unexpected.is_empty():
		return ""
	var reasons: Array[String] = []
	if not missing.is_empty():
		reasons.append("missing fields %s" % ",".join(missing))
	if not unexpected.is_empty():
		reasons.append("unexpected fields %s" % ",".join(unexpected))
	return _field_error(path, "; ".join(reasons))

static func _is_nonempty_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty()

static func _is_json_int(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= float(minimum) and number <= float(maximum)

static func _is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return int(value) >= -JSON_SAFE_INTEGER_MAX and int(value) <= JSON_SAFE_INTEGER_MAX
		TYPE_FLOAT:
			var number := float(value)
			return is_finite(number) and (number != floor(number) or (number >= -float(JSON_SAFE_INTEGER_MAX) and number <= float(JSON_SAFE_INTEGER_MAX)))
		TYPE_ARRAY:
			return (value as Array).all(func(item: Variant) -> bool: return _is_json_value(item))
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if typeof(key) != TYPE_STRING or not _is_json_value((value as Dictionary)[key]):
					return false
			return true
		_:
			return false

static func _number_text(value: float) -> String:
	return str(int(value)) if value == floor(value) else str(value)

static func _field_error(field: String, reason: String) -> String:
	return "PARTY_FORGE_ITEM_ERROR field=%s reason=%s" % [field, reason]
