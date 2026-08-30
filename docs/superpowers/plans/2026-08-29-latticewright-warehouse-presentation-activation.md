# Latticewright Warehouse Presentation Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate the checked-in City access snapshot as a default-off Player Mode presentation source for one visible-but-locked Warehouse flow while retaining `WarehouseAccessPolicy` as the only route authority.

**Architecture:** Separate snapshot loading from consumer mode policy, then resolve one typed Party Forge-owned Warehouse presentation state before building the Main Menu. A dedicated dialog explains the lock and may enter the existing City tree route, while the central Warehouse dispatcher reloads authoritative state and rechecks `WarehouseAccessPolicy` before every open. Candidate failure restores legacy presentation and emits only sanitized, deduplicated local diagnostics.

**Tech Stack:** Godot 4.5.1/GDScript, `.tscn` UI scenes, Party Forge profile/settings stores, checked-in Party Forge City access snapshot, headless focused/unit/integration runners, PowerShell 7.

## Global Constraints

- Execute in an isolated worktree created with `superpowers:using-git-worktrees`; validate the true repository at `F:\Projects(root)\Game dev\Projects\party-forge`, current `main`, remote state, worktrees, and running Godot targets before edits.
- Start from the approved specification commit `9de5de8` or a reviewed descendant that still contains `docs/superpowers/specs/2026-08-29-latticewright-warehouse-presentation-activation-design.md` unchanged.
- Do not push, publish, merge, clean user-owned worktrees, or modify Latticewright without a separate approval.
- Latticewright remains replaceable: gameplay loads only `data/world/access/party-forge-city-access.snapshot.json`; no `.pstree`, runtime-v3, authoring project, importer, or arbitrary destination is read during gameplay.
- Scope is exactly `city.warehouse` and the comparison contract `city.warehouse.interior`; the other six City locations remain inert.
- `PartyForgeSettings.use_city_access_snapshot` remains schema-1 and defaults to `false`; no migration is added.
- `WarehouseAccessPolicy` remains the final Player Mode route authority. Candidate data may reveal a locked destination but may never grant authorization.
- Developer Mode retains unrestricted Warehouse preview and Developer-only shadow comparison.
- No profile/progression mutation, automatic passive-node allocation, destination registry, external telemetry, or persistent activation report.
- Use TDD for each behavior change: capture a focused RED caused only by the missing contract, implement minimally, then capture focused GREEN.
- A Godot run is accepted only when its process exits `0` and the terminal contains `TEST_SUMMARY: PASS` or the runner's exact PASS marker. Do not hard-code the final full-suite count.
- Expected negative-path warnings are acceptable only when captured/sanitized as designed and the runner exits `0`; reject unexpected `SCRIPT ERROR`, `TEST_FAILURE`, parse, load, or resource-loader errors.
- Preserve task-created visual evidence under ignored `.superpowers/`; commit only the dated verification record, not PNGs or logs.

## File Structure

### New production files

- `scripts/world/access/warehouse_presentation_result.gd` — typed Party Forge presentation state, outcome, reason, and sanitized marker formatting.
- `scripts/world/access/warehouse_presentation_resolver.gd` — pure legacy/candidate resolution for `city.warehouse` only.
- `scripts/world/access/warehouse_presentation_reporter.gd` — default-off, deduplicated local diagnostic publication.
- `scripts/ui/warehouse/warehouse_locked_dialog.gd` — locked guidance state, input handling, and focus restoration.
- `scenes/ui/warehouse/warehouse_locked_dialog.tscn` — Living Forge-styled modal composition.

### Modified production files

- `scripts/world/access/city_access_provider.gd` — load the checked-in snapshot whenever the existing flag is on; leave mode policy to consumers.
- `scripts/ui/main_menu/main_menu_projection.gd` — carry typed Warehouse presentation state.
- `scripts/ui/main_menu/main_menu_view_model.gd` — consume resolved state without file I/O.
- `scripts/ui/main_menu/main_menu_screen.gd` — render and expose the locked state as a focusable action.
- `scenes/ui/main_menu/main_menu_screen.tscn` — add non-color-only lock indicators to both existing Warehouse origins.
- `scripts/game/main.gd` — resolve presentation, publish diagnostics, recheck route authority, show the dialog, and reuse the City tree route.
- `scenes/game/main.tscn` — compose the new dialog.

### New tests

- `tests/unit/test_warehouse_presentation_resolver.gd`
- `tests/unit/test_warehouse_presentation_reporter.gd`
- `tests/unit/test_warehouse_locked_dialog.gd`

### Modified tests and evidence

- `tests/unit/test_city_access_provider.gd`
- `tests/unit/test_city_access_shadow_comparator.gd`
- `tests/unit/test_main_menu_view_model.gd`
- `tests/unit/test_main_menu_screen.gd`
- `tests/unit/test_main_wiring.gd`
- `tests/integration/city_access_snapshot_runner.gd`
- `tests/integration/main_menu_navigation_runner.gd`
- `tests/integration/main_menu_responsive_runner.gd`
- `docs/verification/2026-08-29-latticewright-warehouse-presentation-activation.md`

---

### Task 1: Resolve a bounded Player Mode Warehouse presentation

**Files:**
- Create: `scripts/world/access/warehouse_presentation_result.gd`
- Create: `scripts/world/access/warehouse_presentation_resolver.gd`
- Create: `tests/unit/test_warehouse_presentation_resolver.gd`
- Modify: `scripts/world/access/city_access_provider.gd`
- Modify: `tests/unit/test_city_access_provider.gd`
- Modify: `tests/unit/test_city_access_shadow_comparator.gd`

**Interfaces:**
- Consumes: `WarehouseAccessPolicy.resolve(profile: Variant) -> WarehouseAccessPolicy.State`, `CityAccessProvider.resolve(settings: PartyForgeSettings, profile: ProfileState) -> CityAccessProviderResult`, and `CityAccessEvaluator.evaluate(snapshot, profile, location_id) -> CityAccessProjection`.
- Produces: `WarehousePresentationResult.State`, `WarehousePresentationResult.Outcome`, `WarehousePresentationResult.marker() -> String`, and `WarehousePresentationResolver.resolve(settings, profile, legacy_state, provider_result) -> WarehousePresentationResult`.

