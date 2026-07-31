# Party Forge Developer Mode and Feature Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent Developer Mode settings, immutable per-run rules, generalized feature gates, safe party/God-Mode/enemy-density overrides, a controller-ready tabbed Settings screen, and a persistent developer-run HUD badge.

**Architecture:** A typed machine-wide settings model is persisted through a versioned store, then resolved once at run launch into an immutable `RunRulesSnapshot`. Narrow feature, capacity, and combat policies carry effective values to consumers; Settings UI never becomes a gameplay dependency. The current front-end owns the mutable settings draft, while the active run owns its snapshot.

**Tech Stack:** Godot 4.7.1, typed GDScript, `ConfigFile`, TSCN scenes, Godot InputMap, the existing `tests/test_runner.gd` harness, and the connected Godot editor for live verification.

## Global Constraints

- Work only in the isolated feature worktree; preserve the user's dirty `main` checkout.
- Do not modify `scripts/ui/hud.gd`, `scripts/game/game_run.gd`, `scripts/ui/run_result_panel.gd`, or `docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md`.
- Settings persist machine-wide at `user://party_forge_settings.cfg`; profiles and per-profile settings are outside this milestone.
- Run-affecting changes apply only when a new run starts.
- Party capacity accepts 1 through 24; production capacity remains 4.
- Enemy density accepts 0 through 1000 percent; 100 preserves current timing and 0 disables scheduled normal spawns.
- God Mode protects party members from damage below 1 health, preserves damage/healing feedback, and never protects enemies.
- Coming Soon content never becomes activatable, including with Unlock All Implemented Content.
- All nine current classes remain available in Player Simulation until profiles and progression exist.
- Game Settings, Graphics, and Audio are honest Coming Soon pages; Controls is read-only and InputMap-backed.
- The existing in-run pause-menu Settings control remains Coming Soon; only the current front end opens functional Settings.
- Use Godot containers, anchors, size flags, and stretch behavior; verify 1920x1080, 2560x1440, and 3840x2160.
- Preserve projectile tuning, current stat/class/combat/upgrade/ledger/pause foundations, GodotSteam, add-ons, and unrelated UID metadata.
- Use `apply_patch` for source and scene edits. Do not use a Godot scene save that rewrites unrelated resources.
- Every task follows RED, GREEN, full-suite verification, `git diff --check`, and a focused commit.
- Intentional negative-test `push_error` output is acceptable only when the runner exits 0 and prints `TEST_SUMMARY: PASS`.

## File and Responsibility Map

### Settings and run rules

- `scripts/settings/party_forge_settings.gd` - typed mutable saved values, defaults, copy, and normalization.
- `scripts/settings/party_forge_settings_store.gd` - versioned `ConfigFile` load/save and recovery diagnostics.
- `scripts/game/run_rules_snapshot.gd` - immutable effective values captured at run launch.
- `scripts/game/feature_access_policy.gd` - generalized development/progression access resolution.
- `scripts/game/party_capacity_policy.gd` - effective capacity and add-member checks.
- `scripts/game/combat_test_policy.gd` - party damage floor, enemy density, and developer summary.

### Settings presentation

- `scripts/ui/settings/settings_screen.gd` - modal lifecycle, tabs, draft/apply/cancel/reset, and bumper navigation.
- `scripts/ui/settings/controls_settings_page.gd` - InputMap action grouping and read-only binding rows.
- `scripts/ui/settings/input_binding_formatter.gd` - deterministic keyboard/mouse/controller event text.
- `scripts/ui/settings/additional_settings_page.gd` - typed Developer Mode controls and retained inactive values.
- `tools/configure_settings_inputs.gd` - reproducibly adds semantic Settings bumper actions.
- `scenes/ui/settings/settings_screen.tscn` - full-screen five-tab Settings composition.
- `scenes/ui/settings/controls_settings_page.tscn` - grouped, scrollable binding list.
- `scenes/ui/settings/additional_settings_page.tscn` - mode, toggles, sliders, and action controls.
- `scripts/ui/class_selection_panel.gd` - emits `settings_requested` and restores focus.
- `scenes/ui/hud.tscn` - adds the front-end Settings button only.
- `project.godot` - adds semantic Settings bumper actions.

### Runtime consumers

- `scripts/ui/ledger/ledger_feature_gate.gd` - adapts ledger page definitions to `FeatureAccessPolicy`.
- `scripts/ui/ledger/character_ledger.gd` - accepts a feature policy when rebuilding pages.
- `scripts/party/party_manager.gd` - owns the capacity policy and exposes `capacity()` / `can_recruit()`.
- `scripts/progression/upgrade_choice.gd` - validates recruit choices through `PartyManager.can_recruit()`.
- `scripts/progression/level_up_choice_service.gd` - generates recruits through the same boundary.
- `scripts/dev/combat_sandbox.gd` - displays effective capacity.
- `scripts/game/main.gd` - owns settings, creates snapshots, validates launch, and distributes policies.
- `scripts/combat/health_component.gd` - applies an injected damage floor.
- `scripts/characters/party_actor.gd` - configures party health from `CombatTestPolicy`.
- `scripts/party/party_actor_spawner.gd` - passes the combat policy to recruited actors.
- `scripts/game/spawn_director.gd` - density-adjusted scheduled spawns with a per-update bound.
- `scripts/ui/developer_mode_badge.gd` - read-only summary of the active snapshot.
- `scenes/ui/developer_mode_badge.tscn` - independent HUD layer that avoids unrelated `hud.gd` edits.
- `scenes/game/main.tscn` - instances Settings and the developer badge.

### Tests

- `tests/unit/test_party_forge_settings.gd`
- `tests/unit/test_run_rules_policies.gd`
- `tests/unit/test_settings_screen.gd`
- `tests/unit/test_controls_settings_page.gd`
- `tests/unit/test_feature_access_integration.gd`
- `tests/unit/test_party_capacity_policy.gd`
- `tests/unit/test_combat_test_overrides.gd`
- `tests/unit/test_developer_mode_integration.gd`
- `tests/unit/test_health_component.gd`
- `tests/unit/test_spawn_schedule.gd`
- `tests/unit/test_main_wiring.gd`
- `tests/unit/test_responsive_ui.gd`

---

### Task 1: Typed settings and versioned persistence

**Files:**
- Create: `scripts/settings/party_forge_settings.gd`
- Create: `scripts/settings/party_forge_settings_store.gd`
- Test: `tests/unit/test_party_forge_settings.gd`

**Interfaces:**
- Produces: `PartyForgeSettings.Mode { PLAYER_SIMULATION, DEVELOPER_MODE }`
- Produces: `PartyForgeSettings.copy() -> PartyForgeSettings`
- Produces: `PartyForgeSettings.normalize() -> void`
- Produces: `PartyForgeSettingsStore.new(promote_file: Callable = Callable())`; the injectable file-promotion boundary permits deterministic failure recovery tests.
- Produces: `PartyForgeSettingsStore.load_settings(path: String = DEFAULT_PATH) -> PartyForgeSettings`
- Produces: `PartyForgeSettingsStore.save_settings(settings: PartyForgeSettings, path: String = DEFAULT_PATH) -> String`; empty string means success.

