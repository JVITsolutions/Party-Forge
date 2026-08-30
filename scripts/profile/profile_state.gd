class_name ProfileState
extends RefCounted

const PlayerColorPalette := preload("res://scripts/profile/player_color_palette.gd")

enum PrologueState { NOT_STARTED, IN_PROGRESS, COMPLETED }

const SCHEMA_VERSION := 6
const MAX_STASH_TABS := 100

var schema_version := SCHEMA_VERSION
var profile_id := ""
var display_name := ""
var created_at_unix := 0
var updated_at_unix := 0
var prologue_state := PrologueState.NOT_STARTED
var last_safe_checkpoint: Dictionary = {}
var gold := 0
var passive_points_available := 0
var passive_points_lifetime_earned := 0
var milestones: Array[String] = []
var permanent_feature_unlocks: Array[String] = []
var discovered_buildings: Array[String] = []
var discovered_trees: Array[String] = []
var tree_allocations: Dictionary = {}
var tree_visibility_progress: Dictionary = {}
var owned_characters: Dictionary = {}
var squad_capacity := 1
var inventory_columns := 0
var item_records: Dictionary = {"schema_version": 1, "items": []}
var leader_loadout: Dictionary = {}
var leader_loadout_class_id := ""
var stash_tabs: Array[Dictionary] = []
var next_item_sequence := 0
var extraction_capacity := 0
var run_history: Array[Dictionary] = []
var resumable_run: Dictionary = {}
var applied_transactions: Dictionary = {}
var terminal_resolution: Dictionary = {}
var terminal_recovery_overflow: Dictionary = {}
var preferred_player_color_id: StringName = PlayerColorPalette.DEFAULT_ID

static func new_profile(
	id: String,
	name: String,
	now_unix: int,
	preferred_color_id: StringName = PlayerColorPalette.DEFAULT_ID,
) -> ProfileState:
	var result := ProfileState.new()
	result.profile_id = id.strip_edges()
	result.display_name = name.strip_edges()
	result.created_at_unix = maxi(0, now_unix)
	result.updated_at_unix = result.created_at_unix
	result.preferred_player_color_id = preferred_color_id
	result.leader_loadout = _empty_leader_loadout(result.profile_id)
	result.terminal_recovery_overflow = _empty_terminal_recovery_overflow(result.profile_id)
	result.normalize()
	return result

static func _empty_leader_loadout(profile_id: String) -> Dictionary:
	return ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile_id,
		EquipmentSlotIndex.capacity(),
	).to_dictionary()

static func _empty_terminal_recovery_overflow(profile_id: String) -> Dictionary:
	return ItemSlotContainer.create(
		ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID,
		ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW,
		profile_id,
		EquipmentSlotIndex.capacity(),
	).to_dictionary()

func normalize() -> void:
	display_name = display_name.strip_edges()
	gold = maxi(0, gold)
	passive_points_available = maxi(0, passive_points_available)
	passive_points_lifetime_earned = maxi(passive_points_available, passive_points_lifetime_earned)
	squad_capacity = maxi(1, squad_capacity)
	inventory_columns = clampi(inventory_columns, 0, 8)
	extraction_capacity = maxi(0, extraction_capacity)
	if prologue_state not in [PrologueState.NOT_STARTED, PrologueState.IN_PROGRESS, PrologueState.COMPLETED]:
		prologue_state = PrologueState.NOT_STARTED
	if not PlayerColorPalette.is_valid(preferred_player_color_id):
		preferred_player_color_id = PlayerColorPalette.DEFAULT_ID

func copy() -> ProfileState:
	return ProfileCodec.decode(ProfileCodec.encode(self)).profile

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"profile_id": profile_id,
		"display_name": display_name,
		"created_at_unix": created_at_unix,
		"updated_at_unix": updated_at_unix,
		"prologue_state": prologue_state,
		"last_safe_checkpoint": last_safe_checkpoint.duplicate(true),
		"gold": gold,
		"passive_points_available": passive_points_available,
		"passive_points_lifetime_earned": passive_points_lifetime_earned,
		"milestones": milestones.duplicate(),
		"permanent_feature_unlocks": permanent_feature_unlocks.duplicate(),
		"discovered_buildings": discovered_buildings.duplicate(),
		"discovered_trees": discovered_trees.duplicate(),
		"tree_allocations": tree_allocations.duplicate(true),
		"tree_visibility_progress": tree_visibility_progress.duplicate(true),
		"owned_characters": owned_characters.duplicate(true),
		"squad_capacity": squad_capacity,
		"inventory_columns": inventory_columns,
		"item_records": item_records.duplicate(true),
		"leader_loadout": leader_loadout.duplicate(true),
		"leader_loadout_class_id": leader_loadout_class_id,
		"stash_tabs": stash_tabs.duplicate(true),
		"next_item_sequence": next_item_sequence,
		"extraction_capacity": extraction_capacity,
		"run_history": run_history.duplicate(true),
		"resumable_run": resumable_run.duplicate(true),
		"applied_transactions": applied_transactions.duplicate(true),
		"terminal_resolution": terminal_resolution.duplicate(true),
		"terminal_recovery_overflow": terminal_recovery_overflow.duplicate(true),
		"preferred_player_color_id": String(preferred_player_color_id),
	}
