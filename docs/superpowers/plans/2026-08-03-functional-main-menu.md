# Party Forge Functional Main Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Use TDD and `verification-before-completion` for every completion claim.

**Goal:** Replace the current class-selection-first boot with a functional, profile-aware Party Forge front door that provides Play, Settings, Quit, returning-player run setup, City passive-tree routing, and a Developer Quick Start while preserving the existing arena and deferring the final cinematic presentation to Plan 3B.

**Architecture:** A pure main-menu projection converts the active profile, machine settings, and City-tree availability into route intents and visible actions. A reusable full-screen blockout menu renders only that projection and emits signals; it never mutates profiles, starts runs, or interprets passive-tree data. `PartyForgeMain` remains the composition root and routes menu intents to the existing Profiles Settings page, class-selection run setup, passive-tree screen, arena launch, or desktop quit. The temporary Plan 3A prologue handoff uses an explicit route seam so Plan 3B can replace it with the city flight/tutorial without rewriting the menu.

**Tech Stack:** Godot 4.7.1, typed GDScript, `CanvasLayer`/`Control`, existing `ProfileManager`, `PartyForgeSettings`, passive-tree services, custom unit/integration runners, Git worktrees, PowerShell.

## Scope and Decisions

Plan 3A includes:

- A functional blockout main menu with Play, Settings, and Quit.
- First-launch profile creation routing without automatically covering the menu with Settings at boot.
- Active-profile refresh after profile creation or switching.
- Explicit routing for `not_started`, `in_progress`, and `completed` prologue states.
- The existing class-selection panel as the normal run-setup destination.
- A production City-tree entry for eligible returning profiles.
- Developer Quick Start to the current arena.
- Mouse, keyboard, and controller navigation.
- Responsive layout at 1080p, 1440p, and 4K.

Plan 3A does not include:

- Final city, sunrise, house, character, or camera-flight assets.
- Marking a prologue started merely because the temporary run-setup route opened.
- Completing the prologue or granting its Passive Point from the blockout menu.
- Checkpoint/resume implementation, tutorial encounters, or the cinematic skip flow.
- Final character ownership filters, split-screen profile seats, online multiplayer, inventory, stash, or extraction.
- Replacing the current class-selection panel with final run-setup presentation.

## Required Player Behavior

| Context | Main action | Other visible actions | Durable effects |
|---|---|---|---|
| No active profile | `Play` opens Settings directly on Profiles | Settings, Quit | None until profile creation commits through `ProfileManager` |
| `NOT_STARTED` profile | `Play` emits the temporary prologue route and opens current run setup | Settings, Quit | No prologue mutation in Plan 3A |
| `IN_PROGRESS` profile | `Continue` emits the temporary prologue-resume route and opens current run setup | Settings, Quit | No checkpoint mutation in Plan 3A |
| `COMPLETED` profile | `Begin Run` opens current run setup | Settings, Quit, discovered City services | None until an existing service/run action commits |
| Developer Mode with active profile | State-appropriate main action | Settings, Quit, Developer Quick Start, City-tree developer preview | Overrides never mutate profile progression |

The first-launch player-facing action list remains Play, Settings, and Quit. Profiles remain a Settings tab. Returning profiles may gain discovered-service actions; Developer Mode may add clearly labeled testing actions.

## Global Constraints

