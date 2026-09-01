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

## Review disposition and fail-closed TDD correction

Fresh sequential review of candidate `b717a582504c02c6c67765a2735ec9680cf91bc5` first produced a requirements PASS with no findings, then a distinct code-quality FAIL with one Important finding. The quality reviewer verified that the runner recorded the exact-class failure safely at the original line 60, but the original line 62 still indexed `party.members[1]` after logger detachment. A short-party regression could therefore emit an uncaptured script error and skip the fixture cleanup at the end of `_exercise_recruitment()`.

The original candidate remains immutable in Git. Its two blob and worktree identities before the correction were:

| Path | Git blob | SHA-256 |
|---|---|---|
| `tests/integration/frost_recruitment_characterization_runner.gd` | `fbb8b7f2d51c7e7e9ce0c5e1eff83b6fef3041d4` | `63cbf9d332e01c2cbb0758d6bd5df40ed2bc217650311fe1ab6ea8aaaa3decda` |
| `docs/verification/2026-09-01-frost-mage-recruitment-characterization.md` | `44f6cf9118afae13155091c1591a343609ab1139` | `e9fc6d45d1766693d0c98c0734679142ebb013d522c923fabbb4ad5c8e9fe7b6` |

Studio Lead accepted the finding and authorized the smallest same-scope test-only correction. The runner retains a dormant process-environment probe named `PF_FROST_CHARACTERIZATION_FORCE_SHORT_PARTY`. When its value is exactly `1`, only the Frost fixture truncates the party immediately before the exact-class assertion. Normal runs do not enter the probe. The correction resolves member 1 only when the party contains at least two members, retains the exact size-and-class assertion, performs the dependent actor/health assertions whenever that member exists, and reaches the existing single cleanup block on the short-party path.

Every correction run used only `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`, isolated per-process `APPDATA`, `LOCALAPPDATA`, and `USERPROFILE` roots, and a process-only probe variable. Durable evidence is under `C:\Users\Jacob\.codex\visualizations\2026\09\01\01a05e97-79c8-7c53-ab4c-c21da9425be5\frost-publication-evidence`.

| Gate | Native result and exact markers | Diagnostics and cleanup | stdout / stderr SHA-256 |
|---|---|---|---|
| Pre-guard probe RED | exit 1; one `FROST_RECRUITMENT_CHARACTERIZATION_PROBE: SHORT_PARTY`; one `FROST_RECRUITMENT_CHARACTERIZATION_SUMMARY: FAIL (1 failures)`; one intended exact-class failure | one exact `SCRIPT ERROR: Out of bounds get index '1'`; one residual Frost fixture leaf; process exited; parent probe variable absent before and after | `4de87c17761e23f107cc3a3b4942f6398a0ed672a86011c43b21f91db2892414` / `b9c576bcd7c3462a11fc8f679f622cab1494d9bef83894bea3350d77b8d76a87` |
| Guarded probe GREEN | controlled exit 1; the same one probe marker, one FAIL summary, and one intended exact-class failure | zero script/parser/loader/crash diagnostics; zero residual fixture leaves; process exited; parent probe variable absent before and after | `4de87c17761e23f107cc3a3b4942f6398a0ed672a86011c43b21f91db2892414` / `16e6fec01146b54b6450d285ed8ff9223cbb347d92ca5efbe899832f5619a5b8` |
| Normal characterization GREEN | exit 0; exactly one `FROST_RECRUITMENT_CHARACTERIZATION_SUMMARY: PASS (0 failures)`; zero probe/failure markers | zero script/parser/loader/crash diagnostics; zero residual fixture leaves; process exited; parent probe variable absent before and after | `a7d5d14d825c33486e8d2edd482eecc2c283b0b69366e71991b0f352d5bbee2f` / `d99bd6b8dfd6d7f02f68943a1852a25494e6adc0e39af8e51df6a344c6901f11` |

