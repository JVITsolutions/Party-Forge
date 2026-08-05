# Task 10 Report: Item Sandbox Ownership, Layout, and Performance Runners

## Scope

Implemented only Plan 4B Task 10 on `feat/plan-4b-item-ownership` from clean parent `0c8e8f5a7165cae206714540bd51f2ad70f0a5c9`.

Created:

- `tests/integration/developer_item_sandbox_runner.gd`
- `tests/integration/item_storage_profile_runner.gd`
- `tests/integration/item_storage_performance_runner.gd`
- `tests/unit/test_item_storage_responsive_contract.gd`
- `tests/support/task10_filesystem_manifest.gd`

Modified only the real developer tool at `scripts/ui/developer_item_sandbox.gd`. No Task 11 documentation, gameplay/content semantics, equipment application, loot, extraction, transfer, shop, crafting, salvage, or profile schema behavior changed.

## Production Result

- `apply_viewport_size(size: Vector2i)` now reuses `LedgerResponsiveLayout` so the sandbox follows the established compact width/height breakpoints and safe-margin policy without resolution-specific branches.
- The wide body remains horizontal; compact layout becomes vertical and adjusts container minimums through the same production method.
- The 10-column stash now has enough real row height to overflow its `ScrollContainer`, making stash scrolling functional rather than nominal. At every target resolution the real layout measured grid height `916` and scroll viewport height `880`.
- Broadly useful read-only diagnostics report the real slot-button count, a defensive selected-item detail, and the sandbox domain's current integrity error.
- Drag preview creation is guarded by `Viewport.gui_is_dragging()`. Real pointer drags retain their preview; the closest reliable headless callback path can execute `_get_drag_data`, `_can_drop_data`, and `_drop_data` without a Godot drag-state error.

## RED-GREEN Evidence

### Accepted responsive contract RED

Before runner files or production hooks existed, the focused contract exited `1` with `TEST_SUMMARY: FAIL (7 failures)`:

- three assertion failures for the absent Task 10 runner resources;
- four assertion failures for the absent `apply_viewport_size`, `slot_button_count`, `selected_item_detail`, and `integrity_error` methods.

The accepted RED contained no parser, loader, script, or fixture crash.

### Accepted UI runner RED

After the runners existed but before production hooks, the UI runner exited `1` with `ITEM_SANDBOX_UI_SUMMARY: FAIL (13 failures)`. All failures were assertion-level missing-hook failures across the three resolutions plus the controller fixture. There was no parser, loader, resource, or fixture error.

The first profile-runner attempt was rejected as RED evidence because the test fixture asked first-empty stash to move an item already in the stash. The corrected operation sequence passed existing Task 8/9 behavior. The performance runner also passed against existing canonical profile ownership support. No artificial production failure was added to runners whose acceptance behavior already existed.

### GREEN

The focused responsive contract exited `0` with `TEST_SUMMARY: PASS (0 failures)`. The clean UI runner exited `0` without engine, parser, script, or loader errors and emitted:

```text
ITEM_SANDBOX_RESOLUTION_PASS size=1920x1080 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=2560x1440 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=3840x2160 slots=105
ITEM_SANDBOX_CONTROLLER_PASS
ITEM_SANDBOX_UI_SUMMARY: PASS
```

### Review correction RED-GREEN

The review contract first exited `1` with `TEST_SUMMARY: FAIL (7 failures)`. All seven were assertion-level failures for the absent recursive profile manifest, sandbox confinement manifest, physical-window/logical-canvas geometry evidence, cleanup verification in each of the three runners, and filesystem-manifest helper. One earlier contract invocation had a fixture type-inference parse error; it was rejected as RED evidence and corrected before this accepted run.

After the helper resource existed as a minimal stub, the contract exited `1` with `TEST_SUMMARY: FAIL (8 failures)`. Two failures specifically proved that the stub failed to detect an added sentinel file and a same-length byte mutation. The finished helper recursively records sorted relative paths, entry kind, file byte length, SHA-256, and simplified resolved path. It rejects the root or any descendant reported by Godot's `DirAccess.is_link()` API as a link/reparse point. The same focused contract then exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

The final scope audit found that the UI summary was cleanup-gated but its three resolution PASS markers were still emitted earlier. A focused ordering contract exited `1` with exactly one assertion failure. The UI runner now records verified sizes and emits every resolution/controller/UI PASS marker only after cleanup succeeds; the focused contract and exact-marker UI runner both returned to GREEN.

