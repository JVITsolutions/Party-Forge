class_name EnemyDefeatEvent
extends RefCounted

const SOURCE_CATEGORIES: Array[StringName] = [&"ordinary_melee", &"ordinary_specialist", &"elite", &"boss"]

var _run_seed := 0
var run_seed: int:
	get:
		return _run_seed

var _defeat_sequence := 0
var defeat_sequence: int:
	get:
		return _defeat_sequence

var _enemy_sequence := 0
var enemy_sequence: int:
	get:
		return _enemy_sequence

var _enemy_id: StringName
var enemy_id: StringName:
	get:
		return _enemy_id

var _source_category: StringName
var source_category: StringName:
	get:
		return _source_category

var _world_position := Vector3.ZERO
var world_position: Vector3:
	get:
		return _world_position

var _encounter_seconds := 0.0
var encounter_seconds: float:
	get:
		return _encounter_seconds

static func create(
	run_seed_value: int,
	defeat_sequence_value: int,
	enemy_sequence_value: int,
	enemy_id_value: StringName,
	source_category_value: StringName,
	world_position_value: Vector3,
	encounter_seconds_value: float,
) -> EnemyDefeatEvent:
	var event := EnemyDefeatEvent.new()
	event._run_seed = run_seed_value
	event._defeat_sequence = defeat_sequence_value
	event._enemy_sequence = enemy_sequence_value
	event._enemy_id = enemy_id_value
	event._source_category = source_category_value
	event._world_position = world_position_value
	event._encounter_seconds = encounter_seconds_value
	return event

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if _defeat_sequence <= 0:
		errors.append("PARTY_FORGE_LOOT_ERROR field=defeat_sequence reason=must be positive")
	if _enemy_sequence <= 0:
		errors.append("PARTY_FORGE_LOOT_ERROR field=enemy_sequence reason=must be positive")
	if _enemy_id.is_empty():
		errors.append("PARTY_FORGE_LOOT_ERROR field=enemy_id reason=must not be empty")
	if _source_category not in SOURCE_CATEGORIES:
		errors.append("PARTY_FORGE_LOOT_ERROR field=source_category reason=unknown category %s" % _source_category)
	if not is_finite(_encounter_seconds) or _encounter_seconds < 0.0:
		errors.append("PARTY_FORGE_LOOT_ERROR field=encounter_seconds reason=must be finite and nonnegative")
	return errors
