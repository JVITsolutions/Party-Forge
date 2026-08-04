# Functional Main Menu Plan 3A Verification

Date: 2026-08-04

Milestone state: `INTEGRATED; POST-MERGE VERIFIED`

Task 9 acceptance and integration are complete. The original automated gate covered implementation head `ce057a949f8f64bfb661aded26dcfec3cdcdb44c` (`fix: support any-controller main menu input`). Direct Godot MCP acceptance then found one modal-focus defect, which was fixed test-first in `2bd4d3e5ffddc16612f1a0e50cb17dead6b05f6f` (`fix: trap quit confirmation focus`). A fresh independent review reported no Critical or Important findings and returned `READY TO INTEGRATE: YES`. Clean authoritative `main` then fast-forwarded from `71a1054` to accepted branch head `dc1a32a`.

## Evidence boundaries

- **Fresh exact-head automation:** isolated headless import, the complete custom suite, headless input/layout integrations, focused run/profile regressions, and repository checks run against exact implementation HEAD `ce057a9`.
- **Scripted real-window renderer evidence:** `main_menu_responsive_runner.gd` drove the real root `Window` through the OpenGL Compatibility renderer, measured the production `canvas_items` scale path, and captured pixels. This is automated renderer evidence, not a person's connected playtest.
- **Godot MCP Windows/controller acceptance:** an isolated Godot 4.7.1 editor ran the actual 3840x2160 game window while the MCP inspected focus/state, injected mouse, keyboard, and synthetic controller events, captured rendered frames, and read editor/game logs. This is direct runtime evidence, but it is not a human holding a physical controller.

All Godot commands used `Godot_v4.7.1-stable_mono_win64_console.exe`, the functional-main-menu worktree, and fresh task-specific roots:

```text
APPDATA=.superpowers/task-9-appdata
LOCALAPPDATA=.superpowers/task-9-localappdata
```

The live user profile/settings location was not used.

The connected acceptance session used `functional-main-menu@dba2` and separate roots under `.superpowers/task-9-godot-mcp-20260804/`. It created only isolated `MCPAlpha` and `MCPBeta` profiles and isolated settings.

## Fresh exact-head automated gate

Raw logs are retained under `.superpowers/sdd/task-9-automation/`.

| Gate | Command | Exit | Accepted evidence |
| --- | --- | ---: | --- |
| Full import | `godot --headless --path . --import` | 0 | zero `SCRIPT ERROR`, `Parse Error`, `ERROR:`, or `No loader found` scan matches |
| Complete suite | `godot --headless --path . --quit-after 300 --script res://tests/test_runner.gd` | 0 | exactly `TEST_SUMMARY: PASS (112 suites)`; zero `TEST_FAILURE`, script, parse, or loader matches |
| Main-menu navigation | `... res://tests/integration/main_menu_navigation_runner.gd` | 0 | `MAIN_MENU_NAVIGATION_SUMMARY: PASS` |
| Profile boot/main flow | `... res://tests/integration/profile_boot_main_flow_runner.gd` | 0 | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` |
| Settings/Profile navigation | `... res://tests/integration/settings_profiles_navigation_runner.gd` | 0 | `PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS` |
| Passive-tree profile | `... res://tests/integration/passive_tree_profile_runner.gd` | 0 | `PASSIVE_TREE_PROFILE_SUMMARY: PASS` |
| Passive-tree input | `... res://tests/integration/passive_tree_input_runner.gd` | 0 | `PASSIVE_TREE_INPUT_SUMMARY: PASS` |
| Passive-tree responsive | `... res://tests/integration/passive_tree_responsive_runner.gd` | 0 | `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)` |
| Existing UI geometry | `... res://tests/integration/responsive_ui_geometry_runner.gd` | 0 | `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` plus run-setup action size markers |
| Locomotion smoke | `... res://tests/integration/character_locomotion_smoke.gd` | 0 | `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 smooth_turn=1 attack_lock=1 equipment_independent=1 grounding=1 shadow=1` |
| Focused run/profile batch | `focused_test_runner.gd -- test_developer_quick_start.gd test_run_pause_menu.gd test_game_run_pause_clock.gd test_controller_movement_bindings.gd test_leader_movement.gd test_combat_sandbox.gd test_main_wiring.gd` | 0 | `TEST_SUMMARY: PASS (0 failures)`; zero failure/parse/loader matches |
| Modal focus regression | `focused_test_runner.gd -- tests/unit/test_run_pause_menu.gd` | 0 | accepted RED was 12 failures before the scene fix; final `TEST_SUMMARY: PASS (0 failures)` |
| Post-fix full import | `godot --headless --path . --import` | 0 | zero `SCRIPT ERROR`, `Parse Error`, `ERROR:`, or `No loader found` matches |
| Post-fix complete suite | `godot --headless --path . --quit-after 300 --script res://tests/test_runner.gd` | 0 | exactly `TEST_SUMMARY: PASS (112 suites)`; zero `TEST_FAILURE`, script, parse, or loader matches |
| Whitespace/path check | `git diff --check` | 0 | no output after the intentional documentation edits |

