# Interrupted Run Recovery and Profile Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let interrupted durable runs recover without a second checkout, let players permanently delete any selected profile with confirmation, and prevent tests from polluting real profile storage.

**Architecture:** Extend the strict resumable document with a selected leader class, migrate schema-four profiles deterministically, and add a recovery service that validates/binds/bootstraps an existing checkout. Main routes durable recovery directly into context creation. Add a confined permanent-deletion service behind `ProfileManager`; the Profiles page owns confirmation and run-active gating. Test fixtures use unique `user://tests/...` roots.

**Tech Stack:** Godot 4.7.1, typed GDScript, strict JSON codecs/migrations, `AtomicJsonStore`, profile mutation services, `.tscn` UI, focused and real scene-tree integration runners.

## Global Constraints

- Implement only in the isolated `feat/playtest-recovery-loot-ui` worktree.
- Follow strict RED-GREEN-REFACTOR and commit small verified increments.
- Preserve strict run identity and item ownership; resume must never call checkout again.
- Recovery restarts arena simulation from the beginning. Do not claim timer/wave/enemy/upgrade/health/position/ground-drop restoration.
- A legacy class choice must be durably committed before context creation.
- Abandon permanently forfeits the matching run-owned state only after explicit confirmation.
- Profile deletion is permanent, exact-ID confined, disabled during an arena run, and never accepts arbitrary paths.
- Do not weaken damaged-profile activation rules merely to make damaged profiles deletable.
- Do not build a production sentinel cleaner. Local cleanup is an exact-name plus exact-byte verification step only.
- Never test against `ProfileStore.DEFAULT_ROOT`.

---

## Task 1: Isolate developer-sandbox tests from real profiles

**Files:**

- Modify: `tests/unit/test_developer_item_sandbox_state.gd`
- Verify: `scripts/profile/profile_store.gd`

- [ ] **Step 1: Add a failing path contract before changing fixtures**

Centralize a unique test root created once during fixture setup, such as:

```gdscript
const TEST_ROOT_PREFIX := "user://tests/developer_item_sandbox_state"
var _test_root := ""

func _begin_fixture() -> void:
    _test_root = TEST_ROOT_PREFIX.path_join("%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
```

Add an assertion that every sandbox sentinel and profile-preservation fixture begins with `user://tests/` and does not begin with `ProfileStore.DEFAULT_ROOT`.

- [ ] **Step 2: Run RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd
```

Expected: sentinel path assertions fail because two fixtures still use `ProfileStore.DEFAULT_ROOT`.

- [ ] **Step 3: Move every sentinel into the unique test root**

Preserve the exact isolation intent and payload assertions, but create/clean the entire unique test directory in fixture setup/teardown. Do not touch normal profile files.

- [ ] **Step 4: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (0 failures)` and no new file under `user://profiles`.

```powershell
git add tests/unit/test_developer_item_sandbox_state.gd
git commit -m "test: isolate sandbox profile sentinels"
```

---

## Task 2: Version the strict resumable document with leader class identity

**Files:**

- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_migrator.gd`
- Modify: `scripts/run/run_item_bootstrap.gd`
- Modify: `scripts/run/resumable_run_item_codec.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Modify: `tests/unit/test_profile_state.gd`
- Modify: `tests/unit/test_profile_item_schema_migration.gd`
- Modify: `tests/unit/test_atomic_profile_store.gd`
- Modify: `tests/unit/test_run_loadout_checkout_service.gd`

- [ ] **Step 1: Write migration and strict-codec REDs**

Add tests proving:

