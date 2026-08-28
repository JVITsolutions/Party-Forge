# Latticewright City Access final-review fix implementation report

Date: 2026-08-28

Party Forge base: `07970a5aea0a9fd494d1da248b137716a15fad9d`

Latticewright base: `12408a727b3a49aab62bd8c6a70266abdc445d2e`

## Evidence boundary

This report records implementation and verification of the approved five-finding final-review fix wave. It does not claim final readiness and does not authorize merge, push, activation, release, public release, or removal of format-1.

The only canonical City artifact change was the separately approved authoring-only normalization: the two `fieldIds` were reordered to public-codec order. The file remains 11,055 bytes and now has the approved SHA-256 `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a`. The runtime and Party Forge snapshot bytes did not change.

## Implemented findings

1. `GeneratedJsonDocumentWriter` now owns a fixed-target recovery preflight backed by the existing `AtomicJsonStore` transaction evidence. The CLI invokes it before request parsing or source work.
2. Unprovable recovery returns the exact generated-write contract with `state=indeterminate`; the CLI emits one sanitized `INDETERMINATE` result and does not invoke reader, translator, validator, encoder, or writer. Verified rollback and already-verified candidate states continue through the existing transaction path. Recovery cleanup debt survives a later debt-free write.
3. The CLI stage allowlist now preserves the legitimate `confinement`, `mkdir`, `mkdir-target`, `stage-previous`, and `verify-previous` stages. Target restoration remains absent from the CLI.
4. Latticewright serialization preserves the exact accepted authoring and runtime bytes for all 16 retained projects. New requirement projection and strict runtime canonicalization are limited to the separate City Access project; the guarded writer succeeds when prepopulated with the accepted 32 retained files and adds only City Access authoring/runtime plus the expected README.
5. City Access authoring serialization now matches `stringifyProjectV3`, including nested content-type and placement-type `fieldIds`; both City files are covered by the deterministic 64 MiB ceiling test. `buildPartyForgePortfolio().length` remains 16.

## Files changed

### Party Forge implementation commit `0932bfb` (`fix: recover City imports before source preflight`)

- `design/progression/latticewright/party-forge-city-access.pstree`
- `scripts/profile/atomic_json_store.gd`
- `scripts/tools/generated_json_document_writer.gd`
- `tools/import_latticewright_access_snapshot.gd`
- `tests/unit/test_atomic_profile_store.gd`
- `tests/unit/test_generated_json_document_writer.gd`
- `tests/unit/test_latticewright_access_import_cli.gd`

### Latticewright implementation commit `575ada0` (`fix: preserve accepted Party Forge portfolio bytes`)

- `scripts/party-forge/create-party-forge-portfolio.mjs`
- `scripts/party-forge/create-party-forge-portfolio.test.mjs`
- `tests/party-forge/portfolio.test.ts`

## Strict TDD evidence

### Latticewright RED

Exact command:

```powershell
node --test scripts/party-forge/create-party-forge-portfolio.test.mjs; npm.cmd test -- tests/party-forge/portfolio.test.ts
```

Result: exit `1`.

```text
Node producer tests: 4 passed, 2 failed
- exact retained-byte regression showed 15 of 16 retained runtime hashes changed
- guarded writer rejected the accepted pre-existing party-forge-building-apothecary.pstree.json bytes

Vitest: 1 file failed
Tests: 1 failed, 2 passed (3)
- City Access authoring fieldIds were location,destination,visibility instead of the public-codec destination,location,visibility order
```

Why RED was correct: the generic runtime path had projected requirements and applied strict canonical ordering to the retained portfolio, while the City Access authoring path did not apply the public codec's nested `fieldIds` ordering.

### Latticewright GREEN

Exact command:

```powershell
node --test scripts/party-forge/create-party-forge-portfolio.test.mjs; npm.cmd test -- tests/party-forge/portfolio.test.ts
```

Result: exit `0`.

```text
Node producer tests: 6 passed, 0 failed
Vitest Test Files: 1 passed (1)
Vitest Tests: 3 passed (3)
```

The Node regressions verify all 32 accepted retained-file SHA-256 values, guarded-writer preservation, separate City Access output, deterministic serialization, and the authoring/runtime 64 MiB ceiling. The Vitest regression verifies City authoring byte parity with `stringifyProjectV3`.

### Party Forge RED: recovery ownership, ordering, indeterminate state, and stages

