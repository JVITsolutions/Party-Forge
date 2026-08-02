extends RefCounted

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const HAND_SLOTS: Array[StringName] = [&"main_hand", &"off_hand"]
const MIN_CLEARANCE := 0.06
const MIN_EXTENT := 0.18
const QUIVER_IDS: Array[StringName] = [&"greenwood_light_quiver", &"siege_heavy_quiver"]
const BOW_IDS: Array[StringName] = [&"greenwood_recurve_bow", &"siege_greatbow"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var catalog := GameCatalog.load_defaults()
	for definition: ClassDefinition in catalog.classes:
		for body_id: StringName in BODY_IDS:
			var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
			root.add_child(actor)
			actor.configure(PartyMemberState.new(1, definition, true))
			var presentation := actor.get_node("Presentation") as CharacterPresentation
			TestAssertions.truthy(presentation.set_body_preset(body_id), "%s %s body activates" % [definition.id, body_id], failures)
			var model := presentation.active_model as ForgeHumanoidModel
			var has_anchor_names := model.has_method(&"equipped_anchor_names")
			var has_anchor_clearance := model.has_method(&"equipment_anchor_clearance")
			var has_visible_extent := model.has_method(&"equipment_visible_extent")
			TestAssertions.truthy(has_anchor_names, "%s exposes equipped anchor names" % definition.id, failures)
			TestAssertions.truthy(has_anchor_clearance, "%s exposes equipment anchor clearance" % definition.id, failures)
			TestAssertions.truthy(has_visible_extent, "%s exposes equipment visible extent" % definition.id, failures)
			if not has_anchor_names or not has_anchor_clearance or not has_visible_extent:
				actor.free()
				continue
			for slot_id: StringName in HAND_SLOTS:
				var item_id := model.equipped_item_id(slot_id)
				if item_id.is_empty():
					continue
				var anchors: Array[StringName] = []
				anchors.assign(model.call(&"equipped_anchor_names", slot_id))
				TestAssertions.truthy(&"ReadabilityAnchor" in anchors, "%s %s %s readability anchor" % [definition.id, body_id, item_id], failures)
				if item_id not in QUIVER_IDS:
					TestAssertions.truthy(&"ActionOriginSocket" in anchors, "%s %s %s action origin" % [definition.id, body_id, item_id], failures)
				var clearance := float(model.call(&"equipment_anchor_clearance", slot_id, &"ReadabilityAnchor"))
				TestAssertions.truthy(clearance >= MIN_CLEARANCE, "%s %s %s clears arm silhouette (clearance=%.3f)" % [definition.id, body_id, item_id, clearance], failures)
				TestAssertions.truthy(float(model.call(&"equipment_visible_extent", slot_id)) >= MIN_EXTENT, "%s %s %s remains visually readable" % [definition.id, body_id, item_id], failures)
				if item_id in BOW_IDS:
					TestAssertions.truthy(&"ProjectileLaunchSocket" in anchors, "%s launch socket" % item_id, failures)
				if item_id in QUIVER_IDS:
					TestAssertions.truthy(_attachment_parent_contains(model, slot_id, "BackSocket"), "%s is worn on back" % item_id, failures)
			actor.free()
	root.free()
	return failures

func _attachment_parent_contains(model: ForgeHumanoidModel, slot_id: StringName, expected_name: String) -> bool:
	for attachment: Node3D in model.equipped_nodes.get(slot_id, []):
		var cursor: Node = attachment.get_parent()
		while cursor != null and cursor != model:
			if expected_name in String(cursor.name):
				return true
			cursor = cursor.get_parent()
	return false
