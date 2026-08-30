# Task 10 Living Forge Terminal Flow Report

## Scope

- Exact base: `50be00cc8448c55ec79ccd0f27051a6185c81d98`.
- Task: once-only terminal flow, durable recovery/sanitation, schema 6, recovery overflow ownership, and bounded Armoury/Main overflow routing.
- Explicit exclusions: Task 11 result/recap UI, Task 12 boot/lifecycle cutover beyond overflow routing, tactics, push, merge.
- Historical `.superpowers/sdd/task-10-report.md` must remain blob `95a538c9668fa8e6381166dc8c488b502956cd31`.

## TDD Chronology

### Initial RED

Before any production edit, the exact focused Task 10 batch exited `1` with `TEST_SUMMARY: FAIL (34 failures)`. There was no parser, loader, or harness noise. The failures named missing terminal flow/recovery types, schema 6/default migration, irreversible completion surface, overflow ownership/projection/Armoury/Main routing, and terminal-only resolution.

This initial batch was too surface-heavy for the later architecture audit's full durability matrix.

### Expanded post-audit RED

After partial production work limited to schema/container/codec/migrator and recovery value/codec/result types, production work stopped. The tests were expanded for durable capture/picker gating/duplicate begin; selection persistence, terminal-only resolve, cold resolved resume, finalize receipt retention; distinct retry states; strict recursive schema 6; recovery persistence/completion/protection transaction identities; irreversible sanitation authority; overflow storage/projection/Armoury/Main routing; and terminal-only resolve.

The exact focused batch then exited `1` with `TEST_SUMMARY: FAIL (36 failures)`, again with no parser, loader, or harness noise. The schema 6 portion was already partially green at this point; all other named Task 10 surfaces remained red. This chronology is intentionally not presented as a production-untouched full-matrix RED.

### Behavioral RED expansion, stage A

The surface probes were replaced with executable behavioral fixtures for persistence/retry/no-write identity, canonical selection transactions, terminal-only resolution, cold recovery, projection retry call counts, strict recursive migration and codec behavior, typed safety mismatch tables, irreversible sanitation and committed-retry verification, populated overflow protection/drain/ownership preservation, real Armoury focus/input policy, and real Main service routing.

With production still paused after the earlier partial schema/type work, the exact focused batch exited `1` with `TEST_SUMMARY: FAIL (25 failures)`. Missing `RunTerminalFlow` and `RunTerminalRecoveryService` still guarded several behavioral bodies; Main likewise stopped at the missing required resources. The run otherwise reached concrete overflow, ownership, fingerprint, irreversible-sanitation, and UI projection failures. One known partial-production runtime defect remained at `run_terminal_recovery_codec.gd:62`, where an inferred untyped array was passed to a typed exact-field validator.

The approved next TDD rung is intentionally limited to typed public-surface skeletons and that codec type repair, solely so every behavioral body can execute before any real implementation logic is added.

### Behavioral RED expansion, stage B

Typed constructor/public surfaces and the codec array-type repair were added. This first Stage-B skeleton also contained in-memory capture identity, projection, selection/request construction, resume, and candidate-record behavior. The final architecture audit correctly rejected that as premature first-execution GREEN behavior even though it performed no durable terminal mutation, terminal resolution, overflow movement, sanitation, Armoury, or Main routing.

After importing the intended new global classes and correcting test-only typed-array call shapes, the exact focused batch exited `1` with `TEST_SUMMARY: FAIL (66 failures)`. There was no parser, loader, runtime-script, or harness noise. Missing-class skips were zero. Three deeper bodies stopped at their first authentic dependency failure: the resolved one-field mismatch table awaited a durable resolved receipt; the real Armoury protected/input/focus body stopped because populated-overflow projection was rejected; and Main's real service-spy routing body stopped at the same projection rejection. All other behavioral groups executed and failed at their durability, retry, sanitation, overflow ownership, fingerprint, transition, or state-machine assertions.

### Final behavior-level RED gate

The two new Stage-B classes were pared back to typed constructors, queries, and default failure returns only. Capture/checkpoint identity and state transitions, extraction projection, selection validation and canonical SHA/request construction, resume reconstruction, projection/finalize transitions, and recovery record/checkpoint candidate construction were removed before the final RED. Approved constructor dependency-injection surfaces remained production-safe and the pre-existing generic resolver continued to use its default evaluator.

