# Resumable Run Recovery and Profile Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player resume or explicitly abandon a durable checked-out run after restarting Party Forge, and permanently delete any discovered profile from Settings without touching neighboring profile artifacts.

**Architecture:** Advance the strict resumable-run document to include leader-class identity, then put inspection, legacy class binding, and strict forfeiture behind a typed `RunRecoveryService`. `MainMenuViewModel` projects recovery without mutation, while `Main` coordinates a dedicated recovery dialog and starts the existing runtime from the recovered bootstrap without checkout. A confined `ProfileDeletionService` performs exact artifact removal behind `ProfileManager`; the Profiles page owns selection, confirmation, focus, and active-run gating.

**Tech Stack:** Godot 4.7.1, typed GDScript, strict JSON codecs and migrations, `AtomicJsonStore`, profile mutation services, `.tscn` UI scenes, focused unit suites, and production-scene integration runners.

## Global Constraints

- Execute implementation in a fresh isolated Git worktree created with `superpowers:using-git-worktrees`; do not edit directly in the saved-project checkout.
- Follow RED-GREEN-REFACTOR for every behavior change and commit only after the focused gate is green.
- Resume restarts arena simulation from the beginning; it does not restore wave, timer, enemies, upgrades, health, positions, or ground drops.
- Resume preserves the original run ID, run seed, run player ID, leader member ID, selected leader class ID, and checked-out item state.
- Durable resume must never call `RunLoadoutCheckoutService.checkout()` or synthesize `_pending_checkout_recovery`.
- A legacy class choice must validate and commit atomically before runtime-context creation; persistence failure leaves the recovery document unchanged.
- Abandon permanently forfeits only the matching run and its run-owned items after a second explicit confirmation.
- Profile deletion is permanent, confined to the exact configured profile root and discovered ID, and disabled only while `run_started` is true.
- Healthy, recovered, and damaged discovered rows remain selectable for deletion; damaged rows remain ineligible for activation.
- Never run tests against `ProfileStore.DEFAULT_ROOT`; every test and integration runner uses a unique `user://tests/...` root.
- Do not inspect or remove historical files from the user's live profile root as part of this plan.
- Preserve safe player-facing errors separately from technical diagnostic strings.
- Every dialog and new button must have deterministic keyboard/controller focus and cancel without mutation.

---

## File and Responsibility Map

- `scripts/run/run_item_bootstrap.gd`: immutable recovered run identity, checked-out item state, and selected leader class.
- `scripts/run/resumable_run_item_codec.gd`: exact current resumable document fields and strict decode/validation.
- `scripts/profile/profile_state.gd`, `profile_codec.gd`, `profile_migrator.gd`: outer profile schema five and schema-four promotion.
- `scripts/run/run_loadout_checkout_service.gd`: new-checkout class persistence, bootstrap decoding, recovered equipment/class eligibility, and strict forfeit.
- `scripts/run/run_recovery_result.gd`, `run_recovery_service.gd`: typed inspection, legacy binding, and forfeiture boundary.
- `scripts/ui/run_recovery/run_recovery_dialog.gd` and matching scene: Resume, legacy class selection, Abandon, nested confirmation, failure display, and focus.
- `scripts/ui/main_menu/main_menu_view_model.gd`: value-only Resume Run projection.
- `scripts/game/main.gd`: recovery orchestration and shared committed-bootstrap runtime start.
- `scripts/profile/profile_deletion_result.gd`, `profile_deletion_service.gd`: confined, exact artifact deletion result and filesystem boundary.
- `scripts/profile/profile_manager.gd`: discovered-ID authorization, in-memory removal, active-profile replacement, index persistence, and signals.
- `scripts/ui/settings/profiles_settings_page.gd` and matching scene: delete eligibility, named confirmation, cancel/failure behavior, and focus.
- `scripts/ui/settings/settings_screen.gd`: explicit run-active query forwarding.
- `tests/unit/*.gd`: strict contract tests for each boundary.
- `tests/integration/run_recovery_profile_lifecycle_runner.gd`: production-scene restart, recovery, abandonment, deletion, and focus proof.

---

### Task 1: Isolate Existing Profile-Preservation Sentinels

**Files:**

- Modify: `tests/unit/test_developer_item_sandbox_state.gd`
- Test: `tests/unit/test_developer_item_sandbox_state.gd`

**Interfaces:**

- Consumes: `ProfileTestSupport.remove_tree(root: String)` and `ProfileStore.profile_path(profile_id: String, root: String)`.
- Produces: one unique `_test_root` beneath `user://tests/developer_item_sandbox_state/` used by every sentinel fixture in this suite.

- [ ] **Step 1: Add the isolated-root assertion and fixture lifecycle**

Add one per-suite root and make the existing profile-preservation assertions use it:

```gdscript
const TEST_ROOT_PREFIX := "user://tests/developer_item_sandbox_state"
var _test_root := ""

func _begin_fixture() -> void:
	_test_root = TEST_ROOT_PREFIX.path_join("%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	TestAssertions.truthy(
		_test_root.begins_with("user://tests/") and not _test_root.begins_with(ProfileStore.DEFAULT_ROOT),
		"sandbox preservation fixtures use isolated profile storage",
		failures,
	)

func _end_fixture() -> void:
	ProfileTestSupport.remove_tree(_test_root)
```

Call `_begin_fixture()` before the two sentinel scenarios, construct their paths with `ProfileStore.new().profile_path(profile_id, _test_root)`, and call `_end_fixture()` after all byte-preservation assertions.

- [ ] **Step 2: Run the suite to prove the old paths fail the new assertion**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd
```

Expected: `TEST_SUMMARY: FAIL` identifies the still-default sentinel paths; no parser or loader error.

- [ ] **Step 3: Move both sentinels to `_test_root` and preserve their byte assertions**

Replace each default-root construction with:

```gdscript
var profile_sentinel := ProfileStore.new().profile_path(profile_id, _test_root)
```

Keep the exact before/after byte comparisons and make teardown remove only `_test_root`.

- [ ] **Step 4: Run GREEN and commit**

Run the Step 2 command again. Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add tests/unit/test_developer_item_sandbox_state.gd
git commit -m "test: isolate sandbox profile sentinels"
```

---

### Task 2: Version the Strict Recovery Document with Leader Class Identity

**Files:**

- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_migrator.gd`
- Modify: `scripts/run/run_item_bootstrap.gd`
- Modify: `scripts/run/resumable_run_item_codec.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Test: `tests/unit/test_profile_state.gd`
- Test: `tests/unit/test_profile_item_schema_migration.gd`
- Test: `tests/unit/test_atomic_profile_store.gd`
- Test: `tests/unit/test_run_loadout_checkout_service.gd`
- Test: `tests/unit/test_player_run_context.gd`

**Interfaces:**

- Consumes: existing `RunLoadoutCheckoutRequest.selected_leader_class_id` and outer schema-four profile documents.
- Produces: `ProfileState.SCHEMA_VERSION == 5`, exact six-field recovery documents, and `RunItemBootstrap.selected_leader_class_id: StringName`.
- Produces: compatible constructor `RunItemBootstrap.create(run_id_value, run_seed_value, run_player_id_value, leader_member_id_value, item_state_value, selected_leader_class_id_value = &"")`.

- [ ] **Step 1: Write strict-codec and migration failures first**

Add explicit assertions covering the six-field current document:

```gdscript
const CURRENT_RECOVERY_FIELDS: Array[String] = [
	"item_state", "leader_member_id", "run_id", "run_player_id", "run_seed", "selected_leader_class_id",
]

var encoded := ResumableRunItemCodec.encode(
	RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_MEMBER_ID, state, &"fighter")
)
TestAssertions.equal(encoded.keys().sorted(), CURRENT_RECOVERY_FIELDS.duplicate().sorted(), "recovery fields are exact", failures)
TestAssertions.equal(encoded["selected_leader_class_id"], "fighter", "recovery persists leader class", failures)
```

In schema migration tests, derive a valid schema-four document from a current fixture, set `schema_version = 4`, remove `selected_leader_class_id` only from a nonempty `resumable_run`, load through `ProfileStore`, and assert promotion to schema five inserts `"selected_leader_class_id": ""` while preserving the canonical old recovery fields and item-state dictionary exactly. Add failures for a missing current field, an unknown extra field, and a non-string class field.

- [ ] **Step 2: Run RED**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd
```

Expected: failures identify schema version 4 and the absent class field/property; no unrelated suite failure.

- [ ] **Step 3: Add class identity to `RunItemBootstrap` and the strict codec**

Append the optional constructor argument so existing non-persistence call sites remain source-compatible:

```gdscript
var _selected_leader_class_id: StringName = &""
var selected_leader_class_id: StringName:
	get:
		return _selected_leader_class_id

static func create(
	run_id_value: StringName,
	run_seed_value: int,
	run_player_id_value: StringName,
	leader_member_id_value: int,
	item_state_value: ItemOwnershipState,
	selected_leader_class_id_value: StringName = &"",
) -> RunItemBootstrap:
	var result := RunItemBootstrap.new()
	result._run_id = run_id_value
	result._run_seed = run_seed_value
	result._run_player_id = run_player_id_value
	result._leader_member_id = leader_member_id_value
	result._item_state = item_state_value.copy() if item_state_value != null else null
	result._selected_leader_class_id = selected_leader_class_id_value
	return result
```

Change `ResumableRunItemCodec.FIELDS` to include `selected_leader_class_id`, encode it as `String`, pass it into `RunItemBootstrap.create()` during decode, and validate it as a string. Empty is allowed only as the migrated legacy marker; catalog membership remains a service-layer rule.

- [ ] **Step 4: Add schema-four validation and a dedicated four-to-five migration**

In `ProfileCodec`, preserve the outer schema-four field list and route both versions explicitly:

```gdscript
const SCHEMA_FOUR_VERSION := 4
const SCHEMA_FOUR_FIELDS: Array[String] = CURRENT_FIELDS.duplicate()

static func validate_schema_four_document(document: Dictionary) -> String:
	return _validate_document(document, SCHEMA_FOUR_VERSION, false)
```

For `expected_schema == SCHEMA_FOUR_VERSION`, validate the old five-field recovery document without using the new codec. In `ProfileMigrator`, keep schema three-to-four responsible only for `preferred_player_color_id`, then recursively promote schema-four transaction snapshots and the top-level document:

```gdscript
static func _migrate_schema_four_document(document: Dictionary) -> String:
	for transaction_id: Variant in document["applied_transactions"] as Dictionary:
		var record := (document["applied_transactions"] as Dictionary)[transaction_id] as Dictionary
		var snapshot := (record["result_profile"] as Dictionary).duplicate(true)
		var snapshot_error := _migrate_schema_four_document(snapshot)
		if not snapshot_error.is_empty():
			return snapshot_error
		record["result_profile"] = snapshot
	document["schema_version"] = ProfileState.SCHEMA_VERSION
	var recovery := document["resumable_run"] as Dictionary
	if not recovery.is_empty():
		recovery["selected_leader_class_id"] = ""
	return ""
```

Advance `ProfileState.SCHEMA_VERSION` to `5`. Empty recoveries remain `{}`.

- [ ] **Step 5: Make new checkout documents always include the requested class**

Build the checkout bootstrap with the authoritative request value:

```gdscript
var bootstrap := RunItemBootstrap.create(
	request.run_id,
	request.run_seed,
	request.run_player_id,
	request.leader_member_id,
	run_state,
	request.selected_leader_class_id,
)
```

Add a checkout assertion that `result.profile.resumable_run["selected_leader_class_id"] == String(request.selected_leader_class_id)` and that a replayed transaction returns the same value.

- [ ] **Step 6: Run GREEN and commit**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/profile/profile_state.gd scripts/profile/profile_codec.gd scripts/profile/profile_migrator.gd scripts/run/run_item_bootstrap.gd scripts/run/resumable_run_item_codec.gd scripts/run/run_loadout_checkout_service.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
git commit -m "feat: persist resumable run leader class"
```

---

### Task 3: Add the Typed Durable Run Recovery Service

**Files:**

