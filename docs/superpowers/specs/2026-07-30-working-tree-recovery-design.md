# Party Forge Working-Tree Recovery Design

**Date:** 2026-07-30
**Status:** Approved by Jacob on 2026-07-30

## Purpose

Restore the live Party Forge checkout to the last verified runnable behavior and a clean Git state without losing the locally installed GodotSteam bundle, historical handbook ZIP, or active Godot AI integration.

## Root Cause

The open Godot editor retained an older in-memory HUD and project-settings state while newer class-selector and responsive-layout changes were written externally and committed. A later editor save serialized the stale state back to disk. The current checkout therefore removes the catalog-driven class-selector script and grid, restores four hard-coded class buttons, shrinks the selector, and drops `window/stretch/aspect="keep"`.

The dirty checkout reproduces five automated failures and a runtime error at `main.gd:133`. An isolated archive of `HEAD 14ecc9d` imports successfully and passes all 32 suites. The remaining tracked diffs are Godot UID/default-value serialization or whitespace-only formatting, except for the intentional Godot AI game-helper autoload.

## Recovery Boundary

The branch and commit history are immutable recovery inputs. Do not reset, revert, detach, or move `HEAD`. In particular, preserve the committed stat backend, typed combat and recovery systems, nine-class expansion, catalog-driven selection, handbook work, and the approved character-targeted-upgrades design. Recovery operates only on the uncommitted working-tree delta relative to the current `HEAD`.

1. Record a complete patch, status listing, and hashes for untracked material before changing the checkout.
2. Stop and close the Godot editor so stale in-memory resources cannot rewrite repaired files.
3. Restore all tracked formatting, UID churn, default-value elision, and the stale HUD/settings regression to `HEAD 14ecc9d`.
4. Reapply only the intentional `_mcp_game_helper` autoload while retaining the committed `window/stretch/aspect="keep"` setting.
5. Track `tests/unit/test_responsive_ui.gd.uid`, consistent with the repository's tracked Godot UID sidecars.
6. Preserve `addons/godotsteam/` and `Party-Forge-Godot-Handbook-6977ae6.zip` in place, but add them to `.git/info/exclude` so they remain local and do not enter repository history during this recovery.
7. Commit the intentional Godot AI autoload and responsive-test UID as one bounded recovery commit.
8. Reimport, run the complete suite, launch the game, and inspect editor/game logs.
9. Reopen Godot on `res://scenes/game/main.tscn`, confirm the freshly loaded scene has no unsaved changes, and leave the project stopped and ready after verification. Do not invoke Save All during recovery verification.

## Preserved Local Material

- `addons/godotsteam/`: preserve the complete locally installed vendor bundle, including temporary updater files. Steam integration and whether to vendor the dependency through Git LFS receive a separate decision later.
- `Party-Forge-Godot-Handbook-6977ae6.zip`: preserve as a historical downloadable artifact. Current tracked handbook sources remain authoritative.
- `addons/godot_ai/`: retain the already tracked plugin and its runtime game-helper autoload.
- Projectile speed/lifetime tuning: retain the committed tuning already present at `HEAD 14ecc9d`.

No untracked file is deleted, moved, or overwritten by this recovery.

The backup must be sufficient to reconstruct every pre-recovery tracked modification and identify every untracked path. Restoration commands must name the audited dirty paths explicitly; broad branch resets and recursive cleanup commands are prohibited.

## Verification

Recovery is complete only when:

- `git status --short` is empty.
- `project.godot` contains both the Godot AI autoload and `window/stretch/aspect="keep"`.
- `scenes/ui/hud.tscn` uses `class_selection_panel.gd`, `Content/Scroll/Grid`, and the 760x440 centered selector.
- Headless import exits zero.
- The custom test runner exits zero with `TEST_SUMMARY: PASS (32 suites)` and no `SCRIPT ERROR` or unexpected `TEST_FAILURE`.
- The live project reaches `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY` without the `main.gd:133` error.
- The nine-class selector is visible and the project can start a run.
- Godot is reopened on the clean saved `main.tscn`, stopped, unmodified, and ready.

## Future Prevention

After external scene or project-setting changes, reload the affected resources or restart Godot before using Save All. Before every feature execution, capture Git status and verify that the open editor scene matches the saved file. This prevents a long-lived editor from serializing stale in-memory state over newer repository content.

Future feature implementation occurs in an isolated Git worktree. The live root remains the stable integration and Godot AI verification copy. Verified feature commits are integrated into `main`, after which the live editor is restarted or explicitly reloaded before any scene save.
