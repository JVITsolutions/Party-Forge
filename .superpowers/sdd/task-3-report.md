# Task 3 report: primary archetypes and shared damage preparation

Status: implementation, verification, and scoped commit complete.

## Scope

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`
- Branch: `feat/equipment-attribute-application`
- Starting head: `e27bfc9` (`fix: reject projected source ID collisions`)
- Task 3 commit: this report's commit (`feat: apply primary archetype damage scaling`); use `git log -1` for the final immutable hash.
- Added `ActionArchetype` for exact-one playable damage archetype validation and canonical archetype-stat lookup.
- Added `ActionDamageProjection.normal_component()` as the shared finite, nonnegative normal-component calculation.
- Routed runtime preparation and ledger estimates through the shared projection using the action snapshot for archetype, type, critical, and action-rate stats.
- Normalized Mage, Frost Mage, Cleric, and Warlock attacks to sorted caster-primary tags without changing their damage types or other tags.
- No item, affix, class, or base-equipment Resource is mutated. This task does not alter attribute projection or cache invalidation behavior established by Tasks 1-2.

## TDD RED evidence

The first direct missing-class run produced parse errors for `ActionArchetype` and `ActionDamageProjection`, but the focused runner incorrectly returned process exit `0` without a `TEST_SUMMARY`. That result was rejected as RED evidence.

The test was adjusted to dynamically load the not-yet-existing services so all assertions could execute. The required focused batch then exited `1` with:

```text
TEST_SUMMARY: FAIL (13 failures)
```

The failures were limited to the intended missing behavior:

- both new services were absent;
- runtime melee preparation returned `180` instead of archetype-scaled `234`;
- mixed caster runtime components returned `16.8` and `6.6` instead of `21.84` and `8.58`;
- Mage, Cleric, Frost Mage, and Warlock resources lacked their approved caster-primary tags.

## Implementation and coverage

- `ActionArchetype.primary_tag()` returns a primary only when exactly one of melee, ranged, or caster is present.
- `ActionArchetype.stat_id()` maps a valid primary to `<tag>_damage` and otherwise returns an empty ID.
- Playable class validation returns the stable diagnostic `PARTY_FORGE_DAMAGE_ERROR attack=<id> reason=expected exactly one primary archetype`; healing actions remain exempt.
- `ActionDamageProjection.normal_component()` multiplies base, global, archetype, and type scaling once and returns `NAN` for negative, non-finite, or overflowed input.
- Runtime retains `global_scaled` as global-only evidence and records the shared final normal component in `typed_scaled` before critical scaling.
- Tests cover missing/conflicting primary tags, healing exemption, all nine live class mappings, invalid projection inputs, melee runtime scaling, and mixed fire/cold caster parity between runtime and ledger.

## Compatibility-test scope exception

The first complete-suite run exited `1` with `TEST_SUMMARY: FAIL (6 failures)`. All six were stale existing test expectations outside the original Task 3 file list:

- `test_attack_damage_data.gd`: old Mage and Cleric tag arrays;
- `test_expanded_class_content.gd`: old Frost Mage and Warlock tag arrays;
- `test_typed_combat_final_fixes.gd`: the custom playable `radiant_bolt` fixture had no primary archetype.

The parent explicitly approved a minimal test-only scope expansion. Only those four exact tag arrays were updated, and exactly one `caster` tag was appended to the shared `radiant_bolt` fixture. No unrelated assertion or production behavior changed.

## GREEN verification

Godot: `4.7.1.stable.mono.official.a13da4feb`

Expanded focused batch (the four Task 3 suites plus the three approved compatibility suites):

```text
exit 0
TEST_SUMMARY: PASS (0 failures)
```

Fresh complete suite after compatibility updates:

```text
exit 0
TEST_SUMMARY: PASS (159 suites)
```

The focused and complete logs contain existing intentionally asserted negative-path diagnostics. Neither run contains a `TEST_FAILURE` after the final changes.

`git diff --check` passed. Godot generated no Task 3 `.gd.uid` or `.import` sidecars. The worktree still contains the same pre-existing untracked generated `.gd.uid` set; none were modified, removed, staged, or included in the Task 3 commit.

## Generator-authoring review follow-up

Review found that the checked-in attack Resources were normalized, but retained authoring tables could restore stale tags during regeneration. `tools/create_default_data.gd` still omitted `caster` for Mage and Cleric, while `tools/class_expansion_rows.gd` omitted `caster` for Frost Mage and used conflicting `ranged` for Warlock.

The regression test combines both authoritative attack-row tables, requires exactly one row for each of the four caster attacks, compares the complete sorted tag array, and verifies `ActionArchetype.primary_tag()` resolves `caster`. Its controlled RED run exited `1` with:

```text
TEST_SUMMARY: FAIL (8 failures)
```

After changing only those four authoring rows, the direct generator-row suite exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

Disposable project snapshots were used so generator execution could not overwrite the authoritative worktree. The default generator exited `0` with `DATA_GENERATION_OK`, and exact post-generation file assertions reported:

```text
TASK3_REGEN_TAGS_OK scratch=task-3-generator-default actions=4
TASK3_REGEN_TAGS_OK scratch=task-3-generator-migration actions=4
```

The expansion migration rewrote and reloaded its attack Resources before its unchanged class-validation phase exited `1` on pre-existing starter-loadout capability/tag diagnostics. The four emitted attack Resources nevertheless matched the exact normalized arrays. `tools/migrate_class_expansion_data.gd` already copies `row["tags"]` directly, so it required no change; broadening this review fix into unrelated class/loadout migration repair was intentionally deferred.

Final authoritative verification with Godot `4.7.1.stable.official.a13da4feb`:

```text
Task 3 focused batch: exit 0, TEST_SUMMARY: PASS (0 failures)
Complete suite: exit 0, TEST_SUMMARY: PASS (159 suites)
```

The review follow-up is committed separately from the original Task 3 implementation. Only the two retained generator tables, their regression test, and this report belong to that follow-up commit.

## Concerns

- No open Task 3 functional concern is known.
- The retained expansion migration still fails its later class validation on existing starter-loadout capability/tag mismatches. This did not prevent its attack rows from being emitted and verified, and is outside the reviewed tag-preservation defect.
- The focused runner can return exit `0` after a suite-load parse failure, so accepted evidence requires both the expected PASS marker and absence of `TEST_FAILURE`/parse/load failures.
- The report is a pre-existing tracked coordination artifact and is included in the scoped Task 3 commit.

# Multi-Crit Task 3 addendum: bounded authoritative roll preparation

Date: 2026-08-23

Status: implementation and requested verification complete; scoped commit is this report's commit (`feat: prepare bounded multi-crit rolls`).

## Scope and implementation

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playtest-recovery-loot-ui`
- Branch: `feat/playtest-recovery-loot-ui`
- Starting head: `27be0ef848242eb8d547e0e57327d0e07a0a1875`
- Added `MultiCritRoll` as immutable preparation metadata with copied ordered flags, whole-percentage normalization, uncapped requested/guaranteed counts, a 10,000 processed-instance ceiling, fractional-roll evidence, and explicit truncation evidence.
- Below 100%, the roll records exactly one normal-or-critical flag. At or above 100%, it records bounded guaranteed critical flags plus a successful remainder only when a processing slot remains.
- `DamagePacket.multi_crit_roll` is authoritative and defensively copied. Compatibility accessors `critical` and `crit_draw` read the authoritative roll's first outcome and fractional draw.
- `DamageResolver.prepare()` creates the roll once before component sampling, then prepares one component set exactly once. The existing compatibility `post_crit` amount uses the first/resulting flag; later tasks own iteration and independent defended instance resolution.
- `PreparedDamageComponent` required no Task 3 change because its existing `typed_scaled` field already preserves the once-prepared normal base needed by later per-instance critical multiplication.
- No additional projectile, repeated weapon sample, defender dodge/block loop, proc dispatch, presentation staggering, death/overkill processing, or other Task 4+ behavior was added.

