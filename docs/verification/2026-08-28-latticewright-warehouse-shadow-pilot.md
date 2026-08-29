# Warehouse Access Shadow Pilot Verification

## Qualified revision

- Branch: `feat/latticewright-warehouse-shadow-pilot`
- Tested implementation commit: `4befafc test: qualify Warehouse access shadow pilot`
- Parent implementation commits: `8f4140e`, `b7ee46a`, and `6398826`
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Godot version: `4.7.1.stable.mono.official.a13da4feb`

## Acceptance evidence

The dedicated integration runner was invoked as follows:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

It exited `0` in `1.333` seconds and printed exactly one success marker:

```text
CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
```

The focused acceptance batch was invoked as follows:

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_warehouse_access_policy.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_shadow_comparator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_wiring.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

It exited `0` in `46.407` seconds with `TEST_SUMMARY: PASS (0 failures)`.

The importer replay was invoked as follows:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tools/import_latticewright_access_snapshot.gd -- --source res://design/progression/latticewright/party-forge-city-access.pstree.json
```

It exited `0` in `0.517` seconds and printed:

```text
PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
```

The complete suite was invoked as follows:

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/test_runner.gd
```

It exited `0` in `262.815` seconds with `TEST_SUMMARY: PASS (232 suites)`. Case-sensitive scans of its captured output found zero `FAIL`, `TestFailure`, `ScriptError`, `ParseError`, `FailedLoad`, and `NoLoader` markers. The expected negative-path `ERROR:` and `WARNING:` diagnostics remained contained in passing tests.

## Immutable artifact evidence

```text
party-forge-city-access.pstree       49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a
party-forge-city-access.pstree.json  bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78
party-forge-city-access.snapshot.json ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55
```

The fixed staging/recovery root `.party-forge-tools/latticewright-city-access` contained `0` entries after importer replay.

## Captured shadow observations

The integration runner injects an emitter, so expected divergence is captured without allowing a default comparator warning to affect the runner outcome.

```text
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=DIVERGED access=MATCH visibility=DIVERGED destination=NOT_APPLICABLE legacy_access=BLOCKED candidate_access=BLOCKED reason=visibility_hidden_vs_locked
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=MATCH access=MATCH visibility=MATCH destination=MATCH legacy_access=AVAILABLE candidate_access=AVAILABLE reason=all_dimensions_match
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=UNAVAILABLE access=UNAVAILABLE visibility=UNAVAILABLE destination=UNAVAILABLE legacy_access=BLOCKED candidate_access=UNAVAILABLE reason=candidate_snapshot_load_failed
```

The exact `shadow-locked` and `shadow-unlocked` profiles retain byte-identical `ProfileCodec` output around observation. The repeated unlocked observation remains deduplicated. Flag-off performs no candidate load and returns legacy-only behavior.

`MainMenuViewModel` keeps the no-stash Developer Mode Warehouse preview visible and enabled. In Player Mode, the Warehouse projection is unavailable without `stash` and available with `stash`; the focused `test_main_wiring.gd` also exercises and passes the direct locked Warehouse route rejection. Legacy visibility, route authorization, and navigation remain authoritative.

## Repository checks and boundaries

Before this verification record was created, `git status --short` was clean and `git diff --check main...HEAD` exited `0`. The documentation commit below is the only child of the tested implementation commit.

This pilot is default-off, Developer Mode-only, Warehouse-only, and local diagnostic-only. It does not add a general router, destination dispatch, other location activation, profile/settings mutation, telemetry, or Latticewright changes. Nothing was pushed, merged, published, reinstalled, or cleaned.
