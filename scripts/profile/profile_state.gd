class_name ProfileState
extends RefCounted

enum PrologueState { NOT_STARTED, IN_PROGRESS, COMPLETED }

const SCHEMA_VERSION := 1

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
var stash_tabs: Array[Dictionary] = []
var extraction_capacity := 0
var run_history: Array[Dictionary] = []
var resumable_run: Dictionary = {}
var applied_transactions: Dictionary = {}

static func new_profile(id: String, name: String, now_unix: int) -> ProfileState:
	var result := ProfileState.new()
	result.profile_id = id.strip_edges()
	result.display_name = name.strip_edges()
	result.created_at_unix = maxi(0, now_unix)
	result.updated_at_unix = result.created_at_unix
	result.normalize()
	return result

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
		"stash_tabs": stash_tabs.duplicate(true),
		"extraction_capacity": extraction_capacity,
		"run_history": run_history.duplicate(true),
		"resumable_run": resumable_run.duplicate(true),
		"applied_transactions": applied_transactions.duplicate(true),
	}