- Create: `scripts/run/run_recovery_result.gd`
- Create: `scripts/run/run_recovery_service.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Test: `tests/unit/test_run_recovery_service.gd`
- Test: `tests/unit/test_run_loadout_checkout_service.gd`
- Test: `tests/unit/test_player_run_context.gd`

**Interfaces:**

- Consumes: `RunLoadoutCheckoutService.bootstrap_from(profile)` and `forfeit(profile_id, run_id, root)`.
- Produces: `RunRecoveryResult.Code` values `READY`, `CLASS_REQUIRED`, `INVALID`, `PERSISTENCE_FAILED`.
- Produces: `RunRecoveryService.inspect(profile)`, `bind_legacy_class(profile_id, class_id, root)`, and `forfeit(profile_id, run_id, root)`.
- Produces: `RunLoadoutCheckoutService.validate_recovered_class(bootstrap, class_id) -> String`.

- [ ] **Step 1: Create the result contract tests**

Write tests against this exact result shape:

```gdscript
class_name RunRecoveryResult
extends RefCounted

enum Code { READY, CLASS_REQUIRED, INVALID, PERSISTENCE_FAILED }

var code := Code.INVALID
var profile: ProfileState
var bootstrap: RunItemBootstrap
var selected_leader_class_id: StringName = &""
var run_id: StringName = &""
var can_forfeit := false
var error := ""

func ready() -> bool:
	return code == Code.READY and profile != null and bootstrap != null and error.is_empty()
```

Cover: current recovery becomes `READY`; empty class becomes `CLASS_REQUIRED`; malformed bootstrap becomes `INVALID`; unknown or incompatible class becomes `INVALID`; result profile and item state are defensive copies; empty recovery cannot be forfeited; a valid strict bootstrap with a class problem still exposes the exact `run_id` and `can_forfeit == true`.

- [ ] **Step 2: Run RED**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recovery_service.gd
```

Expected: suite load fails only because `RunRecoveryResult` and `RunRecoveryService` do not exist.

- [ ] **Step 3: Expose recovered equipment/class validation without duplicating checkout rules**

Add to `RunLoadoutCheckoutService`:

```gdscript
func validate_recovered_class(bootstrap: RunItemBootstrap, class_id: StringName) -> String:
	if bootstrap == null or bootstrap.item_state() == null:
		return "PARTY_FORGE_RUN_RECOVERY_ERROR field=bootstrap reason=unavailable"
	var leader := bootstrap.item_state().container(
		StringName("run-equipment-%03d" % bootstrap.leader_member_id)
	)
	if leader == null or leader.container_kind != ItemSlotContainer.RUN_MEMBER_EQUIPMENT:
		return "PARTY_FORGE_RUN_RECOVERY_ERROR field=leader_equipment reason=missing"
	var eligibility := _validate_loadout_eligibility(bootstrap.item_state(), leader, class_id)
	return eligibility.replace("PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR", "PARTY_FORGE_RUN_RECOVERY_ERROR")
```

The method reads only the recovered item state and current catalogs. It does not mutate a profile or call checkout.

- [ ] **Step 4: Implement inspection and legacy binding**

Use this service surface:

```gdscript
class_name RunRecoveryService
extends RefCounted

var _checkout: RunLoadoutCheckoutService
var _mutations: ProfileMutationService
var _store: ProfileStore

func _init(
	checkout: RunLoadoutCheckoutService = null,
	mutations: ProfileMutationService = null,
	store: ProfileStore = null,
) -> void:
	_checkout = checkout if checkout != null else RunLoadoutCheckoutService.new()
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_store = store if store != null else ProfileStore.new()

func inspect(profile: ProfileState) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	if profile == null:
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=profile reason=must not be null"
		return result
	var profile_error := ProfileCodec.validate_profile(profile)
	if not profile_error.is_empty():
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=profile reason=%s" % profile_error
		return result
	var bootstrap := _checkout.bootstrap_from(profile)
	if bootstrap == null:
		result.error = "PARTY_FORGE_RUN_RECOVERY_ERROR field=resumable_run reason=strict bootstrap unavailable"
		return result
	result.profile = profile.copy()
	result.bootstrap = RunItemBootstrap.create(
		bootstrap.run_id,
		bootstrap.run_seed,
		bootstrap.run_player_id,
		bootstrap.leader_member_id,
		bootstrap.item_state(),
		bootstrap.selected_leader_class_id,
	)
	result.run_id = bootstrap.run_id
	result.can_forfeit = true
	result.selected_leader_class_id = bootstrap.selected_leader_class_id
	if bootstrap.selected_leader_class_id.is_empty():
		result.code = RunRecoveryResult.Code.CLASS_REQUIRED
		return result
	var class_error := _checkout.validate_recovered_class(bootstrap, bootstrap.selected_leader_class_id)
	if not class_error.is_empty():
		result.error = class_error
		return result
	result.code = RunRecoveryResult.Code.READY
	return result

func bind_legacy_class(
	profile_id: String,
	class_id: StringName,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> RunRecoveryResult:
	var loaded := _store.load_profile(profile_id, root)
	if not loaded.ok():
		return _persistence_failure(loaded.error if not loaded.error.is_empty() else "profile is missing")
	var before := inspect(loaded.profile)
	if before.code != RunRecoveryResult.Code.CLASS_REQUIRED or before.bootstrap == null:
		return _invalid("PARTY_FORGE_RUN_RECOVERY_ERROR field=selected_leader_class_id reason=legacy class binding is not available")
	var expected_run_id := before.bootstrap.run_id
	var transaction_id := "bind-run-class:%s:%s" % [expected_run_id, class_id]
	var mutation := _mutations.apply(
		profile_id,
		transaction_id,
		func(candidate: ProfileState) -> String:
			var current := inspect(candidate)
			if current.code != RunRecoveryResult.Code.CLASS_REQUIRED or current.bootstrap == null:
				return "PARTY_FORGE_RUN_RECOVERY_ERROR field=resumable_run reason=legacy recovery changed"
			if current.bootstrap.run_id != expected_run_id:
				return "PARTY_FORGE_RUN_RECOVERY_ERROR field=run_id reason=run identity changed"
			var class_error := _checkout.validate_recovered_class(current.bootstrap, class_id)
			if not class_error.is_empty():
				return class_error
			candidate.resumable_run["selected_leader_class_id"] = String(class_id)
			return "",
		root,
		-1,
		"bind_run_recovery_class",
		{"class_id": String(class_id), "run_id": String(expected_run_id)},
	)
	if not mutation.ok():
		return _persistence_failure(mutation.error)
	return inspect(mutation.profile)

func forfeit(
	profile_id: String,
	run_id: StringName,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	return _checkout.forfeit(profile_id, run_id, root)

func _invalid(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.error = error
	return result

func _persistence_failure(error: String) -> RunRecoveryResult:
	var result := RunRecoveryResult.new()
	result.code = RunRecoveryResult.Code.PERSISTENCE_FAILED
	result.error = error
	return result
```

