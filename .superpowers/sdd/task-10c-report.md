# Task 10C report: shared occupied-slot and reserved-slot transition planning

Status: implementation and fresh verification complete; scoped commit pending at report-writing time.

## Scope and behavior

- Added one pure `EquipmentOwnershipTransitionPlanner.preview(...)` used by runtime assignment and profile preview/apply. Profile comparison projections continue through the profile preview service and therefore consume the same planner rather than maintaining a third transition path.
- The planner operates on a defensive `ItemOwnershipState` copy, performs an exact source/destination move or occupied swap, then resolves newly introduced equipment reservations in canonical slot order.
- An occupied equipment destination returns its displaced item to the requested item's exact source slot. Further reserved-slot occupants use the primary storage endpoint first, followed by the caller's stable storage order, with the first empty slot in each container.
- A newly equipped reserving item retains an offhand only when `EquipmentEligibility.is_compatible_reserved_item(...)` accepts it. This preserves the existing matching-quiver item-type and weapon-family exception while displacing shields and mismatched quivers.
- Reverse occupied swaps place the storage occupant into the vacated equipment slot and preserve both identities. The planner reports all items newly entering equipment in canonical slot order, so runtime and profile activation reject any newly placed inactive item on either side of a swap.
- If any required displacement has no storage vacancy, planning returns a stable item/source/destination/displaced-item/reserved-slot diagnostic and exposes no candidate. Runtime ownership, immutable registry documents, equipment sources, cached snapshot identity, stat revision, and signals remain unchanged.
- Existing class, slot, handedness, reservation, quiver, complete-loadout, activation, and final-stat validation remain in their authoritative services. Generator and action-validation work were not changed.

## TDD evidence

The controlled RED command ran after the new behavior assertions were written and before the planner or service wiring existed:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_assignment_service.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_profile_storage_projection.gd
```

Accepted result:

```text
TEST_SUMMARY: FAIL (13 failures)
TASK10C_RED_EXIT_CODE=1
```

The failures covered occupied runtime swaps, two-hand/offhand displacement, deterministic storage placement, the matching-quiver follow-on path, insufficient-capacity contextual rejection, profile two-hand preview/apply, and comparison availability. The runner parsed every suite and returned a normal assertion summary.

The first GREEN attempt left five failures in the capacity fixture only. Investigation showed that `inventory_columns = 2` produces ten runtime slots; the fixture had filled two rather than the container's actual capacity, so the planner correctly committed. The test was corrected to fill `context.run_inventory().capacity`, after which the intended rejection and all atomicity assertions passed.

## Final focused and affected gates

The final four-suite Task 10C behavior gate passed:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10C_GREEN_ATTEMPT2_EXIT_CODE=0
```

The expanded twelve-suite affected gate covered assignment, transition, player-run context, profile assignment/projection, activation, resolved and item comparisons, Armoury, Warehouse, Developer Item Sandbox, and run ownership:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10C_AFFECTED_EXIT_CODE=0
```

Independent review reported no actionable Critical, Important, or Minor findings. Its optional hardening suggestion was to make successful multi-item displacement prove the synchronous observer boundary directly. The existing RED-covered two-hand scenario now additionally asserts one signal, one revision increment, affected-cache replacement, immutable item records, and a synchronous observer view containing the committed main hand, cleared offhand, deterministic stored shield, and equipment source. The final five-suite post-review gate passed with zero parser/script/test-failure markers:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10C_POSTREVIEW_FOCUSED_EXIT_CODE=0
TASK10C_POSTREVIEW_FOCUSED_BAD_MARKERS=0
```

### Configured storage-order follow-up

A reviewer-suggested focused regression fills the primary/source stash completely after the occupied swap, gives the next configured stash occupied slots `0..3`, and leaves a still-later configured stash empty. Preview and apply both place the reserved offhand in slot `4` of the next configured stash. This proves stable configured-container ordering wins over a later container's lower vacancy, and that the selected container uses its first empty slot. The same regression proves exact source-slot replacement, unchanged item records, unchanged preview input, and preview/apply parity.

Focused planner/profile gate:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10C_STORAGE_ORDER_FOCUSED_EXIT_CODE=0
TASK10C_STORAGE_ORDER_FOCUSED_BAD_MARKERS=0
```

This follow-up changed only the profile assignment test and this report. No production file changed, so no additional broad run was required.

## Integration and complete suite

Godot: `4.7.1.stable.official.a13da4feb`.

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10C_EQUIPMENT_INTEGRATION_EXIT_CODE=0

ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99
TASK10C_STORAGE_PROFILE_INTEGRATION_EXIT_CODE=0

TEST_SUMMARY: PASS (165 suites)
TASK10C_FULL_EXIT_CODE=0
```

After the review-hardening assertion, the exact final diff received a second complete-suite run:

```text
TEST_SUMMARY: PASS (165 suites)
TASK10C_FINAL_FULL_EXIT_CODE=0
TASK10C_FINAL_FULL_BAD_MARKERS=0
```

The complete suite retained its established intentionally asserted negative-path errors and warnings. It emitted no Task 10C assertion, parser, script-load, or suite-load failure and exited `0`.

## Files and hygiene

- `.superpowers/sdd/task-10c-report.md`
- `scripts/equipment/equipment_ownership_transition_planner.gd`
- `scripts/equipment/equipment_assignment_result.gd`
- `scripts/equipment/equipment_assignment_service.gd`
- `scripts/equipment/equipment_eligibility.gd`
- `scripts/equipment/equipment_transition_service.gd`
- `scripts/equipment/profile_loadout_assignment_service.gd`
- `tests/unit/test_equipment_assignment_service.gd`
- `tests/unit/test_profile_loadout_assignment_service.gd`
- `tests/unit/test_profile_storage_projection.gd`

`git diff --check` passed. Godot generated a `.gd.uid` sidecar for the new planner alongside the worktree's pre-existing untracked sidecars. No `.gd.uid`, `.import`, log, settings root, or scratch artifact is part of the intended commit.

## Remaining concern

No known Task 10C functional concern remains. The planner intentionally handles ownership placement and reserved-slot displacement only; structural eligibility, activation, stat projection, persistence, and runtime source commit remain separate existing validation/commit boundaries.
