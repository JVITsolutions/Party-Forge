class_name CharacterPresentationSandbox
extends Node3D

const BASE_PROFILE_PATHS := {
	&"Masculine": "res://data/presentation/profiles/forge_base_masculine.tres",
	&"Feminine": "res://data/presentation/profiles/forge_base_feminine.tres",
}
const SIDE_IDS: Array[StringName] = [&"Masculine", &"Feminine"]
const REVIEW_PALETTE_BY_SIDE := {&"Masculine": &"red", &"Feminine": &"blue"}

var selected_side_id: StringName = &"Masculine"
var selected_slot_index := 0
var _catalog: GameCatalog
var _base_profile_by_side: Dictionary = {}
var _class_by_side: Dictionary = {&"Masculine": &"fighter", &"Feminine": &"fighter"}
var _is_base_profile_by_side: Dictionary = {&"Masculine": false, &"Feminine": false}
var _slot_enabled: Dictionary = {}
var _equipped_visual_id: Dictionary = {}
var _initialized := false

func _ready() -> void:
	_initialize_profiles()

func _process(delta: float) -> void:
	_initialize_profiles()
	for side_id: StringName in SIDE_IDS:
		var presentation := _presentation(side_id)
		if presentation != null:
			presentation.advance_feedback(delta)

func _initialize_profiles() -> void:
	if _initialized:
		return
	_initialized = true
	_catalog = GameCatalog.load_defaults()
	for side_id: StringName in SIDE_IDS:
		_base_profile_by_side[side_id] = load(String(BASE_PROFILE_PATHS[side_id])) as CharacterVisualProfile
		_apply_profile_mode(side_id, false)
	_populate_selectors()
	_update_diagnostics()

