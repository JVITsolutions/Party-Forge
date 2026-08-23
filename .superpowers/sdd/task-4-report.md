# Task 4 report: immutable item-roll equipment projection

Status: implementation and local verification complete on `feat/equipment-attribute-application`. Task 5 was not started.

## Scope and contract

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Starting head: `3372410` (`fix: preserve caster tags during regeneration`).
- Task 4 commit: this report's commit (`feat: project equipped item rolls into stats`); resolve the immutable hash with `git log -1`.
- Added `EquipmentModifierProjection`, which exposes only `error`, `source`, and `ok()` plus constructors for atomic success/failure results.
- Added pure `EquipmentModifierProjector.project(member_id, container_id, state, active_item_ids, equipment, foundation, stats)`.
- The projector emits exactly one `equipment_member_<member_id>` source, including an empty source for an empty active set.
- Active item rolls become ordinary `StatModifier` records, preserving all five supported operations and required tags. No parallel stat calculation was added.
- Detailed IDs encode member, canonical slot, immutable item instance, affix index/definition, and roll index.
- Labels use the approved actual em dash: `<base display name> — <affix display name>`.
- Inputs are read through defensive ownership/registry copies. Items, affixes, rolls, equipment bases, foundation definitions, stat definitions, and class Resources are never mutated.

## Validation and atomicity

Projection rejects invalid input before exposing a source. Stable diagnostics use:

```text
PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=<id> slot=<slot> item=<item> affix=<affix> roll=<roll> stat=<stat> reason=<reason>
```

The boundary validates member/container/catalog presence, equipment-container kind, active identity uniqueness and exact-one placement, registry references, base and affix identities, affix kind/tier/roll shape, known stats, supported operations, finite and in-range values, required tags against the foundation vocabulary, materialized-roll/definition parity, detailed modifier identity uniqueness, complete item codec validity, and the final source through `StatResolver.validate_sources()`.

Disabled/inactive items are deliberately skipped before item/roll projection, so none of their implicit, attribute, typed-damage, or tagged rolls can contribute.

## TDD evidence

### Controlled missing-service RED

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_modifier_projector.gd
```

Exact result before production files existed:

```text
TEST_SUMMARY: FAIL (2 failures)
TASK4_RED_EXIT_CODE=1
```

Both failures were the requested missing projector/result scripts. The test suite itself loaded and returned a normal assertion summary; this was not Godot's misleading parser-abort/exit-zero behavior.

### Registration/import

After implementation and syntax correction, a bounded editor import registered both new global classes:

```text
[ DONE ] first_scan_filesystem
[ DONE ] update_scripts_classes
[ DONE ] loading_editor_layout
TASK4_IMPORT_EXIT_CODE=0
```

### Review regression RED

Self-review identified that one item referenced from two equipment slots would otherwise project twice. A test-first duplicate-reference case exited `1` with exactly three assertions: the result incorrectly succeeded, exposed a source, and lacked the required stable error. Counting equipped references before projection made the same case fail closed atomically.

### Focused GREEN

Fresh focused result after all code/test changes:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_FOCUSED_GREEN_EXIT_CODE=0
```

The final focused output contains no parser, load, assertion, or Task 4 warning diagnostic.

## Coverage

- One active item contains an implicit, attribute prefix, typed-damage suffix, and tagged melee roll; all four appear exactly once and in deterministic slot/affix/roll order.
- A separately equipped inactive item contributes nothing.
- Exact source metadata, detailed modifier IDs, actual-em-dash labels, values, operations, and required tags are asserted.
- Repeated identical input produces byte-equivalent source documents.
- Ownership `to_dictionary()` bytes, caller item dictionaries, and the active-ID array remain unchanged.
- Empty active sets retain a uniform replaceable source with zero modifiers.
- Flat, increased, reduced, more, and less operations project without translation.
- Non-finite values, unsupported operations, unknown stats, empty or unknown tags, duplicate active IDs, unknown active IDs, duplicate equipped references, null ownership, and a null stat catalog all fail with exact stable errors, no partial source, and byte-equivalent ownership.

