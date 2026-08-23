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

---

# Multi-Crit Task 5: synchronous bundles and run-scoped overkill

Status: Task 5 implementation and required automated verification are complete on `feat/playtest-recovery-loot-ui`. Task 6 runtime routing and final presentation art were not started.

## Authority and preserved state

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playtest-recovery-loot-ui`.
- Starting head: `227b97b9bb16d9de8abee7f8d8053659afebe920`.
- The user-owned untracked `docs/validation/screenshots/playtest-recovery/` and `docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md` paths remain untouched and unstaged.
- The user-owned main Godot editor/process was not inspected, stopped, or modified.
- `.superpowers/sdd/progress.md` was not modified or staged.

## Implemented contract

- `CombatResolutionService` is a run-scoped `Node` with explicit `CombatRng` and `DamageTypeCatalog` dependencies and one owned `OverkillBufferService`.
- `resolve_bundle(packet, target)` validates the packet/target/dependencies, captures stable target identity, one world position, one health reference, and one packet-bound defense snapshot, then iterates only a copied ordered `critical_flags` array.
- Every instance calls Task 4 `DamageResolver.resolve_instance()` and receives independent dodge/block resolution. Health and life steal apply only while the target is alive.
- Positive living results emit one hit-proc request, critical living results emit one crit-proc request, positive life-steal living results emit one life-steal request, and the first live-to-dead transition emits one kill event.
- Already-rolled post-death instances continue calculate-only and emit no hit, crit, life-steal, flash, or additional kill request. Killing excess and successful post-death would-be damage are added exactly once.
- One completed immutable/defensively copied bundle is published only after all synchronous gameplay resolution. Its presentation events contain captured position, stable order/index/count, damage, critical state, living/overkill-only state, dodge/block state, and flash eligibility; no visual nodes or final art were created.
- A mid-bundle unavailable or freed-health boundary returns ordered evidence including the invalid index, publishes one explicitly failed finite diagnostic/bundle contract, stops immediately, and publishes no completed/proc/kill contract after the invalid boundary.
- Completed and failed diagnostics defensively copy requested/processed/guaranteed counts, fractional chance/draw/success/consumption, ceiling truncation, requested-count overflow, total overkill, validity, and failure boundary/reason where applicable.
- `DamageResult.copy()` provides the narrowly required defensive-copy support for immutable bundle access.

## Strict TDD evidence

The pre-change resolver/multi-crit/health baseline passed:

```text
TEST_SUMMARY: PASS (0 failures)
BASELINE_EXIT_CODE=0
```

Both Task 5 tests were saved before any production edit. The exact required focused command then failed only because the two services did not exist:

```text
TEST_FAILURE: run-scoped combat resolution service exists
TEST_FAILURE: run-scoped overkill buffer service exists
TEST_SUMMARY: FAIL (2 failures)
TASK5_RED_EXIT_CODE=-1073741819
```

The Windows native status occurred after the explicit failure summary and was not treated as evidence by itself. The first production load exposed unresolved new-class registration references; these parse errors were corrected with explicit script preloads before any GREEN claim.

The first valid minimal implementation run produced:

```text
TEST_SUMMARY: PASS (0 failures)
TASK5_GREEN_ATTEMPT_2_EXIT_CODE=0
```

Self-review then added a freed captured-health boundary regression. Before the safeguard it produced an invalid freed-object constructor call and:

```text
TEST_SUMMARY: FAIL (3 failures)
TASK5_FREED_HEALTH_RED_EXIT_CODE=1
```

The minimal correction substitutes an unavailable captured-health adapter at the exact invalid boundary so Task 4 returns stable ordered evidence. Its focused rerun passed.

A second self-review added huge-finite clock and failed-diagnostics probes. Before correction:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK5_REVIEW_PROBES_RED_EXIT_CODE=1
```

The failures proved repeated huge finite deltas could make elapsed state non-finite and poison a later record, while a failed bundle neither published nor retained diagnostics. The buffer now rebases its internal deterministic clock whenever no live record depends on it; failed bundles publish and retain one copied explicitly invalid finite diagnostic snapshot.

Fresh final exact Task 5 focused evidence:

```text
TEST_SUMMARY: PASS (0 failures)
TASK5_REVIEW_FINAL_FOCUSED_EXIT_CODE=0
```

## Ordered counts and timing proof

The primary `3 x 60` critical fixture against `100` health proves synchronously after one call:

- result indices `[0, 1, 2]`, final damage `[60, 60, 60]`, and target health `0`;
- two hit-proc, two crit-proc, and two life-steal requests;
- one kill event on index `1`, one completed bundle, and one completed diagnostics snapshot;
- three ordered damage-number events, two flash-eligible living events, and one overkill-only event;
- captured position remains `Vector3(1, 2, 3)` in every event after the actor moves during the first proc callback;
- killing excess `20` plus successful post-death damage `60` equals total/buffered overkill `80`;
- post-death result restores no life and the source receives life steal only from the two living health removals.

