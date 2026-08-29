# Warehouse Access Shadow Pilot Verification

## Qualified revision

- Final status: `DONE`
- Branch: `feat/latticewright-warehouse-shadow-pilot`
- Tested implementation commit: `5820892faafc90ab42e9d1ef3e90883c9d457c1b fix: reject duplicate City access snapshot keys`
- Documentation child: this document-only commit
- Previous verification tip: `a9b750c docs: refresh Warehouse access shadow pilot verification`
- Parent implementation commits: `9e5395a`, `4befafc`, `8f4140e`, `b7ee46a`, and `6398826`
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Godot version: `4.7.1.stable.mono.official.a13da4feb`

## Final-review duplicate-key correction

The final reviewer found that `CityAccessSnapshotLoader.load_bytes` called Godot's `JSON.parse` directly. Godot accepts duplicate JSON object keys and retains the later member, so root and nested duplicate-key snapshots could pass into schema validation despite the approved fail-closed design.

The existing strict tooling reader already had the required recursive token scanner. The scanner was extracted without logic changes to `res://scripts/data/strict_json_token_scanner.gd`. Both `StrictJsonDocumentReader` and `CityAccessSnapshotLoader` now invoke that shared, pure scanner before `JSON.parse`; the runtime loader returns a sanitized failure for any duplicate object key.

### TDD RED

Tests were added first for raw duplicate keys at the snapshot root and inside a location object, plus a real `CityAccessProvider` to `CityAccessShadowComparator` path using duplicate snapshot bytes. The provider/comparator case requires `candidate_snapshot_load_failed`, forbids raw key/source/path leakage, and verifies unchanged profile and settings inputs.

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_shadow_comparator.gd
```

Before the production fix, this exited `1` in `1.528` seconds with `TEST_SUMMARY: FAIL (12 failures)`. Both raw duplicate documents loaded successfully, and the comparator returned the ordinary locked divergence (`visibility_hidden_vs_locked`) instead of sanitized `UNAVAILABLE`. This is the expected regression failure.

### TDD GREEN

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_strict_json_document_reader.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_shadow_comparator.gd
```

After the shared-scanner fix, this exited `0` in `16.601` seconds with `TEST_SUMMARY: PASS (0 failures)`. The strict reader retained its duplicate-key stage and exact-byte/hash behavior; the loader rejected root and nested duplicates; the provider/comparator path emitted only the allowlisted `candidate_snapshot_load_failed` reason.

An extraction comparison against the scanner body at `a9b750c` produced `SCANNER_BODY_DIFF_COUNT=0` after removing its former single nesting indentation.

## Fresh qualification on the tested implementation commit

### Focused strict-reader, loader, provider, and comparator suites

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_strict_json_document_reader.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd
```

Exit `0` in `16.426` seconds with `TEST_SUMMARY: PASS (0 failures)`.

### Dedicated integration runner

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

Exit `0` in `3.082` seconds with exactly one acceptance marker:

```text
CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
```

### Mandated 16-file acceptance batch

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_warehouse_access_policy.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_wiring.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

Exit `0` in `42.045` seconds with `TEST_SUMMARY: PASS (0 failures)`. Expected negative-path warnings, errors, and invalid-UTF-8 notices remained contained in passing tests.

### Import replay, hashes, and staging

```powershell
& $godot --headless --path . --quit-after 600 --script res://tools/import_latticewright_access_snapshot.gd -- --source res://design/progression/latticewright/party-forge-city-access.pstree.json
```

Exit `0` in `0.391` seconds:

```text
PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
```

SHA-256 values before and after replay were identical:

```text
party-forge-city-access.pstree        49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a
party-forge-city-access.pstree.json   bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78
party-forge-city-access.snapshot.json ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55
```

The fixed staging/recovery root `.party-forge-tools/latticewright-city-access` contained `0` entries after replay. `git status --short` remained empty.

### Complete Party Forge suite

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/test_runner.gd
```

Exit `0` in `240.685` seconds with `TEST_SUMMARY: PASS (232 suites)`. Case-sensitive scans of the captured output found zero `FAIL`, `TEST_FAILURE`, `TestFailure`, `ScriptError`, `ParseError`, `FailedLoad`, and `NoLoader` markers. Expected negative-path `ERROR:` and `WARNING:` diagnostics remained contained in passing tests.

## Failure-path and behavioral evidence

Duplicate-key snapshot bytes now fail before ordinary parsing. `CityAccessProvider` converts the load failure to `candidate_snapshot_load_failed`; `CityAccessShadowComparator` reports `UNAVAILABLE` for access, visibility, and destination and emits no raw duplicate key, source text, filesystem path, parser text, profile ID, or display name.

The existing integration evidence remains unchanged:

```text
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=DIVERGED access=MATCH visibility=DIVERGED destination=NOT_APPLICABLE legacy_access=BLOCKED candidate_access=BLOCKED reason=visibility_hidden_vs_locked
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=MATCH access=MATCH visibility=MATCH destination=MATCH legacy_access=AVAILABLE candidate_access=AVAILABLE reason=all_dimensions_match
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=UNAVAILABLE access=UNAVAILABLE visibility=UNAVAILABLE destination=UNAVAILABLE legacy_access=BLOCKED candidate_access=UNAVAILABLE reason=candidate_snapshot_load_failed
```

Profile and settings dictionaries are compared before and after duplicate-key observation and remain equal. The candidate remains observational: the authoritative legacy menu projection, Warehouse route authorization, unrestricted Developer preview, diagnostic deduplication, and default-off gate are unchanged.

## Repository checks and unchanged boundaries

At the tested implementation commit, `git status --short` was empty and `git diff --check main...HEAD` exited `0`. The documentation child contains only this verification file.

This correction changes no loader schema fields, snapshot bytes, hashes, comparator allowlist, UI, routes, profiles, settings, Developer preview, importer behavior, generated artifacts, Latticewright files, or authoring/runtime documents. It does not implement optional hidden/malformed/unknown-location recommendations. Nothing was pushed, merged, published, reinstalled, or cleaned.