1. current resumable documents require exact field `selected_leader_class_id`;
2. new checkout writes the selected class from `RunLoadoutCheckoutRequest`;
3. schema-four documents migrate to schema five with `selected_leader_class_id = ""` inside a nonempty legacy recovery;
4. empty recoveries remain empty;
5. migration preserves run ID, seed, player/member IDs, registry, containers, slots, and item bytes semantically;
6. unknown/non-string class values fail closed.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd
```

Expected: schema/version/class-field assertions fail; no unrelated parse failure.

- [ ] **Step 3: Implement schema five and typed bootstrap class identity**

Add `selected_leader_class_id: StringName` to `RunItemBootstrap.create(...)`. Make current `ResumableRunItemCodec.FIELDS` include the class field and encode/decode it. The codec accepts either an empty legacy marker or a syntactically valid nonempty string; known-class validation belongs to the recovery service because the codec must remain data-layer only. New checkout code must never emit the empty marker.

Advance `ProfileState.SCHEMA_VERSION` to 5 and add a 4-to-5 migration that injects the empty marker only when `resumable_run` is nonempty. Update historical fixture construction so older documents do not accidentally retain future-only fields.

- [ ] **Step 4: Make checkout always write a nonempty class**

Thread `request.selected_leader_class_id` into `RunItemBootstrap`. Preserve all existing transfer/eligibility/forfeit behavior.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
```

Expected: `PASS (0 failures)`.

```powershell
git add scripts/profile/profile_state.gd scripts/profile/profile_codec.gd scripts/profile/profile_migrator.gd scripts/run/run_item_bootstrap.gd scripts/run/resumable_run_item_codec.gd scripts/run/run_loadout_checkout_service.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd
git commit -m "feat: persist resumable run leader class"
```

---

## Task 3: Add an atomic durable-run recovery service

**Files:**

