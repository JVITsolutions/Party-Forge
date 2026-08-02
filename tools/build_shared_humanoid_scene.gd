extends SceneTree

const SOURCE := preload("res://scenes/characters/presentation/forge_vanguard_body_source.tscn")
const MODEL_SCRIPT := preload("res://scripts/presentation/forge_humanoid_model.gd")
const ANIMATION_AUTHORING := preload("res://scripts/presentation/humanoid_animation_authoring.gd")
const OUTPUT := "res://scenes/characters/presentation/forge_humanoid_model.tscn"
const SOCKET_PATHS := {
	&"helmet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket",
	&"body_armour": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket",
	&"legs": "HitPivot/BodyPivot/HipsPivot/LegsSocket",
	&"gloves": "HitPivot/BodyPivot/HipsPivot/GlovesSocket",
	&"boots": "HitPivot/BodyPivot/HipsPivot/BootsSocket",
	&"amulet": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket",
	&"belt": "HitPivot/BodyPivot/HipsPivot/BeltSocket",
	&"main_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"off_hand": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	&"back": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/BackSocket",
}

func _initialize() -> void:
	print("FORGE_HUMANOID_BUILD_STAGE source")
	var model := SOURCE.instantiate() as Node3D
	if model == null:
		_fail("source instantiate failed"); return
	model.name = &"ForgeHumanoidModel"
	model.set_script(MODEL_SCRIPT)
	var removals: Array[Node] = []
	for node: Node in model.find_children("*", "Node3D", true, false):
		if node.has_meta(&"equipment_slot"):
			removals.append(node)
	for node: Node in removals:
		node.free()
	print("FORGE_HUMANOID_BUILD_STAGE removed=%d" % removals.size())
	print("FORGE_HUMANOID_BUILD_STAGE sockets")
	for socket_id: StringName in SOCKET_PATHS:
		if not _ensure_socket(model, NodePath(String(SOCKET_PATHS[socket_id]))):
			model.free(); return
	var back_socket := model.get_node("HitPivot/BodyPivot/HipsPivot/TorsoPivot/BackSocket") as Node3D
	back_socket.position = Vector3(0.0, 0.12, 0.24)
	print("FORGE_HUMANOID_BUILD_STAGE sockets_done")
	if not _configure_authored_action_players(model):
		model.free(); return
	print("FORGE_HUMANOID_BUILD_STAGE save")
	_save(model)

func _configure_authored_action_players(model: Node3D) -> bool:
	var action_player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if action_player == null or not action_player.has_animation(&"hit_flinch"):
		_fail("required source animation player or hit feedback is missing")
		return false
	action_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var library := action_player.get_animation_library(&"")
	if library == null:
		_fail("default animation library is missing")
		return false
	var idle_ids: Array[StringName] = [&"idle", &"paladin_idle", &"ranger_idle", &"marksman_idle", &"rogue_idle", &"mage_idle", &"frost_mage_idle", &"cleric_idle", &"warlock_idle"]
	for action_id: StringName in idle_ids:
		var idle := ANIMATION_AUTHORING.build_idle(action_id) as Animation
		if idle == null:
			_fail("idle authoring failed action=%s" % action_id)
			return false
		if library.has_animation(action_id):
			library.remove_animation(action_id)
		library.add_animation(action_id, idle)
	var attack_events := {
		&"attack_slash": &"impact",
		&"paladin_hammer_smite": &"impact",
		&"ranger_quick_bow_shot": &"release",
		&"marksman_heavy_bow_shot": &"release",
		&"rogue_dagger_flurry": &"impact",
		&"mage_fire_burst": &"release",
		&"frost_staff_shard": &"release",
		&"cleric_lightning_bolt": &"release",
		&"cleric_healing_blessing": &"release",
		&"warlock_chaos_bolt": &"release",
	}
	for action_id: StringName in attack_events:
		var attack := ANIMATION_AUTHORING.build_attack(action_id, attack_events[action_id]) as Animation
		if attack == null:
			_fail("attack authoring failed action=%s" % action_id)
			return false
		if library.has_animation(action_id):
			library.remove_animation(action_id)
		library.add_animation(action_id, attack)
	var feedback_player := AnimationPlayer.new()
	feedback_player.name = &"FeedbackAnimationPlayer"
	feedback_player.root_node = NodePath("..")
	model.add_child(feedback_player)
	var feedback_library := AnimationLibrary.new()
	var feedback := action_player.get_animation(&"hit_flinch").duplicate(true) as Animation
	for track_index: int in range(feedback.get_track_count() - 1, -1, -1):
		if String(feedback.track_get_path(track_index)) != "HitPivot:position":
			feedback.remove_track(track_index)
	feedback_library.add_animation(&"hit_flinch", feedback)
	feedback_player.add_animation_library(&"", feedback_library)
	return true

