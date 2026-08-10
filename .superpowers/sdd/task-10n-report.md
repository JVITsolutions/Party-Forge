# Task 10N report: final fresh verification, hygiene, and evidence refresh

Status: **DONE**. Final verification and scoped hygiene passed at exact feature input `1d5fdbeb57addd037dd4ddd0b9788db72fffe022`; only durable evidence was changed, and the branch was not integrated.

## Scope and preflight

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Branch: `feat/equipment-attribute-application`.
- Approved-design range: `00d145d7b461dde8d2cf4b01b36d57fb5ee73852..1d5fdbeb57addd037dd4ddd0b9788db72fffe022` (43 commits after the start).
- Godot: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`, version `4.7.1.stable.mono.official.a13da4feb`.
- Feature tracked and index diffs were empty at preflight. Only protected untracked `.gd.uid` sidecars were present.
- The authoritative main checkout was captured read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63`. Its known tracked overlays are `scripts/party/party_manager.gd` and `scripts/party/party_member_state.gd`; it was not mutated, reset, cleaned, stashed, or integrated.
- Fifteen unrelated `godot-ai.exe` helpers existed. No editor/game/import/test/generator process targeted this worktree, and no unrelated process was stopped.

The canonical UID manifest serializes each sorted normalized relative path, byte length, and per-file SHA-256 with tab delimiters, joining rows with LF and no trailing LF. It measured exactly 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`. A trailing LF instead produces `406771aca63ab52a7fb02ccffabd0a8123c91343de3e5d1e4a49b605d8971d42`. Task 10M's older path/content hashes used another serialization; none is evidence of content drift.

## Accepted commands and results

All commands ran sequentially from the worktree root with fresh task-local `APPDATA=.superpowers\sdd\task-10n-final-appdata` and `LOCALAPPDATA=.superpowers\sdd\task-10n-final-localappdata`.

```powershell
& $godot --headless --editor --path . --import --quit-after 1800
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/logger_teardown_order_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/script_error_capture_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_damage_resolver.gd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/support/task10m_empty_runner_probe.ps1 -GodotPath $godot
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd
```

| Gate | Exit / duration | Result |
| --- | --- | --- |
| Import | `0` / 17.320s | six known missing-UID cache warnings; forbidden diagnostic scan clean |
| Logger teardown | `0` / 0.269s | `TEST_SUMMARY: PASS (0 failures)` |
| Deliberate script error | expected `1` / 0.268s | `TEST_SUMMARY: FAIL (1 failures)`; exact source `script_error_capture_probe.gd:6`, function `run` |
| Intentional `push_error()` | `0` / 0.918s | `TEST_SUMMARY: PASS (0 failures)` and four expected damage errors; established standalone 18-ObjectDB/five-resource notice |
| External empty-runner probe | `0` / 1.517s | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Direct no-argument focused runner | expected `1` / 0.400s | stable `FOCUSED_TEST_RUNNER_ERROR: no suite path arguments`; `TEST_SUMMARY: FAIL (1 failures)` |

The external probe proves real full-runner open failure, real `list_dir_begin()` failure, zero discovery, and focused no-argument failure all return nonzero. The direct current-worktree focused invocation independently confirms its stable diagnostic. The full runner cannot emit PASS for zero suites.

### Expanded focused matrix

```powershell
& $godot --headless --path . --quit-after 2400 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_attribute_derived_source_projector.gd `
  tests/unit/test_member_stat_resolution_service.gd `
  tests/unit/test_action_archetype.gd `
  tests/unit/test_action_cadence.gd `
  tests/unit/test_damage_resolver.gd `
  tests/unit/test_action_combat_estimate_service.gd `
  tests/unit/test_attack_execution.gd `
  tests/unit/test_resolved_attack_geometry.gd `
  tests/unit/test_equipment_modifier_projector.gd `
  tests/unit/test_equipment_activation_resolver.gd `
  tests/unit/test_equipment_transition_service.gd `
  tests/unit/test_party_manager.gd `
  tests/unit/test_player_run_context.gd `
  tests/unit/test_health_component.gd `
  tests/unit/test_run_context_registry.gd `
  tests/unit/test_local_run_setup_coordinator.gd `
  tests/unit/test_non_equipment_activation_refresh.gd `
  tests/unit/test_increment2_generator_parity.gd `
  tests/unit/test_equipment_assignment_service.gd `
  tests/unit/test_profile_loadout_assignment_service.gd `
  tests/unit/test_profile_storage_projection.gd `
  tests/unit/test_game_catalog.gd `
  tests/unit/test_ledger_data_provider.gd `
  tests/unit/test_stats_ledger_page.gd `
  tests/unit/test_resolved_stat_comparison_service.gd `
  tests/unit/test_item_comparison_resolver.gd `
  tests/unit/test_item_presentation_projector.gd `
  tests/unit/test_developer_item_sandbox_state.gd `
  tests/unit/test_developer_item_sandbox.gd `
  tests/unit/test_item_tooltip_card.gd `
  tests/unit/test_item_tooltip_panel.gd `
  tests/support/logger_teardown_order_probe.gd
```

