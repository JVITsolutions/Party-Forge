# Task 10O report: final whole-branch review remediation

Status: **DONE**. All four findings in `task-10o-brief.md` were fixed test-first in the isolated `feat/equipment-attribute-application` worktree. Functional commit: **69bec9790a94264ca431731a2c02f61604c6c8c9** (`fix: close final equipment attribute review findings`). The evidence-only successor commit contains this report and the verification-document update; its exact hash is emitted in the handoff because a commit cannot embed its own final hash.

## Scope and preflight

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Approved-design range at the functional head: `00d145d7b461dde8d2cf4b01b36d57fb5ee73852..69bec9790a94264ca431731a2c02f61604c6c8c9` (45 commits after the range start).
- Godot used for Task 10O evidence: `C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`, reporting `4.7.1.stable.official.a13da4feb`.
- The authoritative main checkout stayed read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63`; its two known tracked overlays remained `scripts/party/party_manager.gd` and `scripts/party/party_member_state.gd`. Nothing was integrated.
- The protected sidecar baseline used sorted normalized relative paths, byte lengths, and per-file SHA-256 values joined by LF without a trailing LF: **127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`**.

## Implementation and accepted RED/GREEN evidence

### Complete candidate-source validation

`PartyManager` now validates the complete post-add or post-replace collection before every public source mutation. Equipment sources must be unique, owned by the member, and use exactly `equipment_member_<member_id>`. Batch equipment replacement validates every complete resulting member collection before mutation, so malformed pre-state rejects without normalization or partial commit.

- Accepted RED: `test_party_manager.gd` plus `test_player_run_context.gd`, exit **1**, **3.578s**, `TEST_SUMMARY: FAIL (55 failures)`.
- Accepted GREEN: same suites, exit **0**, **3.462s**, `TEST_SUMMARY: PASS (0 failures)`.
- Regressions cover rogue IDs, duplicate canonical IDs through owned-source fixture corruption, add/replace/batch rejection, configure/resume rejection, and exact source/stat/cache/signal/health/item no-drift.

### Permanently mutation-inactive stale contexts

One `_can_mutate_current_owner()` guard delegates to exact live coordinator ownership/generation. Release, resolution marking, item/equipment transactions, progression, pending-level consumption, actor binding, member-added mutation, and non-equipment refresh now fail closed or no-op when the context is stale. Exact late clear cannot affect a replacement context.

- Accepted RED: `test_player_run_context.gd`, exit **1**, **4.440s**, `TEST_SUMMARY: FAIL (10 failures)`.
- Accepted GREEN: same suite, exit **0**, **4.268s**, `TEST_SUMMARY: PASS (0 failures)`.
- The first hardened full run later exposed one stale fixture assumption: `test_run_resolution_service.gd` created an unconfigured context but expected `mark_items_resolved()` to mutate it. The fixture was moved to a configured current owner, preserving live-owner transaction semantics while leaving stale/unconfigured mutation disabled.

### Caster-only Warlock

The generator row and canonical Warlock class remove only the stale `ranged` capability. Theme, identity, projectile, armour, and equipment tags remain. Actual-catalog regressions cover the relevant melee/ranged/caster ledger archetypes for all nine classes, and the real Warlock bolt snapshot proves caster modifiers apply while ranged-only modifiers do not.

- Accepted RED: catalog/ledger/action/generator suites, exit **1**, **3.523s**, `TEST_SUMMARY: FAIL (6 failures)`.
- Accepted GREEN: same suites, exit **0**, **4.615s**, `TEST_SUMMARY: PASS (0 failures)`.
- The first hardened full run found one remaining stale `test_expanded_class_content.gd` expected row. Removing only `ranged` aligned that fixture with the approved generator and canonical resource contract.

### Neutral raw-roll fallback

Fallback comparison rows retain raw numeric direction separately but set benefit `direction` to neutral. Visible text names the raw operation and higher/lower direction with `benefit unknown`; accessible text adds `neutral comparison`. Authoritative projected rows retain their existing improved/worse colors and unchanged-row omission.

- One preliminary RED attempt had test-harness script errors and was rejected as evidence.
- Accepted RED after fixing the test harness: comparison/tooltip suites, exit **1**, **0.502s**, `TEST_SUMMARY: FAIL (49 failures)`, with no script error.
- Accepted GREEN: same suites, exit **0**, **0.409s**, `TEST_SUMMARY: PASS (0 failures)`.
- A post-clean exact-text check caught mojibake punctuation in both implementation and expectation: RED exit **1**, `TEST_SUMMARY: FAIL (1 failures)`. Plain ASCII `-` and `--` replaced those glyphs; the exact two-suite rerun exited **0** with `TEST_SUMMARY: PASS (0 failures)`.
- Regressions cover larger and smaller FLAT, INCREASED, REDUCED, MORE, and LESS raw rolls, accessible wording, raw direction, neutral semantic direction, and neutral tooltip color.

