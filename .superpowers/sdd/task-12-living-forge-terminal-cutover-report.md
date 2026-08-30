# Task 12 — Living Forge Terminal Cutover Report

Date: 2026-08-30
Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\living-forge-combat-loop-ui`
Approved base and pre-commit parent: `7fd2fd13e33e3cad3679e2ffafc5b0bab906f413`
Scope: Task 12 only. No Task 13 qualification expansion, Task 14 screenshots, tactics/gambits, push, merge, or obsolete result-API compatibility shim was included.

## Delivered contract

- `Main` now owns the terminal sequence: begin, durable initial record, extraction projection, canonical selection, preflight, resolution, exact-profile refresh, durable receipt verification, recap validation, finalize, then and only then disposable-loot/transient cleanup and presentation.
- Hostile effects are cancelled immediately after the `can_begin()` guard and before capture/presentation. A duplicate terminal event returns without cancellation or mutation.
- Boot gives a durable terminal record precedence over restart metadata, ordinary resumable-run recovery, and new-run setup. Pre-resolution records restore their constrained selections; resolved receipts rebuild recap without another resolve or extraction mutation.
- Initial-save failure is retry-save-only. If the write committed but its refresh failed, retry is refresh/rebuild-only and never repeats persistence.
- Projection failure is `Retry Results` only. Same-session and cold retry perform projection work only; they do not resolve or mutate extraction again.
- Automatic-only capacity failure exposes truthful `Protect Displaced Gear`. Protection is authorized only for `RESOLUTION_INTERRUPTED`, refreshes and immediately reruns the same pure preflight, retains protected IDs, clears the old confirmed request/transaction before returning to an editable picker, and uses a distinct resolution-failure persistence phase so no earlier automatic-only result can replay.
- Finalized Restart, Return, and Quit re-read the exact profile and verify the current durable receipt at action time. They clear the receipt durably before routing. A committed clear followed by refresh failure retries refresh plus the exact route only, with one completion call.
- Restart stores and consumes one typed `RunSetupRestartIntent`; it preselects the lobby only and never checks out or starts automatically. Invalid/missing intent data yields an explicit unresolved-selection reason.
- Pre-resolution Return/Quit preserve the terminal receipt. With no current scene, Return re-presents terminal recovery rather than exposing the ordinary front end.
- Active-run `Abandon Run` uses `RunRecoveryService.forfeit(...)` exactly once. A post-forfeit refresh failure leaves the tree paused in a non-dismissible committed state whose only focusable action is `Retry Return to Forge`; retries refresh and route only.
- Finalized receipt-clear failures remain readable without claiming success and restore deterministic action focus.

## Ordering and identity proof

The production and runtime tests bind the following order:

1. `_terminal_flow.can_begin()`
2. `_cancel_hostile_effects()`
3. `_terminal_flow.begin(...)`
4. persist/recover exact terminal record before picker
5. refresh/reconcile selection, acknowledge the exact unused-capacity projection, persist canonical selection
6. pure preflight and one resolution
7. exact-profile refresh and `RESOLVED_AWAITING_PROJECTION` receipt verification
8. `_build_terminal_result(...)` and recap validation
9. `_terminal_flow.finalize()` succeeds
10. `_clear_live_loot()` and final transient cleanup
11. present the finalized projection

Injected recap/finalize failures prove steps 10–11 do not run. Live loot remains during choosing, pending, interruption, failed retry, and failed finalize. Same-session and cold projection retry assert zero additional resolution and zero extraction mutation. All recovery/action tests bind the exact profile ID, run ID, selection/request, stage, protected item IDs, and persistence phase.

The post-Protect resolution-failure regression covers both unchanged and changed selection. Each path proves two selection writes plus one distinct `terminal_resolution_interruption` write, exact durable `RESOLUTION_INTERRUPTED` stage/reason/selection/protected IDs, a separate applied transaction phase, cold `Retry Resolution`, Armoury storage locks for every protected overflow ID, and zero cold replay writes/resolution/revocation.

## RED evidence

All binding RED runs were parser-clean/check-only-clean before behavior execution. Expected negative-path engine diagnostics were present in some fixtures; no RED was accepted for parser, missing-class, or harness noise.

### Initial Task 12 matrix

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_pause_menu.gd
```

Recorded: `TEST_SUMMARY: FAIL (33 failures)`, exit `1`. Failures owned the absent terminal ordering, typed actions, restart intent, and authoritative Abandon contracts.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/live_loot_lifecycle_runner.gd
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/personal_loot_defeat_runner.gd
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_setup_lobby_panel_runner.gd
```

Recorded behavior-owned RED markers, each exit `1`:

- `LIVE_LOOT_LIFECYCLE_INTEGRATION: FAIL (1 failure)`
- `PERSONAL_LOOT_DEFEAT_INTEGRATION: FAIL (1 failure)`
- `FORGE_GUARDIAN_VICTORY_REGRESSION: FAIL (1 failure)`
- `PROFILE_BOOT_MAIN_FLOW_SUMMARY: FAIL (1 failure)`
- `RUN_SETUP_LOBBY_PANEL_SUMMARY: FAIL (1 failure)`

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1500 --script res://tests/integration/run_terminal_flow_runner.gd
```

Recorded: `RUN_TERMINAL_FLOW_SUMMARY: FAIL (20 failures)`, exit `1`, binding terminal sequencing, recovery, retry, cleanup, recap, action-time clear, and route interception.

### Focused defect loops