- Create: `scripts/run/run_recovery_result.gd`
- Create: `scripts/run/run_recovery_service.gd`
- Create: `tests/unit/test_run_recovery_service.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Modify: `tests/unit/test_run_loadout_checkout_service.gd`

- [ ] **Step 1: Define and test the service contract**

Use a typed result with codes `READY`, `CLASS_REQUIRED`, `INVALID`, and `PERSISTENCE_FAILED`, plus copied `profile`, `bootstrap`, `selected_leader_class_id`, and `error` fields.

Public service surface:

```gdscript
func inspect(profile: ProfileState) -> RunRecoveryResult
func bind_legacy_class(profile_id: String, class_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> RunRecoveryResult
func forfeit(profile_id: String, run_id: StringName, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult
```

`inspect` validates the strict bootstrap, run/profile ownership, class existence, and equipment eligibility. `bind_legacy_class` uses an atomic profile mutation with a deterministic transaction fingerprint and writes only the empty class marker. It must reject a changed run, nonempty existing class, unknown class, or incompatible checked-out equipment without mutating storage.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recovery_service.gd
```

Expected: suite fails to load because the service/result are absent.

- [ ] **Step 3: Implement the minimal service**

Reuse `RunLoadoutCheckoutService.bootstrap_from()` and strict forfeit rather than duplicating ownership decoding. Persist legacy binding before returning READY. Return copies so UI code cannot mutate stored state.

- [ ] **Step 4: Prove capacity normalization and no second checkout**

Add tests that a recovered zero-capacity run remains byte-stable in storage, then `PlayerRunContext.configure(..., run_inventory_minimum_capacity = 5)` supplies five runtime slots in Developer Mode without changing `ProfileState.inventory_columns`. Add a spy mutation service and assert recovery performs zero checkout operations.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recovery_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
git add scripts/run/run_recovery_result.gd scripts/run/run_recovery_service.gd tests/unit/test_run_recovery_service.gd scripts/run/run_loadout_checkout_service.gd tests/unit/test_run_loadout_checkout_service.gd
git commit -m "feat: recover durable run checkout state"
```

---

## Task 4: Route Play to Resume, class binding, or Abandon

**Files:**

- Modify: `scripts/ui/main_menu/main_menu_view_model.gd`
- Modify: `tests/unit/test_main_menu_view_model.gd`
- Create: `scenes/ui/run_recovery/run_recovery_dialog.tscn`
- Create: `scripts/ui/run_recovery/run_recovery_dialog.gd`
- Create: `tests/unit/test_run_recovery_dialog.gd`
- Modify: `scenes/game/main.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_main_loadout_checkout_recovery.gd`

- [ ] **Step 1: Add main-menu projection RED**

For every valid profile state, a nonempty valid `resumable_run` must override normal Play routing:

```gdscript
TestAssertions.equal(projection.primary_label, "Resume Run", "durable recovery overrides new run", failures)
TestAssertions.equal(projection.primary_route_id, MainMenuViewModel.ROUTE_RUN_RECOVERY, "resume route is explicit", failures)
```

Invalid/damaged recovery must not silently route to a new checkout; it still opens recovery with an error/Abandon path.

- [ ] **Step 2: Add dialog and Main REDs**

Test three dialog modes:

- future recovery: Resume Run / Abandon Run;
- legacy recovery: Choose Class to Recover Run, then Resume/Abandon;
- invalid recovery: failure detail plus Abandon, no start.

Abandon confirmation must contain the active profile display name and the sentence that run-owned items will be permanently lost.

In Main tests, inject a checkout spy and assert durable resume creates the context with original run ID/seed/player/member/item state and checkout call count remains zero.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd
```

- [ ] **Step 4: Implement recovery routing**

Add `ROUTE_RUN_RECOVERY`. `_on_prologue_resume_requested()` and completed-profile Play must open the recovery dialog, not `_open_run_setup()`.

Refactor the current durable half of `_resume_pending_checkout()` into a shared private start function that accepts an already committed profile, class definition, and bootstrap. Same-process checkout retry and after-restart recovery both call that start function; only new runs call `_checkout_and_start_leader_class()`.

For legacy recovery, persist the class through `RunRecoveryService.bind_legacy_class()` first, refresh `ProfileManager`, inspect again, then create context. Context failure keeps the recovery intact.

For Abandon, call strict forfeit using the decoded matching run ID. Refresh the manager only after a committed result. Failure leaves dialog/recovery available.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_run_recovery_service.gd
git add scripts/ui/main_menu/main_menu_view_model.gd tests/unit/test_main_menu_view_model.gd scenes/ui/run_recovery/run_recovery_dialog.tscn scripts/ui/run_recovery/run_recovery_dialog.gd tests/unit/test_run_recovery_dialog.gd scenes/game/main.tscn scripts/game/main.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd
git commit -m "feat: resume or abandon interrupted runs"
```

---

## Task 5: Add exact, permanent profile artifact deletion

**Files:**

- Create: `scripts/profile/profile_deletion_result.gd`
- Create: `scripts/profile/profile_deletion_service.gd`
- Create: `tests/unit/test_profile_deletion_service.gd`
- Modify: `scripts/profile/profile_store.gd`
- Modify: `scripts/profile/profile_manager.gd`
- Modify: `tests/unit/test_profile_manager.gd`

- [ ] **Step 1: Add deletion-service REDs**

Cover:

- healthy primary plus backup deletion;
- backup-only recovered profile deletion;
- damaged discovered profile deletion;
- active profile deletion selects most-recent remaining profile;
- final profile deletion leaves no active profile;
- neighboring profile bytes are unchanged;
- path-like/undiscovered IDs fail before filesystem mutation;
- injected remove failure before any erasure is noncommitted;
- verified artifact erasure followed by index-save failure reports `committed = true` and cleanup debt.

- [ ] **Step 2: Define the exact artifact allowlist**

For `primary = ProfileStore.profile_path(profile_id, root)`, permit only these same-profile paths:

```text
primary
primary.bak
primary.tmp
primary.bak.previous
primary.irreversible-primary.tmp
primary.irreversible-backup.tmp
primary.corrupt-<digits>
primary.bak.corrupt-<digits>
```

Enumerate timestamped corrupt artifacts only by listing the exact root directory and matching the escaped basename plus digits. Reject separators, traversal, drive prefixes, and IDs not discovered during manager bootstrap.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd
```

- [ ] **Step 4: Implement service and manager orchestration**

Expose:

```gdscript
func delete_profile(profile_id: String) -> ProfileDeletionResult
```

`ProfileManager` supplies the service only an ID present in `_profile_statuses`, plus copied remaining profiles and the next active ID. The service erases the allowlisted artifacts irreversibly and persists a rebuilt index. Manager removes memory/status entries after the committed boundary, emits `profiles_changed`, and emits `active_profile_changed(next_profile)` only when one exists.

If index persistence fails after all exact artifacts are verified absent, keep the deletion committed, rebuild in-memory state, and expose cleanup debt; the deleted profile must not return during the process.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_atomic_profile_store.gd
git add scripts/profile/profile_deletion_result.gd scripts/profile/profile_deletion_service.gd tests/unit/test_profile_deletion_service.gd scripts/profile/profile_store.gd scripts/profile/profile_manager.gd tests/unit/test_profile_manager.gd
git commit -m "feat: permanently delete selected profiles"
```

---

## Task 6: Add delete selection and confirmation to Profiles settings

**Files:**

- Modify: `scenes/ui/settings/profiles_settings_page.tscn`
- Modify: `scripts/ui/settings/profiles_settings_page.gd`
- Modify: `tests/unit/test_profiles_settings_page.gd`
- Modify: `tests/integration/settings_profiles_navigation_runner.gd`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify if required for a public run-active query: `scripts/game/main.gd`

- [ ] **Step 1: Add UI REDs**

Assert:

- `Delete Selected Profile` is disabled with no selection or while a run is active;
- selecting healthy/recovered/damaged rows enables Delete when safe;
- damaged remains disabled for Activate but selectable for Delete;
- confirmation names the profile and says deletion is permanent;
- cancel preserves all bytes/index/selection;
- confirm calls manager once and refreshes focus;
- deleting active chooses the next recent profile;
- deleting last shows the existing no-profile/create state.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_profiles_settings_page.gd
```

- [ ] **Step 3: Implement separate activation and deletion eligibility**

Do not disable damaged `ItemList` rows. Instead, let rows be selected and gate `_activate_button()` using `ProfileEntryStatus.selectable()`. Gate Delete using discovered status plus `not run_active`.

Add a modal `ConfirmationDialog`. Keep selection/focus on failure and show the existing safe/technical error channels. On last deletion, focus the profile-name field.

Pass run-active state through the settings screen/page configuration as a callable or explicit setter; do not let the page inspect the scene tree or Main globals.

- [ ] **Step 4: Run GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_profiles_settings_page.gd tests/unit/test_profile_manager.gd tests/unit/test_settings_screen.gd
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/integration/settings_profiles_navigation_runner.gd
git add scenes/ui/settings/profiles_settings_page.tscn scripts/ui/settings/profiles_settings_page.gd tests/unit/test_profiles_settings_page.gd tests/integration/settings_profiles_navigation_runner.gd scripts/ui/settings/settings_screen.gd scripts/game/main.gd
git commit -m "feat: confirm permanent profile deletion"
```

Stage only files actually changed.

---

## Task 7: Add end-to-end recovery and profile lifecycle coverage

**Files:**

- Modify: `tests/integration/profile_boot_main_flow_runner.gd`
- Create: `tests/integration/run_recovery_profile_lifecycle_runner.gd`
- Create or modify: `docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md`

- [ ] **Step 1: Build real scene-tree scenarios**

Use a unique profile root and production Main scene. Cover:

1. create future-format recovery, restart Main, Resume, original run identity/item state, zero second checkouts;
2. create legacy recovery, restart, prompt, bind Ranger or Mage, restart again, direct Resume without reprompt;
3. legacy incompatible class choice fails without changing recovery;
4. Developer Mode zero-slot recovery yields runtime minimum five and does not change persistent `inventory_columns`;
5. Abandon confirmation clears only the matching recovery;
6. delete inactive, active, final, and damaged profiles through real Settings controls;
7. deletion controls stay disabled while `run_started` is true.

Use root `add_child`, `await process_frame`, real button events, and natural queue-free teardown. Do not call `_ready`, `_process`, `_exit_tree`, private button handlers, checkout, or delete services directly in this runner.

- [ ] **Step 2: Run integration RED/GREEN while implementing fixtures**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/profile_boot_main_flow_runner.gd
```

Expected final markers:

```text
RUN_RECOVERY_FUTURE: PASS
RUN_RECOVERY_LEGACY_CLASS: PASS
RUN_RECOVERY_ABANDON: PASS
PROFILE_DELETE_LIFECYCLE: PASS
RUN_RECOVERY_PROFILE_LIFECYCLE: PASS
```

- [ ] **Step 3: Record recovery/delete screenshots**

Capture the Resume/Abandon dialog, legacy class prompt, and named permanent-delete confirmation using an isolated test profile. Mark manual controller verification DEFERRED if not physically exercised.

- [ ] **Step 4: Commit integration evidence**

```powershell
git add tests/integration/profile_boot_main_flow_runner.gd tests/integration/run_recovery_profile_lifecycle_runner.gd docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md docs/validation/screenshots/playtest-recovery
git commit -m "test: cover run recovery and profile deletion"
```

---

## Task 8: Verify and clean only known local sentinel pollution

- [ ] **Step 1: Run the complete affected unit gate**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_run_recovery_service.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_main_wiring.gd
```

- [ ] **Step 2: Run both integration runners in isolated app-data roots**

Run `run_recovery_profile_lifecycle_runner.gd` and `settings_profiles_navigation_runner.gd` with unique `APPDATA`/`LOCALAPPDATA`. Require the exact markers from Task 7.

- [ ] **Step 3: Run cold import, complete suite, and boot smoke**

```powershell
$verificationRoot = Join-Path $env:TEMP ("party-forge-recovery-final-" + [guid]::NewGuid().ToString('N'))
$appData = Join-Path $verificationRoot 'AppData'
$localAppData = Join-Path $verificationRoot 'LocalAppData'
New-Item -ItemType Directory -Force -Path $appData,$localAppData | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = $appData
$env:LOCALAPPDATA = $localAppData
try {
    & $godot --headless --editor --path (Get-Location).Path --quit-after 180
    if ($LASTEXITCODE -ne 0) { throw "Cold import failed: $LASTEXITCODE" }
    & $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
    if ($LASTEXITCODE -ne 0) { throw "Full suite failed: $LASTEXITCODE" }
    & $godot --headless --path (Get-Location).Path --quit-after 120
    if ($LASTEXITCODE -ne 0) { throw "Boot smoke failed: $LASTEXITCODE" }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
```

Expected: exact updated suite-count PASS, boot-ready markers, and zero parser/script/loader/RID/ObjectDB/resource-leak markers.

- [ ] **Step 4: Audit the real profile root read-only**

List files matching only:

```text
task-8-isolation-sentinel-*.json
task-11-reset-isolation-sentinel-*.json
```

For each candidate, verify the basename matches exactly and bytes are exactly `task-8-profile-bytes` or `task-11-active-profile-bytes` respectively. Print the resolved absolute paths and hashes before any deletion.

- [ ] **Step 5: Remove only verified known sentinels**

Delete only candidates that passed both exact-name and exact-byte checks. Preserve every other file. Report the removed paths and that deletion is permanent. Re-bootstrap the live profile list read-only and confirm the sentinel-related damaged entries disappear while real profiles remain.

- [ ] **Step 6: Final scope review**

```powershell
git diff --check
git status --short
git log --oneline --decorate -12
```

Verify no profile file, `.godot` cache, `.uid` sidecar generated by import, temporary app-data root, or local screenshot outside the documented evidence folder is staged.