func _configure_action_players(model: Node3D) -> bool:
	var action_player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if action_player == null or not action_player.has_animation(&"attack_slash") or not action_player.has_animation(&"hit_flinch"):
		_fail("required action animations are missing")
		return false
	action_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var slash := action_player.get_animation(&"attack_slash")
	var method_track := slash.add_track(Animation.TYPE_METHOD)
	slash.track_set_path(method_track, NodePath("."))
	slash.track_insert_key(method_track, 0.28, {&"method": &"emit_action_event", &"args": [&"impact"]})
	var library := action_player.get_animation_library(&"")
	if library == null:
		_fail("default animation library is missing")
		return false
	var paladin_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	paladin_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(paladin_idle, {"TorsoPivot:rotation": Vector3(-0.04, 0, 0), "LeftShoulderPivot:rotation": Vector3(0.08, 0, 0.10), "RightShoulderPivot:rotation": Vector3(0.08, 0, -0.10)})
	var rogue_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	rogue_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(rogue_idle, {"TorsoPivot:rotation": Vector3(0.10, 0, 0), "LeftShoulderPivot:rotation": Vector3(-0.12, 0, 0.18), "RightShoulderPivot:rotation": Vector3(-0.12, 0, -0.18)})
	var paladin_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 0.86, 0.58)
	var rogue_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 0.28, 0.16)
	var ranger_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	ranger_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(ranger_idle, {"TorsoPivot:rotation": Vector3(0.05, -0.06, 0), "LeftShoulderPivot:rotation": Vector3(-0.18, -0.12, 0.18), "RightShoulderPivot:rotation": Vector3(-0.22, 0.18, -0.20), "LeftHipPivot:rotation": Vector3(0, 0, -0.04), "RightHipPivot:rotation": Vector3(0, 0, 0.04)})
	var marksman_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	marksman_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(marksman_idle, {"TorsoPivot:rotation": Vector3(-0.10, 0.08, 0), "LeftShoulderPivot:rotation": Vector3(-0.28, -0.18, 0.25), "RightShoulderPivot:rotation": Vector3(-0.34, 0.26, -0.28), "LeftHipPivot:rotation": Vector3(0, 0, -0.20), "RightHipPivot:rotation": Vector3(0, 0, 0.20)})
	var ranger_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 0.42, 0.18, &"release")
	var marksman_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 1.55, 1.15, &"release")
	if ranger_attack != null:
		_offset_rotation_tracks(ranger_attack, {"TorsoPivot:rotation": Vector3(0.06, -0.10, 0), "LeftShoulderPivot:rotation": Vector3(-0.22, -0.18, 0.20), "RightShoulderPivot:rotation": Vector3(-0.28, 0.22, -0.24), "LeftHipPivot:rotation": Vector3(0, 0, -0.04), "RightHipPivot:rotation": Vector3(0, 0, 0.04)})
	if marksman_attack != null:
		_offset_rotation_tracks(marksman_attack, {"TorsoPivot:rotation": Vector3(-0.16, 0.14, 0), "LeftShoulderPivot:rotation": Vector3(-0.34, -0.24, 0.28), "RightShoulderPivot:rotation": Vector3(-0.44, 0.34, -0.34), "LeftHipPivot:rotation": Vector3(0, 0, -0.20), "RightHipPivot:rotation": Vector3(0, 0, 0.20)})
	var mage_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	mage_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(mage_idle, {"TorsoPivot:rotation": Vector3(-0.02, -0.08, 0), "LeftShoulderPivot:rotation": Vector3(-0.24, -0.10, 0.34), "LeftElbowPivot:rotation": Vector3(-0.28, 0, 0.12), "RightShoulderPivot:rotation": Vector3(-0.12, 0.12, -0.16), "RightElbowPivot:rotation": Vector3(-0.18, 0, -0.08)})
	var frost_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	frost_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(frost_idle, {"TorsoPivot:rotation": Vector3(-0.06, 0, 0), "LeftShoulderPivot:rotation": Vector3(-0.30, -0.22, 0.30), "LeftElbowPivot:rotation": Vector3(-0.40, 0, 0.12), "RightShoulderPivot:rotation": Vector3(-0.30, 0.22, -0.30), "RightElbowPivot:rotation": Vector3(-0.40, 0, -0.12)})
	var cleric_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	cleric_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(cleric_idle, {"TorsoPivot:rotation": Vector3(-0.04, 0.06, 0), "LeftShoulderPivot:rotation": Vector3(-0.42, -0.12, 0.30), "LeftElbowPivot:rotation": Vector3(-0.36, 0, 0.16), "RightShoulderPivot:rotation": Vector3(-0.10, 0.08, -0.14), "RightElbowPivot:rotation": Vector3(-0.16, 0, -0.08)})
	var warlock_idle := action_player.get_animation(&"idle").duplicate(true) as Animation
	warlock_idle.loop_mode = Animation.LOOP_LINEAR
	_offset_rotation_tracks(warlock_idle, {"TorsoPivot:rotation": Vector3(0.12, -0.06, 0), "LeftShoulderPivot:rotation": Vector3(-0.32, -0.18, 0.24), "LeftElbowPivot:rotation": Vector3(-0.42, 0, 0.18), "RightShoulderPivot:rotation": Vector3(-0.38, 0.18, -0.24), "RightElbowPivot:rotation": Vector3(-0.46, 0, -0.18)})
	var mage_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 0.76, 0.46, &"release")
	var frost_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 0.88, 0.52, &"release")
	var cleric_lightning := _scaled_action(action_player.get_animation(&"attack_slash"), 0.62, 0.34, &"release")
	var cleric_heal := _scaled_action(action_player.get_animation(&"attack_slash"), 1.08, 0.72, &"release")
	var warlock_attack := _scaled_action(action_player.get_animation(&"attack_slash"), 1.02, 0.64, &"release")
	if mage_attack != null:
		_offset_rotation_tracks(mage_attack, {"TorsoPivot:rotation": Vector3(-0.08, -0.16, 0), "LeftShoulderPivot:rotation": Vector3(-0.48, -0.20, 0.40), "LeftElbowPivot:rotation": Vector3(-0.44, 0, 0.20), "RightShoulderPivot:rotation": Vector3(-0.20, 0.24, -0.22)})
	if frost_attack != null:
		_offset_rotation_tracks(frost_attack, {"TorsoPivot:rotation": Vector3(-0.16, 0, 0), "LeftShoulderPivot:rotation": Vector3(-0.48, -0.28, 0.36), "RightShoulderPivot:rotation": Vector3(-0.48, 0.28, -0.36), "LeftElbowPivot:rotation": Vector3(-0.50, 0, 0.20), "RightElbowPivot:rotation": Vector3(-0.50, 0, -0.20)})
	if cleric_lightning != null:
		_offset_rotation_tracks(cleric_lightning, {"TorsoPivot:rotation": Vector3(-0.10, 0.12, 0), "LeftShoulderPivot:rotation": Vector3(-0.46, -0.18, 0.36), "RightShoulderPivot:rotation": Vector3(-0.22, 0.18, -0.20)})
	if cleric_heal != null:
		_offset_rotation_tracks(cleric_heal, {"TorsoPivot:rotation": Vector3(-0.14, 0, 0), "LeftShoulderPivot:rotation": Vector3(-0.58, -0.16, 0.42), "RightShoulderPivot:rotation": Vector3(-0.58, 0.16, -0.42), "LeftElbowPivot:rotation": Vector3(-0.38, 0, 0.18), "RightElbowPivot:rotation": Vector3(-0.38, 0, -0.18)})
	if warlock_attack != null:
		_offset_rotation_tracks(warlock_attack, {"TorsoPivot:rotation": Vector3(0.18, -0.14, 0), "LeftShoulderPivot:rotation": Vector3(-0.52, -0.24, 0.32), "RightShoulderPivot:rotation": Vector3(-0.58, 0.30, -0.36), "LeftElbowPivot:rotation": Vector3(-0.56, 0, 0.22), "RightElbowPivot:rotation": Vector3(-0.60, 0, -0.24)})
	if paladin_attack == null or rogue_attack == null or ranger_attack == null or marksman_attack == null or mage_attack == null or frost_attack == null or cleric_lightning == null or cleric_heal == null or warlock_attack == null:
		_fail("class action generation failed")
		return false
	library.add_animation(&"paladin_idle", paladin_idle)
	library.add_animation(&"rogue_idle", rogue_idle)
	library.add_animation(&"paladin_hammer_smite", paladin_attack)
	library.add_animation(&"rogue_dagger_flurry", rogue_attack)
	library.add_animation(&"ranger_idle", ranger_idle)
	library.add_animation(&"marksman_idle", marksman_idle)
	library.add_animation(&"ranger_quick_bow_shot", ranger_attack)
	library.add_animation(&"marksman_heavy_bow_shot", marksman_attack)
	library.add_animation(&"mage_idle", mage_idle)
	library.add_animation(&"frost_mage_idle", frost_idle)
	library.add_animation(&"cleric_idle", cleric_idle)
	library.add_animation(&"warlock_idle", warlock_idle)
	library.add_animation(&"mage_fire_burst", mage_attack)
	library.add_animation(&"frost_staff_shard", frost_attack)
	library.add_animation(&"cleric_lightning_bolt", cleric_lightning)
	library.add_animation(&"cleric_healing_blessing", cleric_heal)
	library.add_animation(&"warlock_chaos_bolt", warlock_attack)
	var feedback_player := AnimationPlayer.new()
	feedback_player.name = &"FeedbackAnimationPlayer"
	feedback_player.root_node = NodePath("..")
	model.add_child(feedback_player)
	var feedback_library := AnimationLibrary.new()
	var feedback := action_player.get_animation(&"hit_flinch").duplicate(true) as Animation
	for track_index: int in range(feedback.get_track_count() - 1, -1, -1):
		if String(feedback.track_get_path(track_index)) != "HitPivot:position":
			feedback.remove_track(track_index)
	feedback_library.add_animation(&"hit_flinch", feedback)
	feedback_player.add_animation_library(&"", feedback_library)
	return true

