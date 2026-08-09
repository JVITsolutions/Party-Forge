# Task 10M report: equipment-source authority and empty-runner hardening

Status: implementation, TDD, affected/integration/full/startup verification, hygiene audit, and scoped feature commit complete.

Implementation commit: `364cdc59c3e02df4d938071755f7bba81fe69ffd` (`fix: close equipment source authority bypasses`).

## Root causes and remediation

After `PlayerRunContext` bound the Task 10K source-refresh coordinator, the general `PartyManager.add_member_source()` and `replace_member_source()` seams still accepted equipment sources directly. Assignment and recruitment also used the general replacement seam. A configured caller could therefore append a duplicate canonical equipment source or replace that source without proving ownership of the exact live coordinator authority.

The general add/replace seams now fail closed for `source_type == &"equipment"` whenever a coordinator is bound. Their established behavior is otherwise unchanged: bound non-equipment changes still route through the coordinator, and unbound valid sources retain direct behavior.

The existing equipment batch now requires the exact currently bound opaque `RefCounted` authority and a live coordinator. `PlayerRunContext.configure()` passes its retained identity for both new and resumed runs. A new minimal member-local equipment seam applies the same exact-identity/live-coordinator gate, canonical equipment ID and owner validation, catalog validation, one commit, and one invalidation. Assignment and recruited-member initialization use that seam with the context's retained authority. Missing, wrong, aliased, or stale identities reject before validation snapshots or mutation. Task 10K's paired non-equipment/equipment seam and exact unbind lifecycle remain unchanged.

The complete test runner previously treated an unavailable or empty unit directory as a successful zero-suite run, and the focused runner treated an argument-free invocation as success. Discovery now returns explicit error-plus-path state and emits stable nonzero diagnostics for open failure, list failure, and zero discovery. The focused runner emits a stable nonzero diagnostic when no suite paths are supplied. Existing script-error Logger behavior is unchanged.

`tests/support/task10m_empty_runner_probe.ps1` provides checked-in external process-boundary coverage without production test-only APIs. It creates isolated minimal projects, invokes the real runners, consumes stdout and stderr concurrently, polls the exact process for at most 30 seconds, validates nonzero exits and exact diagnostics, and deletes only its verified temporary fixture/process targets.

## Atomic rejection coverage

Real configured-run regressions prove that rejected direct equipment add, duplicate append, direct replace, batch replace, and member-local replace attempts preserve:

- canonical member source documents and activation documents;
- run inventory/equipment ownership containers and immutable item bytes;
- shared stat revision;
- base-stat and action-snapshot object identity;
- `stats_changed` emissions; and
- attached runtime health maximum and current health.

The authority cases cover missing, wrong, exact, and stale identities. Existing configure/resume, assignment, recruitment, coordinator replacement/reset, and 24-member behavior remain covered. The Stats Ledger attribution fixture now issues and equips a real Forge Vanguard Sword with Tempered Edge through `PlayerRunContext`; the existing detail-row UI assertion remains exact.

## TDD evidence

### Accepted controlled RED

Before production changes, the three-suite regression command was:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_manager.gd tests/unit/test_player_run_context.gd tests/unit/test_test_runner_contract.gd
```

It executed normally and returned:

```text
TEST_SUMMARY: FAIL (16 failures)
TASK10M_ACCEPTED_RED_EXIT_CODE=1
```

The failures proved the one-argument batch, absent member-local authority seam, direct duplicate append and replacement acceptance, source/revision/cache/signal drift, and false-green empty runners. Expected asserted negative-path `push_error()` diagnostics were present; there was no harness `SCRIPT ERROR`.

The first GREEN attempt exposed a probe defect rather than a product defect: sequential redirected-pipe reads could deadlock when Godot filled stderr. Only the exact verified probe wrapper/child processes under the task temporary root were terminated. The regression was moved to the bounded external probe and both output pipes are now consumed concurrently.

### Focused GREEN

The final authority/runtime focused gate returned:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10M_AUTHORITY_RUNTIME_GREEN_EXIT_CODE=0
```

The dedicated runner probe returned:

```text
TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 zero=1 focused=1
TASK10M_STANDALONE_RUNNER_PROBE_EXIT_CODE=0
```

## Fresh verification

Godot: `4.7.1.stable.official.a13da4feb`.

