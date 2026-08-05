# Plan 4B item and container ownership foundation verification

Verified on 2026-08-05 with Godot `4.7.1.stable.mono.official.a13da4feb` in the isolated `plan-4b-item-ownership` worktree.

## Tested code identity

The exact tested production, test, runner, scene, resource, handbook, and support code is commit `09b08b814657374fc3d66a3d549467e1e35c37f3` (`fix: enforce persisted stash tab cap`). This verification document is a documentation-only child of that code commit.

The complete Plan 4B range is `1df6f9d42214da1f7d092185107cd964f4c7d6b1^..09b08b814657374fc3d66a3d549467e1e35c37f3`; its parent is test-isolation commit `2e56ad9f046990e06a1825e1e4c3f20a9e10858f`. The range contains these intentional commits:

- Design and plan: `1df6f9d`, `c586288`.
- Item foundation and contract corrections: `e55de81`, `0d907b3`, `89e2f35`, `f09058e`, `b0776bf`.
- Immutable item codec and issuance: `452d2dd`, `218452a`.
- Ownership state: `e408532`, `c8eb879`, `653f5d7`.
- Atomic transactions: `2c716e9`, `80433ad`, `2c88e7e`.
- Profile migration: `4fae7f1`, `05c3551`, `28e3c91`, `2b0faf2`.
- Persistent storage reconciliation: `c663b5e`, `f63cf50`, `522bb09`.
- Run ownership and architecture continuity: `b96e644`, `580fd29`, `a9db2e3`, `8e73f42`, `26df2ad`, `90150ee`.
- Isolated sandbox state and UI: `1a93987`, `c1ae583`, `01bbf30`, `40a58cd`.
- Upgrade-recipient controller-scroll correction: `0c8e8f5`.
- Task 10 acceptance and manifest hardening: `e757b77`, `2df3540`, `9965027`, `d4688b9`.
- Handbook and complete-range review corrections: `3e3e99f`, `bc0746e`, `09b08b8`.

No production or test file changed during this final verification wave.

## Isolated environment and artifact baseline

Every accepted Godot command used the exact executable and the same unique, initially empty Temp roots:

```powershell
$project = (Get-Location).Path
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$runRoot = Join-Path $env:TEMP 'party-forge-plan4b-final-20260805-a91d24e6'
$env:APPDATA = Join-Path $runRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $runRoot 'localappdata'
```

Immediately before import, `git status --short --untracked-files=all` and `git ls-files --others --exclude-standard` both returned no paths. This made every subsequently untracked sidecar attributable to this verification.

## Genuine import and complete automated gate

| Gate | Exact command | Exit | Elapsed | Accepted evidence |
| --- | --- | ---: | ---: | --- |
| Import | `& $godot --headless --path $project --import` | 0 | 4.963 s | Zero `No loader found`, parse, script, or failed-resource matches. |
| Complete suite | `& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd` | 0 | 79.840 s | Exactly one `TEST_SUMMARY: PASS (131 suites)`; the same invocation discovered 131 `tests/unit/*.gd` suites and the reported count matched. |

The suite count was discovered from the live `tests/unit` directory during this run and compared with the sole summary marker; it was not assumed from a prior report. The complete run also emitted:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (131 suites)
```

The deterministic SHA-256 is the canonical 99-item Developer Item Sandbox fixture hash. Established negative-path suites intentionally emitted their stable error diagnostics. Shutdown retained 18 leaked-ObjectDB and five-resources-in-use diagnostics; there was no assertion, parse, script, loader, or failed-resource failure.

Import warned that absent `.gd.uid` files were recreated from cache. This was expected generated-sidecar activity, not a loader failure; all newly created paths were inventoried and removed as described below.

## Required focused integration and gameplay gates

Every marker named below appeared exactly once, every process exited `0`, and every log had zero `No loader found`, parse, script, or failed-resource matches.

| Gate | Exact command after the shared prefix | Exit | Elapsed | Required marker |
| --- | --- | ---: | ---: | --- |
| Developer Item Sandbox | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/developer_item_sandbox_runner.gd` | 0 | 8.291 s | `ITEM_SANDBOX_UI_SUMMARY: PASS` |
| Profile isolation | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_profile_runner.gd` | 0 | 8.435 s | `ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99` |
| Storage performance | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_performance_runner.gd` | 0 | 1.294 s | `ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396` |
| Production Arena progression | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/progression_arena_smoke_runner.gd` | 0 | 1.758 s | `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS` |
| Main-menu navigation | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/main_menu_navigation_runner.gd` | 0 | 2.321 s | `MAIN_MENU_NAVIGATION_SUMMARY: PASS` |
| City passive-tree profile | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_profile_runner.gd` | 0 | 1.010 s | `PASSIVE_TREE_PROFILE_SUMMARY: PASS` |
| City passive-tree input | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_input_runner.gd` | 0 | 2.498 s | `PASSIVE_TREE_INPUT_SUMMARY: PASS` |
| City passive-tree responsive | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_responsive_runner.gd` | 0 | 1.302 s | `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)` |
| 24-member ledger | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/ledger_24_member_runner.gd` | 0 | 2.313 s | `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)` |
| Startup | `& $godot --headless --path $project --quit-after 10` | 0 | 1.706 s | One `PARTY_FORGE_BOOT_OK` and one `PARTY_FORGE_CLASS_SELECTION_READY` |

