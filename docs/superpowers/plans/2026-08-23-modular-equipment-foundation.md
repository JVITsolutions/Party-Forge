# Modular Equipment Backup and Provenance Foundation Implementation Plan

> **Execution note:** Implement with test-driven development in the isolated `feat/modular-equipment-pilot` worktree. Do not invoke legacy write-generators or touch `scenes/equipment/test_equipment/`.

**Goal:** Preserve a verifiable copy of the current 99-item presentation baseline and add fail-closed, data-driven provenance validation for replacement assets.

**Architecture:** A pure GDScript contract validates asset-manifest dictionaries. Two command-line SceneTree tools create and verify a bounded backup using an explicit inventory and SHA-256 hashes. Production asset rows are added only when their reviewed files exist; test fixtures prove the schema first.

**Tech stack:** Godot 4.7.1, typed GDScript, JSON, SHA-256, existing custom test runner.

**Threat model:** Trusted local Windows workstation. Protect against accidental overwrite, deletion, path traversal, destination reuse, partial promotion, incorrect Git metadata, and byte drift. Do not build a security boundary against a malicious concurrent local process racing junctions, aliases, files, or helper termination. Keep the implementation small and fail closed for ordinary validation, I/O, and process errors without recursive cleanup.

---

## Task 1: Add the manifest contract with failing tests

**Files:**

- Create: `scripts/presentation/equipment_asset_manifest_contract.gd`
- Create: `tests/unit/test_equipment_asset_manifest_contract.gd`

**Step 1: Write the failing tests**

Cover:

- schema version must equal `1`
- asset IDs are non-empty and unique
- kinds are `rig`, `body`, or `equipment`
- runtime Godot paths are normalized `res://` paths with no traversal
- provenance references use immutable attempt/revision IDs and hashes, never absolute machine paths
- SHA-256 fields contain exactly 64 lowercase hexadecimal characters
- equipment rows declare set, slots, `fit_policy` (`shared` or `variant`), `attachment_mode` (`rigid_socket` or `shared_skin`), and body coverage
- one canonical-rig row declares `pf_humanoid_v1`, topology hash, 1e-6-quantized canonical-rest hash, semantic role mapping, and named-bind policy
- `shared_skin` equipment covers both `masculine` and `feminine`, declares topology/rest signatures, and records each approved Skin's ordered named-bind hash
- shared rigid equipment may point both bodies to one export
- approved rows include reviewer, UTC timestamp, and notes
- invalid input returns all deterministic errors without mutating the source dictionary

Use small in-memory dictionaries; do not create production files to make the test pass.

**Step 2: Run the focused test and confirm RED**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_asset_manifest_contract.gd
```

Expected: the new suite fails because the contract script does not exist or required validation is absent.

**Step 3: Implement the minimum pure contract**

Create `EquipmentAssetManifestContract extends RefCounted` with `SCHEMA_VERSION := 1`, row kinds `rig`, `body`, and `equipment`, body presets `masculine` and `feminine`, fit policies `shared` and `variant`, attachment modes `rigid_socket` and `shared_skin`, and a pure `validate_document(document: Dictionary) -> PackedStringArray` entry point. Implement the method directly rather than leaving a stub.

Keep filesystem access out of this class so it remains deterministic and unit-testable.

**Step 4: Run the focused test and confirm GREEN**

Run the same focused command. Expected: the suite passes.

**Step 5: Commit**

```powershell
git add scripts/presentation/equipment_asset_manifest_contract.gd tests/unit/test_equipment_asset_manifest_contract.gd
git commit -m "test: define equipment asset manifest contract"
```

## Task 2: Define the exact legacy backup inventory

**Files:**

- Create: `tools/modular_equipment_backup_inventory.gd`
- Create: `tests/unit/test_modular_equipment_backup_inventory.gd`

**Step 1: Write the failing inventory test**

Require the inventory builder to return exactly:

- 99 equipment scene files across `dawn_bulwark`, `emberweave`, `forge_vanguard`, `grave_covenant`, `greenwood`, `nightstep`, `rime_scholar`, `siege_archer`, and `storm_chaplain`
- 99 base-definition files across those same nine directories
- 99 canonical presentation-resource files across those same nine directories
- eleven tracked top-level `data/presentation/equipment/forge_vanguard_*.tres` legacy resources, for 110 presentation resources total
- 99 master icons and 99 runtime icons
- nine equipment contact sheets
- the shared humanoid and two base-body scenes
- the presentation profiles and contract scripts needed to interpret the snapshot

Assert that every path exists, is unique, is relative, and excludes `scenes/equipment/test_equipment/`, `.godot/`, generated QA captures, and unrelated gameplay files.

**Step 2: Run the focused test and confirm RED**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_inventory.gd
```

**Step 3: Implement deterministic inventory discovery**

