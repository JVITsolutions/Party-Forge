# Task 10I report: aggregate stat finiteness and profile persistence validation

Status: implementation, TDD, hardened verification, review, and scoped commit complete.

## Scope and behavior

- Starting head: `4efb6a5373b1913bde2d8033dae54e1c7bd7bd99` on `feat/equipment-attribute-application` in the isolated equipment-attribute worktree.
- `MemberStatResolutionService` now validates every canonical catalog value after raw aggregation and again after derived-source final aggregation. A non-finite value returns no raw, derived, or final snapshot.
- The stable error contract is `PARTY_FORGE_STAT_RESOLUTION_ERROR member=<id> stat=<id> stage=<raw|final> value=<value> reason=resolved value is non-finite`.
- The validation is universal finiteness only. Task 10I adds no arbitrary stat cap or new nonnegative rule.
- Because transition, coordinated non-equipment refresh, and resume reconstruction already share member resolution, all three boundaries now reject an aggregate overflow before committing observable state.
- `ProfileLoadoutAssignmentService` now resolves the selected class base plus the candidate activation source and validates every owned action before publishing candidate ownership/loadout documents. Preview and apply therefore share the same pre-persistence boundary.
- Profile validation accepts optional `StatCatalog`, `DamageTypeCatalog`, and `AttributeProjectionTuning` dependencies while preserving the existing constructor defaults. `ProfileStorageProjection` passes its injected catalog/tuning dependencies through to assignment validation and uses them for comparison resolution and action estimates. Its assignment catalog replaces matching default classes and appends an injected non-default class, so the exact rendered class is authoritative for preview validation.

## TDD evidence

The resolver controlled RED used four individually finite `MORE` modifiers that overflowed `max_health` in the raw pass, plus a separate fixture that remained finite until Constitution-derived projection overflowed final `max_health`. Before production changes it exited `1` with:

```text
TEST_SUMMARY: FAIL (6 failures)
```

The six failures were the two accepted resolutions, two missing stable diagnostics, and two leaked partial-resolution contracts. The fresh resolver GREEN exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The profile controlled RED covered final-stat overflow, owned-action overflow, exact persistence bytes, input/item immutability, ownership/loadout preservation, constructor compatibility, and custom-catalog parity. After fixture-only schema corrections, the accepted RED exited `1` with:

```text
TEST_SUMMARY: FAIL (9 failures)
```

Failures were confined to accepted preview/apply overflow and the missing injected-dependency boundary. The fresh profile GREEN exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

Older Task 10D action-overflow fixtures originally reused class capability tags. Universal base-sheet finiteness correctly caused those fixtures to fail earlier than their intended action-derived boundary. With review direction, the affected owned actions and modifiers now share dedicated action-only tags. Critical/rate fixtures keep canonical stats finite and overflow only derived critical/DPS arithmetic, retaining genuine exact action-context coverage without weakening the universal sheet gate.

Internal review found that the first custom-catalog parity test still used a default Fighter ID. A new injected-class regression then produced the controlled review RED:

```text
TEST_SUMMARY: FAIL (1 failures)
```

The projection catalog now appends an injected class when no default class ID matches. The two-suite profile assignment/projection GREEN and final re-review both passed; re-review reported no Critical, Important, or Minor finding and a `READY` verdict.

## Atomicity and isolation coverage

- Equipment preview rejection preserves ownership bytes, activation, member sources, class and item resources, revision, affected cache identity, and signals.
- Coordinated refresh and resume rejection preserve exact sources, activation, revision, affected and unrelated base/action cache identity, signals, and bound runtime health.
- Profile preview/apply rejection preserves the input profile, primary persistence bytes, loaded ownership/loadout documents, and immutable item records.
- The 24-member integration rejects both action-only and non-action aggregate overflow for member 1. Members 2-24 retain exact base/action snapshot identities and revisions, while ownership, item bytes, activation, sources, shared revision, signals, and runtime health remain unchanged.

## Verification

Fresh affected nine-suite gate:

```text
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (0 failures)
```

The gate covered shared resolution, equipment transition, non-equipment refresh/resume, profile assignment/storage projection, action estimates, run context, profile storage, and item transactions.

Fresh integrations:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99
```

Fresh hardened complete suite:

```text
TEST_SUMMARY: PASS (166 suites)
```

All accepted commands exited `0`. There was no captured `SCRIPT ERROR`, parser/loader error, compatibility failure, test failure, fatal, or crash. Complete-suite domain errors and storage warnings were the established asserted negative paths.

## Files in scope

- `.superpowers/sdd/task-10i-report.md`
- `scripts/stats/member_stat_resolution_service.gd`
- `scripts/equipment/profile_loadout_assignment_service.gd`
- `scripts/ui/storage/profile_storage_projection.gd`
- `tests/unit/test_member_stat_resolution_service.gd`
- `tests/unit/test_equipment_transition_service.gd`
- `tests/unit/test_non_equipment_activation_refresh.gd`
- `tests/unit/test_profile_loadout_assignment_service.gd`
- `tests/integration/equipment_attribute_application_runner.gd`

## Hygiene and concerns

- No UID, import, log, scratch, generated data, or unrelated production file is included.
- The worktree retains its protected pre-existing untracked `.gd.uid` sidecars; they remain unstaged and unmodified by the scoped commit.
- No open Task 10I functional concern is known.
