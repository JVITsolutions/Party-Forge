# Task 9 Living Forge Extraction Picker Report

## Scope

- Exact original base: `54afb374b11bc01d5028e3106ba70ff6be1cff56`.
- Review-repair base: `f42a17abc2376647dc9865dff037de5b6da535e1`.
- Final focus-repair base: `97422e9ce3b076e7ebef424e356bc0abf9f34b9c`.
- Task: repair the typed terminal extraction presentation boundary, exact selection controller, Living Forge extraction card/panel, and stable HUD presentation/focus owner against final UI/UX review.
- Excluded: Task 10 terminal orchestration/recovery, `Main`, run-result or recap work, tactics/gambits, push, merge, and worktree cleanup.
- Historical `.superpowers/sdd/task-9-report.md` remains exact git blob `5ca22b51b5b89beb8fc07c31cb6599ec53024f4b`.

## TDD RED

The original Task 9 RED values in the prior revision of this report are historical, reported evidence; this repair does not claim a retained original-run transcript for them.

For the review repair, all expanded unit and real-scene integration assertions were authored before repair production edits. Production paths remained untouched through both RED commands.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_terminal_extraction_view_model.gd tests/unit/test_terminal_extraction_selection_controller.gd tests/unit/test_terminal_extraction_panel.gd
```

- Exit: `1`.
- Exact terminal marker: `TEST_SUMMARY: FAIL (20 failures)`.
- Classification: 7 ordered-source/exact-identity gaps, 4 reconcile capacity-drift gaps, and 9 composite availability/grouping/high-contrast gaps.
- There was no parser, script, loader, or harness failure.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/terminal_extraction_flow_runner.gd
```

- Exit: `1`.
- Exact terminal marker: `TERMINAL_EXTRACTION_FLOW_SUMMARY: FAIL` with 26 named assertion failures.
- Classification: the failures were the approved source grouping, order-independent availability, closed focus, responsive settings, authentic input, stale detail, and HUD focus-ownership contracts.
- There was no parser or script failure.

Final self-review expanded the real integration boundary before its corresponding production repair. It first produced exactly 3 named failures: deterministic warning fallback without an initiating control plus expanded consequence-list containment in both responsive matrices. The minimum repair moved expandable lists into the one bounded body scroll and added canonical first-item fallback. Final UI/UX re-review then identified the automatic Inspect child-anchor edge. Authentic Joy A/B evidence was added first and produced exactly 2 named failures: initiating-anchor mismatch and Cancel-return mismatch. The minimum card repair now emits the actual initiating Inspect child for that action. Both incremental RED runs had clean parser/script execution and were followed by the exact integration GREEN gate.

The final focus repair also followed integration-first RED from exact base `97422e9ce3b076e7ebef424e356bc0abf9f34b9c`. Before any production edit, the real paused-tree runner added keyboard/controller availability transitions and exited `1` with `TERMINAL_EXTRACTION_FLOW_SUMMARY: FAIL`: 7 direct focus-resolution failures plus 1 downstream stale-detail cascade. There was no parser, script, loader, or harness failure. The direct cases covered Confirm becoming pending, pending clearing into retry-only failure, focused editable and newly locked items, pending dominance over successful preflight presentation, and keyboard/D-pad containment away from the underlying HUD. The stale-detail cascade exposed a layout-timing issue in the first visibility guard; the final minimal repair defers visibility until the rebuilt grid has layout, carries only the card instance ID, and safely ignores cards freed by a later projection.

The final requirement-completeness pass added the explicit invalid-projection paused-tree case before its corresponding fallback edit. It produced exactly 1 named integration failure with otherwise clean parser/script execution: the disabled item fell through to generic scene-tree order instead of the canonical terminal action order. Reusing the canonical base focus ring for `_focus_initial()` made the invalid case and its real D-pad containment pass without adding a second focus authority.

## Implemented Contract

