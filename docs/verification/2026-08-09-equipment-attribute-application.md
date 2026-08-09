# Equipment and Attribute Application Verification

Verified 2026-08-09 in the isolated linked worktree on branch `feat/equipment-attribute-application`.

## Scope and exact pre-state

- Approved design base: `00d145d`.
- Fresh verification input: `fd7ba780decd12ebf085f4048bb1085380c5c45b` (`test: drain script errors after logger detach`). This includes the full-review remediation in Tasks 10A-E.
- `git status --short --branch` reported `## feat/equipment-attribute-application` plus only 127 pre-existing untracked `.gd.uid` sidecars. `git diff --name-only` and `git diff --cached --name-only` were empty.
- The content-aware sidecar manifest contained sorted normalized relative paths, byte lengths, and per-file SHA-256 values. It contained 127 files / 2,503 bytes and had aggregate SHA-256 `5f666d4187d174cd04482e4fe0e864beb374c639109bf06e9f278ff9350f04b9`.
- The process snapshot found 15 `godot-ai.exe attach` helpers at PIDs `10900`, `12016`, `14120`, `14816`, `16324`, `18024`, `27292`, `32504`, `32844`, `34792`, `37916`, `38348`, `38720`, `40020`, and `42320`. It found no Godot editor or test process targeting this worktree. No user editor or unrelated helper was stopped.
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.
- Exact engine version: `4.7.1.stable.mono.official.a13da4feb`.
- Every accepted authoritative-worktree Godot command used `.superpowers\sdd\task-10f-clean-appdata` and `.superpowers\sdd\task-10f-clean-localappdata` as brand-new task-specific `APPDATA` and `LOCALAPPDATA` roots. Each disposable generator copy used its own sibling task-specific settings roots.

Common setup:

```powershell
$repo = (Get-Location).Path
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10f-clean-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10f-clean-localappdata'
```

## Fresh import/parser gate

```powershell
& $godot --headless --path . --editor --quit-after 300
```

- Exit `0`; `8.479s`.
- Zero `SCRIPT ERROR`, parse/parser error, failed script/resource load, missing loader, invalid call/index, fatal, or crash diagnostics.
- The editor completed filesystem scan and global-class registration. `MCP | plugin disabled in headless mode` was informational.

## Hardened runner proofs

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/logger_teardown_order_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/script_error_capture_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_damage_resolver.gd
```

| Gate | Required result | Fresh result |
| --- | --- | --- |
| Logger teardown order | normal PASS | exit `0`; `0.497s`; `TEST_SUMMARY: PASS (0 failures)`; zero captured `SCRIPT ERROR` |
| Deliberate script error | hardened runner rejects it | exit `1`; `0.468s`; `TEST_SUMMARY: FAIL (1 failures)`; captured `res://tests/support/script_error_capture_probe.gd:6`, function `run`, and the nil-property reason |
| Intentional `push_error` negative paths | asserted domain errors do not become script errors | exit `0`; `1.440s`; `TEST_SUMMARY: PASS (0 failures)`; four asserted `PARTY_FORGE_DAMAGE_ERROR` records; zero captured `SCRIPT ERROR` |

The runner detaches its mutex-protected logger before draining it. The probe proves a real `ERROR_TYPE_SCRIPT` event forces nonzero failure, while ordinary intentional `push_error` diagnostics remain testable domain output.

## Tasks 1-10E focused remediation gate

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_attribute_derived_source_projector.gd `
  tests/unit/test_member_stat_resolution_service.gd `
  tests/unit/test_action_archetype.gd `
  tests/unit/test_damage_resolver.gd `
  tests/unit/test_action_combat_estimate_service.gd `
  tests/unit/test_equipment_modifier_projector.gd `
  tests/unit/test_equipment_activation_resolver.gd `
  tests/unit/test_equipment_transition_service.gd `
  tests/unit/test_player_run_context.gd `
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
  tests/unit/test_item_presentation_projector.gd `
  tests/unit/test_developer_item_sandbox_state.gd `
  tests/unit/test_developer_item_sandbox.gd `
  tests/unit/test_item_tooltip_card.gd `
  tests/support/logger_teardown_order_probe.gd
```

- Exit `0`; `71.271s`; exact marker `TEST_SUMMARY: PASS (0 failures)` once.
- Zero `TEST_FAILURE`, `SCRIPT ERROR`, parse/parser error, failed-load, or missing-loader diagnostics.
- Allowed asserted output was exactly four `PARTY_FORGE_DAMAGE_ERROR` records plus one `PARTY_FORGE_STAT_ERROR` record.

Remediation coverage:

| Review task | Fresh coverage in this gate |
| --- | --- |
| 10A | source-refresh atomicity, registry exact-owner lifecycle, coordinator bind/release, rollback, unrelated-member cache isolation |
| 10B | complete retained attack/stat/keyword source and persisted-catalog parity |
| 10C | occupied swap, reserved-slot displacement, configured storage order, capacity rejection, preview/apply parity |
| 10D | every owned damaging/healing action, refresh/resume validation, estimate invariants, duplicate action-ID policy, ledger consumer parity |
| 10E | strict six-attribute requirement schema, monotonic core-modifier policy, fixed-point preflight, sandbox/profile presentation atomicity, ledger fixture completion, logger teardown order |

## Hardened complete suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

- Exit `0`; `127.274s`.
- Exact marker: `TEST_SUMMARY: PASS (165 suites)` once.
- Additional exact markers: `DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe` and `ITEM_TRANSACTION_MATRIX: PASS`, each once.
- Zero `TEST_SUMMARY: FAIL`, `TEST_FAILURE`, captured `SCRIPT ERROR`, parse/parser error, failed-load/missing-loader, fatal, or crash markers.
- Zero ObjectDB, resource-in-use, RID, or orphan shutdown diagnostics.
- The passing negative-path suites intentionally emitted 55 domain `push_error` records, 10 asserted JSON-store warnings, and one forced engine directory-creation failure. These retained the established `PARTY_FORGE_*_ERROR`, `PROFILE_BOOTSTRAP_ERROR`, `PROFILE_REFRESH_ERROR`, `JSON_STORE_LOAD_ERROR`, `JSON_STORE_SAVE_ERROR`, `JSON_STORE_CLEANUP_DEBT`, and `JSON_STORE_CORRUPT_PRIMARY_PRESERVED` contracts. None was a runtime script or test-harness error.

## Fresh integrations and startup

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 1200 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path . --quit-after 300
```

| Gate | Exit / duration | Exact accepted marker(s) |
| --- | --- | --- |
| Equipment application | `0` / `1.507s` | `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| Progression isolation | accepted isolated rerun `0` / `14.974s` | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Profile/storage isolation | `0` / `8.615s` | `ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99` |
| Responsive tooltip | `0` / `2.490s` | compatibility `1280x720`; responsive size passes at `1920x1080`, `2560x1440`, `3840x2160`; `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)` |
| 24-member ledger | `0` / `2.672s` | `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)` |
| Startup smoke | `0` / `4.063s` | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once |

All six gates contained zero `SCRIPT ERROR`, test-failure, parse/parser, failed-load/missing-loader, fatal, or crash markers. The equipment integration covered automatic non-equipment-source activation refresh, candidate action rejection atomicity, immutable items, resume, one-member notification/cache replacement, and exact isolation for members 2-24.

The progression runner retained its established subprocess shutdown output. Each of its five engine processes reported three dummy-mesh RID allocations, 128 ObjectDB instances, 113 resources, and the medium/small PagedAllocator pages at exit. The parent and every child still exited `0`, and both required progression markers were present. This is explicitly not represented as shutdown-hygiene-clean.

## Current-HEAD cold generator parity

The cold evidence was regenerated from the verification input commit; no prior Task 10B copy was reused.

```powershell
git archive --format=zip --output=.superpowers/sdd/task-10f-cold-head.zip HEAD
tar -xf .superpowers/sdd/task-10f-cold-head.zip -C <fresh-copy>
& $godot --headless --path <fresh-copy> --import
$env:PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT = $repo.Replace('\', '/')
& $godot --headless --path <fresh-copy> --quit-after 600 --script <generator-script>
& $godot --headless --path <fresh-copy> --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_increment2_generator_parity.gd
```

- Current-HEAD archive: 43,671,733 bytes; SHA-256 `777f4a0f07f692f6cee623a5c1bd0d31fa858a9ca2610531defd96dd11687f3c`.
- Each of the five final copies began with 2,374 archive files, 217 asset files, and no `.godot` cache.
- Terminating `--import` exited `0` with 1,192 imported artifacts in every copy. Durations were typed `30.035s`, stats `30.610s`, keywords `30.832s`, default `30.529s`, and class expansion `31.300s`. Every import had zero aborted-scan or forbidden diagnostics.