A final manifest review found two remaining fail-open API paths. The focused contract first exited `1` with exactly one assertion failure because the helper lacked injectable list-begin and parent-open seams. After adding only the optional test-support signature, it exited `1` with exactly four behavior failures: forced `ERR_CANT_OPEN` and null-parent results both produced an empty error plus the normal one-file manifest. The helper now checks and propagates the `Error` from `DirAccess.list_dir_begin()`, represents link inspection as `{error, is_link}`, treats inability to open a parent directory as an error, passes both optional Callables through recursive traversal, and discards all partial entries on any capture error. The focused contract returned to `TEST_SUMMARY: PASS (0 failures)` while retaining normal, sentinel-extra, same-length SHA, and reported-link behavior.

The subsequent nested-traversal review found that the list-begin test seam replaced the real `DirAccess.list_dir_begin()` call. The focused fixture now contains a deterministic root file plus `nested/nested.dat`. Its callback returns `OK` at the root and `ERR_CANT_OPEN` only for the exact simplified nested path. The accepted first RED exited `1` with `TEST_SUMMARY: FAIL (3 failures)`: the nested error was absent, only the root callback ran, and the reported-link seam was absent. After adding only the reported-link signature, the behavior RED exited `1` with `TEST_SUMMARY: FAIL (4 failures)`: the nested callback/error were still absent and a reported descendant link returned a false-success three-entry manifest. The helper now always invokes and checks the real `directory.list_dir_begin()` first, then applies the optional selective error seam without losing enumeration. It propagates that seam and the reported-link result seam recursively. Nested list failure, descendant parent-open failure, and reported descendant-link rejection all return stable exact errors with `entries == []`, discarding root entries accumulated before the descendant failure.

Exact nested-correction commands and results:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_storage_responsive_contract.gd
# RED 1: exit 1, TEST_SUMMARY: FAIL (3 failures)
# RED 2: exit 1, TEST_SUMMARY: FAIL (4 failures)
# GREEN: exit 0, TEST_SUMMARY: PASS (0 failures)

& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_profile_runner.gd
# exit 0, ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99

