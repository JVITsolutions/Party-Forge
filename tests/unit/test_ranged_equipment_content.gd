extends RefCounted

const SET_FOLDERS := {&"ranger": &"greenwood", &"marksman": &"siege_archer"}
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
			TestAssertions.truthy(exists, "%s ranged item content exists" % item_id, failures)
			all_exist = all_exist and exists
			if exists:
				discovered.append(item_id)
		TestAssertions.equal(discovered, ClassEquipmentRows.SET_ITEM_IDS[set_id], "%s ranged manifest" % set_id, failures)
	if not all_exist:
		return failures
	_assert_item_contracts(failures)
	_assert_cross_eligibility(failures)
	_assert_bow_rules(failures)
	_assert_actions(failures)
	_assert_arrow_scale(failures)
	_assert_catalog(failures)
	return failures

func _assert_item_contracts(failures: Array[String]) -> void:
	var model_scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	for set_id: StringName in SET_FOLDERS:
		var folder := String(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			var base := load("res://data/equipment/bases/%s/%s.tres" % [folder, item_id]) as EquipmentBaseDefinition
			TestAssertions.truthy(base != null and base.validate().is_empty(), "%s ranged base validates" % item_id, failures)
			if base == null or base.presentation == null:
				continue
			var visual := base.presentation
			TestAssertions.truthy(visual.validate().is_empty(), "%s ranged visual validates" % item_id, failures)
			TestAssertions.equal(visual.body_preset_ids, [&"masculine", &"feminine"], "%s supports both body presets" % item_id, failures)
			var scene_root := visual.presentation_scene.instantiate() as Node3D if visual.presentation_scene != null else null
			TestAssertions.truthy(scene_root != null and _has_visible_mesh(scene_root), "%s has independent visible geometry" % item_id, failures)
			if scene_root != null:
				for node: Node in scene_root.find_children("*", "Node3D", true, false):
					TestAssertions.truthy(not node.has_meta(&"body_preset"), "%s scene never contains body or arm geometry" % item_id, failures)
				scene_root.free()
			var model := model_scene.instantiate() as ForgeHumanoidModel if model_scene != null else null
			if model != null:
				TestAssertions.truthy(model.apply_equipment_visual(visual.slot_id, visual), "%s attaches to shared model" % item_id, failures)
				for attachment: Node3D in model.equipped_nodes.get(visual.slot_id, []):
					var socket_path := StringName(attachment.get_meta(&"equipment_socket_id", visual.socket_id))
					var socket := model.get_node_or_null(NodePath(String(socket_path))) as Node3D
					TestAssertions.truthy(socket != null and attachment.get_parent() == socket, "%s remains a socket child, never merged into an arm" % item_id, failures)
				model.free()
			for size: int in [256, 128]:
				var kind := "master" if size == 256 else "runtime"
				var image := Image.new()
				var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size])
				TestAssertions.truthy(image.load(path) == OK and image.get_width() == size and image.get_height() == size, "%s %d ranged icon exists" % [item_id, size], failures)

func _assert_cross_eligibility(failures: Array[String]) -> void:
	var ranger := _class_with_equipment_tags("res://data/classes/ranger.tres", [&"armour_light", &"armour_medium", &"bow_light_medium"])
	var marksman := _class_with_equipment_tags("res://data/classes/marksman.tres", [&"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"])
	var warlock := _class_with_equipment_tags("res://data/classes/warlock.tres", [&"armour_light"])
	var greenwood := load("res://data/equipment/bases/greenwood/greenwood_jerkin.tres") as EquipmentBaseDefinition
	var siege := load("res://data/equipment/bases/siege_archer/siege_archer_coat.tres") as EquipmentBaseDefinition
	TestAssertions.truthy(EquipmentEligibility.validate_equip(greenwood, marksman, &"body_armour").is_empty(), "Marksman may wear Greenwood armour", failures)
	TestAssertions.truthy(EquipmentEligibility.validate_equip(siege, ranger, &"body_armour").is_empty(), "Ranger may wear Siege armour", failures)
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(greenwood, warlock, &"body_armour").is_empty(), "Warlock cannot wear ranged-physical armour", failures)
	for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[&"ranger"].slice(0, 5):
		var base := load("res://data/equipment/bases/greenwood/%s.tres" % item_id) as EquipmentBaseDefinition
		TestAssertions.equal(base.required_all_tags, [&"martial", &"ranged"], "%s is shared ranged-physical armour" % item_id, failures)
		TestAssertions.equal(base.weight_class_id, &"light", "%s is mobile light armour" % item_id, failures)
	for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[&"marksman"].slice(0, 5):
		var base := load("res://data/equipment/bases/siege_archer/%s.tres" % item_id) as EquipmentBaseDefinition
		TestAssertions.equal(base.required_all_tags, [&"martial", &"ranged"], "%s is shared ranged-physical armour" % item_id, failures)
		var expected_weight := &"medium" if item_id in [&"siege_archer_coat", &"siege_archer_braced_leggings"] else &"light"
		TestAssertions.equal(base.weight_class_id, expected_weight, "%s ranged armour weight" % item_id, failures)