Replace the explanatory bodies above with direct branches, not pass-through UI logic. The binding transaction ID is `"bind-run-class:%s:%s" % [bootstrap.run_id, class_id]`; its mutation re-decodes the candidate and rejects profile/run changes, a nonempty class marker, an unknown class, or incompatible equipment before assigning `candidate.resumable_run["selected_leader_class_id"] = String(class_id)`.

- [ ] **Step 5: Prove atomic failure, deterministic restart, and zero checkout**

Add a mutation spy that counts operation names. Assert:

```gdscript
TestAssertions.equal(spy.operation_count(RunLoadoutCheckoutService.CHECKOUT_OPERATION), 0, "recovery never checks out again", failures)
TestAssertions.equal(bound.bootstrap.run_id, original.run_id, "binding preserves run id", failures)
TestAssertions.equal(bound.bootstrap.item_state().to_dictionary(), original.item_state().to_dictionary(), "binding preserves checked-out items", failures)
```

Inject a persistence failure and assert the stored recovery bytes are unchanged. Recreate the service and manager from disk after a successful bind and assert direct `READY` without another class request. Configure `PlayerRunContext` with Developer Mode minimum capacity `5` and assert runtime inventory expands without changing durable `inventory_columns` or recovery bytes.

- [ ] **Step 6: Run GREEN and commit**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recovery_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/run/run_recovery_result.gd scripts/run/run_recovery_service.gd scripts/run/run_loadout_checkout_service.gd tests/unit/test_run_recovery_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
git commit -m "feat: recover durable run checkout state"
```

---

### Task 4: Route Resume, Legacy Class Binding, and Abandonment Through Main

**Files:**

- Modify: `scripts/ui/main_menu/main_menu_view_model.gd`
- Test: `tests/unit/test_main_menu_view_model.gd`
- Create: `scenes/ui/run_recovery/run_recovery_dialog.tscn`
- Create: `scripts/ui/run_recovery/run_recovery_dialog.gd`
- Test: `tests/unit/test_run_recovery_dialog.gd`
- Modify: `scenes/game/main.tscn`
- Modify: `scripts/game/main.gd`
- Test: `tests/unit/test_main_wiring.gd`
- Test: `tests/unit/test_main_loadout_checkout_recovery.gd`

**Interfaces:**

- Consumes: Task 3 `RunRecoveryService` and `RunRecoveryResult`.
- Produces: `MainMenuViewModel.ROUTE_RUN_RECOVERY: StringName = &"run_recovery"`.
- Produces: dialog signals `resume_requested`, `legacy_class_requested(class_id)`, `abandon_requested(run_id)`, and `cancelled`.
- Produces: `RunRecoveryDialog.open(result, classes, profile_name, return_focus)` and `show_failure(safe_message, technical_detail)`.

- [ ] **Step 1: Add main-menu projection failures**

For every otherwise valid profile with nonempty `resumable_run`, assert:

```gdscript
var projection := MainMenuViewModel.build(profile, settings, true)
TestAssertions.equal(projection.primary_label, "Resume Run", "recovery overrides normal play label", failures)
TestAssertions.equal(projection.primary_route_id, MainMenuViewModel.ROUTE_RUN_RECOVERY, "recovery uses explicit route", failures)
TestAssertions.equal(projection.status_text, "An interrupted run is ready to recover.", "recovery explains the route", failures)
```

The view model checks only nonempty recovery state. A malformed nonempty document still routes to recovery so it cannot silently open a fresh checkout.

- [ ] **Step 2: Add recovery-dialog behavior failures**

Create scene tests for these modes:

```gdscript
TestAssertions.truthy(_resume_button().visible and not _resume_button().disabled, "ready recovery offers resume", failures)
TestAssertions.truthy(_class_picker().visible and not _resume_button().visible, "legacy recovery requires class binding", failures)
TestAssertions.truthy(not _resume_button().visible and _abandon_button().visible, "invalid but forfeitable recovery offers abandon only", failures)
TestAssertions.truthy(_abandon_confirmation().dialog_text.contains("run-owned items will be permanently lost"), "abandon warning is explicit", failures)
```

Assert cancel emits no mutating signal and restores focus to the main-menu primary action. Assert the second Abandon confirmation includes the active profile display name and exact run ID.

- [ ] **Step 3: Run UI RED**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd
```

Expected: the new route and dialog are absent; existing menu assertions continue to pass.

- [ ] **Step 4: Implement the projection and dedicated dialog scene**

In `MainMenuViewModel.build()`, place this override immediately after active-profile text is set and before the prologue-state match:

```gdscript
if not supplied_profile.resumable_run.is_empty():
	result.primary_label = "Resume Run"
	result.primary_route_id = ROUTE_RUN_RECOVERY
	result.status_text = "An interrupted run is ready to recover."
else:
	match supplied_profile.prologue_state:
		ProfileState.PrologueState.NOT_STARTED:
			result.primary_label = "Play"
			result.primary_route_id = ROUTE_PROLOGUE_START
			result.status_text = "Begin your journey."
		ProfileState.PrologueState.IN_PROGRESS:
			result.primary_label = "Continue"
			result.primary_route_id = ROUTE_PROLOGUE_RESUME
			result.status_text = "Continue your journey."
		ProfileState.PrologueState.COMPLETED:
			result.primary_label = "Begin Run"
			result.primary_route_id = ROUTE_RUN_SETUP
			result.status_text = "Ready for your next run."
```

Build `run_recovery_dialog.tscn` with a full-screen overlay, title/status labels, technical disclosure, class `OptionButton`, Resume/Bind/Abandon/Cancel buttons, and child `ConfirmationDialog`. The script stores the exact `run_id`, makes Resume and Bind mutually exclusive, enables Abandon only when `can_forfeit`, and never edits profile data itself.

- [ ] **Step 5: Add Main orchestration failures with checkout spying**

Inject `_run_recovery` and a checkout spy into Main. Drive `ROUTE_RUN_RECOVERY`, then assert:

