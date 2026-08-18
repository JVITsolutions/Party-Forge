extends RefCounted

const CHEST_SCENE_PATH := "res://scenes/world/ground_item_chest.tscn"
const RARITY_PALETTE_PATH := "res://scripts/ui/storage/item_rarity_palette.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(CHEST_SCENE_PATH), "ground-item chest scene exists", failures)
	if not ResourceLoader.exists(CHEST_SCENE_PATH):
		return failures
	var packed := load(CHEST_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "ground-item chest scene loads", failures)
	if packed == null:
		return failures
	var chest := packed.instantiate() as Node3D
	_test_bounded_primitive_presentation(chest, failures)
	_test_owner_rarity_selection_and_fallback(chest, failures)
	_test_owner_only_pickup(chest, failures)
	for label_path: NodePath in [^"OwnerMarker/Pennant", ^"OwnerMarker/OwnerLabel"]:
		var label := chest.get_node(label_path) as Label3D
		label.text = ""
		label.font = null
		label.free()
	chest.free()
	RenderingServer.force_sync()
	return failures


func _test_bounded_primitive_presentation(chest: Node3D, failures: Array[String]) -> void:
	var meshes := _descendants_of_type(chest, "MeshInstance3D")
	var collisions := _descendants_of_type(chest, "CollisionShape3D")
	TestAssertions.equal(meshes.size(), 2, "chest uses one primitive target plus one selection-outline primitive", failures)
	TestAssertions.truthy(chest.get_node_or_null("MeshTarget") is MeshInstance3D, "chest keeps one lightweight primitive body target", failures)
	TestAssertions.truthy(chest.get_node_or_null("SelectionRing") is MeshInstance3D, "chest provides a non-color-only selection outline shape", failures)
	TestAssertions.equal(collisions.size(), 1, "chest uses exactly one collision target", failures)
	TestAssertions.truthy(chest.get_node_or_null("RarityLight") is OmniLight3D, "chest exposes a dedicated rarity light", failures)
	TestAssertions.truthy(chest.get_node_or_null("OwnerMarker/Pennant") is Label3D, "owner marker has a billboard pennant silhouette", failures)
	TestAssertions.truthy(chest.get_node_or_null("OwnerMarker/OwnerLabel") is Label3D, "owner marker has an independent billboard P-number label", failures)
	var pennant := chest.get_node_or_null("OwnerMarker/Pennant") as Label3D
	var owner_label := chest.get_node_or_null("OwnerMarker/OwnerLabel") as Label3D
	if pennant != null:
		TestAssertions.equal(pennant.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "pennant always faces the arena camera", failures)
		TestAssertions.truthy(pennant.text in ["▼", "▾", "◆"], "pennant uses a grayscale-readable silhouette rather than color alone", failures)
		TestAssertions.truthy(pennant.font_size <= 28, "owner pennant stays within compact font budget", failures)
		TestAssertions.truthy(pennant.outline_size <= 6, "owner pennant outline stays compact", failures)
	if owner_label != null:
		TestAssertions.equal(owner_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "P-number always faces the arena camera", failures)
		TestAssertions.truthy(owner_label.font_size <= 18, "owner label stays within compact font budget", failures)
		TestAssertions.truthy(owner_label.outline_size <= 4, "owner label outline stays compact", failures)
	var owner_marker := chest.get_node("OwnerMarker") as PlayerOwnerMarker3D
	for player_number: int in [1, 2]:
		var owner_color := PlayerColorPalette.color(&"red" if player_number == 1 else &"blue")
		owner_marker.bind(player_number, owner_color)
		TestAssertions.equal(pennant.text, "▼", "P%d pennant retains downward ownership language" % player_number, failures)
		TestAssertions.equal(pennant.modulate, owner_color, "P%d pennant retains the exact owner color" % player_number, failures)
		TestAssertions.equal(owner_label.text, "P%d" % player_number, "P%d label retains explicit ownership language" % player_number, failures)


