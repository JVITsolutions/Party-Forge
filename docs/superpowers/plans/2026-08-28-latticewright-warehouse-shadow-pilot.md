# Latticewright Warehouse Shadow Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Developer Mode-only, default-off observer that compares the checked-in `city.warehouse` snapshot decision with Party Forge's existing Warehouse rule without changing UI, authorization, navigation, profiles, or settings behavior.

**Architecture:** Extract the legacy Player Mode Warehouse rule into one pure policy used by the existing main-menu view model and a new sidecar comparator. The comparator loads only the Party Forge-owned normalized snapshot through the existing provider, evaluates only `city.warehouse`, compares access/visibility/destination dimensions, and emits a sanitized deduplicated diagnostic after the authoritative menu projection is presented.

**Tech Stack:** Godot 4.7.1, typed GDScript, existing headless unit/integration runners, Git worktrees, PowerShell.

## Global Constraints

- Execute in a new isolated Party Forge worktree created from the then-current `main`; do not implement directly in the shared main checkout.
- Preserve every existing worktree, branch, user file, and unrelated change.
- Do not modify the Latticewright repository, installed Latticewright 0.5.0, its user-data catalog, or any `.pstree`/`.pstree.json` authoring artifact.
- The checked-in normalized snapshot remains the only candidate input used by Party Forge runtime code.
- Shadow mode remains default-off and runs only when Developer Mode and `use_city_access_snapshot` are both enabled.
- Legacy Warehouse visibility, authorization, and navigation remain authoritative.
- Developer Mode continues opening Warehouse without `stash`.
- Evaluate only `city.warehouse`; the other six snapshot locations remain inert.
- Do not add a general destination router or dispatch candidate destination strings.
- Diagnostics are local-only, sanitized, allowlisted, deduplicated, and contain no profile IDs, display names, paths, or raw parser text.
- Candidate failures cannot change UI, routes, profiles, settings, snapshots, or authoring data.
- Do not push, merge, publish, reinstall, or clean up worktrees without separate approval.

## File Structure

- Create `scripts/world/access/warehouse_access_policy.gd`: pure authoritative Player Mode Warehouse rule.
- Create `scripts/world/access/city_access_shadow_comparison.gd`: read-only typed comparison value and structured marker formatting.
- Create `scripts/world/access/city_access_shadow_comparator.gd`: candidate gating, evaluation, dimension normalization, sanitization, and in-process deduplication.
- Modify `scripts/ui/main_menu/main_menu_view_model.gd`: consume `WarehouseAccessPolicy` while retaining the existing Developer Mode override.
- Modify `scripts/game/main.gd`: own one long-lived comparator and invoke it after presenting the authoritative menu projection.
- Create `tests/unit/test_warehouse_access_policy.gd`: policy RED/GREEN coverage and input immutability.
- Create `tests/unit/test_city_access_shadow_comparator.gd`: gating, dimension, failure, sanitizer, and deduplication coverage.
- Modify `tests/unit/test_main_menu_view_model.gd`: prove the policy extraction preserves existing projections.
- Modify `tests/unit/test_main_wiring.gd`: prove the sidecar runs without changing menu or route behavior.
- Modify `tests/integration/city_access_snapshot_runner.gd`: exercise the production snapshot through the comparator.
- Create `docs/verification/2026-08-28-latticewright-warehouse-shadow-pilot.md`: exact commit, commands, results, hashes, and retained boundaries.

---

### Task 1: Extract the authoritative Warehouse access policy

**Files:**
- Create: `scripts/world/access/warehouse_access_policy.gd`
- Create: `tests/unit/test_warehouse_access_policy.gd`
- Modify: `scripts/ui/main_menu/main_menu_view_model.gd:58-72`
- Modify: `tests/unit/test_main_menu_view_model.gd:187-203`

**Interfaces:**
- Consumes: `ProfileState.permanent_feature_unlocks: Array[String]`.
- Produces: `WarehouseAccessPolicy.State` and `static func resolve(profile: Variant) -> State`.
- Used by: `MainMenuViewModel.build(...)` and Task 2's comparator.

- [ ] **Step 1: Write the failing policy tests**

Create `tests/unit/test_warehouse_access_policy.gd` with these exact cases:

