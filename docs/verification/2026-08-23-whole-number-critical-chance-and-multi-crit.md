# Whole-Number Critical Chance and Multi-Crit Verification

Date: 2026-08-23
Branch: `feat/playtest-recovery-loot-ui`
Tasks 8-9 scope: live-scene ordering, 10,000-instance ceiling safety, legacy-save compatibility, automated acceptance

## Acceptance status

Task 8's automated acceptance layer is GREEN in the working tree. The runtime runner uses production `Main`, `PartyActor`, `AttackExecutor`, `PartyProjectile`, `SpawnDirector`, `EnemyActor`, and `CombatResolutionService` nodes attached to the real `SceneTree`. It invokes public combat entry points and awaits natural frames; it does not directly invoke lifecycle callbacks, private damage-resolution methods, or enemy defeat.

The test does not instantiate floating damage labels. Final floating-number, hit-flash, sound, and overkill-art acceptance remains a later visual/game-feel gate.

Task 9 automated acceptance was executed against exact final commit `560dc5f6da7719dde55ac19059047391cf7457e3`. Tasks 1-5, 7, and 8 focused batches passed with exit 0, their required PASS markers, and zero forbidden parser, loader, script, RID, ObjectDB, or resource-leak markers in disposable physical copies with only the Godot AI test-harness autoload/plugin entries disabled. Production `project.godot` was not changed.

Task 6 is not accepted under the zero-forbidden-marker focused gate. Its combined batch passes assertions, but consistently retains exactly two ObjectDB instances and one `res://scripts/stats/stat_modifier.gd` resource. The same retention reproduces at pre-increment parent `a996f28`, proving it predates this multi-crit increment; that provenance is recorded, but the gate is not waived.

## TDD evidence

Initial runner RED:

- `multi_crit_combat_runner.gd`: exit 1, exact file-not-found loader failure.
- `multi_crit_performance_runner.gd`: exit 1, exact file-not-found loader failure.

Legacy-save characterization RED:

- The first assertion incorrectly required a schema-1 document to remain byte-identical after decode. The codec correctly migrated it to canonical schema 2 while preserving the raw `0.0111` critical roll. The assertion was corrected to distinguish supported schema migration from destructive stat snapping.

GREEN evidence:

- Exact nine-suite focused gate: exit 0, `TEST_SUMMARY: PASS (0 failures)`.
- Live combat integration: exit 0, one `MULTI_CRIT_COMBAT_INTEGRATION: PASS` marker.
- Ceiling/performance integration: exit 0, one `MULTI_CRIT_PERFORMANCE_INTEGRATION: PASS` marker.
- Full suite: exit 0, `TEST_SUMMARY: PASS (205 suites)`.
- A physical cold copy created from `git archive HEAD` plus only the four Task 8 files imported with fresh isolated `APPDATA`, `LOCALAPPDATA`, and `.godot` state: exit 0. Its exact focused gate and both integration runners also exited 0 with the same PASS markers.

Expected negative-path unit tests print their intentional `PARTY_FORGE_*_ERROR` diagnostics in the focused/full logs. No parser, resource-loader, script, RID, ObjectDB, or resource-leak marker was emitted by the Task 8 integration runs.

## Live-scene combat boundaries

`tests/integration/multi_crit_combat_runner.gd` proves:

- A 105% Ranger projectile creates exactly one `PartyProjectile`; prescribed remainder failure resolves one damage instance, while prescribed success resolves two.
- An 1150% Fighter melee execution resolves twelve instances and changes health synchronously inside the public `execute` call. The next natural frame applies no additional delayed gameplay damage.
- Two 200% critical instances preserve independent defense evidence: instance 0 consumes a successful dodge draw and does not roll block; instance 1 consumes a failed dodge draw followed by a successful block draw.
- A lethal 1150% bundle delivered to a production Boltcaster emits enemy reward and defeat once, creates one XP orb, and performs one personal-loot drop. Later successful instances are retained as overkill-only results.
- The enemy is naturally queued and freed. The copied presentation bundle remains usable afterward with stable indices `0..11`, count `12`, target identity, and captured world position.
- The overkill record remains readable after node deletion, remains present through deterministic advancement to 1.999 seconds, and expires at 2.000 seconds.

## Ceiling safety observation

`tests/integration/multi_crit_performance_runner.gd` resolves two identical durable-target fixtures:

| Case | Requested | Processed | Result events | Elapsed |
| --- | ---: | ---: | ---: | ---: |
| Exact ceiling | 10,000 | 10,000 | 10,000 | 856.771 ms |
| Larger request | 10,001 | 10,000 | 10,000 | 889.952 ms |

Observed static memory:

- Before: 109,314,814 bytes
- After: 111,283,446 bytes
- Peak: 317,511,514 bytes

Both bundles had finite damage/health/overkill totals, zero overkill against the durable targets, bounded 10,000-element result/event arrays, exact requested/processed diagnostics, and byte-equivalent authored attack/source/target build documents before and after resolution. The larger request was explicitly marked truncated, and 10,000 was the largest processed count.

These numbers are a headless safety observation on this machine, not a rendered gameplay performance benchmark or frame-time promise.

The isolated cold-copy repetition observed 851.490 ms at the exact ceiling and 847.640 ms for the truncated request, with 109,309,400 bytes before, 111,278,032 bytes after, and a 317,506,100-byte peak. The independently imported copy again processed exactly 10,000 results/events in both cases and exited 0.

The final Task 9 performance acceptance repetition observed 911.413 ms for the exact 10,000-instance request and 901.118 ms for the truncated 10,001-instance request. Both processed exactly 10,000 bounded instances and emitted the required performance PASS marker. Observed memory was 108,549,189 bytes before, 110,518,105 bytes after, and 316,746,221 bytes at peak.

## Task 9 cold acceptance

An untouched physical archive of exact commit `560dc5f6da7719dde55ac19059047391cf7457e3` was exercised with the normal project configuration and fresh isolated `APPDATA`, `LOCALAPPDATA`, and `.godot` state:

- Cold import: exit 0; zero forbidden markers.
- Full suite: exit 0; exactly one `TEST_SUMMARY: PASS (205 suites)` marker; zero forbidden markers.
- Thirty-frame boot smoke: exit 0; exactly one `PARTY_FORGE_BOOT_OK` and one `PARTY_FORGE_CLASS_SELECTION_READY`; zero forbidden markers.

This exact cold acceptance is clean. It does not erase or waive the separate pre-existing Task 6 focused-suite retention described above.

## Legacy save compatibility

The codec coverage decodes a literal schema-1 Ring of Mercy with an off-grid `crit_chance` roll of `0.0111`:

- The input document remains unchanged.
- Normal schema migration produces schema 2 while retaining the exact raw `0.0111` issued roll.
- Equipment projection plus `StatResolver` combines the default 5% with the legacy roll and non-destructively finalizes combat critical chance to 6%.
- The decoded item remains byte-equivalent after projection/resolution.
- Stat formatting shows `6%`; item projection shows `+1% Critical Strike Chance`; the advanced tooltip shows `Range: 1%-2%`. Raw `0.0111` and `1.11%` are not exposed to the player.
- Actual `ProfileCodec.encode` and `ResumableRunItemCodec.encode` documents contain no overkill buffer, combat diagnostics, damage-bundle, processed-instance, or presentation-event state.

`tests/unit/test_profile_state.gd` did not require a fixture-name or schema change and was therefore intentionally left untouched.

## Commands

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_instance_codec.gd tests/unit/test_multi_crit_roll.gd tests/unit/test_damage_resolver.gd tests/unit/test_combat_resolution_service.gd tests/unit/test_overkill_buffer_service.gd tests/unit/test_attack_execution.gd tests/unit/test_enemy_typed_combat.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_developer_mode_badge.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/multi_crit_combat_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/multi_crit_performance_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 2400 --script res://tests/test_runner.gd
```

## Independent severity review

The controller reviewed the exact implementation range through `560dc5f6da7719dde55ac19059047391cf7457e3` against the approved specification and plan.

- Critical findings: none.
- Important findings: none.
- Minor findings: none in the implementation range.

The review explicitly confirmed independent per-instance dodge/block rolls; no post-death hit, crit, or life-steal procs; successful resolved damage only in overkill totals; one reward, defeat, loot decision, and projectile delivery; the 10,000-instance processing ceiling without authored-build mutation; generated/source/persisted catalog parity; legacy save compatibility; and no mutation of the pre-existing untracked playtest-recovery evidence.

## Remaining gate

Task 9 automated execution and independent review are complete at exact final commit `560dc5f6da7719dde55ac19059047391cf7457e3`, subject to the explicitly unwaived pre-existing Task 6 focused-suite retention. Manual 1080p visual acceptance remains pending; no Task 9 screenshots were created. No final floating-label or overkill presentation claim is made here.
