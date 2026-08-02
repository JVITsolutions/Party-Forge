# Profile Persistence Foundation Verification

Date: 2026-08-01

Milestone state: `PASS`

This record covers the profile-persistence foundation through commit `8a7b5ee2edbef1c8f31b94efc126126a89a76835`. Automated and controller manual verification are recorded below.

## Task commit ranges

| Task | Inclusive commit range | Commits |
| --- | --- | --- |
| 1 - Versioned profile state | `0e5786a82556263ffb803e29927f6d431249a1bc^..0e5786a82556263ffb803e29927f6d431249a1bc` | `0e5786a82556263ffb803e29927f6d431249a1bc` - `feat: add versioned profile state` |
| 2 - Atomic profile persistence and recovery | `4232e4e422ee6760363cb6b8ecd38162c560b017^..ca7e7519de9d19905a3847a800e82fe216ce1994` | `4232e4e422ee6760363cb6b8ecd38162c560b017` - `feat: persist profiles atomically`; `ca7e7519de9d19905a3847a800e82fe216ce1994` - `fix: harden atomic profile recovery` |
| 3 - Local profile management | `8b42385f0ae956e3ba41f4d1d9edcf6585e2441b^..9d62768e9554eec4f0077892b8c1b27df391f76e` | `8b42385f0ae956e3ba41f4d1d9edcf6585e2441b` - `feat: manage local player profiles`; `9d62768e9554eec4f0077892b8c1b27df391f76e` - `fix: roll back failed profile operations` |
| 4 - Idempotent profile mutations | `68bf940591b003a45c9cbbedaafa68658b183f87^..18d71dc566cdd62f8e18faad03a988c41cc9e9ba` | `68bf940591b003a45c9cbbedaafa68658b183f87` - `feat: add idempotent profile mutations`; `18d71dc566cdd62f8e18faad03a988c41cc9e9ba` - `fix: protect profile mutation metadata` |
| 5 - Profiles Settings UI | `3b8a84286079894937b48fd54c275965a8ad0981^..bc0a5ba75e2508966966c53a8b9dc297b8b27220` | `3b8a84286079894937b48fd54c275965a8ad0981` - `feat: add profile management settings`; `bc0a5ba75e2508966966c53a8b9dc297b8b27220` - `fix: preserve profile settings navigation` |
| 6 - Active-profile boot and run gate | `3dbca477f5c42ece37207b9ad24acf86cc64e59c^..8a7b5ee2edbef1c8f31b94efc126126a89a76835` | `3dbca477f5c42ece37207b9ad24acf86cc64e59c` - `feat: require an active profile for runs`; `8a7b5ee2edbef1c8f31b94efc126126a89a76835` - `test: retain profile boot main flow` |

The intervening commits `56c7410cd4508e386f6715dd56a1e99cdcfb7510` (`fix: sort damage tags deterministically`) and `03d1f25c33e3f76763aee67c12cbcba0bd0ccfb2` (`docs: align profile index with Godot JSON`) are present in branch history but are not attributed to the Task 1-6 implementation ranges above.

## Automated evidence

All Godot commands used `Godot_v4.7.1-stable_mono_win64_console.exe`, the isolated feature worktree, and a fresh task-specific `APPDATA` root under `.superpowers/sdd/`. No command used the live Party Forge settings or profile directory.