Exact command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_latticewright_access_import_cli.gd
```

Result: exit `1`.

```text
TEST_SUMMARY: FAIL (13 failures)
- AtomicJsonStore recovery entry point was missing
- GeneratedJsonDocumentWriter recovery entry point was missing
- recovery-before-request/read/translate counters remained 0
- unresolved recovery still invoked all five downstream dependencies and reported imported
- confinement, mkdir, mkdir-target, stage-previous, and verify-previous collapsed to unknown
```

Why RED was correct: the CLI could reject before the fixed writer saw pending transaction evidence, and its current-stage sanitizer did not recognize all legitimate writer stages.

### Party Forge RED: recovery cleanup debt aggregation

After the main recovery behavior was green, self-review found that a successful later write overwrote cleanup debt reported by recovery. A new focused regression was added before the fix.

Exact command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_latticewright_access_import_cli.gd
```

Result: exit `1`.

```text
TEST_SUMMARY: FAIL (1 failures)
service retains recovery cleanup debt after a debt-free write: expected true
```

### Party Forge GREEN

Exact command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_latticewright_access_import_cli.gd
```

Result: exit `0`.

```text
TEST_SUMMARY: PASS (0 failures)
```

The isolated CLI cleanup-debt rerun also exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

The real-filesystem regressions cover no-pending recovery, exact retained-prior restoration and evidence cleanup, already-verified candidate recovery, unresolved restoration with retained evidence, request/read/translate failure after recovery, and zero downstream calls after indeterminate recovery. Mocks are limited to dependency seams and failure injection; no test-only production API was added.

## Fresh verification

### Latticewright

```powershell
node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
```

Exit `0`: 6 passed, 0 failed.

```powershell
npm.cmd test -- tests/party-forge/portfolio.test.ts
```

Exit `0`: 1 file passed, 3 tests passed.

```powershell
npm.cmd run typecheck
```

Exit `0`.

```powershell
npm.cmd run lint
```

Exit `0`.

```powershell
npm.cmd test
```

Exit `0`.

```text
Test Files  219 passed (219)
Tests       2793 passed (2793)
Duration    134.65s
```

### Party Forge

Exact 12-suite feature gate:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

Exit `0` in 18.68 seconds.

```text
TEST_SUMMARY: PASS (0 failures)
```

Integration acceptance:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

Exit `0`.

```text
CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
```

Explicit checked-in importer replay:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tools/import_latticewright_access_snapshot.gd -- --source res://design/progression/latticewright/party-forge-city-access.pstree.json
```

Exit `0`.

```text
PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
```

Complete Party Forge suite:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 2400 --script res://tests/test_runner.gd
```

Exit `0`.

```text
TEST_SUMMARY: PASS (227 suites)
```

The full suite emitted its established negative-path error/warning diagnostics, including the deliberate invalid UTF-8 path, and reached the single PASS marker without a test failure.

### Artifact integrity and parity

```text
design/progression/latticewright/party-forge-city-access.pstree
  bytes=11055
  sha256=49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a

design/progression/latticewright/party-forge-city-access.pstree.json
  bytes=9972
  sha256=bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78

data/world/access/party-forge-city-access.snapshot.json
  bytes=2539
  sha256=ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55
```

Fresh producer comparison reported authoring parity `true` and runtime parity `true`. `.party-forge-tools/latticewright-city-access` contained zero files after verification. `git diff --check` passed in both worktrees before their implementation commits, and exact staged name/status/stat scopes were inspected before each commit.

## Preservation checks

- The 16-project retained portfolio stays at 16 projects and preserves all 32 accepted authoring/runtime file hashes.
- The City Access artifact remains separate and is the only path receiving the new requirement projection and strict runtime canonicalization.
- The approved authoring-only normalization changed no semantic value, byte count, runtime artifact, or Party Forge snapshot.
- No City scene, navigation, profile schema, `ProfileCodec`, provider activation, passive allocation, legacy format-1 data, main ref, remote, or release was changed.
- No merge or push was performed.

## Self-review and concerns

- The retained `party-forge-city.pstree.json` is intentionally a historical exception: it was separately accepted in canonical order before City Access, while the other 15 retained runtimes keep their earlier byte order. The exact 32-hash regression makes this compatibility choice explicit and fail-closed.
- Recovery continues to use `AtomicJsonStore`'s existing transaction evidence and fixed writer roots. The CLI has no target-restoration implementation and sees only the exact five-key outcome contract.
- The no-pending recovery result proves the absence of unresolved transaction evidence; it does not revalidate the already checked-in target. Candidate/prior validation remains in the existing transaction recovery and ordinary writer paths.
- Historical verification documents still contain the old City authoring hash as evidence of their earlier immutable state. They were not rewritten; this report records the approved replacement hash.
- Independent whole-branch review is still required. This implementation report is not a readiness verdict.