func _test_owner_rarity_selection_and_fallback(chest: Node3D, failures: Array[String]) -> void:
	var record := _record(&"drop-p2", &"player_2", 2, Vector3(3.0, 0.0, 4.0), &"rare")
	var detail := _detail("Windrunner Band", "Rare")
	detail["icon_path"] = "res://missing/world-loot-icon.png"
	detail["model_path"] = "res://missing/world-loot-model.tscn"
	var owner_color := PlayerColorPalette.color(&"blue")
	chest.call(&"bind", record, detail, owner_color)
	TestAssertions.truthy(chest.visible, "bound chest remains visible even when optional icon/model assets are missing", failures)
	TestAssertions.equal(chest.position, record.world_position, "record world position binds without moving authoritative state", failures)
	var owner_label := chest.get_node("OwnerMarker/OwnerLabel") as Label3D
	var pennant := chest.get_node("OwnerMarker/Pennant") as Label3D
	TestAssertions.equal(owner_label.text, "P2", "owner number binds explicitly", failures)
	TestAssertions.equal(pennant.modulate, owner_color, "owner pennant uses the exact active profile color", failures)
	TestAssertions.truthy(owner_label.visible, "P-number remains visible independently of rarity glow", failures)
	var light := chest.get_node("RarityLight") as OmniLight3D
	var rarity_palette := load(RARITY_PALETTE_PATH) as Script
	TestAssertions.equal(light.light_color, rarity_palette.call("color_for", &"rare"), "rarity light uses the shared exact palette", failures)
	var energy_before := light.light_energy
	chest.call(&"set_selected", true)
	TestAssertions.truthy(light.light_energy > energy_before, "selection is visually distinct from ordinary rarity glow", failures)
	TestAssertions.truthy((chest.get_node("SelectionRing") as MeshInstance3D).visible, "selection exposes the outline independently of color", failures)
	TestAssertions.truthy(owner_label.visible, "selection does not gate the always-readable P-number", failures)
	chest.call(&"set_selected", false)
	TestAssertions.truthy(not (chest.get_node("SelectionRing") as MeshInstance3D).visible, "clearing selection hides the outline", failures)
	TestAssertions.near(light.light_energy, energy_before, 0.001, "selection clears back to the bound rarity presentation", failures)
	var anchor := chest.call(&"tooltip_anchor") as Control
	TestAssertions.truthy(anchor is Button, "chest exposes one lightweight focusable screen anchor", failures)
	if anchor != null:
		for token: String in ["Windrunner Band", "Rare", "P2", "5.0 m"]:
			TestAssertions.truthy(anchor.accessibility_name.contains(token), "accessibility text includes %s" % token, failures)
	TestAssertions.equal(_descendants_of_type(chest, "ItemTooltipPanel").size(), 0, "chest never creates a private tooltip", failures)


func _test_owner_only_pickup(chest: Node3D, failures: Array[String]) -> void:
	var requests: Array[Array] = []
	chest.connect(&"pickup_requested", func(drop_id: StringName, input_owner: StringName) -> void:
		requests.append([drop_id, input_owner])
	)
	chest.call(&"request_pickup", &"player_1")
	TestAssertions.equal(requests.size(), 0, "non-owner input cannot emit pickup", failures)
	chest.call(&"request_pickup", &"player_2")
	TestAssertions.equal(requests, [[&"drop-p2", &"player_2"]], "owner input emits the exact drop and owner identity once", failures)


func _record(drop_id: StringName, owner_id: StringName, player_number: int, position: Vector3, rarity_id: StringName) -> GroundItemRecord:
	var record := GroundItemRecord.new()
	record.drop_id = drop_id
	record.item_id = "item-%s" % drop_id
	record.run_player_id = owner_id
	record.profile_id = "profile-%s" % owner_id
	record.player_number = player_number
	record.color_id = &"blue" if player_number == 2 else &"red"
	record.world_position = position
	record.rarity_id = rarity_id
	record.source_id = &"test-source"
	record.ground_slot = player_number - 1
	return record


func _detail(item_name: String, rarity_name: String) -> Dictionary:
	return {
		"instance_id": "world-item",
		"name": item_name,
		"rarity_id": rarity_name.to_lower(),
		"rarity_name": rarity_name,
		"item_level": 10,
		"compatible_slot_ids": ["ring_left"],
		"affixes": [],
		"modifier_totals": {},
	}


func _descendants_of_type(root: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		if child.is_class(type_name):
			result.append(child)
		result.append_array(_descendants_of_type(child, type_name))
	return result
