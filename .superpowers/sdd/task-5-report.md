# Task 5 report: deterministic active and disabled equipment

Status: implementation, verification, and scoped commit complete on `feat/equipment-attribute-application`. Task 6 was not started.

## Scope and contracts

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Starting head: `1ffc958` (`fix: reject unknown equipment modifier tags`).
- Task 5 commit: this report's commit (`feat: disable equipment with unmet attributes`); resolve its immutable hash with `git log -1`.
- Added `EquipmentActivationResolver.resolve(...)` with the approved PartyManager preview inputs and one deterministic fixed-point activation path.
- Added `EquipmentActivationResult` with `is_active()`, sorted `disabled_reasons()`, sorted `active_item_ids`, `raw_attributes`, the final equipment `source`, structured failure state, and a defensive `copy()`.
- Split `EquipmentEligibility` into structural and attribute-requirement validation while retaining `validate_equip()` as the legacy combined contract.
- `EquipmentAssignmentService` now validates complete candidate loadouts structurally. Attribute activation and rejection of a newly placed disabled item remain deliberately owned by Task 6's transition coordinator.

## TDD RED evidence

The required focused command ran before either activation production script existed and before assignment validation was changed:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_assignment_service.gd
```

Exact accepted RED result:

```text
TEST_SUMMARY: FAIL (3 failures)
TASK5_RED_EXIT_CODE=1
```

The two activation assertions failed because the resolver/result scripts were absent. The assignment assertion failed because complete-loadout validation still rejected an unmet attribute requirement. The suite itself parsed, executed, and returned a normal assertion summary.

## Implementation behavior

- Resolution begins with zero active items and projects only the current active set through the Task 4 `EquipmentModifierProjector`.
- Every pass combines that projected source with non-equipment sources and resolves raw attributes through the existing `StatResolver`; no parallel stat math was added.
- Newly eligible equipped items are added in sorted identity order. The final active set is reprojected once, and disabled requirements are computed from the final raw attributes.
- A support item activated by base Strength can activate a dependent item on a later pass.
- A dependent item cannot satisfy its own requirement, and mutually dependent items cannot bootstrap from insufficient base attributes.
- Removing support leaves the dependent item in its slot but disables it and removes every affix from the projected source. Restoring support reactivates it automatically.
- Active IDs and each disabled-reason list are sorted. Repeated identical inputs produce equivalent active ordering and final source documents.
- Invalid class, slot, handedness/reservation, quiver, occupancy, and ownership/container assignments remain atomic structural failures through the existing assignment service.

## Immutability and defensive boundaries

- Activation reads defensive ownership registry/container copies and never mutates the caller's `ItemOwnershipState`, immutable item records, equipment definitions, item foundation definitions, base values, capabilities, or non-equipment sources.
- Assignment preview continues to build a copied candidate and leaves both ownership input and class Resources unchanged.
- `EquipmentActivationResult.copy()` owns independent active/disabled collections, an independent final equipment source, and an independent core-attribute snapshot with revision, capabilities, values, and breakdowns preserved.
- Tests mutate the copied source, raw Strength, and returned active-ID array and prove the original result is unchanged.

## Verification evidence

Godot: `4.7.1.stable.mono.official.a13da4feb`.

Final focused gate after all implementation and test changes:

```text
TEST_SUMMARY: PASS (0 failures)
TASK5_FINAL_FOCUSED_EXIT_CODE=0
TASK5_FINAL_FOCUSED_PASS_MARKERS=1
TASK5_FINAL_FOCUSED_BAD_MARKERS=0
```

Fresh complete suite after the final change:

```text
TEST_SUMMARY: PASS (161 suites)
TASK5_FINAL_FULL_EXIT_CODE=0
TASK5_FINAL_FULL_BAD_MARKERS=0
TASK5_FINAL_FULL_EXPECTED_ERROR_LINES=56
TASK5_FINAL_FULL_WARNING_LINES=10
```

The complete runner's errors and warnings are established intentional negative-path diagnostics. There were no `TEST_FAILURE`, script, parse, or load-failure markers.

`git diff --check` passed before staging. The bounded editor import registered both new global classes and exited `0`.

## Files and hygiene

- `.superpowers/sdd/task-5-report.md`
- `scripts/equipment/equipment_activation_result.gd`
- `scripts/equipment/equipment_activation_resolver.gd`
- `scripts/equipment/equipment_eligibility.gd`
- `scripts/equipment/equipment_assignment_service.gd`
- `tests/unit/test_equipment_activation_resolver.gd`
- `tests/unit/test_equipment_assignment_service.gd`

Godot generated `.gd.uid` sidecars for both new scripts and the new test alongside the worktree's pre-existing untracked sidecars. No `.gd.uid`, `.import`, `.godot`, ignored scratch artifact, or unrelated file is staged or included in the Task 5 commit.

## Concerns

- No open Task 5 functional concern is known.
- Task 5 intentionally does not commit ownership/stat-source transitions or reject a newly placed item that remains disabled. Those atomic run-context behaviors, health refresh, cache invalidation, and bootstrap reconstruction remain Task 6 scope.
- The complete runner output is not diagnostically pristine because established tests intentionally exercise rejection paths; the authoritative full result is exit `0`, `PASS (161 suites)`, and zero failure/script/parse/load markers.
