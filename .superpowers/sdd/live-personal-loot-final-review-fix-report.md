# Live Personal Loot Final Review Fix Report

Date: 2026-08-11

Branch: `feat/live-personal-loot`

Starting head: `4f6f28abd62c886dfec895e15700f2d6f6f91eae`

## Scope

This pass is limited to the seven confirmed whole-branch review findings: production owner-leader comparisons, controller inspection and stable post-pickup selection, centralized gameplay-input blocking, bounded camera/viewport reprojection, the Character Ledger Close/focus graph, and typed live-loot diagnostics.

Planned production paths are the directly implicated Main, world chest/controller, ledger scene/scripts, personal-loot coordinator/ownership result/service, and Developer Mode badge. Planned tests are the existing focused world/Main/ledger/diagnostic suites plus the existing pickup-input and 2,000-record performance runners. No unrelated scope expansion is planned. Generic reports remain untouched.

## RED evidence

- Focused grouped RED: exit 1 with 19 intended contract failures after correcting the comparison fixture; a Main-only rerun exited 1 with 5 intended failures and no test-script error.
- Main RED covered the absent real owner-leader Alt/LT card, absent central gameplay-input blocker, and incorrect untyped diagnostic accounting.
- World/ledger/coordinator/badge RED covered the dedicated comparison seam, bounded/eventual camera reprojection, missing Close control, typed diagnostic records, and explicit session-only badge wording.
- Actual viewport-dispatched pickup RED: exit 1 with 8 intended failures for focus/shared tooltip, leader-relative distance, non-color ring, persistent `Move closer`, and stable multi-chest success advancement/empty clearing.
- Moving camera/viewport performance RED: exit 1 at 2,000 records with `peak_frame_ms=276.751`, no bounded-work diagnostics, and the expected `>33.4ms` hard-gate failure.

## Implementation

- Main now configures a dedicated production comparison projector. It reads the owning run context, finds the owner leader and current applicable equipped item, stages the ground candidate in a defensive ownership-state copy, and obtains current/candidate stat snapshots through `EquipmentTransitionService.preview`; item details contain no synthetic equipment field and no profile or UI state is mutated.
- One centralized Main gameplay-input predicate now covers non-running/upgrade states plus ledger, pause, settings, armoury, warehouse, passive-tree, item-sandbox, and loadout-warning modals. World mouse/controller interaction uses that predicate.
- Controller selection now immediately projects, focuses, and presents the single shared tooltip; distance is owner-leader-relative, a Torus selection outline supplies a non-color cue, and `Move closer` remains on the retained selection. Input runs through the real viewport dispatch path.
- Successful record removal advances deterministically to the nearest remaining visible owned chest using owner-leader position and drop-ID tie-breaking; removing the last record clears selection.
- Camera/viewport invalidation now uses a stable, bounded 32-projection batch. New/selected/inspected/queried records update immediately, other records converge after motion stops, and targeting tests continue to use current world-space visibility rather than stale anchor state.
- Character Ledger now owns a visible Close button and a closed `focus_next`/`focus_previous` cycle spanning the full roster, tabs, Close, active equipment controls, and inventory controls while retaining its directional roster/page bridge, shoulder paging, cancel behavior, and member-24 focus restoration.
- Ownership failures now carry typed stage/code metadata through the coordinator. Main counts only actual `generation` diagnostics as generation failures and retains separate stage/code buckets; ordinary roll misses are separate from failures. Developer diagnostics explicitly identify their session-only lifetime and clear with the run snapshot.
- Existing generic item transaction, equipment assignment, ownership mutation, shared-tooltip, pooling, per-owner selection, and feature-policy behavior was not changed.

## Verification

- Focused final gate (11 directly affected suites): `TEST_SUMMARY: PASS (0 failures)`. No parse/load/leak marker was present; the two Main stderr messages are intentional negative-path assertions already owned by that suite.
- Actual dispatched pickup runner:
  - `GROUND_ITEM_PICKUP_MOUSE: PASS`
  - `GROUND_ITEM_PICKUP_CONTROLLER: PASS`
  - `GROUND_ITEM_PICKUP_FULL_INVENTORY: PASS`
  - `GROUND_ITEM_PICKUP_FOREIGN_OWNER: PASS`
  - `GROUND_ITEM_PICKUP_INPUT_INTEGRATION: PASS`
- Lifecycle/defeat/multiplayer regression markers passed: `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`, `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`, `PERSONAL_LOOT_XP_REGRESSION: PASS`, `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS`, and `LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: PASS`.
- Ledger integration markers passed: `TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: PASS (0 failures)` including member 24, and `TASK11_EQUIPMENT_LEDGER_PREVIEW_SUMMARY: PASS (0 failures)`.
- Moving-camera/viewport performance at 2,000 records: `LIVE_LOOT_PERFORMANCE_SUMMARY: PASS`; peak frame `0.031ms`, peak bounded work `32`, peak pending `1968`, settled in `66` frames, with `LIVE_LOOT_MOVING_CAMERA_SUMMARY` and memory markers present.
- Final isolated full suite: `TEST_SUMMARY: PASS (201 suites)`. No parse/load/leak marker was present. The suite retains its intentional validation errors and storage-cleanup warnings.
- Cold acceptance evidence was not rerun or modified.

## Self-review and commit

- `git diff --check` passed. Review found no synthetic production comparison field, test-only production API, private-method integration shortcut, UI-side item mutation, profile mutation, or unrelated generic report edit.
- Generated untracked `.uid` cache artifacts from a diagnostic editor scan were removed before staging.
- Exact tracked scope is the approved Main/world/ledger/coordinator/ownership/badge files and their directly corresponding unit/integration runners, plus this unique report. Generic reports remain untouched.
- Commit message: `fix: complete live loot interaction contracts`.