| Gate | Exit | Exact accepted summary or marker | Forbidden markers | Residual `user://tests/profile_*` roots | Raw log |
| --- | ---: | --- | ---: | ---: | --- |
| Clean editor import/parser check | 0 | `[ DONE ] first_scan_filesystem`; 0 `SCRIPT ERROR`/`Parse Error` markers | 0 | N/A | `.superpowers/sdd/task-7-import-rerun.log` |
| Complete suite, accepted run A | 0 | `TEST_SUMMARY: PASS (78 suites)` | 0 `SCRIPT ERROR`/`TEST_FAILURE` | 0 | `.superpowers/sdd/task-7-full-2.log` |
| Complete suite, accepted run B | 0 | `TEST_SUMMARY: PASS (78 suites)` | 0 `SCRIPT ERROR`/`TEST_FAILURE` | 0 | `.superpowers/sdd/task-7-full-3.log` |
| Retained profile boot/main flow | 0 | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` | 0 runner failure/script markers | 0 | `.superpowers/sdd/task-7-profile-boot-main-flow.log` |
| Retained Settings Profiles navigation | 0 | `PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS` | 0 runner failure/script markers | 0 | `.superpowers/sdd/task-7-settings-profiles-navigation.log` |
| Retained responsive geometry | 0 | `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` | 0 runner failure/script markers | 0 | `.superpowers/sdd/task-7-responsive-ui-geometry.log` |
| Focused recovery/idempotency runner | 0 | `TASK7_PROFILE_FOCUSED_SUMMARY: PASS (3 suites)` | 0 `SCRIPT ERROR`/`TASK7_PROFILE_FOCUSED_FAILURE` | 0 | `.superpowers/sdd/task-7-profile-focused.log` |

The focused runner recorded individual PASS markers for:

- `res://tests/unit/test_atomic_profile_store.gd`
- `res://tests/unit/test_profile_manager.gd`
- `res://tests/unit/test_profile_mutation_service.gd`

Its APPDATA root was `.superpowers/sdd/task-7-profile-focused-appdata`. The two accepted complete-suite roots were `.superpowers/sdd/task-7-full-2-appdata` and `.superpowers/sdd/task-7-full-3-appdata`. Each root was fresh before launch and contained zero `user://tests/profile_*` directories after its process exited.

## Intentional diagnostics

The focused recovery suite intentionally emitted `JSON_STORE_CORRUPT_PRIMARY_PRESERVED` twice while exercising corrupt-primary recovery and failed-promotion recovery. The diagnostic paths were inside the disposable root `user://tests/profile_store_53068_209666/` and named the preserved `profile-corrupt1.json.corrupt-1785626841` and `profile-corrupt2.json.corrupt-1785626841` artifacts. The suite subsequently removed its exact root and exited 0.

The focused manager suite intentionally exercised a nested-path filesystem failure under its disposable `user://tests/profile_manager_*` root. The responsive runner intentionally exercised `PARTY_FORGE_SETTINGS_SAVE_ERROR ... stage=promote` negative paths. The complete suite retains its established negative-path `push_error` diagnostics and shutdown leak/resource warnings; neither accepted log contains `SCRIPT ERROR` or `TEST_FAILURE`, and both commands exited 0.

## Manual approval matrix

| # | Manual validation | Result | Evidence |
| ---: | --- | --- | --- |
| 1 | Launch with no profiles; a run attempt opens Profiles Settings. | `PASS` | A live Godot run under fresh isolated APPDATA opened Settings directly on Profiles with `Create a profile to begin playing.` No profile was active, and the class screen remained blocked behind the overlay. |
| 2 | Create `Jacob`; it becomes active and persists after restart. | `PASS` | Created `Jacob` through the live Profiles UI; the list showed `Jacob [Active]`. After stopping and restarting with the same isolated APPDATA, the game booted to `Choose Your Leader`. The profile JSON recorded `display_name` as `Jacob` and `gold` as 0. |
| 3 | Create `Guest`; switch between both profiles. | `PASS` | Created `Guest`; the list showed `Guest [Active]` and `Jacob`. Selected and activated Jacob; the list then showed `Jacob [Active]`. |
| 4 | Reject duplicate `jacob` without changing either profile. | `PASS` | Entering lowercase `jacob` produced the exact live status `That profile name already exists. Choose another name.` Exactly two valid profile JSON files remained. |
| 5 | Start Fighter and complete at least one ordinary arena interaction. | `PASS` | Selected Fighter in the live UI. The arena reached 00:08 with Fighter Rank 1 and active enemy combat. Selected Vanguard Wall and Confirm for a normal level-up; the run returned to `RUNNING`, pending levels were 0, and the panel was hidden. |
| 6 | Enable Developer Mode; verify it creates no profile unlocks or gold. | `PASS` | Enabled and applied Developer Mode; isolated `party_forge_settings.cfg` recorded `mode=1`. Re-reading Jacob and Guest showed `gold=0`, zero milestones, zero permanent feature unlocks, zero owned characters, and zero run history for both profiles. |
| 7 | After two disposable saves, corrupt only the primary; recover the previous generation and preserve the corrupt primary for diagnosis. | `PASS` | After two saves to isolated Jacob, only the primary was corrupted. Load returned `ok=true`, `recovered_from_backup=true`, and `gold=0`. Saving preserved `profile-b06c7dc014f324f2ccdf7a850550209a.json.corrupt-1785628235`, restored a valid primary, retained `.bak`, and the final load returned `ok=true`. The live log named the preserved artifact in an intentional `JSON_STORE_CORRUPT_PRIMARY_PRESERVED` warning. |
| 8 | Verify keyboard/mouse and controller focus through all six Settings tabs at 1920x1080, 2560x1440, and 3840x2160. | `PASS` (hybrid live and retained exact-resolution evidence) | At live 4K, mouse input opened all six tabs in order with titles Game Settings, Controls, Graphics, Audio, Profiles, and Additional Settings. Simulated controller RB (joy button 10) cycled all six, focused page-specific controls, and wrapped to Game Settings. `PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS` retains the keyboard/controller navigation contract. `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` supplies geometry/focus evidence at 1920x1080, 2560x1440, and 3840x2160. The 1080p/1440p assurance is retained-runner evidence; live visual/input validation was at 4K. |

