# Plan 4B Task 6 report: passive storage reconciliation and persistent transactions

Status: implementation and local verification complete on `feat/plan-4b-item-ownership`. Task 7 was not started.

## Scope and contracts

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan-4b-item-ownership`.
- Base: `c663b5e` (`docs: define persistent item storage contract`).
- Added `ProfileStorageReconciler`, which validates allocation strings and resolved profile stash contracts, computes the complete proposal before assignment, materializes exact stable 100-slot tabs, validates the final ownership document through Tasks 2/3, and never shrinks or rewrites existing storage/item placement.
- Added `ProfileItemStorageService`, which uses `ProfileMutationService` as the durable journal, a new ephemeral Task 4 journal inside each candidate, and the complete canonical item request as the outer fingerprint source.
- Create requests require the exact `profile:<profile_id>` origin namespace and current integral sequence; the sequence advances once only with a successful atomic commit. Replays, collisions, Task 4 failures, validation failures, and save failures consume no sequence and expose no partial profile.
- Added the reconciler as an optional production-default dependency of `PassiveTreeMutationService`. Permanent allocation reconciliation runs after permanent-effect projection inside the same profile candidate, so a reconciliation error aborts points, allocations, unlocks, storage, journal, and file writes together.
- The future extraction-policy requirement remains outside Task 6 and was not implemented.

## RED evidence

The tests were authored before the production scripts. Focused RED runs produced the intended missing-feature diagnostics and no PASS summary:

```text
Identifier "ProfileStorageReconciler" not declared in the current scope.
Identifier "ProfileItemStorageService" not declared in the current scope.
Could not find base class "ProfileStorageReconciler".
```

The focused runner's missing-suite exit behavior is unreliable, so the missing-type parse diagnostics and absence of a PASS summary, rather than the process exit alone, are the accepted RED evidence.

## Coverage

`test_profile_storage_reconciler.gd` covers:

- empty, Field Pack, Stash Access, combined, and duplicate saved allocations;
- exact one-column/five-slot projection and exact `stash-tab-000` schema/owner/kind/capacity/slots contract;
- repeated byte-equivalent reconciliation, monotonic columns/tabs after allocation removal, and preservation of a pre-existing item at slot 42;
- null dependencies, malformed allocation data, nonpositive/fractional/unsafe stash counts, the 100-tab cap, incorrect `slotsPerTab`, stable-ID collision, and invalid existing ownership with byte-equivalent input on every applicable error;
- summing only profile-scope storage while malformed non-profile contracts are ignored.

`test_profile_item_storage_service.gd` covers:

- persistent create/reload with one item and exact slot placement;
- durable outer replay with `duplicate = true` and no primary-file hash change;
- same-ID/different-request collision with no write;
- exact complete-canonical-request fingerprinting;
- owner, origin namespace, origin sequence, sequence exhaustion, duplicate instance, and invalid destination rejection;
- injected atomic promotion failure, no partial profile, and no sequence consumption;
- non-create sequence preservation and exact move placement;
- defensive request documents plus successful/replayed profile projections that cannot mutate saved state.

`test_passive_tree_mutation_service.gd` now proves successful Stash Access allocation materializes the exact tab and an injected reconciliation failure leaves profile bytes, Passive Points, allocations, permanent unlocks, storage, and outer journal unchanged.

## Verification evidence

All focused commands used Godot 4.7.1 and exited `0`:

- New reconciliation/storage plus Task 3/4 ownership batch: `ITEM_TRANSACTION_MATRIX: PASS`; `TEST_SUMMARY: PASS (0 failures)`.
- Passive effect/progression/mutation batch: `TEST_SUMMARY: PASS (0 failures)`.
- Profile state/migration/mutation/manager batch: `TEST_SUMMARY: PASS (0 failures)`.
- Atomic profile store batch: `TEST_SUMMARY: PASS (0 failures)`.

The profile and atomic batches emitted only their existing asserted filesystem-failure, corrupt-generation-preservation, and cleanup-debt diagnostics.

Fresh hermetic import used worktree-local `APPDATA` and `LOCALAPPDATA`: exit `0`, 21 captured lines, zero warnings, and zero script/parse/loader/engine-error markers.

Fresh hermetic full suite: exit `0`, 538 captured lines, zero `TEST_FAILURE`, script, parse, or loader markers, and:

```text
TEST_SUMMARY: PASS (127 suites)
```

All 48 error lines and eight warning lines were inspected. They are intentional existing negative-path diagnostics and established shutdown noise; none originates from the new Task 6 services. The existing 18 leaked `ObjectDB` instances and five resources-still-in-use shutdown diagnostics remain.

## Hygiene and concerns

- `git diff --check` is clean.
- Import/full-suite verification created seven untracked test `.gd.uid` sidecars; only those verification-created test UIDs were removed. The two production-script UIDs remain scoped artifacts.
- No open Task 6 production-code concern is known; the one rejected engine-shutdown verification anomaly is documented below.

## Review correction: persistent operation policy

Sequential review found that the initial wrapper forwarded Task 4's `sandbox_remove` operation and could therefore persist item destruction in a production profile. Task 4 correctly owns that operation for disposable sandbox teardown, but Plan 4B does not authorize profile destruction, discard, or extraction.

The correction added a positive persistent-operation whitelist containing only `create_and_place`, `move_to_empty`, and `swap_occupied`. Any other request operation now fails before the durable profile mutation boundary with:

```text
PARTY_FORGE_PROFILE_ITEM_STORAGE_ERROR field=request.operation reason=unsupported persistent operation <operation>
```

Correction RED exited `1` with `TEST_SUMMARY: FAIL (9 failures)`. The failures proved that `sandbox_remove` had returned success, exposed a committed profile, removed the item and exact slot, changed file bytes/hash, and recorded a durable transaction.

Correction GREEN and final evidence:

- Focused storage/Task 4 ownership/profile mutation/atomic-store batch: exit `0`, 55 captured lines, zero test/script/parse/loader failure markers, `ITEM_TRANSACTION_MATRIX: PASS`, and `TEST_SUMMARY: PASS (0 failures)`.
- The first post-correction full run reached `TEST_SUMMARY: PASS (127 suites)` with zero test/script/parse/loader failures, then produced Windows access-violation exit `-1073741819` during engine shutdown before the established leak diagnostics. It was rejected as completion evidence.
- Exact hermetic full-suite retry: exit `0`, 538 captured lines, zero test/script/parse/loader failure markers, and `TEST_SUMMARY: PASS (127 suites)`. The established 48 intentional error lines, eight warnings, 18 leaked `ObjectDB` instances, and five resources-still-in-use diagnostics were inspected.
- No verification-created test UID sidecars remained after the correction runs.

The regression proves the stable error, no partial profile, byte/hash equivalence, preserved item record and slot 37, unchanged `next_item_sequence`, and absence of a durable journal entry. Task 7 and future extraction behavior remain untouched.