## Complete-suite result

Godot: `4.7.1.stable.official.a13da4feb`.

Fresh complete suite after the final production/test changes:

```text
TEST_SUMMARY: PASS (160 suites)
TASK4_FULL_SUITE_EXIT_CODE=0
```

This is one suite above Task 3's recorded 159-suite baseline. The runner retains its established intentional negative-path `ERROR`/`WARNING` diagnostics, but no `TEST_FAILURE`, script/parse/load failure, or non-zero exit remained.

## Files and hygiene

- `.superpowers/sdd/task-4-report.md`
- `scripts/equipment/equipment_modifier_projection.gd`
- `scripts/equipment/equipment_modifier_projector.gd`
- `tests/unit/test_equipment_modifier_projector.gd`

The bounded import generated `.gd.uid` sidecars for both new scripts and the new test alongside the worktree's pre-existing untracked generated sidecars. No `.gd.uid`, `.import`, `.godot`, ignored scratch artifact, or unrelated file is staged or included in the Task 4 commit.

## Concerns

- No open Task 4 production concern is known.
- The complete runner output is not diagnostically pristine because established tests intentionally exercise and log rejection paths. The authoritative summary is `PASS (160 suites)` with exit `0`; focused Task 4 output is clean.

## Review follow-up: unknown required-tag vocabulary

Review found that required tags were checked for empty/duplicate values and exact roll/definition equality, but not for membership in `ItemFoundationCatalog.known_item_tags`. A corrupt definition and immutable roll carrying the same unknown tag could therefore project a valid-looking modifier that never applies.

The regression duplicates the fixture definition and roll with `review_unknown_tag` while leaving that ID outside the foundation vocabulary. Before the fix, the focused suite exited `1` with exactly three failures: the projection incorrectly succeeded, exposed a non-null partial source, and returned no stable diagnostic.

The narrow fix passes `foundation.known_item_tags` into the existing tag validator and returns the exact contextual error:

```text
PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=1 slot=main_hand item=item-active affix=melee_focus roll=0 stat=attack_speed reason=unknown required tag review_unknown_tag
```

Fresh review verification:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_UNKNOWN_TAG_GREEN_EXIT_CODE=0

TEST_SUMMARY: PASS (160 suites)
TASK4_TAG_FIX_FULL_SUITE_EXIT_CODE=0
```

The failure result asserts `source == null`, the ownership document remains byte-equivalent, and no unrelated production, test, generated, or import file is part of the review fix.

# Multi-Crit Task 4 addendum: independent defended damage instances

Status: Task 4 implementation and required automated verification complete on `feat/playtest-recovery-loot-ui`. Task 5 and Task 6 were not started.

## Scope and contract

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playtest-recovery-loot-ui`.
- Starting head: `b0f426d35c9fb5721cbfbd137d6c2b3753164c1c` (`fix: harden multi-crit roll bounds`).
- `DamageDefenseSnapshot` captures target identity/team, dodge chance, per-type defense stat/value/mitigation rule, packet-specific incoming multiplier, block chance, and block effectiveness. Scalars reject writes; nested defense data is copied on construction and on access.
- `DamageResolver.capture_defense()` reads those live inputs once. Invalid target, packet, catalog, type/rule, non-finite component base, or non-finite frozen defense data returns structured invalid metadata with a stable `PARTY_FORGE_DAMAGE_ERROR` diagnostic.
- `DamageResolver.resolve_instance()` validates the authoritative instance index/critical flag, independently rolls dodge and then block, derives each normal/critical amount from the once-prepared `typed_scaled` base, applies only frozen mitigation inputs, and separates calculation from optional health/life-steal mutation.
- `DamageResult` now records `instance_index`, `target_was_alive`, `overkill_only`, `health_before`, `killing_blow`, `excess_damage`, and `proc_eligible`.
- `DamageResolver.resolve()` remains a compatibility path: it captures once and resolves only authoritative instance index `0`. It does not iterate the multi-crit bundle.
- No bundle service/iteration, proc dispatcher, presentation event/queue, overkill buffer, projectile/runtime routing, or other Task 5/6 behavior was added.