- [ ] **Step 1: Write the failing provider and resolver tests**

Update the provider test so flag-on Player Mode loads the fixed snapshot rather than returning `candidate_requires_developer_mode`. Retain flag-off zero-load, invalid-loader, missing-snapshot, fixed-path, immutability, and forbidden-dependency assertions.

Create `test_warehouse_presentation_resolver.gd` with a table that asserts the exact state/outcome/reason matrix:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_activation_matrix(failures)
	_test_candidate_cannot_grant_or_remove_authority(failures)
	_test_candidate_failure_is_sanitized_legacy(failures)
	_test_inputs_are_not_mutated(failures)
	return failures

func _test_activation_matrix(failures: Array[String]) -> void:
	var locked := ProfileState.new_profile("presentation-locked", "Locked", 1)
	var unlocked := ProfileState.new_profile("presentation-unlocked", "Unlocked", 2)
	unlocked.permanent_feature_unlocks = ["stash"]
	var player := PartyForgeSettings.new()
	player.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	var flag_off := WarehousePresentationResolver.resolve(
		player, locked, WarehouseAccessPolicy.State.BLOCKED, CityAccessProviderResult.legacy()
	)
	TestAssertions.equal(flag_off.state, WarehousePresentationResult.State.HIDDEN, "flag-off locked profile uses legacy hidden state", failures)
	player.use_city_access_snapshot = true
	var candidate := CityAccessProviderResult.candidate(_snapshot(&"city.warehouse", &"city.warehouse.interior", CityAccessProjection.State.LOCKED))
	var locked_result := WarehousePresentationResolver.resolve(player, locked, WarehouseAccessPolicy.State.BLOCKED, candidate)
	TestAssertions.equal(locked_result.state, WarehousePresentationResult.State.LOCKED, "valid locked candidate is visible locked", failures)
	TestAssertions.equal(locked_result.outcome, WarehousePresentationResult.Outcome.CANDIDATE, "valid locked candidate records candidate outcome", failures)

func _snapshot(location_id: StringName, destination_id: StringName, state: CityAccessProjection.State) -> CityAccessSnapshot:
	var visible_when := [{"kind": "always", "value": ""}]
	var available_when := [{"kind": "always", "value": ""}]
	if state == CityAccessProjection.State.HIDDEN:
		visible_when = [{"kind": "prologue_state", "value": "completed"}]
	elif state == CityAccessProjection.State.LOCKED:
		available_when = [{"kind": "permanent_unlock", "value": "stash"}]
	var document := {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {
			"adapter": "latticewright-runtime-v3-city-access",
			"format": "latticewright-progression",
			"formatVersion": 3,
			"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		},
		"locations": [{
			"id": String(location_id),
			"destinationId": String(destination_id),
			"visibleWhen": visible_when,
			"availableWhen": available_when,
		}],
	}
	var loaded := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	return loaded.snapshot if loaded.ok() else null
```

The test fixture helper must build snapshots through `CityAccessSnapshotLoader.load_bytes`, not by mutating snapshot internals. Cover `HIDDEN`, `LOCKED`, and `AVAILABLE`, wrong location, wrong available destination, failed provider, invalid projection, Developer Mode bypass, and setting-off legacy behavior.

- [ ] **Step 2: Run focused tests and verify RED**

```powershell
$partyForgeGodot = 'F:\Projects(root)\Game dev\Engines\Godot_v4.5.1-stable_win64.exe'
& $partyForgeGodot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_warehouse_presentation_resolver.gd
```

Expected: exit `1`; the provider assertion reports that Player Mode still refuses the candidate and the new resolver suite fails to load because its production classes do not exist. Reject unrelated parse or existing-suite failures as RED evidence.

- [ ] **Step 3: Implement the typed result**

Create `warehouse_presentation_result.gd`:

```gdscript
class_name WarehousePresentationResult
extends RefCounted

enum State { HIDDEN, LOCKED, AVAILABLE }
enum Outcome { LEGACY, CANDIDATE, CANDIDATE_FAILED, DIVERGED }

const STATE_NAMES := [&"HIDDEN", &"LOCKED", &"AVAILABLE"]
const OUTCOME_NAMES := [&"LEGACY", &"CANDIDATE", &"CANDIDATE_FAILED", &"DIVERGED"]
const ALLOWED_REASONS: Array[StringName] = [
	&"legacy_gate", &"invalid_input", &"consumer_not_player_mode",
	&"candidate_provider_unavailable", &"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid", &"candidate_snapshot_load_failed",
	&"candidate_projection_invalid", &"candidate_destination_invalid",
	&"candidate_matches_authority", &"candidate_cannot_reduce_authority",
	&"candidate_hidden", &"candidate_locked", &"candidate_cannot_grant_authority",
	&"invalid_reason",
]

var state: State
var outcome: Outcome
var reason: StringName

func _init(state_value: State, outcome_value: Outcome, reason_value: StringName) -> void:
	state = state_value
	outcome = outcome_value
	reason = reason_value if reason_value in ALLOWED_REASONS else &"invalid_reason"

func copy() -> WarehousePresentationResult:
	return WarehousePresentationResult.new(state, outcome, reason)

func marker() -> String:
	var state_index := int(state) if int(state) >= 0 and int(state) < STATE_NAMES.size() else int(State.HIDDEN)
	var outcome_index := int(outcome) if int(outcome) >= 0 and int(outcome) < OUTCOME_NAMES.size() else int(Outcome.CANDIDATE_FAILED)
	var safe_reason := reason if reason in ALLOWED_REASONS else &"invalid_reason"
	return "PARTY_FORGE_WAREHOUSE_PRESENTATION outcome=%s state=%s reason=%s" % [
		OUTCOME_NAMES[outcome_index], STATE_NAMES[state_index], String(safe_reason),
	]
```

Only resolver-owned allowlisted `StringName` reasons should reach this constructor in production. The constructor and `marker()` both fail closed to `invalid_reason`, and the test must mutate public fields after construction to prove raw text and invalid enum integers still cannot escape through the marker.

- [ ] **Step 4: Implement the pure resolver**

Create `warehouse_presentation_resolver.gd` with these exact public constants and entry point:

```gdscript
class_name WarehousePresentationResolver
extends RefCounted

const LOCATION_ID := &"city.warehouse"
const EXPECTED_DESTINATION_ID := &"city.warehouse.interior"
const ALLOWED_PROVIDER_FAILURES: Array[StringName] = [
	&"candidate_snapshot_invalid",
	&"candidate_snapshot_loader_invalid",
	&"candidate_snapshot_load_failed",
]

static func resolve(
	settings: Variant,
	profile: Variant,
	legacy_state: WarehouseAccessPolicy.State,
	provider_result: Variant,
) -> WarehousePresentationResult:
	var legacy := _legacy(legacy_state, &"legacy_gate")
	if not settings is PartyForgeSettings or not profile is ProfileState:
		return _legacy(legacy_state, &"invalid_input")
	var typed_settings := settings as PartyForgeSettings
	if typed_settings.mode != PartyForgeSettings.Mode.PLAYER_SIMULATION:
		return _legacy(legacy_state, &"consumer_not_player_mode")
	if not typed_settings.use_city_access_snapshot:
		return legacy
	if not provider_result is CityAccessProviderResult:
		return _failed(legacy_state, &"candidate_provider_unavailable")
	var provider := provider_result as CityAccessProviderResult
	if provider.mode != CityAccessProviderResult.Mode.CANDIDATE or provider.snapshot == null:
		var provider_reason := provider.diagnostic if provider.diagnostic in ALLOWED_PROVIDER_FAILURES else &"candidate_provider_unavailable"
		return _failed(legacy_state, provider_reason)
	var projection: Variant = CityAccessEvaluator.evaluate(provider.snapshot, profile, LOCATION_ID)
	if not projection is CityAccessProjection:
		return _failed(legacy_state, &"candidate_projection_invalid")
	var typed := projection as CityAccessProjection
	if typed.location_id != LOCATION_ID or typed.reason_id in [&"invalid_input", &"unknown_location"]:
		return _failed(legacy_state, &"candidate_projection_invalid")
	if typed.state == CityAccessProjection.State.AVAILABLE and typed.destination_id != EXPECTED_DESTINATION_ID:
		return _failed(legacy_state, &"candidate_destination_invalid")
	if legacy_state == WarehouseAccessPolicy.State.AVAILABLE:
		return WarehousePresentationResult.new(
			WarehousePresentationResult.State.AVAILABLE,
			WarehousePresentationResult.Outcome.CANDIDATE if typed.state == CityAccessProjection.State.AVAILABLE else WarehousePresentationResult.Outcome.DIVERGED,
			&"candidate_matches_authority" if typed.state == CityAccessProjection.State.AVAILABLE else &"candidate_cannot_reduce_authority",
		)
	match typed.state:
		CityAccessProjection.State.HIDDEN:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.HIDDEN, WarehousePresentationResult.Outcome.CANDIDATE, &"candidate_hidden")
		CityAccessProjection.State.LOCKED:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.LOCKED, WarehousePresentationResult.Outcome.CANDIDATE, &"candidate_locked")
		CityAccessProjection.State.AVAILABLE:
			return WarehousePresentationResult.new(WarehousePresentationResult.State.LOCKED, WarehousePresentationResult.Outcome.DIVERGED, &"candidate_cannot_grant_authority")
	return _failed(legacy_state, &"candidate_projection_invalid")