```gdscript
extends RefCounted

const POLICY_PATH := "res://scripts/world/access/warehouse_access_policy.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(FileAccess.file_exists(POLICY_PATH), "Warehouse access policy exists", failures)
	if not FileAccess.file_exists(POLICY_PATH):
		return failures
	var policy := load(POLICY_PATH)
	TestAssertions.truthy(policy != null, "Warehouse access policy loads", failures)
	if policy == null:
		return failures
	TestAssertions.equal(policy.resolve(null), 0, "null profile is blocked", failures)
	TestAssertions.equal(policy.resolve(RefCounted.new()), 0, "wrong profile type is blocked", failures)
	var profile := ProfileState.new_profile("warehouse-policy", "Warehouse Policy", 1)
	var before_locked := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 0, "profile without stash is blocked", failures)
	TestAssertions.equal(profile.to_dictionary(), before_locked, "locked policy evaluation does not mutate profile", failures)
	profile.permanent_feature_unlocks = ["equipment_inventory", "stash", "stash"]
	var before_unlocked := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 1, "profile with stash is available", failures)
	TestAssertions.equal(profile.to_dictionary(), before_unlocked, "unlocked policy evaluation does not mutate profile", failures)
	profile.permanent_feature_unlocks.clear()
	var before_cleared := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 0, "later input mutation does not leave cached access", failures)
	TestAssertions.equal(profile.to_dictionary(), before_cleared, "re-evaluation after input mutation remains read-only", failures)
	return failures
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_access_policy.gd
```

Expected: exit `1`; the suite reports `Warehouse access policy exists` as a failure because the production file is absent. Reject parse errors or unrelated suite failures as RED evidence.

- [ ] **Step 3: Implement the minimal pure policy**

Create `scripts/world/access/warehouse_access_policy.gd`:

```gdscript
class_name WarehouseAccessPolicy
extends RefCounted

enum State { BLOCKED, AVAILABLE }

static func resolve(profile: Variant) -> State:
	if not profile is ProfileState:
		return State.BLOCKED
	var typed_profile := profile as ProfileState
	return State.AVAILABLE if "stash" in typed_profile.permanent_feature_unlocks else State.BLOCKED
```

- [ ] **Step 4: Make `MainMenuViewModel` use the policy without changing behavior**

Keep `FeatureAccessPolicy` for Armoury only. Replace the Warehouse `FeatureAccessPolicy.resolve(...)` call with:

```gdscript
var warehouse_player_available := (
	WarehouseAccessPolicy.resolve(supplied_profile) == WarehouseAccessPolicy.State.AVAILABLE
)
result.warehouse_visible = developer_mode or warehouse_player_available
result.warehouse_enabled = result.warehouse_visible
result.warehouse_label = "Developer Warehouse Preview" if developer_mode and not warehouse_player_available else "Warehouse"
```

Update the policy constructor inputs to contain only `armoury` and `equipment_inventory`. Do not alter City tree or Armoury rules.

Extend `_test_armoury_and_warehouse_feature_access` to retain the existing locked, unlocked, and Developer preview assertions and add a source check that `MainMenuViewModel` calls `WarehouseAccessPolicy.resolve` and no longer calls `feature_policy.resolve(&"warehouse"...)`.

- [ ] **Step 5: Run focused GREEN verification**

Run:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_access_policy.gd tests/unit/test_main_menu_view_model.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`, with the locked/unlocked/Developer preview behavior unchanged.

- [ ] **Step 6: Commit Task 1**

```powershell
git add scripts/world/access/warehouse_access_policy.gd tests/unit/test_warehouse_access_policy.gd scripts/ui/main_menu/main_menu_view_model.gd tests/unit/test_main_menu_view_model.gd
git diff --cached --check
git commit -m "refactor: centralize Warehouse access policy"
```

Expected: one commit containing only the four Task 1 files.

---

### Task 2: Implement the typed shadow comparison and diagnostic boundary

**Files:**
- Create: `scripts/world/access/city_access_shadow_comparison.gd`
- Create: `scripts/world/access/city_access_shadow_comparator.gd`
- Create: `tests/unit/test_city_access_shadow_comparator.gd`

**Interfaces:**
- Consumes: `WarehouseAccessPolicy.resolve(profile)`, `CityAccessProvider.resolve(settings, profile)`, and `CityAccessEvaluator.evaluate(snapshot, profile, location_id)`.
- Produces: `func observe(settings: Variant, profile: Variant) -> Variant`, returning `null` when inactive or a `CityAccessShadowComparison` when active.
- Constructor: `CityAccessShadowComparator.new(provider: CityAccessProvider = null, evaluator: Callable = Callable(), emitter: Callable = Callable())`.
- Emitter signature: `func(marker: String, warning: bool) -> void`.

- [ ] **Step 1: Write failing comparator tests**

Create `tests/unit/test_city_access_shadow_comparator.gd`. Its `run()` must call four named cases:

```gdscript
func run() -> Array[String]:
	var failures: Array[String] = []
	_test_inactive_gates_and_reset(failures)
	_test_locked_and_unlocked_dimensions(failures)
	_test_failure_and_destination_sanitization(failures)
	_test_deduplication_and_input_immutability(failures)
	return failures
