# Task 9 Living Forge Extraction Picker Report

## Scope

- Exact base: `54afb374b11bc01d5028e3106ba70ff6be1cff56`.
- Task: add the typed terminal extraction presentation boundary, exact selection controller, Living Forge extraction card/panel, and stable HUD presentation owner.
- Excluded: Task 10 terminal orchestration/recovery, run-result or recap work, tactics/gambits, push, merge, and worktree cleanup.
- Historical `.superpowers/sdd/task-9-report.md` remains exact git blob `5ca22b51b5b89beb8fc07c31cb6599ec53024f4b`.

## TDD RED

The three Task 9 unit suites were authored before their production contracts and run with:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_terminal_extraction_view_model.gd tests/unit/test_terminal_extraction_selection_controller.gd tests/unit/test_terminal_extraction_panel.gd
```

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (4 failures)`.
- Classification: only the then-missing typed item/projection, view-model, controller, and panel scene contracts failed; there was no unrelated parser or loader noise.

The integration runner was also authored before production and run with:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/terminal_extraction_flow_runner.gd
```

- Exit: `1`.
- Marker: `TERMINAL_EXTRACTION_FLOW_SUMMARY: FAIL`.
- Classification: the runner named only the absent Task 9 projection/controller/card/panel surface.

Final review expanded the test boundary before its corresponding repair. The focused suite produced `TEST_SUMMARY: FAIL (2 failures)` for duplicate automatic identities during stale reconciliation. The real panel integration produced `TERMINAL_EXTRACTION_FLOW_SUMMARY: FAIL` for full item-24 visibility and deterministic reverse footer focus. The minimum repair then added complete duplicate validation, focus-entered scroll visibility, and explicit reverse footer neighbors.

## Implemented Contract

- `TerminalExtractionViewModel` builds a value-only, copy-owned picker projection from the Task 7 policy/source boundary. Canonical policy order is retained; names, rarity, detail, and comparison data come from the existing catalog-backed item presentation services. Live and JSON cold-source inputs produce byte-equivalent item detail/comparison documents.
- `TerminalExtractionSelectionController` privately retains copied exact `ExtractionSelection` tokens. All-fit selects all, constrained and zero-capacity policies select none, automatic items remain locked, capacity cannot be exceeded, returned selections preserve policy order, and duplicate automatic/eligible/cross-group identities fail closed.
- Unused-capacity acknowledgement exists only when both capacity is unused and ordinary items will be lost. Any selection change or reconcile resets it. Pending state rejects mutation. Reconcile preserves only exact container-and-slot source tokens and reports removed or changed selected IDs in prior canonical order.
- `ForgeExtractionItemCard` is a real always-processing button whose authority is only a stable item ID. It uses explicit `AUTOMATIC · LOCKED`, `SELECTED`, and `WILL BE LOST` text plus icon/shape/accessibility state, has a 48-pixel-or-larger target, and emits identical stable-ID intent from mouse, keyboard, and controller activation.
- `TerminalExtractionPanel` is a full-screen always-processing pointer-stopping terminal overlay with no combat route. It presents automatic retention, a 24-item scrollable eligible grid, exact persistent counts and canonical lists, typed player-safe preflight failures, disabled invalid confirmation, local unused-capacity acknowledgement, pending duplicate blocking, and explicit detail/tooltip force-dismiss and exact focus return.
- The picker owns a closed focus path while paused: real Enter, Space, Joy A, mouse, D-pad traversal through item 24, footer traversal, reverse traversal, Cancel consumption, item-24 scroll visibility, and underlying combat pointer blocking are exercised by the integration runner.
- Settings use the shared Living Forge theme/accessibility variations for high contrast, UI scale, and text scale. Picker state changes have no required animation. This task makes no Task 14 aesthetic or screenshot acceptance claim, and it does not claim that the pre-existing `ItemTooltipCard` hard-coded font overrides gained new scale behavior.
- `HUD/TerminalExtraction` is the stable scene owner. `show_terminal_extraction`, `show_terminal_resolution_pending`, and `hide_terminal_extraction` delegate presentation only. Main orchestration remains intentionally deferred to Task 10.

## GREEN Verification

### Exact Task 9 unit gate

The exact three-suite command above was repeated after the final repair.

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.

### Exact Task 9 integration gate

The exact integration command above was repeated after the final repair.

- Exit: `0`.
- Marker: `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS`.

### Retained HUD and Task 7/8 regressions

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_run_terminal_snapshot.gd tests/unit/test_player_run_context.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
```

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.
- The emitted HUD unavailable and duplicate-equipment-source diagnostics belong to asserted retained negative-path cases.

The retained real HUD input and party-scale runners both exited `0` with `COMBAT_HUD_INPUT_SUMMARY: PASS` and `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`.

### Complete unit regression

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
```

- Exit: `0`.
- Exact terminal marker after the final production repair: `TEST_SUMMARY: PASS (250 suites)`.
- The filtered completion stream contained no `SCRIPT ERROR` or `TEST_FAILURE` marker.

### Import, UID classification, and repository checks

- Headless import completed with exit `0`.
- Cold import produced 51 unrelated missing cache UID sidecars; all 51 were classified and removed. Exactly the ten intended Task 9 UIDs remain:
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

## Principal SHA-256 Evidence

- `terminal_extraction_item_projection.gd`: `1a50feff2384ec7c6e7f683637efb2dce9a74a8fa736383c4cfb7d7407af38c1`
- `terminal_extraction_projection.gd`: `cf8a835865586d65c065ea57f0efb86521041d00345f26f90f306de5ba73096a`
- `terminal_extraction_view_model.gd`: `c72a1a4bdf07b38607fc3346a82b29424870d206d402cd252595369c52f69653`
- `terminal_extraction_selection_controller.gd`: `449ca82de9d0018d4b92368582d7d1e576c276a194add2239feb1e1fe1cd683f`
- `terminal_extraction_panel.gd`: `5685c47fa688548bbd18d317a0e1594bda672cec9ee63bcb6c742097861ba8d0`
- `forge_extraction_item_card.gd`: `3a7d1b279577be53000c9ca0468a40d0359dc515a994f3ee6cc84d053bab5fbe`
- `terminal_extraction_panel.tscn`: `caa8dd9130ec8259c545f67cb13a7d6d9b6820d255bf86ed1e03ea2d5adb2384`
- `forge_extraction_item_card.tscn`: `eaf359cedd55c6370ad7133e1e5c5098885e585f97ebf9f38fa9e4eea3ed9328`
- `test_terminal_extraction_view_model.gd`: `82218dd9e3ece4b91eba12a9eb038e2eede8bc334f9bf2619433ca974b574cac`
- `test_terminal_extraction_selection_controller.gd`: `ca38d5af68ed790dbe6c0491df85fd561baf21fdafc01e6c5f902e1ec96ca7e0`
- `test_terminal_extraction_panel.gd`: `e77deaa2e74d627375a0aa8511490cdddac6c98224a8fdd3541613398807d764`
- `terminal_extraction_flow_runner.gd`: `02f907c6e4e5b45e9eef58001adb60a250e7ef79db7f59acc1a8c29c26801fd5`

## Delivery State

- Task 9 implementation and proportional verification are complete in the isolated worktree.
- No Task 10 orchestration, result/recap work, tactics, push, merge, or worktree cleanup was performed.