func _scaled_action(source: Animation, target_duration: float, event_time: float, event_name: StringName = &"impact") -> Animation:
	if source == null or source.length <= 0.0:
		return null
	var result := source.duplicate(true) as Animation
	var scale := target_duration / source.length
	for track_index: int in range(result.get_track_count() - 1, -1, -1):
		if result.track_get_type(track_index) == Animation.TYPE_METHOD:
			result.remove_track(track_index)
			continue
		for key_index: int in result.track_get_key_count(track_index):
			result.track_set_key_time(track_index, key_index, result.track_get_key_time(track_index, key_index) * scale)
	result.length = target_duration
	result.loop_mode = Animation.LOOP_NONE
	var method_track := result.add_track(Animation.TYPE_METHOD)
	result.track_set_path(method_track, NodePath("."))
	result.track_insert_key(method_track, event_time, {&"method": &"emit_action_event", &"args": [event_name]})
	return result

func _offset_rotation_tracks(animation: Animation, offsets: Dictionary) -> void:
	for track_index: int in animation.get_track_count():
		var path := String(animation.track_get_path(track_index))
		for suffix: String in offsets:
			if not path.ends_with(suffix):
				continue
			for key_index: int in animation.track_get_key_count(track_index):
				var value: Variant = animation.track_get_key_value(track_index, key_index)
				if value is Vector3:
					animation.track_set_key_value(track_index, key_index, value + offsets[suffix])
				elif value is Quaternion:
					var offset := Quaternion.from_euler(offsets[suffix] as Vector3)
					animation.track_set_key_value(track_index, key_index, offset * (value as Quaternion))