## Strict TDD evidence

The pre-change focused baseline at exact start head exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_BASELINE_EXIT_CODE=0
```

Tests were saved before any production edit. Two initial fixture attempts referenced the unregistered `MultiCritRoll` global class and aborted during parse without a `TEST_SUMMARY`; both were rejected as RED evidence. After changing only the test fixture to use the existing preloaded script resource, the exact required focused command produced the accepted RED:

```text
TEST_FAILURE: defended instance resolution defines an immutable defense snapshot
TEST_FAILURE: damage resolver captures target defenses once
TEST_FAILURE: damage resolver resolves one independently defended instance
TEST_SUMMARY: FAIL (3 failures)
TASK4_RED_EXIT_CODE=-1073741819
```

The three failures were exactly the missing Task 4 file and APIs. The Windows native status reflects the process crash after the explicit failure summary; it was not treated as evidence by status alone.

The first minimal implementation run exited `0` with `TEST_SUMMARY: PASS (0 failures)`. Self-review then added a regression for a directly instantiated blank snapshot. Before the correction, the focused runner exited `1` with `TEST_SUMMARY: FAIL (2 failures)`: the empty rejection reason let calculation continue into missing frozen type data, and the test then observed the null result. The narrow fallback now rejects blank snapshots before RNG or health access with `reason=invalid defense snapshot`.

Fresh final Task 4 focused result:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_FOCUSED_GREEN_EXIT_CODE=0
```

## Required behavior coverage

- A three-critical-instance packet uses prescribed draws in exact order: instance 0 dodges and consumes no block draw; instance 1 misses dodge and blocks; instance 2 misses dodge and block. Total defender RNG consumption is exactly five draws.
- The blocked and unblocked instances each derive their own `60` critical amount from a `30` `typed_scaled` base at a `2.0` multiplier. A 50% block produces `30`; the unblocked instance produces `60`.
- A 100%-effective block records zero final/actual damage, preserves health, and sets `proc_eligible == false` after consuming its independent dodge and block opportunities.
- After capture, the test mutates live dodge, armor, incoming provider, block chance, and block effectiveness and also mutates a caller-exposed defense dictionary. Resolution still uses frozen `0.25` dodge, `100` armor, `0.50` incoming multiplier, `0.50` block chance, and `0.50` effectiveness for exact final damage `25`.
- Non-finite captured armor and a blank snapshot fail before RNG/health mutation with stable diagnostics.
- Two living `60`-damage instances against `100` health record health-before values `100` and `40`; the second is the killing blow with `20` excess. Living damage alone is proc-eligible and life steal uses actual health removed.
- The third instance resolves after death with `apply_health == false` and `allow_life_steal == false`: `target_was_alive == false`, `overkill_only == true`, `final_damage == 60`, `actual_health_removed == 0`, `excess_damage == 60`, `killing_blow == false`, and `proc_eligible == false`. Target/source health remain unchanged.
- The compatibility wrapper resolves one first authoritative critical flag, applies exactly `40` damage once, records `instance_index == 0`, and leaves the second prepared flag unprocessed.

## Verification

Expanded resolver/multi-crit/RNG/typed-combat compatibility batch:

```text
tests/unit/test_damage_resolver.gd
tests/unit/test_multi_crit_roll.gd
tests/unit/test_combat_rng.gd
tests/unit/test_typed_combat_final_fixes.gd
tests/unit/test_action_damage_component_projection.gd

TEST_SUMMARY: PASS (0 failures)
TASK4_RELATED_COMPAT_EXIT_CODE=0
```

The declared known-stale batch remained exactly unchanged:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK4_KNOWN_FIVE_EXIT_CODE=1
```

- `test_attack_execution.gd`: three planned Task 6 health/RNG expectations.
- `test_action_combat_estimate_service.gd`: two planned Task 7 average-damage/DPS expectations.

The fresh complete repository suite also exited `1` with exactly those same five failures:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK4_FULL_SUITE_EXIT_CODE=1
```

