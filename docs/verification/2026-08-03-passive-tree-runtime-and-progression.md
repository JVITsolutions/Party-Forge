# Passive-Tree Runtime and Progression Verification

Date: 2026-08-03

Milestone state: `AUTOMATED PASS; PENDING USER RENDERED VALIDATION`

This record covers the Party Forge implementation range `e27323f..HEAD` on `feat/passive-tree-runtime-progression`. The pre-verification implementation head is `3fae139` (`fix: preserve passive tree settings draft`); the Task 13 verification commit is the commit containing this document and is intentionally resolved from Git history instead of self-referencing its own SHA.

## Source traceability

The Passive Skill Tree Creator logistics source remains on `feat/party-forge-city-logistics` at `b9b4ac7` (`feat: expand Party Forge city logistics tree`). Creator commit `1b04c68` is the 0.3.0 implementation milestone that added the newer deterministic coordinate/linking capabilities. At verification time Creator `main` had advanced to `07b4abc` through two later documentation-only commits. Reconciliation of the reviewed City branch with Creator 0.3.0+ remains pending and did not rewrite the already reviewed 30-node artifact during Party Forge runtime work.

| Artifact | SHA-256 |
| --- | --- |
| Creator `samples/party-forge-city.pstree` | `b7936c656f6682c29135eac225df24e3808e1e387e759f8af1f59adec303fed9` |
| Party Forge `data/passive_trees/city/party-forge-city.pstree` | `b7936c656f6682c29135eac225df24e3808e1e387e759f8af1f59adec303fed9` |
| Creator `samples/party-forge-city.pstree.json` | `732daae5a3f1637aebed1ad670902da7e4f0a5cb4ed79592f8029144a25ec67c` |
| Creator `integrations/godot/demo/party-forge-city.pstree.json` | `732daae5a3f1637aebed1ad670902da7e4f0a5cb4ed79592f8029144a25ec67c` |
| Party Forge `data/passive_trees/city/party-forge-city.pstree.json` | `732daae5a3f1637aebed1ad670902da7e4f0a5cb4ed79592f8029144a25ec67c` |

Byte comparisons returned `True` for Creator source versus game source, Creator runtime export versus game runtime export, and Creator runtime export versus its Godot demo copy. The Creator City worktree already contained an untracked editor autosave, `samples/party-forge-city.pstree.autosave`; this task did not read it as authoritative, change it, or remove it.

## Characterization record

The new runners were executed before any production correction. Profile persistence passed on its first run, and responsive geometry passed on its first run at all three target sizes. The first input-runner attempts exposed runner-only harness mistakes: its key event shape differed from the repository's established real-input runner, and its fixed drag coordinate could land beneath one of the 30 node controls after controller pan/zoom. The runner was corrected to use the established key-event shape and to select an actual blank canvas point. The final characterization then passed. No production gap was found, no artificial RED was created, and Task 13 changed no production file.

| Characterization | Exit | Result | Raw log |
| --- | ---: | --- | --- |
| Full editor import | 0 | Import completed; no parse or script error | `.superpowers/sdd/task-13-logs/00-characterization-import.log` |
| Profile runner, first execution | 0 | `PASSIVE_TREE_PROFILE_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/01-characterization-profile.log` |
| Input runner, initial harness | 1 | Seven runner assertions; no product change | `.superpowers/sdd/task-13-logs/02-characterization-input.log` |
| Input runner, corrected key harness | 1 | Two drag-target harness assertions; no product change | `.superpowers/sdd/task-13-logs/02b-characterization-input-harness.log` |
| Input runner, drag-routing diagnostic | 1 | Confirmed the fixed coordinate reached no canvas input because a node control owned that point; no product change | `.superpowers/sdd/task-13-logs/02c-input-drag-diagnostic.log` |
| Input runner, blank-point confirmation | 0 | `PASSIVE_TREE_INPUT_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/02d-input-blank-diagnostic.log` |
| Responsive runner, first execution | 0 | `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)` | `.superpowers/sdd/task-13-logs/03-characterization-responsive.log` |

## Complete automated gate

