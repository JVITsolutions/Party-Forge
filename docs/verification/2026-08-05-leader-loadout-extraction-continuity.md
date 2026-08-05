# Leader loadout extraction continuity verification

Verified on 2026-08-05 with Godot `4.7.1.stable.mono.official.a13da4feb` in the isolated `leader-loadout-extraction-continuity` worktree.

## Tested identities and range

The exact tested Party Forge code is `3c753f41c24df7c7a3093e253f775109e21afb75` (`fix: freeze committed local run bootstrap`). The approved-plan and Tasks 1-11 range is:

```text
81c68a51af3596cdb3c655b88d5bb25a8c9746e7..3c753f41c24df7c7a3093e253f775109e21afb75
```

Expressed as a Git revision range, it is `e9742ecb5ec7f550687c1eae84679de25463b499^..3c753f41c24df7c7a3093e253f775109e21afb75`. The production/test implementation begins after the corrected plan, so its code range is `8003d9ce6f4bc568452c8d59509bdc1ef9c46699^..3c753f41c24df7c7a3093e253f775109e21afb75`. The complete plan range changes 86 files with 10,919 insertions and 137 deletions.

Creator authority was tested without modification at `86fa8c2ef41352f4508da8eb72c456f1741435d0` (`feat: add leader loadout extraction unlock`).

This record and Chapter 12 are documentation-only children of the tested Party Forge code. The next gate after the documentation commit is an independent complete-range review; this record does not claim that pending review was already performed.

## Documentation RED and GREEN

The focused static acceptance command was defined and run before Chapter 12 existed:

```powershell
$doc = 'docs/handbook/12-equipment-stash-and-extraction.md'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$checks = [ordered]@{
  profile_container = 'profile_leader_equipment'
  run_container = 'run_member_equipment'
  extraction_unlock = 'leader_loadout_extraction'
  creator_source = 'samples/party-forge-city.pstree'
  creator_runtime = 'samples/party-forge-city.pstree.json'
  creator_demo = 'integrations/godot/demo/party-forge-city.pstree.json'
  game_source = 'data/passive_trees/city/party-forge-city.pstree'
  game_runtime = 'data/passive_trees/city/party-forge-city.pstree.json'
  armoury_route = 'ROUTE_ARMOURY'
  warehouse_route = 'ROUTE_WAREHOUSE'
  shared_stash = 'same profile item registry'
  leader_only = 'leader-only'
  warning_incompatible = 'INCOMPATIBLE'
  warning_destructive = 'DESTRUCTIVE_CONFIRMATION'
  hold = '1.25'
  per_profile = 'per-profile'
  player_mode = 'Player Mode'
  developer_mode = 'Developer Mode'
  barracks = 'Barracks'
  starting_followers = 'starting followers'
  follower_equipment = 'follower equipment'
  sandbox_boundary = 'SANDBOX_REMOVE'
}
if (-not (Test-Path -LiteralPath $doc -PathType Leaf)) {
  $timer.Stop()
  Write-Error "DOC_ACCEPTANCE_RED missing=$doc elapsed_ms=$($timer.ElapsedMilliseconds)"
  exit 1
}
$text = Get-Content -LiteralPath $doc -Raw
$missing = @($checks.GetEnumerator() | Where-Object {
  $text.IndexOf($_.Value, [System.StringComparison]::OrdinalIgnoreCase) -lt 0
} | ForEach-Object { $_.Key })
$timer.Stop()
if ($missing.Count -gt 0) {
  Write-Error "DOC_ACCEPTANCE_FAIL missing=$($missing -join ',') elapsed_ms=$($timer.ElapsedMilliseconds)"
  exit 1
}
Write-Output "DOC_ACCEPTANCE_PASS checks=$($checks.Count) elapsed_ms=$($timer.ElapsedMilliseconds)"
exit 0
```

RED exited `1` in 31 ms with the intended diagnostic:

```text
DOC_ACCEPTANCE_RED missing=docs/handbook/12-equipment-stash-and-extraction.md elapsed_ms=31
```

The unchanged command then exited `0` in 74 ms:

```text
DOC_ACCEPTANCE_PASS checks=22 elapsed_ms=74
```

The check requires exact profile/run containers, extraction unlock/precedence vocabulary, all Creator/game artifact paths, distinct routes over shared ownership, leader-only Armoury v1, both warning states and the 1.25-second hold, per-profile isolation, Player/Developer Mode boundaries, Barracks deferrals, and the sandbox-removal boundary.

## Isolated Godot environment and cold import

