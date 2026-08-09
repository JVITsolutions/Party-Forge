# Task 10D report: candidate action validation before equipment commit

Status: implementation, review follow-up, verification, and scoped commit complete.

## Scope

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`
- Branch: `feat/equipment-attribute-application`
- Starting head: `f510919` (`test: cover equipment displacement storage order`)
- Task 10D commit: this report's commit (`fix: validate candidate equipment actions`); use `git log -1` for the immutable hash.
- Added `ClassDefinition.owned_actions()` as the authoritative current-model action enumeration. It returns a new array in deterministic primary/support order, excludes null entries, and deduplicates identical resource instances. `EquipmentTransitionService` and `LedgerDataProvider` both use it.
- Equipment preview now resolves every owned action through `MemberStatResolutionService` with `DamageResolver.action_tags_for(attack)` and the complete candidate source list, including the candidate equipment source.
- Every damaging candidate action must produce an available result through `ActionCombatEstimateService.estimate_from_snapshot()`. No combat formula was duplicated.
- The shared estimate path now rejects non-finite or negative component projections, normal/critical/average component values and totals, action rate, and DPS with contextual unavailable reasons. It also applies the existing exact-one playable archetype validation.
- Healing actions still pass authored validation and tagged snapshot resolution but are not forced through damaging archetype or estimate requirements.
- Missing primary actions, invalid damage types, tagged overflow, and unavailable estimates return the stable outer `PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR` context with the affected action and nested detail.

## TDD evidence

### Baseline

The pre-edit affected baseline passed:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10D_BASELINE_EXIT_CODE=0
```

It covered equipment transition, action estimates, ledger data, and game-catalog behavior.

### Controlled RED

Tests were added before production changes and run with:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_transition_service.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_game_catalog.gd
```

Accepted result:

```text
TEST_SUMMARY: FAIL (39 failures)
TASK10D_RED_EXIT_CODE=1
```

There were no parser or suite-load aborts. Failures were confined to the absent owned-action interface, absent candidate action gate, currently non-contextual estimate invariant reasons, and the expected state/revision/cache/signal mutations caused by the invalid transition being accepted.

### First focused GREEN

The transition, estimate, catalog, and ledger suites passed on the first implementation run:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10D_GREEN_ATTEMPT1_EXIT_CODE=0
```

## Coverage

- Candidate equipment modifiers that are inert in the untagged sheet but overflow the exact melee action snapshot.
- Mixed fire/cold action components with overflow isolated to the cold component.
- Invalid damage type rejection.
- Critical-multiplier overflow, action-rate overflow, DPS overflow, mixed normal-total overflow, and negative component projection.
- Healing support-action exemption without a primary damage archetype requirement.
- A class with both primary and damaging support actions, proving the second action is validated.
- Missing primary-action rejection.
- Deterministic owned-action order, defensive return arrays, identical-resource deduplication, and null filtering.
- Run-context rejection before commit, preserving ownership, activation, sources, base/action cache identity, revision, signals, bound runtime current/maximum health, item records, and class resources.
- Successful existing transition coverage continues to prove one revision and one member-local signal.
- The 24-member integration adds a failed tagged-action transition and proves member 1 ownership, activation, caches, revision, signals, bound current/maximum health, and immutable items remain unchanged while members 2-24 retain exact cache identity.

## Final verification

Expanded 11-suite affected gate:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10D_AFFECTED_EXIT_CODE=0
```

The gate covered Tasks 2, 3, and 6 resolution/combat/transition paths plus PartyManager, PlayerRunContext, ledger, comparison, and catalog consumers.

Equipment integration:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10D_INTEGRATION_ATTEMPT1_EXIT_CODE=0
```

Complete suite:

```text
TEST_SUMMARY: PASS (165 suites)
TASK10D_FULL_EXIT_CODE=0
```

### Review follow-up

Independent scoped review found no Critical or Important issue. Its one Minor coverage finding was valid: the rejection tests named health preservation but did not bind a real runtime `HealthComponent`. The unit rollback fixture and 24-member integration now bind member-one health and assert exact current and maximum health preservation across the rejected transition.

Fresh post-review gates:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10D_POSTREVIEW_FOCUSED_EXIT_CODE=0

EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10D_POSTREVIEW_INTEGRATION_EXIT_CODE=0

TEST_SUMMARY: PASS (165 suites)
TASK10D_POSTREVIEW_FULL_EXIT_CODE=0
```

Godot: `4.7.1.stable.mono.official.a13da4feb`.

## Files in scope

- `.superpowers/sdd/task-10d-report.md`
- `scripts/data/class_definition.gd`
- `scripts/equipment/equipment_transition_service.gd`
- `scripts/ui/ledger/action_combat_estimate_service.gd`
- `scripts/ui/ledger/ledger_data_provider.gd`
- `tests/integration/equipment_attribute_application_runner.gd`
- `tests/unit/test_action_combat_estimate_service.gd`
- `tests/unit/test_equipment_transition_service.gd`
- `tests/unit/test_game_catalog.gd`

## Hygiene and concerns

- No generator, swap planner, storage comparison, tooltip, or equipment-screen implementation changed.
- `git diff --check` passed before the final report/commit cycle.
- The worktree retains its pre-existing untracked Godot `.gd.uid` sidecars. None are in Task 10D scope and none will be staged.
- Full-suite output retains established intentional negative-path errors and storage-cleanup warnings; the authoritative result is exit `0` with `PASS (165 suites)`.
- One post-review expanded focused attempt printed `PASS (0 failures)` and then exited with Windows access-violation code `-1073741819`; it was rejected as evidence. The changed transition suite passed alone, and the exact expanded batch rerun exited `0` with `PASS (0 failures)`, so the fault was not reproducible.
- The current class model has only primary and support action fields. Future multiple-primary or additional action fields must extend `ClassDefinition.owned_actions()` so all consumers stay on the same enumeration path.