`rg --files` found no dedicated file named as an arena-smoke runner, run-pause integration runner, or controller-movement integration runner. The gate therefore records the exact existing focused equivalents instead of inventing runner names: `test_combat_sandbox.gd` plus `test_main_wiring.gd` for arena composition, `test_run_pause_menu.gd` plus `test_game_run_pause_clock.gd` for pause behavior, and `test_controller_movement_bindings.gd` plus `test_leader_movement.gd` and `character_locomotion_smoke.gd` for controller/movement coverage. Ordinary rendered arena and pause behavior were subsequently exercised through the connected Godot MCP session.

## Scripted real-window renderer gate

The non-headless command was:

```text
godot --path . --rendering-method gl_compatibility --quit-after 240 --script res://tests/integration/main_menu_responsive_runner.gd
```

It exited 0 with three `MAIN_MENU_RESPONSIVE_SIZE_PASS` markers and `MAIN_MENU_RESPONSIVE_SUMMARY: PASS (3 root-window sizes)`. It proved a 1920x1080 logical canvas at physical sizes/scales 1920x1080/1.000, 2560x1440/1.333, and 3840x2160/2.000. The script also rendered Settings above the menu and the City passive tree above both.

| Captured frame | Bytes | SHA-256 |
| --- | ---: | --- |
| `main-menu-1920x1080.png` | 47,213 | `00E9D8D0C56277914B73FE236E38ED79B410C4998EEBA42472100BD732C23341` |
| `main-menu-2560x1440.png` | 93,439 | `6A4949B28AE1461120FBD4C1FF9DD1686F23E01ED6196434AA3C82F21BE9BA2E` |
| `main-menu-3840x2160.png` | 139,877 | `AD6557FBFB595C55D9710D01CA34E018BBCDA4F92752696EA2641E7FD1AA9E70` |
| `settings-1920x1080.png` | 53,587 | `8F4642631CD46F8DF77C8A0F896866BEACA51BB25D18781179294071BB7715C4` |
| `city-1920x1080.png` | 212,131 | `599547CC966F4C9F22F6D4E46A24E9F8A921A8E3637E81848B20F317B49A18D9` |

These captures are scripted evidence. Task 8 recorded independent visual inspection of the same deterministic frames; Task 9 did not substitute that prior inspection for fresh human manual smoke.

## Developer Quick Start noncontamination reload

The focused batch freshly ran `tests/unit/test_developer_quick_start.gd`. Its success path creates an isolated durable profile containing an in-progress prologue, Passive Points, milestones, permanent unlocks, building/tree discovery, tree allocations/visibility, and an applied transaction. It then launches Quick Start and reloads the profile through `ProfileStore`.

The passing assertions require the reloaded complete profile dictionary, profile bytes, file modification time, recursive profile-root path/content/length/time snapshot, and both profile mutation-signal counts to remain unchanged. They also require the captured `RunRulesSnapshot` to match the saved applied settings. This is fresh automated disk-reload evidence; the controller-driven rendered Quick Start check remains pending.

## Expected diagnostics and known baseline shutdown output

The import emitted 38 `Missing .uid file ... re-created from cache` warnings. Those paths are the established generated-sidecar baseline, not missing tracked Plan 3A UIDs. Import still exited 0 with no parse, loader, or `ERROR:` match; exact cleanup later validated and removed the same 38 generated UIDs together with 591 generated `.import` files.