The working tree began with only the two intended handbook paths dirty. It had zero untracked sidecars; the only untracked path was the new Chapter 12 document.

The existing worktree `.godot` cache was moved intact to a unique Temp backup before import. All Godot commands used:

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\leader-loadout-extraction-continuity'
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$taskRoot = Join-Path $env:TEMP 'party-forge-task12-20260805-7d7b27a8'
$env:APPDATA = Join-Path $taskRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $taskRoot 'localappdata'
```

The cold import command was:

```powershell
& $godot --headless --path $project --import
```

It exited `0` in 21.279 seconds, created a fresh `.godot` cache, and had zero `No loader found`, `Parse Error`, `SCRIPT ERROR`, `Failed loading resource`, crash, access-violation, or timeout matches. It retained cold-import shutdown diagnostics: three DummyMesh RID allocations, 221 ObjectDB instances, 149 resources, and medium/small Variant allocator pages reported at exit. Those diagnostics did not replace the exit/loader/parse gates.

## Party Forge automated gates

Every accepted command exited `0`, emitted its required marker exactly once, and had zero crash, timeout, missing-summary, unexpected loader, parse, script, or failed-resource matches.

| Gate | Elapsed | Accepted evidence |
| --- | ---: | --- |
| Cold import | 21.279 s | Fresh cache; forbidden matches `0` |
| Seven-suite resource probe | 14.300 s | `TEST_SUMMARY: PASS (0 failures)` |
| Tasks 1-11 focused batch | 30.062 s | 31 named suites; `TEST_SUMMARY: PASS (0 failures)` |
| Complete suite | 105.407 s | Exactly one `TEST_SUMMARY: PASS (144 suites)`; 144 live `tests/unit/*.gd` suites discovered |
| Armoury/Warehouse responsive and input | 1.240 s | Three size markers and `TASK9_STORAGE_RESPONSIVE_SUMMARY: PASS (0 failures)` |
| Loadout warning responsive/input | 11.930 s | Responsive, controller, keyboard, mouse, and final PASS markers |
| Responsive runner static resolution check | under 1 s | Two runners, three exact `Vector2i` targets, zero missing |

### Resource probe command

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_equipment_contract.gd `
  tests/unit/test_passive_tree_artifact_sync.gd `
  tests/unit/test_passive_tree_loader.gd `
  tests/unit/test_armoury_screen.gd `
  tests/unit/test_warehouse_screen.gd `
  tests/unit/test_loadout_warning_dialog.gd `
  tests/unit/test_main_wiring.gd
```

### Tasks 1-11 focused command

```powershell
& $godot --headless --path $project --quit-after 300 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_equipment_slot_index.gd `
  tests/unit/test_item_ownership_state.gd `
  tests/unit/test_profile_state.gd `
  tests/unit/test_profile_item_schema_migration.gd `
  tests/unit/test_atomic_profile_store.gd `
  tests/unit/test_profile_item_storage_service.gd `
  tests/unit/test_profile_storage_reconciler.gd `
  tests/unit/test_player_run_context.gd `
  tests/unit/test_run_item_ownership.gd `
  tests/unit/test_equipment_assignment_service.gd `
  tests/unit/test_run_loadout_checkout_service.gd `
  tests/unit/test_main_loadout_checkout_recovery.gd `
  tests/unit/test_passive_tree_artifact_sync.gd `
  tests/unit/test_passive_tree_contracts.gd `
  tests/unit/test_passive_tree_loader.gd `
  tests/unit/test_passive_tree_progression_service.gd `
  tests/unit/test_passive_tree_view_model.gd `
  tests/unit/test_run_extraction_policy.gd `
  tests/unit/test_run_resolution_service.gd `
  tests/unit/test_loadout_transition_service.gd `
  tests/unit/test_profile_loadout_assignment_service.gd `
  tests/unit/test_profile_storage_projection.gd `
  tests/unit/test_armoury_screen.gd `
  tests/unit/test_warehouse_screen.gd `
  tests/unit/test_main_menu_view_model.gd `
  tests/unit/test_main_menu_screen.gd `
  tests/unit/test_main_wiring.gd `
  tests/unit/test_loadout_warning_dialog.gd `
  tests/unit/test_class_selection_panel.gd `
  tests/unit/test_local_run_setup_coordinator.gd `
  tests/unit/test_run_context_registry.gd
```

### Complete suite command

```powershell
& $godot --headless --path $project --quit-after 420 --script res://tests/test_runner.gd
```

The full suite's established assertion-level negative paths emitted stable prefixes including `PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR`, `PARTY_FORGE_RUN_CONTEXT_ERROR`, `PARTY_FORGE_DAMAGE_ERROR`, `PARTY_FORGE_STAT_ERROR`, and `PARTY_FORGE_UPGRADE_APPLICATION_ERROR`. They were generated by tests that deliberately submit rejected requests. The run ended with the required 144-suite PASS marker, followed by the known 18 ObjectDB/five-resource shutdown diagnostics.

## Synthetic rendered and input acceptance

The Armoury/Warehouse command was:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/armoury_warehouse_responsive_runner.gd
```

It emitted:

```text
TASK9_STORAGE_RESOLUTION_PASS size=1920x1080
TASK9_STORAGE_RESOLUTION_PASS size=2560x1440
TASK9_STORAGE_RESOLUTION_PASS size=3840x2160
TASK9_STORAGE_RESPONSIVE_SUMMARY: PASS (0 failures)
```

This runner exercised the eleven rendered leader slots, all three unlocked fixture stash tabs, 100 rendered slots in the selected tab, Warehouse search/rarity/item-type/sort control visibility, focus containment/restoration, exact shared item records/placements, Armoury equip intent emission, and Warehouse exact-slot move intent emission. It did not traverse to the final stash slot or apply and persist an eligibility-checked equip request; those backend contracts are covered by the focused storage/assignment unit suites instead.

Two warning-run attempts used the plan-style `--quit-after 180` command. Both exited `0` after approximately 2.1-2.3 seconds but emitted no required marker because `--quit-after` counts processed frames and stopped the timed 1.25-second hold sequence early. Both runs were rejected. The accepted command lets this self-terminating runner reach its own cleanup and summary:

```powershell
& $godot --headless --path $project --script res://tests/integration/loadout_warning_input_runner.gd
```

It exited `0` in 11.930 seconds and emitted exactly once:

```text
TASK10_LOADOUT_WARNING_RESPONSIVE_PASS
TASK10_LOADOUT_WARNING_CONTROLLER_PASS
TASK10_LOADOUT_WARNING_KEYBOARD_PASS
TASK10_LOADOUT_WARNING_MOUSE_PASS
TASK10_LOADOUT_WARNING_INPUT_SUMMARY: PASS (0 failures)
```

Both committed runners statically declare and iterate `Vector2i(1920, 1080)`, `Vector2i(2560, 1440)`, and `Vector2i(3840, 2160)`. The warning runner covered the exact item/reason list, focus loop, scrolling, cancel, Armoury redirect, short/split hold rejection, focus-loss reset, exact-token confirmation, and controller/keyboard/mouse parity. These are headless Godot layout and injected input-event checks. They are synthetic evidence, not physical-device or human visual certification.

The focused unit batch additionally covered ordinary versus automatic leader extraction, repeated compatible checkout, exact overflow lists, sufficient-stash movement, transition cancellation/atomicity, per-profile two/four-participant setup isolation, participant ordering, and backend readiness. It does not turn those backend seams into an unimplemented split-screen UI.

## Creator gates and artifact equality

Creator remained clean at the exact authority commit before and after these commands:

```powershell
npx.cmd vitest run src/core/serialization/party-forge-city-fixture.test.ts
npm.cmd test
npm.cmd run typecheck
npm.cmd run lint
```

| Gate | Exit | Elapsed | Evidence |
| --- | ---: | ---: | --- |
| City golden fixture | 0 | 3.373 s | 1 file, 6 tests passed |
| Complete Creator unit suite | 0 | 31.805 s | 90 files, 931 tests passed |
| TypeScript typecheck | 0 | 3.722 s | `tsc --noEmit` |
| ESLint | 0 | 3.457 s | `eslint .` |

Fresh SHA-256 and byte comparisons produced:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Creator `samples/party-forge-city.pstree` | 39,830 | `22cf0f498e889718671557fd2136fd0e9817d2b4c60aa222ce21d8391de60436` |
| Party Forge `data/passive_trees/city/party-forge-city.pstree` | 39,830 | `22cf0f498e889718671557fd2136fd0e9817d2b4c60aa222ce21d8391de60436` |
| Creator `samples/party-forge-city.pstree.json` | 34,829 | `7dd84990fe1609ac186d8412df18da5316b8731d2c1a5814e97cb750a6b9ee28` |
| Creator `integrations/godot/demo/party-forge-city.pstree.json` | 34,829 | `7dd84990fe1609ac186d8412df18da5316b8731d2c1a5814e97cb750a6b9ee28` |
| Party Forge `data/passive_trees/city/party-forge-city.pstree.json` | 34,829 | `7dd84990fe1609ac186d8412df18da5316b8731d2c1a5814e97cb750a6b9ee28` |

`StructuralEqualityComparer` byte comparisons returned `True` for Creator source to game source, Creator runtime to Creator demo, and Creator runtime to game runtime. Hash equality was not inferred from filenames or a previous report.

## Destructive boundary and sidecars

A complete `scripts/` scan found `SANDBOX_REMOVE` only in the generic item transaction request/service definition and dispatch boundary. A narrower scan of production feature paths found zero occurrences in `scripts/equipment`, `scripts/extraction`, `scripts/profile`, `scripts/run`, `scripts/ui/armoury`, `scripts/ui/warehouse`, `scripts/ui/loadout_warning`, and `scripts/game`. A call-site scan found zero production `ItemTransactionRequest.sandbox_remove(...)` calls.

Cold import and the accepted gates generated 65 untracked `.gd.uid` files and zero untracked `.import` files. The pre-import sidecar snapshot was empty, so all 65 were attributable to this verification. Every path was confirmed untracked and matched the exact sidecar extensions before individual removal. The generated `.godot` cache was moved to the isolated Temp evidence root, and the pre-existing worktree cache was restored. The worktree then had zero untracked `.gd.uid`/`.import` paths.

Detailed logs and the quarantined cold cache remain outside the repository under `C:\Users\Jacob\AppData\Local\Temp\party-forge-task12-20260805-7d7b27a8` for the immediate independent review handoff. No Creator file and no tracked production/test file was changed during Task 12 verification.

## Review and correction history

Tasks 1-11 were independently reviewed before this documentation task. The feature commits and their review-driven correction commits are:

| Area | Feature commit | Review/fix history |
| --- | --- | --- |
| Fixed equipment containers | `8003d9c` | Accepted without a follow-up production correction |
| Profile schema three | `a094959` | `d2fe4ed` preserves schema-two item order |
| Run equipment ownership | `703b080` | `979bba3` reserves the run assignment boundary |
| Loadout checkout | `d0476f8` | `d083f67`, `e61a2f1`, `bbfac11` make forfeit irreversible, recovery safe, and artifacts sanitized |
| City unlock | `8d92941` | Creator authority pinned at `86fa8c2` |
| Extraction projection | `0cf6600` | Accepted without a follow-up production correction |
| Atomic run resolution | `e65cde3` | `e743701` handles occupied leader loadouts safely |
| Compatibility transition | `3fa71ba` | `a40452e`, `b84d526`, `e1d9511` reject stale state and bind/canonicalize exact records |
| Armoury/Warehouse | `aea428f` | `f364de3` hardens the shared storage interfaces |
| Warning flow | `1400f17` | `736d204` hardens transition authorization |
| Local setup | `d02a217` | `045c6df`, `e84f5e6`, `3c753f4` preserve checkout continuity, preflight identity, and freeze committed bootstrap |

Task 12's initial verification pass found no new Critical or Important product defect. It did find and honestly reject the two truncated warning-run commands described above; the production/test files were not changed because the self-terminating runner completes correctly when allowed to reach its own summary. Independent complete-range review after `9878ca0` then identified an Important recovery defect: confirmed overflow destruction used an ordinary profile save, allowing the pre-destruction backup to resurrect removed gear after primary corruption. The review also identified the synthetic-runner overclaim corrected above.

The complete-range correction added a generic irreversible `ProfileMutationService` entry point and selects it only for validated transitions with nonempty `overflow_item_ids`; non-overflow transitions retain ordinary save rotation, and resumable-run revocation keeps its existing API. Test-first evidence was:

| Correction gate | Exit | Evidence |
| --- | ---: | --- |
| RED loadout regression before production changes | 1 | `TEST_SUMMARY: FAIL (10 failures)`; stale backup restored the destroyed item, corrupt-primary replay was not a duplicate, and the injected destructive failure took the ordinary path |
| GREEN focused loadout regression | 0 | `TEST_SUMMARY: PASS (0 failures)` |
| Mutation/atomic-store/storage/loadout focused batch | 0 | Five named suites; `TEST_SUMMARY: PASS (0 failures)` |
| Complete suite after correction | 0 | 92.588 s; exactly one `TEST_SUMMARY: PASS (144 suites)`, zero `TEST_FAILURE` lines, and zero loader/parse/crash/timeout matches |

The regressions now prove that both active generations omit confirmed overflow, corrupt-primary recovery cannot resurrect the destroyed item, replay is byte-stable and idempotent before and after backup recovery, an injected second-promotion failure restores the exact prior profile-directory bytes and artifact set, and an ordinary non-overflow transition still retains its pre-transition profile in `.bak`.

Post-correction hygiene produced `git diff --check` exit `0`, zero untracked `.gd.uid`/`.import` sidecars, zero sandbox-removal matches in the production feature paths, and exactly the intended mutation service, transition service, loadout regression, and verification record as dirty paths before commit. The correction does not modify the pinned Creator worktree or artifacts.

A second independent complete-range review after `5a9a6bd` found that the irreversible save had sanitized physical generations but not older `applied_transactions[*].result_profile` snapshots containing destroyed overflow IDs. Replaying an ordinary transaction committed before destruction could therefore expose the removed gear from its historical result, including after corrupt-primary backup recovery.

The second correction passes the exact removed instance IDs through the generic irreversible mutation boundary and generalizes the existing run-revocation snapshot sanitizer. Every affected historical result is replaced with a journal-free projection of the post-mutation profile while retaining its original committed timestamp; duplicate detection and the separate resumable-run revocation API remain unchanged.

| Second-correction gate | Exit | Evidence |
| --- | ---: | --- |
| RED historical replay regression | 1 | `TEST_SUMMARY: FAIL (4 failures)`; the destroyed ID remained in the current journal, backup journal, recovered journal, and older duplicate result |
| GREEN focused loadout regression | 0 | `TEST_SUMMARY: PASS (0 failures)` |
| Mutation/atomic-store/storage/loadout/run-revocation focused batch | 0 | Six named suites; `TEST_SUMMARY: PASS (0 failures)` |
| Complete suite after second correction | 0 | 93.966 s; exactly one `TEST_SUMMARY: PASS (144 suites)`, zero `TEST_FAILURE` lines, and zero loader/parse/crash/timeout matches |

The historical regression commits an ordinary transaction while the future overflow item exists, destroys that item through the confirmed transition, corrupts and recovers the primary, and replays the older transaction. The replay remains duplicate/idempotent without invoking its callback, while its returned result, both active generations, and the current transaction journal contain no occurrence of the destroyed ID. Earlier irreversible-failure byte/artifact preservation, ordinary-transition backup rotation, destructive replay, corrupt-primary recovery, and run-revocation tests remain in the focused and full passing sets.

Post-second-correction hygiene produced `git diff --check` exit `0`, zero untracked `.gd.uid`/`.import` sidecars, zero sandbox-removal matches in the production feature paths, and exactly the intended mutation service, transition service, loadout regression, and verification record as dirty paths before commit. The pinned Creator worktree remained clean and unchanged.

## Explicit physical/manual and production-UI deferrals

The following were not performed and are not claimed:

- physical two-controller or four-controller acceptance;
- physical-device pairing, disconnect/reconnect, or platform-controller certification;
- multi-window, split-camera, or full split-screen participant UI acceptance;
- human visual approval at 1920x1080, 2560x1440, or 3840x2160;
- an end-user production extraction-picker walkthrough, because the policy/resolution backend exists but that complete production UI is not supplied by Tasks 1-11;
- Adventure-mode drop-in behavior; and
- starting followers, follower persistent equipment sheets, follower equipment preparation, repeated Barracks follower nodes, or `followers_bring_gear`.

Armoury v1 is leader-only. Task 11 is join-before-run backend coordination, not evidence for split-screen/camera presentation. Developer Mode preview evidence does not grant or mutate Player Mode permanent progression.

## Final documentation and repository hygiene

The post-authoring gate reran the 22-point documentation acceptance command, resolved every local Markdown link in the three intended docs, scanned those docs for placeholder markers, ran `git diff --check`, repeated the destructive-boundary and untracked-sidecar scans, and required `git status --short --untracked-files=all` to list only:

```text
docs/handbook/12-equipment-stash-and-extraction.md
docs/handbook/README.md
docs/verification/2026-08-05-leader-loadout-extraction-continuity.md
```

Observed results were:

```text
DOC_ACCEPTANCE_FINAL checks=22 missing=0
DOC_LINK_CHECK links=23 broken=0
DOC_PLACEHOLDER_SCAN hits=0
GIT_DIFF_CHECK exit=0 lines=0
UNTRACKED_SIDECAR_SCAN count=0
PRODUCTION_DESTRUCTIVE_BOUNDARY_SCAN hits=0
INTENDED_DIRTY_SCOPE actual=3 unexpected=0
```

The no-match placeholder scan returned `rg` exit `1`, which is the expected ripgrep status when zero lines match. Only the three intended documentation paths were dirty. No merge to `main` is part of this task.
