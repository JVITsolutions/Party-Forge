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