No sixth `TEST_FAILURE`, parser failure, load failure, or Task 4 regression appeared. `git diff --check` passed before report/staging review.

## Files and self-review

Task 4 scope is limited to:

- `.superpowers/sdd/task-4-report.md`
- `scripts/combat/damage_defense_snapshot.gd`
- `scripts/combat/damage_result.gd`
- `scripts/combat/damage_resolver.gd`
- `tests/unit/test_damage_resolver.gd`

Self-review confirmed:

- the snapshot copies nested dictionaries both into and out of its authority;
- all seven result-evidence defaults fail closed;
- dodge returns before block, while every non-dodged instance receives its own block opportunity;
- frozen per-type rule/value data, not the live target/catalog definition, drives mitigation;
- post-death successful damage is recorded as excess without health, proc, kill, or life-steal mutation;
- the compatibility wrapper performs no extra critical/base/defender RNG and resolves no additional flags;
- no generated `.gd.uid`/`.import` sidecar was created;
- the user-owned untracked playtest-recovery screenshot/report paths remain untouched and unstaged;
- `.superpowers/sdd/progress.md` was neither modified nor staged.

## Concerns

- The five full-suite failures are the explicitly planned stale Task 6/7 expectations and remain unresolved by design.
- Focused runs print intentional negative-path `PARTY_FORGE_DAMAGE_ERROR` messages plus the repository's established ObjectDB/resource-exit markers. Accepted evidence requires the explicit summary and absence of unplanned `TEST_FAILURE`/parse/load failures.
- No open Task 4 production concern is known after the blank-snapshot diagnostic correction.

# Multi-Crit Task 4 review correction: packet binding and arithmetic safety

Status: both Task 4 review blockers are corrected and locally verified on top of `a8302d225758031b30a9e1220604c25220b09b34`. Task 5 and later behavior remain unimplemented.

## Root cause and correction scope

The original snapshot froze target/type defense values but did not identify the exact `DamagePacket` used when the packet-specific incoming multiplier was captured. A different packet with compatible target/type rows could therefore consume the first packet's snapshot and defender RNG.

The original instance resolver also performed dodge before deterministic damage arithmetic and validated only the critical product. Finite operands could overflow later mitigation, multi-component accumulation, incoming multiplication, blocked-outcome calculation, or life-steal derivation. Those paths could publish valid `INF` evidence; the life-steal case could mutate target health before the non-finite heal request was silently rejected.

The focused correction changes only:

- `.superpowers/sdd/task-4-report.md`
- `scripts/combat/damage_defense_snapshot.gd`
- `scripts/combat/damage_resolver.gd`
- `tests/unit/test_damage_resolver.gd`

`DamageDefenseSnapshot` now retains a strong reference to the exact transient packet. `matches_packet()` uses object identity, the read-only transient instance ID supplies diagnostics, and `copy()` preserves the same binding. `resolve_instance()` rejects any packet/snapshot mismatch before target mutation, defender RNG, or calculation.

Deterministic calculation is now precomputed before dodge while preserving the externally observed RNG order: dodge still rolls first and a non-dodged instance then rolls block. The precompute validates component evidence, critical draw/multiplier/product, per-type mitigation, accumulated mitigation, incoming multiplication, both possible block outcomes, prospective excess, and both possible life-steal bounds. Invalid results retain finite fail-closed defaults and carry attack/source/target/instance/stage/type context.

## Strict TDD evidence

### Review-blocker RED

Tests were saved before production changes. The exact Task 4 focused command produced:

```text
TEST_SUMMARY: FAIL (45 failures)
TASK4_REVIEW_RED_EXIT_CODE=-1073741819
```

Accepted failures proved:

- packet B resolved successfully with packet A's copied snapshot and consumed two defender draws;
- critical overflow lacked stage context;
- resistance multiplication, two-component accumulation, incoming multiplication, and blocked-outcome arithmetic remained valid with non-finite evidence and consumed defender RNG;
- life-steal overflow consumed both defender draws and reduced target health from `1.0e308` to zero before rejection;
- invalid results exposed non-finite damage evidence.