Every Godot process used `Godot_v4.7.1-stable_mono_win64_console.exe`, this isolated worktree, `APPDATA=.superpowers/sdd/task-13-final-gate-appdata`, and `LOCALAPPDATA=.superpowers/sdd/task-13-final-gate-localappdata`. No automated process used the live Party Forge settings/profile location.

| Gate command | Exit | Accepted marker | Raw log |
| --- | ---: | --- | --- |
| `godot --headless --path . --import` | 0 | editor import completed | `.superpowers/sdd/task-13-logs/10-final-import.log` |
| `godot --headless --path . --script res://tests/test_runner.gd` | 0 | `TEST_SUMMARY: PASS (108 suites)` | `.superpowers/sdd/task-13-logs/11-final-full-suite.log` |
| `... profile_boot_main_flow_runner.gd` | 0 | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/12-profile-boot.log` |
| `... settings_profiles_navigation_runner.gd` | 0 | `PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/13-settings-navigation.log` |
| `... responsive_ui_geometry_runner.gd` | 0 | `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` | `.superpowers/sdd/task-13-logs/14-responsive-ui.log` |
| `... passive_tree_profile_runner.gd` | 0 | `PASSIVE_TREE_PROFILE_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/15-passive-profile.log` |
| `... passive_tree_input_runner.gd` | 0 | `PASSIVE_TREE_INPUT_SUMMARY: PASS` | `.superpowers/sdd/task-13-logs/16-passive-input.log` |
| `... passive_tree_responsive_runner.gd` | 0 | `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)` | `.superpowers/sdd/task-13-logs/17-passive-responsive.log` |
| `... character_presentation_sandbox_runner.gd` | 0 | `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5` | `.superpowers/sdd/task-13-logs/18-character-presentation.log` |
| `... character_locomotion_smoke.gd` | 0 | `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 smooth_turn=1 attack_lock=1 equipment_independent=1 grounding=1 shadow=1` | `.superpowers/sdd/task-13-logs/19-character-locomotion.log` |
| `git diff --check` | 0 | no output | `.superpowers/sdd/task-13-logs/20-git-diff-check.log` |

The accepted final logs contain zero `SCRIPT ERROR`, `Parse Error`, or `TEST_FAILURE` markers. The full suite retains established intentional negative-path `push_error` diagnostics and its shutdown leak/resource warnings. The responsive runner intentionally emits two failed-settings-promotion diagnostics. The presentation smoke retains its established dummy-renderer RID shutdown diagnostics. Those commands nevertheless reached their exact PASS markers and exited 0.

All three new runners remove their exact disposable `user://tests/passive_tree_*` roots on success and failure. The final gate APPDATA retained no child under `Godot/app_userdata/Party Forge/tests` after the processes exited.

## Safe and future-contract evidence

- The profile runner creates and selects a profile through `ProfileManager`, discovers City through the production prologue mutation, grants additional points only through `ProfileMutationService.grant_passive_points`, and allocates through `PassiveTreeMutationService`.
- Restarting reconstructed manager/store/mutation services preserves the exact point balance, City allocation, and `equipment_inventory` permanent projection.
- Replaying the stable allocation transaction returns `duplicate=true`, spends no second point, and stores only one allocation. Reusing that ID for another node returns the transaction-conflict error. An unknown-node request returns the stable progression rejection and leaves the saved profile unchanged.
- The input runner uses a disposable malformed JSON file under its test profile root. `PassiveTreeCatalog` rejects it, composed Main opens the exact `City passive tree unavailable` safe screen, and Settings, the active profile, and the arena catalog remain usable. The committed Creator/game exports are never replaced.
- The composed input runner verifies that Developer reveal does not modify `tree_visibility_progress` or allocations before an explicit mutation. It also verifies unsaved Additional Settings draft values survive the child-screen round trip.
- Existing strict registry/catalog/full-suite coverage keeps Stash Access, Field Pack, Extraction License, and Secured Loadout as typed future contracts. This milestone records their permanent unlock/discovery effects but does not instantiate stash tabs, inventory grids, extraction storage, or bring-in-gear runtime services.
- The input runner covers actual `Viewport.push_input` mouse selection, middle/right drag, wheel zoom, device-0 left-stick linked navigation, right-stick continuous pan, trigger zoom, controller allocation/refund/cancel, keyboard allocation/confirmation, keyboard close, and both levels of focus restoration.
- The responsive runner measures real `Control.get_global_rect()` geometry in live `SubViewport` layouts at 1920x1080, 2560x1440, and 3840x2160. It verifies the frame/canvas/detail/points header, reachable confirmation buttons, linked navigation to `hero-registry`, and panning that far node into the clipped canvas.

