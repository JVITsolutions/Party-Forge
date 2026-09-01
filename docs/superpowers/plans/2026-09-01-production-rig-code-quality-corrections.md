# Production Rig Code-Quality Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `HumanoidRigMappingResolution` fail closed in release and debug builds when directly constructed with an invalid token, and remove the obsolete private bind-name helper without weakening the public mapped-bind contract.

**Architecture:** Keep the existing cold-load-safe `RefCounted` wrapper and factory allocation path. Add a build-independent constructor guard and private construction-validity invariant, then delete only the dead `_matching_name_indices()` helper and its direct test block while retaining the public validator. Verify the two changes as separate commits, then qualify the combined tracked state through a fresh archive, disposable cold import, full suite, deterministic diagnostic-family comparison, and two sequential read-only reviews.

**Tech Stack:** Godot 4.7.1 stable Mono, GDScript, PowerShell 7, Git linked worktrees, SHA-256 evidence manifests, `System.Diagnostics.Process`, and `System.IO.Compression.ZipArchive`.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement` on `feat/class-preview-character-model-replacement`; never use the main checkout as the write lane.
- Design authority is `docs/superpowers/specs/2026-09-01-production-rig-code-quality-corrections-design.md` at commit `71cd334df31986e102fd38c375c07cd965bf762a` and SHA-256 `804c658ac18a598b9770414e01c4c5b1e98594b5da978c0c8dbb1567e0226a02`.
- Preserve all existing Task D, Step 7A, Step 7B, verifier, qualifier, requirements-review, and code-quality-review evidence roots byte-for-byte. Consumed probes and failed harness attempts remain provenance and are never rerun, overwritten, or cited as post-change proof.
- Preserve the 77 untracked records described by `C:\Users\Jacob\AppData\Local\Temp\pf-character-task2-reconcile-gate-0001\premerge-untracked-manifest.json`, manifest SHA-256 `9f7d8b800e27f94d2bc1f7798a88c9bda73c65d0429c3c072bbe00daeafbe2bd`.
- Preserve fixture `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json` at SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`.
- Preserve immutable masculine GLB `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\bodies\masculine\rigging\attempt-0002\output\pf_humanoid_v1_masculine_body_master_rigged_mixamo_attempt_0002.glb` at SHA-256 `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` and feminine GLB `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\bodies\feminine\rigging\attempt-0001\output\pf_humanoid_v1_feminine_body_master_rigged_mixamo_attempt_0001.glb` at SHA-256 `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`.
- Preserve Dawn Bulwark's three user-owned modifications. Treat Combat HUD as read-only concurrent drift; never target it and stop on overlapping-path or cross-worktree writes.
- Keep these five sentinels absent: shared, masculine, and feminine mapping `.tres` resources; `data/presentation/manifests/pf_character_equipment_v2.json`; and `docs/qa/character-model-replacement/body-pair-qualification.md`.
- Product/test scope is exactly four paths. No fixture, plan, spec, import metadata, resource, manifest, scene, cache, asset, or other test may change.
- Create exactly two implementation commits after the execution baseline, in this order: `fix: enforce release-safe rig result construction`; `refactor: remove obsolete rig name helper`.
- `PF_RIG_FACTORY_CONTRACT_PROBE` is absent before and after every normal, characterization, import, and full-suite process. Only the separately gated direct-constructor RED and GREEN processes may receive the exact value `invalid_direct_constructor`.
- Do not rerun the consumed `invalid_success` or `invalid_failure` probes. Preserve their evidence as historical provenance; use unchanged-function source audits and new normal focused tests for post-change containment.
- Stop without retry or improvisation on an untrustworthy RED, unexpected diagnostic, test failure, reviewer FAIL, inadequate review evidence, hash drift, scope drift, unknown generated path, or cross-worktree mutation.
- No mapping resource, body qualification, presentation transaction, active visual integration, head, armor, equipment, Dawn Bulwark production, asset, download, Blender, 3D Gen Studio, merge, rebase, push, cleanup, deletion, or publication is authorized.

---

## File Responsibility Map

| Path | Operation | Responsibility |
|---|---|---|
| `scripts/presentation/humanoid_rig_mapping_resolution.gd` | Modify | Add inert field defaults, the release-safe pre-assignment token guard, the private `_construction_valid` invariant, and validity-aware `is_success()` while preserving factories and public API. |
| `tests/unit/test_humanoid_rig_mapping_catalog.gd` | Modify | Add the isolated `invalid_direct_constructor` probe and exact inert-wrapper assertions; retain all normal factory, identity, defensive-copy, loader, and catalog assertions. |
| `scripts/presentation/humanoid_rig_contract.gd` | Modify | Delete only unused `_matching_name_indices()`; preserve `validate_mapped_bind_identity()`, `_resolve_mapped_skin_binds()`, legacy validators, serializers, and every other method byte-for-byte. |
| `tests/unit/test_production_humanoid_rig_mapping.gd` | Modify | Delete only the direct private-helper assertion block; retain all public bind-identity, mapped-rig, numeric-bind, rest, hierarchy, and legacy coverage. |

## Exact Interfaces and Invariants

The public result interface remains unchanged:

```gdscript
static func succeeded(requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping) -> RefCounted
static func failed(requested_body_preset: StringName, selected_resource_path: String, failure_categories: Array[StringName], error_messages: PackedStringArray) -> RefCounted
func get_requested_body_preset() -> StringName
func get_selected_resource_path() -> String
func get_mapping() -> RigMapping
func get_failure_categories() -> Array[StringName]
func get_error_messages() -> PackedStringArray
func is_success() -> bool
func rejected_by_mapped_rig(validation_errors: PackedStringArray) -> RefCounted
```

The private constructor signature remains unchanged:

```gdscript
func _init(
		factory_token: RefCounted,
		requested_body_preset: StringName,
		selected_resource_path: String,
		mapping: RigMapping,
		failure_categories: Array[StringName],
		error_messages: PackedStringArray
	) -> void
```

An invalid token must emit exactly:

```text
humanoid rig mapping resolution constructor contract failed: invalid factory token
```

It returns at most the already allocated wrapper with empty preset/path/categories/messages, null mapping, `is_success() == false`, exact runtime script identity, and `rejected_by_mapped_rig()` returning that same inert wrapper. No caller-supplied value is stored. `_construction_valid` is underscore-private, has no public accessor or setter, starts `false`, and becomes `true` only as the final valid-construction assignment.

The public pure bind validator remains:

```gdscript
static func validate_mapped_bind_identity(
		bone_names: Array[StringName],
		bind_name: StringName,
		numeric_bone_index: int,
		bind_slot: int
	) -> PackedStringArray
```

---

### Task 0: Capture the Exact Execution Baseline and Containment

**Files:**
- Read: approved design and current plan.
- Write: fresh task-owned evidence under `C:\Users\Jacob\AppData\Local\Temp` only.

**Interfaces:**
- Consumes: approved design commit `71cd334df31986e102fd38c375c07cd965bf762a`.
- Produces: immutable `codeQualityCorrectionBase` evidence used by every diff, commit, reviewer, and rollback audit.

- [ ] **Step 1: Revalidate linked-worktree identity and clean tracked state**

Run:

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
$designCommit = '71cd334df31986e102fd38c375c07cd965bf762a'
$designPath = 'docs/superpowers/specs/2026-09-01-production-rig-code-quality-corrections-design.md'
$planPath = 'docs/superpowers/plans/2026-09-01-production-rig-code-quality-corrections.md'
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'

