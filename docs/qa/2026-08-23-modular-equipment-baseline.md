# Modular Equipment Legacy Baseline Verification

Date: 2026-08-23

## Immutable baseline

- External target: `F:/Projects(root)/Game dev/Projects/party-forge-asset-staging/modular-equipment/pilot-0001/baseline/legacy-equipment-v1`
- Builder invocation count: exactly one
- Builder exit code: `0`
- Builder result: `PARTY_FORGE_MODULAR_BACKUP_OK files=534 bytes=2106921 manifest=F:/Projects(root)/Game dev/Projects/party-forge-asset-staging/modular-equipment/pilot-0001/baseline/legacy-equipment-v1/manifest.json`
- Independent verifier exit code: `0`
- Verifier result: `PARTY_FORGE_MODULAR_BACKUP_OK files=534 bytes=2106921 manifest_sha256=b57067552d8d8894adc7bfe7d23b3e1684e671eb90f8cfb52b06412447ec6ad6`

The builder ran from the isolated implementation worktree with explicit arguments:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tools/build_modular_equipment_backup.gd -- --source-root 'F:\Projects(root)\Game dev\Projects\party-forge' --output 'F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\baseline\legacy-equipment-v1' --source-commit ba0665d984fe555d9449303192378204921cda8f --source-branch main
```

It was not retried, reused, deleted, cleaned, or overwritten.

## Immediate preflight and source state

Immediately before the builder mutation:

- Implementation worktree: clean full porcelain status on `feat/modular-equipment-pilot` at `ba6b0e435c7025552d97133aa2140b99989d1cb1`.
- Authoritative source root: `F:/Projects(root)/Game dev/Projects/party-forge`.
- Authoritative HEAD: `ba0665d984fe555d9449303192378204921cda8f`.
- Authoritative branch: `main`.
- Complete `git status --porcelain=v1 --untracked-files=all`: empty.
- External target: absent.
- `scenes/equipment/test_equipment/`: absent; absence fingerprint recorded as `ABSENT`.

The builder manifest records the same source root, Git top-level, commit, branch, and empty full worktree status. A post-build read-only check found the authoritative HEAD and branch unchanged, full porcelain status still empty, and `scenes/equipment/test_equipment/` still absent.

## Inventory and content proof

The manifest has schema version `1`, state `complete`, `expected_file_count=534`, `file_count=534`, and `total_bytes=2106921`. Its 534 sorted file rows are the exact per-file byte-size and SHA-256 record for this baseline. The SHA-256 above covers the exact raw `manifest.json` bytes.

| Category | Files |
|---|---:|
| Base definitions | 99 |
| Canonical presentations | 99 |
| Contact sheets | 9 |
| Contract scripts | 5 |
| Equipment scenes | 99 |
| Legacy presentations | 11 |
| Master icons | 99 |
| Presentation profiles | 11 |
| Runtime icons | 99 |
| Shared character scenes | 3 |
| **Total** | **534** |

An independent PowerShell audit compared manifest membership with every payload file and recomputed SHA-256 and byte size for every authoritative source file and copied target file:

- Duplicate manifest paths: `0`.
- Actual payload files: `534`.
- Membership differences: `0`.
- Source byte/hash mismatches: `0`.
- Target byte/hash mismatches: `0`.
- `scenes/equipment/test_equipment/` in authoritative source: `false`.
- `scenes/equipment/test_equipment/` in baseline target: `false`.

The independent GDScript verifier separately validated exact expected membership, manifest structure and totals, file sizes, and file SHA-256 values without invoking the builder.

## Automated gates

Affected inventory/builder/verifier matrix:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_inventory.gd res://tests/unit/test_modular_equipment_backup_builder.gd res://tests/unit/test_modular_equipment_backup_validator.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.

Full suite:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/test_runner.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (206 suites)`. The suite emitted established assertion-owned negative-path errors and warnings without a test-failure summary.

The final supervised run began with zero Godot 4.7.1 contenders, but its monitor observed foreign Godot PIDs `12440`, `16680`, `33308`, and `36336` during execution. No collision or test failure occurred, and the parent execution coordinator accepted this passing run as Task 5 full-suite evidence. Earlier overlapping attempts were not used as completion evidence.

## Safety conclusion

- No production presentation asset was replaced.
- The authoritative checkout remained byte/status clean and unchanged.
- The excluded user experiment was neither copied nor modified.
- The external target was mutated only by the single successful builder invocation; all later baseline operations were read-only.