The behavioral suites then added failed initial retry, zero capacity, duplicate Confirm reuse, identical resolution retry/once-only delegation, choosing/selected/interrupted cold resume, automatic-only Protect/repreflight, reducible interruption, repeated projection retry, defensive accepted-result queries, post-finalized transition rejection, exact completion service and argument/storage failures, zero-item sanitation, codec stage combinations, partial-overflow/protection failure cases, occupied-target rejection, duplicate ownership decoding, numeric overflow-capacity exclusion, and unprotected overflow-to-leader UI rejection.

The exact 17-suite focused command, captured in terminal session `5191`, exited `1` with `TEST_SUMMARY: FAIL (92 failures)`. There was no parser, loader, missing-class, runtime-script, or harness noise. Failure grouping was: flow state/durability/retry/cold-resume/protection/projection/finalize `32`; recovery codec/migration/storage/capture/safety/completion/protection/sanitation `48`; terminal evaluator overflow/capacity `2`; strict irreversible AtomicJsonStore authorization `1`; reconciliation overflow ownership `1`; assignment fingerprint/projection `2`; compatibility/transition `3`; checkout `1`; real Armoury projection/input `1`; and Main real routing `1`.

In session `5191`, the remaining short-circuits were explicit RED markers rather than hidden skips: default-failure `begin()` blocked the deeper flow retry/cold-resume/protect/reducible bodies; absent accepted truth blocked the defensive result body; absent durable receipts blocked the pre/resolved safety mismatch bodies; stub inspection blocked the original protection happy path; and populated-overflow projection rejection blocked the later Armoury/Main instance assertions. Direct completion and protection failure matrices executed independently of those paths. The safety short-circuits were removed in the corrected gate below.

### Corrected direct-safety RED

The architecture reviewer found that the pre- and post-resolution safety mutation tables still depended on the unimplemented flow, so their deeper cases had not executed in session `5191`. Independent, structurally valid durable fixtures replaced that dependency. The direct pre-resolution fixture executes all `21` one-field mutations covering receipt and strict-bootstrap identity, outcome, member/source, item record, container, slot, selection, transaction, and stage. The direct resolved fixture executes all `20` one-field mutations covering its own identity/outcome/stage, member/source/item/container/slot, record and accepted selections, record/applied transactions, and durable registry/stash/leader-loadout/overflow placement. Their exact-pass assertions remain RED at the typed safety stub; both exact execution-count assertions pass, with zero safety-matrix short-circuits. Structurally valid receipts with a missing or mismatched applied-resolution transaction also execute and remain write-free while failing for the missing applied-specific rejection.

The corrected recovery-safety focused suite exited `1` with `TEST_SUMMARY: FAIL (47 failures)`. The corrected exact 17-suite run in terminal session `91599` exited `1` with `TEST_SUMMARY: FAIL (91 failures)`: flow `32`, recovery `47`, preflight `2`, AtomicJsonStore `1`, reconciler `1`, assignment `2`, transition `3`, checkout `1`, Armoury `1`, and Main `1`. There was no parser, loader, missing-class, runtime-script, or harness noise. This corrected run supersedes session `5191` as the final behavior-level RED gate.

## Architecture Scope Corrections

- Strict terminal completion requires a verified irreversible AtomicJsonStore/ProfileStore path; a committed duplicate must re-verify/sanitize before navigation authorization.
- Overflow participates in `LoadoutCompatibilityProjection.state_fingerprint_for`.
- `ArmouryProjection` owns a distinct recovery-overflow value; Warehouse remains ordinary-stash-only.
- Protected overflow entries remain focusable/inspectable but cannot begin drag/controller pickup; a bounded `StorageSlotButton` movement-policy seam is required.
- Actual boot precedence and Main lifecycle cutover remain Task 12; Task 10 Main work is limited to overflow move routing/location.

## Verification

### Focused GREEN ladder

- Exact flow suite: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Exact recovery four-suite slice (`test_run_terminal_recovery_safety`, `test_run_resolution_preflight`, `test_run_resolution_service`, and `test_run_extraction_policy`): exit `0`, `TEST_SUMMARY: PASS (0 failures)`. The output retained the intentional injected `JSON_STORE_CLEANUP_DEBT` failure-path warnings.
- Exact Armoury suite: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- The first exact 17-suite integration run exposed two stale retained schema expectations only. After restoring the fail-closed invariant that every stored transaction `result_profile` is journal-free, migrating every root v5 transaction snapshot to schema 6, and comparing decoded ownership canonically rather than relying on JSON number representation, the focused ProfileState/migration rerun exited `0` with `TEST_SUMMARY: PASS (0 failures)`.
- Final exact 17-suite Task 10 batch, terminal session `32480`: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. Established assertion-owned AtomicJsonStore/Main negative-path diagnostics remained; there was no `TEST_FAILURE`.