## Scope and preservation checks

- Starting state: clean linked worktree on `feat/profile-persistence-foundation` at `8a7b5ee2edbef1c8f31b94efc126126a89a76835`.
- `scenes/game/main.tscn` was not modified in this worktree. Its working and HEAD Git object hashes are both `775bd86ed4ed6441de8a03754111edbf28070c95`.
- `assets/ui/currency/` has no Task 7 change in this worktree.
- The main checkout was used only for read-only status checks. Task 7 issued no write there and did not overwrite its modified `scenes/game/main.tscn` or its eight untracked currency `.import` files.
- A separate untracked plan file seen in the main checkout at Task 7 start disappeared from main-checkout status during automated verification because of concurrent activity outside this worktree. Task 7 did not target or remove that file; this prevents a truthful claim that the entire external main-checkout status remained byte-for-byte identical.
- The automated editor import generated 40 untracked `.uid` sidecars in this isolated worktree, and the controller's manual editor session later regenerated 40 exact worktree-contained `.uid` paths. The generated files were validated and removed after each phase; the final untracked UID count is 0.
- No production code or committed test was changed by Task 7.
- `git diff --check` exited 0 before this document was created.

## Finalization checks

The controller quit the Godot editor after manual validation. Immediately before staging the evidence-only commit, `git status --short` contained only:

```text
?? docs/verification/
```

## Post-review corrective verification

The independent senior review identified four Important persistence issues. Focused test-first corrections now cover strict schema-v1 JSON typing and nested shapes, verified-promotion commit semantics, fingerprinted idempotency records with stable committed results, and structured healthy/recovered/damaged profile disclosure in Settings.

- RED: `.superpowers/sdd/task-8-profile-fixes-red3.log` exited 1 with `TASK8_PROFILE_FIX_SUMMARY: FAIL (37 failures)` before production changes.
- Profile-health UI RED: `.superpowers/sdd/task-8-profile-health-ui-red.log` exited 1 with `TASK8_PROFILE_FIX_SUMMARY: FAIL (6 failures)` before profile-status/UI production changes.
- Focused GREEN: `.superpowers/sdd/task-8-profile-fixes-green2.log` exited 0 with `TASK8_PROFILE_FIX_SUMMARY: PASS (7 suites)`.
- Retained integration GREEN: `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`, `PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS`, and `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` in the corresponding `task-8-*.log` files.

The earlier `DamageResolver` `StringName` sorting fix remains intentionally in this branch. Its pre-fix evidence showed `tags.sort()` returning `[physical, melee]` where deterministic string order required `[melee, physical]`; `.superpowers/sdd/damage-tag-order-green.log` recorded `DAMAGE_TAG_ORDER_FOCUSED: PASS`. `tests/unit/test_damage_resolver.gd` now retains a focused multi-tag lexicographic regression assertion.
