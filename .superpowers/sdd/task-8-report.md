# Task 8 Report: Deterministic Developer Item Sandbox State

## Scope

Implemented only Plan 4B Task 8 on `feat/plan-4b-item-ownership` from parent `90150ee36e0ac45c748c2292af241448cf62832f`.

Created:

- `scripts/dev/developer_item_fixture_issuer.gd`
- `scripts/dev/developer_item_sandbox_state.gd`
- `scripts/dev/developer_item_sandbox_store.gd`
- `tests/unit/test_developer_item_sandbox_state.gd`

No Task 9 UI, Player Mode routing, Task 7 source, future extraction/loadout documentation, profile-manager bootstrap path, or normal profile implementation was changed.

## Implementation Result

- Reset issues all 99 equipment definitions in exact catalog order through `ItemInstanceIssuer` under namespace `sandbox:developer-item-sandbox`.
- Item level is `1 + (index % 100)` and rarity is `functional_rarity_ids()[index % 5]`.
- Deterministic fixture affixes use catalog definitions, explicit tiers and operations, and a clamped midpoint roll inside each authored tier.
- Canonical containers are `developer-inventory` with capacity 5 and `developer-stash-000` with capacity 100.
- All 99 initial placements are applied through Task 4 create transactions. The construction-only journal is discarded after the candidate is complete; the persisted mutation journal starts empty.
- The persisted document contains sandbox schema version, fixed owner, strict ownership state, issuance metadata, and the Task 4 mutation journal through `AtomicJsonStore` at `user://developer_item_sandbox/sandbox.json`.
- Successful writes commit the JSON-normalized document, so in-memory values, persisted values, reload projections, and deterministic hashes agree exactly.
- Mutation journal integrity requires entry count equal to `next_transaction_sequence`, canonical zero-padded sequence transaction IDs, current ownership equal to the final journal state, and exact canonical reset placement when the journal is empty.
- Public ownership projections and serialized documents are defensive copies.
- Save, reload, movement, reset, malformed/corrupt rejection, atomic failure, Task 4 replay, and Task 4 collision preserve the required state and byte boundaries.

## RED-GREEN-REFACTOR Evidence

### Initial RED

Command:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <task-8-worktree> --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd
```

Accepted result:

- Exit `1`.
- `TEST_SUMMARY: FAIL (3 failures)`.
- The three failures were intentional assertions for the absent fixture issuer, sandbox state, and sandbox store resources.
- There were no parser, script, loader, or resource failures in the accepted RED run.

One earlier test attempt was rejected as RED evidence because the test itself contained parser/type-inference errors and emitted no trustworthy summary. Those test errors were corrected before the accepted RED run.

### GREEN and Refactor

- A fresh Godot import exited `0` and registered the three new global classes.
- An initial post-import GREEN found a real float-bound persistence failure. Boundary fixture rolls were replaced with clamped authored-tier midpoints.
- The next GREEN found pre-JSON in-memory floats differed from the stored JSON-normalized representation. Successful reset and transaction commits now adopt the validated JSON-normalized document.
- First valid GREEN exited `0` with `TEST_SUMMARY: PASS (0 failures)` and marker `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe`.

### Strict Journal Integrity RED-GREEN

- RED exited `1` with exactly two focused failures: a journal-count/next-sequence mismatch was accepted, and a rewound ownership snapshot matching an earlier journal entry was accepted.
- GREEN exited `0` after requiring matching count, canonical sequence IDs, and current ownership equal to the final serialized journal entry.
- A follow-up RED exited `1` with exactly one focused failure for a noncanonical moved state carrying an empty journal and sequence zero.
- GREEN validates an empty journal against exact deterministic issued items and canonical reset placement.

## Determinism Gate

The final focused Task 8 suite ran twice after all production and test changes:

```text
TASK8_FINAL_FOCUSED_RUN_1_EXIT=0
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (0 failures)

TASK8_FINAL_FOCUSED_RUN_2_EXIT=0
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
TEST_SUMMARY: PASS (0 failures)

TASK8_FINAL_DETERMINISM_MATCH=YES
```

Neither final focused run emitted unexpected parser, script, loader, or resource failures.

## Required Regression Gate

The focused regression batch covered:

- item instance codec and deterministic issuance;
- canonical ownership state;
- Task 4 transaction matrix;
- atomic profile store;
- profile item-schema migration and profile state;
- profile manager and mutation persistence;
- profile storage reconciliation and item storage service;
- passive-tree storage integration;
- Task 7 run item ownership.

Result:

```text
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (0 failures)
TASK8_REQUIRED_REGRESSION_EXIT=0
```

The atomic/profile suites emitted their established intentional corruption, promotion-failure, cleanup-debt, and filesystem-failure diagnostics while returning the passing summary.

## Complete Suite

Command:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <task-8-worktree> --quit-after 720 --script res://tests/test_runner.gd
```

Result:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (129 suites)
TASK8_FULL_SUITE_EXIT=0
```

The complete suite emitted existing intentional negative-test warnings/errors and the established exit-time leak diagnostics. It emitted no unexpected parser, script, loader, or resource failure for Task 8 and exited `0`.

## Isolation and Artifact Evidence

- Production Task 8 sources contain no `ProfileManager` reference and never call `ProfileManager.bootstrap()`.
- The sandbox document path does not begin with `ProfileStore.DEFAULT_ROOT`.
- The focused test preserves a per-process sentinel under the normal profile root across reset and injected sandbox-save failure, proving normal profile bytes are unchanged.
- The required fresh import generated 12 previously absent untracked `.gd.uid` files. Baseline status proved they were verification-created; all 12 were removed and none is intended for the Task 8 commit.
- Final staging is limited to the three Task 8 source files, the focused Task 8 suite, and this report.

## Review Boundary

Commit message: `feat: add deterministic developer item sandbox state`

Stop after the focused Task 8 commit for independent review. Task 9 has not started.
