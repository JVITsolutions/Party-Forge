# Functional Main Menu Plan 3A Verification

Date: 2026-08-04

Milestone state: `AUTOMATED EXACT-HEAD PASS; MANUAL WINDOWED ACCEPTANCE PENDING`

Task 9 is not complete and this branch is not approved for integration. This record covers fresh automated evidence captured from the clean implementation head `ce057a949f8f64bfb661aded26dcfec3cdcdb44c` (`fix: support any-controller main menu input`) before these documentation edits. No commit, merge, or authoritative-main activation was performed.

## Evidence boundaries

- **Fresh exact-head automation:** isolated headless import, the complete custom suite, headless input/layout integrations, focused run/profile regressions, and repository checks run against exact implementation HEAD `ce057a9`.
- **Scripted real-window renderer evidence:** `main_menu_responsive_runner.gd` drove the real root `Window` through the OpenGL Compatibility renderer, measured the production `canvas_items` scale path, and captured pixels. This is automated renderer evidence, not a person's connected playtest.
- **Manual Windows/controller acceptance:** no person performed the Task 9 windowed smoke during this automation pass. Every item in the manual matrix remains `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE`.

All Godot commands used `Godot_v4.7.1-stable_mono_win64_console.exe`, the functional-main-menu worktree, and fresh task-specific roots:

```text
APPDATA=.superpowers/task-9-appdata
LOCALAPPDATA=.superpowers/task-9-localappdata
```

The live user profile/settings location was not used.

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
| Whitespace/path check | `git diff --check` | 0 | no output after the intentional documentation edits |

`rg --files` found no dedicated file named as an arena-smoke runner, run-pause integration runner, or controller-movement integration runner. The gate therefore records the exact existing focused equivalents instead of inventing runner names: `test_combat_sandbox.gd` plus `test_main_wiring.gd` for arena composition, `test_run_pause_menu.gd` plus `test_game_run_pause_clock.gd` for pause behavior, and `test_controller_movement_bindings.gd` plus `test_leader_movement.gd` and `character_locomotion_smoke.gd` for controller/movement coverage. Ordinary rendered arena and pause behavior remain in the manual matrix.

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
- **File inventory:** the branch range `71a1054..ce057a9` contains exactly 31 intentional files: 12 production/configuration paths, 11 test scripts, and eight intended `.gd.uid` sidecars. No unexplained binary, `.png.import`, cache, or generated baseline UID is part of the range.

## Repository preservation

- Pre-gate state: clean `feat/functional-main-menu` at exact `ce057a9`, zero sidecars, zero worktree Godot processes, and four safety stashes.
- Verification-generated state: exactly 629 untracked sidecars, comprising 591 `.import` and 38 `.uid`; no other untracked path.
- Cleanup: the established `task-1-final-sidecar-cleanup.ps1` and its 629-path allowlist validated every target as an in-worktree, untracked leaf and reported `CLEANUP_PASS validated=629 deleted=629 final_status_count=0 stash_diff=0` before documentation edits.
- Post-documentation state is limited to the intentional Task 9 Markdown paths. No Godot process remains and the four stashes are unchanged.

## Connected Windows attempt - control bridge blocked

On 2026-08-04, the controller launched the exact worktree twice with isolated `APPDATA` and `LOCALAPPDATA`: once as the standalone `Party Forge (DEBUG)` game and once through `Party Forge - Godot Engine` for an embedded-game fallback. Both created responsive native Windows processes and discoverable windows. The desktop-control bridge then rejected both freshly returned Godot window handles with a stale-owner error even though the reported and current owner identifiers were identical. No menu input could be sent through the approved desktop-control path, so none of the manual rows below is promoted to PASS.

Both attempted processes were closed, the resulting 629 known import/UID sidecars were removed through the validated allowlist, the editor-only removal of the input-policy comments was restored exactly, and the four safety stashes remained unchanged. This is a tooling limitation, not evidence that a menu flow passed or failed.

## Manual Windows/controller acceptance - pending

No row below is passed by automation.

| Manual flow | Status |
| --- | --- |
| No-profile boot visibly offers only Play, Settings, and Quit; Play opens Profiles with profile-name focus | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Create a profile, switch profiles, and confirm the selected name returns to the menu without starting a run | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Open/close Settings and confirm exact originating focus | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Open class-selection run setup and use Back to return to the primary menu action | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Select a class and confirm the ordinary arena/combat launch | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Open the run pause menu and confirm Quit Run returns to the functional main menu | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Use a completed/discovered profile to open the production City tree and return to exact City focus | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Use saved Developer Mode to run Developer Quick Start and independently inspect the persisted test profile afterward | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Exercise mouse, keyboard, controller 0, and a second connected controller through accept/cancel/focus routes | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |
| Use desktop Quit and confirm the Windows process closes; inspect the connected editor/game logs after each flow | `PENDING CONTROLLER MANUAL WINDOWED EVIDENCE` |

## Explicitly deferred to Plan 3B

Final city/sunrise/house/character assets, cinematic city-to-house camera flight, body transition, prologue checkpoint/resume behavior, skip flow, tutorial encounters, and final tutorial staging remain deferred. The current skyline and prologue route are replaceable Plan 3A seams and are not final presentation.
