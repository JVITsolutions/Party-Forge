extends RefCounted

const SET_FOLDERS := {&"paladin": &"dawn_bulwark", &"rogue": &"nightstep"}
const MAX_BOUNDS := AABB(Vector3(-1.25, -0.10, -0.85), Vector3(2.5, 2.8, 1.7))
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
			TestAssertions.truthy(exists, "%s item content exists" % item_id, failures)
			all_exist = all_exist and exists
			if exists:
				discovered.append(item_id)
				_assert_item(set_id, item_id, base_path, failures)
		TestAssertions.equal(discovered, ClassEquipmentRows.SET_ITEM_IDS[set_id], "%s manifest" % set_id, failures)
	if not all_exist:
		return failures
	_assert_rules(failures)
	_assert_actions(failures)
	_assert_catalog(failures)
	return failures

func _assert_item(set_id: StringName, item_id: StringName, base_path: String, failures: Array[String]) -> void:
	var folder := String(SET_FOLDERS[set_id])
	var base := load(base_path) as EquipmentBaseDefinition
	TestAssertions.truthy(base != null and base.validate().is_empty(), "%s base validates" % item_id, failures)
	if base == null or base.presentation == null:
		return
	var visual := base.presentation
	TestAssertions.truthy(visual.validate().is_empty(), "%s visual validates" % item_id, failures)
	TestAssertions.equal(visual.body_preset_ids, [&"masculine", &"feminine"], "%s supports both body presets" % item_id, failures)
	if visual.combat_visible:
		var scene := visual.presentation_scene
		var root := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(root != null and _has_visible_mesh(root), "%s has visible independent geometry" % item_id, failures)
		if root != null:
			for child: Node in root.find_children("*", "Node3D", true, false):
				if child.has_meta(&"equipment_socket_id"):
					TestAssertions.truthy(not StringName(child.get_meta(&"equipment_socket_id")).is_empty(), "%s declares attachment socket" % item_id, failures)
			root.free()
	var model_scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	var model := model_scene.instantiate() as ForgeHumanoidModel if model_scene != null else null
	if model != null and visual.combat_visible:
		var equipped := model.apply_equipment_visual(visual.slot_id, visual)
		TestAssertions.truthy(equipped, "%s attaches through its declared slot" % item_id, failures)
		if equipped:
			var installed: Array = model.equipped_nodes.get(visual.slot_id, [])
			TestAssertions.truthy(not installed.is_empty(), "%s installs one or more separate attachment nodes" % item_id, failures)
			for attachment: Node3D in installed:
				var socket_path := StringName(attachment.get_meta(&"equipment_socket_id", visual.socket_id))
				var socket := model.get_node_or_null(NodePath(String(socket_path))) as Node3D
				TestAssertions.truthy(socket != null and attachment.get_parent() == socket, "%s remains parented to an equipment socket, not an arm mesh" % item_id, failures)
				TestAssertions.truthy(not attachment.has_meta(&"body_preset"), "%s attachment is never reused as body or arm geometry" % item_id, failures)
			var bounds := model.visual_bounds()
			TestAssertions.truthy(MAX_BOUNDS.encloses(bounds), "%s remains within shared humanoid bounds bounds=%s" % [item_id, bounds], failures)
		model.free()
	for size: int in [256, 128]:
		var kind := "master" if size == 256 else "runtime"
		var icon_path := "res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size]
		var image := Image.new()
		var loaded := image.load(ProjectSettings.globalize_path(icon_path)) == OK
		TestAssertions.truthy(loaded and image.get_width() == size and image.get_height() == size, "%s %d icon exists" % [item_id, size], failures)

func _assert_rules(failures: Array[String]) -> void:
	var paladin_armour := load("res://data/equipment/bases/dawn_bulwark/dawn_bulwark_plate.tres") as EquipmentBaseDefinition
	var rogue_armour := load("res://data/equipment/bases/nightstep/nightstep_leathers.tres") as EquipmentBaseDefinition
	TestAssertions.equal(paladin_armour.required_all_tags, [&"martial", &"vanguard"], "Paladin heavy armour requires martial vanguard", failures)
	TestAssertions.equal(rogue_armour.required_all_tags, [&"martial", &"skirmisher"], "Rogue light armour requires martial skirmisher", failures)
	_assert_weapon(&"sunforged_warhammer", &"dawn_bulwark", &"warhammer", &"one_hand_hammer", [&"martial", &"one_hand_hammer"], failures)
	_assert_weapon(&"dawn_bulwark_shield", &"dawn_bulwark", &"shield", &"shield", [&"martial", &"shield"], failures)
	_assert_weapon(&"nightstep_dagger_main", &"nightstep", &"dagger", &"dual_daggers", [&"dagger", &"dual_wield"], failures)
	_assert_weapon(&"nightstep_dagger_off", &"nightstep", &"dagger", &"dual_daggers", [&"dagger", &"dual_wield"], failures)

