# Frost Mage Recruitment Characterization

Status: NO CURRENT FROST-SPECIFIC CRASH REPRODUCED; EXISTING GENERAL RECRUITMENT FIX VERIFIED; ONE INDEPENDENT NONDETERMINISTIC UNIT-HARNESS DEFECT ISOLATED

## Scope and source state

- Repository: `F:\Projects(root)\Game dev\Projects\party-forge`
- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\frost-mage-recruitment-crash`
- Branch: `fix/frost-mage-recruitment-crash`
- Investigated source HEAD: `ca7f64c3ef4bb9eaef90096468f4fe6a0a1ad571`
- `main` and `origin/main` were both `ca7f64c3ef4bb9eaef90096468f4fe6a0a1ad571` at the investigation gate.
- The worktree began with no tracked/index changes and exactly 68 preserved untracked `.gd.uid` sidecars.
- Art, models, class-card containment, RNG production behavior, Combat HUD feature work, and assets were excluded.

Current main already contains `aad6bcfe425793dd4ac612141f4ab151db9471cf` (`fix: stabilize recruitment HUD binding`). That commit is an ancestor of the investigated HEAD and owns the general deferred HUD refresh, safe freed-focus check, Frost recruitment regression, and error capture support. No Frost-specific production branch exists in that repair.

## Preserved pre-restart evidence

All commands used Godot `C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`, `--path` set to the exact worktree above, and the APPDATA/LOCALAPPDATA/USERPROFILE root named by each log directory.

| Order | Invocation after `--path <worktree>` | Result | Log SHA-256 |
|---|---|---|---|
| 1 | `--headless --editor --import --quit` | exit 0; cold import completed | `d138f48314e48c701e5484b2ffae16839f649def8d0a7e1abee41a584b5ae0d2` |
| 2 | `--headless --quit-after 1200 --script res://tests/integration/level_up_commit_flow_runner.gd` | exit 0; `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)` | `2d11bbee8f2a11831f530810e14cbaeb19be2e0b3122d0934fe26f04c8220ae4` |
| 3 | `--headless --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_manager.gd tests/unit/test_party_actor_spawner.gd tests/unit/test_player_run_context.gd tests/unit/test_combat_hud.gd tests/unit/test_main_wiring.gd tests/unit/test_game_catalog.gd tests/unit/test_expanded_class_content.gd tests/unit/test_expanded_catalog.gd tests/unit/test_caster_equipment_content.gd tests/unit/test_playable_class_presentations.gd` | exit 1; four queued-level assertions failed only in `test_main_wiring.gd` | `174b139407d4ad159147735d9929e4b8e51f0c276a36367dfb4c35af996c5521` |
| 4 | `--headless --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd` | exit 0; `TEST_SUMMARY: PASS (0 failures)` | `4e3187a28e30f4dd2e27bc8b551f011eec464c00b95952ff6fbf124eb80124e5` |
| 5 | `--headless --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_manager.gd tests/unit/test_party_actor_spawner.gd tests/unit/test_player_run_context.gd tests/unit/test_combat_hud.gd tests/unit/test_game_catalog.gd tests/unit/test_expanded_class_content.gd tests/unit/test_expanded_catalog.gd tests/unit/test_caster_equipment_content.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_run_recovery_service.gd` | exit 0; `TEST_SUMMARY: PASS (0 failures)` | `be6206c2063f78d603239ac06a517ad350898334a43956e72ef1f0b6b1274f5e` |

The corresponding files retain lengths and UTC write times:

- `baseline-cold-import.log`: 224940 bytes; `2026-09-01T16:14:05.3662960Z`
- `level-up-commit-flow-current.log`: 264 bytes; `2026-09-01T16:17:03.6253033Z`
- `frost-focused-current.log`: 26771 bytes; `2026-09-01T16:19:02.5818561Z`
- `main-wiring-alone.log`: 7260 bytes; `2026-09-01T16:20:43.3762423Z`
- `supporting-focused.log`: 30020 bytes; `2026-09-01T16:21:32.6539549Z`

## Combined-only failure isolation

The four failures were:

1. second production confirmation expected pending `1 -> 0`, got `1`;
2. expected the pending queue to become `[]`, got `[3]`;
3. expected the run to resume after the second confirmation, but it remained in level-up;
4. expected the tree to resume after the final confirmation, but it remained paused.

Minimal order characterization produced these results:

| Invocation order before `test_main_wiring.gd` | Result | Log SHA-256 |
|---|---|---|
| `test_party_manager.gd`, `test_party_actor_spawner.gd` | PASS, exit 0 | `17577c4d2298619cfa372ae01dbfdaa7dc1c7f90327cfc5b689a294a5139ff7d` |
| `test_player_run_context.gd`, `test_combat_hud.gd` | PASS, exit 0 | `f02c1a676bef8a1cd0c80c49c8aa18ba81cbda363980d7df2daf20e53bda8f4d` |
| all four predecessors in the original order | PASS, exit 0 | `2188672470d74ef85193b42f9a8d3148786f3d636ae3dbca14e46457e2826bcf` |