The full suite intentionally exercises rejected/corrupt/invalid paths. Its direct diagnostic counts were: six `PARTY_FORGE_ATTACK_SEQUENCE_ERROR`, five `PARTY_FORGE_DAMAGE_ERROR`, two `PARTY_FORGE_GOD_MODE_OWNERSHIP_ERROR`, two `PARTY_FORGE_LEDGER_ERROR`, nine `PARTY_FORGE_PRESENTATION_ERROR`, one projectile-presentation error, four profile-required errors, one run-rules error, one feature-access error, two settings-save errors, one settings-version error, one stat error, six upgrade-application errors, three profile-bootstrap errors, three JSON cleanup-debt warnings, one corrupt-primary-preserved warning, and one deliberate directory-creation failure. These are assertions' expected negative paths; the command reached the exact 112-suite PASS marker and exited 0.

The existing responsive geometry runner emitted one deliberate settings-promotion error and the focused main-wiring path emitted one deliberate `PARTY_FORGE_RUN_PROFILE_REQUIRED` diagnostic. Both reached their PASS markers and exited 0.

The full suite retained the known test-harness shutdown diagnostics:

```text
WARNING: 18 ObjectDB instances were leaked at exit
ERROR: 5 resources still in use at exit
```

They are recorded as baseline diagnostics, not relabeled as clean shutdown and not treated as a product runtime pass.

## Changed-file review against Plan 3A

- **Projection and blockout screen:** `main_menu_projection.gd`, `main_menu_view_model.gd`, `main_menu_screen.gd`, `main_menu_screen.tscn`, and their three intended script UIDs provide stable routes, copy-owned values, visible-action focus, accessibility text, and replaceable Plan 3A presentation. UI code contains no profile/settings persistence or desktop-quit call.
- **Composition and run setup:** `main.gd`, `main.tscn`, `class_selection_panel.gd`, and `hud.tscn` keep routing/quit in `PartyForgeMain`, boot to the menu, reuse nine-class run setup with Back, hide pre-run HUD, and reveal it only after successful launch.
- **Profiles, Settings, and City child flow:** `profiles_settings_page.gd`, `settings_screen.gd`, and `passive_tree_screen.gd` preserve bootstrap details, originating focus, fail-closed route status, and child focus during mutation refresh. The Profiles page change is required by Task 5's bootstrap-diagnostic behavior even though the plan's abbreviated file list named the Settings screen composition point.
- **Input map:** `project.godot` preserves keyboard accept/cancel and makes only shared standard UI A/B bindings any-controller; player-specific movement/custom actions remain scoped.
- **Integration coverage:** the five changed/added integration scripts and their intended UIDs cover menu navigation, real-renderer responsiveness, profile boot, City input/focus, and run-setup geometry.
- **Unit coverage:** the seven changed/added unit scripts and their intended UIDs cover policy, screen, wiring, class-selection lifecycle, boot, and Quick Start noncontamination.
- **File inventory:** the branch range from `71a1054` through the modal-fix head contains exactly 37 intentional files: four documentation files, one project configuration, four scenes, eight production scripts, 12 test scripts, and eight intended `.gd.uid` sidecars. No unexplained binary, `.png.import`, cache, or generated baseline UID is part of the range.

## Repository preservation

- Pre-gate state: clean `feat/functional-main-menu` at exact `ce057a9`, zero sidecars, zero worktree Godot processes, and four safety stashes.
- Verification-generated state: exactly 629 untracked sidecars, comprising 591 `.import` and 38 `.uid`; no other untracked path.
- Cleanup: the established `task-1-final-sidecar-cleanup.ps1` and its 629-path allowlist validated every target as an in-worktree, untracked leaf and reported `CLEANUP_PASS validated=629 deleted=629 final_status_count=0 stash_diff=0` before documentation edits.
- The connected editor and post-fix import each recreated the same 629 allowlisted sidecars. Cleanup revalidated and deleted all 629; its final-status assertion then reported only the intentional modal-fix or verification-document changes. No Godot process remains and the four stashes are unchanged.

## Connected Godot MCP acceptance

The restored Godot AI connection targeted only `functional-main-menu@dba2`, an isolated editor whose project path was the feature worktree. The game ran at physical 3840x2160 with a 1920x1080 logical canvas. MCP screenshots reported current frames at 1920x1080 capture resolution, while state queries read the real focus owner, open surfaces, run state, pause state, profile state, and process liveness.

