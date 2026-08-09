# Task 10J report: action-tagged runtime geometry and projectile stats

Status: implementation, independent static review, and fresh verification complete; ready for integration.

## Scope and design

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`
- Branch: `feat/equipment-attribute-application`
- Starting head: `4e3f4ecea4792bfa91bfae1cbad8ee99db4a8119` (`fix: reject aggregate stat overflow before persistence`).
- Canonical `attack_range`, `area_size`, and `projectile_speed` values remain multipliers. Effective values are authored range/radius/speed multiplied by the exact resolved action snapshot.
- `ResolvedAttackGeometry.from_snapshot()` is the strict shared projection. It rejects missing snapshots, invalid multipliers, and non-finite/invalid effective geometry without substituting neutral values.
- `CombatModifiers.resolve_for_action()` routes player runtime consumers through `PartyManager.stats_for_action()` and retains the resolved snapshot and strict geometry together. The existing member/action cache remains authoritative.
- `PartyActor` now resolves primary and support geometry separately for target acquisition and attack-sequence range revalidation. `AttackExecutor` uses the same action path for melee radius, projectile range, area radius, and projectile speed. A configured manager with no matching member snapshot fails closed before execution.
- Runtime action resolution fails closed when the party manager, member state, or exact action snapshot is missing. Healing and nonprojectile actions validate only applicable geometry; they do not require projectile speed.
- `ActionCombatEstimateService` consumes the same strict projection before cadence/damage/healing formulas. Candidate validation already calls this shared estimate path, so transition, refresh, resume, and profile validation reject invalid effective geometry without a second formula.
- `ActionCombatEstimate` exposes effective range, area radius, and projectile speed. Equipment comparisons and ledger cards display relevant values; inapplicable area/projectile lines are omitted. Geometry-only changes do not alter hit, DPS, healing, or HPS.

## TDD evidence

The first test-only attempt called the not-yet-existing strict static method directly. Godot produced a parse/load abort and exit `0`; that attempt was rejected as RED evidence. The tests were changed to probe the missing interface dynamically.

Accepted controlled RED:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_resolved_attack_geometry.gd `
  tests/unit/test_action_combat_estimate_service.gd `
  tests/unit/test_resolved_stat_comparison_service.gd `
  tests/unit/test_stats_ledger_page.gd
```

Result:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK10J_CONTROLLED_RED_EXIT_CODE=1
```

Failures were confined to the absent strict snapshot projection, absent estimate geometry fields/comparison rows, and absent Fighter/healing ledger geometry lines.

The expanded runtime/rollback RED then exited `1` with `TEST_SUMMARY: FAIL (14 failures)`. It additionally proved the old executor used generic values (`14.4`, `2.5`, `11`) instead of exact action values (`18`, `3.5`, `16.5`), PartyActor did not acquire through action-only primary/healing range, missing member snapshots still launched projectiles, and effective-geometry equipment validation did not return action/range context.

Separate pre-implementation gates proved resume and coordinated 24-member refresh accepted a finite multiplier whose authored projection overflowed. The resume suite failed nine atomicity assertions; the equipment integration failed six rejection/isolation assertions.

## Coverage

- Matching action-only tags, nonmatching tags, and unrestricted plus tagged modifiers combining once.
- Runtime executor range, melee/area radius, projectile speed, and PartyActor target acquisition.
- Primary projectile and healing support actions, plus nonprojectile/no-area applicability.
- Missing manager, member state, or managed action snapshot safe stop, including healing execution.
- Pure/runtime/ledger geometry parity and geometry-only no-DPS/no-HPS behavior.
- Effective geometry overflow with individually finite authored data and resolved multipliers.
- Equipment preview rollback, resumable reconstruction rollback, coordinated source-refresh rollback, health/signal/revision/source/cache preservation.
- 24-member isolation for members 2-24 and repeated exact action-cache identity.
- Comparison symbols/accessibility text and ledger card containment at three target viewports.
- Healing/support actions in equipment comparison, including a support-only effective-range delta.
- Exact authoritative `PartyMemberState` identity, including same-ID foreign-state projectile and healing rejection.
- One reusable action context per actor/action tick through cooldown, targeting, sequence revalidation, and execution.
- Context-free combat modifiers expose cadence only; geometry multipliers require an exact action snapshot.
- Geometry-only healing comparison preserves healing amount and estimated HPS.

## Fresh verification

Godot: `4.7.1.stable.mono.official.a13da4feb`.

All accepted commands used isolated Task 10J APPDATA/LOCALAPPDATA roots inside `.superpowers/sdd`.

### Initial focused GREEN

Six runtime/transition/preview/UI suites:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10J_FIRST_GREEN_EXIT_CODE=0
```

### Expanded affected GREEN

Twelve suites covering resolved geometry, member resolution/PartyManager, estimates, runtime execution, equipment transition, non-equipment refresh/resume, profile assignment/projection, ledger provider/page, and comparison projection:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10J_AFFECTED_FOCUSED_EXIT_CODE=0
```