## Supplemental final acceptance

These committed real-focus runners supplement rather than replace the Plan 4B gates:

| Gate | Exact command | Exit | Elapsed | Required marker |
| --- | --- | ---: | ---: | --- |
| Upgrade-recipient controller scrolling | `& $godot --headless --path $project --quit-after 10000 --script res://tests/integration/upgrade_recipient_controller_scroll_runner.gd` | 0 | 2.675 s | `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)` |
| Task 9 sandbox focus ownership | `& $godot --headless --path $project --quit-after 180 --script res://tests/integration/task9_developer_item_sandbox_focus_runner.gd` | 0 | 5.203 s | `TASK9_SANDBOX_FOCUS_SUMMARY: PASS (0 failures)` |

The upgrade-recipient runner reached eligible member 24 at all targets and recorded the same `scroll=2826 max=3602 page=776` at 1920x1080, 2560x1440, and 3840x2160. It exercised real parsed D-pad, keyboard, and controller-accept events and verified deferred-scroll rebuild safety.

## Storage, immutability, and performance evidence

The profile-isolation runner created two normal profiles plus the isolated sandbox; it compared each normal profile's semantic dictionary, primary bytes, journal, SHA-256, active selection, profile-index bytes/SHA-256, and recursive profile-root manifest before and after sandbox save, reload, move, swap, integrity scan, and deterministic reset. Its cleanup-gated summary proves both normal profiles and the active-profile index remained exact and the sandbox remained confined to its separate root.

The production Arena smoke separately emitted the explicit active-profile byte proof:

```text
PROGRESSION_ARENA_PROFILE_IMMUTABLE profile=profile-plan4a-task9-smoke sha256_before=72eba3d64a08a90b466457fe330ff00c237723592278d6fc35a9ffc2e4d57842 sha256_after=72eba3d64a08a90b466457fe330ff00c237723592278d6fc35a9ffc2e4d57842 values_equal=true bytes_equal=true
```

Fresh headless performance measurements were:

```text
ITEM_STORAGE_PERFORMANCE_ONE profile=1 items=99 containers=1 encode_ms=0.549 decode_ms=12.507 validate_ms=4.884 save_ms=33.482 reload_ms=16.794 bytes=52757
ITEM_STORAGE_PERFORMANCE_FOUR profiles=4 items=396 containers=4 elapsed_ms=304.970 bytes=211860 ceiling_ms=15000 ceiling_bytes=8388608 headless_regression_only=true
ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396
```

These are headless regression measurements, not platform-wide performance certification.

## Resolution and controller evidence

The sandbox runner emitted only after its complete cleanup gate:

```text
ITEM_SANDBOX_RESOLUTION_PASS size=1920x1080 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=2560x1440 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=3840x2160 slots=105
ITEM_SANDBOX_CONTROLLER_PASS
ITEM_SANDBOX_UI_SUMMARY: PASS
```

At each target, its real layout reported grid height `916`, scroll viewport height `880`, and a reachable final stash slot. It covered 5 inventory plus 100 stash slots, closed focus traversal, parsed D-pad/face-button movement and cancellation, inspector/action focus safety, drag callbacks, state/byte preservation, and cleanup. Headless mode used the runner's real target-sized SubViewport fallback because the headless display server does not report windowed mode. This is synthetic controller-contract evidence, not physical-device certification.