## Strict TDD evidence

The pre-change relevant baseline batch (`test_damage_resolver.gd`, `test_action_damage_component_projection.gd`, `test_combat_rng.gd`, and `test_typed_combat_final_fixes.gd`) exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

Tests were then added before production changes. The exact required focused RED command exited `1` with:

```text
TEST_SUMMARY: FAIL (8 failures)
```

Accepted RED failures were exactly:

- missing `multi_crit_roll.gd`;
- missing authoritative packet metadata in the resolver and weapon-projection fixtures;
- old at-or-above-100% behavior did not consume the processable fractional draw;
- shifted weapon range values were `10.4` and `5.0` instead of `12.5` and `7.0`;
- shifted compatibility post-critical values were `20.8` and `10.0` instead of `25.0` and `14.0`;
- total draw count was `2` instead of `3`.

Two intermediate GREEN attempts were rejected as evidence: one process exited `0` without a `TEST_SUMMARY` after a new-class self-reference compile failure, and one proper test run still exposed floating boundary behavior at the exact `0.05` draw. The implementation was minimally corrected to normalize through integer percentage points so equality at the prescribed boundary fails deterministically.

The exact required focused command then exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The final focused run after self-review type tightening also exited `0` with the same PASS marker and no parse/load/test failure.

## Boundary and safety coverage

