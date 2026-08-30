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

## Review repair from `f1c5538`

The review repair remained inside Task 6. It added no Task 7 work and did not push or merge.

### Repaired contracts

- `LevelUpPanel` now ignores activation unless the modal is visible, the offer view is active, and the state is `CHOOSING`. A stale card signal after final success therefore cannot reactivate the hidden panel.
- Main independently requires a pending level, `LEVEL_UP` run state, and the live `PlayerRunContext` source-refresh authority before any upgrade mutation. An accepted mutation consumes exactly one pending level; a lost authority is rejected before mutation and returns a player-readable reason through the unified result seam.
- Offer cards and long card content now live in a bounded horizontal/vertical `CardsScroll`. Valid 1-, 5-, 7-, and 8-offer presentations remain reachable at `1280x720` with UI/text scales `150/150` and `80/150`. Confirmation prose owns a bounded `BodyScroll`, while Confirm/Cancel remain fixed and reachable.
- Cards render the approved semantic order and include recipient/class tags, rarity, route action, normalized reviewed icons, and neutral forge fallback only for empty or unknown icon IDs. Accessibility names include rarity, semantic content, tags, and route action.
- Recipient and recruit confirmation enter a visibly named `PENDING` state with focus moved off the hidden Confirm control to the initiating visible card. Duplicate intent remains blocked.
- Both Task 13 natural-combat validation scripts were migrated from the deleted `Choices` node to real `UpgradeCard` controls plus the unified recipient and confirmation routes. Their static route assertions are part of `test_main_wiring`, and full editor import parsed both scripts. The long-running evidence-writing Task 13 natural-combat acceptances were not replayed as part of this focused UI repair.

### Repair RED evidence

All repair test changes were authored before repair production changes.

- Main authority and stale Task 13 callers: exit `1`, `TEST_SUMMARY: FAIL (11 failures)`; three failures proved lost-authority mutation/pause/error behavior and eight proved the two legacy Task 13 callers.
- Responsive retained contract: exit `1`, `TEST_SUMMARY: FAIL (7 failures)` after stale pre-Task-6 paths were migrated; the remaining failures were only the missing offer and confirmation scroll contracts.
- Upgrade-card semantic/icon contract: exit `1`, `TEST_SUMMARY: FAIL (3 failures)` for semantic order, tags, and normalized icon/fallback behavior.
- Commit flow: exit `1`, `LEVEL_UP_COMMIT_FLOW_SUMMARY: FAIL (4 failures)` for target/recruit pending focus, hidden stale-card mutation, and stale direct Main intent.
- Windowed geometry: exit `1`, `LEVEL_UP_FIVE_CARD_SUMMARY: FAIL (1 failures)` for the missing bounded typed offer geometry.

The first GREEN geometry run preserved the minimal failing scaled one-card case and showed that `ScrollContainer` focus-follow retained an invalid horizontal offset after initial focus. Resetting the offer scroll at presentation and reasserting the first focused card after layout was the single production handshake fix. The final geometry runner also dispatches real viewport mouse motion, keyboard Tab focus, and controller D-pad focus to `UpgradeCard`, proving identical tooltip content and real dismissal without direct handler calls.

### Repair verification

- Exact eight-suite Task 6 command: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Focused Main, responsive, and card/tooltip repair suites: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Windowed geometry: four size-pass markers and `LEVEL_UP_FIVE_CARD_SUMMARY: PASS (4 sizes)`; exit `0`. The runner also covers valid 1/5/7/8 offers, both extreme scale pairs, real tooltip input parity, and a long recipient-confirmation body with fixed actions.
- Recipient scrolling: `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)`; exit `0`.
- Unified commit flow: `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)`; exit `0`.
- Temporary popup retention: four size-pass markers and `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)`; exit `0`.
- Related Task 5/progression units, Task 4 HUD/Main/PartyManager units, Task 4 party-scale/input integrations, progression arena immutable-profile smoke, and responsive geometry all retained their exact PASS markers and exit `0`.
- Full unit suite: terminal `TEST_SUMMARY: PASS (245 suites)`; exit `0`.
- Full headless editor import: exit `0`; both migrated Task 13 scripts parsed. Import regenerated 51 unrelated missing sidecars, which were classified as previously tracked-script byproducts and removed by exact path.
- Same-process exact UID classification: `TASK6_UID_CLASSIFIER=PASS intended=1 unexpected=0`; exit `0`.
- `git diff --check`: exit `0`. Historical `.superpowers/sdd/task-6-report.md` remains blob `d35c6c18ea8c059310edf258f74022edee1fafb5`.

