# Resumable Run Recovery and Profile Deletion Verification

## Provenance

- Date: 2026-08-27 (America/New_York)
- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\resumable-run-profile-deletion`
- Production implementation HEAD under test: `7d66007830834bb32d00081a886f158e6b14186f`
- Task 7 evidence commit subject: `test: cover run recovery and profile deletion` (the exact created commit is recorded in `.superpowers/sdd/task-7-implementer-report.md` because a commit cannot contain its own hash)
- Executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Engine: `Godot 4.7.1.stable.mono.official.a13da4feb`

Every production `Main` instance received a unique `user://tests/run_recovery_profile_lifecycle/<scenario>/<pid>-<ticks>-<counter>/profiles` root and sibling `settings.json` before entering the tree. The profile-boot regression runner now follows the same profile/settings isolation rule. No live `user://profiles`, settings, or developer-item-sandbox document was opened or mutated.

## RED to GREEN

The new runner first exited `1` with exactly one intentional failure: `Task 7 production-scene lifecycle scenarios are not implemented`. After implementation, the exact gates below exited `0`. Actions are driven through production controls/signals plus awaited keyboard/controller events; the runner does not call lifecycle callbacks, private UI handlers, checkout/recovery/deletion services, or direct production mutation handlers.

## Headless integration gates

Run sequentially from the worktree:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/settings_profiles_navigation_runner.gd
```

| Gate | Exit | Exact accepted markers |
| --- | ---: | --- |
| Recovery/profile lifecycle | `0` | `RUN_RECOVERY_CURRENT: PASS` x1; `RUN_RECOVERY_LEGACY_CLASS: PASS` x1; `RUN_RECOVERY_ABANDON: PASS` x1; `PROFILE_DELETE_LIFECYCLE: PASS` x1; `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS` x1 |
| Profile boot/main flow | `0` | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` x1 |
| Settings/Profile navigation | `0` | `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS` x1 |

Across all three logs, the case-insensitive scan for parser, loader, script, crash, RID, ObjectDB, and resource-retention failure markers returned `0`. The lifecycle runner intentionally exercises and verifies three rejected paths which emit structured production diagnostics: incompatible legacy class, mismatched abandonment run ID, and damaged profile bootstrap.

## Scenario evidence

- Current recovery: normal Profiles and Fighter controls create the durable checkout; natural restart and Resume Run preserve run ID, seed, player ID, member ID, class, and exact item-state document. The durable journal has exactly one `run_loadout_checkout` before and after resume.
- Legacy recovery: an isolated schema-four recovery migrates to the empty class marker, binds Fighter through the visible dialog, persists across another restart, and then offers direct Resume. A separate Fighter-incompatible vestment fixture keeps exact bytes and never starts runtime.
- Abandonment: keyboard cancel preserves bytes and returns focus; a changed run ID rejects the cached abandonment; restart plus matching confirmation clears recovery and removes the run-owned item ID from current and historical profile storage.
- Deletion: real Settings > Profiles controls cover inactive, active, final, recovered, damaged, and active-run states; cancel bytes, neighbor bytes, most-recent replacement, empty create state, disabled active-run Delete, and keyboard/controller focus restoration are asserted.

## Windowed player-facing evidence

Command (exit `0`; all five lifecycle markers exactly once; forbidden scan `0`):

```powershell
& $godot --windowed --resolution 1280x720 --position 40,40 --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd -- --capture-evidence
```

The PNGs were captured from the rendered production viewport only while the corresponding isolated fixture UI was open, then visually inspected:

| Screenshot | Player-facing proof | SHA-256 |
| --- | --- | --- |
| `docs/validation/screenshots/run-recovery-profile-lifecycle/resume-run.png` | Recover Interrupted Run with Resume Run, Abandon Run, and Cancel | `9F91DE52501E8478C4C33D05CBF4974E849A2DF772F325A6C9D99FCF0464616F` |
| `docs/validation/screenshots/run-recovery-profile-lifecycle/legacy-class.png` | Legacy leader-class picker with Bind Class and Resume | `23A11A119BEFF5FCC565D26C0F107720C8C77DD2538FBDC57566EFABBEB462AC` |
| `docs/validation/screenshots/run-recovery-profile-lifecycle/delete-profile.png` | Named `Lifecycle Active` permanent-delete confirmation | `56C49FDE7BA6B5A86CB5B786FF421905B38D4BFE2047402AB0278BAC4162C5E7` |

Automated keyboard and controller-button/shoulder events passed in the production scene. Physical-controller manual check: **DEFERRED**; no other acceptance check is deferred.

## Task 8 final recovery and profile gate

- Final gate date: 2026-08-27 (America/New_York)
- Pre-document commit under test: `694de5c37f3fb117254d6e6cb524315ee442acec`
- Executable/version preflight: `Godot_v4.7.1-stable_mono_win64_console.exe --version` exited `0` and printed `4.7.1.stable.mono.official.a13da4feb`.
- Full process output is retained in ignored `.superpowers/sdd/task-8-*.log` files. `git check-ignore` for the first log exited `0`.