static func _legacy(legacy_state: WarehouseAccessPolicy.State, reason: StringName) -> WarehousePresentationResult:
	var state := WarehousePresentationResult.State.AVAILABLE if legacy_state == WarehouseAccessPolicy.State.AVAILABLE else WarehousePresentationResult.State.HIDDEN
	return WarehousePresentationResult.new(state, WarehousePresentationResult.Outcome.LEGACY, reason)

static func _failed(legacy_state: WarehouseAccessPolicy.State, reason: StringName) -> WarehousePresentationResult:
	var result := _legacy(legacy_state, reason)
	result.outcome = WarehousePresentationResult.Outcome.CANDIDATE_FAILED
	return result
```

Do not add file access, a router, a scene dependency, or any location mapping beyond the two constants above.

- [ ] **Step 5: Move mode policy out of the provider**

In `CityAccessProvider.resolve`, retain invalid-settings and setting-off `LEGACY` results, remove the `candidate_requires_developer_mode` branch, and load the fixed snapshot in either valid mode when the flag is on:

```gdscript
func resolve(settings: PartyForgeSettings, _profile: ProfileState) -> CityAccessProviderResult:
	if settings == null:
		return CityAccessProviderResult.legacy(&"invalid_settings")
	if not settings.use_city_access_snapshot:
		return CityAccessProviderResult.legacy()
	var load_result: Variant = _snapshot_loader.call(SNAPSHOT_PATH)
	if not load_result is CityAccessLoadResult:
		return CityAccessProviderResult.candidate_failed(&"candidate_snapshot_loader_invalid")
	var typed_load_result := load_result as CityAccessLoadResult
	if not typed_load_result.ok() or typed_load_result.snapshot == null:
		return CityAccessProviderResult.candidate_failed(&"candidate_snapshot_load_failed")
	return CityAccessProviderResult.candidate(typed_load_result.snapshot)
```

In `test_city_access_shadow_comparator.gd`, retain and strengthen the proof that `_enabled` prevents all provider calls outside Developer Mode even though the provider itself can now load in Player Mode.

- [ ] **Step 6: Run focused tests and verify GREEN**

```powershell
& $partyForgeGodot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_access_policy.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_warehouse_presentation_resolver.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. Tests prove that flag-off performs zero snapshot loads, the shadow comparator remains Developer-only, Player Mode candidate loading is inert until consumed by the resolver, and candidate data cannot grant or remove policy authority.

- [ ] **Step 7: Commit Task 1**

```powershell
git add -- scripts/world/access/city_access_provider.gd scripts/world/access/warehouse_presentation_result.gd scripts/world/access/warehouse_presentation_resolver.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_warehouse_presentation_resolver.gd
git diff --cached --check
git commit -m "feat: resolve staged Warehouse presentation"
```

Expected: one commit containing only Task 1 files.

---