- [ ] **Step 1: Write the failing persistence suite**

Create `tests/unit/test_party_forge_settings.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_defaults_and_normalization(failures)
	_test_round_trip_and_inactive_retention(failures)
	_test_missing_unknown_and_malformed_fields(failures)
	_test_failed_save_preserves_previous_file(failures)
	return failures

func _test_defaults_and_normalization(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	TestAssertions.equal(settings.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "settings default to Player Simulation", failures)
	TestAssertions.equal(settings.party_capacity_override, 4, "developer party cap defaults to four", failures)
	TestAssertions.equal(settings.enemy_density_percent, 100, "enemy density defaults to 100 percent", failures)
	settings.party_capacity_override = -50
	settings.enemy_density_percent = 5000
	settings.normalize()
	TestAssertions.equal(settings.party_capacity_override, 1, "party cap clamps to one", failures)
	TestAssertions.equal(settings.enemy_density_percent, 1000, "density clamps to 1000", failures)

func _test_round_trip_and_inactive_retention(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_test.cfg"
	var store := PartyForgeSettingsStore.new()
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	settings.unlock_all_implemented_content = true
	settings.god_mode = true
	settings.party_capacity_override = 17
	settings.enemy_density_percent = 650
	TestAssertions.equal(store.save_settings(settings, path), "", "valid settings save", failures)
	var loaded := store.load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "mode round trips", failures)
	TestAssertions.truthy(loaded.god_mode and loaded.unlock_all_implemented_content, "inactive developer values remain stored", failures)
	TestAssertions.equal(loaded.party_capacity_override, 17, "party cap round trips", failures)
	TestAssertions.equal(loaded.enemy_density_percent, 650, "density round trips", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_missing_unknown_and_malformed_fields(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_malformed_test.cfg"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[settings]\nmode=99\nparty_capacity_override=-3\nunknown_future_key=\"safe\"\n")
	file.close()
	var loaded := PartyForgeSettingsStore.new().load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "unknown mode fails closed", failures)
	TestAssertions.equal(loaded.party_capacity_override, 1, "loaded cap clamps", failures)
	TestAssertions.equal(loaded.enemy_density_percent, 100, "missing density uses default", failures)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[settings]\nmode=\"1\"\ngod_mode=\"true\"\n")
	file.close()
	loaded = PartyForgeSettingsStore.new().load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "wrong mode type cannot enable Developer Mode", failures)
	TestAssertions.truthy(not loaded.god_mode, "wrong Boolean type fails closed", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var future_path := "user://party_forge_settings_future_test.cfg"
	var future := ConfigFile.new()
	future.set_value("settings", "schema_version", 999)
	future.set_value("settings", "mode", PartyForgeSettings.Mode.DEVELOPER_MODE)
	future.save(future_path)
	TestAssertions.equal(PartyForgeSettingsStore.new().load_settings(future_path).mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "unsupported version cannot enable Developer Mode", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path))

func _test_failed_save_preserves_previous_file(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_preserve_test.cfg"
	var store := PartyForgeSettingsStore.new()
	var original := PartyForgeSettings.new()
	original.party_capacity_override = 8
	TestAssertions.equal(store.save_settings(original, path), "", "baseline save succeeds", failures)
	var failing_store := PartyForgeSettingsStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var changed := original.copy()
	changed.party_capacity_override = 24
	TestAssertions.truthy(not failing_store.save_settings(changed, path).is_empty(), "failed promotion reports failure", failures)
	TestAssertions.equal(store.load_settings(path).party_capacity_override, 8, "previous valid file is unchanged", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 2: Import and run the suite to verify RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
```

Expected: nonzero test exit or `TEST_SUMMARY: FAIL`; both settings classes are absent.

- [ ] **Step 3: Implement the typed model**

Create `scripts/settings/party_forge_settings.gd`:

```gdscript
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
```

- [ ] **Step 4: Implement defensive `ConfigFile` persistence**

Create `scripts/settings/party_forge_settings_store.gd` with `DEFAULT_PATH := "user://party_forge_settings.cfg"`, section `settings`, a temporary sibling file, and these exact keys:

```gdscript
class_name PartyForgeSettingsStore
extends RefCounted

const DEFAULT_PATH := "user://party_forge_settings.cfg"
const SECTION := "settings"
var _promote_file: Callable

func _init(promote_file: Callable = Callable()) -> void:
	_promote_file = promote_file

func load_settings(path: String = DEFAULT_PATH) -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	var config := ConfigFile.new()
	var load_error := config.load(path)
	if load_error == ERR_FILE_NOT_FOUND:
		return result
	if load_error != OK:
		push_error("PARTY_FORGE_SETTINGS_LOAD_ERROR path=%s code=%d" % [path, load_error])
		return result
	var version_value: Variant = config.get_value(SECTION, "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	var loaded_version := int(version_value) if typeof(version_value) == TYPE_INT else -1
	if loaded_version != PartyForgeSettings.SCHEMA_VERSION:
		push_error("PARTY_FORGE_SETTINGS_VERSION_ERROR path=%s version=%d supported=%d" % [path, loaded_version, PartyForgeSettings.SCHEMA_VERSION])
		return result
	result.schema_version = loaded_version
	var mode_value: Variant = config.get_value(SECTION, "mode", PartyForgeSettings.Mode.PLAYER_SIMULATION)
	result.mode = int(mode_value) if typeof(mode_value) == TYPE_INT else PartyForgeSettings.Mode.PLAYER_SIMULATION
	var unlock_value: Variant = config.get_value(SECTION, "unlock_all_implemented_content", false)
	result.unlock_all_implemented_content = bool(unlock_value) if typeof(unlock_value) == TYPE_BOOL else false
	var god_value: Variant = config.get_value(SECTION, "god_mode", false)
	result.god_mode = bool(god_value) if typeof(god_value) == TYPE_BOOL else false
	var capacity_value: Variant = config.get_value(SECTION, "party_capacity_override", 4)
	result.party_capacity_override = int(capacity_value) if typeof(capacity_value) == TYPE_INT else 4
	var density_value: Variant = config.get_value(SECTION, "enemy_density_percent", 100)
	result.enemy_density_percent = int(density_value) if typeof(density_value) == TYPE_INT else 100
	result.normalize()
	return result

func save_settings(settings: PartyForgeSettings, path: String = DEFAULT_PATH) -> String:
	if settings == null:
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s reason=settings is null" % path
	var normalized := settings.copy()
	normalized.normalize()
	var config := ConfigFile.new()
	config.set_value(SECTION, "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	config.set_value(SECTION, "mode", normalized.mode)
	config.set_value(SECTION, "unlock_all_implemented_content", normalized.unlock_all_implemented_content)
	config.set_value(SECTION, "god_mode", normalized.god_mode)
	config.set_value(SECTION, "party_capacity_override", normalized.party_capacity_override)
	config.set_value(SECTION, "enemy_density_percent", normalized.enemy_density_percent)
	var temporary := "%s.tmp" % path
	var backup := "%s.bak" % path
	var save_error := config.save(temporary)
	if save_error != OK:
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d" % [path, save_error]
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
		var backup_error := DirAccess.rename_absolute(absolute_target, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=backup" % [path, backup_error]
	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		if had_previous:
			DirAccess.rename_absolute(absolute_backup, absolute_target)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=promote" % [path, promote_error]
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
	return ""

func _promote(temporary: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
```