func _assert_bow_rules(failures: Array[String]) -> void:
	var ranger := _class_with_equipment_tags("res://data/classes/ranger.tres", [&"armour_light", &"armour_medium", &"bow_light_medium"])
	var marksman := _class_with_equipment_tags("res://data/classes/marksman.tres", [&"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"])
	var recurve := load("res://data/equipment/bases/greenwood/greenwood_recurve_bow.tres") as EquipmentBaseDefinition
	var light_quiver := load("res://data/equipment/bases/greenwood/greenwood_light_quiver.tres") as EquipmentBaseDefinition
	var greatbow := load("res://data/equipment/bases/siege_archer/siege_greatbow.tres") as EquipmentBaseDefinition
	var heavy_quiver := load("res://data/equipment/bases/siege_archer/siege_heavy_quiver.tres") as EquipmentBaseDefinition
	var shield := load("res://data/equipment/bases/forge_vanguard/forge_vanguard_shield.tres") as EquipmentBaseDefinition
	_assert_bow(recurve, &"light_bow", [&"bow_light_medium", &"ranged"], failures)
	_assert_bow(greatbow, &"greatbow", [&"greatbow", &"ranged"], failures)
	_assert_quiver(light_quiver, &"light_bow", [&"bow_light_medium", &"ranged"], failures)
	_assert_quiver(heavy_quiver, &"greatbow", [&"greatbow", &"ranged"], failures)
	TestAssertions.truthy(EquipmentEligibility.validate_equip(recurve, ranger, &"main_hand").is_empty(), "Ranger accepts recurve", failures)
	TestAssertions.truthy(EquipmentEligibility.validate_equip(light_quiver, ranger, &"off_hand", {&"main_hand": recurve}).is_empty(), "Ranger bow accepts light quiver exception", failures)
	TestAssertions.truthy(EquipmentEligibility.validate_equip(greatbow, marksman, &"main_hand").is_empty(), "Marksman accepts greatbow", failures)
	TestAssertions.truthy(EquipmentEligibility.validate_equip(heavy_quiver, marksman, &"off_hand", {&"main_hand": greatbow}).is_empty(), "Marksman bow accepts heavy quiver exception", failures)
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(heavy_quiver, marksman, &"off_hand", {&"main_hand": recurve}).is_empty(), "light bow rejects heavy-family quiver", failures)
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(greatbow, marksman, &"main_hand", {&"off_hand": light_quiver}).is_empty(), "greatbow rejects equipped light-family quiver", failures)
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(greatbow, ranger, &"main_hand").is_empty(), "Ranger rejects greatbow", failures)
	TestAssertions.truthy(not EquipmentEligibility.validate_equip(shield, ranger, &"off_hand", {&"main_hand": recurve}).is_empty(), "bow reservation rejects shield coexistence", failures)

func _assert_bow(bow: EquipmentBaseDefinition, family: StringName, tags: Array, failures: Array[String]) -> void:
	TestAssertions.equal(bow.item_type_id, &"bow", "%s item type" % bow.id, failures)
	TestAssertions.equal(bow.weapon_family_id, family, "%s family" % bow.id, failures)
	TestAssertions.equal(bow.required_all_tags, tags, "%s restrictions" % bow.id, failures)
	TestAssertions.equal(bow.handedness_id, &"two_hand", "%s is two handed" % bow.id, failures)
	TestAssertions.equal(bow.reserved_slot_ids, [&"off_hand"], "%s reserves offhand" % bow.id, failures)
	TestAssertions.equal(bow.compatible_offhand_item_types, [&"quiver"], "%s permits only quiver offhand" % bow.id, failures)

