class_name BuildWeightedLootContent
extends SceneTree

const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const STATS_PATH := "res://data/stats/core_stats.tres"
const DAMAGE_TYPES_PATH := "res://data/damage_types/core_damage_types.tres"
const ROWS := preload("res://tools/weighted_loot_content_rows.gd")
const RARITY_PATHS: Array[String] = [
	"res://data/items/rarities/common.tres",
	"res://data/items/rarities/uncommon.tres",
	"res://data/items/rarities/rare.tres",
	"res://data/items/rarities/epic.tres",
	"res://data/items/rarities/legendary.tres",
	"res://data/items/rarities/mythic.tres",
	"res://data/items/rarities/exotic.tres",
	"res://data/items/rarities/ascendant.tres",
	"res://data/items/rarities/divine.tres",
	"res://data/items/rarities/eternal.tres",
]
const KNOWN_SOURCE_IDS: Array[StringName] = [&"ordinary_enemy", &"boss", &"developer"]
const ORDINARY_RARITY_IDS: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]

static var _error_record: Dictionary = {}

func _initialize() -> void:
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var stats := load(STATS_PATH) as StatCatalog
	var damage_types := load(DAMAGE_TYPES_PATH) as DamageTypeCatalog
	var documents := build_document_set(equipment, stats, damage_types)
	if documents.is_empty():
		quit(1)
		return
	for path_variant: Variant in documents.keys():
		var path := String(path_variant)
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		if directory_error != OK:
			_fail("write", path, "directory error %d" % directory_error)
			quit(1)
			return
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_fail("write", path, "file error %d" % FileAccess.get_open_error())
			quit(1)
			return
		file.store_string(String(documents[path]))
		file.close()
	print("PARTY_FORGE_WEIGHTED_CONTENT_BUILD_OK documents=%d" % documents.size())
	quit(0)

static func build_document_set(
	equipment: EquipmentCatalog,
	stats: StatCatalog,
	damage_types: DamageTypeCatalog
) -> Dictionary:
	_error_record = {}
	if equipment == null:
		return _failed("inputs", "equipment", "catalog is missing")
	if stats == null:
		return _failed("inputs", "stats", "catalog is missing")
	if damage_types == null:
		return _failed("inputs", "damage_types", "catalog is missing")
	var explicit_rows: Array[Dictionary] = ROWS.explicit_rows()
	var implicit_rows: Array[Dictionary] = ROWS.implicit_rows(equipment)
	var profile_rows: Array[Dictionary] = ROWS.weapon_profile_rows()
	var row_error := _validate_source_rows(explicit_rows, implicit_rows, profile_rows, equipment)
	if not row_error.is_empty():
		return _failed("rows", String(row_error.get("id", "catalog")), String(row_error.get("reason", "invalid rows")))

	var affixes: Array[ItemAffixDefinition] = []
	var affix_by_id: Dictionary = {}
	for row: Dictionary in explicit_rows + implicit_rows:
		var definition := _affix_from_row(row)
		definition.take_over_path(String(row["output_path"]))
		affixes.append(definition)
		affix_by_id[definition.id] = definition
	affixes.sort_custom(func(left: ItemAffixDefinition, right: ItemAffixDefinition) -> bool: return String(left.id) < String(right.id))

	var profiles: Array[WeaponDamageProfile] = []
	var profile_by_base: Dictionary = {}
	for row: Dictionary in profile_rows:
		var profile := _weapon_profile_from_row(row)
		profile.take_over_path(String(row["output_path"]))
		profiles.append(profile)
		profile_by_base[row["base"]] = profile
	profiles.sort_custom(func(left: WeaponDamageProfile, right: WeaponDamageProfile) -> bool: return String(left.id) < String(right.id))

	var production_equipment := EquipmentCatalog.new()
	var production_bases: Array[EquipmentBaseDefinition] = []
	var implicit_by_base: Dictionary = {}
	for row: Dictionary in implicit_rows:
		implicit_by_base[row["base"]] = row["id"]
	for source: EquipmentBaseDefinition in equipment.definitions:
		var base := source.duplicate(true) as EquipmentBaseDefinition
		base.presentation = source.presentation
		var implicit_ids: Array[StringName] = [implicit_by_base[source.id]]
		base.implicit_affix_ids = implicit_ids
		base.weapon_damage_profile = profile_by_base.get(source.id) as WeaponDamageProfile
		production_bases.append(base)
	production_equipment.definitions = production_bases

	var foundation := ItemFoundationCatalog.new()
	foundation.modifier_family_ids = _modifier_families(affixes)
	foundation.known_source_ids = KNOWN_SOURCE_IDS.duplicate()
	foundation.known_item_tags = _known_item_tags(production_equipment)
	foundation.rarities = _load_rarities()
	foundation.affixes = affixes
	if foundation.rarities.size() != RARITY_PATHS.size():
		return _failed("rarities", "catalog", "one or more rarity resources failed to load")
	var equipment_errors := production_equipment.validate()
	if not equipment_errors.is_empty():
		return _failed("equipment", "catalog", equipment_errors[0])
	var foundation_errors := foundation.validate(stats, production_equipment)
	if not foundation_errors.is_empty():
		return _failed("foundation", "catalog", foundation_errors[0])

	var documents: Dictionary = {}
	for definition: ItemAffixDefinition in affixes:
		documents[definition.resource_path] = _affix_document(definition)
	for profile: WeaponDamageProfile in profiles:
		documents[profile.resource_path] = _weapon_profile_document(profile)
	for index: int in equipment.definitions.size():
		var source := equipment.definitions[index]
		var base := production_bases[index]
		documents[source.resource_path] = _equipment_base_document(source, base)
	documents[FOUNDATION_PATH] = _foundation_document(foundation)
	if documents.size() != 306:
		return _failed("documents", "catalog", "document total must equal 306, got %d" % documents.size())
	return _canonical_documents(documents)

