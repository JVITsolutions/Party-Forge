class_name CombatTestPolicy
extends RefCounted

var _god_mode := false
var _density := 100
var _developer_mode := false
var _unlock_all := false
var _capacity := 4

func _init(god_mode_enabled: bool, density: int, developer_mode: bool, unlock_all: bool, capacity: int) -> void:
	_developer_mode = developer_mode
	_god_mode = god_mode_enabled and developer_mode
	_density = clampi(density, 0, 1000) if developer_mode else 100
	_unlock_all = unlock_all and developer_mode
	_capacity = clampi(capacity, 1, 24) if developer_mode else 4

func god_mode() -> bool: return _god_mode
func enemy_density_percent() -> int: return _density
func minimum_party_health() -> float: return 1.0 if _god_mode else 0.0

func summary_parts() -> PackedStringArray:
	var parts := PackedStringArray()
	if not _developer_mode: return parts
	if _unlock_all: parts.append("UNLOCK ALL")
	if _god_mode: parts.append("GOD")
	if _capacity != 4: parts.append("PARTY %d" % _capacity)
	if _density != 100: parts.append("ENEMIES %d%%" % _density)
	return parts
