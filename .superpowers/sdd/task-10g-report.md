# Task 10G report: shared action cadence with cooldown recovery

Status: implementation, TDD, hardened verification, and scoped commit complete.

## Scope and formula

- Starting head: `7d2a0087bb03b85ea1c308265a548f9f1b91e0ca` on `feat/equipment-attribute-application` in the isolated equipment-attribute worktree.
- Added one pure `ActionCadence.resolve(authored_cooldown, attack_speed, cooldown_rate)` calculation.
- Units are explicit: authored/effective cooldown are seconds, attack speed and cooldown rate are neutral-at-`1.0` rate multipliers, runtime progress is their product, and actions per second is that product divided by authored cooldown.
- The helper rejects non-finite/nonpositive authored cooldown, negative or non-finite rate inputs, overflowed progress multipliers/action rates, and non-finite or nonpositive effective cooldowns.
- `cooldown_rate == 1.0` preserves the prior attack-speed-only cadence.

## Consumers and semantics

- `PartyActor` now advances primary and support cooldowns through action-tag-aware `CombatModifiers.action_cadence()`. Attack presentation receives the same progress multiplier.
- `ActionCombatEstimateService` uses the shared cadence for damaging APS/DPS and healing uses-per-second/HPS.
- `CandidateActionValidationService` no longer owns a duplicate healing cadence/HPS formula; both damage and healing validate through the shared estimate path.
- `LedgerDataProvider` includes healing actions in owned-action order. `StatsLedgerPage` renders Healing / Use, Uses / Second, and Estimated HPS with a healing-specific estimate boundary.
- Healing remains exempt from primary damage-archetype validation. Wisdom changes healing power through the existing approved projection and changes both damage/healing cadence through cooldown recovery without altering unrelated damage per hit.

## TDD evidence

### Baseline

The six pre-edit affected suites exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10G_BASELINE_EXIT_CODE=0
```

### Controlled RED

Tests were authored before production changes for the pure formula, neutral compatibility, Wisdom runtime/estimate parity, healing HPS, ledger healing rows, and equipment/refresh/resume rollback. One first attempt exposed a test-only untyped empty-array argument and was rejected. After correcting only that test fixture, the accepted RED exited `1` with:

```text
TEST_SUMMARY: FAIL (31 failures)
TASK10G_CONTROLLED_RED_EXIT_CODE=1
```

There was no captured `SCRIPT ERROR`. Failures were confined to the missing helper, inert cooldown recovery, unavailable healing estimates, accepted cadence overflow, committed invalid refresh/resume state, and absent ledger healing rows.

### GREEN

The initial seven-suite cadence/runtime/transition/ledger batch exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10G_GREEN2_EXIT_CODE=0
```

The expanded 14-suite affected gate exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10G_AFFECTED_EXIT_CODE=0
```

It covered attribute projection, two-pass resolution, archetypes, cadence, estimates, runtime combat, equipment transition, run-context reconstruction, registry/coordinator lifecycle, non-equipment refresh, ledger data/UI, and profile storage projection.

## Integration and full verification

Fresh 24-member integrations:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10G_EQUIPMENT_INTEGRATION_EXIT_CODE=0

LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)
TASK10G_LEDGER_24_EXIT_CODE=0
```

Fresh hardened complete suite:

```text
TEST_SUMMARY: PASS (166 suites)
TASK10G_FULL_EXIT_CODE=0
```

The new cadence suite raises the suite count from 165 to 166. The runner exited `0`; its emitted domain errors and storage warnings were the established asserted negative paths, not captured script failures.

Fresh editor import/parser gate exited `0`, completed filesystem scan and global-class registration including `ActionCadence`, and emitted no parser, script, or failed-resource-load diagnostic. It recreated exactly six known `.gd.uid` sidecars: the two new scripts, the modified candidate-action validator, and three hardened-runner support scripts. All six exact generated files were removed; the pre-existing 127 untracked sidecars were preserved.

## Coverage highlights

- Neutral values and combined multiplier/effective-cooldown/action-rate arithmetic.
- Zero, negative, non-finite, underflowed, and overflowed cadence boundaries.
- Wisdom-only damaging and healing runtime/estimate cadence parity.
- Healing amount, action rate, and HPS without a damage archetype.
- Attack-speed, cooldown-recovery, effective-cooldown, rate, DPS, and HPS rejection.
- Equipment preview rejection plus non-equipment refresh and resumable reconstruction atomicity, including exact source/cache/revision/signal/health preservation.
- 24-member affected-member isolation and ledger rendering through three viewports.

## Files in scope

- `.superpowers/sdd/task-10g-report.md`
- `scripts/combat/action_cadence.gd`
- `scripts/combat/combat_modifiers.gd`
- `scripts/characters/party_actor.gd`
- `scripts/combat/candidate_action_validation_service.gd`
- `scripts/ui/ledger/action_combat_estimate.gd`
- `scripts/ui/ledger/action_combat_estimate_service.gd`
- `scripts/ui/ledger/ledger_data_provider.gd`
- `scripts/ui/ledger/stats_ledger_page.gd`
- `tests/unit/test_action_cadence.gd`
- `tests/unit/test_action_combat_estimate_service.gd`
- `tests/unit/test_attack_execution.gd`
- `tests/unit/test_equipment_transition_service.gd`
- `tests/unit/test_non_equipment_activation_refresh.gd`
- `tests/unit/test_ledger_data_provider.gd`
- `tests/unit/test_stats_ledger_page.gd`

## Concerns

- No open Task 10G functional concern is known.
- Healing-card layout is covered through unit rendering and the three-viewpoint 24-member ledger integration; no new manual visible-window pixel review was performed.
- The worktree retains its pre-existing untracked `.gd.uid` sidecars. None are staged or included in Task 10G.