Commands were run from the isolated worktree root (the `$godot` variable was the resolved console executable):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/support/task10m_empty_runner_probe.ps1 -GodotPath $godot
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_manager.gd tests/unit/test_player_run_context.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_manager.gd tests/unit/test_player_run_context.gd tests/unit/test_run_context_registry.gd tests/unit/test_non_equipment_activation_refresh.gd tests/unit/test_member_stat_resolution_service.gd tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_resolved_attack_geometry.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_health_component.gd tests/unit/test_item_tooltip_panel.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path . --quit-after 36000 --script res://tests/test_runner.gd
```

Import and startup used the same executable with `--headless --editor --path . --import --quit-after 1800` and `--headless --path . --quit-after 1800`, respectively, after setting APPDATA and LOCALAPPDATA to the resolved task-local settings directories.

The widened 16-suite Task 10I/10J/10K/10L affected gate covered PartyManager, PlayerRunContext, registry/lifecycle, non-equipment refresh, member resolution, activation/transition, estimates/geometry/comparisons, profile assignment/projection, ledger provider/page, health, and tooltip behavior:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10M_AFFECTED_TASK10I_J_K_L_EXIT_CODE=0
```

The standalone focused runner retains its previously documented 18-ObjectDB/5-resource shutdown notice and is not represented as the clean shutdown gate.

Equipment configure/resume and action-cache integration:

```text
TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1633
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10M_EQUIPMENT_24_EXIT_CODE=0
```

Progression/lifecycle integration:

```text
PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK10M_PROGRESSION_24_EXIT_CODE=0
```

The progression runner retains its already documented subprocess shutdown notices.

Profile storage and responsive tooltip integrations:

```text
ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99
TASK10M_PROFILE_STORAGE_EXIT_CODE=0
ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)
TASK10M_TOOLTIP_EXIT_CODE=0
```

Tooltip verification also included the compatibility 1280x720 case plus 1920x1080, 2560x1440, and 3840x2160 responsive viewports. An initial ledger command contained the nonexistent filename `ledger_24_member_responsive_runner.gd` and failed at loader startup with exit `1`; it was not counted as a test result. The corrected checked-in runner returned:

```text
LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)
TASK10M_LEDGER_24_EXIT_CODE=0
```

Hardened complete suite:

```text
TEST_SUMMARY: PASS (166 suites)
TASK10M_HARDENED_FULL_EXIT_CODE=0
```

The complete runner finished in 148.1 seconds. Its 94,280-byte log had zero exact matches for test failure, captured `SCRIPT ERROR`, parse/load failures, ObjectDB/resource/RID/allocator/orphan leaks, fatal, or crash diagnostics. Established asserted negative-path domain errors and warnings remain; the full shutdown scan is clean.

Isolated import/startup used task-local APPDATA and LOCALAPPDATA roots and returned:

```text
TASK10M_ISOLATED_IMPORT_EXIT_CODE=0
PARTY_FORGE_BOOT_OK
PARTY_FORGE_CLASS_SELECTION_READY
TASK10M_ISOLATED_STARTUP_EXIT_CODE=0
```

Both startup markers appeared exactly once. Import and startup scans contained zero parser/script/loader/leak/fatal/crash markers. Import recreated six known cache sidecars (`action_cadence.gd.uid`, `candidate_action_validation_service.gd.uid`, three support probe UIDs, and `test_action_cadence.gd.uid`); those exact import-created files were removed without touching the protected set.

## Scope and hygiene

Tracked Task 10M files are limited to:

- `scripts/party/party_manager.gd`
- `scripts/run/player_run_context.gd`
- `tests/focused_test_runner.gd`
- `tests/test_runner.gd`
- `tests/support/task10m_empty_runner_probe.ps1`
- `tests/unit/test_party_manager.gd`
- `tests/unit/test_player_run_context.gd`
- `tests/unit/test_stats_ledger_page.gd`
- `.superpowers/sdd/task-10m-report.md`

`git diff --check` passed. The feature commit contains zero `.gd.uid` files. Before verification and again after import cleanup, the protected manifest was exactly 127 files with path SHA-256 `8b2b1faa563decd5ccd1817f5ed5819c9d7136b04a120c95b530e59edc16dc1b` and content-manifest SHA-256 `40aecb998ba34829c10a96f11ae20722c51140c08d32628a94336f4c00b4f7cd`.

Task-local verification logs and isolated settings roots remain ignored under `.superpowers/sdd`; they contain no tracked descendants and are not commit scope. Policy prevented their final recursive deletion after their targets were resolved beneath this isolated worktree. The authoritative main checkout was not modified, reset, stashed, or cleaned.

## Remaining concerns

No Task 10M functional concern remains. The ignored task-local verification artifacts are the only cleanup residue. Physical-controller acceptance and visible GPU-backed manual pixel review remain deferred at the wider project level; neither is part of this authority/test-runner remediation.
