extends RefCounted

const SET_FOLDERS := {
	&"mage": &"emberweave",
	&"frost_mage": &"rime_scholar",
	&"cleric": &"storm_chaplain",
	&"warlock": &"grave_covenant",
}
const CLASS_TAGS := {
	&"mage": [&"armour_light", &"caster_wand", &"caster_focus"],
	&"frost_mage": [&"armour_light", &"caster_staff"],
	&"cleric": [&"armour_light", &"armour_medium", &"divine_sceptre", &"divine_tome"],
	&"warlock": [&"armour_light", &"occult_wand", &"occult_grimoire"],
}
const WEAPON_RULES := {
	&"emberweave_wand": [&"wand", &"caster_wand"],
	&"emberweave_flame_focus": [&"focus", &"caster_focus"],
	&"rime_scholar_staff": [&"staff", &"caster_staff"],
	&"storm_chaplain_sceptre": [&"sceptre", &"divine_sceptre"],
	&"storm_chaplain_holy_tome": [&"tome", &"divine_tome"],
	&"grave_covenant_bone_wand": [&"wand", &"occult_wand"],
	&"grave_covenant_grimoire": [&"grimoire", &"occult_grimoire"],
}
const ACTIONS := {
	&"mage_fire_burst": [0.76, 0.46],
	&"frost_staff_shard": [0.88, 0.52],
	&"cleric_lightning_bolt": [0.62, 0.34],
	&"cleric_healing_blessing": [1.08, 0.72],
	&"warlock_chaos_bolt": [1.02, 0.64],
}
const SPECIALIZED_SCENES := {
	&"mage_fire_burst": "res://scenes/combat/presentation/projectiles/mage_fire_orb.tscn",
	&"frost_staff_shard": "res://scenes/combat/presentation/projectiles/frost_shard.tscn",
	&"cleric_lightning_bolt": "res://scenes/combat/presentation/projectiles/cleric_lightning_bolt.tscn",
	&"cleric_healing_blessing": "res://scenes/combat/presentation/effects/healing_blessing.tscn",
	&"warlock_chaos_bolt": "res://scenes/combat/presentation/projectiles/warlock_chaos_bolt.tscn",
}
const GUARD_LIMBS := [
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var all_exist := true
	for set_id: StringName in SET_FOLDERS:
		var folder := String(SET_FOLDERS[set_id])
		var discovered: Array[StringName] = []
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var base_path := "res://data/equipment/bases/%s/%s.tres" % [folder, item_id]
			var visual_path := "res://data/presentation/equipment/%s/%s.tres" % [folder, item_id]
			var scene_path := "res://scenes/equipment/%s/%s.tscn" % [folder, item_id]
			var exists := ResourceLoader.exists(base_path) and ResourceLoader.exists(visual_path) and ResourceLoader.exists(scene_path)
			TestAssertions.truthy(exists, "%s caster item content exists" % item_id, failures)
			all_exist = all_exist and exists
			if exists: discovered.append(item_id)
		TestAssertions.equal(discovered, ClassEquipmentRows.SET_ITEM_IDS[set_id], "%s exact caster manifest" % set_id, failures)
	if not all_exist: return failures
	_assert_item_contracts(failures)
	_assert_eligibility_and_weapon_rules(failures)
	_assert_actions(failures)
	_assert_catalog(failures)
	return failures

func _assert_item_contracts(failures: Array[String]) -> void:
	var model_scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	for set_id: StringName in SET_FOLDERS:
		var folder := String(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var base := load("res://data/equipment/bases/%s/%s.tres" % [folder, item_id]) as EquipmentBaseDefinition
			TestAssertions.truthy(base != null and base.validate().is_empty(), "%s caster base validates" % item_id, failures)
			if base == null or base.presentation == null: continue
			var visual := base.presentation
			TestAssertions.truthy(visual.validate().is_empty(), "%s caster visual validates" % item_id, failures)
			TestAssertions.equal(visual.body_preset_ids, [&"masculine", &"feminine"], "%s supports reusable bodies" % item_id, failures)
			var equipment_root := visual.presentation_scene.instantiate() as Node3D if visual.presentation_scene != null else null
			TestAssertions.truthy(equipment_root != null and _has_visible_mesh(equipment_root), "%s has independent visible geometry" % item_id, failures)
			if equipment_root != null:
				for node: Node in equipment_root.find_children("*", "Node3D", true, false):
					TestAssertions.truthy(not node.has_meta(&"body_preset"), "%s never contains body or arm geometry" % item_id, failures)
				equipment_root.free()
			var model := model_scene.instantiate() as ForgeHumanoidModel if model_scene != null else null
			if model != null:
				TestAssertions.truthy(model.apply_equipment_visual(visual.slot_id, visual), "%s attaches to shared model" % item_id, failures)
				for attachment: Node3D in model.equipped_nodes.get(visual.slot_id, []):
					var socket_path := StringName(attachment.get_meta(&"equipment_socket_id", visual.socket_id))
					var socket := model.get_node_or_null(NodePath(String(socket_path))) as Node3D
					TestAssertions.truthy(socket != null and attachment.get_parent() == socket, "%s stays a socket child, never merged into an arm" % item_id, failures)
				model.free()
			for size: int in [256, 128]:
				var kind := "master" if size == 256 else "runtime"
				var image := Image.new()
				var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size])
				TestAssertions.truthy(image.load(path) == OK and image.get_width() == size and image.get_height() == size, "%s %d caster icon exists" % [item_id, size], failures)