```gdscript
TestAssertions.equal(checkout_spy.checkout_calls, 0, "durable resume performs zero checkouts", failures)
TestAssertions.equal(main.active_run_context.run_id, original.run_id, "runtime preserves recovered run id", failures)
TestAssertions.equal(main.game_run.run_seed, original.run_seed, "runtime preserves recovered seed", failures)
TestAssertions.equal(main.active_run_context.item_state().to_dictionary(), original.item_state().to_dictionary(), "runtime preserves checked-out item state", failures)
```

Add failures proving class binding refreshes the manager and reinspects before start; incompatible binding leaves disk bytes unchanged; context creation failure keeps recovery; confirmed Abandon calls strict forfeit once; a forfeit error leaves the dialog and recovery available.

- [ ] **Step 6: Refactor committed-bootstrap start and wire recovery routes**

Add `ROUTE_RUN_RECOVERY` to `_on_main_menu_route_requested()`. Add `_run_recovery := RunRecoveryService.new()` and connect the dialog signals in `_wire_static_ui()`.

Make `_prepare_run_start` accept the durable seed with these exact edits:

```diff
-func _prepare_run_start(definition: ClassDefinition) -> bool:
+func _prepare_run_start(definition: ClassDefinition, run_seed: int = RUN_SEED) -> bool:
 	if definition == null:
 		return false
 	active_run_rules = RunRulesSnapshot.from_settings(saved_settings)
 	if CURRENT_STARTING_PARTY_SIZE > active_run_rules.party_capacity():
 		_show_run_setup_error("PARTY_FORGE_RUN_RULES_ERROR selected=%d capacity=%d" % [CURRENT_STARTING_PARTY_SIZE, active_run_rules.party_capacity()])
 		return false
-	game_run.configure_seed(RUN_SEED)
+	game_run.configure_seed(run_seed)
 	var combat_configuration_errors: PackedStringArray = combat_resolution_service.call("configure", game_run.combat_rng, catalog.damage_types) as PackedStringArray
 	if not combat_configuration_errors.is_empty():
 		_show_run_setup_error(combat_configuration_errors[0])
 		return false
 	party_manager.configure_identity(game_run.run_seed, catalog.generic_name_pool)
```

Extract one shared committed-bootstrap entry:

```gdscript
func _start_committed_run(
	committed_profile: ProfileState,
	definition: ClassDefinition,
	bootstrap: RunItemBootstrap,
) -> bool:
	if not _prepare_run_start(definition, bootstrap.run_seed):
		return false
	if party_manager.members.is_empty() or party_manager.members[0].member_id != bootstrap.leader_member_id:
		_show_run_setup_error("PARTY_FORGE_RUN_RECOVERY_ERROR field=leader_member_id reason=deterministic leader mismatch")
		return false
	return _start_leader_class_from_checkout(definition, committed_profile, bootstrap)
```

Both `_resume_pending_checkout()` and after-restart recovery call `_start_committed_run()`. Only `_checkout_and_start_leader_class()` calls checkout. `_open_run_recovery()` refreshes the active profile, calls `inspect`, and opens the dialog. Legacy selection calls `bind_legacy_class`, refreshes the manager, reinspects, then starts only from `READY`. Abandon uses the result's decoded `run_id`, shows the nested confirmation, calls `forfeit`, refreshes only after commit, closes the dialog, and refreshes the menu projection.

- [ ] **Step 7: Run GREEN and commit**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_run_recovery_service.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (0 failures)` and no ObjectDB/resource-retention marker.

```powershell
git add scripts/ui/main_menu/main_menu_view_model.gd tests/unit/test_main_menu_view_model.gd scenes/ui/run_recovery/run_recovery_dialog.tscn scripts/ui/run_recovery/run_recovery_dialog.gd tests/unit/test_run_recovery_dialog.gd scenes/game/main.tscn scripts/game/main.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd
git commit -m "feat: resume or abandon interrupted runs"
```

---

### Task 5: Add Exact Permanent Profile Artifact Deletion

**Files:**

- Create: `scripts/profile/profile_deletion_result.gd`
- Create: `scripts/profile/profile_deletion_service.gd`
- Create: `tests/unit/test_profile_deletion_service.gd`
- Modify: `scripts/profile/profile_store.gd`
- Modify: `scripts/profile/profile_manager.gd`
- Test: `tests/unit/test_profile_manager.gd`
- Test: `tests/unit/test_atomic_profile_store.gd`

**Interfaces:**

- Consumes: `ProfileCodec.validate_profile_id`, `ProfileStore.profile_path`, current bootstrap-discovered `_profile_statuses`, and `ProfileIndexStore.save_index`.
- Produces: `ProfileDeletionResult` with `committed`, `cleanup_debt`, `deleted_profile_id`, `next_active_profile_id`, and `error`.
- Produces: `ProfileDeletionService.delete_profile_artifacts(profile_id, discovered_profile_ids, root) -> ProfileDeletionResult`.
- Produces: `ProfileManager.delete_profile(profile_id) -> ProfileDeletionResult`.

- [ ] **Step 1: Define the deletion result and write confinement failures**

Use this exact result contract:

```gdscript
class_name ProfileDeletionResult
extends RefCounted

var committed := false
var cleanup_debt := false
var deleted_profile_id := ""
var next_active_profile_id := ""
var error := ""

func ok() -> bool:
	return committed and not cleanup_debt
```

Build isolated fixtures for primary plus backup, backup-only, damaged primary/backup, every fixed suffix, numeric corrupt suffixes, and neighboring lookalike names. Assert path-like IDs (`../profile-a`, `C:\profile-a`, `folder/profile-a`, `folder\profile-a`) and valid-but-undiscovered IDs fail before the injected remover is called.

- [ ] **Step 2: Lock the exact artifact allowlist in tests**

For `primary = ProfileStore.profile_path(profile_id, root)`, the only permitted source paths are:

```gdscript
[
	primary,
	"%s.bak" % primary,
	"%s.tmp" % primary,
	"%s.bak.previous" % primary,
	"%s.irreversible-primary.tmp" % primary,
	"%s.irreversible-backup.tmp" % primary,
]
```

Dynamic candidates are only `primary + ".corrupt-" + digits` and `primary + ".bak.corrupt-" + digits`. Add byte-for-byte assertions that `profile-a2.json`, `profile-a.json.corrupt-text`, index files, and all neighboring profiles remain unchanged.

- [ ] **Step 3: Run deletion RED**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd
```

