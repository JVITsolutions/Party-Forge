class_name HumanoidAnimationAuthoring
extends RefCounted

const HIT := "HitPivot"
const BODY := "HitPivot/BodyPivot"
const HIPS := "HitPivot/BodyPivot/HipsPivot"
const TORSO := "HitPivot/BodyPivot/HipsPivot/TorsoPivot"
const LEFT_SHOULDER := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot"
const LEFT_ELBOW := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot"
const RIGHT_SHOULDER := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot"
const RIGHT_ELBOW := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot"
const LEFT_HIP := "HitPivot/BodyPivot/HipsPivot/LeftHipPivot"
const LEFT_KNEE := "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot"
const LEFT_FOOT := "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot"
const RIGHT_HIP := "HitPivot/BodyPivot/HipsPivot/RightHipPivot"
const RIGHT_KNEE := "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot"
const RIGHT_FOOT := "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot"
const IDLE_TIMES: Array[float] = [0.0, 0.4, 0.8, 1.2, 1.6]
const PHASES: Array[float] = [0.0, 0.28, 0.52, 0.76, 1.0]
const ATTACK_TIMING := {
	&"attack_slash": [0.55, 0.28],
	&"paladin_hammer_smite": [0.86, 0.58],
	&"ranger_quick_bow_shot": [0.42, 0.18],
	&"marksman_heavy_bow_shot": [1.55, 1.15],
	&"rogue_dagger_flurry": [0.28, 0.16],
	&"mage_fire_burst": [0.76, 0.46],
	&"frost_staff_shard": [0.88, 0.52],
	&"cleric_lightning_bolt": [0.62, 0.34],
	&"cleric_healing_blessing": [1.08, 0.72],
	&"warlock_chaos_bolt": [1.02, 0.64],
}

static func build_idle(action_id: StringName) -> Animation:
	var style := _idle_style(action_id)
	var animation := Animation.new()
	animation.length = IDLE_TIMES[-1]
	animation.loop_mode = Animation.LOOP_LINEAR
	var torso_y := float(style[&"torso_y"])
	var shoulder_x := float(style[&"shoulder_x"])
	var shoulder_z := float(style[&"shoulder_z"])
	var elbow_x := float(style[&"elbow_x"])
	var elbow_z := float(style[&"elbow_z"])
	var left_shoulder_base := Vector3(shoulder_x, -0.08, shoulder_z)
	var right_shoulder_base := Vector3(shoulder_x, 0.08, -shoulder_z)
	var left_elbow_base := Vector3(elbow_x, 0.0, elbow_z)
	var right_elbow_base := Vector3(elbow_x, 0.0, -elbow_z)
	if action_id == &"idle":
		left_shoulder_base = Vector3(-0.28, -0.05, -0.55)
		right_shoulder_base = Vector3(-0.18, -0.16, 0.34)
		left_elbow_base = Vector3(0.10, 0.0, -0.65)
		right_elbow_base = Vector3(0.10, 0.0, 0.38)
	_add_rotation_track(animation, TORSO, _five(
		Vector3(-0.04, torso_y, 0.0), Vector3(-0.025, torso_y + 0.018, 0.01), Vector3(-0.055, torso_y, 0.0), Vector3(-0.025, torso_y - 0.018, -0.01), Vector3(-0.04, torso_y, 0.0)
	), IDLE_TIMES)
	_add_rotation_track(animation, LEFT_SHOULDER, _five(
		left_shoulder_base, left_shoulder_base + Vector3(-0.025, 0.01, 0.015), left_shoulder_base + Vector3(-0.01, 0, 0), left_shoulder_base + Vector3(0.015, -0.01, -0.015), left_shoulder_base
	), IDLE_TIMES)
	_add_rotation_track(animation, RIGHT_SHOULDER, _five(
		right_shoulder_base, right_shoulder_base + Vector3(0.015, 0.01, 0.015), right_shoulder_base + Vector3(-0.01, 0, 0), right_shoulder_base + Vector3(-0.025, -0.01, -0.015), right_shoulder_base
	), IDLE_TIMES)
	_add_rotation_track(animation, LEFT_ELBOW, _constant_guard(left_elbow_base, 0.018), IDLE_TIMES)
	_add_rotation_track(animation, RIGHT_ELBOW, _constant_guard(right_elbow_base, -0.018), IDLE_TIMES)
	_add_position_track(animation, HIPS, _five(Vector3.ZERO, Vector3(0.0, 0.012, 0.0), Vector3(0.0, 0.022, 0.0), Vector3(0.0, 0.012, 0.0), Vector3.ZERO), IDLE_TIMES)
	var hip_spread := 0.22 if action_id == &"marksman_idle" else (0.06 if action_id == &"ranger_idle" else 0.05)
	_add_rotation_track(animation, LEFT_HIP, _constant_guard(Vector3(0.02, 0.0, -hip_spread), 0.012), IDLE_TIMES)
	_add_rotation_track(animation, RIGHT_HIP, _constant_guard(Vector3(0.02, 0.0, hip_spread), -0.012), IDLE_TIMES)
	return animation

