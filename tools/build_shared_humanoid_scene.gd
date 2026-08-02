extends SceneTree

const SOURCE := preload("res://scenes/characters/presentation/forge_vanguard_model.tscn")
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
		_ensure_socket(model, NodePath(String(SOCKET_PATHS[socket_id])))
	print("FORGE_HUMANOID_BUILD_STAGE sockets_done")
	print("FORGE_HUMANOID_BUILD_STAGE save")
	_save(model)

func _ensure_socket(model: Node3D, path: NodePath) -> void:
	if model.get_node_or_null(path) != null: return
	var text := String(path)
	var parent_path := NodePath(text.rsplit("/", false, 1)[0])
	var parent := model.get_node_or_null(parent_path) as Node3D
	if parent == null:
		_fail("missing socket parent %s" % parent_path); return
	var socket := Node3D.new(); socket.name = StringName(text.get_file()); parent.add_child(socket)

func _save(model: Node3D) -> void:
	_set_owners(model, model)
	var packed := PackedScene.new()
	if packed.pack(model) != OK or ResourceSaver.save(packed, OUTPUT) != OK:
		_fail("pack or save failed"); return
	model.free()
	print("FORGE_HUMANOID_BUILD_OK path=%s" % OUTPUT)
	quit(0)

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children(): child.owner = root; _set_owners(child, root)
func _fail(reason: String) -> void: push_error("FORGE_HUMANOID_BUILD_ERROR reason=%s" % reason); quit(1)