### Task 2: Carry and render the typed Main Menu locked state

**Files:**
- Modify: `scripts/ui/main_menu/main_menu_projection.gd`
- Modify: `scripts/ui/main_menu/main_menu_view_model.gd`
- Modify: `scripts/ui/main_menu/main_menu_screen.gd`
- Modify: `scenes/ui/main_menu/main_menu_screen.tscn`
- Modify: `tests/unit/test_main_menu_view_model.gd`
- Modify: `tests/unit/test_main_menu_screen.gd`

**Interfaces:**
- Consumes: `WarehousePresentationResult.State` from Task 1.
- Produces: `MainMenuViewModel.build(profile, settings, city_tree_available, warehouse_presentation_state = null) -> MainMenuProjection`, copied `warehouse_presentation_state`, and focusable locked Warehouse route origins.

- [ ] **Step 1: Write failing projection and screen tests**

Add assertions for all three states in Player Mode:

```gdscript
var hidden := MainMenuViewModel.build(profile, player_settings, true, WarehousePresentationResult.State.HIDDEN)
var locked := MainMenuViewModel.build(profile, player_settings, true, WarehousePresentationResult.State.LOCKED)
var available := MainMenuViewModel.build(unlocked_profile, player_settings, true, WarehousePresentationResult.State.AVAILABLE)
TestAssertions.truthy(not hidden.warehouse_visible and not hidden.warehouse_enabled, "hidden Warehouse has no menu action", failures)
TestAssertions.truthy(locked.warehouse_visible and locked.warehouse_enabled, "locked Warehouse remains selectable", failures)
TestAssertions.equal(locked.warehouse_presentation_state, WarehousePresentationResult.State.LOCKED, "locked state remains typed", failures)
TestAssertions.truthy(available.warehouse_visible and available.warehouse_enabled, "available Warehouse remains selectable", failures)
```

In the screen suite, present `LOCKED` and assert both `Warehouse` and `CityWarehouseHotspot` are visible, enabled, focusable, emit `ROUTE_WAREHOUSE`, retain their exact route origin, show a visible `LockBadge`, and expose accessibility text containing **Requires Stash Access**. Assert `HIDDEN` removes both origins from the focus loop and `AVAILABLE` hides both badges.

- [ ] **Step 2: Run focused tests and verify RED**

```powershell
& $partyForgeGodot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd
```

Expected: exit `1`; failures name the missing typed projection field, fourth build input, and lock badge nodes.

- [ ] **Step 3: Extend the projection and view model**

Add to `MainMenuProjection` and `copy()`:

```gdscript
var warehouse_presentation_state: WarehousePresentationResult.State = WarehousePresentationResult.State.HIDDEN

# copy()
result.warehouse_presentation_state = warehouse_presentation_state
```

Change the view-model signature to:

```gdscript
static func build(
	profile: Variant,
	settings: Variant,
	city_tree_available: Variant,
	warehouse_presentation_state: Variant = null,
) -> MainMenuProjection:
```

After resolving the existing `warehouse_player_available`, normalize the fourth input with an explicit enum membership check. Invalid or omitted input preserves current legacy behavior. Developer Mode always projects available preview; Player Mode consumes the typed state:

```gdscript
var resolved_warehouse_state := _warehouse_state(warehouse_presentation_state, warehouse_player_available)
if developer_mode:
	resolved_warehouse_state = WarehousePresentationResult.State.AVAILABLE
result.warehouse_presentation_state = resolved_warehouse_state
result.warehouse_visible = resolved_warehouse_state != WarehousePresentationResult.State.HIDDEN
result.warehouse_enabled = result.warehouse_visible
result.warehouse_label = "Developer Warehouse Preview" if developer_mode and not warehouse_player_available else "Warehouse"

static func _warehouse_state(value: Variant, legacy_available: bool) -> WarehousePresentationResult.State:
	if typeof(value) == TYPE_INT and int(value) in [
		WarehousePresentationResult.State.HIDDEN,
		WarehousePresentationResult.State.LOCKED,
		WarehousePresentationResult.State.AVAILABLE,
	]:
		return int(value) as WarehousePresentationResult.State
	return WarehousePresentationResult.State.AVAILABLE if legacy_available else WarehousePresentationResult.State.HIDDEN
```

- [ ] **Step 4: Add lock indicators and screen presentation**

Under both existing scene buttons, add a non-interactive `Label` named `LockBadge` with text `LOCKED`, brass/ember contrast, and `mouse_filter = 2`. Keep it hidden by default.

In `MainMenuScreen._apply_projection`, configure both Warehouse actions through one helper:

```gdscript
func _configure_warehouse_action(button: Button, label: String, badge: Label) -> void:
	var state := _projection.warehouse_presentation_state
	var visible_state := state != WarehousePresentationResult.State.HIDDEN
	_configure_action(button, label, visible_state, visible_state)
	var locked := state == WarehousePresentationResult.State.LOCKED
	badge.visible = visible_state and locked
	button.accessibility_name = label
	button.accessibility_description = (
		"Warehouse locked. Requires Stash Access. Select for unlock guidance."
		if locked
		else "Open permanent Warehouse storage."
	)
```

Call it for `Warehouse/LockBadge` and `CityWarehouseHotspot/LockBadge`. The existing `_rebuild_focus_loop` must include locked actions because they are visible and enabled.

- [ ] **Step 5: Run focused tests and verify GREEN**

```powershell
& $partyForgeGodot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_access_policy.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. Existing Developer preview labels and legacy omitted-input behavior remain green.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- scripts/ui/main_menu/main_menu_projection.gd scripts/ui/main_menu/main_menu_view_model.gd scripts/ui/main_menu/main_menu_screen.gd scenes/ui/main_menu/main_menu_screen.tscn tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd
git diff --cached --check
git commit -m "feat: present locked Warehouse destination"
```

---

### Task 3: Build the Warehouse locked guidance dialog

**Files:**
- Create: `scripts/ui/warehouse/warehouse_locked_dialog.gd`
- Create: `scenes/ui/warehouse/warehouse_locked_dialog.tscn`
- Create: `tests/unit/test_warehouse_locked_dialog.gd`