The exact Godot commands were run from the worktree in this order:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --editor --path (Get-Location).Path --quit-after 600
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_run_recovery_service.gd tests/unit/test_player_run_context.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/settings_profiles_navigation_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 2400 --script res://tests/test_runner.gd
```

| Gate/log | Process exit | Exact measured result |
| --- | ---: | --- |
| Cold import / `task-8-cold-import.log` | `0` | parser/loader/missing-resource/script forbidden markers `0` |
| Exact 15-suite affected batch / `task-8-affected-15.log` | `0` | `TEST_SUMMARY: PASS (0 failures)` x1; forbidden parser/loader/script/crash/RID/ObjectDB/resource-retention markers `0` |
| Recovery/profile lifecycle / `task-8-integration-lifecycle.log` | `0` | `RUN_RECOVERY_CURRENT: PASS` x1; `RUN_RECOVERY_LEGACY_CLASS: PASS` x1; `RUN_RECOVERY_ABANDON: PASS` x1; `PROFILE_DELETE_LIFECYCLE: PASS` x1; `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS` x1; forbidden markers `0` |
| Profile boot/main flow / `task-8-integration-profile-boot.log` | `0` | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` x1; forbidden markers `0` |
| Settings/Profile navigation / `task-8-integration-settings-navigation.log` | `0` | `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS` x1; forbidden markers `0` |
| Complete unit suite / `task-8-full-unit.log` | `0` | `TEST_SUMMARY: PASS (222 suites)` x1; discovered `tests/unit/*.gd` files `222`; forbidden markers `0` |

The complete suite emitted 105 expected negative-path `ERROR:` lines and 10 warnings. They are accepted only with the green process/summary evidence above; none matched parser, loader, script, crash, RID, ObjectDB, or resource-retention failure markers. The lifecycle integration's expected diagnostics were the incompatible legacy class, mismatched abandonment run ID, and damaged-profile bootstrap paths.

Repository audit commands and measured process exits:

```powershell
git diff --check                         # exit 0
git status --short                      # exit 0
git log --oneline --decorate -12        # exit 0
git merge-base main HEAD                # exit 0
git diff --name-status b7b20200e8c3a24d85f40372cc2632c5f41d0715..HEAD # exit 0
```

The merge base was `b7b20200e8c3a24d85f40372cc2632c5f41d0715`. Tracked scope contains implementation, tests, the corrected implementation plan, three approved screenshots, and verification documentation; tracked `.uid` count is `0`. Before this document edit, status contained exactly 21 generated untracked `.uid` files and no other entry. None was staged. No `.godot`, isolated `user://tests` data, unrelated worktree change, or live profile-root file was tracked or accessed by this gate.

## Post-review fix final gate

- Final gate date: 2026-08-27 (America/New_York)
- Implementation commit under test: `13fd79a11d3dd706c7ced68d26a2e35fe22f8b88`
- Executable/version preflight: `Godot_v4.7.1-stable_mono_win64_console.exe --version` exited `0` and printed `4.7.1.stable.mono.official.a13da4feb`.
- Full logs: ignored `.superpowers/sdd/post-fix-final-*.log`.

The exact Task 8 sequence was rerun from the worktree in order:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --editor --path (Get-Location).Path --quit-after 600
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_run_recovery_service.gd tests/unit/test_player_run_context.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_run_recovery_dialog.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_profile_deletion_service.gd tests/unit/test_profile_manager.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/settings_profiles_navigation_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 2400 --script res://tests/test_runner.gd
```

| Gate/log | Process exit | Exact measured result |
| --- | ---: | --- |
| Cold import / `post-fix-final-cold-import.log` | `0` | parser/loader/missing-resource/script forbidden markers `0` |
| Exact 15-suite affected batch / `post-fix-final-affected-15.log` | `0` | `TEST_SUMMARY: PASS (0 failures)` x1; forbidden parser/loader/script/crash/RID/ObjectDB/resource-retention markers `0` |
| Recovery/profile lifecycle / `post-fix-final-integration-lifecycle.log` | `0` | `RUN_RECOVERY_CURRENT: PASS` x1; `RUN_RECOVERY_LEGACY_CLASS: PASS` x1; `RUN_RECOVERY_ABANDON: PASS` x1; `PROFILE_DELETE_LIFECYCLE: PASS` x1; `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS` x1; forbidden markers `0` |
| Profile boot/main flow / `post-fix-final-integration-profile-boot.log` | `0` | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` x1; forbidden markers `0` |
| Settings/Profile navigation / `post-fix-final-integration-settings-navigation.log` | `0` | `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS` x1; forbidden markers `0` |
| Complete unit suite / `post-fix-final-full-unit.log` | `0` | `TEST_SUMMARY: PASS (222 suites)` x1; discovered `tests/unit/*.gd` files `222`; forbidden markers `0` |

The complete suite again emitted 105 expected negative-path `ERROR:` lines and 10 warnings. None matched the forbidden parser, loader, script, crash, RID, ObjectDB, or resource-retention markers. Across the three sequential integration logs, every required accepted marker appeared exactly once and the combined forbidden scan returned `0`.

Repository audit commands and measured process exits:

```powershell
git diff --check                         # exit 0
git status --short                      # exit 0
git log --oneline --decorate -12        # exit 0
git merge-base main HEAD                # exit 0
git diff --name-status b7b20200e8c3a24d85f40372cc2632c5f41d0715..HEAD # exit 0
git diff --name-only b7b20200e8c3a24d85f40372cc2632c5f41d0715..HEAD -- '*.uid' # exit 0
```

The merge base remained `b7b20200e8c3a24d85f40372cc2632c5f41d0715`. Before this section was appended, tracked and staged working-tree diffs were empty. Branch-scope tracked `.uid` count was `0`; status contained exactly 21 generated untracked `.uid` files and no other entry, and none was staged. The gate used only the worktree project path and isolated test roots; it did not access live profile, settings, or developer-sandbox roots.
