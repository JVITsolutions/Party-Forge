# Party Forge Review Batch 1 Implementation Plan

> **Execution boundary:** Work only on `feat/living-forge-combat-loop-ui`. Preserve the active user Godot editor/debug session and all user-owned/untracked files. Do not touch procedural character/equipment geometry, Blender assets, imported models, or preview camera depth. Do not merge, push, fetch, clean, or modify `main`.

## Slice 1: Recruitment and focus correctness

- Extend `tests/integration/level_up_commit_flow_runner.gd` with a freed gameplay-focus regression and a real Frost Mage recruitment through Main.
- Assert the recruitment route produces no script error, binds a valid companion health authority, restores valid gameplay focus, and never emits `COMBAT_HUD_UNAVAILABLE`.
- First make the regression fail. Then update `scripts/ui/level_up_panel.gd` so validity is checked before type/access.
- Repair the general member-added/actor-bound sequencing in `scripts/ui/hud.gd` and/or `scripts/party/party_actor_spawner.gd` without special-casing Frost Mage or weakening HUD authority validation.
- Run the commit-flow runner plus directly affected HUD/party/run-context tests.

## Slice 2: Percentage and upgrade detail

- Update `tests/unit/test_upgrade_presentation.gd` first to require `%` for every player-facing ratio-percent effect and reject the words `percent` and `percentage points` across the authored upgrade catalog.
- Extend `tests/integration/level_up_five_card_geometry_runner.gd` with first-slot Ranged Calibration detail-popup assertions for `+10% Attack Range.`, `+10% Projectile Speed.`, focus ownership, and scroll origin.
- Update `scripts/progression/upgrade_presentation_service.gd` and repair the shared detail path only if the integration test proves it necessary.
- Run the presentation unit suite and five-card integration runner.

## Slice 3: Living Forge class selection

- Add RED coverage to `tests/unit/test_class_selection_panel.gd`, `tests/unit/test_character_equipment_preview.gd`, `tests/integration/play_lobby_input_runner.gd`, and `tests/integration/play_lobby_responsive_runner.gd` for all nine class previews, Frost Mage title containment, every-card directional traversal, preview focus transfer, keyboard/controller rotation, and Start Run focused styling.
- Update `scripts/ui/class_selection_panel.gd`, `scripts/ui/ledger/character_equipment_preview.gd`, and the relevant Living Forge theme/action-bar seams with shared behavior. Keep preview camera depth settings unchanged.
- Run class-selection, preview, lobby input/responsive, theme, accessibility, and visual regression gates.

## Slice 4: Character HUD background opacity

- Add RED settings/model/store/UI/HUD tests covering a default of 50%, normalization bounds, version-1 migration, persistence, Game Settings binding/writing, application to every member card, recruitment inheritance, and high-contrast readability.
- Bump the settings schema and migrate version 1 in `scripts/settings/party_forge_settings_store.gd`; add the bounded field to `scripts/settings/party_forge_settings.gd`.
- Add the control to `scenes/ui/settings/game_settings_page.tscn` and bind it in `scripts/ui/settings/game_settings_page.gd`.
- Apply background alpha only to the dark member-card/shell surfaces in `scripts/ui/living_forge/components/forge_party_member_card.gd` and `scripts/ui/hud.gd`, leaving text, bars, icons, borders, focus rings, and semantic cues opaque. High contrast retains an accessibility-safe opaque surface.
- Run settings, settings-screen, combat-HUD, responsive, accessibility, and visual gates.

## Slice 5: Fresh normal-run seeds

- Add RED tests around a legitimate injectable seed-source seam in Main.
- Replace the fixed new-normal-run default with one fresh positive seed per checkout while retaining explicit seeds for recovery, replay, and tests.
- Add deterministic same-seed reproduction, injected different-new-run variability, and a fixed bounded seed corpus that demonstrates more than one name/class/upgrade result without probability thresholds.
- Do not change class weighting or introduce Paladin/Warlock weighting.
- Run Main wiring, checkout/recovery/replay, identity, level-up choice, and gameplay integration tests.

## Qualification and handoff

- After every slice, run its focused tests and commit only that coherent slice.
- Run all directly impacted Living Forge/gameplay runners, then the full headless suite and require terminal `TEST_SUMMARY: PASS` plus exit code 0.
- Verify the worktree is clean, active user Godot processes are still running, no untracked `.uid` was removed, the diff contains no art/model/geometry/camera-depth changes, and no branch other than the feature branch moved.
- Report exact commits, files, commands, markers, remaining uncertainty, and collision risk, then stop for Jacob's approval.