**Interfaces:**
- Consumes: one `Guidance` enum and the exact Warehouse origin `Control`.
- Produces: `open(guidance: Guidance, return_focus: Control) -> bool`, `close(restore_focus := true)`, `is_open() -> bool`, and `city_tree_requested(return_focus: Control)`.

- [ ] **Step 1: Write the failing dialog contract test**

Load and instantiate the production scene. Assert the exact approved copy/action matrix:

```gdscript
dialog.open(WarehouseLockedDialog.Guidance.CITY_TREE_AVAILABLE, return_focus)
TestAssertions.equal(_title(dialog).text, "WAREHOUSE LOCKED", "available guidance title", failures)
TestAssertions.equal(_requirement(dialog).text, "Requires Stash Access", "available guidance requirement", failures)
TestAssertions.equal(_body(dialog).text, "Unlock Stash Access in the City tree to open permanent storage.", "available guidance body", failures)
TestAssertions.truthy(_city_tree(dialog).visible and not _city_tree(dialog).disabled, "available guidance exposes City tree CTA", failures)

dialog.open(WarehouseLockedDialog.Guidance.PROLOGUE_REQUIRED, return_focus)
TestAssertions.equal(_body(dialog).text, "Complete the prologue to access the City tree. Then unlock Stash Access to open the Warehouse.", "prologue guidance body", failures)
TestAssertions.truthy(not _city_tree(dialog).visible and _back(dialog).visible, "prologue guidance withholds dead CTA", failures)

dialog.open(WarehouseLockedDialog.Guidance.TEMPORARILY_UNAVAILABLE, return_focus)
TestAssertions.equal(_body(dialog).text, "City services are temporarily unavailable. Try again later.", "runtime failure is not mislabeled as progression", failures)
```

Also assert initial focus, two-control focus loop, one-control fallback loop, Escape/Back close, exact origin restoration, no signal on Back, one `city_tree_requested(origin)` signal on the CTA, and no profile/settings dependency in the dialog source.

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
& $partyForgeGodot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_locked_dialog.gd
```

Expected: exit `1` because the scene and script do not exist.

- [ ] **Step 3: Implement the dialog script**

Create `warehouse_locked_dialog.gd`:

```gdscript
class_name WarehouseLockedDialog
extends CanvasLayer

signal city_tree_requested(return_focus: Control)
signal closed

enum Guidance { CITY_TREE_AVAILABLE, PROLOGUE_REQUIRED, TEMPORARILY_UNAVAILABLE }

const TITLE := "WAREHOUSE LOCKED"
const REQUIREMENT := "Requires Stash Access"
const AVAILABLE_BODY := "Unlock Stash Access in the City tree to open permanent storage."
const PROLOGUE_BODY := "Complete the prologue to access the City tree. Then unlock Stash Access to open the Warehouse."
const UNAVAILABLE_BODY := "City services are temporarily unavailable. Try again later."

var _return_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view_city_tree().pressed.connect(_on_view_city_tree)
	_back().pressed.connect(_on_back)

func open(guidance: Guidance, return_focus: Control) -> bool:
	_return_focus = return_focus
	_title().text = TITLE
	_requirement().text = REQUIREMENT
	match guidance:
		Guidance.CITY_TREE_AVAILABLE:
			_body().text = AVAILABLE_BODY
			_view_city_tree().visible = true
			_view_city_tree().disabled = false
		Guidance.PROLOGUE_REQUIRED:
			_body().text = PROLOGUE_BODY
			_view_city_tree().visible = false
			_view_city_tree().disabled = true
		Guidance.TEMPORARILY_UNAVAILABLE:
			_body().text = UNAVAILABLE_BODY
			_view_city_tree().visible = false
			_view_city_tree().disabled = true
	visible = true
	_rebuild_focus_loop()
	_initial_focus().grab_focus()
	return true

func close(restore_focus := true) -> void:
	visible = false
	var target := _return_focus
	_return_focus = null
	if restore_focus and target != null and is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	closed.emit()

func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		close(true)
		get_viewport().set_input_as_handled()

func _on_view_city_tree() -> void:
	var target := _return_focus
	close(false)
	city_tree_requested.emit(target)

func _on_back() -> void:
	close(true)

func _initial_focus() -> Button:
	return _view_city_tree() if _view_city_tree().visible else _back()

func _rebuild_focus_loop() -> void:
	var controls: Array[Button] = [_back()]
	if _view_city_tree().visible:
		controls.push_front(_view_city_tree())
	for index: int in controls.size():
		var control := controls[index]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])

func _title() -> Label: return get_node("Overlay/Frame/Layout/Title") as Label
func _requirement() -> Label: return get_node("Overlay/Frame/Layout/Requirement") as Label
func _body() -> Label: return get_node("Overlay/Frame/Layout/Body") as Label
func _view_city_tree() -> Button: return get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
func _back() -> Button: return get_node("Overlay/Frame/Layout/Actions/Back") as Button
```

- [ ] **Step 4: Compose the Living Forge modal scene**

Create a `CanvasLayer` at layer `47`, hidden by default, with this exact node tree:

```text
WarehouseLockedDialog (CanvasLayer)
└── Overlay (ColorRect, full rect, modal mouse filter)
    └── Frame (PanelContainer, centered, minimum 640x360)
        └── Layout (VBoxContainer)
            ├── LockInsignia (Label, text "LOCKED")
            ├── Title (Label)
            ├── Requirement (Label)
            ├── Body (Label, autowrap word-smart)
            └── Actions (HBoxContainer)
                ├── ViewCityTree (Button, text "View City Tree")
                └── Back (Button, text "Back")
