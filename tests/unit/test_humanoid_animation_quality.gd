extends RefCounted

const MODEL_SCENE := preload("res://scenes/characters/presentation/forge_humanoid_model.tscn")
const IDLES: Array[StringName] = [&"idle", &"paladin_idle", &"ranger_idle", &"marksman_idle", &"rogue_idle", &"mage_idle", &"frost_mage_idle", &"cleric_idle", &"warlock_idle"]
const ATTACKS: Array[StringName] = [&"attack_slash", &"paladin_hammer_smite", &"ranger_quick_bow_shot", &"marksman_heavy_bow_shot", &"rogue_dagger_flurry", &"mage_fire_burst", &"frost_staff_shard", &"cleric_lightning_bolt", &"cleric_healing_blessing", &"warlock_chaos_bolt"]
const POSE_SAMPLES: Array[float] = [0.0, 0.28, 0.52, 0.76, 1.0]
const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const IDLE_RUNTIME_SAMPLES: Array[float] = [0.0, 0.4, 0.8, 1.2]
const LEFT_HAND_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket"
const RIGHT_HAND_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket"
const LEFT_ELBOW_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot"
const RIGHT_ELBOW_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot"
const MAX_IDLE_HAND_MEAN_BEHIND := 0.10
const MAX_IDLE_HAND_SPAN := 0.85
const MAX_ATTACK_HAND_BEHIND_Z := 0.18
const MAX_BOW_DRAW_HAND_BEHIND_Z := 0.26
const MAX_ATTACK_ELBOW_BEHIND_Z := 0.14

func run() -> Array[String]:
	var failures: Array[String] = []
	var model := MODEL_SCENE.instantiate() as ForgeHumanoidModel
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	for idle_id: StringName in IDLES:
		var idle := player.get_animation(idle_id)
		TestAssertions.truthy(idle != null, "%s exists" % idle_id, failures)
		if idle != null:
			_assert_idle_is_guarded(idle, idle_id, failures)
			for body_id: StringName in BODY_IDS:
				TestAssertions.truthy(model.set_body_preset(body_id), "%s body activates for %s" % [body_id, idle_id], failures)
				_assert_runtime_idle_silhouette(model, player, idle_id, body_id, failures)
	for attack_id: StringName in ATTACKS:
		var attack := player.get_animation(attack_id)
		TestAssertions.truthy(attack != null, "%s exists" % attack_id, failures)
		if attack != null:
			_assert_attack_has_phases(attack, attack_id, failures)
			for body_id: StringName in BODY_IDS:
				TestAssertions.truthy(model.set_body_preset(body_id), "%s body activates for %s" % [body_id, attack_id], failures)
				_assert_runtime_attack_curve(model, player, attack, attack_id, body_id, failures)
	var fighter_signature := _track_signature(player.get_animation(&"attack_slash"))
	for index: int in range(1, ATTACKS.size()):
		var attack_id := ATTACKS[index]
		TestAssertions.truthy(_track_signature(player.get_animation(attack_id)) != fighter_signature, "%s is not a scaled Fighter slash" % attack_id, failures)
	_assert_walk_quality(player, failures)
	model.free()
	return failures

func _assert_runtime_idle_silhouette(model: ForgeHumanoidModel, player: AnimationPlayer, action_id: StringName, body_id: StringName, failures: Array[String]) -> void:
	for sample_time: float in IDLE_RUNTIME_SAMPLES:
		player.play(action_id)
		player.seek(sample_time, true)
		player.advance(0.0)
		var left_hand := _transform_from_model(model, model.get_node(LEFT_HAND_PATH) as Node3D).origin
		var right_hand := _transform_from_model(model, model.get_node(RIGHT_HAND_PATH) as Node3D).origin
		var mean_z := (left_hand.z + right_hand.z) * 0.5
		var hand_span := absf(right_hand.x - left_hand.x)
		TestAssertions.truthy(mean_z <= MAX_IDLE_HAND_MEAN_BEHIND, "%s %s keeps hands out from behind the back at %.1f (mean_z=%.3f)" % [action_id, body_id, sample_time, mean_z], failures)
		TestAssertions.truthy(hand_span <= MAX_IDLE_HAND_SPAN, "%s %s avoids a T-pose hand span at %.1f (span=%.3f)" % [action_id, body_id, sample_time, hand_span], failures)