The Windows native status occurred after the explicit failure summary and was not treated as evidence by exit status alone.

The armor probe initially expected rejection because the old expression overflowed its `post_crit * 100` intermediate. During root-cause analysis, the intended invariant was narrowed correctly: nonnegative armor cannot mathematically increase a finite amount. The implementation now multiplies by the bounded armor factor `100 / (100 + armor)`, and the test requires a valid, finite `1.0e308` result instead of rejecting a mathematically representable outcome.

### Evidence-publication self-review RED

After the first correction GREEN, self-review added direct-construction probes for an unused non-finite critical multiplier and non-finite authored component evidence. Before tightening validation:

```text
TEST_SUMMARY: FAIL (7 failures)
TASK4_EVIDENCE_RED_EXIT_CODE=1
```

Both packets resolved as valid, consumed defender RNG, and the multiplier path published `INF`. The correction rejects these at `stage=critical` or `stage=component`, leaves numeric result defaults finite, and consumes no defender RNG.

### Compatibility-draw self-review RED

A final numeric-field audit found that `MultiCritRoll.from_compatibility()` could carry a non-finite draw into `DamageResult.crit_draw`. The focused regression produced:

```text
TEST_SUMMARY: FAIL (3 failures)
TASK4_DRAW_RED_EXIT_CODE=1
```

The three failures were valid resolution, two consumed defender draws, and published `NAN` draw evidence. The resolver now accepts only `-1` or a finite draw in `[0,1)`, reports `stage=critical`, and keeps the invalid result's draw evidence at its finite `-1` default.

### Final GREEN

Fresh exact focused result after all corrections:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_REVIEW_FINAL_FOCUSED_EXIT_CODE=0
```

## Binding and arithmetic coverage

- Packet-specific target callback returns `0.50` for packet A and `0.25` for packet B. A copy of A's snapshot rejects B with `reason=snapshot packet mismatch`, zero RNG, and unchanged health; the same copy resolves A with captured multiplier `0.50` and final damage `10`.
- A finite `1.0e308` typed amount multiplied by critical multiplier `2` rejects before RNG at `stage=critical`.
- The armor factor ordering preserves a finite `1.0e308` result without intermediate overflow.
- A finite `1.0e308` fire amount with finite `-1.0e308` resistance rejects at `stage=mitigation` before RNG.
- Two individually finite `9.0e307` resistance components reject their overflowing sum at `stage=accumulation`.
- Finite `1.0e308 * 2` incoming scaling rejects at `stage=incoming`.
- Both block outcomes are calculated before RNG; finite `1.0e308` damage and finite `1.0e308` block effectiveness reject the overflowing blocked outcome at `stage=block`, regardless of the prescribed block result.
- A finite `1.0e308` actual-removal bound and life-steal rate `2` reject at `stage=life_steal` before defender RNG or target/source mutation.
- Excess subtraction uses nonnegative finite operands after earlier guards. A maximum-scale successful calculate-only hit records finite, nonnegative excess and preserves health.
- Invalid results do not publish non-finite critical, health, mitigation, incoming, block, damage, excess, or life-steal evidence.

## Verification

Expanded resolver/multi-crit/RNG/typed-combat compatibility batch:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_REVIEW_RELATED_EXIT_CODE=0
```

The declared stale batch remains exactly the planned three Task 6 and two Task 7 failures:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK4_REVIEW_KNOWN_FIVE_EXIT_CODE=1
```

The fresh repository-wide suite contains exactly the same five failures and no additional parser/load/test failure:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK4_REVIEW_FULL_SUITE_EXIT_CODE=1
```

`git diff --check` passes. No generated sidecar, Task 5+ contract, bundle iteration, proc dispatch, presentation, overkill buffer, runtime integration, QA evidence, or progress-file change is present.

## Concerns

- The five declared Task 6/7 stale expectations remain intentionally unresolved.
- Focused negative-path coverage deliberately prints structured `PARTY_FORGE_DAMAGE_ERROR` messages; the authoritative result is the explicit summary.
- No open Task 4 review concern is known after the packet-binding and arithmetic-evidence audit.
