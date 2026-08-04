class_name RewardPacket
extends RefCounted

var packet_id: StringName
var experience := 0
var world_position := Vector3.ZERO

static func create(id: StringName, experience_value: int, position: Vector3) -> RewardPacket:
	var packet := RewardPacket.new()
	packet.packet_id = id
	packet.experience = experience_value
	packet.world_position = position
	return packet

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if packet_id.is_empty():
		errors.append("PARTY_FORGE_REWARD_ERROR field=packet_id")
	if experience < 0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=experience")
	return errors
