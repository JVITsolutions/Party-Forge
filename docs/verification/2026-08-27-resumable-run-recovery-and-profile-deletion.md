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
