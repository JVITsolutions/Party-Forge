extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_failed_replacement_and_clear(failures)
	_test_icon_only_entry(failures)
	_test_multi_socket_item(failures)
	_test_item_colors_and_wearer_accent_isolation(failures)
	return failures

func _test_failed_replacement_and_clear(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"MainHandSocket"])
	var first := _visual(&"first_sword", &"main_hand", &"MainHandSocket", _single_attachment_scene())
	var invalid := _visual(&"invalid_sword", &"main_hand", &"MissingSocket", _single_attachment_scene())
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", first), "first item equips", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "first item is recorded", failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", invalid), "missing socket rejects equip", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "failed equip preserves old item", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"main_hand"), "clear succeeds", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"", "clear removes item", failures)
	_free_model(model)

func _test_icon_only_entry(failures: Array[String]) -> void:
	var model := _model_with_sockets([])
	var icon_only := _visual(&"cosmetic_badge", &"belt", &"", null)
	icon_only.combat_visible = false
	TestAssertions.truthy(model.apply_equipment_visual(&"belt", icon_only), "icon-only entry equips without a scene", failures)
	TestAssertions.equal(model.equipped_item_id(&"belt"), &"cosmetic_badge", "icon-only entry is recorded", failures)
	_free_model(model)

func _test_multi_socket_item(failures: Array[String]) -> void:
	var model := _model_with_sockets([&"LeftHandSocket", &"RightHandSocket"])
	var paired := _visual(&"paired_daggers", &"main_hand", &"RightHandSocket", _paired_attachment_scene())
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", paired), "multi-socket item equips", failures)
	TestAssertions.equal(model.get_node("LeftHandSocket/LeftAttachment").name, &"LeftAttachment", "left attachment reaches left socket", failures)
	TestAssertions.equal(model.get_node("RightHandSocket/RightAttachment").name, &"RightAttachment", "right attachment reaches right socket", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"paired_daggers", "multi-socket item is recorded once", failures)
	_free_model(model)

func _test_item_colors_and_wearer_accent_isolation(failures: Array[String]) -> void:
	var scene := _colored_attachment_scene()
	var definition := _visual(&"accented_sword", &"main_hand", &"MainHandSocket", scene)
	definition.item_colors = {&"metal": Color(0.1, 0.8, 0.2, 1.0)}
	definition.wearer_accent_channel = &"accent"
	var first := _model_with_sockets([&"MainHandSocket"])
	var second := _model_with_sockets([&"MainHandSocket"])
	first.set_palette(&"red", Color(0.9, 0.1, 0.1, 1.0))
	second.set_palette(&"red", Color(0.1, 0.1, 0.9, 1.0))
	TestAssertions.truthy(first.apply_equipment_visual(&"main_hand", definition), "first colored item equips", failures)
	TestAssertions.truthy(second.apply_equipment_visual(&"main_hand", definition), "second colored item equips", failures)
	var first_metal := first.get_node("MainHandSocket/ColoredAttachment/Metal") as MeshInstance3D
	var first_accent := first.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	var second_accent := second.get_node("MainHandSocket/ColoredAttachment/Accent") as MeshInstance3D
	TestAssertions.equal((first_metal.material_override as StandardMaterial3D).albedo_color, definition.item_colors[&"metal"], "item-owned material color wins", failures)
	TestAssertions.equal((first_accent.material_override as StandardMaterial3D).albedo_color, Color(0.9, 0.1, 0.1, 1.0), "first wearer accent applies", failures)
	TestAssertions.equal((second_accent.material_override as StandardMaterial3D).albedo_color, Color(0.1, 0.1, 0.9, 1.0), "second wearer accent applies", failures)
	TestAssertions.truthy(first_accent.material_override != second_accent.material_override, "wearer accent materials are instance-isolated", failures)
	_free_model(first)
	_free_model(second)

func _model_with_sockets(socket_ids: Array[StringName]) -> ForgeHumanoidModel:
	var model := ForgeHumanoidModel.new()
	for socket_id: StringName in socket_ids:
		var socket := Node3D.new()
		socket.name = socket_id
		model.add_child(socket)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	return model

func _free_model(model: Node3D) -> void:
	model.free()

func _visual(id: StringName, slot: StringName, socket: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var value := EquipmentVisualDefinition.new()
	value.id = id
	value.slot_id = slot
	value.supported_slot_ids = [slot]
	value.socket_id = socket
	value.presentation_scene = scene
	value.combat_visible = true
	value.body_preset_ids = [&"masculine", &"feminine"]
	return value

func _single_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"SingleAttachment"
	root.add_child(MeshInstance3D.new())
	root.get_child(0).owner = root
	return _pack_scene(root)

func _paired_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	for description: Dictionary in [
		{&"name": &"LeftAttachment", &"socket": &"LeftHandSocket"},
		{&"name": &"RightAttachment", &"socket": &"RightHandSocket"},
	]:
		var attachment := Node3D.new()
		attachment.name = description[&"name"]
		attachment.set_meta(&"equipment_socket_id", description[&"socket"])
		root.add_child(attachment)
		attachment.owner = root
	return _pack_scene(root)

func _colored_attachment_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"ColoredAttachment"
	for description: Dictionary in [
		{&"name": &"Metal", &"region": &"metal"},
		{&"name": &"Accent", &"region": &"accent"},
	]:
		var mesh := MeshInstance3D.new()
		mesh.name = description[&"name"]
		mesh.set_meta(&"palette_region", description[&"region"])
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		mesh.material_override = material
		root.add_child(mesh)
		mesh.owner = root
	return _pack_scene(root)

func _pack_scene(root: Node3D) -> PackedScene:
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