static func build_walk(action_id: StringName) -> Animation:
	var animation := Animation.new()
	animation.length = 0.8
	animation.loop_mode = Animation.LOOP_LINEAR
	var times: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8]
	_add_rotation_track(animation, LEFT_HIP, _five(Vector3(0.42, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.42, 0, 0), Vector3(-0.08, 0, 0), Vector3(0.42, 0, 0)), times)
	_add_rotation_track(animation, LEFT_KNEE, _five(Vector3(0.12, 0, 0), Vector3(0.30, 0, 0), Vector3(0.36, 0, 0), Vector3(0.18, 0, 0), Vector3(0.12, 0, 0)), times)
	_add_rotation_track(animation, LEFT_FOOT, _five(Vector3(-0.08, 0, 0), Vector3(-0.16, 0, 0), Vector3(0.18, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.08, 0, 0)), times)
	_add_rotation_track(animation, RIGHT_HIP, _five(Vector3(-0.42, 0, 0), Vector3(-0.08, 0, 0), Vector3(0.42, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.42, 0, 0)), times)
	_add_rotation_track(animation, RIGHT_KNEE, _five(Vector3(0.36, 0, 0), Vector3(0.18, 0, 0), Vector3(0.12, 0, 0), Vector3(0.30, 0, 0), Vector3(0.36, 0, 0)), times)
	_add_rotation_track(animation, RIGHT_FOOT, _five(Vector3(0.18, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.08, 0, 0), Vector3(-0.16, 0, 0), Vector3(0.18, 0, 0)), times)
	_add_position_track(animation, BODY, _five(Vector3.ZERO, Vector3(0, -0.025, 0), Vector3.ZERO, Vector3(0, -0.025, 0), Vector3.ZERO), times)
	_add_rotation_track(animation, TORSO, _five(Vector3(-0.04, 0.08, 0), Vector3(-0.04, 0, 0), Vector3(-0.04, -0.08, 0), Vector3(-0.04, 0, 0), Vector3(-0.04, 0.08, 0)), times)
	_add_rotation_track(animation, LEFT_SHOULDER, _five(Vector3(-0.28, -0.05, -0.55), Vector3(-0.24, -0.05, -0.50), Vector3(-0.32, -0.05, -0.58), Vector3(-0.30, -0.05, -0.56), Vector3(-0.28, -0.05, -0.55)), times)
	_add_rotation_track(animation, LEFT_ELBOW, _five(Vector3(0.10, 0, -0.65), Vector3(0.14, 0, -0.62), Vector3(0.08, 0, -0.68), Vector3(0.06, 0, -0.66), Vector3(0.10, 0, -0.65)), times)
	_add_rotation_track(animation, RIGHT_SHOULDER, _five(Vector3(-0.18, -0.16, 0.34), Vector3(-0.22, -0.16, 0.38), Vector3(-0.15, -0.16, 0.30), Vector3(-0.16, -0.16, 0.32), Vector3(-0.18, -0.16, 0.34)), times)
	_add_rotation_track(animation, RIGHT_ELBOW, _five(Vector3(0.10, 0, 0.38), Vector3(0.06, 0, 0.36), Vector3(0.14, 0, 0.42), Vector3(0.12, 0, 0.40), Vector3(0.10, 0, 0.38)), times)
	return animation

