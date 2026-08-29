# Equipment Preview Headless Test Contract Design

Date: 2026-08-28

## Problem

`tests/unit/test_equipment_inventory_ledger_page.gd` mounts the equipment page directly beneath the headless test root. That root is not effectively visible, so `CharacterEquipmentPreview._sync_rendering()` correctly keeps its `SubViewport` at `UPDATE_DISABLED`. Two older assertions still expect `UPDATE_ALWAYS` after activation and reactivation, causing the only two full-suite failures.

The production lifecycle is already correct. The focused unit test proves that activation builds the selected member presentation, deactivation frees it, and reactivation builds a new presentation with the same equipment. Separate integration runners prove that an effectively visible preview and a real visible equipment-ledger page use `UPDATE_ALWAYS`, suspend when hidden or deactivated, and resume when shown or reactivated.

## Decision

Correct the two stale unit-test expectations. In the invisible headless fixture:

- activation must build the selected member presentation while keeping rendering `UPDATE_DISABLED`;
- deactivation must free the presentation and keep rendering `UPDATE_DISABLED`;
- reactivation must build a new correctly equipped presentation while keeping rendering `UPDATE_DISABLED`.

Visible rendering remains an integration-level contract. No production script, scene, resource, or rendering behavior changes.

## Alternatives Rejected

1. Move the assertions out of the unit test entirely. This is valid but loses useful local documentation that actor lifecycle and render scheduling are separate concerns.
2. Convert the entire page test to an asynchronous visible-window integration test. This duplicates existing integration coverage and makes a broad transaction test slower.
3. Make page activation override effective visibility. This would render invisible or detached previews, duplicate lifecycle authority, and contradict the visibility-gated production contract.

## Test-Driven Implementation

The current focused failure is the RED proof: both stale assertions report `expected 4, got 0` while all actor lifecycle assertions pass.

The minimal GREEN change updates only those two expectations and their messages. Verification must run:

1. `tests/unit/test_equipment_inventory_ledger_page.gd` through the focused runner;
2. `tests/integration/character_equipment_preview_visibility_runner.gd`;
3. `tests/integration/equipment_ledger_preview_runner.gd`;
4. the complete test suite.

Acceptance requires all four commands to pass, no production-file diff, no weakened actor/equipment assertions, a clean `git diff --check`, and a clean worktree after commit.

## Scope and Risk

Scope is exactly one test file and two expectation/message updates, plus this design and the implementation plan. Risk is low because production bytes remain unchanged and two independent real-SceneTree runners continue to own visible rendering behavior.
