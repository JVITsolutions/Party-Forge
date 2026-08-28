# Latticewright City Access final contract correction report

Date: 2026-08-28
Status: implementation evidence only; not a final-readiness claim

## Boundary

This correction wave was implemented only in the retained Party Forge and
Latticewright feature worktrees. It did not merge, push, activate the candidate,
wire gameplay, alter profiles, remove format-1, modify `main`, clean worktrees,
or release anything. Independent fix review and another whole-branch audit
remain required.

Starting feature heads:

- Party Forge: `41c6efd87495731ac819b6e6f967a39497fc1cc7`
- Latticewright: `575ada0d98de11b3e5c9f6f78119405dd0c98286`

Latticewright correction commit:

- `26098c0da6fa5c60597fc414cd2b4db79d0b1114` (`fix: correct Party Forge portfolio contract`)

The Party Forge correction commit is the commit containing this generated
report; recording its own hash inside its committed bytes would be
self-referential.

## Implemented corrections

1. `AtomicJsonStore` now returns a distinct four-field recovery contract with
   `resolution` equal to `none`, `rolled_back`, `candidate_verified`, or
   `indeterminate`. The three safe resolutions continue the current import
   through the writer; indeterminate recovery stops before source work. Recovery
   cleanup debt is aggregated into the final write result, and recovery and
   restoration remain writer-owned.
2. Latticewright declares
   `buildPartyForgeCityAccessProject(): ProgressionProjectV3`; the TypeScript
   test imports it directly without an `as unknown` bypass.
3. The generator and checked-in README now state that the directory contains
   the retained 16-project portfolio plus the separate City Access
   authoring/runtime pair. The producer test asserts the exact complete README
   text while retaining the accepted 32-file hash regression.
4. The production-only `_has_state()` test seam was removed. The provider test
   releases a real result, creates a survivor, and verifies that the actual
   registry contains exactly the survivor and no stale owner.
5. Writer and CLI recovery tests use `user://tests/...` target and staging roots
   through an injected writer seam. They exercise real filesystem interruption
   and recovery while asserting the fixed snapshot bytes and fixed staging tree
   remain unchanged.

## RED evidence

Latticewright:

```powershell
node --test scripts/party-forge/create-party-forge-portfolio.test.mjs; npm.cmd run typecheck
```

Meaningful RED result: Node reported `5/6` passing because the exact generated
README wording did not match. TypeScript reported `TS2305` because
`buildPartyForgeCityAccessProject` was absent from the declaration, with
dependent implicit-`any` diagnostics. Exit code: `1`.

Party Forge, after correcting two test-harness parse mistakes without changing
production code:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_provider.gd
```

Meaningful RED result: `TEST_SUMMARY: FAIL (43 failures)`, exit code `1`.
Failures demonstrated the old generated-write recovery shape, safe recovery
stopping before current comparison, no isolated writer path seam, CLI rejection
of the new safe resolutions, acceptance of invalid recovery shapes, and the
production `_has_state()` method still being present. The checked-in snapshot
hash was unchanged before and after the RED run and the fixed staging tree had
zero entries.

## GREEN evidence

### Latticewright

```powershell
node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
npm.cmd test -- tests/party-forge/portfolio.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/resolve-runtime.test.ts
npm.cmd run typecheck
npm.cmd run lint
npm.cmd test
```

Results:

- producer: `6/6` passed
- relevant Vitest: `3` files, `20/20` tests passed
- typecheck: exit `0`
- lint: exit `0`
- full suite: `219` files, `2793/2793` tests passed; exit `0`

### Party Forge focused and required gates

Focused correction gate:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_provider.gd
```

Result: `TEST_SUMMARY: PASS (0 failures)`, exit `0`.

Exact 12-suite gate:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

Result: `TEST_SUMMARY: PASS (0 failures)`, exit `0`.

Integration runner:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

Result: `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy`, exit `0`.

Checked-in importer replay:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tools/import_latticewright_access_snapshot.gd -- --source res://design/progression/latticewright/party-forge-city-access.pstree.json
```

Result:
`PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare`,
exit `0`.

Complete suite:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 2400 --script res://tests/test_runner.gd
```

Result: `TEST_SUMMARY: PASS (227 suites)`, exit `0`. Expected negative-path
diagnostics were emitted by the suite; the authoritative runner summary passed.

## Artifact and repository integrity

Protected City artifacts after all RED and GREEN runs:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `design/progression/latticewright/party-forge-city-access.pstree` | 11,055 | `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a` |
| `design/progression/latticewright/party-forge-city-access.pstree.json` | 9,972 | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` |
| `data/world/access/party-forge-city-access.snapshot.json` | 2,539 | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` |

Additional checks:

- protected artifact diff count: `0`
- fixed staging tree `.party-forge-tools/latticewright-city-access`: `0` entries
- checked-in generated README equals the exact generator text
- all `32` checked-in retained portfolio files equal the accepted generator
  bytes; the producer's fixed SHA-256 map regression also passed
- Party Forge `main`: `65f0d238345ea0a009e298a07f2191289fd88260`
  (unchanged from the starting observation)
- Latticewright `main`: `e2ea0b1d2534563138260048e0ae9fb0525ef94e`
  (unchanged from the starting observation)
- merge commits introduced from either starting feature head: `0`
- `git diff --check`: passed in both repositories
- Latticewright worktree was clean after its repository-scoped commit

The Party Forge worktree is expected to become clean after committing the
implementation and this report together. That post-commit state is verified
outside this self-contained report.