The exact final focused command was:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_recovery_safety.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_mutation_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_armoury_screen.gd tests/unit/test_main_wiring.gd
```

### Lifecycle integration

The exact lifecycle runner exited `0` with every required marker:

- `RUN_RECOVERY_CURRENT: PASS`
- `RUN_RECOVERY_LEGACY_CLASS: PASS`
- `RUN_RECOVERY_ABANDON: PASS`
- `PROFILE_DELETE_LIFECYCLE: PASS`
- `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`

The schema-four lifecycle downgrader was corrected to recursively remove schema-6 terminal fields from nested transaction snapshots. This is a test-fixture compatibility correction; no Task 12 boot precedence or lifecycle cutover was implemented.

### Uncontested full suite

Before the final run, one stale Codex-owned headless parse process and its exact parent shell, hung against this worktree since August 29, were identified by command line and stopped. The suite then ran with zero Godot engine contenders. Terminal session `57460` exited `0` with:

- `ITEM_TRANSACTION_MATRIX: PASS`
- `TEST_SUMMARY: PASS (252 suites)`
- `FULL_SUITE_EXIT:0`

The run retained established assertion-owned negative-path errors/warnings and two existing invalid-UTF-8 replacement diagnostics. It emitted no `TEST_FAILURE` and reached the required terminal summary.

### Independent review corrections

The independent code review reported no Critical findings and six Important findings. Each accepted finding received its own focused RED before the minimum fix:

- Strict duplicate completion retained-item reconstruction: `TEST_SUMMARY: FAIL (2 failures)`, exit `1`; then `TEST_SUMMARY: PASS (0 failures)`, exit `0`. The committed mutation callback remains once-only while duplicate sanitation returns the verified current profile instead of the intentionally journal-free historical result snapshot.
- Durable receipt revalidation, resolved transaction operation/fingerprint/receipt binding, committed initial-save projection retry, and the restored journal-free result-snapshot invariant: `TEST_SUMMARY: FAIL (16 failures)`, exit `1`; then the exact three-suite slice passed with `TEST_SUMMARY: PASS (0 failures)`, exit `0`.
- Armoury focus fallback: `TEST_SUMMARY: FAIL (3 failures)`, exit `1`; then `TEST_SUMMARY: PASS (0 failures)`, exit `0`. Focus restoration now prefers the exact moved item identity, then the nearest same-container slot, then the first deterministic safe control.
- Null recovery-overflow fingerprint protection: the focused RED produced the expected null dereference and `TEST_SUMMARY: FAIL (2 failures)`, exit `1`; the minimum validation guard then passed with `TEST_SUMMARY: PASS (0 failures)`, exit `0`.

The combined post-review five-suite slice passed with `TEST_SUMMARY: PASS (0 failures)`, exit `0`. The exact post-review 17-suite run in terminal session `21421` passed with `TEST_SUMMARY: PASS (0 failures)`, exit `0`. The lifecycle runner again emitted all five required PASS markers and exited `0`.

The final uncontested post-review full suite ran in terminal session `14614` and exited `0` with:

- `ITEM_TRANSACTION_MATRIX: PASS`
- `TEST_SUMMARY: PASS (252 suites)`
- `POST_REVIEW_FULL_SUITE_EXIT:0`

Only established assertion-owned negative-path diagnostics and warnings appeared; there was no `TEST_FAILURE`.

## Implementation and Boundary Review

- Initial capture checkpoints the live validated item state and terminal receipt atomically before picker exposure; typed initial-save retry remains distinct from resolution and projection retry.
- Canonical selected-item order derives from policy truth, selection state is persisted before resolution, and terminal-only resolution commits accepted extraction, run revocation, and the resolved receipt atomically while the generic resolution path remains available.
- Cold pre-resolution and resolved receipt recovery, defensive query copies, once-only state transitions, projection-only retry, finalize receipt retention, and action-time strict completion are covered by the behavioral suites.
- Irreversible completion now fails closed when artifact sanitation cannot be verified. A committed duplicate reruns strict irreversible verification/sanitation without reinvoking the mutation callback.
- Schema 6, recursive transaction migration, exact terminal codec validation, typed stage safety, and input immutability are covered by direct durable fixtures.
- Recovery Overflow is a distinct source-only ownership container. It participates in ownership decoding/fingerprints but never ordinary stash capacity, loadout, or destination sets. Current receipt-protected items remain inspectable but movement-locked; older overflow items can move only to an empty ordinary stash slot.
- Armoury renders Recovery Overflow separately with the non-color `SOURCE ONLY` label, fail-closed mouse/controller movement policy, readable protection reason, deterministic focus traversal, and stable focus descriptors across refresh. The post-review unit evidence always asserts the exact returned target for moved-item identity, nearest same-container fallback, and deterministic first-safe-control fallback; when the rebuilt controls are tree-attached it additionally asserts the real GUI focus owner. The responsive integration uses real parsed D-pad events across leader, stash, overflow, and Close.
- Main changes are limited to real overflow location/read and routing through `ProfileItemStorageService`; ordinary assignment still uses `ProfileLoadoutAssignmentService`. No Task 11 recap/result screen, Task 12 boot cutover, tactics, push, or merge was added.

Justified bounded additions beyond the original file list are `AtomicJsonStore` strict sanitation authorization, `LoadoutCompatibilityProjection` overflow fingerprinting, distinct `ArmouryProjection` overflow state, `StorageSlotButton` movement policy, and the schema-6 lifecycle test-fixture correction.

## Import, UID, and Integrity Audit

- The required Task 10 classes were imported and exercised by focused, lifecycle, and full-suite runs.
- Import/test fallout produced `60` untracked `.gd.uid` sidecars: the exact `9` intended Task 10 UIDs plus `51` unrelated regenerated sidecars. The confirmed unrelated `51` were removed by exact resolved paths. Final state is `9` intended, `0` unrelated.
- Historical `.superpowers/sdd/task-10-report.md` remains blob `95a538c9668fa8e6381166dc8c488b502956cd31`.
- `git diff --check` is clean.

## Final review repair wave

The final review repairs started from committed head `e4dfaf5538617f539ea3eeb4077e755e50da28c7` with a clean worktree. The pre-repair exact 17-suite baseline exited `0` with `BASELINE_17_EXIT:0` and terminal `TEST_SUMMARY: PASS (0 failures)`.

Every Critical/Important repair used a focused RED before its minimum production change and a focused GREEN afterward. Commands below use the exact console executable and worktree path from this report's focused command; each command was wrapped with `$exit=$LASTEXITCODE; Write-Output "<MARKER>:$exit"; exit $exit`.

- Completion full typed-safety revalidation used `--script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_recovery_safety.gd`. The first matrix RED was `CRITICAL_COMPLETION_RED_EXIT:1`, `TEST_SUMMARY: FAIL (14 failures)`; the callback-interleaving expansion was `CRITICAL_COMPLETION_CALLBACK_RED_EXIT:1`, `TEST_SUMMARY: FAIL (17 failures)`. All seven metadata/receipt/result/placement mutations were structurally valid, saved, executed, and write-free. GREEN was `CRITICAL_COMPLETION_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. `complete_terminal()` now invokes the shared typed safety authority both before irreversible mutation and inside its callback.
- Terminal duplicate receipt/source/request binding used `--script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd`. RED was `TERMINAL_DUPLICATE_RECEIPT_RED_EXIT:1`, `TEST_SUMMARY: FAIL (1 failures)`; GREEN was `TERMINAL_DUPLICATE_RECEIPT_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. Same request with a different typed source is rejected without a write.
- Cold automatic-only protection recovery used the same terminal-flow command. RED was `AUTOMATIC_ONLY_COLD_RESUME_RED_EXIT:1`, `TEST_SUMMARY: FAIL (7 failures)`; GREEN was `AUTOMATIC_ONLY_COLD_RESUME_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. The interrupted record, exact transaction/reason, cold preflight recomputation, restored eligibility, successful Protect, and fresh repreflight all execute.
- Initial capture input binding used the recovery-safety command. RED was `CAPTURE_INPUT_BINDING_RED_EXIT:1`, `TEST_SUMMARY: FAIL (5 failures)`; GREEN was `CAPTURE_INPUT_BINDING_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. Same-run typed seed/player/leader/source drift and stale committed projection are write-free failures.
- Protection replay binding used the recovery-safety command. RED was `PROTECTION_REPLAY_BINDING_RED_EXIT:1`, `TEST_SUMMARY: FAIL (2 failures)`; GREEN was `PROTECTION_REPLAY_BINDING_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. A changed supplied interrupted record and a structurally valid live placement drift both reject without writes; exact replay remains idempotent.
- Pre-resolution stale-selection safety used the recovery-safety command. RED was `STALE_SELECTION_SAFETY_RED_EXIT:1`, `TEST_SUMMARY: FAIL (1 failures)` even though the transaction digest matched the surviving subset; GREEN was `STALE_SELECTION_SAFETY_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. Exact reconstructed count, canonical ID order, and canonical selection documents now precede digest acceptance.
- Armoury pre-drop truth used `--script res://tests/focused_test_runner.gd -- tests/unit/test_armoury_screen.gd`. RED was `ARMOURY_DROP_POLICY_RED_EXIT:1`, `TEST_SUMMARY: FAIL (3 failures)` for overflow destination, leader target, and occupied-stash target; GREEN was `ARMOURY_DROP_POLICY_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. Mouse `_can_drop_data()`, `_drop_data()`, public/request routing, and controller-held South/place share the same source/destination decision.
- Visible protection status, Living Forge accessibility, and deterministic navigation used the same Armoury command. RED was `ARMOURY_ACCESSIBILITY_NAV_RED_EXIT:1`, `TEST_SUMMARY: FAIL (10 failures)`; GREEN was `ARMOURY_ACCESSIBILITY_NAV_GREEN_EXIT:0`, `TEST_SUMMARY: PASS (0 failures)`. The exact autowrapped sighted status is `Available after terminal resolution`; the Armoury resolves high contrast with independent UI/text scale on configure/open/refresh, Close remains at least 48px, footer copy names the implemented inputs, and wide/compact layouts retain all four explicit focus neighbors.
- The exact responsive integration command was `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/armoury_warehouse_responsive_runner.gd`. An initial new assertion expected Close immediately after stash, but the canonical Task 9 fixture includes an empty Recovery Overflow container; the test expectation was corrected without production change to require stash -> overflow -> Close. Final output was `TASK9_STORAGE_RESPONSIVE_SUMMARY: PASS (0 failures)`, `ARMOURY_REAL_DPAD_GREEN_EXIT:0`, with real parsed D-pad traversal and focus-driven stash scrolling at all three resolutions.