- [ ] **Step 5: Verify GREEN and commit**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
git add scripts/settings tests/unit/test_party_forge_settings.gd
git commit -m "feat: persist developer settings"
```

Expected: `TEST_SUMMARY: PASS`, diff check exit 0, and a focused commit.

---

### Task 2: Immutable run snapshot and policy boundaries

**Files:**
- Create: `scripts/game/run_rules_snapshot.gd`
- Create: `scripts/game/feature_access_policy.gd`
- Create: `scripts/game/party_capacity_policy.gd`
- Create: `scripts/game/combat_test_policy.gd`
- Test: `tests/unit/test_run_rules_policies.gd`

**Interfaces:**
- Produces: `RunRulesSnapshot.from_settings(settings: PartyForgeSettings) -> RunRulesSnapshot`
- Produces read-only methods: `developer_mode_active()`, `unlock_all_implemented_content()`, `god_mode()`, `party_capacity()`, `enemy_density_percent()`.
- Produces: `RunRulesSnapshot.feature_policy(known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> FeatureAccessPolicy`
- Produces: `RunRulesSnapshot.capacity_policy() -> PartyCapacityPolicy`
- Produces: `RunRulesSnapshot.combat_policy() -> CombatTestPolicy`
- Produces: `FeatureAccessPolicy.resolve(feature_id: StringName, development_state: int, unlock_id: StringName = &"") -> FeatureAccessPolicy.State`
- Produces: `PartyCapacityPolicy.can_add(current_count: int, additional_members: int = 1) -> bool`
- Produces: `CombatTestPolicy.minimum_party_health() -> float` and `summary_parts() -> PackedStringArray`.

- [ ] **Step 1: Write the failing policy suite**

Create a suite that proves neutralization and immutability:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var saved := PartyForgeSettings.new()
	saved.unlock_all_implemented_content = true
	saved.god_mode = true
	saved.party_capacity_override = 24
	saved.enemy_density_percent = 1000
	var player := RunRulesSnapshot.from_settings(saved)
	TestAssertions.truthy(not player.developer_mode_active(), "Player Simulation remains production mode", failures)
	TestAssertions.truthy(not player.god_mode(), "Player Simulation neutralizes God Mode", failures)
	TestAssertions.equal(player.party_capacity(), 4, "Player Simulation uses production cap", failures)
	TestAssertions.equal(player.enemy_density_percent(), 100, "Player Simulation uses normal density", failures)
	var missing := RunRulesSnapshot.from_settings(null)
	TestAssertions.truthy(not missing.developer_mode_active(), "missing settings fail safely to Player Simulation", failures)
	saved.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var developer := RunRulesSnapshot.from_settings(saved)
	saved.party_capacity_override = 1
	TestAssertions.equal(developer.party_capacity(), 24, "snapshot is unaffected by later settings mutation", failures)
	TestAssertions.equal(developer.combat_policy().minimum_party_health(), 1.0, "God Mode exposes one-health floor", failures)
	TestAssertions.truthy(developer.capacity_policy().can_add(23), "capacity allows slot 24", failures)
	TestAssertions.truthy(not developer.capacity_policy().can_add(24), "capacity rejects slot 25", failures)
	var gate := developer.feature_policy([&"equipment", &"preview", &"implemented"], [&"implemented_unlock"])
	TestAssertions.equal(gate.resolve(&"equipment", FeatureAccessPolicy.State.COMING_SOON), FeatureAccessPolicy.State.COMING_SOON, "Coming Soon never unlocks", failures)
	TestAssertions.equal(gate.resolve(&"preview", FeatureAccessPolicy.State.DEVELOPER_PREVIEW), FeatureAccessPolicy.State.AVAILABLE, "Developer Preview opens in Developer Mode", failures)
	TestAssertions.equal(gate.resolve(&"implemented", FeatureAccessPolicy.State.AVAILABLE, &"implemented_unlock"), FeatureAccessPolicy.State.AVAILABLE, "Unlock All bypasses progression", failures)
	TestAssertions.equal(gate.resolve(&"unknown", FeatureAccessPolicy.State.AVAILABLE), FeatureAccessPolicy.State.HIDDEN, "unknown feature fails closed", failures)
	return failures
```

- [ ] **Step 2: Run RED**

Run the import and full test commands from Task 1. Expected: new rule classes are missing.

- [ ] **Step 3: Implement immutable snapshot construction**

Create `scripts/game/run_rules_snapshot.gd` with private backing values, getter methods only, and copies returned for policy objects:

```gdscript
class_name RunRulesSnapshot
extends RefCounted

const PRODUCTION_PARTY_CAPACITY := 4

var _developer_mode_active := false
var _unlock_all := false
var _god_mode := false
var _party_capacity := PRODUCTION_PARTY_CAPACITY
var _enemy_density_percent := 100

static func from_settings(settings: PartyForgeSettings) -> RunRulesSnapshot:
	var result := RunRulesSnapshot.new()
	if settings == null:
		push_error("PARTY_FORGE_RUN_RULES_ERROR reason=settings snapshot source is missing")
	var normalized := settings.copy() if settings != null else PartyForgeSettings.new()
	normalized.normalize()
	result._developer_mode_active = normalized.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
	if result._developer_mode_active:
		result._unlock_all = normalized.unlock_all_implemented_content
		result._god_mode = normalized.god_mode
		result._party_capacity = normalized.party_capacity_override
		result._enemy_density_percent = normalized.enemy_density_percent
	return result

func developer_mode_active() -> bool: return _developer_mode_active
func unlock_all_implemented_content() -> bool: return _unlock_all
func god_mode() -> bool: return _god_mode
func party_capacity() -> int: return _party_capacity
func enemy_density_percent() -> int: return _enemy_density_percent
func feature_policy(known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> FeatureAccessPolicy:
	return FeatureAccessPolicy.new(_developer_mode_active, _unlock_all, known_features, known_unlocks, unlocked)
func capacity_policy() -> PartyCapacityPolicy: return PartyCapacityPolicy.new(_party_capacity)
func combat_policy() -> CombatTestPolicy: return CombatTestPolicy.new(_god_mode, _enemy_density_percent, _developer_mode_active, _unlock_all, _party_capacity)
```

- [ ] **Step 4: Implement the three narrow policies**

`FeatureAccessPolicy` defines `enum State { HIDDEN, COMING_SOON, DEVELOPER_PREVIEW, AVAILABLE }` and owns copied arrays of known feature IDs, known unlock IDs, and currently unlocked IDs. Unknown feature or unlock IDs deny with a grep-friendly diagnostic; Coming Soon stays Coming Soon; Developer Preview becomes Available only in Developer Mode; Available requires no unlock ID or a currently unlocked ID unless Unlock All is active. `PartyCapacityPolicy` clamps constructor input 1 through 24 and rejects negative counts or additions. `CombatTestPolicy` clamps density 0 through 1000, returns `1.0` only for active God Mode, and returns summary tokens in stable order: `UNLOCK ALL`, `GOD`, `PARTY N`, `ENEMIES N%` when non-default.

Create `scripts/game/feature_access_policy.gd`:

```gdscript
class_name FeatureAccessPolicy
extends RefCounted

enum State { HIDDEN, COMING_SOON, DEVELOPER_PREVIEW, AVAILABLE }

var _developer_mode := false
var _unlock_all := false
var _known_features: Array[StringName] = []
var _known_unlocks: Array[StringName] = []
var _unlocked: Array[StringName] = []

func _init(developer_mode: bool, unlock_all: bool, known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> void:
	_developer_mode = developer_mode
	_unlock_all = unlock_all
	_known_features = known_features.duplicate()
	_known_unlocks = known_unlocks.duplicate()
	_unlocked = unlocked.duplicate()

func resolve(feature_id: StringName, development_state: int, unlock_id: StringName = &"") -> State:
	if feature_id.is_empty() or feature_id not in _known_features:
		push_error("PARTY_FORGE_FEATURE_ACCESS_ERROR feature=%s reason=unknown feature" % feature_id)
		return State.HIDDEN
	if not unlock_id.is_empty() and unlock_id not in _known_unlocks:
		push_error("PARTY_FORGE_FEATURE_ACCESS_ERROR feature=%s unlock=%s reason=unknown unlock" % [feature_id, unlock_id])
		return State.HIDDEN
	match development_state:
		State.HIDDEN: return State.HIDDEN
		State.COMING_SOON: return State.COMING_SOON
		State.DEVELOPER_PREVIEW: return State.AVAILABLE if _developer_mode else State.HIDDEN
		State.AVAILABLE:
			return State.AVAILABLE if unlock_id.is_empty() or unlock_id in _unlocked or _unlock_all else State.HIDDEN
		_: return State.HIDDEN
```

Create `scripts/game/party_capacity_policy.gd`:

```gdscript
class_name PartyCapacityPolicy
extends RefCounted

var _capacity := 4

func _init(capacity: int) -> void:
	_capacity = clampi(capacity, PartyForgeSettings.MIN_PARTY_CAPACITY, PartyForgeSettings.MAX_PARTY_CAPACITY)

func capacity() -> int: return _capacity

func can_add(current_count: int, additional_members: int = 1) -> bool:
	return current_count >= 0 and additional_members > 0 and current_count + additional_members <= _capacity
```

Create `scripts/game/combat_test_policy.gd`:

```gdscript
class_name CombatTestPolicy
extends RefCounted

var _god_mode := false
var _density := 100
var _developer_mode := false
var _unlock_all := false
var _capacity := 4

func _init(god_mode: bool, density: int, developer_mode: bool, unlock_all: bool, capacity: int) -> void:
	_developer_mode = developer_mode
	_god_mode = god_mode and developer_mode
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
```

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, and `git diff --check`, then:

```powershell
git add scripts/game/run_rules_snapshot.gd scripts/game/feature_access_policy.gd scripts/game/party_capacity_policy.gd scripts/game/combat_test_policy.gd tests/unit/test_run_rules_policies.gd
git commit -m "feat: snapshot effective run rules"
```

---

### Task 3: Tabbed Settings shell and start-screen routing

**Files:**
- Create: `scripts/ui/settings/settings_screen.gd`
- Create: `scenes/ui/settings/settings_screen.tscn`
- Create: `tools/configure_settings_inputs.gd`
- Modify: `scripts/ui/class_selection_panel.gd`
- Modify: `scenes/ui/hud.tscn`
- Modify: `scenes/game/main.tscn`
- Modify: `project.godot`
- Test: `tests/unit/test_settings_screen.gd`
- Modify: `tests/unit/test_class_selection_panel.gd`

**Interfaces:**
- Produces: `ClassSelectionPanel.settings_requested`.
- Produces: `SettingsScreen.configure(store: PartyForgeSettingsStore, settings: PartyForgeSettings) -> void`.
- Produces: `SettingsScreen.open(return_focus: Control = null)`, `close()`, `is_open()`, and `current_settings() -> PartyForgeSettings`.
- Produces: `SettingsScreen.settings_applied(settings: PartyForgeSettings)`.

- [ ] **Step 1: Write failing shell and routing tests**

The suite instantiates the scene and asserts the exact tab contract:

```gdscript
var screen := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
var tabs := screen.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
var expected := ["Game Settings", "Controls", "Graphics", "Audio", "Additional Settings"]
var actual: Array[String] = []
for index: int in range(tabs.get_tab_count()): actual.append(tabs.get_tab_title(index))
TestAssertions.equal(actual, expected, "Settings tabs use approved order", failures)
TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Game Settings/Content/State").text, "Coming Soon", "Game Settings is honest about availability", failures)
TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Graphics/Content/State").text, "Coming Soon", "Graphics is honest about availability", failures)
TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Audio/Content/State").text, "Coming Soon", "Audio is honest about availability", failures)
```

Extend `test_class_selection_panel.gd` to press `Content/Actions/Settings` and assert one `settings_requested` emission.

- [ ] **Step 2: Run RED**

Expected: the Settings scene, button, and signal do not exist.

- [ ] **Step 3: Build the full-screen five-tab scene**

Create a `CanvasLayer` root with `SettingsScreen` script and this exact hierarchy:

```text
SettingsScreen
  Overlay (full-rect ColorRect, mouse filter STOP)
    Frame (PanelContainer, margins 48/36/-48/-36)
      Layout (VBoxContainer)
        Title (Label: Settings)
        Tabs (TabContainer)
          Game Settings/Content/State (Label: Coming Soon)
          Controls/Content/State (Label: Controls load from InputMap in Task 4)
          Graphics/Content/State (Label: Coming Soon)
          Audio/Content/State (Label: Coming Soon)
          Additional Settings/Content/State (Label: Developer controls are prepared in Task 5)
        NextRunNotice (Label)
        Status (Label)
```

Set the root to `PROCESS_MODE_ALWAYS`, hidden by default, and use expand/fill size flags on the frame, tab container, and tab contents.

- [ ] **Step 4: Implement modal and bumper behavior**

In `settings_screen.gd`, duplicate the supplied settings into `_draft`, show `Run-affecting changes apply when the next run starts.`, restore `_return_focus` on close, and handle `settings_previous_tab`, `settings_next_tab`, and `ui_cancel`. Add these project actions with controller left/right shoulder events. Do not reuse ledger-named actions.

Create and run `tools/configure_settings_inputs.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_set_action(&"settings_previous_tab", JoyButton.LEFT_SHOULDER)
	_set_action(&"settings_next_tab", JoyButton.RIGHT_SHOULDER)
	ProjectSettings.save()
	print("PARTY_FORGE_SETTINGS_INPUTS_OK")
	quit(0)

func _set_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": [event]})
```

Run:

```powershell
& $godot --headless --path $project --script res://tools/configure_settings_inputs.gd
```

Expected: exit 0, `PARTY_FORGE_SETTINGS_INPUTS_OK`, and both actions serialized in `project.godot`.

The tab cycle is:

```gdscript
func _cycle_tab(direction: int) -> void:
	var tabs := _tabs()
	tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
	_focus_active_page()
```

- [ ] **Step 5: Add start-screen Settings routing**

Add `signal settings_requested` and `_emit_settings_requested()` to `class_selection_panel.gd`. In `hud.tscn`, add `Content/Actions` as an `HBoxContainer` below the class grid and a focusable `Settings` button wired in `_ready()`. Keep all nine class buttons unchanged.

Instance `SettingsScreen` in `main.tscn` above the HUD and below run-only modal layers. Main wiring is completed in Task 5.

- [ ] **Step 6: Verify GREEN and commit**

Run import, full suite, and diff check, then:

```powershell
git add project.godot tools/configure_settings_inputs.gd scripts/ui/settings/settings_screen.gd scenes/ui/settings/settings_screen.tscn scripts/ui/class_selection_panel.gd scenes/ui/hud.tscn scenes/game/main.tscn tests/unit/test_settings_screen.gd tests/unit/test_class_selection_panel.gd
git commit -m "feat: add tabbed settings shell"
```

---

### Task 4: Read-only InputMap Controls page

**Files:**
- Create: `scripts/ui/settings/input_binding_formatter.gd`
- Create: `scripts/ui/settings/controls_settings_page.gd`
- Create: `scenes/ui/settings/controls_settings_page.tscn`
- Modify: `scenes/ui/settings/settings_screen.tscn`
- Test: `tests/unit/test_controls_settings_page.gd`

**Interfaces:**
- Produces: `InputBindingFormatter.event_text(event: InputEvent) -> String`.
- Produces: `InputBindingFormatter.events_for_device(events: Array[InputEvent], controller: bool) -> String`.
- Produces: `ControlsSettingsPage.refresh_bindings() -> void`.
- Produces row metadata: `action_id`, `keyboard_text`, `controller_text`, and `missing_binding`.

- [ ] **Step 1: Write failing formatter and page tests**

Test a key, mouse button, joypad button, joypad axis, and an action with no events. Then instantiate the page and assert rows exist for `move_left`, `pause_menu`, `character_ledger`, `settings_previous_tab`, and `settings_next_tab`. Assert the displayed event strings equal strings produced from `InputMap.action_get_events(action)` rather than copied constants.

Use this representative assertion:

```gdscript
var page := (load("res://scenes/ui/settings/controls_settings_page.tscn") as PackedScene).instantiate() as ControlsSettingsPage
page.refresh_bindings()
var pause_row := page.row_for(&"pause_menu")
TestAssertions.truthy(not pause_row.is_empty(), "Controls lists pause menu", failures)
TestAssertions.equal(String(pause_row.keyboard_text), InputBindingFormatter.events_for_device(InputMap.action_get_events(&"pause_menu"), false), "pause keyboard text comes from InputMap", failures)
TestAssertions.equal(String(pause_row.controller_text), InputBindingFormatter.events_for_device(InputMap.action_get_events(&"pause_menu"), true), "pause controller text comes from InputMap", failures)
```

- [ ] **Step 2: Run RED**

Expected: formatter and page classes are missing.

- [ ] **Step 3: Implement deterministic binding formatting**

`InputBindingFormatter.event_text()` uses `as_text()` for keys, maps mouse buttons to `Mouse <index>`, maps joypad buttons through `InputEventJoypadButton.as_text()`, and maps axes to `<axis text> +/-`. `events_for_device(events, controller)` filters joypad events versus keyboard/mouse events, deduplicates strings, joins with ` / `, and returns `Missing binding` when empty.

- [ ] **Step 4: Build the grouped scroll page**

Create a scrollable page with sections `Gameplay`, `Menus`, and `Character Ledger`. `ControlsSettingsPage.ACTION_GROUPS` contains stable action IDs and labels, while every binding value comes from InputMap. Each row is a three-column grid: action label, keyboard/mouse, controller. Missing sides receive `Missing binding` and a warning tooltip. A footer reads `Rebinding: Coming Soon`.

Implement `row_for(action_id) -> Dictionary` for presentation queries and tests; it returns a duplicate of stored read-only row data.

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, and diff check, then commit:

```powershell
git add scripts/ui/settings/input_binding_formatter.gd scripts/ui/settings/controls_settings_page.gd scenes/ui/settings/controls_settings_page.tscn scenes/ui/settings/settings_screen.tscn tests/unit/test_controls_settings_page.gd
git commit -m "feat: display current input bindings"
```

---

### Task 5: Functional Additional Settings and next-run snapshot wiring

**Files:**
- Create: `scripts/ui/settings/additional_settings_page.gd`
- Create: `scenes/ui/settings/additional_settings_page.tscn`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `scenes/ui/settings/settings_screen.tscn`
- Modify: `scripts/game/main.gd`
- Test: `tests/unit/test_settings_screen.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Produces: `AdditionalSettingsPage.bind(settings: PartyForgeSettings) -> void`.
- Produces: `AdditionalSettingsPage.write_to(settings: PartyForgeSettings) -> void`.
- Produces: `AdditionalSettingsPage.reset_developer_options() -> void`.
- Main owns `saved_settings`, `settings_store`, and `active_run_rules`.

- [ ] **Step 1: Extend tests for retained/inactive controls and apply timing**

Assert these exact node values and behavior:

```gdscript
page.bind(saved)
TestAssertions.truthy(page.get_node("Layout/UnlockAll").disabled, "Player Simulation disables Unlock All", failures)
TestAssertions.equal(int(page.get_node("Layout/PartyCapacity/Value").value), 17, "inactive party cap stays visible", failures)
page.get_node("Layout/Mode").selected = PartyForgeSettings.Mode.DEVELOPER_MODE
page.call("_on_mode_changed", PartyForgeSettings.Mode.DEVELOPER_MODE)
TestAssertions.truthy(not page.get_node("Layout/UnlockAll").disabled, "Developer Mode enables overrides", failures)
```

In `test_main_wiring.gd`, load settings with God Mode true but Player Simulation selected, select the fighter, and assert `active_run_rules.god_mode()` is false. Create a second main with Developer Mode and cap 9, start it, mutate `saved_settings.party_capacity_override` to 2, and assert the active snapshot remains 9.

- [ ] **Step 2: Run RED**

Expected: Additional Settings controls and main-owned snapshot are absent.

- [ ] **Step 3: Build and bind Additional Settings**

Create controls with these ranges and steps:

```text
Mode OptionButton: Player Simulation, Developer Mode
UnlockAll CheckButton
GodMode CheckButton
PartyCapacity HSlider: min 1, max 24, step 1
EnemyDensity HSlider: min 0, max 1000, step 10
ApplyAndReturn Button
Cancel Button
ResetDeveloperOptions Button
```

Mode changes call `_refresh_enabled_state()`. Override values remain visible when disabled. Slider value labels update to `N` and `N%`. Reset sets false, false, 4, and 100 in the draft controls without saving.

- [ ] **Step 4: Complete apply/cancel/reset persistence**

On open, `SettingsScreen` takes a fresh copy of the current saved settings. Apply asks the page to write into the draft, normalizes it, and calls the store. On non-empty error, keep the screen open and display the exact error. On success, replace the screen's current settings copy, emit `settings_applied(copy)`, and close. Cancel closes without modifying the current settings. Reset only updates the draft controls.

- [ ] **Step 5: Wire Settings and snapshot ownership in `PartyForgeMain`**

At `_ready()`, create the store, load once, configure the Settings screen, and connect `ClassSelectionPanel.settings_requested` to open it. Connect `settings_applied` to replace `saved_settings` only.

At the beginning of `select_leader_class()`, before configuring any runtime manager, execute:

```gdscript
active_run_rules = RunRulesSnapshot.from_settings(saved_settings)
party_manager.configure_capacity(active_run_rules.capacity_policy())
```

Validate the current starting-party size of exactly one leader against `active_run_rules.party_capacity()`. Because the supported minimum is one, this is always valid in this milestone. Keep the validation next to snapshot creation so a later multi-member start flow can replace the constant without silently deleting selections; do not create an unused pending-party model now.

- [ ] **Step 6: Verify GREEN and commit**

Run import, full suite, and diff check, then:

```powershell
git add scripts/ui/settings/additional_settings_page.gd scenes/ui/settings/additional_settings_page.tscn scripts/ui/settings/settings_screen.gd scenes/ui/settings/settings_screen.tscn scripts/game/main.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd
git commit -m "feat: apply developer rules on next run"
```

---

### Task 6: Generalized feature access and ledger adapter

**Files:**
- Modify: `scripts/ui/ledger/ledger_feature_gate.gd`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scripts/game/main.gd`
- Modify: `data/ui/ledger_pages/stats.tres`
- Modify: `data/ui/ledger_pages/current_upgrades.tres`
- Modify: `data/ui/ledger_pages/equipment_inventory.tres`
- Modify: `tests/unit/test_character_ledger_foundation.gd`
- Test: `tests/unit/test_feature_access_integration.gd`

**Interfaces:**
- Changes: `LedgerFeatureGate.new(policy: FeatureAccessPolicy, supported_features: Array[StringName] = [], supported_unlocks: Array[StringName] = [])`.
- Changes: `CharacterLedger.configure(..., feature_policy: FeatureAccessPolicy = null)`.

- [ ] **Step 1: Write failing feature-state integration tests**

Cover Hidden, Coming Soon, Developer Preview, and Available in Player Simulation, Developer Mode, and Unlock All. Include direct activation rejection. Keep Equipment and Inventory Coming Soon and assert it never instantiates a page scene.

```gdscript
var developer_settings := PartyForgeSettings.new()
developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
developer_settings.unlock_all_implemented_content = true
var policy := RunRulesSnapshot.from_settings(developer_settings).feature_policy([&"stats", &"current_upgrades", &"equipment_inventory"])
var gate := LedgerFeatureGate.new(policy, [&"equipment_inventory"])
var equipment := load("res://data/ui/ledger_pages/equipment_inventory.tres") as LedgerPageDefinition
TestAssertions.equal(gate.resolve(equipment), LedgerPageDefinition.State.COMING_SOON, "Unlock All cannot activate Equipment Coming Soon", failures)
```

- [ ] **Step 2: Run RED**

Expected: old Boolean gate constructor cannot consume the policy.

- [ ] **Step 3: Adapt ledger states to the generalized policy**

Give all three ledger definitions a stable `feature_id` equal to their page ID. `LedgerFeatureGate` validates known IDs as it does now, maps `LedgerPageDefinition.State` to the numerically matching `FeatureAccessPolicy.State`, calls `policy.resolve()`, and maps the result back. A null policy uses a Player Simulation policy whose known-feature list comes from the page catalog.

Store the supplied policy in `CharacterLedger`, use it in `_build_pages()`, and pass `active_run_rules.feature_policy([&"stats", &"current_upgrades", &"equipment_inventory"])` from main. Because `_wire_static_ui()` currently configures the ledger before a run snapshot exists, it uses a neutral Player Simulation policy; `select_leader_class()` reconfigures it with the active snapshot before `game_run.start_run()`. Direct tab activation still rejects Coming Soon.

- [ ] **Step 4: Verify GREEN and commit**

Run import, full suite, and diff check, then:

```powershell
git add scripts/ui/ledger/ledger_feature_gate.gd scripts/ui/ledger/character_ledger.gd scripts/game/main.gd data/ui/ledger_pages tests/unit/test_character_ledger_foundation.gd tests/unit/test_feature_access_integration.gd
git commit -m "feat: generalize feature access policy"
```

---

### Task 7: Effective party capacity across every consumer

**Files:**
- Modify: `scripts/party/party_manager.gd`
- Modify: `scripts/progression/upgrade_choice.gd`
- Modify: `scripts/progression/level_up_choice_service.gd`
- Modify: `scripts/dev/combat_sandbox.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_party_manager.gd`
- Modify: `tests/unit/test_upgrade_choices.gd`
- Modify: `tests/unit/test_combat_sandbox.gd`
- Test: `tests/unit/test_party_capacity_policy.gd`

**Interfaces:**
- Produces: `PartyManager.configure_capacity(policy: PartyCapacityPolicy) -> void`.
- Produces: `PartyManager.capacity() -> int`.
- Produces: `PartyManager.can_recruit(additional_members: int = 1) -> bool`.

- [ ] **Step 1: Write the failing cross-consumer capacity tests**

Create parties at capacities 1 and 24. Assert recruitment, recruit-choice validity, level-up recruit generation, sandbox label, and main health lookup use the effective cap. Preserve the existing production-cap test.

```gdscript
var party := PartyManager.new()
party.configure_capacity(PartyCapacityPolicy.new(24))
party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
for index: int in range(23):
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "developer capacity accepts member %d" % (index + 2), failures)
TestAssertions.equal(party.members.size(), 24, "party reaches developer ceiling", failures)
TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"fighter")), "member 25 is rejected", failures)
```

- [ ] **Step 2: Run RED**

Expected: `configure_capacity`, `capacity`, and `can_recruit` are missing.

- [ ] **Step 3: Centralize capacity in `PartyManager`**

Keep `MAX_PARTY_SIZE := 4` as the production default. Add `_capacity_policy := PartyCapacityPolicy.new(MAX_PARTY_SIZE)`. `configure_capacity(null)` restores production. `can_recruit()` delegates to policy with `members.size()`. `recruit()` uses `can_recruit()`.

- [ ] **Step 4: Replace every direct capacity comparison**

Replace direct `PartyManager.MAX_PARTY_SIZE` runtime comparisons in:

```text
UpgradeChoice.is_valid_for -> party.can_recruit()
LevelUpChoiceService.generate -> party.can_recruit()
CombatSandbox party label -> party.capacity()
PartyForgeMain._health_for_member -> remove the four-actor early break and require `party_manager.member_by_id(member_id)` before accepting an actor
```

When the combat sandbox is launched directly from the editor and `cap_override_allowed()` returns true, configure its manager with `PartyCapacityPolicy.new(24)` before initialization; ordinary game and headless sandbox behavior keep the production policy. Run `rg -n "MAX_PARTY_SIZE" scripts tests` and confirm remaining hits are only the constant, explicit production-default tests, or comments explaining the default. Add a HUD regression assertion that a 24-member party does not crash the existing four-entry summary; dynamic above-four HUD presentation is outside this milestone because the Character Ledger is the complete party view.

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, diff check, and the `rg` audit, then:

```powershell
git add scripts/party/party_manager.gd scripts/progression/upgrade_choice.gd scripts/progression/level_up_choice_service.gd scripts/dev/combat_sandbox.gd scripts/game/main.gd tests/unit/test_party_manager.gd tests/unit/test_upgrade_choices.gd tests/unit/test_combat_sandbox.gd tests/unit/test_party_capacity_policy.gd
git commit -m "feat: apply effective party capacity"
```

---

### Task 8: Party-only God Mode at the health boundary

**Files:**
- Modify: `scripts/combat/health_component.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/party/party_actor_spawner.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_health_component.gd`
- Test: `tests/unit/test_combat_test_overrides.gd`

**Interfaces:**
- Produces signal: `HealthComponent.damage_received(attempted_damage: float, health_removed: float)`.
- Produces: `HealthComponent.configure_damage_floor(minimum_health: float) -> void`.
- Produces: `PartyActor.configure_combat_policy(policy: CombatTestPolicy) -> void`.
- Changes: `PartyActorSpawner.initialize(..., combat_policy: CombatTestPolicy = null)`.

- [ ] **Step 1: Write failing God Mode boundary tests**

Test lethal damage, feedback signals, healing, explicit `kill()`, a normal party member, and an enemy:

```gdscript
var health := HealthComponent.new()
health.configure(100.0, true, 8.0, 0.5)
health.configure_damage_floor(1.0)
var changes := [0]
health.health_changed.connect(func(_current: float, _maximum: float) -> void: changes[0] += 1)
TestAssertions.equal(health.apply_damage(500.0), 99.0, "God Mode reports actual health removed", failures)
TestAssertions.equal(health.current_health, 1.0, "God Mode stops damage at one", failures)
TestAssertions.truthy(not health.is_dead and not health.is_downed, "God Mode avoids death and downing", failures)
TestAssertions.equal(changes[0], 1, "God Mode still emits damage feedback", failures)
var received := [0]
health.damage_received.connect(func(_attempted: float, _removed: float) -> void: received[0] += 1)
health.apply_damage(20.0)
TestAssertions.equal(received[0], 1, "repeated damage at one health still emits feedback", failures)
TestAssertions.equal(health.heal(20.0), 20.0, "healing remains functional", failures)
health.kill()
TestAssertions.truthy(health.is_dead, "explicit kill remains authoritative", failures)
```

- [ ] **Step 2: Run RED**

Expected: damage-floor and actor-policy methods are absent.

- [ ] **Step 3: Add an injected damage floor**

Add `_damage_floor := 0.0`; clamp `configure_damage_floor()` to `0.0...max_health`; in `apply_damage()` replace the zero clamp with `maxf(_damage_floor, current_health - final_damage)`. Emit `damage_received(final_damage, previous - current_health)` on every valid damage attempt, including repeated hits while already at the floor. Keep `kill()` unchanged. The existing death/down logic runs only when the resulting health is zero.

- [ ] **Step 4: Configure only party actors**

`PartyActor.configure_combat_policy()` stores a safe default policy, applies `minimum_party_health()` to its `HealthComponent`, and connects `damage_received` to the existing damage-flash behavior so a hit that removes zero health at the floor still flashes. Main calls it for the leader after ordinary `configure(member)` initializes health. `PartyActorSpawner` receives the same policy and applies it to every new companion after `configure(member)` and before combat begins. A missing policy explicitly resets the floor to zero. Enemy code receives no combat policy and remains at floor zero.

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, and diff check, then:

```powershell
git add scripts/combat/health_component.gd scripts/characters/party_actor.gd scripts/party/party_actor_spawner.gd scripts/game/main.gd tests/unit/test_health_component.gd tests/unit/test_combat_test_overrides.gd
git commit -m "feat: add party-only God Mode"
```

---

### Task 9: Enemy-density scheduling and frame-safety bound

**Files:**
- Modify: `scripts/game/spawn_director.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_spawn_schedule.gd`
- Modify: `tests/unit/test_combat_test_overrides.gd`

**Interfaces:**
- Changes: `SpawnDirector.configure(..., density_percent: int = 100)`.
- Changes: `SpawnDirector.advance_time(delta: float) -> int`; returns scheduled spawn attempts for the update.
- Produces: `SpawnDirector.MAX_SCHEDULED_SPAWNS_PER_UPDATE := 64`.

- [ ] **Step 1: Write failing 0/100/1000 density tests**

Use the same deterministic markers and combat catalog as existing spawn tests. Assert:

```gdscript
zero.configure(..., 0)
TestAssertions.equal(zero.advance_time(10.0), 0, "zero density disables scheduled normal spawns", failures)
TestAssertions.near(zero.elapsed_seconds, 10.0, 0.001, "zero density still advances schedule time", failures)
normal.configure(..., 100)
TestAssertions.equal(normal.advance_time(1.26), 2, "100 percent preserves baseline schedule including initial spawn", failures)
extreme.configure(..., 1000)
TestAssertions.equal(extreme.advance_time(30.0), SpawnDirector.MAX_SCHEDULED_SPAWNS_PER_UPDATE, "1000 percent is bounded per update", failures)
TestAssertions.truthy(extreme.spawn_cooldown > 0.0, "overflow debt resets to one effective interval", failures)
```

Also assert direct `spawn_enemy()` remains available at zero density and Forge Guardian add spawning through `scripts/enemies/forge_guardian.gd` does not consult density.

- [ ] **Step 2: Run RED**

Expected: configure has no density argument and `advance_time()` does not return attempts.

- [ ] **Step 3: Implement density-adjusted scheduling**

Clamp density 0 through 1000. For density above zero, calculate:

```gdscript
func _effective_interval(base_interval: float) -> float:
	return base_interval * 100.0 / float(_enemy_density_percent)
```

At zero, advance elapsed run time without scheduled spawns. Count scheduled spawn attempts in each `advance_time()` call. At 64, discard surplus catch-up debt for that update by setting cooldown to one current effective interval, advance the remaining clock, and return 64. Direct spawn and boss paths remain unchanged.

- [ ] **Step 4: Pass density from the active snapshot**

Append `active_run_rules.enemy_density_percent()` to main's `spawn_director.configure()` call. Existing tests and callers that omit the new final argument retain 100 percent behavior.

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, and diff check, then:

```powershell
git add scripts/game/spawn_director.gd scripts/game/main.gd tests/unit/test_spawn_schedule.gd tests/unit/test_combat_test_overrides.gd
git commit -m "feat: scale enemy spawn density safely"
```

---

### Task 10: Developer badge, responsive acceptance, and end-to-end verification

**Files:**
- Create: `scripts/ui/developer_mode_badge.gd`
- Create: `scenes/ui/developer_mode_badge.tscn`
- Modify: `scenes/game/main.tscn`
- Modify: `scripts/game/main.gd`
- Test: `tests/unit/test_developer_mode_integration.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_responsive_ui.gd`

**Interfaces:**
- Produces: `DeveloperModeBadge.configure(snapshot: RunRulesSnapshot) -> void`.
- Produces: `DeveloperModeBadge.summary_text() -> String`.

- [ ] **Step 1: Write failing badge and end-to-end tests**

Assert Player Simulation hides the badge, Developer Mode shows it, tokens use the policy's stable order, and later mutation of saved settings does not change the badge.

```gdscript
var settings := PartyForgeSettings.new()
settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
settings.god_mode = true
settings.party_capacity_override = 12
settings.enemy_density_percent = 500
var snapshot := RunRulesSnapshot.from_settings(settings)
var badge := (load("res://scenes/ui/developer_mode_badge.tscn") as PackedScene).instantiate() as DeveloperModeBadge
badge.configure(snapshot)
TestAssertions.truthy(badge.visible, "Developer Mode badge is visible", failures)
TestAssertions.equal(badge.summary_text(), "DEV MODE | GOD | PARTY 12 | ENEMIES 500%", "badge summarizes active overrides", failures)
```

- [ ] **Step 2: Extend responsive targets to the approved three resolutions**

Preserve the existing 720p regression while adding the three approved acceptance targets. Set `VIEWPORT_SIZES` in `test_responsive_ui.gd` to:

```gdscript
const VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
	Vector2(3840.0, 2160.0),
]
```

Assert the Settings frame, tab row, Controls scroll, Additional Settings actions, tooltips/status region, and developer badge are contained at all three sizes. Keep existing ledger and pause containment checks.

- [ ] **Step 3: Run RED**

Expected: badge scene is missing and Settings containment assertions fail until final layout wiring exists.

- [ ] **Step 4: Build the independent badge**

Create an always-processing `CanvasLayer` with a top-right `MarginContainer` and `Label`. `configure(null)` and Player Simulation hide it. Developer Mode shows `DEV MODE` plus `snapshot.combat_policy().summary_parts()`. The badge receives no store, settings model, or write callback.

- [ ] **Step 5: Wire and refine responsive containment**

Instance the badge above the normal HUD but below full-screen modal layers. Configure it immediately after `active_run_rules` is created. Adjust only Settings/badge container margins, size flags, autowrap, and scroll behavior needed for the three target tests; do not create resolution-specific hard-coded layouts.

- [ ] **Step 6: Run automated completion verification**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
rg -n "MAX_PARTY_SIZE" scripts tests
rg -n -i "TO[D]O|TB[D]|PLACEH[O]LDER|FIXME|XXX" scripts/settings scripts/game scripts/ui/settings tests/unit/test_*developer* tests/unit/test_*settings*
```

Expected: import exit 0; `TEST_SUMMARY: PASS`; diff check exit 0; no runtime capacity consumer bypasses `PartyManager.capacity()` / `can_recruit()`; no unfinished implementation markers.

- [ ] **Step 7: Run live acceptance in the connected editor**

For each of 1920x1080, 2560x1440, and 3840x2160:

1. Open Settings from class selection with mouse and controller.
2. Cycle all five tabs with controller bumpers.
3. Confirm Game, Graphics, and Audio say Coming Soon.
4. Confirm Controls reflects current keyboard and controller bindings and missing bindings visibly warn.
5. Save Developer Mode with Unlock All, God Mode, party cap 12, and density 500%.
6. Start a run and confirm `DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%` is visible without overlap.
7. Take lethal party damage and confirm health stops at 1 while damage feedback continues.
8. Confirm enemies still die and scheduled spawn pressure increases.
9. Return to the front end, select Player Simulation, leave developer values unchanged, start another run, and confirm no badge, production cap 4, normal mortality, and 100% density.
10. Confirm all nine existing classes remain selectable in Player Simulation.

Record exact pass/fail evidence and any known baseline-only warnings. A headless pass does not replace these live checks.

- [ ] **Step 8: Commit final integration**

```powershell
git add scripts/ui/developer_mode_badge.gd scenes/ui/developer_mode_badge.tscn scenes/game/main.tscn scripts/game/main.gd tests/unit/test_developer_mode_integration.gd tests/unit/test_main_wiring.gd tests/unit/test_responsive_ui.gd
git commit -m "feat: finish developer mode integration"
```

---

## Final Acceptance Gate

Before claiming the milestone complete, verify every item:

- The persisted file is versioned and corruption cannot enable Developer Mode.
- Player Simulation retains but neutralizes saved developer values.
- The active run and badge remain unchanged after saved settings mutate.
- Settings is available only from the current front end during this milestone.
- The five tabs use the approved order and controller navigation.
- Controls reads actual InputMap data and does not imply rebinding works.
- Coming Soon content never activates.
- Every party-cap consumer uses the effective policy; cap 1 and cap 24 pass.
- God Mode affects party damage only and explicit kill behavior remains authoritative.
- Density 0, 100, and 1000 pass; scheduled catch-up never exceeds 64 attempts in one update.
- Direct/scripted spawns and bosses retain their documented behavior.
- The badge is read-only, accurate, persistent during a developer run, and absent in Player Simulation.
- Automated and live layouts pass at 1920x1080, 2560x1440, and 3840x2160.
- Full test suite, import validation, diff check, controller smoke, and live mode comparison pass.
- The four protected user-edited files and all unrelated resources remain untouched.
