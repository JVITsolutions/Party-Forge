class_name CharacterVisualProfile
extends Resource

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]

@export var id: StringName
@export var presentation_scene: PackedScene
@export var default_body_preset: StringName = &"masculine"
@export var default_palette_id: StringName = &"red"
@export var palette_colors: Dictionary = {}
@export var default_equipment: Array[EquipmentLoadoutEntry] = []
@export var available_equipment: Array[EquipmentBaseDefinition] = []
@export var idle_action_id: StringName = &"idle"
@export var walk_action_id: StringName = &"walk"
@export var default_equipment_visuals: Array[EquipmentVisualDefinition] = []
@export var available_equipment_visuals: Array[EquipmentVisualDefinition] = []
@export var required_animation_names: Array[StringName] = [&"idle"]
@export var attack_animation_by_id: Dictionary = {}
@export var attack_presentations: Array[AttackPresentationDefinition] = []
@export var class_heads: Array[CharacterHeadVisualDefinition] = []

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
	_validate_default_equipment(default_equipment, errors)
	_validate_available_equipment(available_equipment, errors)
	_validate_equipment_visuals(default_equipment_visuals, &"default", errors)
	_validate_equipment_visuals(available_equipment_visuals, &"available", errors)
	var animation_names: Dictionary = {}
	for animation_id: StringName in required_animation_names:
		if animation_id.is_empty() or animation_names.has(animation_id):
			errors.append("profile %s has empty or duplicate animation" % id)
		animation_names[animation_id] = true
	if idle_action_id.is_empty() or not animation_names.has(idle_action_id):
		errors.append("profile %s idle animation %s is missing" % [id, idle_action_id])
	if walk_action_id.is_empty() or not animation_names.has(walk_action_id):
		errors.append("profile %s walk animation %s is missing" % [id, walk_action_id])
	for attack_id: Variant in attack_animation_by_id:
		var animation_id := StringName(attack_animation_by_id[attack_id])
		if StringName(attack_id).is_empty() or not animation_names.has(animation_id):
			errors.append("profile %s attack mapping %s -> %s is invalid" % [id, attack_id, animation_id])
	var attack_presentation_ids: Dictionary = {}
	for definition: AttackPresentationDefinition in attack_presentations:
		if definition == null:
			errors.append("profile %s has null attack presentation" % id)
			continue
		if definition.id.is_empty() or definition.attack_id.is_empty() or definition.action_id.is_empty() or definition.required_event_name not in [&"release", &"impact"]:
			errors.append("profile %s attack presentation identity is invalid" % id)
		if attack_presentation_ids.has(definition.id):
			errors.append("profile %s has duplicate attack presentation %s" % [id, definition.id])
		attack_presentation_ids[definition.id] = true
		if not animation_names.has(definition.action_id):
			errors.append("profile %s attack presentation %s action %s is missing" % [id, definition.id, definition.action_id])
	_validate_class_heads(errors)
	return errors


func head_for_body(body_preset_id: StringName) -> CharacterHeadVisualDefinition:
	for head: CharacterHeadVisualDefinition in class_heads:
		if head != null and head.body_preset_id == body_preset_id:
			return head
	return null

func resolve_attack_presentation(attack_id: StringName, weapon_family_id: StringName) -> AttackPresentationDefinition:
	for value: AttackPresentationDefinition in attack_presentations:
		if value != null and value.attack_id == attack_id and value.weapon_animation_family_id == weapon_family_id:
			return value
	for value: AttackPresentationDefinition in attack_presentations:
		if value != null and value.attack_id == attack_id and value.weapon_animation_family_id.is_empty():
			return value
	return null

func get_available_equipment_visual(slot_id: StringName) -> EquipmentVisualDefinition:
	for item: EquipmentBaseDefinition in available_equipment:
		if item != null and slot_id in item.compatible_slot_ids and item.presentation != null:
			return item.presentation
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.slot_id == slot_id:
			return definition
	return null

func get_available_equipment_visual_by_id(equipment_id: StringName) -> EquipmentVisualDefinition:
	for item: EquipmentBaseDefinition in available_equipment:
		if item != null and item.id == equipment_id:
			return item.presentation
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.id == equipment_id:
			return definition
	return null