Final repair verification:

- Combined repair command: exact console/focused runner with `test_run_terminal_flow.gd`, `test_run_terminal_recovery_safety.gd`, `test_run_resolution_service.gd`, `test_armoury_screen.gd`, and `test_main_wiring.gd`. Session `58053` ended `TEST_SUMMARY: PASS (0 failures)`, `COMBINED_REPAIR_SUITES_EXIT:0`.
- The exact 17-suite command printed earlier in this report ran in session `45912` and ended `TEST_SUMMARY: PASS (0 failures)`, `EXACT_17_REPAIR_EXIT:0`.
- Lifecycle command: `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd`. It exited `LIFECYCLE_REPAIR_EXIT:0` with `RUN_RECOVERY_CURRENT: PASS`, `RUN_RECOVERY_LEGACY_CLASS: PASS`, `RUN_RECOVERY_ABANDON: PASS`, `PROFILE_DELETE_LIFECYCLE: PASS`, and `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`.
- Full-suite command: `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd`. Session `86200` ended `ITEM_TRANSACTION_MATRIX: PASS`, `TEST_SUMMARY: PASS (252 suites)`, `FINAL_REPAIR_FULL_SUITE_EXIT:0`. Established assertion-owned negative-path diagnostics and the existing invalid-UTF-8 replacement diagnostic remained; no `TEST_FAILURE` occurred.
- Integrity audit: `git diff --check` exit `0`; historical report blob remains `95a538c9668fa8e6381166dc8c488b502956cd31`; the base-to-head intended UID list contains exactly `9`, current untracked UID count is `0`, and no changed path crosses into tactics, Task 11 recap/result UI, or Task 12 boot/lifecycle cutover.

## Keyboard pickup help repair

- The Armoury unit assertion was strengthened to require the actual keyboard pickup wording `Keyboard: arrows inspect, X pick up, Enter place`, matching the `item_sandbox_pickup` physical-X binding in `project.godot`.
- TDD RED: the exact Armoury focused command exited `1` with `TEST_SUMMARY: FAIL (1 failures)` and only the strengthened keyboard-help assertion failed (`ARMOURY_HELP_RED_EXIT:1`).
- The Armoury footer now reads exactly `Keyboard: arrows inspect, X pick up, Enter place • Controller: D-pad inspect, West pick up, South place • Mouse: drag/drop`.
- TDD GREEN: the exact Armoury focused command exited `0` with `TEST_SUMMARY: PASS (0 failures)` (`ARMOURY_HELP_GREEN_EXIT:0`).
- Real D-pad responsive integration exited `0` with `TASK9_STORAGE_RESOLUTION_PASS` at `1920x1080`, `2560x1440`, and `3840x2160`, `TASK9_STORAGE_RESPONSIVE_SUMMARY: PASS (0 failures)`, and `ARMOURY_REAL_DPAD_GREEN_EXIT:0`.