The original failure is therefore not a stable cross-suite singleton leak and does not reach the Frost recruitment path. A temporary read-only seed enumerator then reproduced the exact failed queue shape deterministically:

`QUEUED_LEVEL_SEED_CHARACTERIZATION_FOUND seed=14 first=0:mage second=4:projectile_mastery leader=1 eligible=[2] party_size=2`

The clean diagnostic process exited 0. Its log is 881 bytes, UTC `2026-09-01T16:33:00.3228970Z`, SHA-256 `eec664128fbad890dc1a99c9304fcbced7cce9222b32e596c74ac49f7d8d9ac7`.

Root cause: `_test_queued_levels_show_fresh_production_offers()` starts a normal run through `_started_main()`, so it now receives a fresh random run seed. Its `_submit_bound_offer()` helper always chooses the leader for a recipient-confirmation card. Seed 14 recruits Mage in the first slot, then places `projectile_mastery` in the second slot; that upgrade is valid for party member 2 but not leader member 1. The rejected leader application correctly leaves pending level 3 queued. This is an independently proven test determinism/recipient-selection defect introduced at the test boundary, not a product queue defect and not a Frost crash. It remains excluded from this recruitment checkpoint.

## Historical recruitment root cause

Historical log `C:\Users\Jacob\AppData\Local\Temp\party-forge-review-batch-1\00-baseline-full-suite.log` is 103971 bytes, UTC `2026-08-31T07:22:50.1516903Z`, SHA-256 `27cb003dfe4b85111305238c05cb3c98bb4915283f3161d1573dde91972bf2b0`.

Its real recruitment trace is:

`PartyManager.recruit()` -> `_invalidate_all_members()` -> `PartyActor._on_stats_changed()` -> `_refresh_runtime_stats()` -> `HealthComponent.set_max_health()` -> `HUD._on_health_changed()` -> `HUD._refresh_projection()` -> `COMBAT_HUD_UNAVAILABLE reason=member health is unavailable`.

The party member existed before `PartyActorSpawner` completed `PlayerRunContext.bind_actor()` and emitted `actor_bound`. Commit `aad6bcfe` fixes this general ordering window by deferring HUD projection while a party actor is unbound and refreshing after binding. It also validates `_gameplay_return_focus` before any type check or access.

## Saved/bootstrap boundary

`ResumableRunItemCodec.FIELDS` is exactly `item_state`, `leader_member_id`, `run_id`, `run_player_id`, `run_seed`, and `selected_leader_class_id`. It does not persist recruited party members, actor weak references, health-component bindings, HUD projection state, or focus controls. The historical stack originates directly in live `PartyManager.recruit()` signal ordering, not profile/bootstrap decoding. Recovery/loadout suites passed in the supporting gate, so no older saved/bootstrap trigger was found.

## Exact current owning-path characterization

`tests/integration/frost_recruitment_characterization_runner.gd` now performs the smallest symmetric real-path comparison. It creates separate otherwise identical production `Main` fixtures for Ranger and Frost Mage, starts a Fighter-led run, presents one explicit recruit through `LevelUpPanel`, confirms through Main's real transaction, and asserts for both classes:

- exact party membership commit;
- zero captured engine errors and zero captured script errors;
- no transient `COMBAT_HUD_UNAVAILABLE`;
- bound companion actor and positive bound health maximum;
- valid gameplay-focus restoration;
- closed level-up modal and resumed running state.

Fresh verification commands and evidence:

```powershell
& $godot --headless --path $worktree --quit-after 1200 --script res://tests/integration/frost_recruitment_characterization_runner.gd
& $godot --headless --path $worktree --quit-after 1200 --script res://tests/integration/level_up_commit_flow_runner.gd
```

- Characterization: exit 0; `FROST_RECRUITMENT_CHARACTERIZATION_SUMMARY: PASS (0 failures)`; log SHA-256 `eca7e33d5a72cc4f86060acf7115a04c4404216e35cb4d94ef3ff1138e5737c5`.
- Existing owning runner: exit 0; `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)`; log SHA-256 `2d11bbee8f2a11831f530810e14cbaeb19be2e0b3122d0934fe26f04c8220ae4`.

## Verdict and remaining work

- Exact main does not reproduce a Frost Mage recruitment crash.
- No production repair is justified or included.
- The existing general recruitment fix remains verified.
- This checkpoint adds only deterministic Ranger-versus-Frost owning-path characterization and this report.
- The seed-dependent `test_main_wiring.gd` helper defect is independently reproducible and should be assigned to a separate test-isolation/RNG lane; it must not be described as recruitment failure evidence.