```

Use `CityAccessSnapshotLoader.load_path(CityAccessProvider.SNAPSHOT_PATH)` for real locked/unlocked coverage. Inject a provider loader that counts calls and an emitter that appends `[marker, warning]` to an array. Assert exact dimension enums and these exact semantic results:

```gdscript
# no stash
outcome = DIVERGED
access = MATCH
visibility = DIVERGED
destination = NOT_APPLICABLE
reason = &"visibility_hidden_vs_locked"

# stash present
outcome = MATCH
access = MATCH
visibility = MATCH
destination = MATCH
reason = &"all_dimensions_match"
```

For failure coverage, inject `CityAccessLoadResult.failure("raw fixture path must never escape")` and assert the marker contains `candidate_snapshot_load_failed` but contains neither `raw fixture` nor a path. Inject an evaluator returning `CityAccessProjection.new(&"city.warehouse", CityAccessProjection.State.AVAILABLE, &"visible", &"city.unexpected")` and assert destination divergence with `candidate_destination_unmapped`.

For gating, assert flag-off and Player Mode return `null`, do not call the provider, and do not emit. For deduplication, call the same active tuple twice and assert one emission; change the profile's `stash` state and assert a second emission; disable then re-enable and assert the current tuple emits again. Capture `profile.to_dictionary()` and `settings.copy()` field values before and after each call.

- [ ] **Step 2: Run the comparator test and verify RED**

Run:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_shadow_comparator.gd
```

Expected: exit `1` because the comparison and comparator scripts do not exist. Reject script errors from existing production files as valid RED evidence.

- [ ] **Step 3: Create the read-only comparison value**

Create `scripts/world/access/city_access_shadow_comparison.gd` with:

```gdscript
class_name CityAccessShadowComparison
extends RefCounted

enum Outcome { MATCH, DIVERGED, UNAVAILABLE }
enum Dimension { MATCH, DIVERGED, NOT_APPLICABLE, UNAVAILABLE }
enum AccessState { AVAILABLE, BLOCKED, UNAVAILABLE }

const LOCATION_ID := &"city.warehouse"

var _outcome: Outcome
var _access: Dimension
var _visibility: Dimension
var _destination: Dimension
var _legacy_access: AccessState
var _candidate_access: AccessState
var _reason: StringName

var outcome: Outcome:
	get: return _outcome
	set(_next): pass
var access: Dimension:
	get: return _access
	set(_next): pass
var visibility: Dimension:
	get: return _visibility
	set(_next): pass
var destination: Dimension:
	get: return _destination
	set(_next): pass
var legacy_access: AccessState:
	get: return _legacy_access
	set(_next): pass
var candidate_access: AccessState:
	get: return _candidate_access
	set(_next): pass
var reason: StringName:
	get: return _reason
	set(_next): pass

func _init(
	outcome_value: Outcome,
	access_value: Dimension,
	visibility_value: Dimension,
	destination_value: Dimension,
	legacy_access_value: AccessState,
	candidate_access_value: AccessState,
	reason_value: StringName,
) -> void:
	_outcome = outcome_value
	_access = access_value
	_visibility = visibility_value
	_destination = destination_value
	_legacy_access = legacy_access_value
	_candidate_access = candidate_access_value
	_reason = reason_value

func marker() -> String:
	return "PARTY_FORGE_CITY_ACCESS_SHADOW location=%s outcome=%s access=%s visibility=%s destination=%s legacy_access=%s candidate_access=%s reason=%s" % [
		LOCATION_ID,
		Outcome.keys()[outcome],
		Dimension.keys()[access],
		Dimension.keys()[visibility],
		Dimension.keys()[destination],
		AccessState.keys()[legacy_access],
		AccessState.keys()[candidate_access],
		reason,
	]
```