func _assert_eligibility_and_weapon_rules(failures: Array[String]) -> void:
	for set_id: StringName in SET_FOLDERS:
		var actor_class := _class_with_equipment_tags("res://data/classes/%s.tres" % set_id, CLASS_TAGS[set_id])
		var folder := String(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var base := load("res://data/equipment/bases/%s/%s.tres" % [folder, item_id]) as EquipmentBaseDefinition
			var result := EquipmentEligibility.validate_equip(base, actor_class, base.compatible_slot_ids[0])
			TestAssertions.truthy(result.is_empty(), "%s equips on its caster class" % item_id, failures)
			if base.item_type_id in [&"helmet", &"body_armour", &"legs", &"gloves", &"boots"]:
				TestAssertions.equal(base.required_all_tags, [&"caster"], "%s requires the caster armour family" % item_id, failures)
	var rogue := _class_with_equipment_tags("res://data/classes/rogue.tres", [&"armour_light"])
	var mage_robe := load("res://data/equipment/bases/emberweave/emberweave_robe.tres") as EquipmentBaseDefinition
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(mage_robe, rogue, &"body_armour").is_empty(), "light-armour martial cannot wear caster robes", failures)
	for item_id: StringName in WEAPON_RULES:
		var set_id := _set_for_item(item_id)
		var folder := String(SET_FOLDERS[set_id])
		var base := load("res://data/equipment/bases/%s/%s.tres" % [folder, item_id]) as EquipmentBaseDefinition
		TestAssertions.equal(base.item_type_id, WEAPON_RULES[item_id][0], "%s item type" % item_id, failures)
		TestAssertions.equal(base.weapon_family_id, WEAPON_RULES[item_id][0], "%s weapon family" % item_id, failures)
		TestAssertions.equal(base.required_all_tags, [WEAPON_RULES[item_id][1]], "%s class capability" % item_id, failures)
	var staff := load("res://data/equipment/bases/rime_scholar/rime_scholar_staff.tres") as EquipmentBaseDefinition
	TestAssertions.equal(staff.handedness_id, &"two_hand", "Frost staff is two handed", failures)
	TestAssertions.equal(staff.reserved_slot_ids, [&"off_hand"], "Frost staff reserves offhand", failures)
	TestAssertions.truthy(staff.compatible_offhand_item_types.is_empty(), "Frost staff permits no offhand exception", failures)
	TestAssertions.equal(ClassEquipmentRows.SET_ITEM_IDS[&"frost_mage"].size(), 10, "Frost set has no default offhand item", failures)
	var cleric_armour := load("res://data/equipment/bases/storm_chaplain/storm_chaplain_vestments.tres") as EquipmentBaseDefinition
	TestAssertions.equal(cleric_armour.weight_class_id, &"medium", "Cleric vestments read as medium support armour", failures)