func _ensure_socket(model: Node3D, path: NodePath) -> bool:
	if model.get_node_or_null(path) != null: return true
	var text := String(path)
	var parent_path := NodePath(text.rsplit("/", false, 1)[0])
	var parent := model.get_node_or_null(parent_path) as Node3D
	if parent == null:
		_fail("missing socket parent %s" % parent_path); return false
	var socket := Node3D.new(); socket.name = StringName(text.get_file()); parent.add_child(socket)
	return true

func _save(model: Node3D) -> void:
	_set_owners(model, model)
	var packed := PackedScene.new()
	if packed.pack(model) != OK or ResourceSaver.save(packed, OUTPUT) != OK:
		_fail("pack or save failed"); return
	model.free()
	if not _remove_generated_node_ids(OUTPUT):
		_fail("stabilize scene failed"); return
	print("FORGE_HUMANOID_BUILD_OK path=%s" % OUTPUT)
	quit(0)

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children(): child.owner = root; _set_owners(child, root)
func _remove_generated_node_ids(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var expression := RegEx.new()
	if expression.compile(" unique_id=[0-9]+") != OK: return false
	var stable := expression.sub(file.get_as_text(), "", true)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(stable)
	return file.get_error() == OK
func _fail(reason: String) -> void: push_error("FORGE_HUMANOID_BUILD_ERROR reason=%s" % reason); quit(1)
