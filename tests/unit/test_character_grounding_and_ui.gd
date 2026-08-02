extends RefCounted

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const MAX_GROUND_GAP := 0.01
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")

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
	_test_health_bar_clearance(actor, presentation, definition.visual_profile, label, failures)
	_test_palette_preserving_hit(model, label, failures)
	actor.free()

func _assert_grounded(presentation: CharacterPresentation, model: ForgeHumanoidModel, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(bool(presentation.call(&"refresh_grounding")), "%s grounding refresh succeeds" % label, failures)
	TestAssertions.truthy(absf(float(model.call(&"ground_gap"))) <= MAX_GROUND_GAP, "%s visible lower bound meets ground plane" % label, failures)

func _boots_definition(profile: CharacterVisualProfile) -> EquipmentVisualDefinition:
	for entry: EquipmentLoadoutEntry in profile.default_equipment:
		if entry != null and entry.slot_id == &"boots" and entry.item != null:
			return entry.item.presentation
	return null

func _test_health_bar_clearance(actor: PartyActor, presentation: CharacterPresentation, profile: CharacterVisualProfile, label: String, failures: Array[String]) -> void:
	var bar := HEALTH_BAR_SCENE.instantiate() as HealthBar3D
	actor.add_child(bar)
	bar.configure(actor.get_node("HealthComponent") as HealthComponent)
	TestAssertions.truthy(bar.has_method(&"refresh_presentation_anchor"), "%s health bar exposes adaptive anchor refresh" % label, failures)
	if not bar.has_method(&"refresh_presentation_anchor"):
		return
	bar.call(&"refresh_presentation_anchor")
	_assert_bar_above_bounds(bar, presentation, "%s default helmet" % label, failures)
	var helmet := _slot_definition(profile, &"helmet")
	if helmet != null:
		TestAssertions.truthy(presentation.clear_equipment_visual(&"helmet"), "%s helmet clears independently" % label, failures)
		_assert_bar_above_bounds(bar, presentation, "%s without helmet" % label, failures)
		TestAssertions.truthy(presentation.apply_equipment_visual(&"helmet", helmet), "%s helmet re-equips independently" % label, failures)
		_assert_bar_above_bounds(bar, presentation, "%s helmet restored" % label, failures)

func _assert_bar_above_bounds(bar: HealthBar3D, presentation: CharacterPresentation, label: String, failures: Array[String]) -> void:
	var bounds := presentation.visual_bounds()
	var required_y := bounds.position.y + bounds.size.y + 0.12
	TestAssertions.truthy(bar.position.y >= required_y, "%s health bar clears visible bounds (bar=%.3f required=%.3f)" % [label, bar.position.y, required_y], failures)

func _test_palette_preserving_hit(model: ForgeHumanoidModel, label: String, failures: Array[String]) -> void:
	var bases: Dictionary = {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var base := model.base_materials.get(mesh) as StandardMaterial3D
		if base != null and mesh.visible:
			bases[mesh] = base.albedo_color
	model.set_hit_weight(1.0)
	for mesh: MeshInstance3D in bases:
		var base_color := bases[mesh] as Color
		var hit_material := mesh.material_override as StandardMaterial3D
		TestAssertions.truthy(hit_material != null, "%s %s retains a hit material" % [label, mesh.name], failures)
		if hit_material == null:
			continue
		var hit_color := hit_material.albedo_color
		TestAssertions.truthy(absf(hit_color.get_luminance() - base_color.get_luminance()) < 0.55, "%s %s hit flash keeps bounded luminance" % [label, mesh.name], failures)
		if base_color.s > 0.10:
			TestAssertions.truthy(hit_color.s > 0.10, "%s %s hit flash preserves readable color" % [label, mesh.name], failures)
		if hit_material.emission_enabled:
			TestAssertions.truthy(hit_material.emission_energy_multiplier <= 0.45, "%s %s hit emission is capped" % [label, mesh.name], failures)
	model.set_hit_weight(0.0)
	for mesh: MeshInstance3D in bases:
		var restored := mesh.material_override as StandardMaterial3D
		TestAssertions.equal(restored.albedo_color if restored != null else Color.TRANSPARENT, bases[mesh], "%s %s hit clear restores base color" % [label, mesh.name], failures)

func _slot_definition(profile: CharacterVisualProfile, slot_id: StringName) -> EquipmentVisualDefinition:
	for entry: EquipmentLoadoutEntry in profile.default_equipment:
		if entry != null and entry.slot_id == slot_id and entry.item != null:
			return entry.item.presentation
	return null
