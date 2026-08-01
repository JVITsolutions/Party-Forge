# Party Forge Profile Persistence Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe local profiles, atomic persistence, verified backup recovery, idempotent profile mutations, profile creation and selection in Settings, and a boot-time profile gate while preserving the current arena front end.

**Architecture:** Typed `RefCounted` profile models serialize through one strict codec. A reusable atomic JSON document store owns temporary files, backup rotation, read-back validation, and recovery; `ProfileStore` and `ProfileIndexStore` adapt it to their schemas. `ProfileManager` owns discovery, unique names, and active selection, while `ProfileMutationService` is the only value-bearing mutation path. Settings receives the manager through an optional configuration seam so existing tests and current gameplay remain compatible.

**Tech Stack:** Godot 4.7.1, typed GDScript, JSON, `FileAccess`, `DirAccess`, TSCN scenes, the existing `tests/test_runner.gd` harness, and PowerShell verification on Windows.

## Global Constraints

- Execute in an isolated feature worktree created with the `using-git-worktrees` skill; do not implement directly in the user's dirty `main` checkout.
- Before creating the worktree, record `git status --short`, the current branch, open Godot processes, and the saved state of `scenes/game/main.tscn`.
- Preserve the user's existing `scenes/game/main.tscn`, `assets/ui/currency/`, and `docs/superpowers/plans/2026-08-01-hollow-zangetsu-coin-variants.md` work.
- Do not modify `scenes/game/main.tscn` in this plan. `PartyForgeMain` must create profile services in script and use the Settings scene already instanced there.
- Keep `user://party_forge_settings.cfg` machine-wide and separate from profile progression.
- Store profiles beneath `user://profiles/`; tests use unique `user://tests/profile_*` roots and remove only paths they created.
- Never silently replace an unreadable profile with an empty profile.
- Keep one verified previous profile backup after every successful overwrite.
- Every value-bearing mutation requires a non-empty idempotency key.
- Developer Mode must not grant or persist production profile unlocks in this plan.
- Do not implement passive-tree allocation, the cinematic menu, equipment, extraction, or split-screen gameplay here.
- Keep the current class-selection screen and arena runnable after an active profile is selected.
- Use `apply_patch` for source and scene edits. Do not save scenes through the open Godot editor.
- Every task follows RED, GREEN, full-suite verification, `git diff --check`, and a focused commit.
- The full-suite pass condition is exit code `0` plus `TEST_SUMMARY: PASS`; do not hard-code a suite count.
- Intentional negative-test diagnostics are acceptable only when the runner exits `0` and prints `TEST_SUMMARY: PASS`.

## Standard Verification Commands

Run these from the isolated worktree:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
```

Expected GREEN result: both Godot commands exit `0`, the runner prints `TEST_SUMMARY: PASS`, no unexpected `SCRIPT ERROR` or `TEST_FAILURE` appears, and `git diff --check` exits `0`.

## File and Responsibility Map

### Profile domain

- `scripts/profile/profile_state.gd` - typed persistent values, normalization, deep copy, and dictionary conversion.
- `scripts/profile/profile_load_result.gd` - typed profile decode/load result with missing, recovery, and error state.
- `scripts/profile/profile_codec.gd` - strict JSON/schema parsing and profile validation.
- `scripts/profile/json_document_result.gd` - typed generic JSON load result.
- `scripts/profile/atomic_json_store.gd` - atomic temporary-write, read-back verification, backup rotation, recovery, and injected promotion failure seam.
- `scripts/profile/profile_store.gd` - profile-specific file names and codec adaptation.
- `scripts/profile/profile_index.gd` - versioned profile summaries and active profile ID.
- `scripts/profile/profile_index_store.gd` - atomic index persistence through `AtomicJsonStore`.
- `scripts/profile/profile_operation_result.gd` - typed manager operation result.
- `scripts/profile/profile_manager.gd` - discovery, orphan reconciliation, unique names, creation, active selection, and in-memory copies.
- `scripts/profile/profile_mutation_result.gd` - typed committed/duplicate/error mutation result.
- `scripts/profile/profile_mutation_service.gd` - idempotent load-mutate-save transactions and initial grant helpers.

### Settings presentation

- `scripts/ui/settings/profiles_settings_page.gd` - profile list, create/select actions, friendly errors, and focus contract.
- `scenes/ui/settings/profiles_settings_page.tscn` - responsive Profiles page.
- `scripts/ui/settings/settings_screen.gd` - optional profile-manager configuration, Profiles tab focus, and profile error disclosure.
- `scenes/ui/settings/settings_screen.tscn` - inserts Profiles before Additional Settings.

### Boot integration

- `scripts/game/main.gd` - creates the stores/manager, bootstraps profiles, configures Settings, and rejects run launch without an active profile.

### Tests

- `tests/unit/test_profile_state.gd`
- `tests/unit/test_atomic_profile_store.gd`
- `tests/unit/test_profile_manager.gd`
- `tests/unit/test_profile_mutation_service.gd`
- `tests/unit/test_profiles_settings_page.gd`
- `tests/unit/test_profile_boot_integration.gd`
- `tests/unit/test_settings_screen.gd`
- `tests/unit/test_main_wiring.gd`

---

### Task 1: Typed profile state and strict codec

**Files:**
- Create: `scripts/profile/profile_state.gd`
- Create: `scripts/profile/profile_load_result.gd`
- Create: `scripts/profile/profile_codec.gd`
- Test: `tests/unit/test_profile_state.gd`

**Interfaces:**
- Produces: `ProfileState.PrologueState { NOT_STARTED, IN_PROGRESS, COMPLETED }`
- Produces: `ProfileState.new_profile(profile_id: String, display_name: String, now_unix: int) -> ProfileState`
- Produces: `ProfileState.normalize() -> void`
- Produces: `ProfileState.copy() -> ProfileState`
- Produces: `ProfileState.to_dictionary() -> Dictionary`
- Produces: `ProfileCodec.encode(profile: ProfileState) -> String`
- Produces: `ProfileCodec.decode(text: String) -> ProfileLoadResult`
- Produces: `ProfileCodec.validate_profile(profile: ProfileState) -> String`; empty means valid.

- [ ] **Step 1: Write the failing profile-state suite**

Create `tests/unit/test_profile_state.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_new_profile_defaults(failures)
	_test_round_trip_and_deep_copy(failures)
	_test_malformed_and_future_schema_fail_closed(failures)
	return failures

