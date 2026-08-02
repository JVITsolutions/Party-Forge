extends SceneTree

# Creates the immutable, baked input for the item-scene generator. This is a
# separate source artifact; build_equipment_assets.gd never reads its outputs.
const IDS: Array[StringName] = ClassEquipmentRows.SET_ITEM_IDS[&"fighter"]
const OUTPUT := "res://scenes/characters/presentation/forge_vanguard_equipment_source.tscn"

func _initialize() -> void:
	var source := Node3D.new()
	source.name = &"ForgeVanguardEquipmentSource"
	for item_id: StringName in IDS:
		var item_scene := load("res://scenes/equipment/forge_vanguard/%s.tscn" % item_id) as PackedScene
		if item_scene == null:
			_fail("missing authored input %s" % item_id)
			return
		var item := item_scene.instantiate() as Node3D
		if item == null:
			_fail("could not instantiate authored input %s" % item_id)
			return
		item.name = item_id
		source.add_child(item)
	_set_owners(source, source)
	var packed := PackedScene.new()
	if packed.pack(source) != OK or ResourceSaver.save(packed, OUTPUT) != OK:
		_fail("could not save baked equipment source")
		return
	source.free()
	if not _remove_generated_node_ids():
		_fail("could not stabilize baked equipment source")
		return
	print("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_OK items=%d" % IDS.size())
	quit(0)

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_set_owners(child, root)

func _remove_generated_node_ids() -> bool:
	var file := FileAccess.open(OUTPUT, FileAccess.READ)
	if file == null: return false
	var expression := RegEx.new()
	if expression.compile(" unique_id=[0-9]+") != OK: return false
	var stable := expression.sub(file.get_as_text(), "", true)
	file = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null: return false
	file.store_string(stable)
	return file.get_error() == OK

func _fail(reason: String) -> void:
	push_error("FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_ERROR reason=%s" % reason)
	quit(1)