$top = git -C $project rev-parse --show-toplevel
$gitDir = git -C $project rev-parse --git-dir
$commonDir = git -C $project rev-parse --git-common-dir
$superLines = @(git -C $project rev-parse --show-superproject-working-tree 2>$null)
$superExit = $LASTEXITCODE
$super = ([string]($superLines -join [Environment]::NewLine)).Trim()

if ($top -cne 'F:/Projects(root)/Game dev/Projects/party-forge/.worktrees/class-preview-character-model-replacement') { throw 'wrong worktree' }
if ($gitDir -ceq $commonDir -or $superExit -ne 0 -or -not [string]::IsNullOrEmpty($super)) { throw 'linked-worktree isolation failed' }
if ((git -C $project branch --show-current) -cne 'feat/class-preview-character-model-replacement') { throw 'wrong branch' }
if (@(git -C $project diff --name-only).Count -ne 0 -or @(git -C $project diff --cached --name-only).Count -ne 0) { throw 'tracked or index drift' }
git -C $project merge-base --is-ancestor $designCommit HEAD
if ($LASTEXITCODE -ne 0) { throw 'approved design is not an ancestor' }
if ((Get-FileHash -LiteralPath (Join-Path $project $designPath) -Algorithm SHA256).Hash.ToLowerInvariant() -cne '804c658ac18a598b9770414e01c4c5b1e98594b5da978c0c8dbb1567e0226a02') { throw 'approved design hash drift' }
```

This detects the existing linked worktree; do not create another worktree or install dependencies. No Godot command runs in Task 0.

- [ ] **Step 2: Capture the dynamic execution baseline**

Immediately before Task A, require the current clean `HEAD` to be this final plan-correction commit, then prove the complete corrected-plan, original-plan, and approved-design ancestry before capturing it:

```powershell
$helperAuditCorrectionCommit = 'f21fed4f234256b1808a86e331fa0a99fee51d53'
$originalPlanCommit = '16bddc127eda3f536a13e301c812ec90d1ed2c04'
$executionPlanSubject = 'docs: correct rig quality execution baseline'
$codeQualityCorrectionBase = git -C $project rev-parse HEAD
$baseParent = git -C $project rev-parse "$codeQualityCorrectionBase^"
if ($baseParent -cne $helperAuditCorrectionCommit) { throw 'execution baseline parent is not the approved helper-audit correction' }
$basePaths = @(git -C $project diff-tree --no-commit-id --name-only -r $codeQualityCorrectionBase)
if ($basePaths.Count -ne 1 -or $basePaths[0] -cne $planPath) { throw 'execution baseline is not the final one-plan-file correction' }
if ((git -C $project log -1 --format=%s $codeQualityCorrectionBase) -cne $executionPlanSubject) { throw 'execution baseline subject drift' }

$helperAuditParent = git -C $project rev-parse "$helperAuditCorrectionCommit^"
$helperAuditPaths = @(git -C $project diff-tree --no-commit-id --name-only -r $helperAuditCorrectionCommit)
if ($helperAuditParent -cne $originalPlanCommit) { throw 'helper-audit correction parent drift' }
if ($helperAuditPaths.Count -ne 1 -or $helperAuditPaths[0] -cne $planPath) { throw 'helper-audit correction path drift' }
if ((git -C $project log -1 --format=%s $helperAuditCorrectionCommit) -cne 'docs: scope rig helper audit to GDScript') { throw 'helper-audit correction subject drift' }

