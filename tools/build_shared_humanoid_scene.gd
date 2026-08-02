extends SceneTree

const SOURCE := preload("res://scenes/characters/presentation/forge_vanguard_body_source.tscn")
const MODEL_SCRIPT := preload("res://scripts/presentation/forge_humanoid_model.gd")
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
	&"projectile_launch": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket/ProjectileLaunchSocket",
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
	print("FORGE_HUMANOID_BUILD_STAGE sockets_done")
	if not _configure_action_players(model):
		model.free(); return
	print("FORGE_HUMANOID_BUILD_STAGE save")
	_save(model)

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
