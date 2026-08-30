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
- `RunExtractionPolicy.project()` retains the live wrapper and delegates canonical leader/follower/inventory ordering to `project_source()`.
- `RunResolutionEvaluator` is the one identity/extraction/ownership/eligibility/stash/candidate-mutation authority.
- Evaluation/preflight expose defensive extraction plus `mandatory`, `ordinary`, `required`, `available`, and `automatic_only_blocked`; required is constructed as mandatory plus ordinary on accepted and capacity-failure paths.
- Preflight copies the caller profile, never loads through `ProfileStore`, and leaves profile bytes, profile documents, live context ownership, and request selections unchanged.
- Durable `resolve_source()` reruns the same evaluator inside unchanged `ProfileMutationService.apply_with_resumable_run_revocation()` authority using unchanged `OPERATION` plus `request.canonical_document()` fingerprint input.
- First success and duplicate replay expose a defensive accepted extraction. Duplicate callback-skipped replay reconstructs and validates it from exact request/source truth.
- Live ownership newer than the checkout snapshot remains supported: source capture validates run identity, not snapshot item equality.

## GREEN Verification

### Focused Task 7 suites

Same exact three-suite command as RED:

- Exit: `0`
- Marker: `TEST_SUMMARY: PASS (0 failures)`
- Covers strict roundtrip/isolation/malformed source matrix; legacy/source policy parity; zero, constrained, ordinary, automatic and automatic-only capacity; `2 + 1 = 3` demand; `3/1/0` available-space fixtures; document/byte purity; accepted/rejected preflight-resolve parity; fresh durable drift; duplicate/collision; defensive accepted projection; canonical and nonlexical stash behavior.

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

- Complete `--headless --import`: exit `0`.
- Intended new UIDs only:
  - `scripts/extraction/run_resolution_source.gd.uid`
  - `scripts/extraction/run_resolution_source_result.gd.uid`
  - `scripts/extraction/run_resolution_evaluation.gd.uid`
  - `scripts/extraction/run_resolution_evaluator.gd.uid`
  - `scripts/extraction/run_resolution_preflight_result.gd.uid`
  - `tests/unit/test_run_resolution_preflight.gd.uid`
- `git diff --check`: clean.

## Principal SHA-256 Evidence

- `run_resolution_source.gd`: `652932731246f28dda5c7a45a323941b53249eb47d87fee761a4058524f60f58`
- `run_resolution_evaluator.gd`: `c0eb664bd52f815117077ba71d683599a86efc6dc21f33e67c55f30faa6a456e`
- `run_resolution_service.gd`: `e6d655446e882ebf6c32ca577ea081fbc9cd73bcc10a7781814601f200df614f`
- `test_run_resolution_preflight.gd`: `c9e652fb8d659472133bbe2a14ad445ccf5325b01a18f3eb382c9797d2971fd7`

## Delivery State

- Task 7 implementation and verification are complete in the isolated worktree.
- No Task 8 work, push, merge, or worktree cleanup was performed.