func set_class(class_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	if _catalog == null or _catalog.class_by_id(class_id) == null:
		return false
	_class_by_side[side_id] = class_id
	_is_base_profile_by_side[side_id] = false
	var success := _apply_profile_mode(side_id, false)
	_update_diagnostics()
	return success

func get_class_id(side_id: StringName = selected_side_id) -> StringName:
	_initialize_profiles()
	return StringName(_class_by_side.get(side_id, &""))

func set_body(preset_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	return presentation != null and presentation.set_body_preset(preset_id)

func set_palette(palette_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var palette_color: Variant = presentation.active_profile.palette_colors.get(palette_id)
	if typeof(palette_color) != TYPE_COLOR:
		return false
	return presentation.set_palette(palette_id, palette_color as Color)

func toggle_slot(slot_id: StringName, enabled: bool, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var success := false
	if enabled:
		var stored_id := get_equipped_visual_id(slot_id, side_id)
		var definition := presentation.active_profile.get_available_equipment_visual_by_id(stored_id) if not stored_id.is_empty() else presentation.active_profile.get_available_equipment_visual(slot_id)
		success = definition != null and presentation.apply_equipment_visual(slot_id, definition)
		if success:
			_equipped_visual_id[_slot_key(side_id, slot_id)] = definition.id
	else:
		success = presentation.clear_equipment_visual(slot_id)
	if success:
		_slot_enabled[_slot_key(side_id, slot_id)] = enabled
	return success

func equip_variant(equipment_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var definition := presentation.active_profile.get_available_equipment_visual_by_id(equipment_id)
	if definition == null or not presentation.apply_equipment_visual(definition.slot_id, definition):
		return false
	_equipped_visual_id[_slot_key(side_id, definition.slot_id)] = definition.id
	_slot_enabled[_slot_key(side_id, definition.slot_id)] = true
	return true

func cycle_slot_variant(slot_id: StringName, direction: int = 1, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var variants := presentation.active_profile.get_available_equipment_visuals_for_slot(slot_id)
	if variants.is_empty():
		return false
	var current_id := get_equipped_visual_id(slot_id, side_id)
	var current_index := -1
	for index: int in variants.size():
		if variants[index].id == current_id:
			current_index = index
			break
	var next_index := posmod(current_index + direction, variants.size())
	return equip_variant(variants[next_index].id, side_id)

func get_equipped_visual_id(slot_id: StringName, side_id: StringName = selected_side_id) -> StringName:
	_initialize_profiles()
	return StringName(_equipped_visual_id.get(_slot_key(side_id, slot_id), &""))

func play_clip(animation_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	return presentation != null and presentation.play_action(animation_id)

func play_primary(side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var definition := _class_definition(side_id)
	var presentation := _presentation(side_id)
	if definition == null or definition.primary_attack == null or presentation == null:
		return false
	var attack_visual := presentation.resolve_attack_presentation(definition.primary_attack)
	return attack_visual != null and presentation.play_action(attack_visual.action_id)

func preview_specialized_effect(side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var definition := _class_definition(side_id)
	var presentation := _presentation(side_id)
	if definition == null or definition.primary_attack == null or presentation == null:
		return false
	var attack_visual := presentation.resolve_attack_presentation(definition.primary_attack)
	if attack_visual == null:
		return false
	var scene := attack_visual.projectile_scene if attack_visual.projectile_scene != null else attack_visual.impact_scene
	if scene == null:
		return definition.primary_attack.id in [&"fighter_cleave", &"paladin_smite", &"rogue_flurry"]
	var preview := scene.instantiate() as Node3D
	if preview == null:
		return false
	preview.name = "EffectPreview"
	add_child(preview)
	preview.position = Vector3(0, 1.0, -1.2)
	preview.queue_free()
	return true

func trigger_hit(side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_model == null:
		return false
	presentation.flash_hit()
	return true

func set_downed(is_downed: bool, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_model == null:
		return false
	presentation.set_downed(is_downed)
	return true

func set_base_profile(enabled: bool, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	if side_id not in SIDE_IDS:
		return false
	return _apply_profile_mode(side_id, enabled)

func get_palette_id(side_id: StringName = selected_side_id) -> StringName:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	return presentation.active_palette_id if presentation != null else &""

func is_base_profile(side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	return bool(_is_base_profile_by_side.get(side_id, false))

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: set_body(&"masculine")
		KEY_2: set_body(&"feminine")
		KEY_TAB: _cycle_class(1)
		KEY_R: set_palette(&"red")
		KEY_B: set_palette(&"blue")
		KEY_G: set_palette(&"green")
		KEY_I: play_clip(&"idle")
		KEY_A: play_clip(&"attack_slash")
		KEY_C: play_clip(&"attack_combo")
		KEY_P: play_primary()
		KEY_F: preview_specialized_effect()
		KEY_H: trigger_hit()
		KEY_Q: _cycle_slot(-1)
		KEY_E: _cycle_slot(1)
		KEY_SPACE:
			var slot_id: StringName = EquipmentSlotCatalog.SLOT_IDS[selected_slot_index]
			toggle_slot(slot_id, not bool(_slot_enabled.get(_slot_key(selected_side_id, slot_id), false)))
		KEY_V:
			var slot_id: StringName = EquipmentSlotCatalog.SLOT_IDS[selected_slot_index]
			cycle_slot_variant(slot_id, 1)
		KEY_M: set_base_profile(not is_base_profile())

func _apply_profile_mode(side_id: StringName, use_base_profile: bool) -> bool:
	var presentation := _presentation(side_id)
	var class_definition := _class_definition(side_id)
	var profile := _base_profile_by_side.get(side_id) as CharacterVisualProfile if use_base_profile else (class_definition.visual_profile if class_definition != null else null)
	if presentation == null or profile == null:
		return false
	var palette_id := profile.default_palette_id
	var review_palette_id := StringName(REVIEW_PALETTE_BY_SIDE.get(side_id, profile.default_palette_id))
	if profile.palette_colors.has(review_palette_id):
		palette_id = review_palette_id
	var color: Variant = profile.palette_colors.get(palette_id)
	if typeof(color) != TYPE_COLOR or not presentation.apply_profile(profile, color as Color):
		return false
	var body_id := &"masculine" if side_id == &"Masculine" else &"feminine"
	if not presentation.set_body_preset(body_id):
		return false
	if not presentation.set_palette(palette_id, color as Color):
		return false
	_is_base_profile_by_side[side_id] = use_base_profile
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		_slot_enabled[_slot_key(side_id, slot_id)] = false
		_equipped_visual_id.erase(_slot_key(side_id, slot_id))
	if profile.default_equipment.is_empty():
		for definition: EquipmentVisualDefinition in profile.default_equipment_visuals:
			if definition != null:
				_slot_enabled[_slot_key(side_id, definition.slot_id)] = true
				_equipped_visual_id[_slot_key(side_id, definition.slot_id)] = definition.id
	else:
		for entry: EquipmentLoadoutEntry in profile.default_equipment:
			if entry != null and entry.item != null:
				_slot_enabled[_slot_key(side_id, entry.slot_id)] = true
				_equipped_visual_id[_slot_key(side_id, entry.slot_id)] = entry.item.id
	_update_diagnostics()
	return true

func _class_definition(side_id: StringName) -> ClassDefinition:
	if _catalog == null:
		return null
	return _catalog.class_by_id(StringName(_class_by_side.get(side_id, &"")))

func _populate_selectors() -> void:
	var class_selector := get_node_or_null("UI/ClassSelector") as OptionButton
	if class_selector != null and class_selector.item_count == 0:
		for definition: ClassDefinition in _catalog.classes:
			class_selector.add_item(definition.display_name)
			class_selector.set_item_metadata(class_selector.item_count - 1, definition.id)
	var body_selector := get_node_or_null("UI/BodySelector") as OptionButton
	if body_selector != null and body_selector.item_count == 0:
		for body_id: StringName in [&"masculine", &"feminine"]:
			body_selector.add_item(String(body_id).capitalize())
			body_selector.set_item_metadata(body_selector.item_count - 1, body_id)
	var slot_selector := get_node_or_null("UI/SlotSelector") as OptionButton
	if slot_selector != null and slot_selector.item_count == 0:
		for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
			slot_selector.add_item(String(slot_id).replace("_", " ").capitalize())
			slot_selector.set_item_metadata(slot_selector.item_count - 1, slot_id)

func _update_diagnostics() -> void:
	var label := get_node_or_null("UI/Diagnostics") as Label
	if label == null:
		return
	var slot_id: StringName = EquipmentSlotCatalog.SLOT_IDS[selected_slot_index]
	var presentation := _presentation(selected_side_id)
	var action_id := StringName(presentation.active_model.get("active_action_id")) if presentation != null and presentation.active_model != null else &""
	label.text = "class=%s body=%s slot=%s item=%s action=%s" % [get_class_id(selected_side_id), selected_side_id.to_lower(), slot_id, get_equipped_visual_id(slot_id, selected_side_id), action_id]

func _presentation(side_id: StringName) -> CharacterPresentation:
	if side_id not in SIDE_IDS:
		return null
	return get_node_or_null(NodePath("Models/%s" % side_id)) as CharacterPresentation

func _slot_key(side_id: StringName, slot_id: StringName) -> StringName:
	return StringName("%s:%s" % [side_id, slot_id])

func _cycle_slot(direction: int) -> void:
	selected_slot_index = posmod(selected_slot_index + direction, EquipmentSlotCatalog.SLOT_IDS.size())
	_update_diagnostics()

func _cycle_class(direction: int) -> void:
	var ids: Array[StringName] = []
	for definition: ClassDefinition in _catalog.classes:
		ids.append(definition.id)
	var current := ids.find(get_class_id())
	set_class(ids[posmod(current + direction, ids.size())])
