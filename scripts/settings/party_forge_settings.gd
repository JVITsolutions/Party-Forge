class_name PartyForgeSettings
extends RefCounted

enum Mode { PLAYER_SIMULATION, DEVELOPER_MODE }

const SCHEMA_VERSION := 1
const MIN_PARTY_CAPACITY := 1
const MAX_PARTY_CAPACITY := 24
const MIN_ENEMY_DENSITY := 0
const MAX_ENEMY_DENSITY := 1000

var schema_version := SCHEMA_VERSION
var mode := Mode.PLAYER_SIMULATION
var unlock_all_implemented_content := false
var god_mode := false
var party_capacity_override := 4
var enemy_density_percent := 100

func normalize() -> void:
	if mode not in [Mode.PLAYER_SIMULATION, Mode.DEVELOPER_MODE]:
		mode = Mode.PLAYER_SIMULATION
	party_capacity_override = clampi(party_capacity_override, MIN_PARTY_CAPACITY, MAX_PARTY_CAPACITY)
	enemy_density_percent = clampi(enemy_density_percent, MIN_ENEMY_DENSITY, MAX_ENEMY_DENSITY)

func copy() -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.schema_version = schema_version
	result.mode = mode
	result.unlock_all_implemented_content = unlock_all_implemented_content
	result.god_mode = god_mode
	result.party_capacity_override = party_capacity_override
	result.enemy_density_percent = enemy_density_percent
	return result