### Integration and cache GREEN

```text
TEST_SUMMARY: PASS (0 failures)
TASK10J_RESUME_GREEN_EXIT_CODE=0
TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1737
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10J_24_MEMBER_GREEN_EXIT_CODE=0
LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)
TASK10J_LEDGER_RESPONSIVE_EXIT_CODE=0
```

The cache probe performs 512 repeated member-one action lookups, requires exact snapshot object identity, and completed in 1.737 ms. The integration also preserves exact base/action snapshot identity for members 2-24 across rejection.

### Hardened complete suite

```text
TEST_SUMMARY: PASS (166 suites)
TASK10J_FULL_SUITE_EXIT_CODE=0
```

The complete suite retained established asserted negative-path domain errors and JSON-store/filesystem warnings. It exited `0` with no test failure marker.

### Independent review corrections and final rerun

The first static review found two Important issues and no Critical issues: missing runtime manager/member context still selected neutral geometry, and profile comparison skipped healing actions. Controlled review RED exited `1` with three expected failures: null-manager healing changed health from `40` to `58`, null-member healing changed it to `76`, and no `action:cleric_heal:range` row was produced.

Both corrections were implemented test-first. The two-suite review GREEN, widened twelve-suite gate, 24-member/cache integration, and responsive ledger integration all passed. The first repeated full gate exposed four catalog-validation failures caused by the new test fixture sharing an external affix-effect resource; no production assertion failed. The regression was rewritten to use canonical immutable inputs and direct profile-estimate comparison. It then passed in the same focused process as all three catalog-validation suites that had exposed the leak.

Final evidence after that correction:

```text
TEST_SUMMARY: PASS (166 suites)
TASK10J_FINAL_FULL_EXIT_CODE=0
```

Independent re-review found no Critical, Important, or Minor issues and returned `READY`.

### Parent review corrections and final rerun

Parent review found two Important and two Minor issues: same-ID foreign member states could borrow the authoritative member's action cache, `PartyActor` repeatedly resolved and allocated action state through one tick/request, the legacy context-free modifier path still exposed geometry multipliers, and healing comparison did not directly pin geometry-only amount/HPS parity.

Controlled parent-review RED exited `1` with four focused failures:

```text
same-ID foreign member state cannot launch a projectile: got Projectile instead of null
same-ID foreign member state cannot execute healing: expected 40, got 58
24-actor primary hot path resolves exactly one action snapshot per actor tick: failed
targeting, sequence request, and execution reuse one exact action context: expected 1 call, got 6
TASK10J_PARENT_REVIEW_RED_EXIT_CODE=1
```

The added geometry-only healing test already passed in that RED run, confirming range changes did not alter healing amount or HPS. The implementation now verifies `PartyManager.member_by_id()` returns the identical `PartyMemberState`, and one context owns the exact snapshot, geometry, cadence, member, manager, and action identity. `PartyActor` resolves that context once per action tick and passes it through target selection, sequence range revalidation, and `AttackExecutor`; the executor reuses the retained snapshot for the source adapter. Cadence is projected once inside the context. `CombatModifiers.resolve()` is explicitly deprecated for geometry and leaves range, area, and projectile multipliers neutral.

Fresh parent-review verification:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10J_RUNTIME_CONTEXT_GREEN_EXIT_CODE=0
TEST_SUMMARY: PASS (0 failures)
TASK10J_PARENT_REVIEW_AFFECTED_EXIT_CODE=0
TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1852
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10J_PARENT_REVIEW_24_MEMBER_EXIT_CODE=0
LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)
TASK10J_PARENT_REVIEW_LEDGER_EXIT_CODE=0
TEST_SUMMARY: PASS (166 suites)
TASK10J_PARENT_REVIEW_FULL_EXIT_CODE=0
```

The hot-path regression creates 24 live `PartyActor` instances and asserts exactly 24 action-snapshot calls for one tick. A separate attack request asserts the call count remains exactly one after targeting, sequence start, locked-target revalidation, and impact execution.

## Scope and hygiene

- Production changes are limited to runtime action geometry resolution/consumers and estimate/comparison/ledger presentation.
- Test changes are limited to focused combat/geometry/transition/resume/preview/UI coverage and the existing equipment/ledger integrations.
- No item definition, affix data, attack resource, stat catalog, scene, generator, profile schema, or save data changed.
- `git diff --check` exits `0`.
- The worktree retains the same 127 protected pre-existing untracked `.gd.uid` sidecars. No UID/import/log/settings/scratch artifact is staged or in Task 10J scope.

## Concerns

- Full-suite output intentionally contains established negative-path diagnostics; authoritative evidence is exit `0` plus `PASS (166 suites)`.
- No physical-controller or manual GPU-backed visual pass was added. The retained deterministic responsive integration proves containment and visible/accessibility wording through the three supported ledger viewports.