func _assert_quiver(quiver: EquipmentBaseDefinition, family: StringName, tags: Array, failures: Array[String]) -> void:
	TestAssertions.equal(quiver.item_type_id, &"quiver", "%s item type" % quiver.id, failures)
	TestAssertions.equal(quiver.weapon_family_id, family, "%s family" % quiver.id, failures)
	TestAssertions.equal(quiver.required_all_tags, tags, "%s restrictions" % quiver.id, failures)

func _assert_actions(failures: Array[String]) -> void:
	var scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	var model := scene.instantiate() as ForgeHumanoidModel if scene != null else null
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer if model != null else null
	TestAssertions.truthy(player != null, "shared model exposes ranged animation player", failures)
	if player != null:
		_assert_idle(player, &"ranger_idle", failures)
		_assert_idle(player, &"marksman_idle", failures)
		_assert_release_action(player, &"ranger_quick_bow_shot", 0.42, 0.18, failures)
		_assert_release_action(player, &"marksman_heavy_bow_shot", 1.55, 1.15, failures)
		var ranger_hip := _sample_rotation(player.get_animation(&"ranger_idle"), "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", 0.0)
		var marksman_hip := _sample_rotation(player.get_animation(&"marksman_idle"), "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", 0.0)
		TestAssertions.truthy(ranger_hip.angle_to(marksman_hip) > 0.08, "Marksman brace stance is visibly wider than Ranger stance", failures)
	if model != null:
		model.free()

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

func _assert_arrow_scale(failures: Array[String]) -> void:
	var ranger_scene := load("res://scenes/combat/presentation/projectiles/ranger_arrow.tscn") as PackedScene
	var marksman_scene := load("res://scenes/combat/presentation/projectiles/marksman_heavy_arrow.tscn") as PackedScene
	var ranger := ranger_scene.instantiate() as Node3D if ranger_scene != null else null
	var marksman := marksman_scene.instantiate() as Node3D if marksman_scene != null else null
	var ranger_shaft := ranger.get_node_or_null("Shaft") as MeshInstance3D if ranger != null else null
	var marksman_shaft := marksman.get_node_or_null("Shaft") as MeshInstance3D if marksman != null else null
	TestAssertions.truthy(ranger_shaft != null and marksman_shaft != null, "both authored arrow meshes exist", failures)
	if ranger_shaft != null and marksman_shaft != null:
		var ranger_height := (ranger_shaft.mesh as CylinderMesh).height
		var marksman_height := (marksman_shaft.mesh as CylinderMesh).height
		TestAssertions.near(marksman_height / ranger_height, 1.5, 0.02, "Marksman arrow geometry is visibly larger before 1.45 runtime scale", failures)
	if ranger != null: ranger.free()
	if marksman != null: marksman.free()

func _assert_catalog(failures: Array[String]) -> void:
	var catalog := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	TestAssertions.truthy(catalog != null and catalog.validate().is_empty(), "ranged catalog validates", failures)
	if catalog != null:
		for set_id: StringName in SET_FOLDERS:
			for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
				TestAssertions.truthy(catalog.definition(item_id) != null, "catalog includes %s" % item_id, failures)

func _class_with_equipment_tags(path: String, tags: Array[StringName]) -> ClassDefinition:
	var value := (load(path) as ClassDefinition).duplicate(true) as ClassDefinition
	for tag: StringName in tags:
		if tag not in value.capability_tags: value.capability_tags.append(tag)
	return value

func _method_event_time(animation: Animation, event_name: StringName) -> float:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD: continue
		for key_index: int in animation.track_get_key_count(track_index):
			var call := animation.track_get_key_value(track_index, key_index) as Dictionary
			if call.get(&"args", []) == [event_name]: return animation.track_get_key_time(track_index, key_index)
	return -1.0

func _sample_rotation(animation: Animation, path: String, time: float) -> Quaternion:
	var track := animation.find_track(NodePath("%s:rotation" % path), Animation.TYPE_ROTATION_3D)
	return animation.rotation_track_interpolate(track, time) if track >= 0 else Quaternion.IDENTITY

func _has_visible_mesh(root: Node3D) -> bool:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null: return true
	return false
