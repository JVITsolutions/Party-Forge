extends RefCounted

const PROFILE_PATH := "res://data/presentation/profiles/forge_vanguard.tres"

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := load(PROFILE_PATH) as CharacterVisualProfile
	TestAssertions.truthy(profile != null, "Forge Vanguard profile loads", failures)
	if profile == null or profile.presentation_scene == null:
		return failures
	TestAssertions.equal(profile.validate(), PackedStringArray(), "Forge Vanguard profile validates", failures)
	TestAssertions.equal(profile.default_equipment.size(), 11, "Fighter has one default for every canonical slot", failures)
	TestAssertions.equal(profile.available_equipment.size(), 12, "Fighter exposes hammer as its twelfth option", failures)
	var model := profile.presentation_scene.instantiate() as ForgeHumanoidModel
	TestAssertions.truthy(model != null, "Fighter uses the shared ForgeHumanoidModel", failures)
	if model == null:
		return failures
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		TestAssertions.truthy(model.has_equipment_slot(slot_id), "model exposes canonical slot %s" % slot_id, failures)
	for entry: EquipmentLoadoutEntry in profile.default_equipment:
		var visual := entry.item.presentation if entry != null and entry.item != null else null
		TestAssertions.truthy(visual != null, "default entry has a presentation", failures)
		if visual != null:
			TestAssertions.truthy(model.apply_equipment_visual(entry.slot_id, visual), "default %s equips" % entry.slot_id, failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"forge_vanguard_sword", "red sword remains Fighter default", failures)
	TestAssertions.equal(model.equipped_item_id(&"off_hand"), &"forge_vanguard_shield", "shield remains Fighter default", failures)
	var hammer := _item_by_id(profile, &"forge_vanguard_hammer")
	TestAssertions.truthy(hammer != null and hammer.presentation != null, "hammer alternative loads", failures)
	if hammer != null and hammer.presentation != null:
		TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", hammer.presentation), "hammer can replace sword", failures)
		TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"forge_vanguard_hammer", "hammer replacement is recorded", failures)
		var sword := _item_by_id(profile, &"forge_vanguard_sword")
		TestAssertions.truthy(sword != null and sword.presentation != null and model.apply_equipment_visual(&"main_hand", sword.presentation), "sword can be restored", failures)
		TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"forge_vanguard_sword", "sword restore is recorded", failures)
	model.free()
	return failures

func _item_by_id(profile: CharacterVisualProfile, item_id: StringName) -> EquipmentBaseDefinition:
	for item: EquipmentBaseDefinition in profile.available_equipment:
		if item != null and item.id == item_id:
			return item
	return null