func _assert_runtime_attack_curve(model: ForgeHumanoidModel, player: AnimationPlayer, animation: Animation, action_id: StringName, body_id: StringName, failures: Array[String]) -> void:
	for normalized_time: float in _attack_sample_times():
		player.play(action_id)
		player.seek(normalized_time * animation.length, true)
		player.advance(0.0)
		var right_hand_limit := MAX_BOW_DRAW_HAND_BEHIND_Z if action_id in [&"ranger_quick_bow_shot", &"marksman_heavy_bow_shot"] else MAX_ATTACK_HAND_BEHIND_Z
		_assert_attack_joint_depth(model, LEFT_HAND_PATH, &"left_hand", MAX_ATTACK_HAND_BEHIND_Z, action_id, body_id, normalized_time, failures)
		_assert_attack_joint_depth(model, RIGHT_HAND_PATH, &"right_hand", right_hand_limit, action_id, body_id, normalized_time, failures)
		_assert_attack_joint_depth(model, LEFT_ELBOW_PATH, &"left_elbow", MAX_ATTACK_ELBOW_BEHIND_Z, action_id, body_id, normalized_time, failures)
		_assert_attack_joint_depth(model, RIGHT_ELBOW_PATH, &"right_elbow", MAX_ATTACK_ELBOW_BEHIND_Z, action_id, body_id, normalized_time, failures)

func _attack_sample_times() -> Array[float]:
	var samples: Array[float] = []
	for index: int in 21:
		samples.append(float(index) / 20.0)
	return samples

func _assert_attack_joint_depth(model: ForgeHumanoidModel, node_path: String, joint_label: StringName, limit: float, action_id: StringName, body_id: StringName, normalized_time: float, failures: Array[String]) -> void:
	var joint := model.get_node_or_null(node_path) as Node3D
	TestAssertions.truthy(joint != null, "%s %s has %s" % [action_id, body_id, joint_label], failures)
	if joint == null:
		return
	var depth := _transform_from_model(model, joint).origin.z
	TestAssertions.truthy(depth <= limit, "%s %s %s stays out from behind the back at %.2f (z=%.3f limit=%.3f)" % [action_id, body_id, joint_label, normalized_time, depth, limit], failures)