Expected: missing deletion classes/methods are the only failures.

- [ ] **Step 4: Implement exact target discovery and verified removal**

Use an injectable remover and a preflight that returns no paths until identity and confinement pass:

```gdscript
class_name ProfileDeletionService
extends RefCounted

var _remove_file: Callable

func _init(remove_file: Callable = Callable()) -> void:
	_remove_file = remove_file if remove_file.is_valid() else func(path: String) -> Error:
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func delete_profile_artifacts(
	profile_id: String,
	discovered_profile_ids: PackedStringArray,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileDeletionResult:
	var result := ProfileDeletionResult.new()
	var identity_error := _validate_identity(profile_id, discovered_profile_ids)
	if not identity_error.is_empty():
		result.error = identity_error
		return result
	var targets := _artifact_paths(profile_id, root)
	if targets.is_empty():
		result.error = "PROFILE_DELETE_ERROR profile=%s reason=confined artifact targets unavailable" % profile_id
		return result
	var snapshots: Dictionary = {}
	for path: String in targets:
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			if FileAccess.get_open_error() != OK:
				result.error = "PROFILE_DELETE_ERROR profile=%s stage=snapshot path=%s code=%d" % [profile_id, path, FileAccess.get_open_error()]
				return result
			snapshots[path] = bytes
	for path: String in targets:
		if not FileAccess.file_exists(path):
			continue
		var remove_error := _remove_file.call(path) as Error
		if remove_error != OK and FileAccess.file_exists(path):
			var restore_error := _restore_snapshots(snapshots)
			result.error = "PROFILE_DELETE_ERROR profile=%s stage=remove path=%s code=%d restore_code=%d" % [profile_id, path, remove_error, restore_error]
			return result
	for path: String in targets:
		if FileAccess.file_exists(path):
			var restore_error := _restore_snapshots(snapshots)
			result.error = "PROFILE_DELETE_ERROR profile=%s stage=verify path=%s restore_code=%d" % [profile_id, path, restore_error]
			return result
	result.committed = true
	result.deleted_profile_id = profile_id
	return result

func _validate_identity(profile_id: String, discovered: PackedStringArray) -> String:
	if profile_id not in discovered:
		return "PROFILE_DELETE_ERROR profile=%s reason=undiscovered profile" % profile_id
	if ProfileCodec.validate_profile_id(profile_id).is_empty():
		return ""
	if profile_id.is_empty() or not profile_id.is_valid_filename() or profile_id in [".", ".."]:
		return "PROFILE_DELETE_ERROR profile=%s reason=unsafe discovered profile id" % profile_id
	if "/" in profile_id or "\\" in profile_id or ":" in profile_id:
		return "PROFILE_DELETE_ERROR profile=%s reason=unsafe discovered profile id" % profile_id
	return ""

func _artifact_paths(profile_id: String, root: String) -> Array[String]:
	var primary := ProfileStore.new().profile_path(profile_id, root)
	var root_absolute := ProjectSettings.globalize_path(root).simplify_path()
	var primary_absolute := ProjectSettings.globalize_path(primary).simplify_path()
	if primary_absolute.get_base_dir() != root_absolute:
		return []
	var result: Array[String] = [
		primary,
		"%s.bak" % primary,
		"%s.tmp" % primary,
		"%s.bak.previous" % primary,
		"%s.irreversible-primary.tmp" % primary,
		"%s.irreversible-backup.tmp" % primary,
	]
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	var basename := primary.get_file()
	for candidate_name: String in directory.get_files():
		for prefix: String in ["%s.corrupt-" % basename, "%s.bak.corrupt-" % basename]:
			if candidate_name.begins_with(prefix) and _digits_only(candidate_name.trim_prefix(prefix)):
				result.append(root.path_join(candidate_name))
	result.sort()
	return result

func _digits_only(value: String) -> bool:
	if value.is_empty():
		return false
	for codepoint: int in value.to_utf32_buffer():
		if codepoint < 48 or codepoint > 57:
			return false
	return true

func _restore_snapshots(snapshots: Dictionary) -> Error:
	for path: String in snapshots:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_buffer(snapshots[path] as PackedByteArray)
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			return write_error
		if FileAccess.get_file_as_bytes(path) != snapshots[path] as PackedByteArray:
			return ERR_FILE_CORRUPT
	return OK
```

Implement `_digits_only(value)` by checking each Unicode codepoint is `48..57`; do not accept signs or empty suffixes. Resolve both root and every candidate with `ProjectSettings.globalize_path()`, require `candidate.get_base_dir() == root_absolute`, and require the derived candidate filename to equal one of the fixed names or pass the numeric-suffix check. Snapshot every existing target before the first remove. If a remove fails, rewrite any already-removed snapshot and verify all original bytes; return `committed == false`. After every removal succeeds, verify every target is absent before returning `committed == true`.

- [ ] **Step 5: Add manager orchestration and post-commit index semantics**

Inject the deletion service into `ProfileManager._init()` as a fourth optional dependency. Authorize only IDs currently present in `_profile_statuses`:

```gdscript
func delete_profile(profile_id: String) -> ProfileDeletionResult:
	if not _profile_statuses.has(profile_id):
		return _delete_failure("PROFILE_DELETE_ERROR profile=%s reason=undiscovered profile" % profile_id)
	var discovered := PackedStringArray()
	for discovered_id: Variant in _profile_statuses:
		discovered.append(String(discovered_id))
	var result := _deletion.delete_profile_artifacts(profile_id, discovered, _root)
	if not result.committed:
		return result
	_profiles.erase(profile_id)
	_profile_statuses.erase(profile_id)
	if _index.active_profile_id == profile_id:
		_index.active_profile_id = _most_recent_profile_id()
	_rebuild_index()
	result.next_active_profile_id = _index.active_profile_id
	var index_error := _index_store.save_index(_index, _root)
	if not index_error.is_empty():
		result.cleanup_debt = true
		result.error = "PROFILE_DELETE_CLEANUP_DEBT profile=%s committed=true error=%s" % [profile_id, index_error]
	profiles_changed.emit()
	var active := active_profile()
	if active != null:
		active_profile_changed.emit(active)
	return result

func _delete_failure(error: String) -> ProfileDeletionResult:
	var result := ProfileDeletionResult.new()
	result.error = error
	return result
```

