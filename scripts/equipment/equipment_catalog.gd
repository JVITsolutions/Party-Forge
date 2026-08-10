class_name EquipmentCatalog
extends Resource

const DAMAGE_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")
const PRODUCTION_BASE_COUNT := 99
const PRODUCTION_PROFILE_BASE_IDS: Array[StringName] = [
	&"emberweave_wand", &"forge_vanguard_hammer", &"forge_vanguard_sword",
	&"grave_covenant_bone_wand", &"greenwood_recurve_bow", &"nightstep_dagger_main",
	&"nightstep_dagger_off", &"rime_scholar_staff", &"siege_greatbow",
	&"storm_chaplain_sceptre", &"sunforged_warhammer",
]
const PRODUCTION_SUPPORT_BASE_IDS: Array[StringName] = [
	&"dawn_bulwark_shield", &"emberweave_flame_focus", &"forge_vanguard_shield",
	&"grave_covenant_grimoire", &"greenwood_light_quiver", &"siege_heavy_quiver",
	&"storm_chaplain_holy_tome",
]

@export var definitions: Array[EquipmentBaseDefinition] = []

func definition(id: StringName) -> EquipmentBaseDefinition:
	for value: EquipmentBaseDefinition in definitions:
		if value != null and value.id == id: return value
	return null

func size() -> int:
	return definitions.size()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for value: EquipmentBaseDefinition in definitions:
		if value == null:
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=<null> reason=definition missing")
			continue
		if seen.has(value.id): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=duplicate id" % value.id)
		seen[value.id] = true
		for reason: String in value.validate(DAMAGE_TYPES): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
		if value.presentation != null:
			for reason: String in value.presentation.validate(): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
	if definitions.size() == PRODUCTION_BASE_COUNT:
		_validate_production_assignments(errors)
	return errors

func _validate_production_assignments(errors: PackedStringArray) -> void:
	var implicit_owners: Dictionary = {}
	var profile_count := 0
	for value: EquipmentBaseDefinition in definitions:
		if value == null:
			continue
		if value.implicit_affix_ids.size() != 1:
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=production base requires exactly one implicit affix" % value.id)
		elif implicit_owners.has(value.implicit_affix_ids[0]):
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=production implicit %s is also assigned to %s" % [value.id, value.implicit_affix_ids[0], implicit_owners[value.implicit_affix_ids[0]]])
		else:
			implicit_owners[value.implicit_affix_ids[0]] = value.id
		if value.id in PRODUCTION_PROFILE_BASE_IDS:
			profile_count += 1
			var expected_id := StringName("weapon_profile_%s" % value.id)
			var expected_path := "res://data/items/weapon_profiles/%s.tres" % value.id
			if value.weapon_damage_profile == null:
				errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=production weapon damage profile is missing" % value.id)
			elif value.weapon_damage_profile.id != expected_id or value.weapon_damage_profile.resource_path != expected_path:
				errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=production weapon damage profile link must be %s at %s" % [value.id, expected_id, expected_path])
		elif value.weapon_damage_profile != null:
			var role := "support" if value.id in PRODUCTION_SUPPORT_BASE_IDS else "non-weapon"
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=production %s base must not have a weapon damage profile" % [value.id, role])
	if profile_count != PRODUCTION_PROFILE_BASE_IDS.size():
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=<catalog> reason=production profile link count must equal %d" % PRODUCTION_PROFILE_BASE_IDS.size())
