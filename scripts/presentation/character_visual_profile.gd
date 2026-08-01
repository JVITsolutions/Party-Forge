class_name CharacterVisualProfile
extends Resource

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]

@export var id: StringName
@export var presentation_scene: PackedScene
@export var default_body_preset: StringName = &"masculine"
@export var default_palette_id: StringName = &"red"
@export var palette_colors: Dictionary = {}
@export var default_equipment_visuals: Array[EquipmentVisualDefinition] = []
@export var available_equipment_visuals: Array[EquipmentVisualDefinition] = []
@export var required_animation_names: Array[StringName] = [&"idle"]
@export var attack_animation_by_id: Dictionary = {}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("profile id is empty")
	if presentation_scene == null:
		errors.append("profile %s presentation scene is missing" % id)
	if default_body_preset not in BODY_PRESETS:
		errors.append("profile %s body preset %s is invalid" % [id, default_body_preset])
	if not palette_colors.has(default_palette_id):
		errors.append("profile %s default palette %s is missing" % [id, default_palette_id])
	for palette_id: Variant in palette_colors:
		if StringName(palette_id).is_empty() or typeof(palette_colors[palette_id]) != TYPE_COLOR:
			errors.append("profile %s palette %s is invalid" % [id, palette_id])
	_validate_equipment_visuals(default_equipment_visuals, &"default", errors)
	_validate_equipment_visuals(available_equipment_visuals, &"available", errors)
	var animation_names: Dictionary = {}
	for animation_id: StringName in required_animation_names:
		if animation_id.is_empty() or animation_names.has(animation_id):
			errors.append("profile %s has empty or duplicate animation" % id)
		animation_names[animation_id] = true
	if not animation_names.has(&"idle"):
		errors.append("profile %s idle animation is missing" % id)
	for attack_id: Variant in attack_animation_by_id:
		var animation_id := StringName(attack_animation_by_id[attack_id])
		if StringName(attack_id).is_empty() or not animation_names.has(animation_id):
			errors.append("profile %s attack mapping %s -> %s is invalid" % [id, attack_id, animation_id])
	return errors

func get_available_equipment_visual(slot_id: StringName) -> EquipmentVisualDefinition:
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.slot_id == slot_id:
			return definition
	return null

func _validate_equipment_visuals(definitions: Array[EquipmentVisualDefinition], collection_name: StringName, errors: PackedStringArray) -> void:
	var equipment_slots: Dictionary = {}
	for definition: EquipmentVisualDefinition in definitions:
		if definition == null:
			errors.append("profile %s has null %s equipment visual" % [id, collection_name])
			continue
		for reason: String in definition.validate():
			errors.append("profile %s %s" % [id, reason])
		if equipment_slots.has(definition.slot_id):
			errors.append("profile %s has duplicate %s equipment slot %s" % [id, collection_name, definition.slot_id])
		equipment_slots[definition.slot_id] = true
