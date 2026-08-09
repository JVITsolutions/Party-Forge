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