- Authoritative repository: `F:\Projects(root)\Game dev\Projects\party-forge`.
- Product baseline commit: `3d5b045` (`chore: track generated Godot script UIDs`); the plan-document commit is expected to be its immediate descendant.
- After plan approval, begin implementation in an isolated worktree from the then-current clean `main` branch and require that it contains `3d5b045`.
- Preserve the two cleanup safety stashes; do not drop or apply them during this plan.
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.
- Use a task-specific `APPDATA` and `LOCALAPPDATA` inside the worktree for imports and tests.
- Commit intended `.gd.uid` files for new scripts/tests. Do not commit default-generated `.png.import` files or `.godot/` cache content.
- Keep `PartyForgeMain` as the sole owner of scene routing and desktop quit.
- UI classes emit intents and consume immutable/copy-owned projections; they do not write profile files or settings files.
- Developer Quick Start requires an active profile and never marks prologue, milestones, unlocks, or Passive Points.
- Normal City-tree access requires the active profile to have discovered `party-forge-city-v1`; Developer Mode may open a full-visibility preview.
- Player-mode City-tree access must use the real profile allocation/fog/refund projection, not the developer projection.
- Settings and child screens must restore focus to the exact originating menu/run-setup control.
- The existing arena, combat, profiles, settings, ledger, pause menu, upgrades, popup pinning, passive tree, and controller behavior must remain functional.
- Plan 3B presentation must be replaceable behind the prologue route seam without changing menu tests or profile rules.

Before Godot command blocks:

```powershell
$godot='F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$env:APPDATA=(Resolve-Path '.superpowers/plan-3a-appdata').Path
$env:LOCALAPPDATA=(Resolve-Path '.superpowers/plan-3a-localappdata').Path
```

---

## Repository and File Map

### New menu domain/UI

- `scripts/ui/main_menu/main_menu_projection.gd`: copy-owned display/action projection.
- `scripts/ui/main_menu/main_menu_view_model.gd`: pure profile/settings-to-projection policy.
- `scripts/ui/main_menu/main_menu_screen.gd`: lifecycle, signals, focus, and responsive layout.
- `scenes/ui/main_menu/main_menu_screen.tscn`: asset-replaceable blockout menu.

### Existing composition points

- `scripts/game/main.gd`: boot, route composition, run setup, City tree, quick start, and quit.
- `scenes/game/main.tscn`: instances the main-menu screen.
- `scripts/ui/class_selection_panel.gd`: current run-setup destination and Back intent.
- `scenes/ui/hud.tscn`: adds the run-setup Back action and keeps run HUD hidden before launch.
- `scripts/ui/settings/settings_screen.gd`: menu-origin focus restoration and Profiles routing.
- `scripts/ui/passive_tree/passive_tree_screen.gd`: reused without menu-specific branching.
- `scripts/profile/profile_manager.gd`: active profile source and change signals.
- `scripts/profile/profile_state.gd`: existing prologue/discovery state; schema remains unchanged.

### Tests and evidence

- `tests/unit/test_main_menu_view_model.gd`
- `tests/unit/test_main_menu_screen.gd`
- `tests/unit/test_class_selection_panel.gd`
- `tests/unit/test_profile_boot_integration.gd`
- `tests/unit/test_main_wiring.gd`
- `tests/integration/main_menu_navigation_runner.gd`
- `tests/integration/main_menu_responsive_runner.gd`
- `tests/integration/profile_boot_main_flow_runner.gd`
- `tests/integration/passive_tree_input_runner.gd`
- `docs/verification/2026-08-03-functional-main-menu.md`

---

### Task 1: Protect the Clean Baseline in an Isolated Worktree

**Files:** no product edits.

- [ ] Record `main` HEAD, status count, existing worktrees, and the two cleanup safety stashes.
- [ ] Create `feat/functional-main-menu` under `.worktrees/functional-main-menu` from the approved clean `main` head and verify that `3d5b045` is an ancestor.
- [ ] Create isolated application-data directories under that worktree.
- [ ] Run a full Godot import and require exit code 0 with no parse/load errors.
- [ ] Run `res://tests/test_runner.gd` and require `TEST_SUMMARY: PASS (109 suites)` before feature edits.
- [ ] Run the existing profile boot, settings/profile navigation, passive-tree input, and passive-tree responsive runners.
- [ ] Snapshot all untracked sidecars created by import so cleanup removes only verification-created files.

**Commit:** none.

### Task 2: Define the Pure Main-Menu Projection and Route Policy

**Files:**

- Create `scripts/ui/main_menu/main_menu_projection.gd`.
- Create `scripts/ui/main_menu/main_menu_view_model.gd`.
- Create `tests/unit/test_main_menu_view_model.gd`.