static func _validate_source_rows(
	explicit_rows: Array[Dictionary],
	implicit_rows: Array[Dictionary],
	profile_rows: Array[Dictionary],
	equipment: EquipmentCatalog
) -> Dictionary:
	if explicit_rows.size() != 96:
		return {"id": "explicit", "reason": "row total must equal 96"}
	if implicit_rows.size() != 99:
		return {"id": "implicit", "reason": "row total must equal 99"}
	if profile_rows.size() != 11:
		return {"id": "profiles", "reason": "row total must equal 11"}
	if equipment.size() != 99:
		return {"id": "equipment", "reason": "base total must equal 99"}
	var ids: Dictionary = {}
	var paths: Dictionary = {}
	var category_counts := {"focused": 0, "standard_hybrid": 0, "premium_hybrid": 0, "implicit": 0}
	var side_counts := {"prefix": 0, "suffix": 0, "implicit": 0}
	for row: Dictionary in explicit_rows + implicit_rows:
		var id: StringName = row.get("id", &"")
		var path := String(row.get("output_path", ""))
		if id.is_empty() or ids.has(id):
			return {"id": String(id), "reason": "affix id is empty or duplicated"}
		if path.is_empty() or paths.has(path):
			return {"id": String(id), "reason": "output path is empty or duplicated"}
		ids[id] = true
		paths[path] = true
		var category := String(row.get("category", ""))
		var side := String(row.get("side", ""))
		if not category_counts.has(category) or not side_counts.has(side):
			return {"id": String(id), "reason": "category or side is unsupported"}
		category_counts[category] = int(category_counts[category]) + 1
		side_counts[side] = int(side_counts[side]) + 1
		if (row.get("tiers", []) as Array).size() != 12:
			return {"id": String(id), "reason": "tier total must equal 12"}
	if category_counts != {"focused": 64, "standard_hybrid": 24, "premium_hybrid": 8, "implicit": 99}:
		return {"id": "categories", "reason": "category totals are invalid"}
	if side_counts != {"prefix": 48, "suffix": 48, "implicit": 99}:
		return {"id": "sides", "reason": "side totals are invalid"}
	var assigned_bases: Dictionary = {}
	for row: Dictionary in implicit_rows:
		var base_id: StringName = row.get("base", &"")
		if equipment.definition(base_id) == null or assigned_bases.has(base_id):
			return {"id": String(base_id), "reason": "implicit base assignment is missing or duplicated"}
		assigned_bases[base_id] = true
	var profile_bases: Dictionary = {}
	for row: Dictionary in profile_rows:
		var base_id: StringName = row.get("base", &"")
		var path := String(row.get("output_path", ""))
		if equipment.definition(base_id) == null or profile_bases.has(base_id):
			return {"id": String(base_id), "reason": "weapon profile base is missing or duplicated"}
		if paths.has(path):
			return {"id": String(base_id), "reason": "weapon profile output path is duplicated"}
		profile_bases[base_id] = true
		paths[path] = true
	return {}