## Accepted verification commands and results

All normal worktree runs were sequential and used isolated Task 10O `APPDATA` / `LOCALAPPDATA` roots beneath `.superpowers\sdd`.

```powershell
& $godot --headless --editor --path . --import --quit-after 1800
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/support/task10m_empty_runner_probe.ps1 -GodotPath $godot
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
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 36000 --script res://tests/test_runner.gd
& $godot --headless --path . --quit-after 1800
```

| Gate | Exit / duration | Exact accepted evidence |
| --- | --- | --- |
| Isolated authoritative import | `0` / **17.366s** | import completed; structural/shutdown scan clean |
| Task 10M empty-runner probe | `0` / **1.640s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Widened 32-suite matrix | `0` / **91.044s** | `TEST_SUMMARY: PASS (0 failures)`; sandbox SHA `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe`; boot and selection markers |
| 24-member equipment/cache | `0` / **1.603s** | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1660`; `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| 24-member progression | `0` / **15.056s** | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Isolated startup | `0` / **14.374s** | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once; shutdown scan clean |

The first hardened complete run was an accepted late RED: exit **1** in **129.668s**, `TEST_SUMMARY: FAIL (2 failures)`, for the two contract-aligned fixture updates described above. Their focused rerun passed in **4.043s**. The resulting full rerun exited **0** in **127.892s** with `TEST_SUMMARY: PASS (166 suites)`. After the ASCII-only comparison correction and functional commit, the complete hardened runner was rerun again on exact head **69bec9790a94264ca431731a2c02f61604c6c8c9**: exit **0**, tool wall time **128.5s**, exactly one `TEST_SUMMARY: PASS (166 suites)`. Its 98,074-byte log contained zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker.

The progression runner retains the established five parent/child notice sets: three dummy mesh RIDs, 130 ObjectDB instances, 114 resources, and medium/small PagedAllocator notices per process. The hardened 166-suite release gate and startup were shutdown-clean.

## Fresh cold generator proof

A tracked-only cold copy was built from the exact working content and imported using fresh isolated settings:

```powershell
& $godot --headless --editor --path $cold --import --quit-after 1800
& $godot --headless --path $cold --quit-after 600 --script res://tools/migrate_class_expansion_data.gd
$env:PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT = $worktree
& $godot --headless --path $cold --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_increment2_generator_parity.gd
```

- Cold import: exit **0**, **40.801s**, structural/shutdown scan clean.
- Class-expansion generator: expected exit **1**, **1.057s**, with **35** known unrelated starter-loadout weight/tag capability diagnostics. It still wrote the regenerated class resources before validation.
- Regenerated cold Warlock capability tags were exactly `chaos`, `life_steal`, and `projectile`; no `ranged` tag remained.
- Cold canonical parity suite: exit **0**, **0.454s**, `TEST_SUMMARY: PASS (0 failures)`. It proves both the generator row and canonical resource remain caster-only; the widened actual-catalog gate separately proves canonical equipment tags remain intact.

## Evidence integrity and hygiene

The first inline cleanup command was rejected by command policy before execution and changed nothing. A reviewable exact-path helper then validated and removed **25 top-level Task 10O targets / 4,352 files / 85,951,089 logical bytes**. Every target was beneath this worktree's `.superpowers\sdd`, with zero tracked descendants and zero reparse points. Later exact-head settings/log roots were removed under the same checks; final Task 10O residue was zero, and temporary cleanup helpers were deleted.

The accepted import created the same eight allowlisted generated sidecars as Task 10N. Their exact lengths and SHA-256 values were checked before removal; only those eight were deleted. The protected manifest returned to exactly **127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`**.

At functional commit **69bec9790a94264ca431731a2c02f61604c6c8c9**, tracked and index diffs were empty apart from the forthcoming evidence files. The functional commit changes 16 intentional files; under `data/`, only `data/classes/warlock.tres` changed, and only by removing `ranged`. `git diff --check` passed. No worktree-targeting Godot process remained. The authoritative main checkout was still at its captured head with the same two pre-existing tracked overlays and was not integrated.

## Remaining limitations

- Physical-controller acceptance remains deferred.
- Visible GPU-backed/pixel-level manual review remains deferred.
- The class-expansion generator still exits nonzero on 35 pre-existing starter-loadout capability/tag diagnostics unrelated to the Warlock archetype correction; the affected Warlock output and canonical parity are proven separately.
- This task does not integrate the feature branch into main.