func _transform_from_model(model: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != model:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _assert_walk_quality(player: AnimationPlayer, failures: Array[String]) -> void:
	var walk := player.get_animation(&"walk")
	TestAssertions.truthy(walk != null and is_equal_approx(walk.length, 0.8), "walk is an authored 0.8 second loop", failures)
	if walk == null:
		return
	var left_foot_path := "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot"
	var right_foot_path := "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot"
	var left_foot_track := walk.find_track(NodePath("%s:rotation" % left_foot_path), Animation.TYPE_ROTATION_3D)
	var right_foot_track := walk.find_track(NodePath("%s:rotation" % right_foot_path), Animation.TYPE_ROTATION_3D)
	TestAssertions.truthy(left_foot_track >= 0, "walk authors the left foot pivot", failures)
	TestAssertions.truthy(right_foot_track >= 0, "walk authors the right foot pivot", failures)
	if left_foot_track < 0 or right_foot_track < 0:
		return
	var left_hip_0 := _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", 0.0)
	var left_hip_4 := _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot", 0.4)
	var right_hip_0 := _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/RightHipPivot", 0.0)
	var right_hip_4 := _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/RightHipPivot", 0.4)
	TestAssertions.truthy(left_hip_0 > 0.0 and left_hip_4 < 0.0 and right_hip_0 < 0.0 and right_hip_4 > 0.0, "walk hips alternate stride signs", failures)
	var left_knee_range := absf(_rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot", 0.4) - _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot", 0.0))
	var right_knee_range := absf(_rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot", 0.4) - _rotation_x(walk, "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot", 0.0))
	TestAssertions.truthy(left_knee_range >= 0.12 and right_knee_range >= 0.12, "walk knees visibly alternate flexion", failures)
	var baseline_low := minf(_foot_bottom(walk, true, 0.0), _foot_bottom(walk, false, 0.0))
	for support_time: float in [0.0, 0.4]:
		var support_low := minf(_foot_bottom(walk, true, support_time), _foot_bottom(walk, false, support_time))
		TestAssertions.near(support_low, baseline_low, 0.015, "walk support foot remains grounded at %.1f" % support_time, failures)
	TestAssertions.truthy(_poses_near(_sample_pose(walk, 0.0), _sample_pose(walk, 0.8), 0.001), "walk closes its stride loop", failures)

func _rotation_x(animation: Animation, node_path: String, time: float) -> float:
	var track := animation.find_track(NodePath("%s:rotation" % node_path), Animation.TYPE_ROTATION_3D)
	return animation.rotation_track_interpolate(track, time).get_euler().x if track >= 0 else 0.0

func _foot_bottom(animation: Animation, left: bool, time: float) -> float:
	var side := "Left" if left else "Right"
	var hip := _rotation_x(animation, "HitPivot/BodyPivot/HipsPivot/%sHipPivot" % side, time)
	var knee := _rotation_x(animation, "HitPivot/BodyPivot/HipsPivot/%sHipPivot/%sKneePivot" % [side, side], time)
	var foot := _rotation_x(animation, "HitPivot/BodyPivot/HipsPivot/%sHipPivot/%sKneePivot/%sFootPivot" % [side, side, side], time)
	return -0.48 * cos(hip) - 0.46 * cos(hip + knee) - 0.12 * cos(hip + knee + foot)

func _assert_idle_is_guarded(animation: Animation, action_id: StringName, failures: Array[String]) -> void:
	var samples: Array[Dictionary] = []
	for normalized_time: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var pose := _sample_pose(animation, normalized_time * animation.length)
		samples.append(pose)
		for suffix: String in ["LeftShoulderPivot:rotation", "RightShoulderPivot:rotation", "LeftElbowPivot:rotation", "RightElbowPivot:rotation"]:
			var value: Variant = _pose_value_for_suffix(pose, suffix)
			TestAssertions.truthy(value is Quaternion and (value as Quaternion).get_angle() >= 0.12, "%s keeps %s guarded at %.2f" % [action_id, suffix, normalized_time], failures)
	var torso_variation := _maximum_pose_delta(samples, "TorsoPivot:rotation")
	var hips_variation := _maximum_pose_delta(samples, "HipsPivot:position")
	TestAssertions.truthy(maxf(torso_variation, hips_variation) >= 0.015, "%s has breathing/weight variation" % action_id, failures)
	TestAssertions.truthy(_poses_near(samples[0], samples[-1], 0.001), "%s closes its idle loop" % action_id, failures)

func _assert_attack_has_phases(animation: Animation, action_id: StringName, failures: Array[String]) -> void:
	var pose_times: Array[float] = []
	var event_time := -1.0
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			if animation.track_get_key_count(track_index) > 0:
				event_time = animation.track_get_key_time(track_index, 0)
			continue
		for key_index: int in animation.track_get_key_count(track_index):
			var key_time := animation.track_get_key_time(track_index, key_index)
			if not _contains_near(pose_times, key_time):
				pose_times.append(key_time)
	pose_times.sort()
	TestAssertions.truthy(pose_times.size() >= 4, "%s has at least four authored phases" % action_id, failures)
	TestAssertions.truthy(event_time > pose_times[0] and event_time < pose_times[-1], "%s event occurs inside authored phases" % action_id, failures)
	var first := _sample_pose(animation, 0.0)
	var loaded := _sample_pose(animation, animation.length * 0.52)
	TestAssertions.truthy(_pose_delta(first, loaded, "TorsoPivot:rotation") >= 0.08, "%s changes torso through release" % action_id, failures)
	var hip_delta := maxf(_pose_delta(first, loaded, "LeftHipPivot:rotation"), _pose_delta(first, loaded, "RightHipPivot:rotation"))
	var arm_delta := maxf(_pose_delta(first, loaded, "LeftShoulderPivot:rotation"), _pose_delta(first, loaded, "RightShoulderPivot:rotation"))
	TestAssertions.truthy(hip_delta >= 0.08, "%s changes a hip through release" % action_id, failures)
	TestAssertions.truthy(arm_delta >= 0.08, "%s changes an arm through release" % action_id, failures)

func _track_signature(animation: Animation) -> String:
	var values: PackedStringArray = []
	for suffix: String in ["TorsoPivot:rotation", "LeftShoulderPivot:rotation", "LeftElbowPivot:rotation", "RightShoulderPivot:rotation", "RightElbowPivot:rotation", "LeftHipPivot:rotation", "RightHipPivot:rotation", "LeftKneePivot:rotation", "RightKneePivot:rotation"]:
		var first: Variant = _pose_value_for_suffix(_sample_pose(animation, 0.0), suffix)
		for normalized_time: float in POSE_SAMPLES:
			var value: Variant = _pose_value_for_suffix(_sample_pose(animation, normalized_time * animation.length), suffix)
			values.append(_rounded_delta(value, first))
	return "|".join(values)

func _sample_pose(animation: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	for track_index: int in animation.get_track_count():
		var sample_time := clampf(time, 0.0, animation.length)
		match animation.track_get_type(track_index):
			Animation.TYPE_POSITION_3D:
				pose[String(animation.track_get_path(track_index))] = animation.position_track_interpolate(track_index, sample_time)
			Animation.TYPE_ROTATION_3D:
				pose[String(animation.track_get_path(track_index))] = animation.rotation_track_interpolate(track_index, sample_time)
	return pose

func _pose_value_for_suffix(pose: Dictionary, suffix: String) -> Variant:
	for path: String in pose:
		if path.ends_with(suffix):
			return pose[path]
	return null

func _maximum_pose_delta(samples: Array[Dictionary], suffix: String) -> float:
	var maximum := 0.0
	var first: Variant = _pose_value_for_suffix(samples[0], suffix)
	for sample: Dictionary in samples:
		maximum = maxf(maximum, _value_delta(first, _pose_value_for_suffix(sample, suffix)))
	return maximum

func _pose_delta(first: Dictionary, second: Dictionary, suffix: String) -> float:
	return _value_delta(_pose_value_for_suffix(first, suffix), _pose_value_for_suffix(second, suffix))

func _value_delta(first: Variant, second: Variant) -> float:
	if first is Quaternion and second is Quaternion:
		return (first as Quaternion).angle_to(second as Quaternion)
	if first is Vector3 and second is Vector3:
		return (first as Vector3).distance_to(second as Vector3)
	return 0.0

func _rounded_delta(value: Variant, first: Variant) -> String:
	if value is Quaternion and first is Quaternion:
		var delta := ((first as Quaternion).inverse() * (value as Quaternion)).get_euler()
		return "%.3f,%.3f,%.3f" % [delta.x, delta.y, delta.z]
	if value is Vector3 and first is Vector3:
		var delta := (value as Vector3) - (first as Vector3)
		return "%.3f,%.3f,%.3f" % [delta.x, delta.y, delta.z]
	return "missing"

func _poses_near(first: Dictionary, last: Dictionary, tolerance: float) -> bool:
	for path: String in first:
		if not last.has(path) or _value_delta(first[path], last[path]) > tolerance:
			return false
	return true

func _contains_near(values: Array[float], candidate: float) -> bool:
	for value: float in values:
		if is_equal_approx(value, candidate):
			return true
	return false