static func _affix_from_row(row: Dictionary) -> ItemAffixDefinition:
	var definition := ItemAffixDefinition.new()
	definition.id = row["id"]
	definition.display_name = String(row["display_name"])
	definition.affix_kind = String(row["side"])
	definition.base_weight = float(row["base_weight"])
	definition.modifier_family_ids = _sorted_string_names(row["modifier_family_ids"])
	var required_tag: StringName = row.get("required_item_tag", &"")
	var required_tags: Array[StringName] = []
	if not required_tag.is_empty():
		required_tags.append(required_tag)
	definition.required_item_tags = required_tags
	definition.affinity_tags = _sorted_string_names(row.get("affinity_tags", []))
	definition.allowed_generation_domains = ItemGenerationVocabulary.DOMAINS.duplicate()
	definition.allowed_source_ids = KNOWN_SOURCE_IDS.duplicate()
	definition.allowed_rarity_ids = ORDINARY_RARITY_IDS.duplicate()
	var effect_rows: Array = row["effects"]
	var effect_order: Array[int] = []
	for index: int in effect_rows.size():
		effect_order.append(index)
	effect_order.sort_custom(func(left: int, right: int) -> bool:
		var left_row := effect_rows[left] as Dictionary
		var right_row := effect_rows[right] as Dictionary
		var left_key := "%s:%d" % [left_row["stat_id"], int(left_row["operation"])]
		var right_key := "%s:%d" % [right_row["stat_id"], int(right_row["operation"])]
		return left_key < right_key
	)
	var effects: Array[ItemModifierEffectDefinition] = []
	for source_index: int in effect_order:
		var source := effect_rows[source_index] as Dictionary
		var effect := ItemModifierEffectDefinition.new()
		effect.stat_id = source["stat_id"]
		effect.operation = int(source["operation"])
		effects.append(effect)
	definition.effects = effects
	var tiers: Array[ItemAffixTierDefinition] = []
	for tier_row: Dictionary in row["tiers"]:
		var tier := ItemAffixTierDefinition.new()
		tier.tier = int(tier_row["tier"])
		tier.minimum_item_level = int(tier_row["minimum_item_level"])
		tier.base_weight = float(tier_row["base_weight"])
		var source_minimums: Array = tier_row["minimum_rolls"]
		var source_maximums: Array = tier_row["maximum_rolls"]
		for source_index: int in effect_order:
			tier.minimum_rolls.append(float(source_minimums[source_index]))
			tier.maximum_rolls.append(float(source_maximums[source_index]))
		tier.allowed_rarity_ids = _rarity_ceiling(tier.tier)
		tiers.append(tier)
	definition.tiers = tiers
	return definition

static func _weapon_profile_from_row(row: Dictionary) -> WeaponDamageProfile:
	var profile := WeaponDamageProfile.new()
	profile.id = row["id"]
	profile.minimum_item_level = int(row["minimum_item_level"])
	profile.quality_minimum = float(row["quality_minimum"])
	profile.quality_maximum = float(row["quality_maximum"])
	var component_rows: Array = row["components"]
	component_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["damage_type_id"]) < String(right["damage_type_id"]))
	var components: Array[WeaponDamageComponentCurve] = []
	for component_row: Dictionary in component_rows:
		var component := WeaponDamageComponentCurve.new()
		component.damage_type_id = component_row["damage_type_id"]
		component.minimum_at_level_1 = float(component_row["minimum_at_level_1"])
		component.maximum_at_level_1 = float(component_row["maximum_at_level_1"])
		component.minimum_at_level_1000 = float(component_row["minimum_at_level_1000"])
		component.maximum_at_level_1000 = float(component_row["maximum_at_level_1000"])
		components.append(component)
	profile.components = components
	return profile