| Windowed flow | Result |
| --- | --- |
| Fresh no-profile boot visibly offered only Play, Settings, and Quit; controller A opened Profiles with ProfileName focus | `PASS` |
| Created `MCPAlpha` and `MCPBeta`, switched back to `MCPAlpha`, and returned to PrimaryAction without starting a run | `PASS` |
| Opened/closed Settings and restored exact Settings focus | `PASS` |
| Opened nine-class run setup, used Back, launched Fighter, and observed the live arena | `PASS` |
| Controller movement changed the leader from x=0 to about x=3.41 in 0.5 seconds with positive x velocity | `PASS` |
| Opened pause, navigated to Quit Run, confirmed, and returned to a fresh unpaused main menu focused on PrimaryAction | `PASS` |
| Completed the isolated profile through `ProfileMutationService`, refreshed it, opened production City with `developer_context=false`, and controller B returned to exact CityTree focus | `PASS` |
| Saved isolated Developer Mode, used second-controller left-stick to reach Developer Quick Start, and controller A launched Fighter | `PASS` |
| Compared `ProfileCodec.encode(active_profile).sha256_text()` before and after Quick Start; both were `dd4a35dfc654847f0211ed3219914e1558af3f27ba539ef1c8dd5dc54215cdad` | `PASS` |
| Exercised synthetic mouse input at physical-window coordinates, keyboard text/Tab/Enter, controller 0, and synthetic controller device 1 accept/cancel/analog routes | `PASS` |
| Focused desktop Quit, activated it from controller device 1, and observed `game_status.status=stopped`, `is_playing=false`, and `session_active=false` | `PASS` |

The MCP pass exposed one real defect: with Quit Run confirmation open, D-pad Up could escape from Cancel to the Settings button behind the modal. A focused test first failed all 12 explicit focus-neighbor/traversal assertions. The scene now loops each of Confirm's six focus directions to Cancel and each of Cancel's six directions to Confirm. The focused test passed, and the live 4K rerun proved Cancel -> D-pad Up -> Confirm while the confirmation remained open and the tree remained paused.

The clean final desktop-Quit run's game log contained only the helper registration plus `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY`. The editor still reports 14 known GDScript warnings (shadowing, integer division, enum casts, incompatible ternaries, and one unused parameter); these predate the modal fix and are not parse/runtime failures. During the earlier extended arena run, normal target despawns also produced `PARTY_FORGE_ATTACK_SEQUENCE_ERROR ... target invalid at release` diagnostics. That combat cancellation diagnostic is recorded for a later focused cleanup rather than hidden or attributed to Plan 3A.

The connected controllers are synthetic MCP events, not physical-hardware certification. A short human-held controller smoke remains advisable before a public build, but it is no longer an integration blocker for this Plan 3A branch.

## Independent review and authoritative integration

- Independent review found no Critical or Important defects. Its one Minor finding is test-harness hardening: `tests/integration/main_menu_navigation_runner.gd` removes the default settings file and assumes the documented isolated `APPDATA`/`LOCALAPPDATA` roots. Running that standalone runner against normal user data remains unsupported until it gains backup/restore protection.
- Before integration, both worktrees were clean, authoritative `main` was still the exact planned base `71a1054`, no Godot process was active, the four safety stashes were unchanged, and Git confirmed fast-forward eligibility.
- `main` fast-forwarded to `dc1a32a` without applying either cleanup stash or rewriting unrelated work.
- Fresh post-merge validation on authoritative `main` passed: full import exit 0 with zero script/parse/loader errors; exact `TEST_SUMMARY: PASS (112 suites)`; and headless editor startup exit 0 with zero script/parse/loader errors.
- Post-merge cleanup validated and removed exactly the 629 known generated sidecars. Godot's unrelated indentation rewrite of `scripts/progression/upgrade_choice.gd` was restored to the committed bytes. Final authoritative-main status was clean and all four stashes remained unchanged.

## Explicitly deferred to Plan 3B

Final city/sunrise/house/character assets, cinematic city-to-house camera flight, body transition, prologue checkpoint/resume behavior, skip flow, tutorial encounters, and final tutorial staging remain deferred. The current skyline and prologue route are replaceable Plan 3A seams and are not final presentation.