func _test_new_profile_defaults(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	TestAssertions.equal(profile.schema_version, ProfileState.SCHEMA_VERSION, "profile uses current schema", failures)
	TestAssertions.equal(profile.prologue_state, ProfileState.PrologueState.NOT_STARTED, "prologue starts undiscovered", failures)
	TestAssertions.equal(profile.gold, 0, "gold starts at zero", failures)
	TestAssertions.equal(profile.passive_points_available, 0, "passive points start at zero", failures)
	TestAssertions.equal(profile.squad_capacity, 1, "profile starts with leader-only capacity", failures)
	TestAssertions.equal(profile.inventory_columns, 0, "inventory remains locked", failures)
	TestAssertions.equal(profile.extraction_capacity, 0, "extraction remains locked", failures)

func _test_round_trip_and_deep_copy(failures: Array[String]) -> void:
	var profile := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	profile.permanent_feature_unlocks.append("equipment")
	profile.tree_allocations["party-forge-city-v1"] = ["city-heart"]
	var decoded := ProfileCodec.decode(ProfileCodec.encode(profile))
	TestAssertions.truthy(decoded.ok(), "valid profile decodes", failures)
	TestAssertions.equal(decoded.profile.to_dictionary(), profile.to_dictionary(), "profile round trips exactly", failures)
	var copied := profile.copy()
	(copied.tree_allocations["party-forge-city-v1"] as Array).append("shared-stash")
	TestAssertions.equal((profile.tree_allocations["party-forge-city-v1"] as Array).size(), 1, "copy isolates nested allocations", failures)

func _test_malformed_and_future_schema_fail_closed(failures: Array[String]) -> void:
	var malformed := ProfileCodec.decode("{not json")
	TestAssertions.truthy(not malformed.ok() and malformed.error.contains("PROFILE_DECODE_ERROR"), "malformed JSON reports decode error", failures)
	var future := ProfileState.new_profile("profile-12345678", "Jacob", 1000).to_dictionary()
	future["schema_version"] = ProfileState.SCHEMA_VERSION + 1
	var future_result := ProfileCodec.decode(JSON.stringify(future))
	TestAssertions.truthy(not future_result.ok() and future_result.error.contains("unsupported schema"), "future schema fails closed", failures)
```

- [ ] **Step 2: Run the full suite to verify RED**

Run the standard test command. Expected: nonzero exit or `TEST_SUMMARY: FAIL`, with `ProfileState` or `ProfileCodec` missing.

- [ ] **Step 3: Implement the typed state and result**

Create `scripts/profile/profile_load_result.gd`:

```gdscript
class_name ProfileLoadResult
extends RefCounted

var profile: ProfileState
var error := ""
var missing := false
var recovered_from_backup := false

func ok() -> bool:
	return profile != null and error.is_empty()
```

Create `scripts/profile/profile_state.gd`:

```gdscript
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
```

- [ ] **Step 4: Implement strict decoding and validation**

Create `scripts/profile/profile_codec.gd` with one explicit field assignment per saved field; do not use reflective `set()` loops:

```gdscript
class_name ProfileCodec
extends RefCounted

static func encode(profile: ProfileState) -> String:
	return JSON.stringify(profile.to_dictionary(), "\t", false)

static func decode(text: String) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		result.error = "PROFILE_DECODE_ERROR line=%d reason=%s" % [parser.get_error_line(), parser.get_error_message()]
		return result
	var data := parser.data as Dictionary
	if typeof(data.get("schema_version")) != TYPE_INT or int(data["schema_version"]) != ProfileState.SCHEMA_VERSION:
		result.error = "PROFILE_SCHEMA_ERROR version=%s supported=%d reason=unsupported schema" % [data.get("schema_version", "missing"), ProfileState.SCHEMA_VERSION]
		return result
	var profile := ProfileState.new()
	profile.schema_version = int(data["schema_version"])
	profile.profile_id = str(data.get("profile_id", ""))
	profile.display_name = str(data.get("display_name", ""))
	profile.created_at_unix = int(data.get("created_at_unix", 0))
	profile.updated_at_unix = int(data.get("updated_at_unix", profile.created_at_unix))
	profile.prologue_state = int(data.get("prologue_state", ProfileState.PrologueState.NOT_STARTED))
	profile.last_safe_checkpoint = _dictionary(data.get("last_safe_checkpoint", {}))
	profile.gold = int(data.get("gold", 0))
	profile.passive_points_available = int(data.get("passive_points_available", 0))
	profile.passive_points_lifetime_earned = int(data.get("passive_points_lifetime_earned", 0))
	profile.milestones = _strings(data.get("milestones", []))
	profile.permanent_feature_unlocks = _strings(data.get("permanent_feature_unlocks", []))
	profile.discovered_buildings = _strings(data.get("discovered_buildings", []))
	profile.discovered_trees = _strings(data.get("discovered_trees", []))
	profile.tree_allocations = _dictionary(data.get("tree_allocations", {}))
	profile.tree_visibility_progress = _dictionary(data.get("tree_visibility_progress", {}))
	profile.owned_characters = _dictionary(data.get("owned_characters", {}))
	profile.squad_capacity = int(data.get("squad_capacity", 1))
	profile.inventory_columns = int(data.get("inventory_columns", 0))
	profile.stash_tabs = _dictionaries(data.get("stash_tabs", []))
	profile.extraction_capacity = int(data.get("extraction_capacity", 0))
	profile.run_history = _dictionaries(data.get("run_history", []))
	profile.resumable_run = _dictionary(data.get("resumable_run", {}))
	profile.applied_transactions = _dictionary(data.get("applied_transactions", {}))
	profile.normalize()
	result.error = validate_profile(profile)
	if result.error.is_empty():
		result.profile = profile
	return result

static func validate_profile(profile: ProfileState) -> String:
	if profile == null:
		return "PROFILE_VALIDATION_ERROR reason=profile is null"
	if profile.profile_id.length() < 8 or not profile.profile_id.is_valid_filename():
		return "PROFILE_VALIDATION_ERROR profile=%s reason=invalid profile id" % profile.profile_id
	if profile.display_name.is_empty() or profile.display_name.length() > 32:
		return "PROFILE_VALIDATION_ERROR profile=%s reason=display name must contain 1-32 characters" % profile.profile_id
	if profile.updated_at_unix < profile.created_at_unix:
		return "PROFILE_VALIDATION_ERROR profile=%s reason=updated time predates creation" % profile.profile_id
	return ""

static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			if typeof(item) == TYPE_STRING:
				result.append(item)
	return result

static func _dictionaries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
```

- [ ] **Step 5: Verify GREEN and commit**

Run the standard verification commands. Expected: `TEST_SUMMARY: PASS` and no parser error.

```powershell
git add scripts/profile/profile_state.gd scripts/profile/profile_load_result.gd scripts/profile/profile_codec.gd tests/unit/test_profile_state.gd
git commit -m "feat: add versioned profile state"
```

---

### Task 2: Atomic JSON storage and verified profile recovery

**Files:**
- Create: `scripts/profile/json_document_result.gd`
- Create: `scripts/profile/atomic_json_store.gd`
- Create: `scripts/profile/profile_store.gd`
- Test: `tests/unit/test_atomic_profile_store.gd`

**Interfaces:**
- Consumes: `ProfileCodec.encode()`, `ProfileCodec.decode()`.
- Produces: `AtomicJsonStore.new(promote_file: Callable = Callable())`.
- Produces: `AtomicJsonStore.save_document(path: String, document: Dictionary, validator: Callable) -> String`.
- Produces: `AtomicJsonStore.load_document(path: String, validator: Callable, recover_backup: bool = true) -> JsonDocumentResult`.
- Produces: `ProfileStore.save_profile(profile: ProfileState, root: String = DEFAULT_ROOT) -> String`.
- Produces: `ProfileStore.load_profile(profile_id: String, root: String = DEFAULT_ROOT) -> ProfileLoadResult`.
- Produces: `ProfileStore.profile_ids(root: String = DEFAULT_ROOT) -> PackedStringArray`.

- [ ] **Step 1: Write failing atomic-storage tests**

Create `tests/unit/test_atomic_profile_store.gd` with cases that:

```gdscript
extends RefCounted

const ROOT := "user://tests/profile_store"

func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_round_trip_and_backup_recovery(failures)
	_test_backup_only_is_discoverable(failures)
	_test_corrupt_primary_is_preserved_before_resave(failures)
	_test_failed_promotion_preserves_primary(failures)
	_test_missing_profile_is_distinct(failures)
	_cleanup()
	return failures

func _test_round_trip_and_backup_recovery(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var first := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	first.gold = 10
	TestAssertions.equal(store.save_profile(first, ROOT), "", "first profile save succeeds", failures)
	var second := first.copy()
	second.gold = 20
	second.updated_at_unix = 1001
	TestAssertions.equal(store.save_profile(second, ROOT), "", "second save creates backup", failures)
	var primary_path := store.profile_path(first.profile_id, ROOT)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	var recovered := store.load_profile(first.profile_id, ROOT)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "corrupt primary recovers verified backup", failures)
	TestAssertions.equal(recovered.profile.gold, 10, "recovery returns previous committed generation", failures)

func _test_failed_promotion_preserves_primary(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var original := ProfileState.new_profile("profile-abcdefgh", "Original", 2000)
	TestAssertions.equal(good.save_profile(original, ROOT), "", "baseline save succeeds", failures)
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var changed := original.copy()
	changed.display_name = "Changed"
	TestAssertions.truthy(not failing.save_profile(changed, ROOT).is_empty(), "failed promotion reports error", failures)
	TestAssertions.equal(good.load_profile(original.profile_id, ROOT).profile.display_name, "Original", "failed promotion preserves primary", failures)

func _test_backup_only_is_discoverable(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-backup01", "Backup", 3000)
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "backup-only fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 3001
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "backup-only fixture creates backup", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.profile_path(profile.profile_id, ROOT)))
	TestAssertions.truthy(profile.profile_id in store.profile_ids(ROOT), "backup-only profile remains discoverable", failures)

func _test_corrupt_primary_is_preserved_before_resave(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-corrupt1", "Corrupt", 4000)
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "corrupt fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 4001
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "corrupt fixture creates verified backup", failures)
	var primary_path := store.profile_path(profile.profile_id, ROOT)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt original bytes")
	corrupt.close()
	var recovered := store.load_profile(profile.profile_id, ROOT)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "fixture recovers backup", failures)
	recovered.profile.gold = 3
	recovered.profile.updated_at_unix = 4002
	TestAssertions.equal(store.save_profile(recovered.profile, ROOT), "", "recovered profile resaves", failures)
	var artifacts := DirAccess.get_files_at(ROOT)
	TestAssertions.truthy(artifacts.any(func(name: String) -> bool: return name.begins_with("profile-corrupt1.json.corrupt-")), "corrupt primary is preserved for diagnosis", failures)
	TestAssertions.equal(store.load_profile(profile.profile_id, ROOT).profile.gold, 3, "resaved primary is current", failures)