static func build_attack(action_id: StringName, event_name: StringName) -> Animation:
	if not ATTACK_TIMING.has(action_id):
		return null
	var timing: Array = ATTACK_TIMING[action_id]
	var duration := float(timing[0])
	var event_time := float(timing[1])
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_NONE
	var times: Array[float] = []
	for normalized_time: float in PHASES:
		times.append(normalized_time * duration)
	var pose_data := _attack_pose_data(action_id)
	for path: String in pose_data:
		var values: Array[Vector3] = []
		values.assign(pose_data[path])
		_add_rotation_track(animation, path, values, times)
	var event_track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(event_track, NodePath("."))
	animation.track_insert_key(event_track, event_time, {&"method": &"emit_action_event", &"args": [event_name]})
	return animation

static func sample_pose(animation: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	if animation == null:
		return pose
	var sample_time := clampf(time, 0.0, animation.length)
	for track_index: int in animation.get_track_count():
		match animation.track_get_type(track_index):
			Animation.TYPE_POSITION_3D:
				pose[String(animation.track_get_path(track_index))] = animation.position_track_interpolate(track_index, sample_time)
			Animation.TYPE_ROTATION_3D:
				pose[String(animation.track_get_path(track_index))] = animation.rotation_track_interpolate(track_index, sample_time)
	return pose

static func _idle_style(action_id: StringName) -> Dictionary:
	match action_id:
		&"paladin_idle": return {&"torso_y": 0.0, &"shoulder_x": -0.30, &"shoulder_z": 0.38, &"elbow_x": -0.50, &"elbow_z": 0.16}
		&"ranger_idle": return {&"torso_y": -0.08, &"shoulder_x": -0.42, &"shoulder_z": 0.30, &"elbow_x": -0.48, &"elbow_z": 0.18}
		&"marksman_idle": return {&"torso_y": 0.10, &"shoulder_x": -0.52, &"shoulder_z": 0.34, &"elbow_x": -0.58, &"elbow_z": 0.20}
		&"rogue_idle": return {&"torso_y": -0.05, &"shoulder_x": -0.46, &"shoulder_z": 0.44, &"elbow_x": -0.62, &"elbow_z": 0.22}
		&"mage_idle": return {&"torso_y": -0.10, &"shoulder_x": -0.38, &"shoulder_z": 0.40, &"elbow_x": -0.54, &"elbow_z": 0.22}
		&"frost_mage_idle": return {&"torso_y": 0.0, &"shoulder_x": -0.54, &"shoulder_z": 0.34, &"elbow_x": -0.62, &"elbow_z": 0.18}
		&"cleric_idle": return {&"torso_y": 0.07, &"shoulder_x": -0.40, &"shoulder_z": 0.42, &"elbow_x": -0.52, &"elbow_z": 0.20}
		&"warlock_idle": return {&"torso_y": -0.14, &"shoulder_x": -0.56, &"shoulder_z": 0.36, &"elbow_x": -0.66, &"elbow_z": 0.24}
	return {&"torso_y": 0.0, &"shoulder_x": -0.34, &"shoulder_z": 0.36, &"elbow_x": -0.48, &"elbow_z": 0.16}

static func _attack_pose_data(action_id: StringName) -> Dictionary:
	var data := _base_attack_pose()
	match action_id:
		&"attack_slash":
			_set_phases(data, TORSO, Vector3(0, -0.28, 0), Vector3(0, 0.34, 0), Vector3(0, -0.18, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.85, 0, -0.35), Vector3(0.35, 0, 0.70), Vector3(0.10, 0, 0.22))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.55, 0, -0.30), Vector3(-0.18, 0, 0.18), Vector3(-0.35, 0, 0.08))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.30, 0, 0.44), Vector3(-0.38, 0, 0.34), Vector3(-0.26, 0, 0.40))
			_set_phases(data, LEFT_HIP, Vector3(0.10, 0, 0), Vector3(0.18, 0, 0), Vector3(0.08, 0, 0))
			_set_phases(data, RIGHT_KNEE, Vector3(0.12, 0, 0), Vector3(0.24, 0, 0), Vector3(0.10, 0, 0))
		&"paladin_hammer_smite":
			_set_phases(data, TORSO, Vector3(-0.08, -0.16, 0), Vector3(-0.12, 0.18, 0), Vector3(-0.06, -0.10, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-1.15, 0, -0.20), Vector3(0.48, 0, 0.18), Vector3(0.20, 0, 0.08))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.72, 0, -0.14), Vector3(-0.22, 0, 0.04), Vector3(-0.44, 0, 0.02))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.36, 0, 0.40), Vector3(-0.42, 0, 0.44), Vector3(-0.34, 0, 0.38))
			_set_phases(data, LEFT_HIP, Vector3(0.12, 0, 0), Vector3(0.24, 0, 0), Vector3(0.10, 0, 0))
			_set_phases(data, RIGHT_HIP, Vector3(0.12, 0, 0), Vector3(0.24, 0, 0), Vector3(0.10, 0, 0))
		&"ranger_quick_bow_shot":
			_set_phases(data, TORSO, Vector3(0, 0.34, 0), Vector3(-0.08, 0.18, 0), Vector3(0, 0.06, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.42, 0, -0.18), Vector3(-0.18, 0, -0.08), Vector3(-0.30, 0, -0.12))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.74, 0, 0.58), Vector3(-0.30, 0, 0.24), Vector3(-0.42, 0, 0.30))
			_set_phases(data, RIGHT_HIP, Vector3(0, 0, -0.12), Vector3(0, 0, 0.14), Vector3(0, 0, -0.06))
			_set_phases(data, LEFT_KNEE, Vector3(0.10, 0, 0), Vector3(0.18, 0, 0), Vector3(0.08, 0, 0))
		&"marksman_heavy_bow_shot":
			_set_phases(data, TORSO, Vector3(-0.08, 0.42, 0), Vector3(-0.14, 0.22, 0), Vector3(-0.04, 0.08, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.55, 0, -0.22), Vector3(-0.26, 0, -0.10), Vector3(-0.38, 0, -0.16))
			_set_phases(data, LEFT_SHOULDER, Vector3(-1.02, 0, 0.72), Vector3(-0.42, 0, 0.32), Vector3(-0.56, 0, 0.38))
			_set_phases(data, LEFT_HIP, Vector3(0.14, 0, -0.08), Vector3(0.28, 0, 0.10), Vector3(0.12, 0, -0.04))
			_set_phases(data, RIGHT_KNEE, Vector3(0.16, 0, 0), Vector3(0.28, 0, 0), Vector3(0.12, 0, 0))
		&"rogue_dagger_flurry":
			_set_phases(data, TORSO, Vector3(0, -0.30, 0), Vector3(-0.10, 0.32, 0), Vector3(0, -0.22, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.62, 0, -0.42), Vector3(0.18, 0, 0.50), Vector3(-0.38, 0, -0.20))
			_set_phases(data, LEFT_SHOULDER, Vector3(0.12, 0, 0.48), Vector3(-0.58, 0, -0.36), Vector3(-0.20, 0, 0.28))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.44, 0, -0.18), Vector3(0.22, 0, 0.20), Vector3(-0.30, 0, -0.10))
			_set_phases(data, LEFT_HIP, Vector3(0, 0, 0.22), Vector3(0, 0, -0.22), Vector3(0, 0, 0.12))
		&"mage_fire_burst":
			_set_phases(data, TORSO, Vector3(-0.08, -0.22, 0), Vector3(-0.12, 0.16, 0), Vector3(-0.04, -0.08, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.54, 0, -0.30), Vector3(-0.08, 0, 0.36), Vector3(-0.24, 0, 0.10))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.42, 0, -0.12), Vector3(-0.18, 0, 0.16), Vector3(-0.30, 0, 0.04))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.38, 0, 0.42), Vector3(-0.52, 0, 0.48), Vector3(-0.40, 0, 0.34))
			_set_phases(data, LEFT_HIP, Vector3(0.10, 0, 0), Vector3(0.18, 0, 0), Vector3(0.08, 0, 0))
		&"frost_staff_shard":
			_set_phases(data, TORSO, Vector3(-0.10, 0.18, 0), Vector3(-0.16, -0.12, 0), Vector3(-0.05, -0.04, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.62, 0, -0.30), Vector3(-0.22, 0, 0.18), Vector3(-0.42, 0, -0.12))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.62, 0, 0.30), Vector3(-0.22, 0, -0.18), Vector3(-0.42, 0, 0.12))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.52, 0, -0.18), Vector3(-0.30, 0, 0.12), Vector3(-0.40, 0, -0.08))
			_set_phases(data, RIGHT_HIP, Vector3(0.12, 0, 0), Vector3(0.20, 0, 0), Vector3(0.08, 0, 0))
		&"cleric_lightning_bolt":
			_set_phases(data, TORSO, Vector3(-0.06, -0.18, 0), Vector3(-0.12, 0.14, 0), Vector3(-0.04, -0.06, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.58, 0, -0.22), Vector3(-0.06, 0, 0.30), Vector3(-0.22, 0, 0.08))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.44, 0, 0.38), Vector3(-0.50, 0, 0.46), Vector3(-0.38, 0, 0.34))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.40, 0, -0.14), Vector3(-0.16, 0, 0.14), Vector3(-0.28, 0, 0.02))
			_set_phases(data, LEFT_HIP, Vector3(0.08, 0, 0), Vector3(0.16, 0, 0), Vector3(0.06, 0, 0))
		&"cleric_healing_blessing":
			_set_phases(data, TORSO, Vector3(-0.08, 0, 0), Vector3(-0.14, 0, 0), Vector3(-0.06, 0, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.82, 0, -0.48), Vector3(-0.28, 0, 0.22), Vector3(-0.50, 0, -0.28))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.82, 0, 0.48), Vector3(-0.28, 0, -0.22), Vector3(-0.50, 0, 0.28))
			_set_phases(data, LEFT_HIP, Vector3(0.08, 0, 0), Vector3(0.16, 0, 0), Vector3(0.06, 0, 0))
			_set_phases(data, RIGHT_KNEE, Vector3(0.08, 0, 0), Vector3(0.18, 0, 0), Vector3(0.06, 0, 0))
		&"warlock_chaos_bolt":
			_set_phases(data, TORSO, Vector3(0.10, 0.26, 0), Vector3(-0.16, -0.20, 0), Vector3(0.06, -0.12, 0))
			_set_phases(data, RIGHT_SHOULDER, Vector3(-0.74, 0, -0.34), Vector3(0.06, 0, 0.40), Vector3(-0.28, 0, 0.14))
			_set_phases(data, LEFT_SHOULDER, Vector3(-0.52, 0, 0.36), Vector3(-0.60, 0, 0.48), Vector3(-0.42, 0, 0.30))
			_set_phases(data, RIGHT_ELBOW, Vector3(-0.56, 0, -0.22), Vector3(-0.22, 0, 0.18), Vector3(-0.38, 0, -0.10))
			_set_phases(data, RIGHT_HIP, Vector3(0, 0, -0.14), Vector3(0, 0, 0.18), Vector3(0, 0, -0.08))
	return data

