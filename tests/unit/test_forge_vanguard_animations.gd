extends RefCounted

const PROFILE_PATH := "res://data/presentation/profiles/forge_vanguard.tres"
const EXPECTED_LENGTHS := {
	&"idle": 1.6,
	&"walk": 0.8,
	&"attack_slash": 0.55,
	&"attack_combo": 0.9,
	&"hit_flinch": 0.25,
}
const EXPECTED_GUARD_ROTATIONS := {
	&"left_shoulder": Vector3(-0.28, -0.05, -0.55),
	&"left_elbow": Vector3(0.10, 0.0, -0.65),
	&"right_shoulder": Vector3(-0.18, -0.16, 0.34),
	&"right_elbow": Vector3(0.10, 0.0, 0.38),
}
const PIVOT_PATHS := {
	&"left_shoulder": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
	&"left_elbow": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
	&"right_shoulder": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
	&"right_elbow": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
}
const WALK_LEG_PATHS := {
	&"left_hip": "HitPivot/BodyPivot/HipsPivot/LeftHipPivot",
	&"left_knee": "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot",
	&"right_hip": "HitPivot/BodyPivot/HipsPivot/RightHipPivot",
	&"right_knee": "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot",
}
const ROOT_TRANSFORM_PROPERTIES := [&"position", &"rotation", &"transform", &"global_transform"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := load(PROFILE_PATH) as CharacterVisualProfile
	TestAssertions.truthy(profile != null and profile.presentation_scene != null, "Forge Vanguard animation scene loads", failures)
	if profile == null or profile.presentation_scene == null:
		return failures
	var model := profile.presentation_scene.instantiate() as ForgeHumanoidModel
	TestAssertions.truthy(model != null, "Forge Vanguard model instantiates for animation contract", failures)
	if model == null:
		return failures
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	TestAssertions.truthy(player != null, "AnimationPlayer exists", failures)
	if player != null:
		_assert_animation_metadata(player, failures)
		_assert_guard_contract(player, failures)
		_assert_idle_guard_throughout_loop(player, failures)
		_assert_walk_contract(player, failures)
		_assert_model_root_is_not_animated(player, failures)
		_assert_playback_contract(model, player, failures)
		_assert_downed_playback_contract(model, player, failures)
	_assert_feedback_contract(model, profile, failures)
	_assert_fighter_cleave_mapping(profile, failures)
	model.free()
	return failures

func _assert_animation_metadata(player: AnimationPlayer, failures: Array[String]) -> void:
	for animation_id: StringName in EXPECTED_LENGTHS:
		TestAssertions.truthy(player.has_animation(animation_id), "animation exists: %s" % animation_id, failures)
		if player.has_animation(animation_id):
			var animation := player.get_animation(animation_id)
			TestAssertions.near(animation.length, EXPECTED_LENGTHS[animation_id], 0.02, "%s duration" % animation_id, failures)
			TestAssertions.equal(animation.loop_mode == Animation.LOOP_LINEAR, animation_id in [&"idle", &"walk"], "%s loop contract" % animation_id, failures)

func _assert_guard_contract(player: AnimationPlayer, failures: Array[String]) -> void:
	for animation_id: StringName in EXPECTED_LENGTHS:
		if not player.has_animation(animation_id):
			continue
		var animation := player.get_animation(animation_id)
		for pivot_id: StringName in EXPECTED_GUARD_ROTATIONS:
			var expected := Quaternion.from_euler(EXPECTED_GUARD_ROTATIONS[pivot_id] as Vector3)
			var start := _sample_rotation(animation, String(PIVOT_PATHS[pivot_id]), 0.0)
			var finish := _sample_rotation(animation, String(PIVOT_PATHS[pivot_id]), animation.length)
			if animation_id == &"walk":
				TestAssertions.truthy(start.is_equal_approx(finish), "walk closes its guard stride at %s" % pivot_id, failures)
				continue
			TestAssertions.truthy(start.is_equal_approx(expected), "%s begins in guard at %s" % [animation_id, pivot_id], failures)
			TestAssertions.truthy(finish.is_equal_approx(expected), "%s recovers to guard at %s" % [animation_id, pivot_id], failures)

func _sample_rotation(animation: Animation, node_path: String, time: float) -> Quaternion:
	var track_path := NodePath("%s:rotation" % node_path)
	var track_index := animation.find_track(track_path, Animation.TYPE_ROTATION_3D)
	if track_index < 0:
		return Quaternion.IDENTITY
	return animation.rotation_track_interpolate(track_index, time)

func _sample_position(animation: Animation, node_path: String, time: float) -> Vector3:
	var track_path := NodePath("%s:position" % node_path)
	var track_index := animation.find_track(track_path, Animation.TYPE_POSITION_3D)
	if track_index < 0:
		return Vector3.INF
	return animation.position_track_interpolate(track_index, time)

func _assert_idle_guard_throughout_loop(player: AnimationPlayer, failures: Array[String]) -> void:
	TestAssertions.truthy(player.has_animation(&"idle"), "shared humanoid exposes guard idle", failures)
	if not player.has_animation(&"idle"):
		return
	var idle := player.get_animation(&"idle")
	for pivot_id: StringName in EXPECTED_GUARD_ROTATIONS:
		var track := idle.find_track(NodePath("%s:rotation" % PIVOT_PATHS[pivot_id]), Animation.TYPE_ROTATION_3D)
		TestAssertions.truthy(track >= 0, "idle contains guard rotation track for %s" % pivot_id, failures)
		if track < 0:
			continue
		for sample_time: float in [0.0, 0.4, 0.8, 1.2, 1.6]:
			var sampled := idle.rotation_track_interpolate(track, sample_time)
			TestAssertions.truthy(sampled.angle_to(Quaternion.IDENTITY) > 0.05, "idle keeps %s materially bent at %.1f to prevent A-pose" % [pivot_id, sample_time], failures)

func _assert_walk_contract(player: AnimationPlayer, failures: Array[String]) -> void:
	TestAssertions.truthy(player.has_animation(&"walk"), "shared humanoid exposes authored walk", failures)
	if not player.has_animation(&"walk"):
		return
	var walk := player.get_animation(&"walk")
	for pivot_id: StringName in WALK_LEG_PATHS:
		var track := walk.find_track(NodePath("%s:rotation" % WALK_LEG_PATHS[pivot_id]), Animation.TYPE_ROTATION_3D)
		TestAssertions.truthy(track >= 0, "walk contains %s rotation track" % pivot_id, failures)
	var left_hip_start := _sample_rotation(walk, WALK_LEG_PATHS[&"left_hip"], 0.0).get_euler().x
	var right_hip_start := _sample_rotation(walk, WALK_LEG_PATHS[&"right_hip"], 0.0).get_euler().x
	TestAssertions.truthy(left_hip_start > 0.2 and right_hip_start < -0.2, "walk hips oppose at opening stride", failures)
	var left_knee_start := _sample_rotation(walk, WALK_LEG_PATHS[&"left_knee"], 0.0).get_euler().x
	var right_knee_start := _sample_rotation(walk, WALK_LEG_PATHS[&"right_knee"], 0.0).get_euler().x
	var left_knee_opposite := _sample_rotation(walk, WALK_LEG_PATHS[&"left_knee"], 0.4).get_euler().x
	var right_knee_opposite := _sample_rotation(walk, WALK_LEG_PATHS[&"right_knee"], 0.4).get_euler().x
	TestAssertions.truthy(right_knee_start > left_knee_start and left_knee_opposite > right_knee_opposite, "walk alternates knee flexion", failures)
	var bob_high := _sample_position(walk, "HitPivot/BodyPivot", 0.0)
	var bob_low := _sample_position(walk, "HitPivot/BodyPivot", 0.2)
	TestAssertions.truthy(bob_high.is_finite() and bob_low.is_finite() and bob_high.y > bob_low.y, "walk contains vertical body bob", failures)
	for sample_time: float in [0.0, 0.2, 0.4, 0.6]:
		for pivot_id: StringName in EXPECTED_GUARD_ROTATIONS:
			var track := walk.find_track(NodePath("%s:rotation" % PIVOT_PATHS[pivot_id]), Animation.TYPE_ROTATION_3D)
			TestAssertions.truthy(track >= 0, "walk contains guard track %s at %.1f" % [pivot_id, sample_time], failures)
			if track >= 0:
				var sampled := walk.rotation_track_interpolate(track, sample_time)
				TestAssertions.truthy(sampled.angle_to(Quaternion.IDENTITY) > 0.05, "walk keeps %s bent at %.1f to prevent A-pose" % [pivot_id, sample_time], failures)

func _assert_model_root_is_not_animated(player: AnimationPlayer, failures: Array[String]) -> void:
	for animation_id: StringName in EXPECTED_LENGTHS:
		if not player.has_animation(animation_id):
			continue
		var animation := player.get_animation(animation_id)
		for track_index: int in animation.get_track_count():
			var path_text := String(animation.track_get_path(track_index))
			var target_and_property := path_text.split(":", true, 1)
			if target_and_property.size() != 2:
				continue
			var targets_root := target_and_property[0] in ["", "."]
			var property := StringName(target_and_property[1])
			TestAssertions.truthy(not (targets_root and property in ROOT_TRANSFORM_PROPERTIES), "%s does not animate the model root %s" % [animation_id, property], failures)

func _assert_playback_contract(model: ForgeHumanoidModel, player: AnimationPlayer, failures: Array[String]) -> void:
	TestAssertions.truthy(not model.play_action(&"unknown_action"), "unknown action is rejected", failures)
	for animation_id: StringName in [&"idle", &"walk", &"attack_slash", &"attack_combo", &"hit_flinch"]:
		TestAssertions.truthy(model.play_action(animation_id), "%s action starts" % animation_id, failures)
		TestAssertions.equal(player.current_animation, animation_id, "%s becomes current animation" % animation_id, failures)
		if animation_id in [&"idle", &"walk"]:
			TestAssertions.truthy(player.get_queue().is_empty(), "%s remains a persistent locomotion loop" % animation_id, failures)
		else:
			TestAssertions.truthy(&"idle" in player.get_queue(), "%s queues idle recovery" % animation_id, failures)

func _assert_downed_playback_contract(model: ForgeHumanoidModel, player: AnimationPlayer, failures: Array[String]) -> void:
	var body_pivot := model.get_node_or_null("HitPivot/BodyPivot") as Node3D
	TestAssertions.truthy(body_pivot != null, "body pivot exists for downed pose retention", failures)
	TestAssertions.truthy(model.play_action(&"walk"), "walk starts before downed stop", failures)
	player.advance(0.2)
	var retained_position := body_pivot.position if body_pivot != null else Vector3.ZERO
	model.set_downed(true)
	TestAssertions.truthy(not player.is_playing(), "downed stops active walk playback", failures)
	TestAssertions.truthy(player.get_queue().is_empty(), "downed clears walk queue", failures)
	TestAssertions.equal(model.active_action_id, &"", "downed clears active walk action id", failures)
	if body_pivot != null:
		TestAssertions.equal(body_pivot.position, retained_position, "downed preserves current authored pose", failures)
	TestAssertions.truthy(not model.play_action(&"walk"), "downed model rejects direct walk", failures)
	TestAssertions.truthy(not model.play_action(&"attack_slash"), "downed model rejects direct attack", failures)
	TestAssertions.truthy(not player.is_playing(), "downed action rejections leave player stopped", failures)
	TestAssertions.truthy(player.get_queue().is_empty(), "downed action rejections leave queue empty", failures)
	TestAssertions.equal(model.active_action_id, &"", "downed action rejections leave action id empty", failures)
	model.set_downed(false)
	TestAssertions.truthy(not player.is_playing(), "revival does not auto-resume walk in the model", failures)
	TestAssertions.truthy(model.play_action(&"attack_slash"), "attack starts before downed stop", failures)
	TestAssertions.truthy(&"idle" in player.get_queue(), "attack has queued idle before downed stop", failures)
	model.set_downed(true)
	TestAssertions.truthy(not player.is_playing(), "downed stops active attack playback", failures)
	TestAssertions.truthy(player.get_queue().is_empty(), "downed clears queued attack recovery", failures)
	TestAssertions.equal(model.active_action_id, &"", "downed clears active attack action id", failures)
	model.set_downed(false)


func _assert_feedback_contract(model: ForgeHumanoidModel, profile: CharacterVisualProfile, failures: Array[String]) -> void:
	for entry: EquipmentLoadoutEntry in profile.default_equipment:
		if entry != null and entry.item != null and entry.item.presentation != null:
			model.apply_equipment_visual(entry.slot_id, entry.item.presentation)
	model.set_palette(&"red", Color("d94f4f"))
	var primary := _first_primary_mesh(model)
	TestAssertions.truthy(primary != null, "primary palette mesh exists for hit feedback", failures)
	if primary == null:
		return
	var resting_material := primary.material_override as StandardMaterial3D
	TestAssertions.truthy(resting_material != null, "primary palette material exists", failures)
	if resting_material == null:
		return
	var root_transform := model.transform
	var resting_color := resting_material.albedo_color
	model.set_hit_weight(1.0)
	var hit_material := primary.material_override as StandardMaterial3D
	TestAssertions.equal(model.transform, root_transform, "hit feedback preserves model transform", failures)
	TestAssertions.truthy(hit_material != null and hit_material.albedo_color != resting_color, "hit feedback tints the primary material", failures)
	TestAssertions.truthy(hit_material != null and hit_material.emission_enabled, "hit feedback enables material emission", failures)
	model.set_hit_weight(0.0)
	model.set_downed(true)
	var downed_material := primary.material_override as StandardMaterial3D
	TestAssertions.truthy(downed_material != null and is_equal_approx(downed_material.albedo_color.r, downed_material.albedo_color.g) and is_equal_approx(downed_material.albedo_color.g, downed_material.albedo_color.b), "downed feedback remains grayscale", failures)
	model.set_downed(false)
	var restored_material := primary.material_override as StandardMaterial3D
	TestAssertions.truthy(restored_material != null and restored_material.albedo_color.is_equal_approx(resting_color), "revival restores palette color", failures)

func _assert_fighter_cleave_mapping(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	TestAssertions.equal(profile.attack_animation_by_id.get(&"fighter_cleave"), &"attack_slash", "fighter cleave maps only to slash", failures)
	TestAssertions.truthy(not profile.attack_animation_by_id.values().has(&"attack_combo"), "fighter cleave does not map to combo", failures)

func _first_primary_mesh(model: ForgeHumanoidModel) -> MeshInstance3D:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if StringName(node.get_meta(&"palette_region", &"")) == &"primary":
			return node as MeshInstance3D
	return null