```

Use opaque charcoal/iron surfaces, a restrained brass border, ember requirement text, readable cream body text, minimum 46px button height, and no mandatory entrance animation. The lock insignia and `LOCKED` text must remain readable without color.

- [ ] **Step 5: Run focused tests and verify GREEN**

```powershell
& $partyForgeGodot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_locked_dialog.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)` with deterministic focus and exact copy.

- [ ] **Step 6: Commit Task 3**

```powershell
git add -- scripts/ui/warehouse/warehouse_locked_dialog.gd scenes/ui/warehouse/warehouse_locked_dialog.tscn tests/unit/test_warehouse_locked_dialog.gd
git diff --cached --check
git commit -m "feat: explain locked Warehouse access"
```

---

### Task 4: Wire activation, diagnostics, authoritative routing, and City tree return

**Files:**
- Create: `scripts/world/access/warehouse_presentation_reporter.gd`
- Create: `tests/unit/test_warehouse_presentation_reporter.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: resolver/result from Task 1, menu state from Task 2, dialog from Task 3, existing `MainMenuViewModel.ROUTE_CITY_TREE`, and `_open_city_passive_tree(developer_preview, origin, return_focus)`.
- Produces: `_resolve_warehouse_presentation(profile, settings)`, a central Warehouse route gate, dialog guidance selection, deduplicated diagnostics, and refreshed City tree return behavior.

- [ ] **Step 1: Write failing reporter and main-wiring tests**

The reporter test must prove flag-off or non-Player Mode clears deduplication without emitting, repeated candidate tuples emit once, changed tuples re-emit, and failed/diverged results warn while excluding raw strings and path separators.

Extend `test_main_wiring.gd` with isolated profile/settings roots and these assertions:

```gdscript
var projection := menu.projection()
TestAssertions.equal(projection.warehouse_presentation_state, WarehousePresentationResult.State.LOCKED, "flag-on Player Mode presents locked Warehouse", failures)
main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
var locked_dialog := main.get_node("WarehouseLockedDialog") as WarehouseLockedDialog
TestAssertions.truthy(locked_dialog.is_open() and not warehouse.is_open(), "blocked route opens guidance only", failures)

profile.permanent_feature_unlocks = ["stash"]
TestAssertions.equal(ProfileStore.new().save_profile(profile, root), "", "fixture persists Stash Access", failures)
main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_WAREHOUSE)
TestAssertions.truthy(warehouse.is_open() and not locked_dialog.is_open(), "fresh policy recheck opens newly authorized Warehouse", failures)
```

Also cover setting-off legacy hidden behavior, wrong/failed snapshot legacy fallback, stale cached Developer Mode versus persisted Player Mode, Developer preview, both Warehouse origins, exact dialog focus return, available/prologue/runtime-unavailable guidance, existing City tree route use, and return refresh after persisted `stash` allocation.

- [ ] **Step 2: Run focused tests and verify RED**

```powershell
& $partyForgeGodot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_presentation_reporter.gd tests/unit/test_main_wiring.gd
```

Expected: exit `1`; failures name the missing reporter, dialog composition, Player Mode resolved projection, and locked route behavior.

- [ ] **Step 3: Implement the diagnostic reporter**

Create `warehouse_presentation_reporter.gd`:

```gdscript
class_name WarehousePresentationReporter
extends RefCounted

var _emitter: Callable
var _last_marker := ""

func _init(emitter: Callable = Callable()) -> void:
	_emitter = emitter if emitter.is_valid() else Callable(self, "_emit_default")

func observe(settings: Variant, result: Variant) -> void:
	if (
		not settings is PartyForgeSettings
		or (settings as PartyForgeSettings).mode != PartyForgeSettings.Mode.PLAYER_SIMULATION
		or not (settings as PartyForgeSettings).use_city_access_snapshot
	):
		_last_marker = ""
		return
	if not result is WarehousePresentationResult:
		return
	var typed := result as WarehousePresentationResult
	var marker := typed.marker()
	if marker == _last_marker:
		return
	var warning := typed.outcome in [WarehousePresentationResult.Outcome.CANDIDATE_FAILED, WarehousePresentationResult.Outcome.DIVERGED]
	_emitter.call(marker, warning)
	_last_marker = marker

func _emit_default(marker: String, warning: bool) -> void:
	if warning:
		push_warning(marker)
	else:
		print(marker)
```

- [ ] **Step 4: Compose and connect the dialog**

Add `warehouse_locked_dialog.tscn` as a new external resource and root child in `scenes/game/main.tscn`. In `_wire_static_ui`, connect `city_tree_requested` to `_on_warehouse_locked_city_tree_requested`. Add the dialog to `_gameplay_input_blocked`, close it during front-end reset/profile switch, and never allow it to coexist with `WarehouseScreen`.

- [ ] **Step 5: Resolve and present authoritative state in Main**

Add injectable defaults:

```gdscript
var city_access_provider := CityAccessProvider.new()
var warehouse_presentation_reporter := WarehousePresentationReporter.new()
```

Add:

```gdscript
func _resolve_warehouse_presentation(profile: ProfileState, settings: PartyForgeSettings) -> WarehousePresentationResult:
	var legacy_state := WarehouseAccessPolicy.resolve(profile)
	var provider_result := CityAccessProviderResult.legacy()
	if settings != null and settings.mode == PartyForgeSettings.Mode.PLAYER_SIMULATION and settings.use_city_access_snapshot:
		provider_result = city_access_provider.resolve(settings, profile) if city_access_provider != null else CityAccessProviderResult.candidate_failed(&"candidate_provider_unavailable")
	return WarehousePresentationResolver.resolve(settings, profile, legacy_state, provider_result)
```

In `_refresh_main_menu_projection`, resolve before `MainMenuViewModel.build`, pass `presentation.state` as the fourth input, present the menu, report the activation tuple, then run the existing Developer-only shadow comparator. Do not reorder shadow observation ahead of authoritative presentation.

- [ ] **Step 6: Replace projection-based Warehouse authorization with the policy gate**

After reloading persisted settings in `_open_storage_route`, refresh the active profile before any Warehouse decision. Use this exact route-local sequence before the authorization block:

```gdscript
var profile := profile_manager.active_profile() if profile_manager != null else null
if route_id == MainMenuViewModel.ROUTE_WAREHOUSE and profile != null:
	var refresh_error := profile_manager.refresh_profile(profile.profile_id)
	if not refresh_error.is_empty():
		var failed_menu := get_node("MainMenuScreen") as MainMenuScreen
		failed_menu.open(failed_menu.route_origin())
		(failed_menu.get_node("Status") as Label).text = "Some profile data needs attention. Open Settings > Profiles for details."
		return
	profile = profile_manager.active_profile()
if profile == null:
	return
```

For Warehouse, then apply the policy gate:

