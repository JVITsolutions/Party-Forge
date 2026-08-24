# Task 4 Report: Independent Backup Verification

## Scope

Task 4 was implemented in the isolated `feat/modular-equipment-pilot` worktree. The implementation adds only the independent read-only verifier and its small disposable-fixture unit suite. It does not invoke the backup builder, repair or normalize backup contents, write or delete backup files, or touch the external staging root.

## Files

- `tools/validate_modular_equipment_backup.gd`
- `tests/unit/test_modular_equipment_backup_validator.gd`

## TDD evidence

The test suite was written before the verifier. After correcting a test-only constant-expression parse mistake, the accepted RED command was:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_validator.gd
```

Accepted RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)`. The sole assertion failure was `backup validator implementation exists`, proving the missing verifier caused the failure.

The implemented service verifies raw `manifest.json` bytes, schema/state, complete source metadata, exact expected and manifest counts, deterministic unique normalized relative paths, exact backup membership, file sizes, file SHA-256 values, and declared totals. It returns sorted unique `PARTY_FORGE_MODULAR_BACKUP_ERROR` strings. The CLI requires `--backup-root`, prints every error line and exits nonzero on failure, or prints verified file/byte counts plus the SHA-256 of the exact manifest bytes on success.

The tests cover valid backup, missing file, extra file, actual-size drift, same-length byte/hash drift, duplicate manifest path, escaped path, wrong expected count, malformed JSON, absent source metadata, deterministic combined-error ordering, repeated-result stability, exact success counts/hash, byte-for-byte nonmutation, and absence of a builder dependency.

## Verification

Focused Task 4 GREEN:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_validator.gd
```

Exit `0`; `TEST_SUMMARY: PASS (0 failures)`; no parse, loader, test-failure, or shutdown-leak diagnostic.

Inventory/builder/validator affected matrix:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_inventory.gd res://tests/unit/test_modular_equipment_backup_builder.gd res://tests/unit/test_modular_equipment_backup_validator.gd
```

Exit `0`; `TEST_SUMMARY: PASS (0 failures)`.

Full suite:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/test_runner.gd
```

Exit `0`; `TEST_SUMMARY: PASS (206 suites)`. The run retained established assertion-owned negative-path diagnostics and warnings, with no test-failure summary.

## Scope concerns

- The trusted local-workstation threat model intentionally does not defend against a malicious concurrent process racing filesystem changes during verification.
- Empty unexpected directories are not payload files and are not reported; every unexpected file is rejected.
- Task 5 still owns the one-time external authoritative baseline creation and live CLI verification.

## Commit

`faddf10f3be9df8586a621f57dfaa4659940bbde` - `feat: independently verify modular equipment backups`

The commit contains exactly the two Task 4 files listed above. This report remains intentionally unstaged.

## Review-fix TDD cycle

Independent review identified invalid UTF-8 handling, source-path identity validation, one-physical-line error safety, and missing direct coverage around totals, CLI behavior, and failure immutability.

The accepted assertion RED used the focused Task 4 command above and exited `1` with `TEST_SUMMARY: FAIL (11 failures)`. The failures were the absent production CLI seam, invalid UTF-8 not rejecting, six invalid `source.root`/`source.toplevel` path cases not rejecting, a valid-but-different source identity not rejecting, and two control-character line-safety assertions. The already-present verifier correctly rejected directly corrupted `file_count` and `total_bytes` values, so those new coverage assertions did not add RED failures.

Minimum GREEN added a strict byte-level UTF-8 check before decoding while retaining SHA-256 over the exact raw manifest bytes; normalized local absolute `source.root`/`source.toplevel` validation with UNC/device rejection and case-insensitive identity comparison; percent encoding for C0/C1 control characters before sorting/deduplicating or printing errors; and a `run_cli` path used directly by `_initialize()`.

The expanded disposable fixtures directly cover corrupted `file_count`/`total_bytes`, all negative-path byte snapshots, and production CLI decisions for successful output/exit `0`, missing arguments, malformed backup, and control-bearing arguments with exit `1`. No subprocess or builder is invoked; `_initialize()` delegates entirely to the tested CLI control flow.

Review-fix verification:

- Focused validator: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Inventory/builder/validator affected matrix: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Full suite: exit `0`; `TEST_SUMMARY: PASS (206 suites)`.
- `git diff --check`: clean.

Review-fix commit: `0832091d098c885dcc4351b1235cbf6b1803e2cf` (`fix: harden modular backup verification`). It contains exactly the validator and validator-test files. This report remains intentionally unstaged.

## Final review-fix TDD cycle

The final review identified two remaining boundary defects: Godot virtual/URI paths could pass the backup-root or source-path checks, and Unicode line/paragraph separators could split dynamic diagnostics across physical lines.

The accepted assertion RED used the focused Task 4 command above and exited `1` with `TEST_SUMMARY: FAIL (14 failures)`. The failures comprised six service/CLI backup-root assertions for `res://`, `user://`, and another URI scheme; four service/CLI source assertions for the other URI scheme in `source.root` and `source.toplevel`; and four service/CLI Unicode separator encoding and physical-line assertions. Existing source checks already rejected `res://` and `user://` in source metadata.