func _test_missing_profile_is_distinct(failures: Array[String]) -> void:
	var missing := ProfileStore.new().load_profile("profile-missing1", ROOT)
	TestAssertions.truthy(missing.missing and not missing.ok(), "missing profile is not treated as corruption", failures)

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory != null:
		for name: String in directory.get_files():
			DirAccess.remove_absolute(path.path_join(name))
		for name: String in directory.get_directories():
			_remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Verify RED**

Run the full suite. Expected: failure because `ProfileStore` and `AtomicJsonStore` do not exist.

- [ ] **Step 3: Implement the generic atomic store**

Create `scripts/profile/json_document_result.gd`:

```gdscript
class_name JsonDocumentResult
extends RefCounted

var document: Dictionary = {}
var error := ""
var missing := false
var recovered_from_backup := false

func ok() -> bool:
	return error.is_empty() and not missing
```

Create `scripts/profile/atomic_json_store.gd`:

```gdscript
class_name AtomicJsonStore
extends RefCounted

var _promote_file: Callable

func _init(promote_file: Callable = Callable()) -> void:
	_promote_file = promote_file

func save_document(path: String, document: Dictionary, validator: Callable) -> String:
	if not validator.is_valid():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=validator is missing" % path
	var validation := str(validator.call(document))
	if not validation.is_empty():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=%s" % [path, validation]
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_parent := absolute_target.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_parent)
	if mkdir_error not in [OK, ERR_ALREADY_EXISTS]:
		return "JSON_STORE_SAVE_ERROR path=%s stage=mkdir code=%d" % [path, mkdir_error]
	var temporary := "%s.tmp" % path
	var backup := "%s.bak" % path
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "JSON_STORE_SAVE_ERROR path=%s stage=write code=%d" % [path, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(document, "\t", false))
	file.close()
	var temporary_result := _load_one(temporary, validator)
	if not temporary_result.ok():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-temporary reason=%s" % [path, temporary_result.error]
	var had_previous := FileAccess.file_exists(path)
	var previous_was_valid := false
	var preserved_corrupt := ""
	if had_previous:
		var previous := _load_one(path, validator)
		previous_was_valid = previous.ok()
		if previous_was_valid:
			if FileAccess.file_exists(backup):
				var remove_backup_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
				if remove_backup_error != OK:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
					return "JSON_STORE_SAVE_ERROR path=%s stage=remove-old-backup code=%d" % [path, remove_backup_error]
			var backup_error := DirAccess.rename_absolute(absolute_target, ProjectSettings.globalize_path(backup))
			if backup_error != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
				return "JSON_STORE_SAVE_ERROR path=%s stage=backup code=%d" % [path, backup_error]
		else:
			var verified_backup := _load_one(backup, validator)
			if not verified_backup.ok():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
				return "JSON_STORE_SAVE_ERROR path=%s stage=validate-existing primary=%s backup=%s" % [path, previous.error, verified_backup.error]
			preserved_corrupt = "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
			var preserve_error := DirAccess.rename_absolute(absolute_target, ProjectSettings.globalize_path(preserved_corrupt))
			if preserve_error != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
				return "JSON_STORE_SAVE_ERROR path=%s stage=preserve-corrupt code=%d" % [path, preserve_error]
			push_warning("JSON_STORE_CORRUPT_PRIMARY_PRESERVED path=%s artifact=%s" % [path, preserved_corrupt])
	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		var restore_after_promote := _restore_backup(path, backup, had_previous, previous_was_valid)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "JSON_STORE_SAVE_ERROR path=%s stage=promote code=%d restore_code=%d" % [path, promote_error, restore_after_promote]
	var promoted := _load_one(path, validator)
	if not promoted.ok():
		DirAccess.remove_absolute(absolute_target)
		var restore_after_verify := _restore_backup(path, backup, had_previous, previous_was_valid)
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-promoted restore_code=%d reason=%s" % [path, restore_after_verify, promoted.error]
	return ""

func load_document(path: String, validator: Callable, recover_backup: bool = true) -> JsonDocumentResult:
	if not validator.is_valid():
		var invalid := JsonDocumentResult.new()
		invalid.error = "JSON_STORE_LOAD_ERROR path=%s reason=validator is missing" % path
		return invalid
	var primary := _load_one(path, validator)
	if primary.ok():
		return primary
	if not recover_backup:
		return primary
	var backup_path := "%s.bak" % path
	var backup := _load_one(backup_path, validator)
	if backup.ok():
		backup.recovered_from_backup = true
		return backup
	if primary.missing and backup.missing:
		return primary
	var failed := JsonDocumentResult.new()
	failed.error = "JSON_STORE_LOAD_ERROR path=%s primary=%s backup=%s" % [path, primary.error, backup.error]
	return failed

func _load_one(path: String, validator: Callable) -> JsonDocumentResult:
	var result := JsonDocumentResult.new()
	if not FileAccess.file_exists(path):
		result.missing = true
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = "open code=%d" % FileAccess.get_open_error()
		return result
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		result.error = "parse line=%d reason=%s" % [parser.get_error_line(), parser.get_error_message()]
		return result
	var document := (parser.data as Dictionary).duplicate(true)
	var validation := str(validator.call(document))
	if not validation.is_empty():
		result.error = "validate reason=%s" % validation
		return result
	result.document = document
	return result

func _restore_backup(path: String, backup: String, had_previous: bool, previous_was_valid: bool) -> Error:
	if not had_previous:
		return OK
	if previous_was_valid:
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(path))
	var bytes := FileAccess.get_file_as_bytes(backup)
	var restored := FileAccess.open(path, FileAccess.WRITE)
	if restored == null:
		return FileAccess.get_open_error()
	restored.store_buffer(bytes)
	restored.close()
	return OK

func _promote(temporary: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
```

