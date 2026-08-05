class_name ItemInstance
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var instance_id: String
var base_definition_id: StringName
var item_level: int = 1
var rarity_id: StringName
var affixes: Array[ItemAffixInstance] = []
var origin: Dictionary = {}

func copy() -> ItemInstance:
	var result := ItemInstance.new()
	result.schema_version = schema_version
	result.instance_id = instance_id
	result.base_definition_id = base_definition_id
	result.item_level = item_level
	result.rarity_id = rarity_id
	for affix: ItemAffixInstance in affixes:
		result.affixes.append(affix.copy() if affix != null else null)
	result.origin = _json_copy(origin) as Dictionary
	return result

func to_dictionary() -> Dictionary:
	var affix_documents: Array[Dictionary] = []
	for affix: ItemAffixInstance in affixes:
		affix_documents.append(affix.to_dictionary() if affix != null else {})
	return {
		"affixes": affix_documents,
		"base_definition_id": String(base_definition_id),
		"instance_id": instance_id,
		"item_level": item_level,
		"origin": _json_copy(origin),
		"rarity_id": String(rarity_id),
		"schema_version": schema_version,
	}

static func _json_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value as StringName)
		TYPE_FLOAT:
			var number := float(value)
			if is_finite(number) and number == floor(number) and absf(number) <= 9007199254740991.0:
				return int(number)
			return number
		TYPE_ARRAY:
			var copied: Array = []
			for item: Variant in value as Array:
				copied.append(_json_copy(item))
			return copied
		TYPE_DICTIONARY:
			var source := value as Dictionary
			var keys: Array[String] = []
			for key: Variant in source:
				keys.append(String(key))
			keys.sort()
			var copied: Dictionary = {}
			for key: String in keys:
				var source_key: Variant = key if source.has(key) else StringName(key)
				copied[key] = _json_copy(source[source_key])
			return copied
		_:
			return value