The passive-tree responsive and ledger runners independently passed their same three target sizes/viewports. The upgrade-recipient supplement passed the same three resolutions with 24 rendered recipients and controller/keyboard scrolling to member 24.

## Complete-range review findings and corrections

The independent complete-range review found no Critical issues and two Important blockers. Both received focused assertion-level RED, one root-cause fix, focused GREEN, and inclusion in this final complete gate.

| Finding | Correction and evidence |
| --- | --- |
| Sandbox reset could not recover corrupt primary plus corrupt/missing backup because the protected general save path refused overwrite. | `bc0746e` added an explicit sandbox-only validated replacement transaction with quarantine, promotion verification, and exact rollback. The focused sandbox state RED was `TEST_SUMMARY: FAIL (3 failures)`; GREEN was `TEST_SUMMARY: PASS (0 failures)`. |
| An already-persisted schema-2 profile could contain 101 otherwise-valid stash tabs because the 100-tab cap existed only in reconciliation-local grant logic. | `09b08b8` made `ProfileState.MAX_STASH_TABS` the shared decode/load/snapshot/reconciliation invariant. The focused RED was `TEST_SUMMARY: FAIL (5 failures)`; GREEN and the exact-100 boundary rerun were `TEST_SUMMARY: PASS (0 failures)`. |

The final eight-suite focused regression batch on `09b08b8` exited `0` in 30.7 seconds with `ITEM_TRANSACTION_MATRIX: PASS`, the deterministic sandbox SHA-256 above, and `TEST_SUMMARY: PASS (0 failures)`. This final wave then independently reran import, all 131 suites, all ten required final commands, and both supplemental focus runners.

## Explicit deferred scope

- Minor: the sandbox Status control remains focusable but outside the explicit closed focus graph.
- Minor/evidence gap: the standalone resolution/controller runner does not cover the production-composed main route, saved developer-mode gate, modal layering, or focus restoration at every target resolution. Existing main-menu routing and Task 9 focus runners pass, but no new all-resolution composed-route runner was added.
- The controller recipient interlude retains its accepted Minor: a manually forced all-disabled recipient list has no deterministic initial focus; production offer validation prevents that state.
- Physical-controller certification remains deferred; the accepted runners inject real Godot input events headlessly.
- Equipment application, randomized production loot, ground pickup, extraction, run loss, cross-player transfer, shops, crafting, salvage, rarity audiovisual presentation, Armoury, and Warehouse implementation remain outside Plan 4B.
- Mythic and Eternal remain registered future rarities and are not issued by the default sandbox fixture.

## Generated sidecars and runtime-root disposition

The pre-import untracked snapshot was empty. Import and subsequent suites created exactly 21 untracked `.gd.uid` files and no `.import` files. They comprised four sandbox production scripts, five integration runners, one test-support script, and eleven unit suites. Each path was confirmed untracked, a `.gd.uid`, and strictly beneath this worktree before it was removed individually. No tracked or pre-existing user file was removed.

The integration runners removed their own `user://` task roots before emitting PASS. After validating resolved paths remained beneath the user Temp directory and contained no reparse points, verification removed the unique final APPDATA/LOCALAPPDATA parent and seven named Plan 4B reviewer runtime roots. All eight exact Temp roots were then confirmed absent. No broad clean, reset, or wildcard deletion was used.

## Repository hygiene

Before authoring this record, `git diff --check` exited `0`, `git status --short --untracked-files=all` was empty, all 21 verification-created sidecars were absent, and all eight validated Temp roots were absent.

The initial documentation-only commit was `42b7f292135a79362e3bf31ee94bf6ea37440524` with subject `docs: verify Plan 4B item ownership foundation`; `git show --format= --name-status HEAD` listed only this new verification document. Immediately afterward, `git status --short --untracked-files=all` and `git ls-files --others --exclude-standard` both returned zero paths, while `git diff --check` and `git diff --check HEAD^..HEAD` both exited `0`. This record was then amended only to include that observed proof; the same clean-status, untracked, scope, and diff checks were rerun after the final amend.