- [ ] Write failing tests covering no profile, every prologue state, completed/discovered City tree, Player Mode, Developer Mode, unlock-all, and unavailable City-tree data.
- [ ] Define stable route IDs: `profiles`, `prologue_start`, `prologue_resume`, `run_setup`, `city_tree`, `developer_quick_start`, `settings`, and `quit`.
- [ ] Make `MainMenuProjection` copy-owned and value-only: labels, visibility/enabled flags, route IDs, active-profile text, and nontechnical status text.
- [ ] Implement `MainMenuViewModel.build(profile, settings, city_tree_available)` without reading nodes, singletons, files, or mutable manager state.
- [ ] Require the exact player behavior matrix above.
- [ ] Require normal City-tree visibility only when the profile is completed and contains `party-forge-city-v1` in `discovered_trees`.
- [ ] Require Developer Mode to expose City preview and Quick Start without treating `unlock_all_implemented_content` as durable discovery.
- [ ] Return a safe projection when profile/settings/tree inputs are missing or malformed.
- [ ] Run the focused suite and then the full suite.

**Commit:** `feat: add functional main menu routing policy`

### Task 3: Build the Asset-Replaceable Main-Menu Screen

**Files:**

- Create `scripts/ui/main_menu/main_menu_screen.gd`.
- Create `scenes/ui/main_menu/main_menu_screen.tscn`.
- Create `tests/unit/test_main_menu_screen.gd`.

- [ ] Write failing scene-contract tests for stable paths: `Backdrop`, `Title`, `ActiveProfile`, `PrimaryAction`, `CityTree`, `DeveloperQuickStart`, `Settings`, `Quit`, and `Status`.
- [ ] Build a full-screen `CanvasLayer` with a temporary vector/color city blockout. Keep backdrop nodes presentation-only so Plan 3B can replace them independently.
- [ ] Add signals for each route intent; the screen must not call `ProfileManager`, `ProfileMutationService`, `SceneTree.quit`, or run APIs.
- [ ] Implement `present(projection)`, `open(preferred_focus)`, `close()`, `is_open()`, and defensive `projection()` access.
- [ ] Keep the first-launch visible action set exactly Play, Settings, Quit.
- [ ] Add an explicit controller/keyboard focus loop across only visible/enabled actions.
- [ ] Support mouse activation and `ui_cancel` without trapping focus or closing the desktop.
- [ ] Apply the existing reduced-motion setting to any blockout transitions; no mandatory animation may delay input readiness.
- [ ] Add accessible descriptions for the active profile, City tree, and developer-only controls.
- [ ] Run the focused screen suite and full suite.

**Commit:** `feat: add blockout functional main menu screen`

### Task 4: Make Class Selection a Reusable Run-Setup Destination

**Files:**

- Modify `scripts/ui/class_selection_panel.gd`.
- Modify `scenes/ui/hud.tscn`.
- Modify `tests/unit/test_class_selection_panel.gd`.
- Modify `tests/unit/test_responsive_ui.gd` if its stable geometry contract changes.

- [ ] Write failing tests for `open()`, `close()`, `is_open()`, initial focus, and `back_requested`.
- [ ] Add a Back button beside Settings with mouse/keyboard/controller focus wiring.
- [ ] Preserve all nine current class buttons and their existing `class_selected` contract; character unlock filtering remains deferred.
- [ ] Make opening run setup hide the run HUD status block and make starting a run reveal it.
- [ ] Make Back return to the main menu without starting, mutating, or reloading a run.
- [ ] Preserve Settings return focus to the run-setup Settings button.
- [ ] Re-run responsive class-selection coverage at 1080p, 1440p, and 4K.

**Commit:** `refactor: make class selection reusable run setup`

### Task 5: Compose First Launch, Profiles, Settings, and Returning Routes

**Files:**

- Modify `scripts/game/main.gd`.
- Modify `scenes/game/main.tscn`.
- Modify `scripts/ui/settings/settings_screen.gd` only if an explicit menu-origin helper is required.
- Modify `tests/unit/test_profile_boot_integration.gd`.
- Modify `tests/unit/test_main_wiring.gd`.
- Modify `tests/integration/profile_boot_main_flow_runner.gd`.

