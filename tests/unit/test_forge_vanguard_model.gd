extends RefCounted

const PROFILE_PATH := "res://data/presentation/profiles/forge_vanguard.tres"
const EQUIPMENT_PATHS: Dictionary = {
	&"main_hand": "res://data/presentation/equipment/forge_vanguard_sword.tres",
	&"off_hand": "res://data/presentation/equipment/forge_vanguard_shield.tres",
	&"helmet": "res://data/presentation/equipment/forge_vanguard_helmet.tres",
	&"body_armour": "res://data/presentation/equipment/forge_vanguard_armour.tres",
	&"gloves": "res://data/presentation/equipment/forge_vanguard_gauntlets.tres",
	&"boots": "res://data/presentation/equipment/forge_vanguard_boots.tres",
	&"belt": "res://data/presentation/equipment/forge_vanguard_belt.tres",
	&"amulet": "res://data/presentation/equipment/forge_vanguard_amulet.tres",
	&"ring_left": "res://data/presentation/equipment/forge_vanguard_ring_left.tres",
	&"ring_right": "res://data/presentation/equipment/forge_vanguard_ring_right.tres",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := load(PROFILE_PATH) as CharacterVisualProfile
	TestAssertions.truthy(profile != null, "Forge Vanguard profile loads", failures)
	if profile == null or profile.presentation_scene == null:
		return failures
	TestAssertions.equal(profile.palette_colors.keys().size(), 3, "three palettes", failures)
	TestAssertions.equal(profile.validate(), PackedStringArray(), "Forge Vanguard profile validates", failures)
	var model := profile.presentation_scene.instantiate() as Node3D
	TestAssertions.truthy(model != null and model.has_method(&"set_body_preset"), "model implements body API", failures)
	if model == null:
		return failures
	TestAssertions.truthy(model.call(&"set_body_preset", &"masculine"), "masculine body resolves", failures)
	TestAssertions.truthy(model.call(&"set_body_preset", &"feminine"), "feminine body resolves", failures)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		TestAssertions.truthy(model.call(&"has_equipment_slot", slot_id), "model exposes %s" % slot_id, failures)
	var bounds: AABB = model.call(&"visual_bounds") as AABB
	TestAssertions.truthy(bounds.size.y >= 1.6 and bounds.size.y <= 1.85, "humanoid height fits actor scale", failures)
	TestAssertions.near(bounds.position.y, 0.0, 0.05, "model feet begin at local floor", failures)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := load(EQUIPMENT_PATHS[slot_id]) as EquipmentVisualDefinition
		TestAssertions.truthy(definition != null, "%s equipment resource loads" % slot_id, failures)
		if definition != null:
			TestAssertions.equal(definition.slot_id, slot_id, "%s equipment resource slot" % slot_id, failures)
			TestAssertions.truthy(not definition.visual_channels.is_empty(), "%s equipment resource has visual channel" % slot_id, failures)
			TestAssertions.equal(definition.validate(), PackedStringArray(), "%s equipment resource validates" % slot_id, failures)
	model.free()
	return failures
