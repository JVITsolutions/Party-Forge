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

## Second-pass review fixes

Second-pass starting head: `c50a28d931cc03520148f440ea76578302d5583e`

This follow-up remained inside the approved Main, Developer Mode badge, world controller, Character Ledger, and directly corresponding existing runner/test scope. No generic transaction, ownership, equipment, or generic report file changed.

### Controlled RED

- Main/badge RED produced 8 intended failures: ineligible outcomes incorrectly inflated `ROLL MISS`, stable ineligible reason/source categories were absent, and Main/badge had no production projection status.
- Ledger RED produced 110 intended failures across every region and all 24 roster members because the directional neighbor graph was not closed.
- Moving-camera RED used 2,000 ordinary records plus late-sorting selected, mouse-hovered, and focus-inspected records. It failed only the intended same-frame critical refresh and absent production signal/peak-work contracts after fixture/input-dispatch corrections.

### Implementation

- Camera/viewport invalidation reserves the existing 32-record frame budget for selected, hovered, and focus-inspected IDs first, removes them from ordinary/dirty queues to avoid duplicates, and spends remaining capacity on queued records. Work remains bounded and late ordinary records still converge.
- The controller publishes runtime projection diagnostics (`pending`, `last_frame_work`, retained `peak_work`, and `limit`). Main consumes that signal, and the Developer Mode badge presents the live values. The recorded work includes critical and ordinary projections; the runner's `Performance.TIME_PROCESS <= 33.4ms` hard gate remains unchanged.
- Character Ledger now installs explicit top/bottom/left/right boundary bridges while preserving local roster-grid and equipment/inventory navigation. The directional graph is closed across every visible roster member, every tab, Close, every equipment slot, and every inventory cell.
- Main records misses only for eligible unsuccessful decisions. Ineligible outcomes have a separate session total plus stable reason and source buckets, all rendered by the session-only badge.

### Second-pass verification

- Focused affected gate (15 suites): `TEST_SUMMARY: PASS (0 failures)` with no parse/load/leak marker.
- Actual viewport pickup: all mouse, controller, full-inventory, foreign-owner, and overall integration markers passed.
- Ledger responsive integration: all three resolution markers, member 24, and `TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: PASS (0 failures)` passed. The unit graph check traverses actual `focus_neighbor_top/bottom/left/right` paths from every focusable control to every other focusable control.
- Lifecycle and multiplayer markers: `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS` and `LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: PASS`.
- Moving-camera/viewport performance: 2,003 total records; late selected/hover/focus anchors and leader-relative distances refreshed in the invalidation frame; late ordinary work converged; peak frame `0.035ms`; peak work `32`; peak pending `1942`; settled in `71` frames; memory marker present; `LIVE_LOOT_PERFORMANCE_SUMMARY: PASS`.
- Final isolated full suite: `TEST_SUMMARY: PASS (201 suites)` with no parse/load/leak marker.
- Cold acceptance evidence was not rerun or modified.

### Second-pass self-review and commit

- `git diff --check` passed. Review found bounded combined work, no duplicate critical/ordinary projection, no injected Boolean diagnostic substitute, no test-only production API, no private-method integration shortcut, and no unrelated production/report edit.
- Commit message: `fix: prioritize loot interaction state`.