- [ ] Change boot so the main menu opens first even when no profile exists; do not auto-open Profiles Settings.
- [ ] Keep profile bootstrap diagnostics visible through a safe menu status and through the Profiles page technical details.
- [ ] Handle no-profile Play by opening Settings directly on Profiles and focusing `ProfileName`.
- [ ] Refresh the menu projection on `profiles_changed`, `active_profile_changed`, and successful settings application.
- [ ] After profile creation or switching, return to the menu and show the selected display name without auto-starting a run.
- [ ] Route `prologue_start` and `prologue_resume` through named temporary handlers that open current run setup without changing `prologue_state`.
- [ ] Route `run_setup` to the same class-selection destination.
- [ ] Route class-selection Back and confirmed Quit Run to the main menu with focus restored.
- [ ] Keep desktop Quit owned by `PartyForgeMain._quit()` and connect it only to the main-menu Quit intent and existing result-panel desktop quit.
- [ ] Update boot/run assertions: menu visible, run setup hidden, no leader, timer stopped, run HUD hidden; class selection still launches the arena unchanged.
- [ ] Run focused boot/main suites and the updated end-to-end profile flow.

**Commit:** `feat: route profiles and run setup through main menu`

### Task 6: Add Production and Developer City-Tree Routing

**Files:**

- Modify `scripts/game/main.gd`.
- Modify `scripts/ui/settings/settings_screen.gd` only to share a child-return contract if needed.
- Modify `tests/unit/test_main_wiring.gd`.
- Modify `tests/unit/test_passive_tree_screen.gd` only for shared lifecycle assertions.
- Modify `tests/integration/passive_tree_input_runner.gd`.

- [ ] Replace the current developer-only main handler with one route accepting a `developer_preview` flag and an explicit return control.
- [ ] From the returning menu, open the City tree with `developer_context = false`; require real fog, allocations, points, and refund rules.
- [ ] From Developer Mode, open with `developer_context = true`; require full preview and free testing behavior already defined by the passive-tree services.
- [ ] Fail closed with a player-facing status if the tree catalog is unavailable; never open a half-configured screen.
- [ ] On close, restore the exact City-tree button in the menu or Additional Settings, depending on origin.
- [ ] Refresh the active profile after successful tree mutation so menu service visibility and profile data stay current.
- [ ] Prove that normal access cannot be obtained merely by enabling unlock-all in Player Mode.
- [ ] Re-run passive-tree profile, input, responsive, and readability suites.

**Commit:** `feat: route city tree from returning main menu`

### Task 7: Add a Noncontaminating Developer Quick Start

**Files:**

- Modify `scripts/game/main.gd`.
- Modify `tests/unit/test_main_wiring.gd`.
- Create `tests/unit/test_developer_quick_start.gd`.

- [ ] Write failing tests requiring Developer Mode plus an active profile.
- [ ] Route Quick Start directly through the existing Fighter arena launch path without duplicating run initialization.
- [ ] Capture the same immutable `RunRulesSnapshot` used by ordinary class selection.
- [ ] Assert the profile's prologue state, Passive Points, milestones, unlocks, and transactions are identical before and after Quick Start.
- [ ] Keep Quick Start hidden in Player Mode and unavailable without a valid profile/catalog.
- [ ] Keep errors user-facing and recoverable on the menu; do not leave the menu hidden after a failed launch.
- [ ] Run the focused quick-start suite and full suite.

**Commit:** `feat: add developer arena quick start`

### Task 8: Complete Controller, Focus, and Responsive Integration

**Files:**

- Create `tests/integration/main_menu_navigation_runner.gd`.
- Create `tests/integration/main_menu_responsive_runner.gd`.
- Modify `project.godot` only if existing UI actions are insufficient.
- Modify `scripts/ui/settings/settings_screen.gd` and menu/run-setup scripts only for failures proven by these runners.

