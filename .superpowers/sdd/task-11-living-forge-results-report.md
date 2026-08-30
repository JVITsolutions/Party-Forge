# Task 11 — Truth-Only Living Forge Results Report

Date: 2026-08-30
Assigned base: `98c59769c92e982d79a9e09b6cf68d76e8e59f52`
Scope: Task 11 only. No Main cutover, boot/restart/abandon lifecycle, tactics/gambits, push, merge, or destructive worktree cleanup.

## Outcome

Implemented defensive recap/provider/result projections, required truth-checked loot projection, the typed result view model, and a full Living Forge replacement result panel whose only presentation entry point is `present(projection)`.

The finalized recap is limited to verified outcome/duration, ordered terminal party members and levels, automatic IDs proven in the refreshed leader loadout, selected IDs proven in refreshed stash, protected IDs proven in Recovery Overflow, and lost IDs proven absent. No production build, build-history, consequence, telemetry, value, profile-delta, or highlight provider exists.

## RED evidence

Exact unit command used throughout:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recap_projection.gd tests/unit/test_run_result_projection.gd tests/unit/test_run_result_panel.gd
```

Exact lifecycle command used throughout:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/run_result_lifecycle_runner.gd
```

Observed RED checkpoints:

- Initial API RED: unit exit `1`, `TEST_SUMMARY: FAIL (9 failures)`; lifecycle exit `1`, `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (1 failures)`.
- Strengthened behavior RED: unit exit `1`, `TEST_SUMMARY: FAIL (14 failures)`; lifecycle exit `1`, `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (1 failures)`.
- Provider/log/navigation strengthening RED: unit exit `1`, `TEST_SUMMARY: FAIL (16 failures)`; lifecycle exit `1`, `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (1 failures)`.
- Final code/UI repair RED: unit exit `1`, `TEST_SUMMARY: FAIL (14 failures)`; lifecycle exit `1`, `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (10 failures)`.
- Final modal-scope RED: unit exit `1`, `TEST_SUMMARY: FAIL (4 failures)`; lifecycle exit `1`, `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL (8 failures)`.

The final RED fixtures cover deterministic provider ordering by semantic kind/display order/provider ID, reversed-input identity, exact optional failure/invalid logs, reserved and duplicate IDs, fresh resolution copies per provider, ordered non-ID/name party truth, multiple loot IDs per bucket, overlap/duplicate rejection, strict finalized construction, typed recovery safety, exact action sets, long-list focus traversal, modality parity/payloads, modal isolation, and truthful rendered defeat/victory headlines.

## GREEN evidence

Final exact unit result:

```text
TEST_SUMMARY: PASS (0 failures)
exit 0
```

Final exact lifecycle result:

```text
RUN_RESULT_LIFECYCLE_SUMMARY: PASS
exit 0
```

Relevant adjacent checks:

- Focused terminal/resolution/extraction units: `TEST_SUMMARY: PASS (0 failures)`, exit `0`.
- `terminal_extraction_flow_runner.gd`: `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS`, exit `0`.
- `responsive_ui_geometry_runner.gd`: `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`, exit `0` (the runner emitted its established settings-save fixture warnings).
- Pre-change complete baseline: `TEST_SUMMARY: PASS (252 suites)`, exit `0`.

## Design and truth decisions

- Core outcome, duration, party, and loot are required and fail the complete projection closed when invalid.
- Optional providers receive fresh snapshot and accepted-resolution copies. Empty/error/invalid results log stable provider ID plus exact error and omit without contaminating later providers.
- Finalized projection validation rejects duplicate or semantically out-of-order sections, wrong core semantic/content, snapshot-party drift, duplicate party identities, and empty typed party lists.
- Interrupted Armoury/Return/Quit depends only on typed durable recovery safety. Protect additionally requires typed automatic-only blockage and an exact non-empty displaced-ID proof matching the known count.
- Pending and interrupted projections expose no recap or durable-success claims. `Retry Results` alone receives default focus for projection interruption.
- Finalized presentation leads with the verified `VICTORY`/`DEFEAT` plus duration headline and defaults safely to `Return to Forge`; Restart and Quit are never default focused.
- Recap rows are bounded, expandable, named for accessibility, at least 48 px, explicitly linked through 24-member/30-loot traversal to the footer, and use the Living Forge panel/inset/primary/secondary/destructive theme roles.
- Protect confirmation uses exact copy, primary warning treatment, safe Cancel default, isolated recap/footer focus and activation, trapped Tab/Shift-Tab/directional navigation, `ui_cancel` safe dismissal, exact initiating-focus restoration, and duplicate-pending suppression.

## Imported Task 11 UIDs

Exactly these 13 Task 11 sidecars are intended:

1. `scripts/ui/run_result/run_recap_entry_projection.gd.uid`
2. `scripts/ui/run_result/run_recap_section_projection.gd.uid`
3. `scripts/ui/run_result/run_recap_provider.gd.uid`
4. `scripts/ui/run_result/run_recap_provider_result.gd.uid`
5. `scripts/ui/run_result/run_loot_recap_provider.gd.uid`
6. `scripts/ui/run_result/run_result_party_member_projection.gd.uid`
7. `scripts/ui/run_result/run_result_projection.gd.uid`
8. `scripts/ui/run_result/run_result_projection_result.gd.uid`
9. `scripts/ui/run_result/run_result_view_model.gd.uid`
10. `tests/unit/test_run_recap_projection.gd.uid`
11. `tests/unit/test_run_result_projection.gd.uid`
12. `tests/unit/test_run_result_panel.gd.uid`
13. `tests/integration/run_result_lifecycle_runner.gd.uid`

The separately known 51 import-fallout sidecars were verified untracked and unrelated, then excluded. Existing tracked Task 10 UIDs were preserved.

## Concerns and deferred scope

- Current `Main` still references the legacy result-panel signals. The recovery lifecycle runner therefore logs missing `restart_requested`/`quit_requested` until Task 12 performs the approved Main signal/presentation cutover. No compatibility shim or Task 12 edit was added, per final code/spec review.
- Final visual acceptance remains deferred to approved Task 14; Task 11 verifies theme roles, scaling/high-contrast selection, bounded geometry, input reachability, and accessibility behavior mechanically.

Final code/spec re-review and final UI/UX code/truth review both approved this implementation with no remaining Critical, Important, or Minor findings.
