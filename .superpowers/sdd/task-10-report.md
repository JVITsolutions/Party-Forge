# Task 10 Report: Item Sandbox Ownership, Layout, and Performance Runners

## Scope

Implemented only Plan 4B Task 10 on `feat/plan-4b-item-ownership` from clean parent `0c8e8f5a7165cae206714540bd51f2ad70f0a5c9`.

Created:

- `tests/integration/developer_item_sandbox_runner.gd`
- `tests/integration/item_storage_profile_runner.gd`
- `tests/integration/item_storage_performance_runner.gd`
- `tests/unit/test_item_storage_responsive_contract.gd`

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

## UI, Controller, and Mouse Acceptance

The production scene is instantiated in a real tree at 1920x1080, 2560x1440, and 3840x2160. The runner proves:

- Overlay, safe frame, Inventory, Stash, Inspector, all six actions, and Close remain visible and contained.
- Exactly 5 inventory plus 100 stash buttons exist.
- The stash genuinely overflows, its real scroll value changes, and the final slot becomes reachable.
- A closed focus graph covers all 105 slots, Inspector, six actions, and Close without leaving the modal.
- Real `Input.parse_input_event` west face picks up the focused item, D-pad changes the real focus owner, south face moves or swaps onto the focused slot, and east face cancels held mode before closing the modal when pressed again.
- South face while not holding is inspection-only.
- South face on Save while holding cannot act on a historically focused slot; state and bytes remain exact.
- Godot drag callbacks move to an empty slot, swap an occupied slot, and preserve exact state/bytes on an outside cancellation. Fully synthetic pointer motion is not reliable headless, so the runner uses the closest engine callback path without a test-only production API.

## Profile Isolation Acceptance

The profile runner uses task-specific roots to create two normal profiles with distinct durable mutation journals, selects one as active, and captures each profile's semantic dictionary, exact primary bytes, SHA-256, journal, plus the exact profile-index bytes and SHA-256.

It then resets the isolated 99-item sandbox and performs save, reload, selected-slot move, occupied swap, first-empty stash, first-empty inventory, integrity scan, mutated reload, and reset. Both profiles, both journals, the active-profile selection, profile index, roots, bytes, and hashes remain exact. Neither normal profile contains the sandbox owner or any sandbox item ID.

Exact marker:

```text
ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99
```

## Deterministic Performance Acceptance

The runner creates unique canonical `ProfileState` ownership domains with per-profile issuer namespaces, owner-bound 100-slot stash containers, and all 99 equipment definitions. It times `ProfileCodec.encode`, `ProfileCodec.decode`, validation, `ProfileStore.save_profile`, and `ProfileStore.load_profile` with `Time.get_ticks_usec()` and then decodes the ownership state again to verify exact instances, containers, owners, placements, and cross-profile isolation.

Final headless measurements:

```text
ITEM_STORAGE_PERFORMANCE_ONE profile=1 items=99 containers=1 encode_ms=0.544 decode_ms=11.712 validate_ms=4.810 save_ms=32.686 reload_ms=16.432 bytes=52757
ITEM_STORAGE_PERFORMANCE_FOUR profiles=4 items=396 containers=4 elapsed_ms=266.388 bytes=211860 ceiling_ms=15000 ceiling_bytes=8388608 headless_regression_only=true
ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396
```

The 15,000 ms and 8 MiB ceilings are intentionally generous regression guards. The elapsed ceiling is more than 56 times the observed four-profile baseline, and encoded growth must also remain close to linear from the measured one-profile bytes. These headless timings are not platform-wide performance certification.

## Regression, Import, and Complete Gates

All commands used Godot 4.7.1 stable console with a newly created isolated `APPDATA` and `LOCALAPPDATA` root.

- All three Task 10 runners: exit `0`; all exact markers above.
- Required 19-suite Task 8/9 state/tamper/UI/settings/main, profile/atomic, responsive, and controller batch: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Upgrade-recipient real controller runner: exit `0`; `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)`.
- Fresh editor import: exit `0`; no parse, script, loader, or failed-resource error.
- Complete suite: exit `0` in 67.5 seconds; `TEST_SUMMARY: PASS (131 suites)`; sandbox hash remained `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe`.

The focused and complete suites emitted their established intentional negative-path diagnostics. The complete suite retained only the established shutdown resource/object diagnostics and no Task 10 assertion, parser, script, loader, resource, input, or UI failure.

## Artifact and Review Boundary

The fresh import recreated only `.gd.uid` sidecars proven absent by the clean pre-import status, including sidecars for the new runners/contract and earlier Plan 4B files. They were removed by exact path and are not part of the Task 10 commit. The disposable isolated runtime root was also removed after verification.

Commit message: `test: verify item sandbox ownership and layouts`

Stop after the focused Task 10 commit for independent review. Task 11 has not started.
