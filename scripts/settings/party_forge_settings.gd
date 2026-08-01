class_name PartyForgeSettings
extends RefCounted

enum Mode { PLAYER_SIMULATION, DEVELOPER_MODE }

const SCHEMA_VERSION := 1
const MIN_PARTY_CAPACITY := 1
const MAX_PARTY_CAPACITY := 24
const MIN_ENEMY_DENSITY := 0
const MAX_ENEMY_DENSITY := 1000
const MIN_EXPERIENCE_MULTIPLIER := 100
const MAX_EXPERIENCE_MULTIPLIER := 1000
const MIN_LEVEL_UP_CARD_COUNT := 1
const MAX_LEVEL_UP_CARD_COUNT := 8

var schema_version := SCHEMA_VERSION
var mode := Mode.PLAYER_SIMULATION
var unlock_all_implemented_content := false
var god_mode := false
var party_capacity_override := 4
var enemy_density_percent := 100
var experience_multiplier_percent := 100
var level_up_card_count := 5

func normalize() -> void:
	if mode not in [Mode.PLAYER_SIMULATION, Mode.DEVELOPER_MODE]:
		mode = Mode.PLAYER_SIMULATION
	party_capacity_override = clampi(party_capacity_override, MIN_PARTY_CAPACITY, MAX_PARTY_CAPACITY)
	enemy_density_percent = clampi(enemy_density_percent, MIN_ENEMY_DENSITY, MAX_ENEMY_DENSITY)
	experience_multiplier_percent = clampi(experience_multiplier_percent, MIN_EXPERIENCE_MULTIPLIER, MAX_EXPERIENCE_MULTIPLIER)
	level_up_card_count = clampi(level_up_card_count, MIN_LEVEL_UP_CARD_COUNT, MAX_LEVEL_UP_CARD_COUNT)

func copy() -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.schema_version = schema_version
	result.mode = mode
	result.unlock_all_implemented_content = unlock_all_implemented_content
	result.god_mode = god_mode
	result.party_capacity_override = party_capacity_override
	result.enemy_density_percent = enemy_density_percent
	result.experience_multiplier_percent = experience_multiplier_percent
	result.level_up_card_count = level_up_card_count
	return result