The manager must not reinsert a committed deletion when index save fails. Add tests for active-profile replacement by most-recent `updated_at_unix`, final-profile empty active state, recovered/damaged deletion, precommit remover failure, and committed deletion with injected index failure.

- [ ] **Step 6: Run GREEN and commit**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_atomic_profile_store.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/profile/profile_deletion_result.gd scripts/profile/profile_deletion_service.gd tests/unit/test_profile_deletion_service.gd scripts/profile/profile_store.gd scripts/profile/profile_manager.gd tests/unit/test_profile_manager.gd tests/unit/test_atomic_profile_store.gd
git commit -m "feat: permanently delete selected profiles"
```

---

### Task 6: Add Profile Deletion Selection, Confirmation, and Run Gating

**Files:**

- Modify: `scenes/ui/settings/profiles_settings_page.tscn`
- Modify: `scripts/ui/settings/profiles_settings_page.gd`
- Test: `tests/unit/test_profiles_settings_page.gd`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Test: `tests/unit/test_settings_screen.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/integration/settings_profiles_navigation_runner.gd`

**Interfaces:**

- Consumes: `ProfileManager.delete_profile(profile_id)` and `ProfileEntryStatus.selectable()` for activation only.
- Produces: `ProfilesSettingsPage.bind(manager, run_active_query)` and `set_run_active_query(query)`.
- Produces: Settings configuration argument `run_active_query: Callable = Callable()`.

- [ ] **Step 1: Write page and settings failures**

Assert these exact behaviors:

```gdscript
TestAssertions.truthy(_delete_button().disabled, "delete is disabled without a selected row", failures)
TestAssertions.truthy(not _delete_button().disabled, "damaged discovered row remains deletable", failures)
TestAssertions.truthy(_activate_button().disabled, "damaged row remains ineligible for activation", failures)
TestAssertions.truthy(_delete_button().disabled, "active arena run disables deletion", failures)
TestAssertions.truthy(_delete_confirmation().dialog_text.contains(selected_display_name), "confirmation names selected profile", failures)
TestAssertions.truthy(_delete_confirmation().dialog_text.contains("resumable run and all run-owned items"), "confirmation warns about recovery loss", failures)
```

Snapshot all selected-profile and index bytes before cancel and assert they remain identical. Inject a manager spy and assert confirm calls deletion once, failure keeps the same selection/focus, active deletion focuses the new active row, and final deletion focuses the name field and shows the existing empty state.

- [ ] **Step 2: Run page RED**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profiles_settings_page.gd tests/unit/test_settings_screen.gd
```

Expected: Delete control and run-active boundary assertions fail; activation tests remain green.

- [ ] **Step 3: Add the scene controls and separate eligibility rules**

Add `DeleteProfile: Button` with text `Delete Selected Profile` beside Activate and a child `DeleteConfirmation: ConfirmationDialog`. Store `profile_id` and status state as item metadata. Do not disable damaged list rows.

Use separate gates:

```gdscript
func _selected_status() -> ProfileEntryStatus:
	var selected := _profile_list().get_selected_items()
	if selected.is_empty():
		return null
	return _status_by_id.get(String(_profile_list().get_item_metadata(selected[0]))) as ProfileEntryStatus

func _refresh_action_eligibility() -> void:
	var status := _selected_status()
	_activate_button().disabled = status == null or not status.selectable()
	_delete_button().disabled = status == null or _run_is_active()
```

The confirmation text is:

```gdscript
_delete_confirmation().dialog_text = (
	"Permanently delete %s? This cannot be undone. Any resumable run and all run-owned items will also be discarded."
	% status.display_name
)
```

On committed deletion, refresh rows and focus the next selected/active row, or `_profile_name()` if none remain. On noncommitted failure, preserve selection and focus Delete while rendering the existing friendly and technical error channels. On cleanup debt, refresh the committed deletion and show a safe cleanup warning with the technical result error.

- [ ] **Step 4: Thread an explicit run-active query from Main**

Extend Settings configuration without scene-tree inspection:

```gdscript
func configure(
	store: PartyForgeSettingsStore,
	settings: PartyForgeSettings,
	profile_manager: ProfileManager = null,
	settings_path: String = PartyForgeSettingsStore.DEFAULT_PATH,
	run_active_query: Callable = Callable(),
) -> void:
	_store = store
	_current_settings = settings.copy()
	_draft = _current_settings.copy()
	_profile_manager = profile_manager
	_settings_path = settings_path
	_profiles_page().bind(_profile_manager, run_active_query)
```

In Main:

```gdscript
settings_screen.configure(
	settings_store,
	saved_settings,
	profile_manager,
	settings_path,
	func() -> bool: return run_started,
)
```

Recompute eligibility whenever Settings opens, the selected row changes, profiles change, or a confirmation closes.

- [ ] **Step 5: Run focused and real-settings GREEN gates**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_profiles_settings_page.gd tests/unit/test_profile_manager.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/settings_profiles_navigation_runner.gd
```

Expected: focused `TEST_SUMMARY: PASS (0 failures)` and `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS`.

- [ ] **Step 6: Commit**

```powershell
git add scenes/ui/settings/profiles_settings_page.tscn scripts/ui/settings/profiles_settings_page.gd tests/unit/test_profiles_settings_page.gd scripts/ui/settings/settings_screen.gd tests/unit/test_settings_screen.gd scripts/game/main.gd tests/integration/settings_profiles_navigation_runner.gd
git commit -m "feat: confirm permanent profile deletion"
```

---

### Task 7: Prove the Recovery and Deletion Lifecycle Through Production Scenes

**Files:**

- Create: `tests/integration/run_recovery_profile_lifecycle_runner.gd`
- Modify: `tests/integration/profile_boot_main_flow_runner.gd`
- Create: `docs/verification/2026-08-27-resumable-run-recovery-and-profile-deletion.md`
- Create: `docs/validation/screenshots/run-recovery-profile-lifecycle/resume-run.png`
- Create: `docs/validation/screenshots/run-recovery-profile-lifecycle/legacy-class.png`
- Create: `docs/validation/screenshots/run-recovery-profile-lifecycle/delete-profile.png`

**Interfaces:**

- Consumes: production `res://scenes/game/main.tscn`, public UI signals/buttons, unique injected `profile_root` and `settings_path`, and all services from Tasks 2-6.
- Produces: exact integration markers `RUN_RECOVERY_CURRENT`, `RUN_RECOVERY_LEGACY_CLASS`, `RUN_RECOVERY_ABANDON`, `PROFILE_DELETE_LIFECYCLE`, and `RUN_RECOVERY_PROFILE_LIFECYCLE`.

