# Task 9 Report: Isolated Developer Item Sandbox Interface

## Scope

Implemented only Plan 4B Task 9 on `feat/plan-4b-item-ownership` from parent `c1ae5834d1f06f09a5f2800fd71ebf650608a1fb`.

Created:

- `scripts/ui/developer_item_sandbox.gd`
- `scenes/ui/developer_item_sandbox.tscn`
- `tests/unit/test_developer_item_sandbox.gd`

Modified the Additional Settings, Settings Screen, and main scene routing named by the Task 9 brief. The Task 8 state/store received only the small public selected-slot transaction and read-only integrity surfaces required by the interface, together with strict journal reconstruction for those canonical moves and swaps. `project.godot` received the required controller west-face/keyboard pickup action.

No Task 10 work, production equipment application, randomized loot, ground pickup, extraction, run loss, cross-player transfer, shop, crafting, salvage, rarity audiovisual work, or future Armoury/Warehouse documentation was changed.

## Implementation Result

- Additional Settings exposes `item_sandbox_requested` and a clearly labelled launch button. It is disabled in Player Simulation and enabled only for the effective Developer Mode selector.
- Settings Screen forwards the request and records the exact page/focus restoration point without owning modal creation.
- `PartyForgeMain` reloads the authoritative saved settings on every request. Stale UI state, a forged signal, a direct method call, unlock-all, and other preview flags cannot bypass the saved-mode gate.
- Main precomposes one process-always `DeveloperItemSandbox` CanvasLayer at layer 14. Repeated valid opens are idempotent; close restores Additional Settings and the exact launch-button focus target.
- The responsive modal has safe margins, exactly five inventory buttons, exactly 100 stash buttons in a scrollable ten-column grid, a scrollable inspector, status, close, first-empty move, save, reload, integrity, and reset controls.
- Every slot exposes `container_id` and integer `slot` metadata. Rendering and inspection use defensive public projections only.
- Focus/click inspection shows base display name, instance ID, rarity, level, explicit affix/tier/operation/roll information, owner, container, and slot without mutating state.
- Mouse/keyboard drag-and-drop moves to an empty slot or swaps with an occupied slot. An outside/invalid release clears held state without mutation.
- Keyboard `X` and controller west face (Xbox X / PlayStation Square) pick up the focused populated slot; focus can then move and controller south face places/swaps. Cancel clears held mode before it can close the modal. Ordinary south-face activation while not holding only inspects.
- Source-held and eligible-destination states receive distinct affordances and interaction-mode hints. Focus neighbors form a deterministic closed modal loop across slots, inspector/actions, and close.
- First-empty operations retain their public Task 8 behavior. Arbitrary selected-slot move/swap goes through `DeveloperItemSandboxState.transfer_slots()`, the Task 4 transaction service, and `AtomicJsonStore`.
- Save, reload, integrity, reset, move, and swap surface stable success or exact failure text. Failure preserves the last usable projection and persisted bytes.

## RED-GREEN Evidence

### Accepted Route and Domain RED

Focused command covered the sandbox state, sandbox UI, Settings Screen, and main wiring suites.

Accepted result:

```text
TEST_SUMMARY: FAIL (11 failures)
TASK9_ACCEPTED_RED_EXIT=1
```

The failures were assertion-level requirements for the absent public selected-slot transfer/integrity API, selected-slot move/swap journal support, sandbox script/scene, Additional Settings signal/button, Settings forwarding, and main resources. There were no parser, loader, script, or resource failures in the accepted RED.

Two earlier attempts were rejected as evidence because the new test code contained type-inference errors and, separately, mixed indentation in a main-wiring test. Both test defects were corrected before accepting RED.

### UI Failure-Atomicity RED

A bounded closed-state `configure()` seam was required to inject failing state/store doubles without private UI access.

```text
TEST_SUMMARY: FAIL (1 failures)
TASK9_FAILURE_ATOMIC_RED_EXIT=1
```

The single intentional assertion reported the absent public configuration seam. GREEN after the seam exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

### Focused GREEN

The first UI GREEN was rejected because pre-tree test initialization left slot grids empty and produced two count assertions plus null follow-on errors. Root-cause tracing showed the tests instantiate during `SceneTree._initialize`, before normal `_ready()` timing. Initialization is now pre-tree-safe and idempotent from both `_ready()` and `open()`.