static func _base_attack_pose() -> Dictionary:
	return {
		TORSO: _same_five(Vector3(-0.04, 0, 0)),
		LEFT_SHOULDER: _same_five(Vector3(-0.28, -0.05, -0.55)),
		LEFT_ELBOW: _same_five(Vector3(0.10, 0.0, -0.65)),
		RIGHT_SHOULDER: _same_five(Vector3(-0.18, -0.16, 0.34)),
		RIGHT_ELBOW: _same_five(Vector3(0.10, 0.0, 0.38)),
		LEFT_HIP: _same_five(Vector3(0.02, 0, -0.05)),
		RIGHT_HIP: _same_five(Vector3(0.02, 0, 0.05)),
		LEFT_KNEE: _same_five(Vector3(0.08, 0, 0)),
		RIGHT_KNEE: _same_five(Vector3(0.08, 0, 0)),
	}

static func _set_phases(data: Dictionary, path: String, loaded: Vector3, release: Vector3, follow: Vector3) -> void:
	var current: Array[Vector3] = []
	current.assign(data[path])
	data[path] = _five(current[0], loaded, release, follow, current[0])

static func _add_rotation_track(animation: Animation, path: String, values: Array[Vector3], times: Array[float]) -> void:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:rotation" % path))
	for index: int in mini(values.size(), times.size()):
		animation.track_insert_key(track, times[index], Quaternion.from_euler(values[index]))

static func _add_position_track(animation: Animation, path: String, values: Array[Vector3], times: Array[float]) -> void:
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("%s:position" % path))
	for index: int in mini(values.size(), times.size()):
		animation.track_insert_key(track, times[index], values[index])

static func _same_five(value: Vector3) -> Array[Vector3]:
	return [value, value, value, value, value]

static func _five(first: Vector3, second: Vector3, third: Vector3, fourth: Vector3, fifth: Vector3) -> Array[Vector3]:
	return [first, second, third, fourth, fifth]

static func _constant_guard(base: Vector3, variation: float) -> Array[Vector3]:
	return _five(base, base + Vector3(variation, 0, 0), base, base - Vector3(variation, 0, 0), base)