Minimum GREEN now explicitly accepts only normalized local drive-letter absolute paths for backup roots and source metadata. It no longer relies on `String.is_absolute_path()` to distinguish local paths from Godot virtual or other URI paths. `ErrorText.single_line()` now percent-encodes U+2028 and U+2029 in addition to the previously handled C0/C1 control characters before errors are sorted, deduplicated, returned, or printed.

The expanded tests exercise `res://`, `user://`, and `custom://` through both the service and `run_cli`, exercise U+2028/U+2029 through service and CLI dynamic values, require one physical diagnostic line, and retain byte-for-byte failure snapshots without invoking the builder.

Final review-fix verification:

- Focused validator: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Inventory/builder/validator affected matrix: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- The first full-suite attempt was invalidated by a confirmed concurrent full suite in the `playtest-recovery-loot-ui` worktree using the same `user://developer_item_sandbox`; it reported unrelated atomic-store collisions and byte drift. After condition-waiting for that Godot process to exit, the uncontended rerun exited `0` with `TEST_SUMMARY: PASS (206 suites)`.
- `git diff --check`: clean.

Final review-fix commit: `07da9ca6a50b413e1910f0e99253d9c55a04ef47` (`fix: reject virtual modular backup paths`). It contains exactly the validator and validator-test files. This report remains intentionally unstaged.

## Final backup-root normalization TDD cycle

The final boundary review found that drive-letter backup roots with dot or parent segments, repeated or trailing separators, later backslashes, or control characters could pass request validation and reach filesystem access.

The accepted assertion RED used the focused Task 4 command above and exited `1` with `TEST_SUMMARY: FAIL (12 failures)`: one service and one `run_cli` assertion for each of the six malformed local-root forms. The observed results reached directory or manifest access instead of returning the stable request-validation error.

Minimum GREEN changes backup-root validation to reuse the same `_is_normalized_local_absolute()` predicate as source metadata. No other production behavior changed. The expanded service and CLI tests prove all six forms reject before access with the exact stable diagnostic.

Final backup-root normalization verification:

- Focused validator: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Inventory/builder/validator affected matrix: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- A Task 5 cold-review full suite was already running, so the Task 4 gate condition-waited for both Godot processes to exit and rechecked for zero contenders before launch.
- Uncontended full suite: exit `0`; `TEST_SUMMARY: PASS (206 suites)`.
- `git diff --check`: clean.

Final backup-root normalization commit: `8cafbc4e0d6dede4158b59aa17ae6cb5012c3ed9` (`fix: require normalized modular backup roots`). It contains exactly the validator and validator-test files. This report remains intentionally unstaged.

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
