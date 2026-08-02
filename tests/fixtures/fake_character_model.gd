class_name FakeCharacterModel
extends Node3D

signal action_finished(action_id: StringName)
signal action_event(action_id: StringName, event_name: StringName)

var body_preset := &""
var palette_id := &""
var primary_color := Color.WHITE
var equipped: Dictionary = {}
var played: Array[StringName] = []
var rejected_actions: Array[StringName] = []
var current_action_id: StringName
var downed := false
var hit_weight := 0.0
var feedback_played: Array[StringName] = []

func set_body_preset(value: StringName) -> bool: body_preset = value; return value in [&"masculine", &"feminine"]
func set_palette(value: StringName, color: Color) -> bool: palette_id = value; primary_color = color; return true
func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool: equipped[slot_id] = definition.id; return true
func clear_equipment_visual(slot_id: StringName) -> bool: equipped.erase(slot_id); return true
func play_action(animation_id: StringName, _playback_rate: float = 1.0) -> bool:
	played.append(animation_id)
	if animation_id in rejected_actions:
		return false
	current_action_id = animation_id
	return true
func play_feedback(animation_id: StringName) -> bool:
	feedback_played.append(animation_id)
	return true
func finish_action(animation_id: StringName) -> void: action_finished.emit(animation_id)
func set_hit_weight(value: float) -> void: hit_weight = value
func set_downed(value: bool) -> void:
	downed = value
	if value:
		current_action_id = &""