static func _load_rarities() -> Array[ItemRarityDefinition]:
	var result: Array[ItemRarityDefinition] = []
	for path: String in RARITY_PATHS:
		var rarity := load(path) as ItemRarityDefinition
		if rarity != null:
			result.append(rarity)
	return result

static func _modifier_families(affixes: Array[ItemAffixDefinition]) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: ItemAffixDefinition in affixes:
		for family_id: StringName in definition.modifier_family_ids:
			if family_id not in result:
				result.append(family_id)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

static func _known_item_tags(equipment: EquipmentCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	for base: EquipmentBaseDefinition in equipment.definitions:
		for tag: StringName in base.normalized_generation_tags():
			if tag not in result:
				result.append(tag)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

static func _rarity_ceiling(tier: int) -> Array[StringName]:
	if tier <= 3:
		return [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
	if tier <= 5:
		return [&"uncommon", &"rare", &"epic", &"legendary"]
	if tier <= 8:
		return [&"rare", &"epic", &"legendary"]
	if tier <= 10:
		return [&"epic", &"legendary"]
	return [&"legendary"]

static func _canonical_documents(documents: Dictionary) -> Dictionary:
	var paths: Array[String] = []
	for path_variant: Variant in documents.keys():
		paths.append(String(path_variant))
	paths.sort()
	var result: Dictionary = {}
	for path: String in paths:
		result[path] = documents[path]
	return result

static func _affix_document(definition: ItemAffixDefinition) -> String:
	var lines: Array[String] = []
	var load_steps := 1 + 3 + definition.effects.size() + definition.tiers.size()
	lines.append("[gd_resource type=\"Resource\" script_class=\"ItemAffixDefinition\" load_steps=%d format=3]" % load_steps)
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/item_affix_definition.gd\" id=\"1_affix\"]")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/item_modifier_effect_definition.gd\" id=\"2_effect\"]")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/item_affix_tier_definition.gd\" id=\"3_tier\"]")
	for index: int in definition.effects.size():
		var effect := definition.effects[index]
		lines.append("")
		lines.append("[sub_resource type=\"Resource\" id=\"Effect%d\"]" % (index + 1))
		lines.append("script = ExtResource(\"2_effect\")")
		lines.append("stat_id = %s" % _value_text(effect.stat_id))
		lines.append("operation = %d" % effect.operation)
		if not effect.required_tags.is_empty():
			lines.append("required_tags = %s" % _string_name_array_text(effect.required_tags))
	for tier: ItemAffixTierDefinition in definition.tiers:
		lines.append("")
		lines.append("[sub_resource type=\"Resource\" id=\"Tier%d\"]" % tier.tier)
		lines.append("script = ExtResource(\"3_tier\")")
		lines.append("tier = %d" % tier.tier)
		lines.append("minimum_item_level = %d" % tier.minimum_item_level)
		lines.append("base_weight = %s" % _value_text(tier.base_weight))
		lines.append("minimum_rolls = %s" % _float_array_text(tier.minimum_rolls))
		lines.append("maximum_rolls = %s" % _float_array_text(tier.maximum_rolls))
		lines.append("allowed_rarity_ids = %s" % _string_name_array_text(tier.allowed_rarity_ids))
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1_affix\")")
	lines.append("id = %s" % _value_text(definition.id))
	lines.append("display_name = %s" % _value_text(definition.display_name))
	lines.append("affix_kind = %s" % _value_text(definition.affix_kind))
	lines.append("base_weight = %s" % _value_text(definition.base_weight))
	lines.append("modifier_family_ids = %s" % _string_name_array_text(definition.modifier_family_ids))
	if not definition.required_item_tags.is_empty():
		lines.append("required_item_tags = %s" % _string_name_array_text(definition.required_item_tags))
	if not definition.affinity_tags.is_empty():
		lines.append("affinity_tags = %s" % _string_name_array_text(definition.affinity_tags))
	lines.append("allowed_generation_domains = %s" % _string_name_array_text(definition.allowed_generation_domains))
	lines.append("allowed_source_ids = %s" % _string_name_array_text(definition.allowed_source_ids))
	lines.append("allowed_rarity_ids = %s" % _string_name_array_text(definition.allowed_rarity_ids))
	lines.append("effects = Array[ExtResource(\"2_effect\")]([%s])" % _subresource_references("Effect", definition.effects.size()))
	lines.append("tiers = Array[ExtResource(\"3_tier\")]([%s])" % _subresource_references("Tier", definition.tiers.size()))
	return "\n".join(lines) + "\n"