This exact nonzero 32-file union adds Task 10M dead-callback authority and runtime geometry coverage to the prior Task 1-10L matrix. It exited `0` in 80.344s with `TEST_SUMMARY: PASS (0 failures)` and the stable developer-sandbox SHA-256. Its 5,107-byte log had one PASS summary and zero fail/test-failure, captured/raw script error, parser/loader, shutdown-leak, fatal, crash, or access-violation marker.

### Hardened complete suite

```powershell
& $godot --headless --path . --quit-after 36000 --script res://tests/test_runner.gd
```

Exit `0`, 130.960s, 46,732 bytes:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (166 suites)
```

The PASS summary appeared once. The log contained zero FAIL summary, `TEST_FAILURE`, captured/raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. Exactly 57 established asserted negative-path error markers and ten documented JSON-store warnings remained.

### Integrations and startup

```powershell
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path . --quit-after 1800
```

| Gate | Exit / duration | Exact marker(s) |
| --- | --- | --- |
| Equipment/cache | `0` / 1.611s | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1688`; `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| Progression | `0` / 15.203s | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Cleric ledger | `0` / 2.769s | `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)` |
| Profile/storage | `0` / 8.796s | `ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99` |
| Tooltip | `0` / 2.582s | compatibility 1280x720; responsive 1920x1080, 2560x1440, 3840x2160; `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)` |
| Startup | `0` / 14.438s | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once |

The progression parent and four size subprocesses retain five documented sets of three dummy mesh RIDs, 130 ObjectDB instances, 114 resources, and medium/small PagedAllocator notices. Every other integration/startup scan was clean.

## Generator parity provenance

The last accepted fresh cold proof input is `51b6f0096e595a9d0370c24e8679629ad55e2291`. The exact command:

```powershell
git diff --name-status 51b6f0096e595a9d0370c24e8679629ad55e2291..1d5fdbeb57addd037dd4ddd0b9788db72fffe022 -- tools data tests/unit/test_increment2_generator_parity.gd
```

returned no paths, and `git diff --quiet` over the same range/scope exited `0`. This checks every generator and its row inputs under `tools/`, every generated/canonical path under `data/`, and the complete parity-suite input. The parity suite also passed within the 32-file gate. The isolated Task 10H proof for `migrate_typed_combat_data.gd`, `create_stat_foundation_data.gd`, `create_character_upgrade_data.gd`, `create_default_data.gd`, and `migrate_class_expansion_data.gd` was therefore reused; no new destructive cold generation was warranted.

## Evidence integrity and cleanup

Two preliminary wrapper attempts were rejected as evidence. The first used stop-on-error and PowerShell promoted an expected missing-UID warning to `NativeCommandError` before an exit could be recorded. The second completed the gates, but its result records were captured into arrays rather than emitted, so exact timings were unavailable. No result from either attempt is credited. Before the accepted run, exact task-created settings/log targets were validated beneath `.superpowers\sdd`, the six allowlisted generated sidecars were checked by byte length/hash, and the protected 127-file baseline was restored.

After evidence extraction, exact cleanup validation removed 24 top-level targets / 41 files / 7,089,808 logical bytes beneath this worktree's `.superpowers\sdd`: four Task 10M logs and its settings root, fourteen Task 10N logs and two settings roots, and three obsolete review diffs. Every target had zero tracked descendants and zero reparse points. Briefs, reports, progress, and `review-ef28190..1d5fdbe.diff` were preserved. Temporary cleanup helpers were removed; the residue scan returned zero.

The accepted import/gates produced eight sidecars. Six were the established import-warning files with previously recorded lengths/hashes. Two additional Task 10M support-script sidecars were created at the accepted import timestamp:

- `tests/support/task10m_list_failure_runner.gd.uid`: 20 bytes, SHA-256 `eb858aaf08f4b6f5d8c4cbf4e5b00ccc1e3c9e38c554ec7a32f10b1f7b749da3`.
- `tests/support/test_suite_discovery.gd.uid`: 20 bytes, SHA-256 `ba309cb99472122b2f84ece719f33be37ef8c941d8b7b27d9cf25d7cc4b6b02c`.

Only those eight exact generated files were deleted. The final protected manifest returned to exactly 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`.

Final hygiene found zero worktree-targeting Godot process and left all 15 unrelated `godot-ai.exe` helpers untouched. `git diff --name-only -- data`, the index diff, and tracked drift outside the two evidence deliverables were empty; `git diff --check` passed. The authoritative main checkout remained read-only with its same two tracked overlays.

## Remaining limitations

- Physical-controller acceptance remains deferred.
- Visible GPU-backed/pixel-level manual review remains deferred.
- The progression integration and isolated asserted-`push_error()` probe retain their documented standalone shutdown notices; the 166-suite hardened runner is the shutdown-clean release gate.
- Task 10N does not integrate the branch into main.