func get_available_equipment_visuals_for_slot(slot_id: StringName) -> Array[EquipmentVisualDefinition]:
	var matches: Array[EquipmentVisualDefinition] = []
	for item: EquipmentBaseDefinition in available_equipment:
		if item != null and slot_id in item.compatible_slot_ids and item.presentation != null:
			matches.append(item.presentation)
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.slot_id == slot_id:
			matches.append(definition)
	return matches

func _validate_equipment_visuals(definitions: Array[EquipmentVisualDefinition], collection_name: StringName, errors: PackedStringArray) -> void:
	var equipment_slots: Dictionary = {}
	var equipment_ids: Dictionary = {}
	var geometry_keys: Dictionary = {}
	for definition: EquipmentVisualDefinition in definitions:
		if definition == null:
			errors.append("profile %s has null %s equipment visual" % [id, collection_name])
			continue
		for reason: String in definition.validate():
			errors.append("profile %s %s" % [id, reason])
		if equipment_ids.has(definition.id):
			errors.append("profile %s has duplicate %s equipment id %s" % [id, collection_name, definition.id])
		equipment_ids[definition.id] = true
		if not definition.geometry_key.is_empty() and geometry_keys.has(definition.geometry_key):
			errors.append("profile %s has duplicate %s geometry key %s" % [id, collection_name, definition.geometry_key])
		geometry_keys[definition.geometry_key] = true
		if collection_name == &"default" and equipment_slots.has(definition.slot_id):
			errors.append("profile %s has duplicate default equipment slot %s" % [id, definition.slot_id])
		equipment_slots[definition.slot_id] = true

func _validate_default_equipment(definitions: Array[EquipmentLoadoutEntry], errors: PackedStringArray) -> void:
	var item_ids: Dictionary = {}
	var slots: Dictionary = {}
	for entry: EquipmentLoadoutEntry in definitions:
		if entry == null:
			errors.append("profile %s has null default equipment entry" % id)
			continue
		for reason: String in entry.validate():
			errors.append("profile %s %s" % [id, reason])
		if entry.item != null:
			for reason: String in entry.item.validate():
				errors.append("profile %s %s" % [id, reason])
			_validate_item_presentation(entry.item, errors)
			if item_ids.has(entry.item.id):
				errors.append("profile %s has duplicate default equipment id %s" % [id, entry.item.id])
			item_ids[entry.item.id] = true
		if slots.has(entry.slot_id):
			errors.append("profile %s has duplicate default equipment slot %s" % [id, entry.slot_id])
		slots[entry.slot_id] = true

func _validate_available_equipment(definitions: Array[EquipmentBaseDefinition], errors: PackedStringArray) -> void:
	var item_ids: Dictionary = {}
	for item: EquipmentBaseDefinition in definitions:
		if item == null:
			errors.append("profile %s has null available equipment item" % id)
			continue
		for reason: String in item.validate():
			errors.append("profile %s %s" % [id, reason])
		_validate_item_presentation(item, errors)
		if item_ids.has(item.id):
			errors.append("profile %s has duplicate available equipment id %s" % [id, item.id])
		item_ids[item.id] = true

func _validate_item_presentation(item: EquipmentBaseDefinition, errors: PackedStringArray) -> void:
	if item.presentation == null:
		return
	for reason: String in item.presentation.validate():
		errors.append("profile %s %s" % [id, reason])


func _validate_class_heads(errors: PackedStringArray) -> void:
	if class_heads.is_empty():
		return
	var counts := {&"masculine": 0, &"feminine": 0}
	for head: CharacterHeadVisualDefinition in class_heads:
		if head == null:
			errors.append("profile %s has null class head" % id)
			continue
		for reason: String in head.validate():
			errors.append("profile %s %s" % [id, reason])
		if counts.has(head.body_preset_id):
			counts[head.body_preset_id] = int(counts[head.body_preset_id]) + 1
	if int(counts[&"masculine"]) != 1 or int(counts[&"feminine"]) != 1:
		errors.append("profile %s requires exactly one masculine and one feminine head" % id)