- [ ] **Step 4: Implement the profile adapter**

Create `scripts/profile/profile_store.gd`:

```gdscript
class_name ProfileStore
extends RefCounted

const DEFAULT_ROOT := "user://profiles"

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func profile_path(profile_id: String, root: String = DEFAULT_ROOT) -> String:
	return root.path_join("%s.json" % profile_id)

func save_profile(profile: ProfileState, root: String = DEFAULT_ROOT) -> String:
	var validation := ProfileCodec.validate_profile(profile)
	if not validation.is_empty():
		return validation
	return _documents.save_document(profile_path(profile.profile_id, root), profile.to_dictionary(), func(document: Dictionary) -> String:
		var decoded := ProfileCodec.decode(JSON.stringify(document))
		return decoded.error
	)

func load_profile(profile_id: String, root: String = DEFAULT_ROOT) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var loaded := _documents.load_document(profile_path(profile_id, root), func(document: Dictionary) -> String:
		var decoded := ProfileCodec.decode(JSON.stringify(document))
		return decoded.error
	)
	result.missing = loaded.missing
	result.recovered_from_backup = loaded.recovered_from_backup
	result.error = loaded.error
	if loaded.ok():
		var decoded := ProfileCodec.decode(JSON.stringify(loaded.document))
		result.profile = decoded.profile
		result.error = decoded.error
	return result

func profile_ids(root: String = DEFAULT_ROOT) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	for name: String in directory.get_files():
		var profile_id := ""
		if name.ends_with(".json") and name != "profile_index.json":
			profile_id = name.trim_suffix(".json")
		elif name.ends_with(".json.bak") and name != "profile_index.json.bak":
			profile_id = name.trim_suffix(".json.bak")
		if not profile_id.is_empty() and profile_id not in result:
			result.append(profile_id)
	result.sort()
	return result
```

Before GREEN, harden the `save_profile` validation Callable so a decode failure returns its error without dereferencing a null profile.

- [ ] **Step 5: Verify recovery behavior and commit**

Run the standard verification commands. Inspect the test root afterward and require that the suite cleanup removed it.

```powershell
git add scripts/profile/json_document_result.gd scripts/profile/atomic_json_store.gd scripts/profile/profile_store.gd tests/unit/test_atomic_profile_store.gd
git commit -m "feat: persist profiles atomically"
```

**Review checkpoint:** inspect restore logic before continuing. A failed promotion must not erase the last valid primary or its only valid backup.

---

### Task 3: Profile index, discovery, creation, and active selection

**Files:**
- Create: `scripts/profile/profile_index.gd`
- Create: `scripts/profile/profile_index_load_result.gd`
- Create: `scripts/profile/profile_index_store.gd`
- Create: `scripts/profile/profile_operation_result.gd`
- Create: `scripts/profile/profile_manager.gd`
- Test: `tests/unit/test_profile_manager.gd`

**Interfaces:**
- Consumes: `ProfileStore`, `AtomicJsonStore`, `ProfileState`.
- Produces: `ProfileManager.bootstrap(root: String = ProfileStore.DEFAULT_ROOT) -> String`.
- Produces: `ProfileManager.profiles() -> Array[ProfileState]` returning deep copies.
- Produces: `ProfileManager.active_profile() -> ProfileState` returning a deep copy or null.
- Produces: `ProfileManager.create_profile(display_name: String, now_unix: int = -1) -> ProfileOperationResult`.
- Produces: `ProfileManager.select_profile(profile_id: String) -> String`.
- Produces: `ProfileManager.refresh_profile(profile_id: String) -> String`.
- Produces signals: `profiles_changed`, `active_profile_changed(profile: ProfileState)`.

- [ ] **Step 1: Write failing manager tests**

Create `tests/unit/test_profile_manager.gd` covering:

```gdscript
extends RefCounted

const ROOT := "user://tests/profile_manager"

func run() -> Array[String]:
	var failures: Array[String] = []
	ProfileTestSupport.remove_tree(ROOT)
	var ids: Array[String] = ["profile-aaaaaaaa", "profile-bbbbbbbb"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(ROOT), "", "empty root bootstraps", failures)
	var first := manager.create_profile("Jacob", 1000)
	TestAssertions.truthy(first.ok(), "first profile creates", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Jacob", "first profile becomes active", failures)
	var duplicate := manager.create_profile("  jacob  ", 1001)
	TestAssertions.truthy(not duplicate.ok() and duplicate.error.contains("name already exists"), "names are unique case-insensitively", failures)
	var second := manager.create_profile("Guest", 1002)
	TestAssertions.truthy(second.ok(), "second profile creates", failures)
	TestAssertions.equal(manager.profiles().size(), 2, "manager lists both profiles", failures)
	TestAssertions.equal(manager.select_profile(first.profile.profile_id), "", "existing profile selects", failures)
	TestAssertions.equal(manager.active_profile().profile_id, first.profile.profile_id, "selection persists in memory", failures)
	var reloaded := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new())
	TestAssertions.equal(reloaded.bootstrap(ROOT), "", "manager reloads from disk", failures)
	TestAssertions.equal(reloaded.active_profile().profile_id, first.profile.profile_id, "active selection round trips", failures)
	ProfileTestSupport.remove_tree(ROOT)
	return failures
```

Create `tests/support/profile_test_support.gd` and update Task 2's test to use it:

```gdscript
class_name ProfileTestSupport
extends RefCounted

static func remove_tree(user_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(user_path)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_absolute_tree(absolute)

static func _remove_absolute_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory != null:
		for name: String in directory.get_files():
			DirAccess.remove_absolute(path.path_join(name))
		for name: String in directory.get_directories():
			_remove_absolute_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Verify RED**

Run the full suite. Expected: missing index/manager classes.

- [ ] **Step 3: Implement the index model and store**

`ProfileIndex` stores only recoverable summaries:

```gdscript
class_name ProfileIndex
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var active_profile_id := ""
var entries: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {"schema_version": schema_version, "active_profile_id": active_profile_id, "entries": entries.duplicate(true)}

func rebuild(profiles: Array[ProfileState]) -> void:
	entries.clear()
	for profile: ProfileState in profiles:
		entries.append({"profile_id": profile.profile_id, "display_name": profile.display_name, "updated_at_unix": profile.updated_at_unix})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["updated_at_unix"]) > int(b["updated_at_unix"]))
```

Create `profile_index_load_result.gd`:

```gdscript
class_name ProfileIndexLoadResult
extends RefCounted

var index: ProfileIndex
var error := ""
var missing := false

func ok() -> bool:
	return index != null and error.is_empty()
```

Create `profile_index_store.gd`:

```gdscript
class_name ProfileIndexStore
extends RefCounted

const FILE_NAME := "profile_index.json"

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
	return _documents.save_document(root.path_join(FILE_NAME), index.to_dictionary(), Callable(self, "_validate_document"))

func load_index(root: String = ProfileStore.DEFAULT_ROOT) -> ProfileIndexLoadResult:
	var result := ProfileIndexLoadResult.new()
	var loaded := _documents.load_document(root.path_join(FILE_NAME), Callable(self, "_validate_document"))
	result.missing = loaded.missing
	if loaded.missing:
		result.index = ProfileIndex.new()
		return result
	if not loaded.ok():
		result.error = loaded.error
		return result
	var index := ProfileIndex.new()
	index.schema_version = int(loaded.document["schema_version"])
	index.active_profile_id = str(loaded.document.get("active_profile_id", ""))
	for entry: Variant in loaded.document.get("entries", []):
		index.entries.append((entry as Dictionary).duplicate(true))
	result.index = index
	return result