$originalPlanParent = git -C $project rev-parse "$originalPlanCommit^"
$originalPlanPaths = @(git -C $project diff-tree --no-commit-id --name-only -r $originalPlanCommit)
if ($originalPlanParent -cne $designCommit) { throw 'original plan parent is not the approved design' }
if ($originalPlanPaths.Count -ne 1 -or $originalPlanPaths[0] -cne $planPath) { throw 'original plan path drift' }
if ((git -C $project log -1 --format=%s $originalPlanCommit) -cne 'docs: plan production rig code-quality corrections') { throw 'original plan subject drift' }
```

Create a fresh evidence root and record the baseline without a trailing newline:

```powershell
$evidenceRoot = Join-Path $env:TEMP ('pf-rig-code-quality-corrections-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
[System.IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
$baselineRecord = [ordered]@{
    schema = 1
    worktree = $project
    branch = 'feat/class-preview-character-model-replacement'
    design_commit = $designCommit
    design_sha256 = '804c658ac18a598b9770414e01c4c5b1e98594b5da978c0c8dbb1567e0226a02'
    code_quality_correction_base = $codeQualityCorrectionBase
    execution_plan_subject = $executionPlanSubject
    helper_audit_correction_commit = $helperAuditCorrectionCommit
    original_plan_commit = $originalPlanCommit
    plan_path = $planPath
    captured_utc = [DateTime]::UtcNow.ToString('o')
}
[System.IO.File]::WriteAllText(
    (Join-Path $evidenceRoot 'execution-baseline.json'),
    ($baselineRecord | ConvertTo-Json -Compress),
    [System.Text.UTF8Encoding]::new($false)
)
```

- [ ] **Step 3: Rehash protected inputs and record protected worktrees**

Require all 77 manifest records to exist at exact byte lengths and lowercase SHA-256 values. Rehash the fixture, both immutable GLBs, the approved spec, this plan, and these exact accepted review artifacts:

```text
C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2\step7b-independent-verifier-result-v2.json
SHA-256 0e275eeb2bf1e270850f10e01f5965f875202f3bf14b370b2a51afbe527c51d2

C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2\requirements-review-result.md
SHA-256 c7179da6fd84f6cdacffad13db637394fddf426a140e40d03934bb22ad838b2a

C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2\code-quality-review-result.md
SHA-256 c8b679ce663905936600c94e6431eedf9e87d39e287873b535c846b343f2578b
```

Require all five sentinels absent. Record Dawn Bulwark `HEAD` and exactly three status entries; record Combat HUD `HEAD` and status read-only. Require `PF_RIG_FACTORY_CONTRACT_PROBE` absent. Stop on every mismatch.

---

### Task A: Enforce Release-Safe Result Construction

**Files:**
- Modify: `tests/unit/test_humanoid_rig_mapping_catalog.gd:82-111` probe branch.
- Modify: `scripts/presentation/humanoid_rig_mapping_resolution.gd:24-38,89-90` defaults, constructor guard, and success invariant.

**Interfaces:**
- Consumes: exact current factory signatures and test-local `tests/support/test_error_capture.gd` logger.
- Produces: build-independent invalid-token rejection with one inert wrapper and unchanged valid factory behavior.

- [ ] **Step 1: Add the isolated invalid-direct-constructor probe**

In `tests/unit/test_humanoid_rig_mapping_catalog.gd`, replace the current `var factory_probe := ...` block through the final `return failures` immediately before `TestAssertions.equal(RESOLUTION_PATH, ...)` with this complete block:

```gdscript
	var factory_probe := OS.get_environment("PF_RIG_FACTORY_CONTRACT_PROBE")
	if not factory_probe.is_empty():
		var error_capture_script := load("res://tests/support/test_error_capture.gd") as Script
		TestAssertions.truthy(error_capture_script != null, "factory contract error capture loads", failures)
		if error_capture_script == null:
			return failures
		var logger := error_capture_script.new() as Logger
		OS.add_logger(logger)
		var invalid_result: Variant
		var supplied_mapping: Resource
		var supplied_categories: Array[StringName] = []
		var supplied_messages := PackedStringArray()
		if factory_probe == "invalid_success":
			invalid_result = _resolution_script.call(&"succeeded", &"unknown", "", null)
		elif factory_probe == "invalid_failure":
			invalid_result = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, supplied_categories, supplied_messages)
		elif factory_probe == "invalid_direct_constructor":
			supplied_mapping = _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
			supplied_categories = [&"missing_resource"]
			supplied_messages = PackedStringArray(["caller-supplied constructor message"])
			invalid_result = _resolution_script.new(
				RefCounted.new(),
				&"masculine",
				MASCULINE_PATH,
				supplied_mapping,
				supplied_categories,
				supplied_messages
			)
		else:
			OS.remove_logger(logger)
			TestAssertions.truthy(false, "factory contract probe value is recognized", failures)
			return failures
		OS.remove_logger(logger)
		var captured: PackedStringArray = logger.call(&"drain_after_detach")
		if factory_probe == "invalid_direct_constructor":
			TestAssertions.truthy(invalid_result is RefCounted, "invalid_direct_constructor returns allocated RefCounted", failures)
			if not invalid_result is RefCounted:
				return failures
			var inert := invalid_result as RefCounted
			TestAssertions.equal(inert.get_script(), _resolution_script, "invalid_direct_constructor keeps exact runtime script", failures)
			TestAssertions.truthy(not bool(inert.call(&"is_success")), "invalid_direct_constructor is not successful", failures)
			TestAssertions.equal(inert.call(&"get_requested_body_preset"), StringName(), "invalid_direct_constructor stores no preset", failures)
			TestAssertions.equal(inert.call(&"get_selected_resource_path"), "", "invalid_direct_constructor stores no path", failures)
			TestAssertions.equal(inert.call(&"get_mapping"), null, "invalid_direct_constructor stores no mapping", failures)
			TestAssertions.equal(inert.call(&"get_failure_categories"), [] as Array[StringName], "invalid_direct_constructor stores no categories", failures)
			TestAssertions.equal(inert.call(&"get_error_messages"), PackedStringArray(), "invalid_direct_constructor stores no messages", failures)
			TestAssertions.equal(inert.call(&"rejected_by_mapped_rig", PackedStringArray(["ignored"])), inert, "invalid_direct_constructor rejection remains inert", failures)
			var returned_categories: Array = inert.call(&"get_failure_categories")
			var returned_messages: PackedStringArray = inert.call(&"get_error_messages")
			returned_categories.append(&"wrong_resource_type")
			returned_messages.append("returned-copy mutation")
			supplied_mapping.set(&"mapping_id", &"caller_mutation")
			supplied_categories.append(&"wrong_resource_type")
			supplied_messages.append("caller mutation")
			TestAssertions.equal(inert.call(&"get_mapping"), null, "invalid_direct_constructor resists mapping mutation", failures)
			TestAssertions.equal(inert.call(&"get_failure_categories"), [] as Array[StringName], "invalid_direct_constructor categories remain inert", failures)
			TestAssertions.equal(inert.call(&"get_error_messages"), PackedStringArray(), "invalid_direct_constructor messages remain inert", failures)
			TestAssertions.equal(captured.size(), 1, "invalid_direct_constructor emits one programmer-contract error", failures)
			if captured.size() == 1:
				TestAssertions.truthy(
					captured[0].contains("humanoid rig mapping resolution constructor contract failed: invalid factory token"),
					"invalid_direct_constructor emits exact constructor-contract error",
					failures
				)
			return failures
		TestAssertions.equal(invalid_result, null, "%s returns no observable result" % factory_probe, failures)
		TestAssertions.equal(captured.size(), 1, "%s emits exactly one programmer-contract error" % factory_probe, failures)
		if captured.size() == 1:
			var expected_reason := (
				"humanoid rig mapping resolution factory contract failed: success body preset unknown is invalid; success mapping is missing"
				if factory_probe == "invalid_success"
				else "humanoid rig mapping resolution factory contract failed: failure categories are empty; failure messages are empty"
			)
			TestAssertions.truthy(captured[0].contains(expected_reason), "%s error preserves exact ordered defects" % factory_probe, failures)
		return failures
```

Do not change any normal-run assertion, `LoaderRecorder`, constant, helper, or existing `invalid_success`/`invalid_failure` behavior. Run `git diff --check` and require the working scope to contain only this test.

- [ ] **Step 2: Run the constructor probe once to obtain trustworthy RED**

Create fresh RED stdout/stderr paths under `$evidenceRoot`. Require the probe variable absent before the command. Run exactly once:

```powershell
$redStdout = Join-Path $evidenceRoot 'task-a-constructor-red.stdout.txt'
$redStderr = Join-Path $evidenceRoot 'task-a-constructor-red.stderr.txt'
$redExit = $null
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable exists before RED' }
try {
    $env:PF_RIG_FACTORY_CONTRACT_PROBE = 'invalid_direct_constructor'
    & $godot --headless --path $project --quit-after 180 --script 'res://tests/focused_test_runner.gd' -- 'tests/unit/test_humanoid_rig_mapping_catalog.gd' 1> $redStdout 2> $redStderr
    $redExit = $LASTEXITCODE
}
finally {
    Remove-Item Env:PF_RIG_FACTORY_CONTRACT_PROBE -ErrorAction SilentlyContinue
}
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable remained after RED' }
```

Trust RED only if all of these are exact:

- native exit `1`;
- exactly one terminal `TEST_SUMMARY: FAIL (2 failures)`;
- exactly two `TEST_FAILURE` records in this order: the suite assertion `invalid_direct_constructor emits exact constructor-contract error: expected true`, then one `SCRIPT ERROR` record whose reason is `humanoid rig mapping resolution constructor is factory-only` and whose source is the current `_init()` assertion;
- the test-local capture cardinality, exact runtime script identity, inert accessors, same-wrapper rejection, and caller/copy mutation assertions all pass;
- no other assertion label fails;
- no parser, loader, import, script-compile, crash, fatal, segmentation, object-leak, or RID-leak diagnostic appears.

The old assertion record is narrowly classified RED evidence, not a waived diagnostic. If Godot aborts before the inert assertions, changes the failure count/order, or emits any additional diagnostic, stop without production changes and request a plan correction. Do not rerun the consumed RED.

- [ ] **Step 3: Implement the exact release-safe constructor boundary**

In `scripts/presentation/humanoid_rig_mapping_resolution.gd`, replace the five backing-field declarations and `_init()` with:

```gdscript
var _requested_body_preset := StringName()
var _selected_resource_path := ""
var _mapping: RigMapping = null
var _failure_categories: Array[StringName] = []
var _error_messages := PackedStringArray()
var _construction_valid := false

func _init(
		factory_token: RefCounted,
		requested_body_preset: StringName,
		selected_resource_path: String,
		mapping: RigMapping,
		failure_categories: Array[StringName],
		error_messages: PackedStringArray
	) -> void:
	if factory_token != _factory_token:
		push_error("humanoid rig mapping resolution constructor contract failed: invalid factory token")
		return
	_requested_body_preset = requested_body_preset
	_selected_resource_path = selected_resource_path
	_mapping = mapping
	_failure_categories.assign(failure_categories)
	_error_messages = error_messages.duplicate()
	_construction_valid = true
```

Replace `is_success()` with:

```gdscript
func is_success() -> bool:
	return _construction_valid and _requested_body_preset in _RESOURCE_PATH_BY_BODY_PRESET and _selected_resource_path == _RESOURCE_PATH_BY_BODY_PRESET[_requested_body_preset] and _mapping != null and _failure_categories.is_empty() and _error_messages.is_empty()
```

Do not change `SCRIPT_PATH`, `_factory_token`, `succeeded()`, `failed()`, any getter, `rejected_by_mapped_rig()`, `_failure_defects()`, category constants, or path tables.

- [ ] **Step 4: Run the one-shot constructor GREEN probe**

Use new GREEN output paths and run exactly once:

```powershell
$greenStdout = Join-Path $evidenceRoot 'task-a-constructor-green.stdout.txt'
$greenStderr = Join-Path $evidenceRoot 'task-a-constructor-green.stderr.txt'
$greenExit = $null
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable exists before GREEN' }
try {
    $env:PF_RIG_FACTORY_CONTRACT_PROBE = 'invalid_direct_constructor'
    & $godot --headless --path $project --quit-after 180 --script 'res://tests/focused_test_runner.gd' -- 'tests/unit/test_humanoid_rig_mapping_catalog.gd' 1> $greenStdout 2> $greenStderr
    $greenExit = $LASTEXITCODE
}
finally {
    Remove-Item Env:PF_RIG_FACTORY_CONTRACT_PROBE -ErrorAction SilentlyContinue
}
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable remained after GREEN' }
```

Acceptance is:

- native exit `0`;
- exactly one terminal `TEST_SUMMARY: PASS (0 failures)`;
- zero `TEST_FAILURE` records;
- exactly one intentional error block containing `humanoid rig mapping resolution constructor contract failed: invalid factory token`;
- zero occurrences of `humanoid rig mapping resolution constructor is factory-only`;
- every inert-wrapper assertion passes;
- zero unrelated prohibited diagnostics;
- `PF_RIG_FACTORY_CONTRACT_PROBE` absent after the process.

Stop without retry on any mismatch.

- [ ] **Step 5: Run normal focused result/catalog GREEN with the probe absent**

Require `Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE` to be false, then run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd
```

Require native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero `TEST_FAILURE`, and zero parser, loader, import, script-compile, crash, fatal, segmentation, object-leak, or RID-leak diagnostics. Do not run either prior invalid-factory probe.

- [ ] **Step 6: Perform the release-safety source/AST dominance audit**

Create a task-owned audit script under `$evidenceRoot` that reads only `humanoid_rig_mapping_resolution.gd` and fails unless all exact conditions hold:

```powershell
$source = [System.IO.File]::ReadAllText((Join-Path $project 'scripts\presentation\humanoid_rig_mapping_resolution.gd'))
$initStart = $source.IndexOf('func _init(', [System.StringComparison]::Ordinal)
$succeededStart = $source.IndexOf('static func succeeded(', [System.StringComparison]::Ordinal)
if ($initStart -lt 0 -or $succeededStart -le $initStart) { throw 'constructor boundary missing' }
$initBlock = $source.Substring($initStart, $succeededStart - $initStart)
$ordered = @(
    'if factory_token != _factory_token:',
    'push_error("humanoid rig mapping resolution constructor contract failed: invalid factory token")',
    'return',
    '_requested_body_preset = requested_body_preset',
    '_selected_resource_path = selected_resource_path',
    '_mapping = mapping',
    '_failure_categories.assign(failure_categories)',
    '_error_messages = error_messages.duplicate()',
    '_construction_valid = true'
)
$cursor = -1
foreach ($needle in $ordered) {
    $next = $initBlock.IndexOf($needle, $cursor + 1, [System.StringComparison]::Ordinal)
    if ($next -lt 0) { throw "constructor sequence missing: $needle" }
    $cursor = $next
}
if ($initBlock.Contains('assert(')) { throw 'constructor still contains assert authorization' }
if ([regex]::Matches($initBlock, '_construction_valid\s*=\s*true').Count -ne 1) { throw 'construction-valid assignment cardinality drift' }
$successStart = $source.IndexOf('func is_success() -> bool:', [System.StringComparison]::Ordinal)
$rejectedStart = $source.IndexOf('func rejected_by_mapped_rig(', [System.StringComparison]::Ordinal)
$successBlock = $source.Substring($successStart, $rejectedStart - $successStart)
if (-not $successBlock.Contains('return _construction_valid and ')) { throw 'success invariant does not begin with construction validity' }
foreach ($forbidden in @('func is_construction_valid', 'func set_requested_body_preset', 'func set_selected_resource_path', 'func set_mapping', 'func set_failure_categories', 'func set_error_messages', 'var construction_valid')) {
    if ($source.Contains($forbidden)) { throw "public or writable state introduced: $forbidden" }
}
```

Also compare the exact `succeeded()` through `_failure_defects()` function blobs against `$codeQualityCorrectionBase`; the only allowed changes in the resolution script are the field declarations, `_init()`, and `is_success()`. Godot's successful load and method metadata in Steps 4-5 are the parser/AST authority; the independent source-order audit proves guard dominance that a debug-only runtime cannot establish for release builds.

- [ ] **Step 7: Audit and commit Task A**

Require `git diff --check` exit `0`, exact working scope of the result script and catalog test, exact fixture/protected/GLB/evidence hashes, absent sentinels, Dawn Bulwark preservation, and read-only Combat HUD containment. Stage only:

```powershell
git -C $project add -- scripts/presentation/humanoid_rig_mapping_resolution.gd tests/unit/test_humanoid_rig_mapping_catalog.gd
git -C $project diff --cached --check
git -C $project commit -m 'fix: enforce release-safe rig result construction'
```

Require the commit parent to equal `$codeQualityCorrectionBase`, exact two-path scope, no `.gd.uid`, documentation, evidence, resource, or asset path, and clean tracked/index state afterward. Store the commit hash as `$constructionCommit`.

---

### Task B: Remove the Obsolete Bind-Name Helper

**Files:**
- Modify: `scripts/presentation/humanoid_rig_contract.gd:238-246`.
- Modify: `tests/unit/test_production_humanoid_rig_mapping.gd:193-202`.

**Interfaces:**
- Consumes: public `validate_mapped_bind_identity()` and the existing mapped-rig regression suite.
- Produces: zero `_matching_name_indices` references in GDScript source/test files with identical public behavior; documentation references remain valid provenance.

- [ ] **Step 1: Run the pre-removal characterization gate**

Require `PF_RIG_FACTORY_CONTRACT_PROBE` absent. Before editing Task B paths, run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Require native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero `TEST_FAILURE`, and zero prohibited diagnostics. Preserve the output and the exact source ranges for the six public bind-identity assertions: duplicate names, empty name, zero match, numeric range, exact agreement, and name/index conflict. This is characterization, not manufactured RED.

- [ ] **Step 2: Delete only the private helper and direct helper assertion block**

Delete this complete block from `scripts/presentation/humanoid_rig_contract.gd`:

```gdscript
static func _matching_name_indices(
		bone_names: Array[StringName],
		target_name: StringName
	) -> PackedInt32Array:
	var matching_indices := PackedInt32Array()
	for bone_index: int in bone_names.size():
		if bone_names[bone_index] == target_name:
			matching_indices.append(bone_index)
	return matching_indices

```

Delete this complete block from `_assert_numeric_bind_resolution()` in `tests/unit/test_production_humanoid_rig_mapping.gd`:

```gdscript
	var duplicate_name_snapshot: Array[StringName] = [&"PresentationRoot", &"DuplicateName", &"DuplicateName"]
	var has_name_list_helper := _contract.has_method(&"_matching_name_indices")
	TestAssertions.truthy(has_name_list_helper, "mapped-production duplicate-name resolver exists", failures)
	if has_name_list_helper:
		TestAssertions.equal(
			_contract.call(&"_matching_name_indices", duplicate_name_snapshot, &"DuplicateName"),
			PackedInt32Array([1, 2]),
			"mapped-production duplicate-name resolver returns every matching index deterministically",
			failures
		)

```

Do not change the public validator, `_resolve_mapped_skin_binds()`, legacy validators, serializers, constants, fixture builders, or any other assertion.

- [ ] **Step 3: Prove exact deletion scope before tests**

Run:

```powershell
$helperHits = @(rg -n --fixed-strings --glob '*.gd' '_matching_name_indices' $project)
$helperSearchExit = $LASTEXITCODE
if ($helperSearchExit -gt 1) { throw "GDScript helper audit failed with exit $helperSearchExit" }
if ($helperSearchExit -eq 0 -and $helperHits.Count -eq 0) { throw 'GDScript helper audit reported success without captured records' }
if ($helperSearchExit -eq 1 -and $helperHits.Count -ne 0) { throw 'GDScript helper audit reported no matches with captured records' }
if ($helperSearchExit -ne 1 -or $helperHits.Count -ne 0) { throw "obsolete GDScript helper remains: $($helperHits -join '; ')" }
git -C $project diff --check
git -C $project diff --name-only
```

Require `rg` exit `1` with zero captured `.gd` matches; exit `0` means at least one obsolete GDScript reference remains, and exit `2` or greater is an audit failure. Require the working scope to contain exactly the rig contract and mapped-rig test. Compare the `validate_mapped_bind_identity()`, `_resolve_mapped_skin_binds()`, `validate_rig()`, `validate_skin()`, `_serialize_transform()`, and `_quantized()` blobs byte-for-byte against `$constructionCommit`.

- [ ] **Step 4: Run the post-removal characterization gate**

Require the probe variable absent and run once:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Require native exit `0`, one terminal `TEST_SUMMARY: PASS (0 failures)`, zero `TEST_FAILURE`, and zero prohibited diagnostics. Reconfirm every retained public bind-identity assertion executed and passed.

- [ ] **Step 5: Audit and commit Task B**

Rehash protected inputs and evidence, confirm sentinels absent and protected worktrees untouched, then stage only:

```powershell
git -C $project add -- scripts/presentation/humanoid_rig_contract.gd tests/unit/test_production_humanoid_rig_mapping.gd
git -C $project diff --cached --check
git -C $project commit -m 'refactor: remove obsolete rig name helper'
```

Require the commit parent to equal `$constructionCommit`, exact two-path scope consisting only of deletions, no other path, and clean tracked/index state. Store the hash as `$helperRemovalCommit`.

---

### Task C: Verify the Combined Corrective Checkpoint

**Files:**
- No tracked changes.
- Read-only scope: the exact four product/test paths.
- Write: fresh task-owned evidence under `$evidenceRoot` and one disposable archive expansion only.

**Interfaces:**
- Consumes: `$codeQualityCorrectionBase`, `$constructionCommit`, and `$helperRemovalCommit`.
- Produces: focused evidence, fresh tracked-archive cold-import/full-suite evidence, diagnostic-family equivalence, two independent review verdicts, and exact containment.

- [ ] **Step 1: Run the complete focused correction gate**

Require `PF_RIG_FACTORY_CONTRACT_PROBE` absent, then run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Require native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero fail markers, zero `TEST_FAILURE`, and zero prohibited diagnostics.

- [ ] **Step 2: Audit exact two-commit/four-path history**

Require exactly two first-parent commits after `$codeQualityCorrectionBase`, no merges, and these exact subjects in order:

```text
fix: enforce release-safe rig result construction
refactor: remove obsolete rig name helper
```

Require the first commit scope to equal the result script plus catalog test, the second to equal the rig contract plus mapped-rig test, and their union to equal the four File Responsibility Map paths. Require `git diff $codeQualityCorrectionBase..HEAD --check` exit `0`, clean tracked/index state, 77 protected untracked records exact, fixture/GLB/evidence hashes exact, and all sentinels absent.

- [ ] **Step 3: Create and validate one fresh tracked archive**

Create fresh paths:

```powershell
$trackedArchive = Join-Path $evidenceRoot 'tracked.zip'
$disposableProject = Join-Path $evidenceRoot 'tracked-project'
$controller = Join-Path $evidenceRoot 'process-controller.ps1'
git -C $project archive --format=zip --output=$trackedArchive HEAD
if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
$archiveSha = (Get-FileHash -LiteralPath $trackedArchive -Algorithm SHA256).Hash.ToLowerInvariant()
```

Validate and manifest the archive with this exact algorithm:

```powershell
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archiveManifestPath = Join-Path $evidenceRoot 'tracked-archive-manifest.jsonl'
$seenArchivePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$archiveRecords = [System.Collections.Generic.List[object]]::new()
$zip = [System.IO.Compression.ZipFile]::OpenRead($trackedArchive)
try {
    foreach ($entry in $zip.Entries) {
        $rawName = [string]$entry.FullName
        $normalized = $rawName.Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($normalized)) { throw 'archive has blank entry' }
        if ([System.IO.Path]::IsPathRooted($normalized) -or $normalized.StartsWith('/') -or $normalized.StartsWith('\')) { throw "archive has rooted entry: $rawName" }
        $isDirectory = $normalized.EndsWith('/')
        $pathBody = $normalized.TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($pathBody)) { throw "archive has root-only entry: $rawName" }
        $segments = @($pathBody.Split('/'))
        foreach ($segment in $segments) {
            if ([string]::IsNullOrWhiteSpace($segment) -or $segment -ceq '.' -or $segment -ceq '..' -or $segment.Contains(':')) { throw "archive has unsafe segment in $rawName" }
        }
        if (-not $seenArchivePaths.Add($pathBody)) { throw "archive has duplicate normalized path: $pathBody" }
        $record = [ordered]@{ relative_path = $pathBody; type = 'directory'; bytes = 0; sha256 = $null }
        if (-not $isDirectory) {
            $stream = $entry.Open()
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { $entryHash = [Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
            $record.type = 'file'
            $record.bytes = [long]$entry.Length
            $record.sha256 = $entryHash
        }
        $archiveRecords.Add([pscustomobject]$record)
    }
}
finally { $zip.Dispose() }
$archivePaths = [string[]]@($archiveRecords | ForEach-Object { [string]$_.relative_path })
[System.Array]::Sort($archivePaths, [System.StringComparer]::Ordinal)
$orderedArchiveRecords = @($archivePaths | ForEach-Object {
    $path = $_
    @($archiveRecords | Where-Object { $_.relative_path -ceq $path })[0]
})
$archiveLines = @($orderedArchiveRecords | ForEach-Object { $_ | ConvertTo-Json -Compress })
[System.IO.File]::WriteAllText($archiveManifestPath, ($archiveLines -join "`n"), [System.Text.UTF8Encoding]::new($false))
if ((Get-FileHash -LiteralPath $trackedArchive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $archiveSha) { throw 'archive changed during validation' }
```

Reject every blank, rooted, device, alternate-stream, traversal, case-colliding, or duplicate normalized path. Preserve the archive/manifest hashes before expansion.

- [ ] **Step 4: Expand and capture the pre-import inventory**

Create `$disposableProject` only after archive validation and expand once:

```powershell
if (Test-Path -LiteralPath $disposableProject) { throw 'disposable project already exists' }
[System.IO.Compression.ZipFile]::ExtractToDirectory($trackedArchive, $disposableProject)
$inventoryRecords = [System.Collections.Generic.List[object]]::new()
$inventorySeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($item in @(Get-ChildItem -LiteralPath $disposableProject -Force -Recurse | Sort-Object -Property FullName)) {
    $relative = [System.IO.Path]::GetRelativePath($disposableProject, $item.FullName).Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($relative) -or -not $inventorySeen.Add($relative)) { throw "invalid inventory path: $relative" }
    if ($item.PSIsContainer) {
        $inventoryRecords.Add([pscustomobject][ordered]@{ relative_path = $relative; type = 'directory'; bytes = 0; sha256 = $null })
    }
    else {
        $inventoryRecords.Add([pscustomobject][ordered]@{
            relative_path = $relative
            type = 'file'
            bytes = [long]$item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }
}
if (@($inventoryRecords | Where-Object { $_.relative_path -ceq '.godot' -or $_.relative_path.StartsWith('.godot/') }).Count -ne 0) { throw 'archive expansion inherited .godot' }
$inventoryPaths = [string[]]@($inventoryRecords | ForEach-Object { [string]$_.relative_path })
[System.Array]::Sort($inventoryPaths, [System.StringComparer]::Ordinal)
$orderedInventoryRecords = @($inventoryPaths | ForEach-Object {
    $path = $_
    @($inventoryRecords | Where-Object { $_.relative_path -ceq $path })[0]
})
$inventoryLines = @($orderedInventoryRecords | ForEach-Object { $_ | ConvertTo-Json -Compress })
[System.IO.File]::WriteAllText((Join-Path $evidenceRoot 'pre-import-inventory.jsonl'), ($inventoryLines -join "`n"), [System.Text.UTF8Encoding]::new($false))
$expandedFiles = @($inventoryRecords | Where-Object type -eq 'file')
$archiveFiles = @($orderedArchiveRecords | Where-Object type -eq 'file')
if ($expandedFiles.Count -ne $archiveFiles.Count) { throw 'expanded file count differs from archive' }
foreach ($record in $archiveFiles) {
    $match = @($expandedFiles | Where-Object relative_path -ceq $record.relative_path)
    if ($match.Count -ne 1 -or $match[0].bytes -ne $record.bytes -or $match[0].sha256 -cne $record.sha256) { throw "expanded file mismatch: $($record.relative_path)" }
}
```

Require zero blank or duplicate paths and exact archive-to-expansion file equality.

- [ ] **Step 5: Requalify and copy the accepted asynchronous controller**

Use only:

```text
C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-controller-qualification-20260901T070102Z-a5e18980\synthetic\process-controller.ps1
SHA-256 46b171f14c852bdb05984bf289e19d1ea9091d7ae2892561b22963b5f20ae1aa
```

Copy it byte-for-byte to `$controller`, require the same hash, parse with `System.Management.Automation.Language.Parser` with zero errors, and AST-scan for zero direct call operators, `Start-Process`, `Stop-Process`, shell redirections, `.Arguments` string assignments, and case-insensitive variables named `pid`. Require separate `ArgumentList` additions, two `ReadToEndAsync` calls, one `WaitForExitAsync`, native `ExitCode` capture only after confirmed exit, and task-owned `Kill(true)` timeout containment. Preserve its accepted synthetic qualification as provenance; do not modify or rerun that historical controller qualification.

- [ ] **Step 6: Run exactly one disposable cold registration/import**

Create brand-new empty environment roots and require the probe variable absent:

```powershell
$importAppData = Join-Path $evidenceRoot 'import-appdata'
$importLocalAppData = Join-Path $evidenceRoot 'import-localappdata'
[System.IO.Directory]::CreateDirectory($importAppData) | Out-Null
[System.IO.Directory]::CreateDirectory($importLocalAppData) | Out-Null
if (@(Get-ChildItem -LiteralPath $importAppData -Force).Count -ne 0 -or @(Get-ChildItem -LiteralPath $importLocalAppData -Force).Count -ne 0) { throw 'import environment is not empty' }
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable exists before import' }
$importArguments = [string[]]@('--headless', '--editor', '--import', '--quit', '--path', $disposableProject)
& $controller -ExecutablePath $godot -ArgumentVector $importArguments -AppDataPath $importAppData -LocalAppDataPath $importLocalAppData -TimeoutMilliseconds 720000 -StdoutPath (Join-Path $evidenceRoot 'import.stdout.txt') -StderrPath (Join-Path $evidenceRoot 'import.stderr.txt') -ResultPath (Join-Path $evidenceRoot 'import.controller-result.json')
```

Require controller success, no timeout or kill, native exit `0`, exact executable/argument vector/environment metadata, no prohibited diagnostics, and no surviving task-owned process. Compare post-import inventory with pre-import. Permit only `.godot/**`; new `*.gd.uid` whose exact `.gd` sibling existed pre-import; and new `*.png.import` whose exact `.png` sibling existed pre-import, whose `source_file` equals the sibling `res://` path exactly once, and whose normalized declared targets are exclusively under `res://.godot/imported/` and exist. Reject every changed/deleted pre-import byte and every unexplained addition or external/traversal reference. Prove the authoritative worktree was not written.

- [ ] **Step 7: Run exactly one complete suite in the imported copy**

Create a separate unused environment and run:

```powershell
$suiteAppData = Join-Path $evidenceRoot 'suite-appdata'
$suiteLocalAppData = Join-Path $evidenceRoot 'suite-localappdata'
[System.IO.Directory]::CreateDirectory($suiteAppData) | Out-Null
[System.IO.Directory]::CreateDirectory($suiteLocalAppData) | Out-Null
if (@(Get-ChildItem -LiteralPath $suiteAppData -Force).Count -ne 0 -or @(Get-ChildItem -LiteralPath $suiteLocalAppData -Force).Count -ne 0) { throw 'suite environment is not empty' }
if (Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE) { throw 'probe variable exists before full suite' }
$suiteArguments = [string[]]@('--headless', '--path', $disposableProject, '--script', 'res://tests/test_runner.gd')
& $controller -ExecutablePath $godot -ArgumentVector $suiteArguments -AppDataPath $suiteAppData -LocalAppDataPath $suiteLocalAppData -TimeoutMilliseconds 720000 -StdoutPath (Join-Path $evidenceRoot 'suite.stdout.txt') -StderrPath (Join-Path $evidenceRoot 'suite.stderr.txt') -ResultPath (Join-Path $evidenceRoot 'suite.controller-result.json')
```

Require no timeout/controller failure/kill, native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (265 suites)`, zero FAIL markers, zero `TEST_FAILURE`, and no prohibited diagnostic class. Reinventory the disposable project and apply the same generated-path classification; no tracked source byte may change.

- [ ] **Step 8: Compare normalized diagnostic families with the accepted known-pass reference**

Revalidate these immutable authorities before parsing:

```text
Reference stderr:
C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-step4b-20260901T073118Z-5f5655f4\evidence\full-suite.stderr.txt
SHA-256 201609952ff70f2b6e9cd5b249f895e52e1da01ff1af4d414a933ad2b312b7a9

Qualified normalizer:
C:\Users\Jacob\AppData\Local\Temp\pf-rig-normalizer-step7a-v2-1-20260901T124044Z-43216493\volatile-diagnostic-normalizer-v2-1.ps1
SHA-256 04ce24ae6bf3cc77224386de031fd7674e3702a1946a3e5538e171fe22d02c1e

Qualified normalizer manifest:
C:\Users\Jacob\AppData\Local\Temp\pf-rig-normalizer-step7a-v2-1-20260901T124044Z-43216493\evidence-manifest-v2-1.json
SHA-256 14b1aaf0a070ee87e2b4de404ef583d282f422a3fa3ddfaec085bf73e1b0791a

Accepted reference family manifest:
C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-ast-v3-20260901T133813Z-1c76419e\reference-diagnostic-families-v2.jsonl
SHA-256 3653bbad8e459ad78218333d3e41292737c3a765c5a834ad39a7dc6994c07504
```

Create the comparison paths and copy these accepted scripts byte-for-byte:

```powershell
$comparisonRoot = Join-Path $evidenceRoot 'diagnostic-comparison'
[System.IO.Directory]::CreateDirectory($comparisonRoot) | Out-Null
$sourceComparisonHarness = 'C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-ast-v3-20260901T133813Z-1c76419e\run-step7b-reclassification-v2.ps1'
$sourceComparisonVerifier = 'C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2\verify-step7b-reclassification-v2.ps1'
$comparisonHarness = Join-Path $comparisonRoot 'run-step7b-reclassification-v2.ps1'
$comparisonVerifier = Join-Path $comparisonRoot 'verify-step7b-reclassification-v2.ps1'
Copy-Item -LiteralPath $sourceComparisonHarness -Destination $comparisonHarness
Copy-Item -LiteralPath $sourceComparisonVerifier -Destination $comparisonVerifier
```

Source identities:

```text
Reclassification harness source:
C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-ast-v3-20260901T133813Z-1c76419e\run-step7b-reclassification-v2.ps1
SHA-256 458369108af8e61fb8b47b372b30caf86bdf755a2ddda0982791efb175d703be

Independent verifier source:
C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2\verify-step7b-reclassification-v2.ps1
SHA-256 1fedb0ef1d9320901894a300a5e36752b98a7a37876b3d684d7d9e9d61b234a4
```

In the copied reclassification harness, replace exactly the two assignment lines for `$script:CurrentStderrPath` and `$script:CurrentStderrSha256` with the literal absolute `$evidenceRoot\suite.stderr.txt` path and its freshly computed lowercase SHA-256. In the copied verifier, replace exactly those same two assignment lines plus `$script:ExpectedHead` with the new suite path/hash and `$helperRemovalCommit`. Use single-quoted PowerShell literals and double embedded apostrophes if a runtime value contains one. Require unchanged line counts, exact two-line and three-line diffs respectively, zero parser errors, and byte-identical remaining lines. No algorithm, reference, normalizer, expected count, project path, output contract, or waiver map may change.

Before either script parses diagnostic content, write `step7b-preexecution-static-result-v2.json` in `$comparisonRoot` from the successful syntax/hash/mechanical-diff qualification:

```powershell
$preexecutionRecord = [ordered]@{
    schema = 3
    gate = 'production_rig_code_quality_diagnostic_comparison_preexecution'
    pristine = $true
    real_stderr_inputs_read = $false
    source_harness_sha256 = '458369108af8e61fb8b47b372b30caf86bdf755a2ddda0982791efb175d703be'
    source_verifier_sha256 = '1fedb0ef1d9320901894a300a5e36752b98a7a37876b3d684d7d9e9d61b234a4'
    qualified_harness_sha256 = (Get-FileHash -LiteralPath $comparisonHarness -Algorithm SHA256).Hash.ToLowerInvariant()
    qualified_verifier_sha256 = (Get-FileHash -LiteralPath $comparisonVerifier -Algorithm SHA256).Hash.ToLowerInvariant()
    harness_changed_lines = 2
    verifier_changed_lines = 3
}
[System.IO.File]::WriteAllText(
    (Join-Path $comparisonRoot 'step7b-preexecution-static-result-v2.json'),
    ($preexecutionRecord | ConvertTo-Json -Compress),
    [System.Text.UTF8Encoding]::new($false)
)
```

The mechanical qualification may hash the two stderr files but must not decode, split, search, normalize, or count diagnostic content before this record is written.

The copied harness may dot-source the qualified normalizer exactly once and read only the immutable reference stderr plus the new suite stderr. Run it exactly once with `-OutputDirectory $comparisonRoot`. It applies the accepted ordered header normalization and diagnostic-block algorithm: exact `ERROR:`/`WARNING:` headers; ordinal substring `GDScript backtrace`; at most one token occurrence per line and one token-bearing line per block; first `[0]` frame; ordinal family sorting; compact UTF-8 without BOM or trailing newline. `INTENTIONAL_NEW_FAMILY_BY_LABEL` remains exactly an empty hashtable.

Require both sides to contain exactly 112 ERROR headers, 18 WARNING headers, 130 global backtrace occurrences, 130 consumed backtraces, zero orphan/unconsumed occurrences, zero unparsed first frames, and zero prohibited diagnostic classes. Require the newly generated reference family manifest to hash to `3653bbad8e459ad78218333d3e41292737c3a765c5a834ad39a7dc6994c07504`; require the new suite family manifest byte-identical to it with zero added, removed, or count-different family. Raw aggregate equality alone is not acceptance.

Only after candidate PASS, run the mechanically corrected independent verifier exactly once with `-OutputDirectory $comparisonRoot`. It must not import or invoke the normalizer; it independently rehashes both stderr inputs, the normalizer/manifest, comparison harness, result, family manifests, diff, formats, counts, equality, empty waiver map, and repository containment. Stop without retry or waiver on either failure.

- [ ] **Step 9: Obtain a fresh requirements review**

Only after Steps 1-8 pass, dispatch one fresh read-only reviewer with this exact brief after interpolating hashes and evidence paths:

```powershell
$requirementsBrief = @"
Review Party Forge production-rig code-quality corrections for requirements compliance only. Do not edit any file. Execution baseline is $codeQualityCorrectionBase, whose exact provenance must be final plan correction -> f21fed4f234256b1808a86e331fa0a99fee51d53 -> 16bddc127eda3f536a13e301c812ec90d1ed2c04 -> approved design 71cd334df31986e102fd38c375c07cd965bf762a. Approved design is docs/superpowers/specs/2026-09-01-production-rig-code-quality-corrections-design.md at SHA-256 804c658ac18a598b9770414e01c4c5b1e98594b5da978c0c8dbb1567e0226a02. Review exactly two implementation commits after the execution baseline, in order: $constructionCommit and $helperRemovalCommit. Product/test scope is exactly the four paths in the plan. Evidence root is $evidenceRoot. Return PASS or FAIL with exact file:line and evidence-path support for every requirement: build-independent invalid-token guard before caller-state assignment; exact constructor error; inert non-null wrapper; no caller-state exposure; private validity bit set last; validity-aware is_success; unchanged cold-safe RefCounted factories, single result_script load, runtime identity, accessors, defensive copies, and no public setter/state; focused invalid_direct_constructor RED and GREEN with exact environment clearance and no waiver; source/AST dominance audit; unchanged invalid factory functions without rerunning their consumed probes; removal only of _matching_name_indices and its direct helper test block; retained public duplicate/zero/empty/range/agreement/conflict validation and mapped-rig integration; exact two-commit/four-path union; fresh focused/archive/import/full-suite/diagnostic-family evidence; fixture/GLB/protected/sentinel/worktree containment; and mandatory pre-resource stop. Treat missing, contradictory, or inadequately supported evidence as FAIL. Do not review art direction, propose edits, or modify the worktree.
"@
```

Stop on FAIL or inadequate evidence. Do not dispatch the quality reviewer.

- [ ] **Step 10: Obtain a distinct fresh code-quality review**

Only after requirements PASS, dispatch a different fresh read-only reviewer with this exact brief:

```powershell
$qualityBrief = @"
Review Party Forge production-rig code-quality corrections for code quality only. Do not edit any file and do not repeat the requirements checklist. Baseline is $codeQualityCorrectionBase with exact final-correction -> f21fed4f234256b1808a86e331fa0a99fee51d53 -> 16bddc127eda3f536a13e301c812ec90d1ed2c04 -> 71cd334df31986e102fd38c375c07cd965bf762a provenance; implementation commits after that baseline are $constructionCommit then $helperRemovalCommit; evidence root is $evidenceRoot. Inspect exactly the four-path diff. Return PASS or FAIL with exact file:line and evidence support for: runtime guard dominance in debug and release; exact one-error inert behavior; zero assert-only authorization; no partial valid state; construction-validity assignment last; is_success validity gating; unchanged factory single-load allocation and cold-safe RefCounted API; no global-class downcast, nested replacement, test-only production seam, mutable error channel, or writable public state; defensive-copy correctness and Resource-reference semantics; direct-constructor probe quality and isolation; no reuse of consumed invalid_success/invalid_failure probes as post-change proof; zero _matching_name_indices references in `.gd` source/test files while documentation provenance remains legitimate; public bind validator remains the sole production name scan; no mock-behavior test or impossible duplicate Skeleton3D fixture; exact deletion-only helper commit; commit-based rollback; new tracked-archive cold import/full suite and byte-identical diagnostic-family evidence; and containment. Treat any release-only bypass, caller-state exposure, diagnostic waiver, dead duplicate logic, broader scope, or inadequate proof as FAIL. Do not propose edits or modify the worktree.
"@
```

Stop on FAIL or inadequate evidence. Do not fix in this execution.

- [ ] **Step 11: Revalidate final containment after both reviews PASS**

Rehash all 77 protected records, both GLBs, fixture, approved design, this plan, every new evidence artifact, and immutable historical evidence named by the design. Require exact two-commit/four-path union, clean tracked/index state, all five sentinels absent, Dawn Bulwark still at its recorded checkpoint with exactly three modifications, and Combat HUD untouched by this lane while reporting any concurrent read-only drift.

---

### Task D: Stop at the Corrected Pre-Resource Checkpoint

**Files:**
- No changes.

**Interfaces:**
- Consumes: both independent PASS reviews and the final containment audit.
- Produces: one Studio Lead checkpoint report and no further mutation.

- [ ] **Step 1: Report the exact checkpoint**

Report:

- worktree, branch, `$codeQualityCorrectionBase`, its exact helper-audit-correction/original-plan/approved-design provenance chain, both implementation hashes/parents/subjects, and exact four-path union;
- approved design and plan hashes;
- trustworthy constructor RED, constructor GREEN, normal focused GREEN, source-structure dominance result, helper characterization before/after, combined focused gate, archive hash, import classification, full-suite marker/exit, diagnostic-family equality, and two reviewer verdicts;
- confirmation that `invalid_success`, `invalid_failure`, and unrelated consumed gates were not rerun or cited as post-change proof;
- protected 77-file, fixture, GLB, sentinel, Dawn Bulwark, Combat HUD, and historical-evidence containment;
- rollback boundaries and remaining risks.

- [ ] **Step 2: Mandatory stop**

Do not create masculine, feminine, or shared mapping `.tres` resources. Do not start body qualification, presentation integration, heads, armor, Dawn Bulwark production, equipment, Blender, assets, downloads, merge, rebase, push, cleanup, deletion, or publication. A new Studio Lead authorization is required.

## Approved-Requirement Traceability

| Approved specification requirement | Plan evidence |
|---|---|
| Build-independent invalid-token rejection before any caller-state assignment | Task A exact `_init()` patch, one-shot probe GREEN, and source-structure dominance audit. |
| Inert non-null wrapper, exact one error, no caller-state exposure | Task A isolated probe assertions and exact captured error. |
| Private validity bit set last and validity-aware success | Task A implementation and source-order audit. |
| Cold-safe factories and runtime identity unchanged | Task A normal catalog GREEN, exact factory-blob comparison, and both reviewers. |
| No source mutation, test-only production seam, global-class dependency, nested wrapper, mutable last error, or public writable state | Task A exact scope/audit and code-quality review. |
| Dead helper and only its direct test logic removed | Task B deletion blocks, zero-GDScript-reference search, and exact deletion-only commit. |
| Public bind-identity behavior remains complete | Task B before/after characterization and retained assertion audit. |
| Two independently reviewable commits and exact four-path union | Task A/Task B commit gates and Task C history audit. |
| Fresh post-change runtime qualification | Task C focused gate, new tracked archive, disposable cold import, full suite, normalized family comparison, and independent verifier. |
| Two fresh sequential read-only reviews | Task C Steps 9-10. |
| Protected inputs, worktrees, evidence, and sentinels remain intact | Task 0, every commit gate, and Task C final containment. |
| No resource or art progression | Task D mandatory stop. |

## Rollback

- Revert `refactor: remove obsolete rig name helper` to restore only `_matching_name_indices()` and its direct helper test block.
- Revert `fix: enforce release-safe rig result construction` only under an explicit approval acknowledging restoration of the release-unsafe assert-only boundary.
- Never amend, squash, rebase, or rewrite either implementation commit or the approved design/plan history.
- Never delete, overwrite, or reinterpret RED/GREEN, archive/import/full-suite, diagnostic, verifier, reviewer, or historical evidence as a rollback shortcut.
- A rollback never touches immutable GLBs, fixture, protected untracked records, mapping resources, Dawn Bulwark, Combat HUD, or another worktree.

## Final Plan Self-Review Checklist

- Every approved design requirement maps to an exact task and terminal evidence item.
- Every code-changing step contains the complete replacement or deletion block.
- The only production/test paths are the exact four entries in the File Responsibility Map.
- The exact constructor error, probe value, method signatures, commit subjects, commands, marker counts, and stop conditions are consistent throughout.
- The constructor RED is one-shot, narrowly classified, and stops before production changes if the old debug assertion cannot yield the exact two-failure evidence.
- Dead-code removal uses before/after characterization rather than a fabricated RED.
- Normal processes require the probe environment absent; consumed probes are provenance only.
- The archive/import/full-suite qualification is fresh for these changes and does not treat historical runtime evidence as post-change proof.
- Both reviewers are fresh, read-only, distinct, and sequential.
- Code fences are balanced, `git diff --check` is required before both commits and final reporting, and no incomplete requirement or undefined interface remains.