The mixed four-instance fixture prescribes seven ordered defender draws: the killing hit contributes `10` excess; one post-death dodge contributes `0`; one fully blocked post-death result contributes `0`; one successful post-death result contributes `60`; total overkill is exactly `70`.

The buffer tests prove:

- a record is readable after `advance(1.999)` and absent immediately after the next `advance(0.001)`;
- re-recording one stable target identity atomically replaces amount/metadata and resets a full independent `2.000` seconds;
- negative, `NAN`, `INF`, and `-INF` deltas are rejected without aging records;
- repeated `1.0e308` finite advances cannot leave non-finite state or poison a later exact `1.999/2.000` lifetime;
- record setters cannot mutate stored state, caller metadata is deep-copied, and each read returns a defensive copy.

The persistence regression checks current `ProfileState`, `ProfileCodec`, and `ResumableRunItemCodec` schema/source authority. No overkill buffer, combat diagnostics, or damage bundle field/reference is persisted.

## Verification matrix

Exact Task 5 focused command:

```text
tests/unit/test_combat_resolution_service.gd
tests/unit/test_overkill_buffer_service.gd
tests/unit/test_health_component.gd

TEST_SUMMARY: PASS (0 failures)
```

Task 3/4 resolver compatibility batch:

```text
tests/unit/test_damage_resolver.gd
tests/unit/test_multi_crit_roll.gd
tests/unit/test_combat_rng.gd
tests/unit/test_typed_combat_final_fixes.gd
tests/unit/test_action_damage_component_projection.gd

TEST_SUMMARY: PASS (0 failures)
TASK5_RESOLVER_COMPAT_EXIT_CODE=0
```

Declared known-stale batch:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK5_KNOWN_FIVE_EXIT_CODE=1
```

- `test_attack_execution.gd`: three planned Task 6 health/RNG expectations.
- `test_action_combat_estimate_service.gd`: two planned Task 7 average-damage/DPS expectations.

Fresh repository-wide suite after the final review corrections:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK5_FINAL_FULL_SUITE_EXIT_CODE=1
```

The full suite contains exactly the same five planned Task 6/7 failures and no additional `TEST_FAILURE`, parse error, script error, or load failure. The established suite intentionally prints negative-path errors and repeated boot/readiness markers. Focused commands also retain the pre-existing exit diagnostics (`18 ObjectDB instances` and `5 resources still in use`); the same markers were present in the exact pre-change baseline and no new Task 5-specific leak marker appeared.

## File scope and self-review

Task 5 scope is limited to:

- `.superpowers/sdd/task-5-report.md`
- `scripts/combat/combat_damage_instance_event.gd`
- `scripts/combat/combat_resolution_service.gd`
- `scripts/combat/damage_bundle_result.gd`
- `scripts/combat/damage_result.gd`
- `scripts/combat/overkill_buffer_service.gd`
- `scripts/combat/overkill_record.gd`
- `tests/unit/test_combat_resolution_service.gd`
- `tests/unit/test_overkill_buffer_service.gd`

`tests/unit/test_health_component.gd` required no change because Task 4 already exposed actual removal/excess boundaries. Self-review confirmed all public arrays/dictionaries/records/events are immutable or defensively copied, captured target position has no later actor dependency, the service owns no wall-clock/await path, failed resolution stops without retry/skip, and the two persistence sources remain unchanged. Source scanning confirms no Main, PartyManager, projectile, area, enemy, scene, save codec, or final visual path references the new service.

No generated `.gd.uid`, `.import`, `.godot`, QA evidence, or unrelated file is included in Task 5 staging.

## Concerns

- The five planned Task 6/7 stale assertions remain intentionally unresolved.
- Production attack paths do not use `CombatResolutionService` until Task 6; this Task 5 commit proves the isolated service contract only.
- Final floating-number and overkill styling remain deliberately out of scope.
- The repository's established headless ObjectDB/resource-exit diagnostics remain present; explicit summaries and the absence of any additional failure/load/parser marker are the authoritative evidence.

---

# Multi-Crit Task 5 Review Hardening

## Review RED-GREEN evidence

The review corrections were test-first. The saved blocker/minor matrix initially produced the accepted deterministic RED:

```text
TEST_SUMMARY: FAIL (39 failures)
TASK5_REVIEW_HARDENING_ACCEPTED_RED_EXIT_CODE=1
```

Those assertions covered callback-driven post-kill health deletion, later-instance and aggregate finite overflow, reentry from hit/diagnostics callbacks, non-finite captured position, large-clock replacement, public calculation preflight, and structural 10,000-instance zero-damage behavior. After minimal production changes, the combined focused matrix passed.

The final review checkpoint added a separate incoming-provider callback that frees and clears target health during defense capture. Before the new dynamic-boundary guard it failed only the three intended assertions:

```text
TEST_SUMMARY: FAIL (3 failures)
TASK5_CAPTURE_CALLBACK_ACCEPTED_RED_EXIT_CODE=1
```