func _validate_document(document: Dictionary) -> String:
	if typeof(document.get("schema_version")) != TYPE_INT or int(document["schema_version"]) != ProfileIndex.SCHEMA_VERSION:
		return "PROFILE_INDEX_ERROR reason=unsupported schema"
	if typeof(document.get("active_profile_id", "")) != TYPE_STRING:
		return "PROFILE_INDEX_ERROR reason=active profile id must be a string"
	if not document.get("entries", []) is Array:
		return "PROFILE_INDEX_ERROR reason=entries must be an array"
	for entry: Variant in document.get("entries", []):
		if not entry is Dictionary:
			return "PROFILE_INDEX_ERROR reason=entry must be a dictionary"
		var item := entry as Dictionary
		if typeof(item.get("profile_id")) != TYPE_STRING or typeof(item.get("display_name")) != TYPE_STRING or typeof(item.get("updated_at_unix")) != TYPE_INT:
			return "PROFILE_INDEX_ERROR reason=entry fields have invalid types"
	return ""
```

- [ ] **Step 4: Implement the operation result and manager**

Create `profile_operation_result.gd`:

```gdscript
class_name ProfileOperationResult
extends RefCounted

var profile: ProfileState
var error := ""

func ok() -> bool:
	return profile != null and error.is_empty()
```

Create `profile_manager.gd`:

```gdscript
class_name ProfileManager
extends RefCounted

signal profiles_changed
signal active_profile_changed(profile: ProfileState)

var _profiles: Dictionary = {}
var _index := ProfileIndex.new()
var _profile_store: ProfileStore
var _index_store: ProfileIndexStore
var _id_factory: Callable
var _root := ProfileStore.DEFAULT_ROOT

func _init(profile_store: ProfileStore = null, index_store: ProfileIndexStore = null, id_factory: Callable = Callable()) -> void:
	_profile_store = profile_store if profile_store != null else ProfileStore.new()
	_index_store = index_store if index_store != null else ProfileIndexStore.new()
	_id_factory = id_factory

func bootstrap(root: String = ProfileStore.DEFAULT_ROOT) -> String:
	_root = root
	_profiles.clear()
	var diagnostics: Array[String] = []
	for profile_id: String in _profile_store.profile_ids(_root):
		var loaded := _profile_store.load_profile(profile_id, _root)
		if loaded.ok():
			_profiles[profile_id] = loaded.profile
		else:
			diagnostics.append("profile=%s error=%s" % [profile_id, loaded.error])
	var loaded_index := _index_store.load_index(_root)
	if loaded_index.ok():
		_index = loaded_index.index
	else:
		_index = ProfileIndex.new()
		if not loaded_index.error.is_empty():
			diagnostics.append(loaded_index.error)
	if not _profiles.has(_index.active_profile_id):
		_index.active_profile_id = _most_recent_profile_id()
	_rebuild_index()
	var save_error := _index_store.save_index(_index, _root)
	if not save_error.is_empty():
		diagnostics.append(save_error)
	return "" if diagnostics.is_empty() else "PROFILE_BOOTSTRAP_ERROR %s" % " | ".join(diagnostics)

func profiles() -> Array[ProfileState]:
	var result: Array[ProfileState] = []
	for profile: ProfileState in _profiles.values():
		result.append(profile.copy())
	result.sort_custom(func(a: ProfileState, b: ProfileState) -> bool: return a.updated_at_unix > b.updated_at_unix)
	return result

func active_profile() -> ProfileState:
	var profile := _profiles.get(_index.active_profile_id) as ProfileState
	return profile.copy() if profile != null else null

func create_profile(display_name: String, now_unix: int = -1) -> ProfileOperationResult:
	var result := ProfileOperationResult.new()
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 32:
		result.error = "PROFILE_CREATE_ERROR reason=name must contain 1-32 characters"
		return result
	var normalized := clean_name.to_lower()
	for profile: ProfileState in _profiles.values():
		if profile.display_name.strip_edges().to_lower() == normalized:
			result.error = "PROFILE_CREATE_ERROR reason=name already exists"
			return result
	var profile_id := _next_profile_id()
	if _profiles.has(profile_id):
		result.error = "PROFILE_CREATE_ERROR profile=%s reason=id collision" % profile_id
		return result
	var timestamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var profile := ProfileState.new_profile(profile_id, clean_name, timestamp)
	var save_error := _profile_store.save_profile(profile, _root)
	if not save_error.is_empty():
		result.error = save_error
		return result
	var previous_active := _index.active_profile_id
	_profiles[profile_id] = profile
	_index.active_profile_id = profile_id
	_rebuild_index()
	var index_error := _index_store.save_index(_index, _root)
	if not index_error.is_empty():
		_profiles.erase(profile_id)
		_index.active_profile_id = previous_active
		_rebuild_index()
		result.error = index_error
		return result
	result.profile = profile.copy()
	profiles_changed.emit()
	active_profile_changed.emit(profile.copy())
	return result

func select_profile(profile_id: String) -> String:
	if not _profiles.has(profile_id):
		return "PROFILE_SELECT_ERROR profile=%s reason=unknown profile" % profile_id
	var previous := _index.active_profile_id
	_index.active_profile_id = profile_id
	var save_error := _index_store.save_index(_index, _root)
	if not save_error.is_empty():
		_index.active_profile_id = previous
		return save_error
	active_profile_changed.emit((_profiles[profile_id] as ProfileState).copy())
	return ""

func refresh_profile(profile_id: String) -> String:
	var loaded := _profile_store.load_profile(profile_id, _root)
	if not loaded.ok():
		return loaded.error
	_profiles[profile_id] = loaded.profile
	_rebuild_index()
	var save_error := _index_store.save_index(_index, _root)
	if save_error.is_empty():
		profiles_changed.emit()
	return save_error

func _rebuild_index() -> void:
	_index.rebuild(profiles())

func _most_recent_profile_id() -> String:
	var available := profiles()
	return available[0].profile_id if not available.is_empty() else ""

func _next_profile_id() -> String:
	if _id_factory.is_valid():
		return str(_id_factory.call())
	return "profile-%s" % Crypto.new().generate_random_bytes(16).hex_encode()
