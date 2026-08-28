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
const UI_SCALE_OPTIONS: Array[int] = [80, 90, 100, 110, 125, 150]
const MIN_PERSONAL_DROP_MULTIPLIER_PERCENT := 0
const MAX_PERSONAL_DROP_MULTIPLIER_PERCENT := 10000
const MIN_PERSONAL_DROP_ITEM_LEVEL_OVERRIDE := 0
const MAX_PERSONAL_DROP_ITEM_LEVEL_OVERRIDE := 1000
const PERSONAL_DROP_SOURCE_CATEGORIES: Array[StringName] = [&"ordinary_melee", &"ordinary_specialist", &"elite", &"boss"]

var schema_version := SCHEMA_VERSION
var mode := Mode.PLAYER_SIMULATION
var unlock_all_implemented_content := false
var god_mode := false
var party_capacity_override := 4
var enemy_density_percent := 100
var experience_multiplier_percent := 100
var level_up_card_count := 5
var reduced_motion := false
var high_contrast := false
var ui_scale_percent := 100
var text_scale_percent := 100
var personal_drop_multiplier_percent := 100
var force_personal_drops := false
var personal_drop_source_category_override: StringName = &""
var personal_drop_item_level_override := 0
var show_ground_chest_diagnostics := false
var use_city_access_snapshot := false

func normalize() -> void:
	if mode not in [Mode.PLAYER_SIMULATION, Mode.DEVELOPER_MODE]:
		mode = Mode.PLAYER_SIMULATION
	party_capacity_override = clampi(party_capacity_override, MIN_PARTY_CAPACITY, MAX_PARTY_CAPACITY)
	enemy_density_percent = clampi(enemy_density_percent, MIN_ENEMY_DENSITY, MAX_ENEMY_DENSITY)
	experience_multiplier_percent = clampi(experience_multiplier_percent, MIN_EXPERIENCE_MULTIPLIER, MAX_EXPERIENCE_MULTIPLIER)
	level_up_card_count = clampi(level_up_card_count, MIN_LEVEL_UP_CARD_COUNT, MAX_LEVEL_UP_CARD_COUNT)
	ui_scale_percent = _nearest_ui_scale_option(ui_scale_percent)
	text_scale_percent = _nearest_ui_scale_option(text_scale_percent)
	personal_drop_multiplier_percent = clampi(personal_drop_multiplier_percent, MIN_PERSONAL_DROP_MULTIPLIER_PERCENT, MAX_PERSONAL_DROP_MULTIPLIER_PERCENT)
	personal_drop_item_level_override = clampi(personal_drop_item_level_override, MIN_PERSONAL_DROP_ITEM_LEVEL_OVERRIDE, MAX_PERSONAL_DROP_ITEM_LEVEL_OVERRIDE)
	if not personal_drop_source_category_override.is_empty() and personal_drop_source_category_override not in PERSONAL_DROP_SOURCE_CATEGORIES:
		personal_drop_source_category_override = &""

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
	result.reduced_motion = reduced_motion
	result.high_contrast = high_contrast
	result.ui_scale_percent = ui_scale_percent
	result.text_scale_percent = text_scale_percent
	result.personal_drop_multiplier_percent = personal_drop_multiplier_percent
	result.force_personal_drops = force_personal_drops
	result.personal_drop_source_category_override = personal_drop_source_category_override
	result.personal_drop_item_level_override = personal_drop_item_level_override
	result.show_ground_chest_diagnostics = show_ground_chest_diagnostics
	result.use_city_access_snapshot = use_city_access_snapshot
	return result


func _nearest_ui_scale_option(value: int) -> int:
	var nearest := UI_SCALE_OPTIONS[0]
	for option: int in UI_SCALE_OPTIONS:
		if abs(option - value) <= abs(nearest - value):
			nearest = option
	return nearest