The RED refined one part of the review risk without invalidating the finding: Godot returned control to the awaiting caller and printed the terminal FAIL summary, so the observed defect was the uncaptured out-of-bounds script error plus skipped Frost fixture cleanup, not a missing terminal summary.

## Post-correction verification

The owning and affected gates then ran in the Frost worktree with the probe absent:

| Gate | Result | stdout / stderr SHA-256 |
|---|---|---|
| Level-up commit flow | exit 0; exactly one `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)`; zero failure/script/parser/loader/crash diagnostics | `e0fa05666842da5e9f666f9b5f818991d2ef1b3f3de943b9dbafe217a1ac370a` / `d99bd6b8dfd6d7f02f68943a1852a25494e6adc0e39af8e51df6a344c6901f11` |
| Twelve-suite recruitment/actor/HUD/main-wiring/catalog/class/presentation/recovery gate | exit 0; exactly one `TEST_SUMMARY: PASS (0 failures)`; zero test/script/parser/loader/crash failures | `824b251ac45c166add348f28a9e51b8e6065c0779b57ad5926e2d9dbf0490a4b` / `4b1d76c80cc9276caded8c8e8bf2ee3a58a0328c6762fd270f6895fcd9b5176c` |
| Git whitespace and scope gate | `git diff --check` exit 0 with zero output; exactly the runner and this document modified; 68 UID sidecars retained with manifest SHA-256 `3aa73e30b352432e214374c85cec6627c2e298b52aecc551d85a7c8884e7ee76` | metadata SHA-256 `26848dc7e3217db9513b6e144fa433678b8d9c8df4743d14c21ded134edb4df1` |

The first complete-suite attempt was rejected as environment-invalid rather than accepted or hidden. The sandbox Windows identity could not read the root certificate store. `test_focused_runner_shutdown_lifecycle.gd` correctly rejected that nested-child `ERROR:` line, producing exit 1, `TEST_SUMMARY: FAIL (2 failures)`, and two `TEST_FAILURE` records. The rejected stdout/stderr hashes are `d6fb5f8425c5d680ca6b912e32c355320fbdddd938b8ff3ed772cfe81ac4c0de` / `5021f9eedebbf0bb3e2497e97c05e511f1b3ae89b6effbf985a53067569c85e5`.

Read-only root-cause isolation then used the same mandated Godot executable under the normal Windows user, without administrator elevation and with isolated `APPDATA`/`LOCALAPPDATA`:

- the exact focused shutdown-lifecycle suite exited 0 in 2.274 seconds with one `TEST_SUMMARY: PASS (0 failures)` and zero error/warning/script/parser/loader/crash lines; stdout/stderr SHA-256 `4883b85b7c2d0b42019ce056282334aae28f0b2e8dc5522afea6476d714296e1` / `7eb70257593da06f682a3ddda54a9d260d4fc514f645237f5ca74b08f8da61a6`;
- the clean 262-suite rerun exited 0 in 371.730 seconds with exactly one `TEST_SUMMARY: PASS (262 suites)`, zero `TEST_FAILURE`, zero script/parser/loader/crash/root-certificate diagnostics, and no process or probe-environment residue; stdout/stderr SHA-256 `89fd9501f77adffaefd4fce6bb5fc6e5736dc7e964e86a6105235c33c9fd19a0` / `abdcacb691c6d6ccea6fe50cc7545e750da2d1726eab632ba1b337f63040d6b1`.

The complete-suite raw diagnostics contain the suite's assertion-owned negative-path emissions and established shutdown notices; none produced a test failure or an unexpected script/parser/loader/crash diagnostic in the accepted run.

## Verdict and remaining work

- Exact main does not reproduce a Frost Mage recruitment crash.
- No production repair is justified or included.
- The existing general recruitment fix remains verified.
- This checkpoint adds only deterministic Ranger-versus-Frost owning-path characterization and this report.
- The seed-dependent `test_main_wiring.gd` helper defect is independently reproducible and should be assigned to a separate test-isolation/RNG lane; it must not be described as recruitment failure evidence.