## Manual approval matrix

No live rendered interaction was witnessed for this Task 13 execution. Automated real-input and real-layout evidence does not replace the user's visual/feel approval.

| # | Manual validation | Result |
| ---: | --- | --- |
| 1 | Create/select a disposable profile in a rendered build. | `PENDING USER RENDERED VALIDATION` |
| 2 | Confirm left-stick cardinal and diagonal movement in the arena. | `PENDING USER RENDERED VALIDATION` |
| 3 | Confirm Controls displays the left-stick bindings. | `PENDING USER RENDERED VALIDATION` |
| 4 | Enable Developer Mode and open City Passive Tree from Additional Settings. | `PENDING USER RENDERED VALIDATION` |
| 5 | Test mouse pan, wheel, selection, and keyboard allocation controls. | `PENDING USER RENDERED VALIDATION` |
| 6 | Test controller navigation, right-stick pan, trigger zoom, allocate, refund, and back. | `PENDING USER RENDERED VALIDATION` |
| 7 | Confirm full Developer reveal does not change saved visibility. | `PENDING USER RENDERED VALIDATION` |
| 8 | Allocate a valid node, restart, and confirm persistence/point balance. | `PENDING USER RENDERED VALIDATION` |
| 9 | Confirm Extraction License explains both prerequisites. | `PENDING USER RENDERED VALIDATION` |
| 10 | Confirm Stash, Inventory, Extraction, and Bring-In Gear say Coming Soon instead of opening storage UI. | `PENDING USER RENDERED VALIDATION` |
| 11 | Open the safe unavailable screen with a disposable invalid fixture and confirm arena/profile/Settings remain usable. | `PENDING USER RENDERED VALIDATION` |
| 12 | Repeat rendered readability/layout checks at 1080p, 1440p, and 4K. | `PENDING USER RENDERED VALIDATION` |

## Repository and generated-file preservation

- Task 13 started from clean isolated head `3fae139`. Its planned tracked scope is exactly the three integration runners plus this document; no production file changed.
- Before Task 13's first import, the worktree had zero untracked `.uid` and `.import` sidecars. Verification generated 123 `.uid` and 591 `.import` files (714 total) inside the isolated worktree. A scoped `git clean -f -- '*.uid' '*.import'` removed exactly those 714 generated files after a dry run reported the same count. Final untracked sidecar counts are zero. They are reproducible by a future Godot import.
- No worktree-contained headless Godot process remained after the gate. The user's live editor process was not targeted or stopped.
- The live main checkout was inspected read-only. Both the pre-finalization and immediate pre-commit snapshots were branch `main`, HEAD `e27323fb10d77750507df38abfd5b64a2c3aafbb`, 813 porcelain entries (101 tracked changes and 712 untracked), with ordered-status SHA-256 `4361e2de3753946781e1d364415d3d192206088689c9efbe40fc1da2ea036e27`. There was no observed drift between those snapshots. If concurrent work changes live main after this evidence point, that later drift is external and must not be attributed to this isolated task.

## Explicit deferred scope

- **Plan 3A - Functional Main Menu:** production Play, Settings, Quit, profiles, passive-tree routing, returning-player routing, and Developer Quick Start.
- **Plan 3B - Cinematic Prologue Presentation:** final city backdrop, city/house camera flight, body transition, tutorial transition, and asset-pipeline presentation.
- **Plan 4 - Per-Profile Run Context and First Services:** squad contexts, distance-gated rewards, inventory seams, the first 100-slot stash tab, extraction, and ownership-safe item transfer.

These are not claimed by this milestone.