- [ ] Drive first boot, Profiles creation, menu return, Settings open/close, run setup Back, completed-profile City tree, tree close, and Developer Quick Start using real input actions.
- [ ] Require controller south-face activation, D-pad/left-stick focus navigation through standard UI actions, shoulder-button settings tabs, and B/Circle cancel behavior.
- [ ] Require keyboard Enter/Space activation, arrow/Tab focus navigation, Escape return, and mouse activation.
- [ ] Assert no hidden or disabled control receives focus.
- [ ] At 1920x1080, 2560x1440, and 3840x2160, require all menu actions, active-profile text, status text, and the temporary backdrop to remain contained and readable.
- [ ] Require Settings (layer 10) and passive tree (layer 12) to render above the main menu; Developer Mode badge may remain visible above the backdrop without covering actions.
- [ ] Capture rendered screenshots for all three target resolutions and inspect them manually.
- [ ] Run existing settings/profile navigation, passive-tree input, class-selection responsive, and controller movement runners to catch focus regressions.

**Commit:** `test: validate functional main menu navigation`

### Task 9: Final Verification, Documentation, and Integration

**Files:**

- Create `docs/verification/2026-08-03-functional-main-menu.md`.
- Update `docs/handbook/10-party-forge-architecture-reference.md` for the new boot and route flow.
- Update any handbook/tutorial references that still say boot begins at class selection.

- [ ] Run `git diff --check` and review every changed file against this plan.
- [ ] Run a fresh full Godot import with exit code 0 and no parse/load errors.
- [ ] Run the full suite and record its exact suite count.
- [ ] Run main-menu navigation/responsive, profile boot, settings/profile navigation, passive-tree profile/input/responsive, controller movement, run pause, and arena smoke runners.
- [ ] Launch a windowed build and manually verify no-profile Play, profile creation, profile switching, settings focus return, class-selection Back, ordinary arena launch, Quit Run return, completed-profile City tree, Developer Quick Start, and desktop Quit.
- [ ] Read editor/game logs after each connected flow and record exact warnings/errors. Existing negative-path test output must not be mislabeled as runtime failure.
- [ ] Confirm Developer Quick Start did not mutate the test profile by reloading it from disk.
- [ ] Confirm the implementation worktree contains only intentional tracked files plus known import-generated sidecars; remove only verification-created sidecars.
- [ ] Obtain an independent code review before integration.
- [ ] Fast-forward or merge only after rechecking live `main`; do not apply either cleanup safety stash.
- [ ] After integration, verify the authoritative main checkout remains clean and the Godot editor can open the project without resaving resources.

**Commit:** `docs: record functional main menu verification`

---

## Final Acceptance Checklist

- [ ] Main boots to a functional menu, not directly to class selection or Profiles Settings.
- [ ] First-launch Player Mode visibly offers only Play, Settings, and Quit.
- [ ] Play with no profile opens Profiles and focuses profile creation.
- [ ] Creating/selecting a profile updates the menu without starting a run.
- [ ] `NOT_STARTED`, `IN_PROGRESS`, and `COMPLETED` profiles produce the approved labels and routes.
- [ ] Plan 3A does not mutate or complete prologue state.
- [ ] Begin Run reaches existing class selection; Back returns to the menu.
- [ ] Selecting a class starts the unchanged arena/combat flow.
- [ ] Quit Run returns to the menu; desktop Quit closes the application.
- [ ] Normal City-tree routing respects discovery and real profile fog/points/refunds.
- [ ] Developer City preview and Quick Start are visible only in Developer Mode and do not contaminate profile progression.
- [ ] Settings and passive-tree child screens restore exact focus to their originating control.
- [ ] Mouse, keyboard, and controller flows pass.
- [ ] 1080p, 1440p, and 4K rendered checks pass.
- [ ] Full import, automated suite, integration runners, live log review, and windowed smoke are recorded.
- [ ] Final city assets, cinematic flight, house entry, body transition, and tutorial staging remain explicitly deferred to Plan 3B.