Use the nine canonical set IDs already represented by the equipment catalog. Sort all paths ordinally. Encode the expected category counts as constants and fail when counts drift.

**Step 4: Run the focused test and confirm GREEN**

**Step 5: Commit**

```powershell
git add tools/modular_equipment_backup_inventory.gd tests/unit/test_modular_equipment_backup_inventory.gd
git commit -m "test: lock legacy equipment backup inventory"
```

## Task 3: Build a no-overwrite backup command

**Files:**

- Create: `tools/build_modular_equipment_backup.gd`
- Create: `tests/unit/test_modular_equipment_backup_builder.gd`

**Step 1: Write failing tests around a disposable user directory**

Test that the builder:

- requires an explicit absolute output directory
- rejects an existing non-empty target
- rejects a target inside the Godot project
- creates parent directories safely
- copies byte-for-byte from an explicit authoritative Party Forge source root while preserving relative paths
- records source commit, branch, worktree status, path, size, and SHA-256
- writes the manifest last, after every copy succeeds
- preserves a failed attempt, writes a bounded failure marker and partial ownership manifest, and never recursively cleans the external staging root
- never follows a path outside the declared inventory

Do not test by copying the full production inventory.

**Step 2: Confirm RED, implement, then confirm GREEN**

The SceneTree entry point accepts named `--source-root`, `--output`, `--source-commit`, and `--source-branch` arguments. Validate the source as the exact root of a Party Forge checkout containing `project.godot`, validate the output as an absolute empty directory outside that source, and validate the commit as exactly 40 hexadecimal characters. The builder may read a dirty source and must record its full `git status`; it never writes to the source.

The pure copy/hash service should be separate from CLI parsing so tests do not spawn subprocesses.

Use ordinary local-path containment and exact inventory validation under the trusted-workstation threat model above. Reject UNC/device paths. Tests should cover deterministic accidental-failure behavior; adversarial junction-swap, alias-race, and hostile concurrent-process simulations are explicitly out of scope.

**Step 3: Commit**

```powershell
git add tools/build_modular_equipment_backup.gd tests/unit/test_modular_equipment_backup_builder.gd
git commit -m "feat: add bounded modular equipment backup builder"
```

## Task 4: Add independent backup verification

**Files:**

- Create: `tools/validate_modular_equipment_backup.gd`
- Create: `tests/unit/test_modular_equipment_backup_validator.gd`

**Step 1: Write failing tests**

Cover a valid fixture, missing file, extra file, size mismatch, hash mismatch, duplicate path, escaped path, wrong expected count, malformed JSON, and absent source metadata.

**Step 2: Implement a read-only verifier**

The verifier must not repair, rewrite, or normalize the backup. It returns nonzero and prints one stable `PARTY_FORGE_MODULAR_BACKUP_ERROR` line per problem. Success prints counts and the manifest SHA-256.

**Step 3: Confirm focused GREEN and commit**

```powershell
git add tools/validate_modular_equipment_backup.gd tests/unit/test_modular_equipment_backup_validator.gd
git commit -m "feat: independently verify modular equipment backups"
```

## Task 5: Create and verify the immutable pilot baseline from the authoritative working tree

**Files:**

- Create outside repo: `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\baseline\legacy-equipment-v1\`
- Create: `docs/qa/2026-08-23-modular-equipment-baseline.md`

**Step 1: Resolve and record exact source state**

Require the implementation worktree to be clean before running its tested tool, but set `--source-root` to the authoritative working tree at `F:\Projects(root)\Game dev\Projects\party-forge`. Record that source's current HEAD, branch, complete `git status --porcelain=v1`, and per-file bytes/hashes. If a relevant file is dirty, preserve those working-tree bytes rather than silently substituting clean-branch bytes.

**Step 2: Run the backup builder exactly once**

Do not reuse, delete, clean, or overwrite a failed target. Preserve its failure marker and partial ownership manifest; a retry receives a new sibling attempt directory.

**Step 3: Run the independent verifier**

Record its success line, category counts, total bytes, and manifest SHA-256 in the QA document.

**Step 4: Confirm the user's experiment was not copied or modified**

Verify `scenes/equipment/test_equipment/` remains absent from the backup and unchanged in the user's main checkout.

**Step 5: Run the full baseline suite**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/test_runner.gd
```

Expected: `TEST_SUMMARY: PASS` with a suite count greater than the original 202-suite baseline.

**Step 6: Commit documentation**

```powershell
git add docs/qa/2026-08-23-modular-equipment-baseline.md
git commit -m "docs: record modular equipment legacy baseline"
```

## Completion criteria

- Contract and backup tests pass.
- The full suite passes.
- The external baseline verifies independently.
- No production presentation asset has been replaced.
- No existing dirty/untracked user file has changed.
