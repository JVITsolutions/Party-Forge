# Task 6 Report: Living Forge Level-Up Flow

Status: implementation and scoped verification complete on `feat/living-forge-combat-loop-ui`. Task 7 work was not started.

## Scope and contracts

- Exact starting HEAD: `5108276637dedae3e77f1b96d974e6bbfbb8cbaf`.
- `UpgradeCard` now receives copy-owned `UpgradeOfferProjection` values and exposes only a stable `StringName` choice key. Reveal previews cannot replace activation identity, and no leaf card retains an exact mutable `UpgradeChoice`.
- `LevelUpPanel` owns the private key-to-exact-choice authority and explicit `REVEALING`, `CHOOSING`, `CHOOSING_RECIPIENT`, `CONFIRMING`, and `PENDING` states. One `application_requested(choice, member_id)` signal covers direct, recipient-confirmed, and recruit-confirmed routes.
- Direct choices enter visible `PENDING` immediately. Recipient choices retain all 24 stable member IDs, useful ineligible reasons, and exact before-to-after confirmation. Recruit choices use class-specific context confirmation.
- Duplicate pending input is suppressed. Cancel or application failure returns to the exact initiating card with the exact readable reason. Empty offers show named recovery without a phantom card, and no-eligible recipient flows default to Cancel.
- Main retains authoritative mutation through `_apply_choice_for_member`, performs fresh `LevelUpApplicationPolicy` validation, and returns one typed result through the unified panel seam. Accepted queued levels remain paused and modal-visible; the final accepted level restores deterministic gameplay focus.
- The bounded five-card modal uses the shared `LivingForgeThemeCatalog`, normal/high-contrast and UI/text scales, reduced-motion behavior, 48-pixel actions, a blocking backdrop, semantic accessibility copy, and a neutral forge fallback icon plus category text. Compact density preserves effect, scope, rank, eligibility, and action meaning.
- Removed legacy card dictionary/exact-choice binding and panel `choice_selected`/`confirmation_requested` routes only after migrating callers. `test_upgrade_tooltip_ui.gd` and `test_foundational_upgrade_presentation.gd` were retained callers that required stable-key/path migration in addition to the task's initially listed tests.
- Excluded: tactics/gambits, Task 7+, Task 14 aesthetic screenshots, push, merge, plan edits, and progress-ledger edits.

## Strict TDD evidence

All Task 6 RED changes across the three unit suites and three integration runners were authored before production edits.

- Focused typed reveal/card, panel state-machine, and Main wiring RED: exit `1`; `TEST_SUMMARY: FAIL (3 failures)`. Failures were limited to the absent typed card binding, unified state machine, and Main application result seam.
- Five-card geometry RED: exit `1`; `LEVEL_UP_FIVE_CARD_SUMMARY: FAIL (1 failures)`.
- Recipient controller/scroll RED: exit `1`; `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: FAIL (1 failures, 3 viewports)`.
- Unified commit-flow RED: exit `1`; `LEVEL_UP_COMMIT_FLOW_SUMMARY: FAIL (1 failures)`.

No RED command contained an unrelated assertion failure. During GREEN, the first real geometry run exposed all five reveal base positions being captured before the hidden HBox's first sort. Restoring the prior one-shot `sort_children` handshake with typed projections fixed only that timing boundary. The commit runner then exposed queued final-focus theft by an obsolete deferred card focus; deferred offer focus is now conditional on the modal remaining visible and choosing.

## Final Task 6 GREEN gates

- Full headless editor import: exit `0`.
- Exact eight-suite unit command (`test_upgrade_offer_projection`, `test_level_up_application_policy`, `test_upgrade_choices`, `test_upgrade_presentation`, `test_foundational_upgrade_presentation`, `test_level_up_reveal_controller`, `test_level_up_targeting_ui`, `test_main_wiring`): `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Five-card real geometry at `1280x720`, `1920x1080`, `2560x1440`, and `3840x2160`: four size-pass markers, `LEVEL_UP_FIVE_CARD_SUMMARY: PASS (4 sizes)`; exit `0`.
- 24-member recipient selection/scroll at three viewports: `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)`; exit `0`.
- Direct/recipient/recruit application, duplicate suppression, exact cancel/failure, no-choice recovery, queued no-unpause, and final focus: `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)`; exit `0`.
- Retained popup mouse/keyboard/controller behavior at four viewports: `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)`; exit `0`.

The focused unit commands retain their established negative-path `push_error` diagnostics while ending with the exact PASS marker and exit `0`. The three Task 6 integration runners complete without parser or loader failures.

## Proportional retained verification

- Related Task 5/progression suites (`test_upgrade_definition`, `test_upgrade_catalog`, `test_upgrade_application`, `test_character_upgrade_integration`, `test_level_up_targeting_ui`, `test_level_up_reveal_controller`, `test_upgrade_tooltip_ui`): `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Task 4 HUD/Main/PartyManager suites: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Task 4 party scale/geometry: `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`; exit `0`.
- Task 4 input routes: `COMBAT_HUD_INPUT_SUMMARY: PASS`; exit `0`.
- Progression arena: `PROGRESSION_ARENA_PROFILE_IMMUTABLE ... values_equal=true bytes_equal=true`, then `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`; exit `0`.
- Responsive retention: four `RESPONSIVE_GEOMETRY_SIZE_PASS` markers and `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`; exit `0`.

## UID, integrity, and boundaries

- The checked-in `Resolve-GeneratedUidState` classifier was redeclared and invoked with exactly `tests/integration/level_up_commit_flow_runner.gd.uid`: `TASK6_UID_CLASSIFIER=PASS intended=1 unexpected=0`; exit `0`.
- Import regenerated unrelated sidecars only for previously tracked scripts. Those observed untracked import byproducts were removed by exact path; the one Task 6 UID was retained.
- `git diff --check` exited `0` before report creation and is repeated after staging.
- Historical `.superpowers/sdd/task-6-report.md` remains byte-identical at blob `d35c6c18ea8c059310edf258f74022edee1fafb5`.
- No production test-only diagnostic method was added. Main remains the mutation authority, and Task 6 adds no tactics, terminal, result-screen, or asset-generation behavior.