- `TerminalExtractionViewModel` and its copy-owned item projection now retain exact member ID, member class display, container ID, container label, and slot. Contiguous typed source sections preserve canonical policy-token order without sorting or merging later repeated sources. Section headings, cards, accessibility descriptions, and consequence rows distinguish inventory/equipment, same-class members, and duplicate display names.
- `TerminalExtractionSelectionController.reconcile` preserves only exact container-and-slot tokens, then deterministically keeps the canonical first selections up to the new capacity. Capacity shrink reports trailing displaced selections in the changed list, growth does not invent selections, and every reconcile resets acknowledgement.
- `TerminalExtractionPanel` keeps one composite availability truth: copied projection validity/error, persisted structured preflight disposition/category/player reason, and pending state. One update path controls Confirm, Retry, selection mutation, pending presentation, and error copy. Within the Task 9 presentation boundary, pending always dominates availability and a structured failure persists across pending toggles. Task 10 owns request-generation correlation and stale-result rejection.
- Fresh projections collapse consequence expansions, rebuild stable contiguous source sections, apply pending/lock state immediately, and present exact automatic/selected/lost rows with owner, container ID, and slot. No display text, rendered color, or item ID alone is used as source authority.
- The base picker has an explicit closed focus ring across eligible toggle and Inspect actions, automatic Inspect actions, summary-list controls, and dynamically available footer actions. Detail and unused-capacity warning surfaces own separate trapped focus rings. Cancel closes only the active child surface; root Cancel is consumed. A stale removed detail item returns to the deterministic nearest canonical eligible item.
- Availability changes capture the current terminal-owned focus descriptor before controls are disabled, rebuild the closed ring, then resolve deterministically to enabled Retry, the still-valid exact action, the exact/nearest editable item, enabled Confirm, or the first enabled base action. Real paused-tree evidence covers Confirm-to-pending, pending-to-retry-only failure, reducible editability, item locking, successful preflight while pending, and pending clear; focus never becomes ownerless or reaches the underlying HUD.
- HUD presentation disables every non-terminal focusable descendant while the terminal is shown and restores each exact prior focus mode plus the prior focus owner/descriptor on hide. Pointer stopping remains full-screen.
- The pinned header, persistent summary, errors, and footer stay outside the single bounded vertical body scroll. Automatic retention uses a reachable bounded horizontal subscroll; eligible contiguous source sections share the body scroll. At `1280x720`, both high-contrast `150/150` and normal-contrast `80/150` UI/text matrices keep the frame/footer bounded, prevent overlap, reflow eligible sections to at most two columns, retain 48-pixel actions, and make 8 automatic plus 24 eligible items reachable.
- `ForgeExtractionItemCard` exposes explicit `AUTOMATIC · LOCKED`, `SELECTED`, and `WILL BE LOST` text/icon states, exact source identity, a real Inspect action, pending/lock behavior, and shared semantic high-contrast/focus tokens without the prior hard-coded focus border. Controller activation emits the exact focusable Inspect child as its return anchor, including for inert automatic card roots.
- Real SubViewport evidence uses actual mouse clicks/right-click, Enter, Space, mapped keyboard Inspect, Joy A/B, and Joy D-pad events. It covers item 24 and reverse footer traversal, summary expansion, exact detail source/content and Cancel return, stale fallback, warning Back/acknowledge, pending duplicate block, base/detail/warning focus containment, underlying pointer blocking, and HUD focus suspension/restoration while paused.
- The panel applies the shared Living Forge theme to itself and the reused tooltip surface. This task still does not claim that the pre-existing `ItemTooltipCard` hard-coded font overrides gained new 150% typography behavior; Task 14 remains the screenshot/aesthetic acceptance gate.
- `HUD/TerminalExtraction` remains presentation/delegation only. No Task 10 orchestration or `Main` mutation was added.

## GREEN Verification

### Exact Task 9 gates

- Exact three-suite unit command above: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Exact integration command above: exit `0`, `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS`.
- The final integration bytes include the availability-focus transition matrix and the authentic item-24 visibility/detail assertion that isolated the RED cascade.