```

Before GREEN, make `bootstrap()` preserve `active_profile_id` across `_rebuild_index()`; `ProfileIndex.rebuild()` must not overwrite it. Add a test for a corrupt index plus two valid profile files and require recovery to select the most recently updated profile.

- [ ] **Step 5: Verify GREEN and commit**

Run the standard verification commands.

```powershell
git add scripts/profile/profile_index.gd scripts/profile/profile_index_load_result.gd scripts/profile/profile_index_store.gd scripts/profile/profile_operation_result.gd scripts/profile/profile_manager.gd tests/support/profile_test_support.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_manager.gd
git commit -m "feat: manage local player profiles"
```

---

### Task 4: Idempotent profile mutation service

**Files:**
- Create: `scripts/profile/profile_mutation_result.gd`
- Create: `scripts/profile/profile_mutation_service.gd`
- Test: `tests/unit/test_profile_mutation_service.gd`

**Interfaces:**
- Consumes: `ProfileStore.load_profile()` and `ProfileStore.save_profile()`.
- Produces: `ProfileMutationService.apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1) -> ProfileMutationResult`.
- Produces: `ProfileMutationService.grant_gold(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult`.
- Produces: `ProfileMutationService.grant_passive_points(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult`.
- Produces: `ProfileMutationService.complete_prologue(profile_id: String, transaction_id: String, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult`.

- [ ] **Step 1: Write failing idempotency tests**

Create `tests/unit/test_profile_mutation_service.gd`:

```gdscript
extends RefCounted

const ROOT := "user://tests/profile_mutation"
const ID := "profile-12345678"

func run() -> Array[String]:
	var failures: Array[String] = []
	ProfileTestSupport.remove_tree(ROOT)
	var store := ProfileStore.new()
	TestAssertions.equal(store.save_profile(ProfileState.new_profile(ID, "Jacob", 1000), ROOT), "", "fixture saves", failures)
	var service := ProfileMutationService.new(store)
	var first := service.grant_gold(ID, "enemy-42-gold", 25, ROOT)
	var retry := service.grant_gold(ID, "enemy-42-gold", 25, ROOT)
	TestAssertions.truthy(first.ok() and not first.duplicate, "first mutation commits", failures)
	TestAssertions.truthy(retry.ok() and retry.duplicate, "retry reports prior commit", failures)
	TestAssertions.equal(store.load_profile(ID, ROOT).profile.gold, 25, "retry does not duplicate gold", failures)
	var prologue := service.complete_prologue(ID, "prologue-complete", ROOT)
	var prologue_retry := service.complete_prologue(ID, "prologue-complete", ROOT)
	TestAssertions.truthy(prologue.ok() and prologue_retry.duplicate, "prologue completion is idempotent", failures)
	var saved := store.load_profile(ID, ROOT).profile
	TestAssertions.equal(saved.prologue_state, ProfileState.PrologueState.COMPLETED, "prologue marks complete", failures)
	TestAssertions.equal(saved.passive_points_available, 1, "prologue awards exactly one point", failures)
	TestAssertions.truthy("party-forge-city-v1" in saved.discovered_trees, "prologue reveals City tree", failures)
	var invalid := service.grant_gold(ID, "", 25, ROOT)
	TestAssertions.truthy(not invalid.ok() and invalid.error.contains("transaction id"), "empty transaction id is rejected", failures)
	ProfileTestSupport.remove_tree(ROOT)
	return failures
```

- [ ] **Step 2: Verify RED**

Run the suite. Expected: mutation classes are missing.

- [ ] **Step 3: Implement the result and mutation boundary**

Create `profile_mutation_result.gd`:

```gdscript
class_name ProfileMutationResult
extends RefCounted

var profile: ProfileState
var error := ""
var duplicate := false

func ok() -> bool:
	return profile != null and error.is_empty()
```

Create `profile_mutation_service.gd`:

```gdscript
class_name ProfileMutationService
extends RefCounted

var _store: ProfileStore

func _init(store: ProfileStore = null) -> void:
	_store = store if store != null else ProfileStore.new()

func apply(profile_id: String, transaction_id: String, mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	if transaction_id.strip_edges().is_empty():
		result.error = "PROFILE_MUTATION_ERROR profile=%s reason=transaction id is required" % profile_id
		return result
	if not mutate.is_valid():
		result.error = "PROFILE_MUTATION_ERROR profile=%s transaction=%s reason=mutation is missing" % [profile_id, transaction_id]
		return result
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		result.error = loaded.error
		return result
	if loaded.profile.applied_transactions.has(transaction_id):
		result.profile = loaded.profile.copy()
		result.duplicate = true
		return result
	var working := loaded.profile.copy()
	var mutation_error := str(mutate.call(working))
	if not mutation_error.is_empty():
		result.error = mutation_error
		return result
	working.normalize()
	var validation := ProfileCodec.validate_profile(working)
	if not validation.is_empty():
		result.error = validation
		return result
	var timestamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	working.applied_transactions[transaction_id] = timestamp
	working.updated_at_unix = maxi(working.created_at_unix, timestamp)
	var save_error := _store.save_profile(working, root)
	if not save_error.is_empty():
		result.error = save_error
		return result
	result.profile = working.copy()
	return result

func grant_gold(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=gold amount must be positive"
		profile.gold += amount
		return ""
	, root)

func grant_passive_points(profile_id: String, transaction_id: String, amount: int, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if amount <= 0:
			return "PROFILE_MUTATION_ERROR reason=passive point amount must be positive"
		profile.passive_points_available += amount
		profile.passive_points_lifetime_earned += amount
		return ""
	, root)

func complete_prologue(profile_id: String, transaction_id: String, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
	return apply(profile_id, transaction_id, func(profile: ProfileState) -> String:
		if profile.prologue_state == ProfileState.PrologueState.COMPLETED:
			return "PROFILE_MUTATION_ERROR reason=prologue already completed with different transaction"
		profile.prologue_state = ProfileState.PrologueState.COMPLETED
		profile.passive_points_available += 1
		profile.passive_points_lifetime_earned += 1
		if "city-heart" not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append("city-heart")
		if "party-forge-city-v1" not in profile.discovered_trees:
			profile.discovered_trees.append("party-forge-city-v1")
		return ""
	, root)
```

- [ ] **Step 4: Add failed-save immutability coverage**

Extend the test with a `ProfileStore` backed by a failing `AtomicJsonStore`. Require the mutation to return an error and a fresh load through the good store to retain the old gold and omit the transaction ID.

- [ ] **Step 5: Verify GREEN and commit**

Run the standard verification commands.

```powershell
git add scripts/profile/profile_mutation_result.gd scripts/profile/profile_mutation_service.gd tests/unit/test_profile_mutation_service.gd
git commit -m "feat: add idempotent profile mutations"
```

**Review checkpoint:** inspect every value-bearing helper. No helper may write a profile directly or omit the transaction ID.

---

### Task 5: Profiles Settings tab

**Files:**
- Create: `scripts/ui/settings/profiles_settings_page.gd`
- Create: `scenes/ui/settings/profiles_settings_page.tscn`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `scenes/ui/settings/settings_screen.tscn`
- Modify: `tests/unit/test_settings_screen.gd`
- Test: `tests/unit/test_profiles_settings_page.gd`

**Interfaces:**
- Consumes: `ProfileManager.profiles()`, `active_profile()`, `create_profile()`, and `select_profile()`.
- Produces: `ProfilesSettingsPage.bind(manager: ProfileManager) -> void`.
- Produces: `ProfilesSettingsPage.refresh() -> void`.
- Produces: `ProfilesSettingsPage.initial_focus() -> Control`.
- Produces signal: `profile_action_failed(message: String)`.
- Extends: `SettingsScreen.configure(store: PartyForgeSettingsStore, settings: PartyForgeSettings, profile_manager: ProfileManager = null) -> void`.
- Produces: `SettingsScreen.open_profiles(return_focus: Control = null) -> void`.

- [ ] **Step 1: Write failing scene and interaction tests**

Create `tests/unit/test_profiles_settings_page.gd`:

```gdscript
extends RefCounted

const ROOT := "user://tests/profile_settings_page"

func run() -> Array[String]:
	var failures: Array[String] = []
	ProfileTestSupport.remove_tree(ROOT)
	var ids: Array[String] = ["profile-aaaaaaaa", "profile-bbbbbbbb"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(ROOT), "", "page fixture bootstraps", failures)
	var page := (load("res://scenes/ui/settings/profiles_settings_page.tscn") as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.bind(manager)
	var list := page.get_node("Layout/ProfileList") as ItemList
	var name := page.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var create := page.get_node("Layout/CreateRow/Create") as Button
	var activate := page.get_node("Layout/Activate") as Button
	var empty := page.get_node("Layout/EmptyState") as Label
	var status := page.get_node("Layout/Status") as Label
	TestAssertions.equal(empty.text, "Create a profile to begin playing.", "empty copy is approved", failures)
	TestAssertions.truthy(empty.visible, "empty state begins visible", failures)
	TestAssertions.equal(name.max_length, 32, "profile name is bounded", failures)
	TestAssertions.equal(page.initial_focus(), name, "empty page focuses name", failures)
	name.text = "Jacob"
	create.pressed.emit()
	TestAssertions.equal(list.item_count, 1, "create adds profile row", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Jacob", "created profile becomes active", failures)
	TestAssertions.equal(page.initial_focus(), list, "populated page focuses list", failures)
	name.text = " jacob "
	create.pressed.emit()
	TestAssertions.truthy(status.text.contains("already exists"), "duplicate name is explained", failures)
	name.text = "Guest"
	create.pressed.emit()
	TestAssertions.equal(list.item_count, 2, "second profile appears", failures)
	var jacob_index := _index_for_id(list, "profile-aaaaaaaa")
	list.select(jacob_index)
	activate.pressed.emit()
	TestAssertions.equal(manager.active_profile().profile_id, "profile-aaaaaaaa", "Activate switches selected profile", failures)
	for control: Control in [list, name, create, activate]:
		TestAssertions.truthy(control.focus_mode != Control.FOCUS_NONE, "%s is focusable" % control.name, failures)
		TestAssertions.truthy(not control.focus_next.is_empty() and not control.focus_previous.is_empty(), "%s has explicit focus neighbors" % control.name, failures)
	page.free()
	ProfileTestSupport.remove_tree(ROOT)
	return failures

func _index_for_id(list: ItemList, profile_id: String) -> int:
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == profile_id:
			return index
	return -1
```

Update `tests/unit/test_settings_screen.gd` expected order to:

```gdscript
var expected := ["Game Settings", "Controls", "Graphics", "Audio", "Profiles", "Additional Settings"]
```

Assert `open_profiles()` activates the Profiles tab and focuses its initial target.

- [ ] **Step 2: Verify RED**

Run the full suite. Expected: missing Profiles scene/tab and order mismatch.

- [ ] **Step 3: Build the responsive Profiles page**

Create `profiles_settings_page.tscn` with this node contract:

```text
Profiles (MarginContainer)
  Layout (VBoxContainer)
    Explanation (Label)
    EmptyState (Label)
    ProfileList (ItemList)
    CreateRow (HBoxContainer)
      ProfileName (LineEdit; max_length=32)
      Create (Button)
    Activate (Button)
    Status (Label)
```

Use anchors, containers, size flags, and `autowrap_mode`; do not use fixed screen positions. The list stores immutable profile IDs in item metadata.

Create `scripts/ui/settings/profiles_settings_page.gd`:

```gdscript
class_name ProfilesSettingsPage
extends MarginContainer

signal profile_action_failed(message: String)

var _manager: ProfileManager

func _ready() -> void:
	(get_node("Layout/CreateRow/Create") as Button).pressed.connect(_create_profile)
	(get_node("Layout/Activate") as Button).pressed.connect(_activate_profile)
	(get_node("Layout/ProfileList") as ItemList).item_activated.connect(func(_index: int) -> void: _activate_profile())
	refresh()

func bind(manager: ProfileManager) -> void:
	_manager = manager
	if _manager != null:
		if not _manager.profiles_changed.is_connected(refresh):
			_manager.profiles_changed.connect(refresh)
		if not _manager.active_profile_changed.is_connected(_on_active_profile_changed):
			_manager.active_profile_changed.connect(_on_active_profile_changed)
	refresh()

func refresh() -> void:
	var list := get_node("Layout/ProfileList") as ItemList
	var empty := get_node("Layout/EmptyState") as Label
	list.clear()
	var available: Array[ProfileState] = _manager.profiles() if _manager != null else []
	var active := _manager.active_profile() if _manager != null else null
	for profile: ProfileState in available:
		var index := list.add_item("%s%s" % [profile.display_name, "  [Active]" if active != null and active.profile_id == profile.profile_id else ""])
		list.set_item_metadata(index, profile.profile_id)
		if active != null and active.profile_id == profile.profile_id:
			list.select(index)
	empty.visible = available.is_empty()
	list.visible = not available.is_empty()
	(get_node("Layout/Activate") as Button).disabled = available.is_empty()

func initial_focus() -> Control:
	var list := get_node("Layout/ProfileList") as ItemList
	return list if list.visible and list.item_count > 0 else get_node("Layout/CreateRow/ProfileName") as LineEdit

func _create_profile() -> void:
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		return
	var name := get_node("Layout/CreateRow/ProfileName") as LineEdit
	var result := _manager.create_profile(name.text)
	if not result.ok():
		_show_error(_friendly_error(result.error), result.error)
		return
	name.clear()
	_clear_error()
	refresh()

func _activate_profile() -> void:
	var list := get_node("Layout/ProfileList") as ItemList
	var selected := list.get_selected_items()
	if _manager == null or selected.is_empty():
		_show_error("Choose a profile first.", "PROFILE_UI_ERROR reason=no profile selected")
		return
	var error := _manager.select_profile(str(list.get_item_metadata(selected[0])))
	if not error.is_empty():
		_show_error(_friendly_error(error), error)
		return
	_clear_error()
	refresh()

func _on_active_profile_changed(_profile: ProfileState) -> void:
	refresh()

func _friendly_error(error: String) -> String:
	if error.contains("name already exists"):
		return "That profile name already exists. Choose another name."
	if error.contains("1-32"):
		return "Profile names must contain 1 to 32 characters."
	return "The profile action could not be completed."

func _show_error(primary: String, technical: String) -> void:
	var status := get_node("Layout/Status") as Label
	status.text = primary
	status.tooltip_text = technical
	profile_action_failed.emit(technical)

func _clear_error() -> void:
	var status := get_node("Layout/Status") as Label
	status.text = ""
	status.tooltip_text = ""
```

- [ ] **Step 4: Integrate the page into Settings**

- Add the packed scene before Additional Settings in `settings_screen.tscn`.
- Add `_profile_manager: ProfileManager` to `SettingsScreen`.
- Extend `configure()` with the optional third argument and bind the page when non-null.
- Add `_profiles_page() -> ProfilesSettingsPage`.
- Add `open_profiles()` that calls `open()`, selects the Profiles tab by control identity rather than hard-coded index, and focuses the page.
- Keep all existing two-argument `configure()` callers valid.
- Keep Apply/Cancel semantics limited to machine settings; profile create/select commits immediately and says so in the Profiles explanation.

Use these exact script changes:

```gdscript
var _profile_manager: ProfileManager

func configure(store: PartyForgeSettingsStore, settings: PartyForgeSettings, profile_manager: ProfileManager = null) -> void:
	_store = store
	_current_settings = settings.copy() if settings != null else PartyForgeSettings.new()
	_draft = _current_settings.copy()
	_profile_manager = profile_manager
	_profiles_page().bind(_profile_manager)

func open_profiles(return_focus: Control = null) -> void:
	open(return_focus)
	var tabs := _tabs()
	for index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_control(index) == _profiles_page():
			tabs.current_tab = index
			break
	_focus_active_page()

func _profiles_page() -> ProfilesSettingsPage:
	return get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
```

Add this scene resource and instance:

```text
[ext_resource type="PackedScene" path="res://scenes/ui/settings/profiles_settings_page.tscn" id="4_profiles"]

[node name="Profiles" parent="Overlay/Frame/Layout/Tabs" instance=ExtResource("4_profiles")]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
```

- [ ] **Step 5: Verify GREEN and commit**

Run the standard verification commands.

```powershell
git add scripts/ui/settings/profiles_settings_page.gd scenes/ui/settings/profiles_settings_page.tscn scripts/ui/settings/settings_screen.gd scenes/ui/settings/settings_screen.tscn tests/unit/test_profiles_settings_page.gd tests/unit/test_settings_screen.gd
git commit -m "feat: add profile management settings"
```

---

### Task 6: Boot integration and active-profile run gate

**Files:**
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_combat_test_overrides.gd`
- Modify: `tests/unit/test_developer_mode_integration.gd`
- Modify: `tests/unit/test_feature_access_integration.gd`
- Modify: `tests/unit/test_final_review.gd`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Test: `tests/unit/test_profile_boot_integration.gd`

**Interfaces:**
- Consumes: `ProfileManager.bootstrap()`, `active_profile()`, and `SettingsScreen.configure(..., profile_manager)`.
- Produces: `PartyForgeMain.profile_manager: ProfileManager`.
- Produces: `PartyForgeMain.active_profile() -> ProfileState` returning a copy or null.
- Produces diagnostic: `PARTY_FORGE_RUN_PROFILE_REQUIRED`.

- [ ] **Step 1: Write failing boot-integration tests**

Create `tests/unit/test_profile_boot_integration.gd` with an injected test root seam:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := "user://tests/profile_boot"
	ProfileTestSupport.remove_tree(root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	TestAssertions.truthy(main.get("profile_manager") is ProfileManager, "main creates ProfileManager", failures)
	TestAssertions.equal(main.call("active_profile"), null, "fresh boot has no active profile", failures)
	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "run launch rejects missing profile", failures)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	TestAssertions.truthy(settings.is_open(), "missing profile opens Profiles Settings", failures)
	var created := (main.get("profile_manager") as ProfileManager).create_profile("Jacob", 1000)
	TestAssertions.truthy(created.ok(), "profile creates through boot manager", failures)
	TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "active profile permits existing arena launch", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()
	ProfileTestSupport.remove_tree(root)
	return failures
```

- [ ] **Step 2: Verify RED**

Run the full suite. Expected: `PartyForgeMain` lacks the profile seams and still launches without a profile.

- [ ] **Step 3: Integrate profile bootstrap without editing the scene**

Modify `scripts/game/main.gd`:

```gdscript
var profile_root := ProfileStore.DEFAULT_ROOT
var profile_manager: ProfileManager

func active_profile() -> ProfileState:
	return profile_manager.active_profile() if profile_manager != null else null
```

In `_ready()`, after loading machine settings and before wiring UI:

```gdscript
profile_manager = ProfileManager.new()
var profile_error := profile_manager.bootstrap(profile_root)
if not profile_error.is_empty():
	push_error(profile_error)
(get_node("SettingsScreen") as SettingsScreen).configure(settings_store, saved_settings, profile_manager)
```

Replace the existing two-argument Settings configure call rather than adding a second call.

At the start of `select_leader_class()`, after initialization but before mutating run state:

```gdscript
if profile_manager == null or profile_manager.active_profile() == null:
	push_error("PARTY_FORGE_RUN_PROFILE_REQUIRED")
	(get_node("SettingsScreen") as SettingsScreen).open_profiles(get_node_or_null("HUD/ClassSelection/Content/Actions/Settings") as Control)
	return false
```

- [ ] **Step 4: Update existing wiring characterizations**

Update every suite found by `rg -l 'select_leader_class' tests/unit`:

```text
tests/unit/test_combat_test_overrides.gd
tests/unit/test_developer_mode_integration.gd
tests/unit/test_feature_access_integration.gd
tests/unit/test_final_review.gd
tests/unit/test_level_up_targeting_ui.gd
tests/unit/test_main_wiring.gd
```

For each main-scene fixture, set a suite-specific `user://tests/<suite-name>-profiles` root before adding the scene to the tree or calling `_ready()`. After `_ready()`, create `Test Profile` through `(main.profile_manager as ProfileManager).create_profile()` before calling `select_leader_class()`. Clean up that exact root after freeing the main scene. Do not bypass the gate with a test-only production flag, and do not let tests read or write `user://profiles`.

Add assertions to `test_main_wiring.gd` that:

- Main exposes one ProfileManager.
- Settings receives the same manager.
- Creating/selecting a profile leaves current class selection and arena launch behavior unchanged.
- Developer Mode Unlock All does not create a profile or bypass the profile requirement.

- [ ] **Step 5: Verify GREEN and commit**

Run the standard verification commands.

```powershell
git add scripts/game/main.gd tests/unit/test_combat_test_overrides.gd tests/unit/test_developer_mode_integration.gd tests/unit/test_feature_access_integration.gd tests/unit/test_final_review.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_main_wiring.gd tests/unit/test_profile_boot_integration.gd
git commit -m "feat: require an active profile for runs"
```

**Approval checkpoint:** manually verify the current front end. A fresh test profile root must route to Profiles Settings; creating a profile must return control; Fighter must still start the existing arena.

---

### Task 7: Milestone verification and evidence handoff

**Files:**
- Create: `docs/verification/2026-08-01-profile-persistence-foundation.md`

**Interfaces:**
- Consumes all Plan 1 tasks.
- Produces a grep-friendly evidence record for the next passive-tree plan.

- [ ] **Step 1: Run clean import and the complete suite**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
$importLog = Join-Path $env:TEMP 'party-forge-profile-import.log'
$testLog = Join-Path $env:TEMP 'party-forge-profile-tests.log'
& $godot --headless --path $project --editor --quit-after 2 2>&1 | Tee-Object -FilePath $importLog
if ($LASTEXITCODE -ne 0) { throw "Godot import/parser check failed: $importLog" }
& $godot --headless --path $project --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath $testLog
if ($LASTEXITCODE -ne 0) { throw "Godot tests failed: $testLog" }
if (-not (Select-String -LiteralPath $testLog -Pattern 'TEST_SUMMARY: PASS' -Quiet)) { throw 'PASS summary missing' }
if (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR|TEST_FAILURE' -Quiet) { throw 'Unexpected script/test failure marker' }
git diff --check
```

- [ ] **Step 2: Run focused recovery and idempotency evidence**

Run the full suite a second time with a clean test root. Require the profile tests to leave no `user://tests/profile_*` artifacts. Record the exact PASS summary and the intentional recovery diagnostics, if any.

- [ ] **Step 3: Perform the manual approval matrix**

Using a disposable test profile root or a backed-up `user://profiles` directory:

1. Launch with no profiles; verify a run attempt opens Profiles Settings.
2. Create `Jacob`; verify it becomes active and persists after restart.
3. Create `Guest`; switch between both profiles.
4. Verify duplicate `jacob` is rejected without changing either profile.
5. Start Fighter and complete at least one ordinary arena interaction.
6. Enable Developer Mode and verify it does not create profile unlocks or gold.
7. Corrupt only a disposable profile primary after two saves; verify the previous generation is recovered and the corrupt primary is preserved for diagnosis.
8. Verify keyboard/mouse and controller focus through all six Settings tabs at 1920x1080, 2560x1440, and 3840x2160.

- [ ] **Step 4: Write the verification record**

Create `docs/verification/2026-08-01-profile-persistence-foundation.md` containing:

- Commit IDs for Tasks 1 through 6.
- Import exit code and log path.
- Test exit code and exact `TEST_SUMMARY` line.
- Manual matrix results with PASS, FAIL, or DEFERRED for every numbered item.
- Any intentional diagnostics.
- Final `git status --short`.
- Explicit confirmation that `scenes/game/main.tscn`, `assets/ui/currency/`, and unrelated user files were not overwritten.

- [ ] **Step 5: Commit evidence only after it is truthful**

```powershell
git add docs/verification/2026-08-01-profile-persistence-foundation.md
git commit -m "docs: verify profile persistence foundation"
```

Do not mark this plan complete while any required automated or manual gate is unverified. Report blocked or deferred checks explicitly.

## Plan 1 Completion Boundary

Plan 1 is complete when safe profiles can be created, selected, reloaded, recovered, and mutated idempotently; Settings exposes the Profiles tab; the current run cannot start without an active profile; and the existing arena remains playable after selection.

Plan 1 does not reveal the City tree, build the cinematic menu, or implement equipment. Those begin only after this milestone is approved.
