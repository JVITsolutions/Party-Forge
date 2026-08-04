# Plan 4A run-context character progression verification

Verified on 2026-08-04 with Godot `4.7.1.stable.mono.official.a13da4feb` in the isolated `run-context-character-progression` worktree.

## Tested code identity

The exact tested code commit is `f68dca131dbd13d7a93b950e1dc2bef7e49ccb6b` (`test: add run context progression harnesses`). It contains the three Task 9 integration runners and their three intentional Godot UID sidecars. This verification document is committed as its documentation-only child, so the tested production and runner code is unchanged between the evidence commit and the verification commit.

All Godot commands used worktree-local, isolated roots:

```powershell
$env:APPDATA = Join-Path $project '.superpowers\sdd\plan4a-task-9-exact-appdata-f68dca1'
$env:LOCALAPPDATA = Join-Path $project '.superpowers\sdd\plan4a-task-9-exact-localappdata-f68dca1'
```

## Exact-head gate results

| Gate | Exact command | Exit | Required evidence |
| --- | --- | ---: | --- |
| Full import | `& $godot --headless --path $project --import` | 0 | No loader, parse, script, or failed-resource matches |
| Complete suite | `& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd` | 0 | `TEST_SUMMARY: PASS (120 suites)`; no forbidden matches |
| Two-context harness | `& $godot --headless --path $project --quit-after 120 --script res://tests/integration/run_context_harness_runner.gd` | 0 | `RUN_CONTEXT_HARNESS_SUMMARY: PASS contexts=2` |
| Production Arena smoke | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/progression_arena_smoke_runner.gd` | 0 | `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS` |
| Progressive load baseline | `& $godot --headless --path $project --quit-after 300 --script res://tests/integration/progression_24_member_runner.gd` | 0 | Four size markers and `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Existing 24-member ledger | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/ledger_24_member_runner.gd` | 0 | `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)` |
| Startup smoke | `& $godot --headless --path $project --editor --quit-after 2` | 0 | No loader, parse, script, or failed-resource matches |
| Whitespace | `git diff --check` | 0 | No output |

The accepted logs are `.superpowers/sdd/plan4a-task-9-exact-import-valid.log`, `plan4a-task-9-exact-full-suite-valid.log`, `plan4a-task-9-exact-run-context-valid.log`, `plan4a-task-9-exact-arena-smoke-180.log`, `plan4a-task-9-exact-progression-24-valid.log`, `plan4a-task-9-exact-ledger-24-180.log`, `plan4a-task-9-exact-startup-valid.log`, and `plan4a-task-9-exact-diff-check-valid.log`. Each command log records `TASK9_EXIT_CODE=0` where applicable. These ignored local logs are evidence, not release artifacts.

The Arena smoke exercised the production main scene, Fighter selection, one locked context, compatibility party access, actor binding and availability, a production-configured experience orb, the level-up state and panel, HUD XP projection, and the production ledger's `Class Growth` source. Run progression changed neither the selected profile values nor its bytes:

```text
PROGRESSION_ARENA_PROFILE_IMMUTABLE profile=profile-plan4a-task9-smoke sha256_before=4737b1eb1f77a941c199f80c6e1b9b9b3e8d2b11e14384931723c631f5824e9d sha256_after=4737b1eb1f77a941c199f80c6e1b9b9b3e8d2b11e14384931723c631f5824e9d values_equal=true bytes_equal=true
```

## Progressive load baseline

These are observed headless timings, not pass/fail performance thresholds. Each size ran 120 physics frames with production Leader/Companion scenes, independent contexts and parties, multiple progression levels including milestone growth, and production ledger projection. The runner fails on correctness errors, missing rows, ownership contamination, nonfinite metrics, or timeout.

| Members | Contexts | Actors | Progression (us) | Ledger refresh (us) | Process avg/max (ms) | Physics avg/max (ms) | Static/max memory (bytes) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 1 | 526 | 2,714 | 0.140767 / 0.165000 | 50.345133 / 100.517000 | 114,287,194 / 116,775,851 |
| 6 | 1 | 6 | 2,385 | 3,276 | 0.483908 / 0.637000 | 101.069467 / 208.871000 | 118,947,728 / 118,969,632 |
| 12 | 2 | 12 | 4,965 | 6,008 | 1.159200 / 1.393000 | 117.206875 / 359.833000 | 124,312,692 / 124,348,080 |
| 24 | 4 | 24 | 9,615 | 13,885 | 2.368883 / 2.911000 | 156.768117 / 605.286000 | 135,049,056 / 135,084,444 |

## Sidecars, diagnostics, and changed-file review

The verification import exposed 591 untracked `.import` files and 41 untracked `.gd.uid` files. Exactly three UIDs belong to the new Task 9 runners and are intentional committed artifacts. The 591 imports and other 38 UIDs are verification-only generated sidecars; they were stashed recoverably rather than deleted. A cold import without those previously generated identities reproduced the repository's known short-scan loader failure, so that timed-out attempt was rejected and is not cited as passing evidence. The accepted import was a complete `--import` from the restored verification-sidecar state and exited 0 with no forbidden diagnostics.

The progressive-load child processes retain known headless shutdown diagnostics: three DummyMesh RID allocations, 116 ObjectDB instances, 101 resources, and Variant allocator pages per size. The complete suite retains its established intentional negative-path error/warning fixtures plus 18 ObjectDB and five resource shutdown diagnostics. The two-frame editor smoke can report `Scan thread aborted` while exiting cleanly. None of these produced a parse, loader, script, test-failure, missing-marker, or nonzero-exit failure in accepted evidence.

Task 9's committed code review contains only the three integration runners and their three intentional UID files; the documentation-only verification commit adds only this file. No production code, data, scenes, assets, or project settings changed in Task 9. `git diff --check` was clean. Independent review of the complete Plan 4A range is assigned to the root implementation owner; confirmed findings must receive a regression and affected/full-gate reruns before integration.

## Explicit Plan 4A boundaries

- Normal Arena remains single-player.
- The two-profile harness proves domain and integration isolation; it is not playable split-screen.
- Controller assignments are covered by automated contracts only. Physical-controller testing, disconnect/reconnect behavior, Steam Remote Play Together, and adaptive-camera behavior are deferred.
- Tutorial work, onboarding presentation, Arena wave rework, and Adventure-mode work are deferred.
- Character progression is run-scoped. No `ProfileState` value changed, and Plan 4A does not persist progression snapshots to profile storage.