Final combined focused result for the Task 8 state, sandbox UI, Settings Screen, and main wiring suites:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (0 failures)
TASK9_COMBINED_FOCUSED_EXIT=0
```

The standalone sandbox UI suite and the failure-atomic injection suite also exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

After report creation and sidecar cleanup, the same four-suite focused command was rerun from the cleaned tree. It exited `0`, reported the same SHA-256 marker, and ended with `TEST_SUMMARY: PASS (0 failures)`.

## Interaction, Layout, and Isolation Evidence

The focused UI suite covers:

- safe modal margins at 1920x1080, 2560x1440, and 3840x2160;
- exact 5/100 slot counts, integer metadata, ten-column scrollable stash, and inspector field content;
- deterministic closed focus graph and focus-driven inspection;
- mouse drag to empty destination, occupied-destination swap, and outside-drop cancellation;
- controller/keyboard pickup, navigation, placement/swap, cancellation, and non-held south-face inspection;
- held-source and destination affordances plus control hints;
- first-empty, save, reload, integrity, reset, stable success text, and exact failure preservation;
- corrupt-document reload/integrity rejection with unchanged primary bytes, backup bytes, and usable projection;
- authoritative main gate, idempotent modal routing, cancel behavior, and exact Settings focus restoration.

The main isolation test performs a real sandbox drag transaction, then proves the active player profile's serialized bytes and semantic hash are unchanged across open, use, and close. The sandbox UI contains no private Task 8 state/store calls and does not edit ownership dictionaries.

## Fresh Import and Regression Gates

A fresh Godot 4.7.1 headless import exited `0` before final verification.

The required 20-suite regression batch covered:

- Task 8 sandbox state and Task 9 UI/settings/main routing;
- feature access, character ledger shell, and responsive ledger input;
- main menu, pause menu, and temporary hover popup;
- controller movement bindings, controls settings, and responsive UI;
- profile state, atomic profile store, profile manager, profile mutation persistence, item storage, storage reconciliation, and profile boot.

Result:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (0 failures)
TASK9_REQUIRED_REGRESSION_EXIT=0
```

The regression suites emitted only their established intentional negative-test diagnostics and exit-time leak warnings. They emitted no unexpected Task 9 parser, script, loader, resource, or UI assertion failure.

## Complete Suite

Command:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <task-9-worktree> --quit-after 720 --script res://tests/test_runner.gd
```

Result on the exact implementation tree:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (130 suites)
TASK9_FULL_SUITE_EXIT=0
```

The complete suite emitted the established intentional negative-test diagnostics and exit leak warnings (`1 FontAdvanced`, `5 CanvasItem`, `32 ObjectDB`, and `5 resources`). There was no unexpected Task 9 parser, script, loader, resource, or UI assertion failure, and the process exited `0`.

## Artifact and Review Boundary

The fresh import created fourteen previously absent untracked `.gd.uid` sidecars. A clean-untracked baseline identified them as verification artifacts; all fourteen were removed by exact path. No pre-existing sidecar was removed.

Final staging is limited to Task 9 source/scenes/tests/report, the required input action, settings/main routing changes, and the narrowly required Task 8 public API/store validation changes.

Commit message: `feat: expose isolated developer item sandbox`

Stop after the Task 9 commit for independent review. Task 10 has not started.

## Independent Review Focus-Owner Correction

Independent review reproduced a real controller-input defect in commit `01bbf30`: after a slot had been inspected, `_focused_slot_button()` returned that historical slot whenever the live viewport focus owner was a non-slot control. Holding an item, visiting an empty slot, moving actual focus to Save/Inspector/Close, and pressing controller south face therefore transferred to the stale slot. Controller west face on those non-slot controls could also pick up the last inspected populated slot.

The correction was implemented test-first with `tests/integration/task9_developer_item_sandbox_focus_runner.gd`, a real-tree runner that uses `Input.parse_input_event` and the viewport's actual focus owner.

Accepted stale-focus RED:

```text
TASK9_SANDBOX_FOCUS_SUMMARY: FAIL (9 failures)
TASK9_STALE_FOCUS_RED_EXIT=1
```

All real-tree setup and focus-reachability assertions passed. The nine intentional failures were exact projection/byte changes from south face on Save, Inspector, and Close (six failures), plus stale pickup from west face on those same non-slot controls (three failures).

The first post-fix run was rejected as GREEN evidence. Its assertions passed, but the Inspector case emitted typed-array validation errors because `_is_slot_button()` attempted to find a `Label` inside `Array[Button]`. The final predicate first requires a real `Button`; no engine error remains.

Final real-input GREEN:

```text
TASK9_SANDBOX_FOCUS_SUMMARY: PASS (0 failures)
TASK9_STALE_FOCUS_GREEN_EXIT=0
```

The minimal production correction now treats any actual non-null non-slot focus owner as no slot. Historical-slot fallback remains only when there is genuinely no focus owner, preserving the existing off-tree test seam. South face on a non-slot clears held mode without mutation; west face cannot pick stale state. Save, Inspector, and Close remain reachable through the closed focus graph.

Independent review also found that the route fixture assumed `user://tests` already existed. A pristine isolated `APPDATA`/`LOCALAPPDATA` RED exited `1` with exactly one assertion failure: `Player Simulation route fixture saves`, settings error code `7`. The fixture now creates the settings path's parent directory explicitly. The same pristine-root focused command then exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

Post-correction seeded gates on the exact tree:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (0 failures) # required 20-suite batch
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (130 suites)
TASK9_CORRECTION_FULL_SUITE_EXIT=0
```

The established intentional negative-test diagnostics and exit-time leak warnings remained unchanged. No unexpected parser, script, loader, resource, input, or UI assertion failure occurred. Both temporary pristine roots were deleted by exact validated path, and no source-adjacent verification sidecar was created.

Correction staging is limited to the sandbox focus resolution, the pristine settings fixture line, the real-input Task 9 regression runner, and this report. Task 10 remains untouched. Stop after the correction commit for another independent review.