- `0%`: no draw, one normal flag.
- `5%`: `0.04` critical, `0.05` normal, exactly one draw.
- `99%`: `0.98` critical, `0.99` normal, exactly one draw.
- `100%`: no draw, one guaranteed critical flag.
- `105%`: `0.04` produces two critical flags; `0.05` produces one guaranteed critical flag; exactly one fractional draw.
- `1150%`: `0.49` produces twelve critical flags; `0.50` produces eleven; exactly one fractional draw.
- `10000.05` reports `10001` requested potential instances and `10000` processed/guaranteed flags, marks truncation, allocates exactly 10,000 flags, preserves the fractional chance, and consumes no fractional draw because no processable slot remains.
- Direct metadata mutation attempts and mutation/clearing of an exposed flag array leave the authoritative values and ordered flags unchanged.
- The runtime `105%` weapon fixture proves end-to-end uncapped resolver behavior, one remainder draw followed by one draw per sorted non-fixed component, and one base component set rather than one set per critical flag.

## Compatibility and repository verification

The post-change legacy compatibility batch (`test_combat_rng.gd` and `test_typed_combat_final_fixes.gd`) exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The known-stale compatibility batch exited `1` with exactly the five failures declared in the Task 3 brief and no additions:

- `test_attack_execution.gd`: three stale health/RNG expectations;
- `test_action_combat_estimate_service.gd`: two stale average-hit/DPS expectations.

The repository-wide suite also exited `1` with exactly:

```text
TEST_SUMMARY: FAIL (5 failures)
```

Those are the same five pre-existing baseline-migration expectations. No additional suite failed.

`git diff --check` passed before staging. A staged-scope diff check and final focused/compatibility reruns are recorded immediately before commit.

## Self-review and concerns

- Review confirmed the processing ceiling bounds allocation before `resize()` and that an unprocessable remainder consumes no RNG.
- Review confirmed `requested_instances` represents the uncapped guaranteed count plus a potential fractional slot, while `processed_instances` is the bounded ordered flag count after the fractional result.
- Review confirmed all public metadata setters ignore writes, flag getters return copies, and packet construction/getters copy the roll so caller-held objects cannot mutate packet authority.
- Godot cannot resolve a brand-new script's own `class_name` identifier during this worktree's first cold import. Its static factory/copy return annotations therefore use `RefCounted`; packet/resolver fields, accessors, parameters, and locals use the concrete preloaded `MultiCritRoll` script type. This preserves cold-import reliability without weakening external Task 3 contracts.
- The focused suite continues to print existing intentional negative-path diagnostics and the existing ObjectDB/resource exit markers; accepted PASS evidence requires the explicit summary and absence of parse/load/test failures.
- The five declared stale full-suite expectations remain for Tasks 6 and 7 as planned. They were not rewritten outside Task 3's contract.
- The user-owned untracked QA evidence paths remain untouched and unstaged. `.superpowers/sdd/progress.md` was not modified or staged, and the main Godot editor/process was not touched.