Keep all construction inside the comparator. Tests must attempt neither production-only setter bypasses nor a test-only API.

- [ ] **Step 4: Implement the comparator**

Create `scripts/world/access/city_access_shadow_comparator.gd` with these constants and public boundary:

```gdscript
class_name CityAccessShadowComparator
extends RefCounted

const LOCATION_ID := &"city.warehouse"
const EXPECTED_DESTINATION_ID := &"city.warehouse.interior"
const ALLOWED_PROVIDER_REASONS: Array[StringName] = [
	&"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid",
	&"candidate_snapshot_load_failed",
]

var _provider: CityAccessProvider
var _evaluator: Callable
var _emitter: Callable
var _last_marker := ""

func _init(provider: CityAccessProvider = null, evaluator: Callable = Callable(), emitter: Callable = Callable()) -> void:
	_provider = provider if provider != null else CityAccessProvider.new()
	_evaluator = evaluator if evaluator.is_valid() else Callable(CityAccessEvaluator, "evaluate")
	_emitter = emitter if emitter.is_valid() else Callable(self, "_emit_default")

func observe(settings: Variant, profile: Variant) -> Variant:
	if not _enabled(settings):
		_last_marker = ""
		return null
	if not profile is ProfileState:
		return _publish(_unavailable(&"candidate_profile_invalid"))
	var legacy_state := WarehouseAccessPolicy.resolve(profile)
	var provider_result := _provider.resolve(settings as PartyForgeSettings, profile as ProfileState)
	if provider_result.mode != CityAccessProviderResult.Mode.CANDIDATE or provider_result.snapshot == null:
		var reason := provider_result.diagnostic if provider_result.diagnostic in ALLOWED_PROVIDER_REASONS else &"candidate_provider_unavailable"
		return _publish(_unavailable(reason, legacy_state))
	var projection: Variant = _evaluator.call(provider_result.snapshot, profile, LOCATION_ID)
	if not projection is CityAccessProjection:
		return _publish(_unavailable(&"candidate_projection_invalid", legacy_state))
	var typed_projection := projection as CityAccessProjection
	if typed_projection.location_id != LOCATION_ID or typed_projection.reason_id in [&"invalid_input", &"unknown_location"]:
		return _publish(_unavailable(&"candidate_projection_invalid", legacy_state))
	return _publish(_compare(legacy_state, typed_projection))
```

Implement private `_enabled`, `_compare`, `_unavailable`, `_publish`, and `_emit_default` functions with these exact rules:

- `_enabled` accepts only valid `PartyForgeSettings` in `DEVELOPER_MODE` with `use_city_access_snapshot == true`.
- Legacy access is `AVAILABLE` only for `WarehouseAccessPolicy.State.AVAILABLE`; legacy visibility is the same boolean.
- Candidate `AVAILABLE` means access available and visible; `LOCKED` means access blocked and visible; valid `HIDDEN` means access blocked and hidden.
- Destination is compared only when both access states are available; it matches only `EXPECTED_DESTINATION_ID`.
- Any access mismatch selects reason `access_state_differs`.
- The known hidden-versus-locked case selects `visibility_hidden_vs_locked`.
- Any other visibility mismatch selects `visibility_state_differs`.
- Any destination mismatch selects `candidate_destination_unmapped`.
- Full parity selects `all_dimensions_match`.
- `_unavailable` marks all candidate dimensions unavailable while preserving the real legacy access state.
- `_publish` emits only when `comparison.marker()` differs from `_last_marker`, stores only that marker, and returns the comparison.
- `_emit_default` uses `print(marker)` for `MATCH`; otherwise it uses `push_warning(marker)`.

Do not accept a location parameter, route callable, scene path, raw reason, or arbitrary destination map.

- [ ] **Step 5: Run comparator GREEN and regression suites**

Run:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_access_policy.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_shadow_comparator.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. The test-captured emitter must prevent expected divergence warnings from becoming script-error failures.

- [ ] **Step 6: Commit Task 2**