func _assert_weapon(item_id: StringName, folder: StringName, item_type: StringName, family: StringName, tags: Array[StringName], failures: Array[String]) -> void:
	var base := load("res://data/equipment/bases/%s/%s.tres" % [folder, item_id]) as EquipmentBaseDefinition
	TestAssertions.equal(base.item_type_id, item_type, "%s item type" % item_id, failures)
	TestAssertions.equal(base.weapon_family_id, family, "%s weapon family" % item_id, failures)
	TestAssertions.equal(base.required_all_tags, tags, "%s equipment restrictions" % item_id, failures)

func _assert_actions(failures: Array[String]) -> void:
	var scene := load("res://scenes/characters/presentation/forge_humanoid_model.tscn") as PackedScene
	var model := scene.instantiate() as ForgeHumanoidModel if scene != null else null
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer if model != null else null
	TestAssertions.truthy(player != null, "shared model exposes animation player for melee wave", failures)
	if player != null:
		TestAssertions.truthy(player.has_animation(&"paladin_idle") and player.has_animation(&"rogue_idle"), "Paladin and Rogue idles exist", failures)
		for idle_id: StringName in [&"paladin_idle", &"rogue_idle"]:
			_assert_guard_idle(player, idle_id, failures)
		TestAssertions.truthy(_action_has_event(player, &"paladin_hammer_smite", &"impact", 0.58), "Paladin impact timing", failures)
		TestAssertions.truthy(_action_has_event(player, &"rogue_dagger_flurry", &"impact", 0.16), "Rogue impact timing", failures)
		for action_id: StringName in [&"paladin_hammer_smite", &"rogue_dagger_flurry"]:
			var animation := player.get_animation(action_id) if player.has_animation(action_id) else null
			if animation != null:
				for track_index: int in animation.get_track_count():
					var path := String(animation.track_get_path(track_index))
					TestAssertions.truthy(not path.begins_with(".:position") and not path.begins_with(".:rotation"), "%s never animates model root" % action_id, failures)
	if model != null:
		model.free()

func _assert_guard_idle(player: AnimationPlayer, idle_id: StringName, failures: Array[String]) -> void:
	if not player.has_animation(idle_id):
		return
	var idle := player.get_animation(idle_id)
	TestAssertions.equal(idle.loop_mode, Animation.LOOP_LINEAR, "%s loops" % idle_id, failures)
	for limb_path: String in GUARD_LIMBS:
		var track := idle.find_track(NodePath("%s:rotation" % limb_path), Animation.TYPE_ROTATION_3D)
		TestAssertions.truthy(track >= 0, "%s contains bent limb track %s" % [idle_id, limb_path], failures)
		if track < 0:
			continue
		for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var sampled := idle.rotation_track_interpolate(track, idle.length * fraction)
			TestAssertions.truthy(sampled.angle_to(Quaternion.IDENTITY) > 0.05, "%s keeps %s bent at %.2f to prevent A-pose" % [idle_id, limb_path, fraction], failures)

func _assert_catalog(failures: Array[String]) -> void:
	var catalog := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	TestAssertions.truthy(catalog != null and catalog.validate().is_empty(), "heavy melee catalog validates", failures)
	if catalog != null:
		for set_id: StringName in SET_FOLDERS:
			for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
				TestAssertions.truthy(catalog.definition(item_id) != null, "catalog includes %s" % item_id, failures)

func _action_has_event(player: AnimationPlayer, action_id: StringName, event_name: StringName, expected_time: float) -> bool:
	if not player.has_animation(action_id):
		return false
	var animation := player.get_animation(action_id)
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD:
			continue
		for key_index: int in animation.track_get_key_count(track_index):
			var call := animation.track_get_key_value(track_index, key_index) as Dictionary
			if call.get(&"args", []) == [event_name] and is_equal_approx(animation.track_get_key_time(track_index, key_index), expected_time):
				return true
	return false

func _has_visible_mesh(root: Node3D) -> bool:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null:
			return true
	return false
