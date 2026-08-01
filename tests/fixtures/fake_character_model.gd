class_name FakeCharacterModel
extends Node3D

var body_preset := &""
var palette_id := &""
var primary_color := Color.WHITE
var equipped: Dictionary = {}
var played: Array[StringName] = []
var downed := false
var hit_weight := 0.0

func set_body_preset(value: StringName) -> bool: body_preset = value; return value in [&"masculine", &"feminine"]
func set_palette(value: StringName, color: Color) -> bool: palette_id = value; primary_color = color; return true
func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool: equipped[slot_id] = definition.id; return true
func play_action(animation_id: StringName) -> bool: played.append(animation_id); return true
func set_hit_weight(value: float) -> void: hit_weight = value
func set_downed(value: bool) -> void: downed = value