& $godot --headless --path $project --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_storage_responsive_contract.gd tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_profile_state.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_manager.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd
# exit 0, TEST_SUMMARY: PASS (0 failures), zero blocking diagnostics
```

## UI, Controller, and Mouse Acceptance

The production scene is instantiated in a real tree at 1920x1080, 2560x1440, and 3840x2160. The runner first requests `Window.MODE_WINDOWED`, awaits layout, and uses the real root Window when that mode is available. Godot's headless display server honors `root.size` but does not report windowed mode, so headless verification uses the permitted fallback: a real target-sized `SubViewport` with `size_2d_override=1920x1080` and stretch enabled. Each resolution marker is emitted only after the physical Window or fallback target equals the labeled size. The runner separately asserts the project's 1920x1080 `canvas_items` logical policy. It also proves:

- Overlay, safe frame, Inventory, Stash, Inspector, all six actions, and Close remain visible and contained.
- Exactly 5 inventory plus 100 stash buttons exist.
- The stash genuinely overflows, its real scroll value changes, and the final slot becomes reachable.
- A closed focus graph covers all 105 slots, Inspector, six actions, and Close without leaving the modal.
- Real `Input.parse_input_event` west face picks up the focused item, D-pad changes the real focus owner, south face moves or swaps onto the focused slot, and east face cancels held mode before closing the modal when pressed again.
- South face while not holding is inspection-only.
- South face on Save while holding cannot act on a historically focused slot; state and bytes remain exact.
- Godot drag callbacks move to an empty slot, swap an occupied slot, and preserve exact state/bytes on an outside cancellation. Fully synthetic pointer motion is not reliable headless, so the runner uses the closest engine callback path without a test-only production API.

## Profile Isolation Acceptance

The profile runner uses task-specific roots to create two normal profiles with distinct durable mutation journals, selects one as active, and captures each profile's semantic dictionary, exact primary bytes, SHA-256, journal, plus the exact profile-index bytes and SHA-256. It additionally captures the complete recursive normal-profile root before any sandbox operation and compares that exact manifest after the full sequence. This replaces the earlier tautological comparison of two globalized root strings.

It then resets the isolated 99-item sandbox and performs save, reload, selected-slot move, occupied swap, first-empty stash, first-empty inventory, integrity scan, mutated reload, and reset. Both profiles, both journals, the active-profile selection, profile index, complete recursive profile-root manifest, bytes, and hashes remain exact. Neither normal profile contains the sandbox owner or any sandbox item ID. A sandbox confinement manifest requires every resolved descendant to remain strictly beneath the simplified sandbox root and allows only the final `sandbox.json` primary and `sandbox.json.bak` atomic generation; directories, temporary/displaced/corrupt generations, profile/index artifacts, and reported links/reparse points fail closed.

All three integration runners now remove their task roots and assert those roots are absent before printing any PASS summary. The same finish path runs after accumulated assertion failures, so cleanup is attempted before FAIL output and exit `1` as well.

Exact marker:

```text
ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99
```

## Deterministic Performance Acceptance

The runner creates unique canonical `ProfileState` ownership domains with per-profile issuer namespaces, owner-bound 100-slot stash containers, and all 99 equipment definitions. It times `ProfileCodec.encode`, `ProfileCodec.decode`, validation, `ProfileStore.save_profile`, and `ProfileStore.load_profile` with `Time.get_ticks_usec()` and then decodes the ownership state again to verify exact instances, containers, owners, placements, and cross-profile isolation.

Final headless measurements:

```text
ITEM_STORAGE_PERFORMANCE_ONE profile=1 items=99 containers=1 encode_ms=0.547 decode_ms=11.940 validate_ms=4.805 save_ms=33.545 reload_ms=17.546 bytes=52757
ITEM_STORAGE_PERFORMANCE_FOUR profiles=4 items=396 containers=4 elapsed_ms=276.910 bytes=211860 ceiling_ms=15000 ceiling_bytes=8388608 headless_regression_only=true
ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396
```

The 15,000 ms and 8 MiB ceilings are intentionally generous regression guards. The elapsed ceiling is more than 56 times the observed four-profile baseline, and encoded growth must also remain close to linear from the measured one-profile bytes. These headless timings are not platform-wide performance certification.

## Regression, Import, and Complete Gates

All commands used Godot 4.7.1 stable console with a newly created isolated `APPDATA` and `LOCALAPPDATA` root.

- All three Task 10 runners: exit `0`; all exact markers above.
- Required bounded 23-suite Task 8/9 state/tamper/UI/settings/main, ownership transaction/run, profile/atomic/storage, responsive, and controller batch: exit `0`; exact `TEST_SUMMARY: PASS (0 failures)` marker present.
- Task 9 real focus-owner runner: exit `0`; exact `TASK9_SANDBOX_FOCUS_SUMMARY: PASS (0 failures)` marker present.
- Upgrade-recipient real controller runner with `--quit-after 10000`: exit `0`; exact `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)` marker present. The command rejects exit `0` without that exact marker.
- Final manifest hardening: focused contract exit `0`; pristine profile-isolation runner exit `0` with its exact marker; bounded seven-suite sandbox/profile/atomic/storage batch exit `0` with `TEST_SUMMARY: PASS (0 failures)` and zero blocking diagnostics. UI and performance interfaces were not touched by this helper-only correction. Per review direction, the complete 131-suite run was not repeated for this final test-support-only change.
- Nested manifest correction: focused contract, pristine exact profile-isolation runner, and the same bounded seven-suite storage batch all passed with their exact markers. The helper/contract-only interface change did not touch UI, performance, or production code, so the complete suite was not repeated.
- Fresh editor import: exit `0`; zero parse, script, loader, or failed-resource diagnostics.
- Complete suite: exit `0` in 70.6 seconds on the final correction tree; exact `TEST_SUMMARY: PASS (131 suites)` marker present; zero test/parser/script/loader failures; sandbox hash remained `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe`.

The focused and complete suites emitted their established intentional negative-path diagnostics. The complete suite retained only the established shutdown resource/object diagnostics and no Task 10 assertion, parser, script, loader, resource, input, or UI failure.

## Artifact and Review Boundary

The fresh import recreated 21 `.gd.uid` sidecars proven absent by the clean pre-import snapshot, including sidecars for the new helper/runners/contract and earlier Plan 4B files. All 21 were removed by exact path and are not part of the correction commit. Every worktree-local RED/GREEN runtime directory was removed before final verification; later pristine runtimes lived under the user Temp directory and were deleted after each command.

Original Task 10 commit: `e757b77` (`test: verify item sandbox ownership and layouts`). The latest nested-manifest correction is intentionally limited to the filesystem-manifest test support, responsive contract, and this report.

Stop after the focused Task 10 commit for independent review. Task 11 has not started.