```powershell
git add scripts/world/access/city_access_shadow_comparison.gd scripts/world/access/city_access_shadow_comparator.gd tests/unit/test_city_access_shadow_comparator.gd
git diff --cached --check
git commit -m "feat: compare Warehouse access shadow state"
```

---

### Task 3: Wire the observer after authoritative menu presentation

**Files:**
- Modify: `scripts/game/main.gd:63-65,1443-1451`
- Modify: `tests/unit/test_main_wiring.gd:153-218`

**Interfaces:**
- Consumes: `CityAccessShadowComparator.observe(saved_settings, profile)` from Task 2.
- Produces: one production-owned, replaceable `city_access_shadow_comparator` dependency retained for the lifetime of `Main`.

- [ ] **Step 1: Add a failing main-wiring test**

Extend `_test_storage_route_policy_and_shared_projection_wiring` or add `_test_warehouse_shadow_observer_is_sidecar` and call it from `run()`.

The test must:

1. Instantiate `res://scenes/game/main.tscn` with an isolated `profile_root` and settings path.
2. Create a profile with no `stash` and capture its dictionary.
3. Persist Developer Mode with `use_city_access_snapshot = true`.
4. Inject a `CityAccessShadowComparator` with the real checked-in snapshot provider and a capturing emitter by setting the production dependency property before `_ready()`.
5. Call `_ready()` and capture the resulting `MainMenuProjection`.
6. Assert exactly one marker reports access match, visibility divergence, and destination not applicable.
7. Assert the Warehouse menu buttons remain visible/enabled as Developer previews.
8. Assert the profile dictionary is unchanged.
9. Refresh the projection again and assert the emitter count remains one.
10. Persist Player Mode, refresh, assert no additional marker, and verify the locked Warehouse route remains hidden and blocked.

Expected RED: the production `Main` has no comparator dependency and no observation call, so the emitter remains empty.

- [ ] **Step 2: Run the main-wiring test and verify RED**

Run:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd
```

Expected: exit `1` only for the new missing-observation assertions.

- [ ] **Step 3: Add the production dependency and post-presentation call**

Add near the existing settings dependencies in `scripts/game/main.gd`:

```gdscript
var city_access_shadow_comparator := CityAccessShadowComparator.new()
```

Rewrite `_refresh_main_menu_projection` without changing its public signature:

```gdscript
func _refresh_main_menu_projection() -> void:
	var profile := profile_manager.active_profile() if profile_manager != null else null
	var projection := MainMenuViewModel.build(profile, saved_settings, _city_runtime_available())
	if not profile_bootstrap_error.is_empty():
		projection.status_text = "Some profile data needs attention. Open Settings > Profiles for details."
	(get_node("MainMenuScreen") as MainMenuScreen).present(projection)
	city_access_shadow_comparator.observe(saved_settings, profile)
```

The call must remain after `present(projection)`. Do not read the comparator result, add fields to `MainMenuProjection`, or change `_storage_route_allowed`.

- [ ] **Step 4: Run focused GREEN and direct-route regressions**

Run:

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_wiring.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. Existing direct locked/unlocked Warehouse route checks and Developer preview checks must remain green.

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/game/main.gd tests/unit/test_main_wiring.gd
git diff --cached --check
git commit -m "feat: observe Warehouse access shadow state"
```

---

### Task 4: Extend end-to-end acceptance and qualify the exact branch

**Files:**
- Modify: `tests/integration/city_access_snapshot_runner.gd`
- Create: `docs/verification/2026-08-28-latticewright-warehouse-shadow-pilot.md`

**Interfaces:**
- Consumes: the production importer output, provider, evaluator, Warehouse policy, comparator, main-menu projection, and existing format-1 rollback loader.
- Produces: one acceptance marker and an evidence document for an exact commit.

- [ ] **Step 1: Extend the dedicated integration runner**

Add a comparator phase after the existing seven-location evaluation and provider rollback assertions. It must use the real checked-in snapshot and capture diagnostics through an injected emitter.

Cover these exact profiles and results:

```gdscript
var locked_profile := ProfileState.new_profile("shadow-locked", "Shadow Locked", 1)
var unlocked_profile := ProfileState.new_profile("shadow-unlocked", "Shadow Unlocked", 2)
unlocked_profile.permanent_feature_unlocks = ["stash"]
```

