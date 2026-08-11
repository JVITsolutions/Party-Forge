class_name GroundItemRecord
extends RefCounted

var drop_id: StringName
var item_id := ""
var run_player_id: StringName
var profile_id := ""
var player_number := 0
var color_id: StringName
var world_position := Vector3.ZERO
var rarity_id: StringName
var source_id: StringName
var ground_slot := -1

func copy() -> GroundItemRecord:
	var result := GroundItemRecord.new()
	result.drop_id = drop_id
	result.item_id = item_id
	result.run_player_id = run_player_id
	result.profile_id = profile_id
	result.player_number = player_number
	result.color_id = color_id
	result.world_position = world_position
	result.rarity_id = rarity_id
	result.source_id = source_id
	result.ground_slot = ground_slot
	return result