### Retained HUD and Task 7/8 regressions

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_run_terminal_snapshot.gd tests/unit/test_player_run_context.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
```

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.
- The emitted HUD-unavailable and duplicate-equipment-source diagnostics are asserted negative-path cases.
- `combat_hud_input_runner.gd`: exit `0`, `COMBAT_HUD_INPUT_SUMMARY: PASS`.
- `combat_hud_party_scale_runner.gd`: exit `0`, `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`.

### Complete non-quiet regression

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 2400 --script res://tests/test_runner.gd
```

- Exit: `0`.
- Exact terminal marker: `TEST_SUMMARY: PASS (250 suites)`.
- The streamed run contained no `TEST_FAILURE` or `SCRIPT ERROR` marker; expected asserted negative-path diagnostics were present.

### Import, UID classification, and repository checks

- Headless editor import exited `0`.
- Import recreated 51 unrelated cache-backed UID sidecars. All 51 were classified as untracked and safely removed inside the worktree.
- Exactly the ten intended, tracked Task 9 UIDs remain present:
  - `scripts/ui/run_result/terminal_extraction_item_projection.gd.uid`
  - `scripts/ui/run_result/terminal_extraction_projection.gd.uid`
  - `scripts/ui/run_result/terminal_extraction_view_model.gd.uid`
  - `scripts/ui/run_result/terminal_extraction_selection_controller.gd.uid`
  - `scripts/ui/living_forge/components/forge_extraction_item_card.gd.uid`
  - `scripts/ui/run_result/terminal_extraction_panel.gd.uid`
  - `tests/unit/test_terminal_extraction_view_model.gd.uid`
  - `tests/unit/test_terminal_extraction_selection_controller.gd.uid`
  - `tests/unit/test_terminal_extraction_panel.gd.uid`
  - `tests/integration/terminal_extraction_flow_runner.gd.uid`
- `git diff --check`: clean.
- Historical Task 9 report blob: `5ca22b51b5b89beb8fc07c31cb6599ec53024f4b`.

## Principal SHA-256 Evidence

- `terminal_extraction_item_projection.gd`: `f26213493657d64da5d7aa90c3fbee70c21a643416a54743f10ee255dddd8dec`
- `terminal_extraction_projection.gd`: `ac3fae70b2360cb3297154d3b5fbb02023663e128d8682f2cac2d2f500b0d020`
- `terminal_extraction_view_model.gd`: `99774ea69a1433fce490e301b0f31f12efa2575229aea0aa4b544cc6e24ac6e1`
- `terminal_extraction_selection_controller.gd`: `13e06238e9177e73badda26b3641854dedcc9e841057912ef633a18a69f7c315`
- `terminal_extraction_panel.gd`: `53d18fee13fd8f15c995118d5cf0ac84199cecce7f44959930a7ffdf99a8fcf4`
- `forge_extraction_item_card.gd`: `96e5bce26c087f03e331e51abf0a16aa1fd88c1500b176937520a59d649c2109`
- `hud.gd`: `fb81400215f803db2bc0d935813a134795a9b6578d9eb260a49f860e6d1ced54`
- `terminal_extraction_panel.tscn`: `c3bf121311b09077cb477c87cc1660e47e9861e0d70bbb433b020ee6312fc699`
- `forge_extraction_item_card.tscn`: `c3a106e62cf1203c7f0d3ab2581d21652293f481b630abdff38bbf7ac59de803`
- `test_terminal_extraction_view_model.gd`: `951974bbf35a743c84d51efb06d6785d0edf08bd74807bf66429cf60e0e3c095`
- `test_terminal_extraction_selection_controller.gd`: `a6a318e20162acd0abb5dd8cfee90fd4b8e2a5db681a60266cb68d6629a1d4fb`
- `test_terminal_extraction_panel.gd`: `d0ad28d24e6cc91e5175c2a4d2122fc3d4f0289c6baa566f46a8ebbcc74480bd`
- `terminal_extraction_flow_runner.gd`: `169b048c7bc747029a2f89da43e250de03d6cf90f30ede79465639c02804bf56`

## Delivery State

- Task 9 review repair, final focus repair, and proportional verification are complete in the isolated worktree.
- No Task 10 orchestration, `Main`, result/recap, tactics, push, merge, or worktree cleanup was performed.