- Locked: overall diverged, access match, visibility diverged, destination not applicable.
- Unlocked: overall/access/visibility/destination match.
- Repeated unlocked observation: no duplicate marker.
- Candidate failure: unavailable marker and unchanged profile bytes.
- Flag off: no candidate load and immediate legacy-only behavior.
- Developer preview: `MainMenuViewModel` remains visible/enabled without `stash`.
- Player Mode: existing Warehouse visibility and route authorization remain based only on `stash`.

Retain the existing final marker exactly:

```text
CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
```

Do not add a second success marker; failures continue to make the runner exit nonzero.

- [ ] **Step 2: Run the dedicated integration runner**

Run:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

Expected: exit `0` and exactly one `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` marker. Expected shadow divergence must be captured by the injected emitter rather than written as an uncaptured warning.

- [ ] **Step 3: Run the complete focused acceptance batch**

Run:

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_warehouse_access_policy.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_wiring.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 4: Replay the importer and verify immutable artifact hashes**

Run:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tools/import_latticewright_access_snapshot.gd -- --source res://design/progression/latticewright/party-forge-city-access.pstree.json
Get-FileHash -Algorithm SHA256 design/progression/latticewright/party-forge-city-access.pstree
Get-FileHash -Algorithm SHA256 design/progression/latticewright/party-forge-city-access.pstree.json
Get-FileHash -Algorithm SHA256 data/world/access/party-forge-city-access.snapshot.json
```

Expected importer marker:

```text
PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
```

Expected SHA-256 values:

- Authoring project: `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a`
- Runtime-v3 source: `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78`
- Canonical snapshot: `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55`

Expected staging/recovery files: zero.

- [ ] **Step 5: Run the complete Party Forge suite**

Run without overlapping Godot or other heavy verification processes:

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/test_runner.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS`; the discovered count must equal the execution baseline plus the two new unit-suite files in this plan. Record the exact printed count rather than copying the previous 230-suite baseline. Case-sensitive scans must find zero `FAIL`, `TestFailure`, `ScriptError`, `ParseError`, `FailedLoad`, or `NoLoader` markers. Expected negative-path `ERROR:` and `WARNING:` diagnostics are not failures when the runner exits `0` and the prohibited marker scan is empty.

- [ ] **Step 6: Commit the integration acceptance changes**

```powershell
git add tests/integration/city_access_snapshot_runner.gd
git diff --cached --check
git commit -m "test: qualify Warehouse access shadow pilot"
```

Record this exact commit as the tested implementation commit.

- [ ] **Step 7: Write the verification record**

Create `docs/verification/2026-08-28-latticewright-warehouse-shadow-pilot.md` containing:

- Exact branch and tested commit.
- Godot executable and version.
- Exact focused, integration, importer, and full-suite commands.
- Exit codes, durations, suite count, and success markers.
- Exact three artifact hashes and zero staging-file result.
- Captured locked/unlocked/failure shadow markers.
- Proof that main-menu and direct Warehouse route behavior stayed unchanged.
- Worktree status and `git diff --check` result.
- Explicit boundaries: default-off, Developer Mode-only, Warehouse-only, legacy authoritative, no push/merge/Latticewright modification.

Run a placeholder scan:

```powershell
rg -n 'TBD|TODO|FIXME|placeholder|pending evidence' docs/verification/2026-08-28-latticewright-warehouse-shadow-pilot.md
```

Expected: exit `1` with no matches.

- [ ] **Step 8: Commit the verification record and perform final checks**

```powershell
git add docs/verification/2026-08-28-latticewright-warehouse-shadow-pilot.md
git diff --cached --check
git commit -m "docs: verify Warehouse access shadow pilot"
git status --short
git diff --check main...HEAD
git log --oneline --decorate -6
```

Expected: clean feature worktree, no diff-check failures, and only the planned implementation/test/verification commits above the execution starting point.

## Execution Completion Gate

After all tasks pass, stop for user review. Report:

- Exact feature branch and HEAD.
- Tested implementation commit and documentation-only child commit.
- Focused, integration, importer, and full-suite results.
- Snapshot hashes and staging-file count.
- Any expected visibility divergence evidence.
- Confirmation that legacy behavior remained authoritative.
- Confirmation that nothing was merged, pushed, published, reinstalled, or cleaned up.

Do not make shadow data authoritative and do not merge to `main` without a new explicit approval.