After revalidating target availability and living health immediately after defense capture and before preflight construction:

```text
TEST_SUMMARY: PASS (0 failures)
TASK5_CAPTURE_CALLBACK_GREEN_EXIT_CODE=0
```

That failure is now attributed to `stage=defense_capture`, uses `failed_instance_index=-1` and `capture_failed=true`, publishes one finite failed contract/diagnostics snapshot, and consumes no target health, defender RNG, proc/kill/completed signal, or overkill-buffer state.

## Hardened contract

- Every copied authoritative critical flag is calculation-preflighted before health, life steal, defender RNG, or gameplay signals. The preflight exposes a Task 4-safe finite maximum-damage result without mutation, and a checked finite aggregate upper bound rejects known later overflow before the first instance.
- The killing transition swaps subsequent calculation to an owned frozen dead-health proxy before killing-result callbacks. Freeing the real health object from the killing hit, crit, or kill callback cannot abort already-prepared post-death flags; all three callback variants retain three ordered results, signal counts `2 hit / 2 crit / 1 kill / 1 completed`, and exact total/buffered overkill `80`. The proxy is freed on completed and failed exits.
- Total overkill is accumulated only through checked finite additions. A buffer record must succeed before completed diagnostics/bundle publication; rejected recording returns one finite failed contract and never publishes completion or `INF`.
- Same-service synchronous reentry returns a stable copied failed value without recursive signals, diagnostics publication, latest-diagnostics replacement, buffer mutation, or extra target mutation. Hit and diagnostics callback reentry leave the outer bundle authoritative and completing once.
- Captured `Vector3` components are validated finite before any event or metadata publication. Structured failure substitutes no non-finite position into public state.
- The buffer tracks each record by a fresh `remaining_seconds=2.000` duration and keeps only a bounded/rebased diagnostic clock. A forced `1.0e16` clock followed by replacement remains present through `1.999` and expires at exactly `2.000`; repeated huge finite deltas cannot overflow elapsed state.
- A direct valid prepared 10,000-flag, zero-damage bundle remains structurally capped at 10,000 results/events, mutates no health, consumes no RNG, publishes no proc/kill/buffer state, and completes once.

## Final verification matrix

Exact Task 5 focus:

```text
tests/unit/test_combat_resolution_service.gd
tests/unit/test_overkill_buffer_service.gd
tests/unit/test_health_component.gd

TEST_SUMMARY: PASS (0 failures)
TASK5_REVIEW_FINAL_EXACT_FOCUSED_EXIT_CODE=0
```

Task 3/4 compatibility:

```text
tests/unit/test_damage_resolver.gd
tests/unit/test_multi_crit_roll.gd
tests/unit/test_combat_rng.gd
tests/unit/test_typed_combat_final_fixes.gd
tests/unit/test_action_damage_component_projection.gd

TEST_SUMMARY: PASS (0 failures)
TASK5_REVIEW_FINAL_COMPAT_EXIT_CODE=0
```

Declared stale Task 6/7 batch:

```text
TEST_SUMMARY: FAIL (5 failures)
TASK5_REVIEW_FINAL_KNOWN_FIVE_EXIT_CODE=1
```

The exact failures remain the three attack-execution defender-draw/health assertions and the two action-estimate average-hit/DPS assertions.

The first shared-application-data full-suite attempt was discarded: it reported 35 failures, including 30 additional developer-sandbox ownership/state failures and two script-level invalid dictionary-property accesses caused by persisted `user://` sandbox artifacts. An independently imported detached duplicate with fresh isolated `APPDATA` and `LOCALAPPDATA` eliminated every one of those 30 additions:

```text
TASK5_REVIEW_COLD_IMPORT_EXIT_CODE=0
PARTY_FORGE_BOOT_OK
PARTY_FORGE_CLASS_SELECTION_READY
TEST_SUMMARY: FAIL (5 failures)
TASK5_REVIEW_FINAL_COLD_FULL_EXIT_CODE=1
```

The cold suite contained exactly the declared five Task 6/7 failures and no additional test, parser, loader, or script failure. Disposable cold project and app-data directories were removed after verification. Focused Task 5 exit diagnostics were `6 ObjectDB instances` and `3 resources still in use`; compatibility retained the established `18 ObjectDB instances` and `5 resources still in use`. No new Task 5-specific failure/load/parser marker appeared.

## Scope, diff check, and concerns

Review-hardening scope is limited to this report, three combat production files, and their three unit suites. Source scanning still finds `CombatResolutionService` only in its own class file: no Main, PartyManager, projectile, area, enemy, scene, persistence, or final presentation path is wired. `.superpowers/sdd/progress.md`, both user-owned untracked QA paths, and the main editor/process remain untouched. `git diff --check` is clean.

The known five Task 6/7 assertions remain intentionally unresolved. Production routing remains Task 6, and final floating-number/overkill visuals remain outside Task 5. The repository's established headless ObjectDB/resource-exit diagnostics remain a concern but did not increase in the verified focused compatibility batch.