static func _weapon_profile_document(profile: WeaponDamageProfile) -> String:
	var lines: Array[String] = []
	lines.append("[gd_resource type=\"Resource\" script_class=\"WeaponDamageProfile\" load_steps=%d format=3]" % (3 + profile.components.size()))
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/weapon_damage_profile.gd\" id=\"1_profile\"]")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/weapon_damage_component_curve.gd\" id=\"2_curve\"]")
	for index: int in profile.components.size():
		var component := profile.components[index]
		lines.append("")
		lines.append("[sub_resource type=\"Resource\" id=\"Component%d\"]" % (index + 1))
		lines.append("script = ExtResource(\"2_curve\")")
		lines.append("damage_type_id = %s" % _value_text(component.damage_type_id))
		lines.append("minimum_at_level_1 = %s" % _value_text(component.minimum_at_level_1))
		lines.append("maximum_at_level_1 = %s" % _value_text(component.maximum_at_level_1))
		lines.append("minimum_at_level_1000 = %s" % _value_text(component.minimum_at_level_1000))
		lines.append("maximum_at_level_1000 = %s" % _value_text(component.maximum_at_level_1000))
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1_profile\")")
	lines.append("id = %s" % _value_text(profile.id))
	lines.append("minimum_item_level = %d" % profile.minimum_item_level)
	lines.append("quality_minimum = %s" % _value_text(profile.quality_minimum))
	lines.append("quality_maximum = %s" % _value_text(profile.quality_maximum))
	lines.append("components = Array[ExtResource(\"2_curve\")]([%s])" % _subresource_references("Component", profile.components.size()))
	return "\n".join(lines) + "\n"

static func _equipment_base_document(source: EquipmentBaseDefinition, base: EquipmentBaseDefinition) -> String:
	var profile_path := base.weapon_damage_profile.resource_path if base.weapon_damage_profile != null else ""
	var load_steps := 3 + (1 if not profile_path.is_empty() else 0)
	var lines: Array[String] = []
	lines.append("[gd_resource type=\"Resource\" script_class=\"EquipmentBaseDefinition\" load_steps=%d format=3]" % load_steps)
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_base_definition.gd\" id=\"1_base\"]")
	lines.append("[ext_resource type=\"Resource\" path=%s id=\"2_presentation\"]" % _value_text(source.presentation.resource_path))
	if not profile_path.is_empty():
		lines.append("[ext_resource type=\"Resource\" path=%s id=\"3_profile\"]" % _value_text(profile_path))
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1_base\")")
	lines.append("id = %s" % _value_text(base.id))
	lines.append("display_name = %s" % _value_text(base.display_name))
	lines.append("item_type_id = %s" % _value_text(base.item_type_id))
	lines.append("compatible_slot_ids = %s" % _string_name_array_text(base.compatible_slot_ids))
	lines.append("weight_class_id = %s" % _value_text(base.weight_class_id))
	if not base.required_all_tags.is_empty(): lines.append("required_all_tags = %s" % _string_name_array_text(base.required_all_tags))
	if not base.required_any_tags.is_empty(): lines.append("required_any_tags = %s" % _string_name_array_text(base.required_any_tags))
	if not base.excluded_tags.is_empty(): lines.append("excluded_tags = %s" % _string_name_array_text(base.excluded_tags))
	lines.append("generation_weight = %s" % _value_text(base.generation_weight))
	if not base.generation_tags.is_empty(): lines.append("generation_tags = %s" % _string_name_array_text(base.generation_tags))
	lines.append("implicit_affix_ids = %s" % _string_name_array_text(base.implicit_affix_ids))
	if not base.attribute_requirements.is_empty(): lines.append("attribute_requirements = %s" % _value_text(base.attribute_requirements))
	lines.append("handedness_id = %s" % _value_text(base.handedness_id))
	if not base.reserved_slot_ids.is_empty(): lines.append("reserved_slot_ids = %s" % _string_name_array_text(base.reserved_slot_ids))
	if not base.compatible_offhand_item_types.is_empty(): lines.append("compatible_offhand_item_types = %s" % _string_name_array_text(base.compatible_offhand_item_types))
	if not base.weapon_family_id.is_empty(): lines.append("weapon_family_id = %s" % _value_text(base.weapon_family_id))
	if base.weapon_damage_profile != null: lines.append("weapon_damage_profile = ExtResource(\"3_profile\")")
	lines.append("implicit_family_id = %s" % _value_text(base.implicit_family_id))
	lines.append("presentation = ExtResource(\"2_presentation\")")
	return "\n".join(lines) + "\n"

