class_name ClassEquipmentRows
extends RefCounted

const SET_ITEM_IDS := {
	&"paladin": [&"dawn_bulwark_crown", &"dawn_bulwark_plate", &"dawn_bulwark_greaves", &"dawn_bulwark_gauntlets", &"dawn_bulwark_sabatons", &"sun_oath_amulet", &"ring_of_vigil", &"ring_of_mercy", &"dawn_bulwark_belt", &"sunforged_warhammer", &"dawn_bulwark_shield"],
	&"ranger": [&"greenwood_hood", &"greenwood_jerkin", &"greenwood_leggings", &"greenwood_gloves", &"greenwood_boots", &"trailmark_amulet", &"hawkeye_band", &"windrunner_band", &"greenwood_belt", &"greenwood_recurve_bow", &"greenwood_light_quiver"],
	&"marksman": [&"siege_archer_cowl", &"siege_archer_coat", &"siege_archer_braced_leggings", &"siege_archer_draw_glove", &"siege_archer_boots", &"farshot_amulet", &"steady_hand_ring", &"long_watch_ring", &"siege_archer_draw_belt", &"siege_greatbow", &"siege_heavy_quiver"],
	&"rogue": [&"nightstep_hood", &"nightstep_leathers", &"nightstep_leggings", &"nightstep_grip_gloves", &"nightstep_soft_boots", &"shadowchain_amulet", &"silent_edge_ring", &"bloodstep_ring", &"nightstep_utility_belt", &"nightstep_dagger_main", &"nightstep_dagger_off"],
	&"mage": [&"emberweave_circlet", &"emberweave_robe", &"emberweave_leggings", &"emberweave_spell_gloves", &"emberweave_shoes", &"emberheart_amulet", &"cinder_ring", &"conflagration_ring", &"emberweave_rune_sash", &"emberweave_wand", &"emberweave_flame_focus"],
	&"frost_mage": [&"rime_scholar_circlet", &"rime_scholar_robe", &"rime_scholar_leggings", &"rime_scholar_gloves", &"rime_scholar_boots", &"winterglass_amulet", &"hoarfrost_ring", &"stillwater_ring", &"rime_scholar_crystal_sash", &"rime_scholar_staff"],
	&"cleric": [&"storm_chaplain_hood", &"storm_chaplain_vestments", &"storm_chaplain_leggings", &"storm_chaplain_prayer_gloves", &"storm_chaplain_boots", &"storm_chaplain_reliquary", &"storm_ring", &"mercy_ring", &"storm_chaplain_belt", &"storm_chaplain_sceptre", &"storm_chaplain_holy_tome"],
	&"warlock": [&"grave_covenant_hood", &"grave_covenant_robe", &"grave_covenant_leggings", &"grave_covenant_ritual_gloves", &"grave_covenant_wrapped_boots", &"grave_covenant_bone_amulet", &"withering_ring", &"pact_ring", &"grave_covenant_chained_sash", &"grave_covenant_bone_wand", &"grave_covenant_grimoire"],
	&"fighter": [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves", &"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"],
}
const SET_FOLDERS := {
	&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood",
	&"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave",
	&"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant",
}

static func total_item_count() -> int:
	var total := 0
	for ids: Array in SET_ITEM_IDS.values(): total += ids.size()
	return total

static func slot_for(set_id: StringName, index: int) -> StringName:
	if set_id == &"fighter" and index == 11: return &"main_hand"
	return EquipmentSlotCatalog.SHEET_SLOT_IDS[index]

static func compatible_slots(slot_id: StringName) -> Array[StringName]:
	var slots: Array[StringName] = []
	if slot_id in [&"ring_left", &"ring_right"]:
		slots.append(&"ring_left")
		slots.append(&"ring_right")
	else:
		slots.append(slot_id)
	return slots

static func display_name_for(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()

static func make_base(id: StringName, slot_id: StringName) -> EquipmentBaseDefinition:
	var value := EquipmentBaseDefinition.new()
	value.id = id; value.display_name = display_name_for(id)
	value.item_type_id = &"ring" if slot_id in [&"ring_left", &"ring_right"] else slot_id
	value.compatible_slot_ids = compatible_slots(slot_id)
	if id == &"rime_scholar_staff":
		value.handedness_id = &"two_hand"
		var reserved_slots: Array[StringName] = []
		reserved_slots.append(&"off_hand")
		value.reserved_slot_ids = reserved_slots
	else:
		value.handedness_id = &"none"
	return value