## Final atomicity repair from `5bc665c`

This repair remained bounded to Task 6. It added no Task 7 work and did not push or merge.

### Atomic application boundary

- The root cause was a split authority boundary: Main applied a party mutation first, that mutation synchronously emitted `upgrades_changed`, an observer could release the `PlayerRunContext` source-refresh coordinator, and the later pending-level consume then failed. The player could therefore receive the upgrade while the UI reported rejection and retained the pending level.
- `PlayerRunContext.apply_pending_leader_level_transaction(application)` now owns one non-reentrant reservation boundary. It requires the live owner and a nonempty queue, captures and verifies the exact front level, reserves that one level, invokes the mutation once, restores the exact queue on a false/non-boolean result, and commits the reservation on success even if a synchronous mutation observer releases ownership. Ordinary pending-level consumption is blocked while the reservation is active.
- Main calls that single boundary after its independent run-state, pending-level, ownership, and exact-choice validation. It remains the typed application-result authority and schedules the next offer or resumes gameplay only after the transaction reports success.
- Authentic coverage connects the real `PartyManager.upgrades_changed` signal to synchronous coordinator release during a party-stat mutation. It proves one mutation plus one level consume succeed together, the run resumes, the panel closes, and a stale card activation cannot mutate or consume again. Unit coverage also proves accepted, rejected, pre-revoked, empty/duplicate, and nested-consume cases.
- The Task 13 defeat validator now iterates the authoritative current choice count, bounds-checks retained card storage, requires visible enabled typed cards, uses visible empty-offer recovery, and emits recovery when no current choice is selectable. A real `LevelUpPanel` fixture proves a one-disabled-choice offer cannot select a hidden retained card and an empty offer activates recovery without an out-of-range access or stall.

### Final repair RED evidence

Both repair test changes were authored before production edits.

- `test_player_run_context.gd`: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for the absent transactional pending-level application boundary.
- `test_main_wiring.gd`: exit `1`, `TEST_SUMMARY: FAIL (5 failures)` for the synchronous authority-release split, retained pending/run/panel state, stale duplicate risk, and unsafe Task 13 defeat iteration.
- The failures were restricted to the two approved repair findings; production was untouched at the RED checkpoint.

### Final repair verification

- Focused `test_player_run_context.gd` and `test_main_wiring.gd`: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Exact eight-suite Task 6 command: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Windowed geometry: four size-pass markers and `LEVEL_UP_FIVE_CARD_SUMMARY: PASS (4 sizes)`; exit `0`.
- Recipient scrolling: `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)`; exit `0`.
- Unified commit flow: `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)`; exit `0`.
- Temporary popup retention: four size-pass markers and `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)`; exit `0`.
- Related Task 5/progression units, Task 4 HUD/Main/PartyManager units, Task 4 party-scale/input integrations, progression arena immutable-profile smoke, and responsive geometry retained their exact PASS markers and exit `0`.
- Task 13 defeat and victory validator parse drivers: `TASK_13_DEFEAT_DRIVER_PARSE: PASS` and `TASK_13_VICTORY_DRIVER_PARSE: PASS`; exit `0`.
- Fresh full unit suite: terminal `TEST_SUMMARY: PASS (245 suites)`; exit `0`.
- Fresh headless editor import: exit `0`. The checked-in classifier was invoked with exactly `tests/integration/level_up_commit_flow_runner.gd.uid`; after exact cleanup of 51 unrelated tracked-script sidecars it reported `TASK6_UID_CLASSIFIER=PASS intended=1 unexpected=0`; exit `0`.
- Historical `.superpowers/sdd/task-6-report.md` remains blob `d35c6c18ea8c059310edf258f74022edee1fafb5`.