| Disposable generator | Generator result | Complete parity result |
| --- | --- | --- |
| `migrate_typed_combat_data.gd` | exit `0`; `0.398s`; `PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=9` | exit `0`; `0.451s`; `TEST_SUMMARY: PASS (0 failures)` |
| `create_stat_foundation_data.gd` | exit `0`; `0.262s` | exit `0`; `0.445s`; `TEST_SUMMARY: PASS (0 failures)` |
| `create_character_upgrade_data.gd` | exit `0`; `0.908s`; `PARTY_FORGE_CHARACTER_UPGRADE_DATA_SAVED upgrades=25 names=10 keywords=81` | exit `0`; `0.446s`; `TEST_SUMMARY: PASS (0 failures)` |
| `create_default_data.gd` | exit `0`; `0.444s`; `DATA_GENERATION_OK` | exit `0`; `0.448s`; `TEST_SUMMARY: PASS (0 failures)` |
| `migrate_class_expansion_data.gd` | expected unrelated exit `1`; `1.001s`; 36 starter-loadout capability diagnostics across Paladin, Rogue, Frost Mage, Warlock, and Marksman | exit `0`; `0.444s`; `TEST_SUMMARY: PASS (0 failures)` for every retained emitted attack |

Every parity run used the hardened focused runner and recorded zero captured `SCRIPT ERROR`. The authoritative worktree had no `data/` diff before or after these disposable runs. The class-expansion nonzero result is the already recorded later validation boundary: its older class rows still lack equipment capability tags required by starter-loadout validation; it is not attack/stat/keyword generator drift.

## Diagnostic audit, rejected attempts, and hygiene

The following invocations were deliberately rejected as evidence:

- An initial multi-probe PowerShell wrapper used `$args` as a function parameter. `$args` is automatic in PowerShell, so it bound zero engine arguments and launched the normal project instead of the headless runner. Its task-created console/GUI pair (PIDs `38456`/`28476`) survived the shell timeout and shared the first settings root. Cleanup exposed the open `godot.log`; the exact parent/child provenance was verified, only those task processes were stopped, and unrelated `godot-ai` helpers were left untouched. Every earlier authoritative-worktree result was invalidated, its root was removed, and every accepted authoritative gate above was rerun with zero overlap under the brand-new `task-10f-clean-*` roots.
- During the invalidated first-root sequence, one intentional-domain-error invocation printed `TEST_SUMMARY: PASS (0 failures)` and then exited with Windows access-violation code `-1073741819`.
- The first clean-root progression invocation likewise printed both required PASS markers and then exited `-1073741819`. It was rejected. With no Godot process remaining, the exact isolated rerun exited `0` in `14.974s`, printed both markers once, and contained zero forbidden diagnostics. The post-PASS access violation therefore remains intermittent engine/process behavior, not accepted proof.
- An initial disposable-copy `--editor --quit-after 300` attempt exited `0` but logged `Scan thread aborted` and created zero imported artifacts. Those copies were rejected. All accepted generator copies were recreated from the exact archive and used terminating `--import`.

The authoritative import created exactly four sidecars proven absent from the pre-state snapshot, all at the import timestamp:

- `scripts/combat/candidate_action_validation_service.gd.uid`
- `tests/support/logger_teardown_order_probe.gd.uid`
- `tests/support/script_error_capture_probe.gd.uid`
- `tests/support/test_script_error_capture.gd.uid`

Only those exact files were removed. The remaining manifest returned to exactly 127 files / 2,503 bytes and the original SHA-256 `5f666d4187d174cd04482e4fe0e864beb374c639109bf06e9f278ff9350f04b9`. No `.import` sidecar was added or removed.

Final hygiene commands:

```powershell
git status --short --branch
git diff --check
git diff --name-only
git diff --cached --name-only
git diff --name-only -- data
```

The ignored task settings, logs, archive, and disposable copies were removed after evidence extraction. Before this document was authored there was no tracked/index drift; after authoring, this document was the only intended tracked change.

## Deferred hands-on review and remaining concerns

- A physical-controller pass is deferred. Automated controller contracts elsewhere remain covered, but this verification does not claim hardware gamepad behavior.
- Manual pixel review in a visible GPU-backed window is deferred. The responsive runner proves deterministic geometry and content containment through 4K, not human visual-quality sign-off.
- The progression runner's established shutdown leak diagnostics remain visible and should not be confused with a clean shutdown pass.
- The retained class-expansion migration still exits `1` on the unrelated starter-loadout capability/tag mismatch described above.
- Two rejected post-PASS Windows access violations occurred in separate processes (one invalidated first-root intentional-domain-error run and one clean-root progression run). Exact isolated reruns plus the consolidated focused gate, complete suite, integrations, and startup all exited `0`; the intermittent engine/process symptom remains documented rather than treated as passing evidence.

No production code, Resource, scene, asset, project setting, profile/save data, canonical generated data, or pre-existing sidecar was changed by Task 10F.
