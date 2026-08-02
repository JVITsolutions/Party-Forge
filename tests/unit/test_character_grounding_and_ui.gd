extends RefCounted

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const MAX_GROUND_GAP := 0.01

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	for definition: ClassDefinition in GameCatalog.load_defaults().classes:
		for body_id: StringName in BODY_IDS:
			_test_class_body(root, definition, body_id, failures)
	root.free()
	return failures

func _test_class_body(root: Node3D, definition: ClassDefinition, body_id: StringName, failures: Array[String]) -> void:
	var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(actor)
	actor.configure(PartyMemberState.new(1, definition, true))
	var presentation := actor.get_node("Presentation") as CharacterPresentation
	var model := presentation.active_model as ForgeHumanoidModel
	var label := "%s %s" % [definition.id, body_id]
	TestAssertions.truthy(presentation.has_method(&"refresh_grounding") and presentation.has_method(&"visual_bounds"), "%s exposes presentation grounding API" % label, failures)
	TestAssertions.truthy(model != null and model.has_method(&"refresh_grounding") and model.has_method(&"ground_gap"), "%s exposes model grounding API" % label, failures)
	var shadow := presentation.get_node_or_null("ContactShadow") as MeshInstance3D
	TestAssertions.truthy(shadow != null, "%s has a model contact shadow" % label, failures)
	TestAssertions.truthy(presentation.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s shadow and presentation add no collision geometry" % label, failures)
	if model == null or not model.has_method(&"ground_gap") or not presentation.has_method(&"refresh_grounding"):
		actor.free()
		return
	TestAssertions.truthy(presentation.set_body_preset(body_id), "%s body activates" % label, failures)
	_assert_grounded(presentation, model, "%s initial" % label, failures)
	var boots := _boots_definition(definition.visual_profile)
	if boots != null:
		TestAssertions.truthy(presentation.clear_equipment_visual(&"boots"), "%s boots clear independently" % label, failures)
		_assert_grounded(presentation, model, "%s without boots" % label, failures)
		TestAssertions.truthy(presentation.apply_equipment_visual(&"boots", boots), "%s boots re-equip independently" % label, failures)
		_assert_grounded(presentation, model, "%s with boots restored" % label, failures)
	if shadow != null:
		TestAssertions.truthy(shadow.position.y >= 0.002 and shadow.position.y <= 0.01, "%s contact shadow remains just above ground" % label, failures)
	actor.free()

func _assert_grounded(presentation: CharacterPresentation, model: ForgeHumanoidModel, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(bool(presentation.call(&"refresh_grounding")), "%s grounding refresh succeeds" % label, failures)
	TestAssertions.truthy(absf(float(model.call(&"ground_gap"))) <= MAX_GROUND_GAP, "%s visible lower bound meets ground plane" % label, failures)

func _boots_definition(profile: CharacterVisualProfile) -> EquipmentVisualDefinition:
	for entry: EquipmentLoadoutEntry in profile.default_equipment:
		if entry != null and entry.slot_id == &"boots" and entry.item != null:
			return entry.item.presentation
	return null