```gdscript
var warehouse_authorized := (
	authoritative_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
	or WarehouseAccessPolicy.resolve(profile) == WarehouseAccessPolicy.State.AVAILABLE
)
if route_id == MainMenuViewModel.ROUTE_WAREHOUSE and not warehouse_authorized:
	var presentation := _resolve_warehouse_presentation(profile, authoritative_settings)
	if presentation.state == WarehousePresentationResult.State.LOCKED:
		var origin := menu.route_origin()
		if origin == null:
			origin = menu.get_node("Warehouse") as Control
		(get_node("WarehouseLockedDialog") as WarehouseLockedDialog).open(_warehouse_guidance(profile), origin)
	return
```

If authorized, continue through the existing `ProfileStorageProjection` and Warehouse open path. `_storage_route_allowed` must use `WarehouseAccessPolicy` plus the explicit Developer preview override for Warehouse; it must not infer authorization from `warehouse_visible` or `warehouse_enabled`.

Add:

```gdscript
func _warehouse_guidance(profile: ProfileState) -> WarehouseLockedDialog.Guidance:
	var durable_city_access := (
		profile != null
		and profile.prologue_state == ProfileState.PrologueState.COMPLETED
		and CITY_TREE_ID in profile.discovered_trees
	)
	if not durable_city_access:
		return WarehouseLockedDialog.Guidance.PROLOGUE_REQUIRED
	return WarehouseLockedDialog.Guidance.CITY_TREE_AVAILABLE if _city_runtime_available() else WarehouseLockedDialog.Guidance.TEMPORARILY_UNAVAILABLE

func _on_warehouse_locked_city_tree_requested(return_focus: Control) -> void:
	_open_city_passive_tree(false, CITY_ORIGIN_MAIN_MENU, return_focus)
```

The CTA therefore reuses the existing City route checks and never opens/configures `PassiveTreeScreen` directly.

- [ ] **Step 7: Refresh the profile and projection on City tree return**

Before `_refresh_main_menu_projection()` in `_on_city_passive_tree_closed`, refresh the active profile from `ProfileManager`:

```gdscript
var refresh_error := ""
var profile := profile_manager.active_profile() if profile_manager != null else null
if profile != null:
	refresh_error = profile_manager.refresh_profile(profile.profile_id)
_refresh_main_menu_projection()
var menu := get_node("MainMenuScreen") as MainMenuScreen
if not refresh_error.is_empty():
	(menu.get_node("Status") as Label).text = "Some profile data needs attention. Open Settings > Profiles for details."
```

On refresh failure, the generic player-safe status appears and the next Warehouse request must fail its required route-local refresh before opening. Restore the exact Warehouse origin only when it remains visible/focusable; otherwise call `menu.open()` without a preferred control so the existing available-action fallback selects focus.

- [ ] **Step 8: Run focused tests and verify GREEN**

```powershell
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_warehouse_presentation_resolver.gd tests/unit/test_warehouse_presentation_reporter.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd tests/unit/test_warehouse_locked_dialog.gd tests/unit/test_main_wiring.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. Direct route calls cannot bypass policy; locked presentation remains selectable; Developer preview remains unrestricted; toggle-off and candidate failure restore legacy behavior.

- [ ] **Step 9: Commit Task 4**

```powershell
git add -- scripts/world/access/warehouse_presentation_reporter.gd scripts/game/main.gd scenes/game/main.tscn tests/unit/test_warehouse_presentation_reporter.gd tests/unit/test_main_wiring.gd
git diff --cached --check
git commit -m "feat: gate Warehouse activation routes"
```

---

### Task 5: Extend end-to-end and responsive acceptance

**Files:**
- Modify: `tests/integration/city_access_snapshot_runner.gd`
- Modify: `tests/integration/main_menu_navigation_runner.gd`
- Modify: `tests/integration/main_menu_responsive_runner.gd`

**Interfaces:**
- Consumes: the complete production composition from Tasks 1-4.
- Produces: mutation-free City access activation evidence, input/navigation evidence, and nonblank locked-menu/dialog screenshots at 1920x1080, 2560x1440, and 3840x2160.

- [ ] **Step 1: Update the City access acceptance runner**

Change the provider-mode assertion so Player Mode plus flag-on resolves `CANDIDATE`. Extend the Warehouse section to prove:

- locked Player Mode resolves `LOCKED` and leaves `ProfileCodec` bytes unchanged;
- unlocked Player Mode resolves `AVAILABLE`;
- flag-off returns legacy hidden/available states without loading;
- malformed, duplicate-key, unknown-location, and wrong-destination candidates return legacy presentation;
- other City location IDs are never evaluated or dispatched;
- Developer Mode still produces shadow comparison and unrestricted preview;
- exact checked-in snapshot bytes and hashes remain unchanged before/after.

Print one new success marker only after all assertions pass:

```gdscript
print("WAREHOUSE_PRESENTATION_ACTIVATION_OK location=city.warehouse rollback=legacy authority=warehouse_policy")
```

- [ ] **Step 2: Extend navigation acceptance**

In `main_menu_navigation_runner.gd`, exercise both locked origins with keyboard/controller actions, verify the dialog traps focus, Back restores the exact origin, View City Tree enters the existing passive tree, and closing the tree returns to the refreshed Warehouse origin. Save no profile changes except the explicit fixture mutation that simulates allocating `stash`.

- [ ] **Step 3: Extend responsive visual evidence**

For each existing `WINDOW_SIZES` value, stage Player Mode with the toggle on and a no-stash profile, then capture:

```text
.superpowers/sdd/warehouse-presentation-activation/locked-menu-1920x1080.png
.superpowers/sdd/warehouse-presentation-activation/locked-dialog-1920x1080.png
.superpowers/sdd/warehouse-presentation-activation/locked-menu-2560x1440.png
.superpowers/sdd/warehouse-presentation-activation/locked-dialog-2560x1440.png
.superpowers/sdd/warehouse-presentation-activation/locked-menu-3840x2160.png
.superpowers/sdd/warehouse-presentation-activation/locked-dialog-3840x2160.png
```

Assert nonblank pixels, contained frame/copy/actions, visible lock text, minimum readable font sizing, deterministic primary focus, and no overlap. Add a high-contrast/reduced-motion pass at 1920x1080 using existing settings fields.

- [ ] **Step 4: Run all three acceptance runners**

```powershell
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/integration/city_access_snapshot_runner.gd
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/integration/main_menu_navigation_runner.gd
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/integration/main_menu_responsive_runner.gd
```

Expected: all exit `0`; output includes `WAREHOUSE_PRESENTATION_ACTIVATION_OK`, the existing navigation PASS marker, and `MAIN_MENU_RESPONSIVE_SUMMARY: PASS (3 root-window sizes)`. All six PNGs exist, are nonblank, and are visually reviewed for the approved hierarchy and copy.

- [ ] **Step 5: Commit Task 5**

```powershell
git add -- tests/integration/city_access_snapshot_runner.gd tests/integration/main_menu_navigation_runner.gd tests/integration/main_menu_responsive_runner.gd
git diff --cached --check
git commit -m "test: qualify Warehouse presentation activation"
```

Do not stage `.superpowers/` screenshots.

---

### Task 6: Qualify the exact branch and record rollback evidence

**Files:**
- Create: `docs/verification/2026-08-29-latticewright-warehouse-presentation-activation.md`

**Interfaces:**
- Consumes: immutable branch tip, checked-in authoring/runtime/snapshot files, focused suites, integration runners, visual evidence, and the existing setting rollback.
- Produces: one reviewable verification record; no production behavior.

- [ ] **Step 1: Cold-import the isolated worktree if required**

```powershell
& $partyForgeGodot --headless --editor --import --path . --quit
```

Expected: exit `0`. Record any generated untracked `.gd.uid` files before tests; remove only task-created UID sidecars after exact path verification, never user-owned files.

- [ ] **Step 2: Run the focused activation regression set**

```powershell
$activationLog = Join-Path (Get-Location) '.superpowers\warehouse-activation-focused.log'
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_warehouse_access_policy.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_warehouse_presentation_resolver.gd tests/unit/test_warehouse_presentation_reporter.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd tests/unit/test_warehouse_locked_dialog.gd tests/unit/test_main_wiring.gd tests/unit/test_passive_tree_loader.gd 2>&1 | Tee-Object -FilePath $activationLog
if ($LASTEXITCODE -ne 0) { throw "Focused activation suite failed: $LASTEXITCODE" }
if (-not (Select-String -LiteralPath $activationLog -Pattern 'TEST_SUMMARY: PASS' -Quiet)) { throw 'Focused PASS summary missing' }
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 3: Run the complete unit suite**