- Selection reconciliation/acknowledgement: focused RED `FAIL (2 failures)`, exit `1`; the old order acknowledged stale capacity state.
- High-precision durable capture: focused RED `FAIL (1 failure)`, exit `1`; a live affix roll `8.411670327186584` canonicalized through `ProfileCodec`/JSON to `8.41167032718658`. The repair compares canonical boundary forms while genuine one-field drift still rejects.
- Hostile cancellation order: focused RED `FAIL (2 failures)`, exit `1`; victory and defeat both left hostile transients active behind interruption/picker UI.
- Finalized Return route seam: the runtime matrix observed route count `0` because `_return_to_front_end()` bypassed the configured typed reload route.
- Committed refresh/no-scene/protection reset review matrix: check-only exit `0`, then `RUN_TERMINAL_FLOW_SUMMARY: FAIL (7 failures)`, exit `1`. It bound refresh-only retry after committed initial save and committed receipt clear, receipt-locked no-scene Return, and fresh post-Protect canonical selection.
- Responsive integration after the first broad run: full-suite RED `FAIL (29 failures)` was traced to stale fixture paths. The focused responsive RED then reported four exact result-frame size failures; production geometry was not weakened.
- Protected post-Protect resolution interruption unit loop:

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_recovery_safety.gd
```

Recorded: `TEST_SUMMARY: FAIL (7 failures)`, `TASK12_PROTECTED_INTERRUPTION_RED_EXIT:1`. The failures proved submitted/durable protected IDs were lost and an unchanged selection could replay the earlier automatic-only persistence identity.

- Protected interruption Main/cold matrix: check-only exit `0`, then `RUN_TERMINAL_FLOW_SUMMARY: FAIL (13 failures)`, exit `1`. Same- and changed-selection rows bound exact protected IDs, distinct persistence, cold recovery, locks, and zero replay behavior.

## GREEN evidence

### Step 5/Task 12 unit and integration commands

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_pause_menu.gd
```

Recorded: `TEST_SUMMARY: PASS (0 failures)`, `TASK12_STEP5_UNIT_FINAL_EXIT:0`.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/live_loot_lifecycle_runner.gd
```

Recorded: `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`, `TASK12_LIVE_LOOT_REVIEW_EXIT:0`.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/personal_loot_defeat_runner.gd
```

Recorded: `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`, `PERSONAL_LOOT_XP_REGRESSION: PASS`, `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS`, `TASK12_PERSONAL_LOOT_REVIEW_EXIT:0`.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/profile_boot_main_flow_runner.gd
```

Recorded: `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`, `TASK12_PROFILE_BOOT_REVIEW_EXIT:0`.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_setup_lobby_panel_runner.gd
```

Recorded: `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS`, `TASK12_LOBBY_REVIEW_EXIT:0`.

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1500 --script res://tests/integration/run_terminal_flow_runner.gd
```

Final isolated matrix: check-only exit `0`; `RUN_TERMINAL_FLOW_SUMMARY: PASS`; behavior exit `0`; runner diff-check exit `0`. This includes all original Task 12 rows, the committed-initial/completion refresh rows, null-scene receipt locking, post-Protect request reset, and both protected resolution-interruption cold-recovery rows.

### Focused repair and adjacent gates

- Result projection/panel/terminal/Main aggregate: `TEST_SUMMARY: PASS (0 failures)`, `TASK12_REVIEW_FOCUSED_EXIT:0`.
- Result lifecycle runner: `RUN_RESULT_LIFECYCLE_SUMMARY: PASS`, `TASK12_RESULT_LIFECYCLE_REVIEW_EXIT:0`.
- Responsive UI focused suite: `TEST_SUMMARY: PASS (0 failures)`, `TASK12_RESPONSIVE_UI_GREEN_EXIT:0`.
- Protected interruption unit rerun: `TEST_SUMMARY: PASS (0 failures)`, `TASK12_PROTECTED_INTERRUPTION_GREEN_EXIT:0`.
- Main parser/check-only after protected interruption repair: `TASK12_PROTECTED_INTERRUPTION_CHECK_EXIT:0`.

### Task 7/10 exact focused slice

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_recovery_safety.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_mutation_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_armoury_screen.gd tests/unit/test_main_wiring.gd
```

Recorded terminal output: `TEST_SUMMARY: PASS (0 failures)`, `TASK12_TASK7_10_17_FINAL_EXIT:0`.

### Full suite

```powershell
& $godotExe --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
```

Recorded terminal output: `TEST_SUMMARY: PASS (255 suites)`, `TASK12_FULL_SUITE_FINAL_EXIT:0`. Expected negative-path test diagnostics were emitted; there were no suite failures, script errors, or parse failures.

## UID and hygiene audit

Godot import completed with exit `0`. Generated sidecars were classified; only the two planned UIDs remain new:

```text
UNTRACKED_UID_COUNT:2
scripts/ui/run_setup/run_setup_restart_intent.gd.uid
tests/integration/run_terminal_flow_runner.gd.uid
TRACKED_UID_COUNT:846
FILESYSTEM_UID_COUNT:848
DUPLICATE_UID_VALUE_COUNT:0
UID:scripts/ui/run_setup/run_setup_restart_intent.gd.uid:uid://da1p4q4ywb7qe
UID:tests/integration/run_terminal_flow_runner.gd.uid:uid://dcwok0o5mn276
TASK12_UID_AUDIT_EXIT:0
```

`git diff --check` recorded `TASK12_DIFF_CHECK_EXIT:0`. Historical reports were not edited or removed.

## Review disposition and remaining concerns

- UI/UX review: approved after immediate hostile cancellation, operation-accurate pending copy/focus, readable finalized-action errors, exact Abandon committed state, and truthful Protect/Armoury behavior were bound.
- Code/spec review: final approval with no findings after the protected-ID/distinct-phase repair and expanded executable Main matrix.
- Task 14 visual evidence remains intentionally deferred. Its later evidence matrix should add committed-Abandon retry and restart-lobby valid/unresolved states.
- No unsupported recap fields or claims were added.