- [ ] **Step 1: Create isolated production-scene fixtures**

Use one unique root per scenario and assign it before adding Main to the tree:

```gdscript
func _new_main(label: String) -> PartyForgeMain:
	var main := load("res://scenes/game/main.tscn").instantiate() as PartyForgeMain
	var suffix := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	main.profile_root = "user://tests/run_recovery_profile_lifecycle/%s/%s/profiles" % [label, suffix]
	main.settings_path = "user://tests/run_recovery_profile_lifecycle/%s/%s/settings.json" % [label, suffix]
	get_root().add_child(main)
	await process_frame
	return main
```

Drive public controls with `emit_signal("pressed")`, keyboard/controller input events, and awaited frames. Do not call `_ready`, `_process`, `_exit_tree`, private button handlers, checkout, recovery, or deletion services directly.

- [ ] **Step 2: Add current-format restart and Resume Run scenario**

Through normal UI checkout, create a recovery, snapshot run ID/seed/player/member/class/item state, naturally free Main, instantiate a new Main at the same isolated paths, press Resume Run and confirm. Assert runtime identity/state equals the snapshot and the durable transaction journal contains exactly one `run_loadout_checkout` operation.

Print only after all assertions pass:

```gdscript
print("RUN_RECOVERY_CURRENT: PASS")
```

- [ ] **Step 3: Add legacy class bind, restart, and incompatible-class scenarios**

Convert only the isolated fixture recovery to the migrated empty class marker, restart, choose one compatible class through the dialog, restart again, and assert Resume is direct with no second prompt. In a separate fixture, choose an incompatible class and assert the recovery file bytes are unchanged and runtime does not start.

```gdscript
print("RUN_RECOVERY_LEGACY_CLASS: PASS")
```

- [ ] **Step 4: Add confirmed matching abandonment scenario**

Open recovery, press Abandon, cancel once and prove bytes unchanged, then confirm. Assert the exact recovery becomes `{}`, run-owned item IDs are absent from profile storage, and a deliberately mismatched run ID cannot clear it.

```gdscript
print("RUN_RECOVERY_ABANDON: PASS")
```

- [ ] **Step 5: Add inactive, active, final, recovered, damaged, and active-run deletion scenarios**

Use real Settings > Profiles controls. Assert cancel byte preservation; deletion of each health state; most-recent replacement after active deletion; no-profile/create state after final deletion; neighbor bytes unchanged; Delete disabled while `run_started == true`; and keyboard/controller focus restoration.

```gdscript
print("PROFILE_DELETE_LIFECYCLE: PASS")
print("RUN_RECOVERY_PROFILE_LIFECYCLE: PASS")
```

- [ ] **Step 6: Run integration gates until naturally clean**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/settings_profiles_navigation_runner.gd
```

Expected: each required marker appears exactly once, exit code is `0`, and output contains no parser, loader, script, crash, RID, ObjectDB, or resource-retention failure marker.

- [ ] **Step 7: Capture and document player-facing evidence**

Run the same isolated fixture in windowed mode and capture Resume/Abandon, legacy class selection, and named Delete confirmation. Record executable, commit, commands, exit codes, markers, screenshot paths, and whether physical controller verification was exercised. If not physically exercised, label only that manual check `DEFERRED`; do not weaken automated input coverage.

- [ ] **Step 8: Commit integration evidence**

```powershell
git add tests/integration/run_recovery_profile_lifecycle_runner.gd tests/integration/profile_boot_main_flow_runner.gd docs/verification/2026-08-27-resumable-run-recovery-and-profile-deletion.md docs/validation/screenshots/run-recovery-profile-lifecycle
git commit -m "test: cover run recovery and profile deletion"
```

---

### Task 8: Run the Final Recovery and Profile Gate

**Files:**

- Verify: every file changed by Tasks 1-7
- Modify only with measured evidence: `docs/verification/2026-08-27-resumable-run-recovery-and-profile-deletion.md`

**Interfaces:**

- Consumes: all focused suites, integration runners, and exact output markers defined above.
- Produces: a clean branch with fresh import, focused coverage, integration coverage, complete suite, and documented evidence.

- [ ] **Step 1: Run a cold import**

Run:

```powershell
& $godot --headless --editor --path (Get-Location).Path --quit-after 600
```

Expected: exit code `0` and no parser, loader, missing-resource, or script error.

- [ ] **Step 2: Run the complete affected unit batch**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_run_recovery_service.gd tests/unit/test_player_run_context.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 3: Re-run all lifecycle integrations**

Run the three Task 7 commands sequentially. Require every named PASS marker exactly once and exit code `0` for each process.

- [ ] **Step 4: Run the complete unit suite**

Run:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 2400 --script res://tests/test_runner.gd
```

Expected: exactly one `TEST_SUMMARY: PASS (222 suites)` and exactly 222 discovered `tests/unit/*.gd` files. Accept expected negative-path diagnostics only when the exit code and summary are green; reject any parser, loader, script, crash, RID, ObjectDB, or resource-retention marker.

- [ ] **Step 5: Audit scope and repository cleanliness**

Run:

```powershell
git diff --check
git status --short
git log --oneline --decorate -12
```

Verify only implementation, tests, approved screenshots, and verification documentation are tracked. Do not stage `.godot`, `.uid` files created only by import, isolated `user://tests` data, unrelated worktree changes, or files from the live profile root.

- [ ] **Step 6: Record final evidence and commit only if the verification document changed**

Append the exact commands, exit codes, suite count, marker counts, and commit SHA to `docs/verification/2026-08-27-resumable-run-recovery-and-profile-deletion.md`, then:

```powershell
git add docs/verification/2026-08-27-resumable-run-recovery-and-profile-deletion.md
git commit -m "docs: record recovery and deletion verification"
```

If the verification document already contains the final measured evidence, do not create an empty commit.