static func _foundation_document(foundation: ItemFoundationCatalog) -> String:
	var lines: Array[String] = []
	var ext_count := 1 + foundation.rarities.size() + foundation.affixes.size()
	lines.append("[gd_resource type=\"Resource\" script_class=\"ItemFoundationCatalog\" load_steps=%d format=3]" % (ext_count + 1))
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/items/item_foundation_catalog.gd\" id=\"1_catalog\"]")
	var next_id := 2
	var rarity_refs: Array[String] = []
	for rarity: ItemRarityDefinition in foundation.rarities:
		var id := str(next_id)
		lines.append("[ext_resource type=\"Resource\" path=%s id=%s]" % [_value_text(rarity.resource_path), _value_text(id)])
		rarity_refs.append("ExtResource(%s)" % _value_text(id))
		next_id += 1
	var affix_refs: Array[String] = []
	for definition: ItemAffixDefinition in foundation.affixes:
		var id := str(next_id)
		lines.append("[ext_resource type=\"Resource\" path=%s id=%s]" % [_value_text(definition.resource_path), _value_text(id)])
		affix_refs.append("ExtResource(%s)" % _value_text(id))
		next_id += 1
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1_catalog\")")
	lines.append("modifier_family_ids = %s" % _string_name_array_text(foundation.modifier_family_ids))
	lines.append("known_source_ids = %s" % _string_name_array_text(foundation.known_source_ids))
	lines.append("known_item_tags = %s" % _string_name_array_text(foundation.known_item_tags))
	lines.append("rarities = Array[ItemRarityDefinition]([%s])" % ", ".join(rarity_refs))
	lines.append("affixes = Array[ItemAffixDefinition]([%s])" % ", ".join(affix_refs))
	return "\n".join(lines) + "\n"

static func _subresource_references(prefix: String, count: int) -> String:
	var result: Array[String] = []
	for index: int in count:
		result.append("SubResource(\"%s%d\")" % [prefix, index + 1])
	return ", ".join(result)

static func _sorted_string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		var tag := StringName(value)
		if not tag.is_empty() and tag not in result:
			result.append(tag)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

static func _string_name_array_text(values: Array[StringName]) -> String:
	var parts: Array[String] = []
	for value: StringName in values:
		parts.append(_value_text(value))
	return "Array[StringName]([%s])" % ", ".join(parts)

static func _float_array_text(values: Array[float]) -> String:
	var parts: Array[String] = []
	for value: float in values:
		parts.append(_value_text(value))
	return "Array[float]([%s])" % ", ".join(parts)

static func _value_text(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING_NAME:
			return "&%s" % JSON.stringify(String(value))
		TYPE_STRING:
			return JSON.stringify(String(value))
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return str(float(value))
		TYPE_ARRAY:
			var parts: Array[String] = []
			for entry: Variant in value:
				parts.append(_value_text(entry))
			return "[%s]" % ", ".join(parts)
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
			var parts: Array[String] = []
			for key: Variant in keys:
				parts.append("%s: %s" % [_value_text(key), _value_text((value as Dictionary)[key])])
			return "{%s}" % ", ".join(parts)
	return str(value)

static func _failed(stage: String, id: String, reason: String) -> Dictionary:
	_fail(stage, id, reason)
	return {}

static func _fail(stage: String, id: String, reason: String) -> void:
	if not _error_record.is_empty():
		return
	_error_record = {"stage": stage, "id": id, "reason": reason}
	printerr("PARTY_FORGE_WEIGHTED_CONTENT_BUILD_ERROR stage=%s id=%s reason=%s" % [stage, id, reason.replace("\n", " ")])
