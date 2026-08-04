class_name PartyCapacityPolicy
extends RefCounted

var _capacity := 4

func _init(capacity_value: int) -> void:
	_capacity = clampi(capacity_value, PartyForgeSettings.MIN_PARTY_CAPACITY, PartyForgeSettings.MAX_PARTY_CAPACITY)

func capacity() -> int: return _capacity

func can_add(current_count: int, additional_members: int = 1) -> bool:
	return current_count >= 0 and additional_members > 0 and current_count + additional_members <= _capacity
