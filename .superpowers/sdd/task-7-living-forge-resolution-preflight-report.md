# Task 7 Living Forge Resolution Preflight Report

## Scope

- Exact base: `7026e79d454534860c31d3b7a806fc7bbaad0c4d`
- Task: share exact resolution preparation between pure preflight and durable resolve.
- Excluded: Task 8 terminal snapshots/UI/orchestration, tactics, push, merge.
- Historical `.superpowers/sdd/task-7-report.md` remains blob `9209b560d411d4aa05e545cbf578f0e9c6a78647`.

## TDD RED

Production files were untouched when the new/extended Task 7 tests first ran.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
```

- Exit: `1`
- Marker: `TEST_SUMMARY: FAIL (7 failures)`
- Classification: only the approved missing Task 7 surface failed: `RunResolutionSource`, `RunResolutionEvaluator`, `RunResolutionPreflightResult`, `RunResolutionService.preflight`, `RunExtractionPolicy.project_source`, and `RunResolutionResult.accepted_extraction`.

## Implemented Contract

- Strict schema-1, node-free `RunResolutionSource` captures exact run/profile/leader identity, ordered member/class/leader rows, copy-owned live ownership, leader class, and resolved core attributes.
- Strict decode rejects missing/extra/type-invalid fields, nonpositive or duplicate member identity, leader mismatch, incomplete core attributes, and ownership whose owner differs from the run player.
- `RunExtractionPolicy.project()` remains backward compatible with configured non-strict/developer contexts. The live wrapper and strict `project_source()` both delegate canonical leader/follower/inventory ordering to one pure owned-source algorithm; strict resolution source capture remains strict.
- `RunResolutionEvaluator` is the one identity/extraction/ownership/eligibility/stash/candidate-mutation authority.
- Evaluation/preflight expose defensive extraction plus `mandatory`, `ordinary`, `required`, `available`, `automatic_only_blocked`, and explicit known-count flags. Safely derivable counts remain populated on rejection; selection-dependent counts are explicitly unavailable for stale selections instead of being reported as zero.
- Evaluation, preflight, and durable result expose typed failure categories plus player-safe reasons separate from internal `PARTY_FORGE... field=...` diagnostics. Stale review, saved-run identity mismatch, ownership verification, eligibility, reducible shortage, automatic-only shortage, over-capacity, duplicate-source collision, and legacy-receipt recovery are distinct.
- Preflight copies the caller profile, never loads through `ProfileStore`, and leaves profile bytes, profile documents, live context ownership, and request selections unchanged.
- Durable `resolve_source()` reruns the same evaluator inside unchanged `ProfileMutationService.apply_with_resumable_run_revocation()` authority using unchanged `OPERATION` plus `request.canonical_document()` fingerprint input.
- The canonical transaction fingerprint remains the unchanged operation plus canonical request. New run-resolution transactions add an optional JSON-safe receipt containing only strict-source and accepted-projection SHA-256 commitments; no lost item identifier is persisted. Duplicate callback-skipped replay requires the exact source commitment, reconstructs from the stored committed profile result, verifies the projection commitment, and returns a defensive accepted extraction. Divergent source is a stable typed collision; legacy four-field resolution transactions load but fail closed when their receipt is unavailable. Other legacy mutation replay behavior is unchanged.
- Receipt commitments use sorted, full-precision JSON so distinct floating-point source truth cannot collapse under default JSON formatting. A regression proves the smallest positive subnormal source value collides with zero under default precision but is distinct under the committed full-precision representation.
- `RunResolutionSourceResult` carries typed identity, ownership, or invalid-source failure kinds. Both live preflight and resolve wrappers map those kinds without inspecting diagnostic text; missing strict bootstrap and invalid matching-owner ownership have exact typed parity.
- Live ownership newer than the checkout snapshot remains supported: source capture validates run identity, not snapshot item equality.

## GREEN Verification

### Review repair RED

Production files were still untouched when the reviewer-repair tests first ran.

- Exact three-suite command above: exit `1`, terminal `TEST_SUMMARY: FAIL (10 failures)`.
- Failures were confined to the newly required legacy wrapper, receipt/source binding, typed player result, and explicit count-availability surfaces.
- Completion review then found three additional edge cases. Tests first produced terminal `TEST_SUMMARY: FAIL (5 failures)`, exit `1`, for typed wrapper source classification and null-member compatibility; the initial float probe rounded to unchanged binary truth and was corrected before acceptance. Full-precision receipt binding, typed source-result kinds, and legacy null-member skipping then passed the exact focused command. Independent re-review reported no Critical or Important findings.

### Focused Task 7 suites

Same exact three-suite command as RED:

- Exit: `0`
- Marker: `TEST_SUMMARY: PASS (0 failures)`
- Covers strict roundtrip/isolation/malformed source matrix; strict/legacy shared-policy parity including configured non-strict contexts; zero, all-fit, constrained, over-capacity, ordinary, automatic replacement, displaced equipment and automatic-only capacity; `2 + 1 = 3` demand; auditable known/unavailable counts; typed player-safe failure classification; exact profile/context/source/request-selection purity; table-driven accepted/rejected preflight-resolve parity; fresh durable drift; duplicate unchanged/collision/legacy-receipt behavior; changed selected, unselected, lost and automatic source contents; defensive accepted projection; canonical and nonlexical stash behavior.

### Retained lifecycle

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
```

- Exit: `0`
- Markers: `RUN_RECOVERY_CURRENT: PASS`, `RUN_RECOVERY_LEGACY_CLASS: PASS`, `RUN_RECOVERY_ABANDON: PASS`, `PROFILE_DELETE_LIFECYCLE: PASS`, `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`.
- Negative-path error logs are assertions owned by the passing runner.

### Retained extraction/loot production

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/weighted_loot_production_runner.gd
```

- Exit: `0`
- Marker: `WEIGHTED_LOOT_PRODUCTION_INTEGRATION: PASS`.

### Complete unit suite

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
```

- Exit: `0`
- Marker: `TEST_SUMMARY: PASS (246 suites)`.

### Import, UID classification, and repository checks

- Complete `--headless --editor --import --quit`: exit `0`. The cold import recreated 51 unrelated missing UID cache files; all 51 were removed after exact untracked classification, leaving only the six intended Task 7 UIDs already committed.
- Intended new UIDs only:
  - `scripts/extraction/run_resolution_source.gd.uid`
  - `scripts/extraction/run_resolution_source_result.gd.uid`
  - `scripts/extraction/run_resolution_evaluation.gd.uid`
  - `scripts/extraction/run_resolution_evaluator.gd.uid`
  - `scripts/extraction/run_resolution_preflight_result.gd.uid`
  - `tests/unit/test_run_resolution_preflight.gd.uid`
- `git diff --check`: clean.

## Principal SHA-256 Evidence

- `run_resolution_source.gd`: `5373fe5abf056380fa011223b90b54116b2b88ee81d1bc0db6b88f5cea60b98e`
- `run_resolution_evaluator.gd`: `e68dcfb6d774cd00afc725da41e937035a7aa7a7fa9e6f26148b295fb4a105c7`
- `run_resolution_service.gd`: `edcf7d67bceae75307e6b9ce5d84ff8a1ef9553715a1bf4d1c8c8841125d183b`
- `test_run_resolution_preflight.gd`: `eb94339e1a1ff1daa0881d7cf5e3c53205467bc95bb92a9336ad4fbbeb432ea1`

## Delivery State

- Task 7 implementation and verification are complete in the isolated worktree.
- No Task 8 work, push, merge, or worktree cleanup was performed.