func _assert_actions(failures: Array[String]) -> void:
	var scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	var model := scene.instantiate() as ForgeHumanoidModel if scene != null else null
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer if model != null else null
	TestAssertions.truthy(player != null, "shared model exposes caster animation player", failures)
	if player != null:
		for idle_id: StringName in [&"mage_idle", &"frost_mage_idle", &"cleric_idle", &"warlock_idle"]: _assert_idle(player, idle_id, failures)
		for action_id: StringName in ACTIONS:
			_assert_release_action(player, action_id, ACTIONS[action_id][0], ACTIONS[action_id][1], failures)
	for action_id: StringName in SPECIALIZED_SCENES:
		TestAssertions.truthy(ResourceLoader.exists(SPECIALIZED_SCENES[action_id]), "%s specialized visual exists" % action_id, failures)
	if model != null: model.free()

func _assert_idle(player: AnimationPlayer, idle_id: StringName, failures: Array[String]) -> void:
	TestAssertions.truthy(player.has_animation(idle_id), "%s exists" % idle_id, failures)
	if not player.has_animation(idle_id): return
	var idle := player.get_animation(idle_id)
	TestAssertions.equal(idle.loop_mode, Animation.LOOP_LINEAR, "%s loops" % idle_id, failures)
	for limb_path: String in GUARD_LIMBS:
		var track := idle.find_track(NodePath("%s:rotation" % limb_path), Animation.TYPE_ROTATION_3D)
		TestAssertions.truthy(track >= 0, "%s guard track %s" % [idle_id, limb_path], failures)
		if track >= 0:
			for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				TestAssertions.truthy(idle.rotation_track_interpolate(track, idle.length * fraction).angle_to(Quaternion.IDENTITY) > 0.05, "%s prevents A-pose on %s at %.2f" % [idle_id, limb_path, fraction], failures)

func _assert_release_action(player: AnimationPlayer, action_id: StringName, duration: float, release: float, failures: Array[String]) -> void:
	TestAssertions.truthy(player.has_animation(action_id), "%s exists" % action_id, failures)
	if not player.has_animation(action_id): return
	var action := player.get_animation(action_id)
	TestAssertions.near(action.length, duration, 0.01, "%s duration" % action_id, failures)
	TestAssertions.near(_method_event_time(action, &"release"), release, 0.01, "%s synchronized release" % action_id, failures)
	for track_index: int in action.get_track_count():
		var path := String(action.track_get_path(track_index))
		TestAssertions.truthy(not path.begins_with(".:position") and not path.begins_with(".:rotation"), "%s never animates model root" % action_id, failures)

func _assert_catalog(failures: Array[String]) -> void:
	var catalog := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	TestAssertions.truthy(catalog != null and catalog.validate().is_empty(), "caster catalog validates", failures)
	if catalog != null:
		for set_id: StringName in SET_FOLDERS:
			for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
				TestAssertions.truthy(catalog.definition(item_id) != null, "catalog includes %s" % item_id, failures)

func _class_with_equipment_tags(path: String, tags: Array) -> ClassDefinition:
	var value := (load(path) as ClassDefinition).duplicate(true) as ClassDefinition
	for tag: StringName in tags:
		if tag not in value.capability_tags: value.capability_tags.append(tag)
	return value

func _set_for_item(item_id: StringName) -> StringName:
	for set_id: StringName in SET_FOLDERS:
		if item_id in ClassEquipmentRows.SET_ITEM_IDS[set_id]: return set_id
	return &""

func _method_event_time(animation: Animation, event_name: StringName) -> float:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD: continue
		for key_index: int in animation.track_get_key_count(track_index):
			var call := animation.track_get_key_value(track_index, key_index) as Dictionary
			if call.get(&"args", []) == [event_name]: return animation.track_get_key_time(track_index, key_index)
	return -1.0

func _has_visible_mesh(root: Node3D) -> bool:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null: return true
	return false