```powershell
$fullLog = Join-Path (Get-Location) '.superpowers\warehouse-activation-full.log'
& $partyForgeGodot --headless --path . --quit-after 1200 --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath $fullLog
if ($LASTEXITCODE -ne 0) { throw "Full suite failed: $LASTEXITCODE" }
if (-not (Select-String -LiteralPath $fullLog -Pattern 'TEST_SUMMARY: PASS' -Quiet)) { throw 'Full PASS summary missing' }
$prohibited = Select-String -LiteralPath $fullLog -CaseSensitive -Pattern 'TEST_SUMMARY: FAIL|TEST_FAILURE|SCRIPT ERROR|Parse Error|Failed loading resource|No loader found'
if ($prohibited) { $prohibited; throw 'Unexpected failure marker found' }
```

Expected: exit `0`, terminal `TEST_SUMMARY: PASS`, and zero prohibited marker matches. Record the discovered suite count printed by this run; do not copy a prior count.

- [ ] **Step 4: Re-run integration and rollback on the exact tip**

Run the three Task 5 runners again after the full suite. Then exercise the production setting path:

1. Developer Mode + flag on -> shadow evidence and Developer preview.
2. Player Mode + flag on + no `stash` -> visible locked Warehouse/dialog.
3. Player Mode + flag off + no `stash` -> hidden Warehouse.
4. Player Mode + either flag state + `stash` -> available Warehouse.

Expected: all states update on refresh without profile mutation, snapshot regeneration, cache cleanup, or process restart.

- [ ] **Step 5: Capture immutable hashes and repository boundaries**

```powershell
$hashPaths = @(
  'design/progression/latticewright/party-forge-city-access.pstree.json',
  'design/progression/latticewright/runtime-v3/party-forge-city-access.runtime.json',
  'data/world/access/party-forge-city-access.snapshot.json'
)
Get-FileHash -Algorithm SHA256 -LiteralPath $hashPaths | Format-Table Path,Hash
git status --short --branch
git diff --check
git -C 'E:\Projects\Passive Skill Tree Creator' status --short --branch
```

Expected: Party Forge hashes match before/after execution, feature worktree has only intended verification documentation after implementation commits, diff check is clean, and the Latticewright repository has no task-created changes.

- [ ] **Step 6: Write the verification record**

Create the dated document with these exact sections:

```markdown
# Warehouse Presentation Activation Verification

## Scope and exact commit
## Default-off and staged-state evidence
## Focused tests
## City access and navigation integration
## Responsive visual/input evidence
## Full-suite result and prohibited-marker scan
## Authoring, runtime, and snapshot SHA-256
## Mutation and repository-boundary checks
## Operational rollback replay
## Remaining activation boundary
```

State explicitly that only `city.warehouse` is active, `WarehouseAccessPolicy` remains authoritative, the other six City locations are inert, no Latticewright files changed, and nothing was pushed or published.

- [ ] **Step 7: Commit the verification record**

```powershell
git add -- docs/verification/2026-08-29-latticewright-warehouse-presentation-activation.md
git diff --cached --check
git commit -m "docs: verify Warehouse presentation activation"
git status --short --branch
```

Expected: clean feature worktree and a final documentation-only commit above the exact tested implementation tip.

## Execution Completion Gate

Before offering merge or cleanup options, run `superpowers:requesting-code-review` against the exact feature tip. Any Critical, Important, or Minor finding requires a bounded fix, focused RED/GREEN evidence where behavior changes, fresh affected tests, full-suite rerun, verification-record refresh, and another independent review. Only a clean review plus the exact recorded test evidence may proceed to `superpowers:finishing-a-development-branch`; merging, pushing, or deleting the worktree still requires the user's explicit choice.
