# Developer Loot Lab verification — 2026-08-10

## Scope and revision

- Branch: `feat/developer-loot-lab`
- Review base: `262312ef4f2d41086d1c3505beac435d6ecfcedb`
- Verified feature revision before this document: `cf064eab705448f2adc3b51380c94b3c5227f40e`
- Godot: `4.7.1.stable.mono.official.a13da4feb`
- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\developer-loot-lab`

## Protected-state inventory

- Main checkout retained exactly 135 untracked `.gd.uid` paths. Manifest digest at audit: `5E0353CE175F42E0DCDE147FEAF74E4EB07D275B5BB1BF6032D2E468237A8F6E`.
- Final feature worktree retained 185 untracked `.gd.uid` paths: the 135 established paths plus 50 feature script/test/tool sidecars. Final manifest digest: `E970DB866F664C9EB8560DD6B14D28ED65231083AD4E7EB2F02177866E60A62F`.
- UID contents generated independently in the feature worktree are not assumed to match the main checkout. No UID was staged, deleted, or normalized.
- No task Godot editor/game process remained after verification. Existing `godot-ai` helper processes were left untouched.
- The two timed-out statistical console runs left exact task child processes behind. PIDs `38024`, `40360`, `18412`, and `40736` were verified as this Godot installation and stopped before the clean single-process rerun; zero remained.
- Startup data was isolated beneath `.superpowers/sdd/loot-lab-startup/run-1786418530652/` through task-local `APPDATA` and `LOCALAPPDATA`.

## Automated verification evidence

| Gate | Result | Duration / evidence |
|---|---|---|
| Cold headless editor import | PASS, exit 0 | 9.4 s; registered `LootLabSessionController`, `LootLabAnalysisView`, `DeveloperLootLab`, and related classes with no parse/load failure |
| 15-suite Loot Lab core/UI focused run | PASS, exit 0 | 98.7 s; `TEST_SUMMARY: PASS (0 failures)`; sandbox SHA-256 `35bd3dc201d295ce5f78a36586f650c4fefbd0873474844a58297a9da1a8a647` |
| Loot Lab real-input/responsive integration | PASS, exit 0 | 8.3 s; `DEVELOPER_LOOT_LAB_INPUT_PASS`, `DEVELOPER_LOOT_LAB_RESPONSIVE_PASS`, and `DEVELOPER_LOOT_LAB_SUMMARY: PASS` |
| Retained developer sandbox integration | PASS, exit 0 | 18.7 s; 1080p, 1440p, 4K, and controller markers; `ITEM_SANDBOX_UI_SUMMARY: PASS` |
| Tooltip controller input | PASS, exit 0 | 0.6 s; `ITEM_TOOLTIP_INPUT_SUMMARY: PASS` |
| Tooltip responsive layout | PASS, exit 0 | 3.5 s; 720p compatibility plus 1080p/1440p/4K markers. Runner retained its pre-existing two ObjectDB/one resource exit warning after the PASS marker. |
| Production weighted-loot evidence rebuild | PASS, exit 0 | 664.7 s; 82 scenarios, 164,000 attempts, 164,000 unique IDs; JSON SHA-256 `67fae56aa1c53a4fa886612e7747ee8eae588fbaf6149898e6e65f2ab67a8a9d`; Markdown SHA-256 `054cbd87290b555dc9f52a20b07d7d89915142869567a9eae6b841b5580f2cdd` |
| Complete project suite | PASS, exit 0 | 199.1 s; `TEST_SUMMARY: PASS (186 suites)` |
| Isolated project startup | PASS, exit 0 | 2.9 s; exactly one `PARTY_FORGE_BOOT_OK` and one `PARTY_FORGE_CLASS_SELECTION_READY` |
| Repository diff check | PASS | `git diff --check 262312e..cf064ea` emitted no whitespace errors |

The first complete-suite attempt failed with 24 Developer Quick Start/City route assertions because those fixtures injected settings without persisting them. Task 12 deliberately made `Main._on_settings_applied()` reload the authoritative store. The fixtures were changed to save through `PartyForgeSettingsStore` first, their three focused suites passed, and the fresh complete suite then passed all 186 suites.

The production evidence rebuild first hit 120-second and 300-second shell ceilings. Those attempts produced no verdict and were not counted as passes. After terminating only their verified leftover task processes, the unchanged runner completed once in isolation with the PASS hashes recorded above.

## Coverage audit

- Sandbox schema 1-to-2 migration preserves the 99 fixtures and initializes `next_generated_item_sequence`.
- Unified create/move/swap journal replay uses `sandbox-transaction-*`; legacy move identifiers remain readable during migration.
- Issuance failures for invalid previews, full containers, projection rejection, and atomic-save failure preserve in-memory state and persisted bytes.
- Batch work is bounded to 256 attempts and 4,000 microseconds per frame; 100,000 attempts require confirmation and active work is cancellable.
- Reports retain at most 100 samples and 20 diagnostic examples per category. Completed and cancelled-partial reports remain independently selectable and export through the pure JSON/Markdown service.
- The integration runner checks the player-profile recursive manifest before and after generation, issuance, scrolling, and cancellation.
- Controller mappings use device `-1`: LB/RB tabs, D-pad focus navigation, south-face actions, east-face cancellation, and right-stick pane scrolling.
- Responsive checks cover horizontal three-pane Workbench layouts at 1080p/1440p/4K, 4/6/8 sample columns, and compact one-pane selectors at 960x540.
- Persisted Player Mode cancels, clears, and closes the developer surface, retains no hidden report selection, and preserves profile bytes.

## Manual and review status

- Automated SubViewport input uses parsed joypad events, not a physical controller. A physical-controller smoke test remains deferred.
- The visual developer playtest (normal/advanced/compare tooltips, manual exports, representative equip/stat projection, and 1080p/1440p/4K visual inspection) remains deferred because no Godot editor session was connected to this feature worktree during final verification.
- An inline revision audit found no critical or important defect across deterministic evidence, migration/replay, atomicity, bounded retention, profile isolation, focus, and responsive layout. It is not an independent reviewer; independent review remains an integration gate because this execution was explicitly kept on the no-subagent path.

## Reproduction commands

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --editor --quit-after 600
& $godot --headless --path . --quit-after 2400 --script res://tests/focused_test_runner.gd -- tests/unit/test_loot_lab_batch_spec.gd tests/unit/test_item_generation_eligibility.gd tests/unit/test_item_generation_analysis.gd tests/unit/test_loot_lab_report_accumulator.gd tests/unit/test_loot_lab_report_export_service.gd tests/unit/test_loot_lab_batch_job.gd tests/unit/test_loot_lab_session_controller.gd tests/unit/test_developer_loot_lab_preferences_store.gd tests/unit/test_developer_loot_lab_item_issuer.gd tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_loot_lab_request_form.gd tests/unit/test_loot_lab_analysis_view.gd tests/unit/test_developer_loot_lab.gd tests/unit/test_developer_item_sandbox.gd tests/unit/test_item_generation_balance_report.gd
& $godot --headless --path . --quit-after 2400 --script res://tests/integration/developer_loot_lab_runner.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/developer_item_sandbox_runner.gd
& $godot --headless --path . --script res://tests/integration/weighted_loot_balance_evidence_runner.gd
& $godot --headless --path . --quit-after 3600 --script res://tests/test_runner.gd
```
