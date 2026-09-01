# Production Rig Review Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the approved production-rig review gaps with read-only structured mapping results, exact-path stateless catalog resolution, a pure mapped-bind identity boundary, and inspected two-body end-to-end validator proof without creating mapping resources or starting presentation integration.

**Architecture:** `HumanoidRigMappingResolution` is a factory-created read-only per-call value wrapper; `HumanoidRigMappingLoader` is the exact-path `ResourceLoader` seam; and `HumanoidRigMappingCatalog` remains stateless by accepting a loader per call. `HumanoidRigContract` gains one pure bind-identity function used by mapped validation, while fixture-backed tests prove both inspected 52-bone bodies through mapped and strict legacy boundaries. Four independently reviewable implementation commits precede fresh focused, cold-import, full-suite, and two-reviewer gates.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, `RefCounted`, `ResourceLoader`, `Skeleton3D`, `Skin`, path-free JSON fixtures, SHA-256, PowerShell 7, `System.Diagnostics.Process`, Git archives, focused Godot tests, and the complete headless suite.

## Global Constraints

- Authoritative worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement`.
- Required branch: `feat/class-preview-character-model-replacement`.
- Approved design checkpoint before this plan: `295ec988877bf2017ef7fb7b77fda13099d1c23a`.
- Approved design: `docs/superpowers/specs/2026-09-01-production-rig-review-correction-design.md`, SHA-256 `4dbd4c70a7732707adfc34d8722518066c9681566b28e0a3b29afa8efff56906`.
- Original implementation base remains `d729b520252c7dc2ad2e9ba7182f63f4c33c27dd`; its thirteen pre-implementation first-parent descendants after this plan correction must not be rewritten. The first eleven predate this corrective plan, commit twelve is `docs: plan production rig review corrections`, and commit thirteen is the diagnostic-free behavior-RED correction that establishes `correctionImplementationBase`.
- The approved seven-path product scope is exact. No eighth product path is allowed.
- `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json` remains byte-identical at SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`.
- Preserve all 77 protected untracked records from `C:\Users\Jacob\AppData\Local\Temp\pf-character-task2-reconcile-gate-0001\premerge-untracked-manifest.json`, whose manifest SHA-256 is `9f7d8b800e27f94d2bc1f7798a88c9bda73c65d0429c3c072bbe00daeafbe2bd`.
- Preserve the masculine GLB SHA-256 `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` and feminine GLB SHA-256 `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`.
- Preserve Dawn Bulwark at `8617495a2ea7ce9f0d1af86e4fa35766df86d735` with its three task-owned modifications. Treat Combat HUD as independently active read-only state; snapshot and report its drift, but never target or write its worktree.
- The shared, masculine, and feminine mapping `.tres` resources remain absent. `data/presentation/manifests/pf_character_equipment_v2.json` and `docs/qa/character-model-replacement/body-pair-qualification.md` remain absent.
- Do not modify `validate_rig()`, `validate_skin()`, their six-decimal serializers, or their externally observed errors.
- Do not add test-only production methods. Loader injection is the approved production dependency seam; tests exercise real result, loader, catalog, and validator behavior.
- The catalog stores no active preset, active mapping, active body, active model, result history, or last error. Active-visual transaction and rollback remain deferred.
- Use path preflight and method-shape guards before loading or calling not-yet-created scripts. A missing global class cache, parser failure, loader failure, or invalid project path is never a trustworthy RED.
- A focused GREEN requires native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero fail markers, and no unexplained parser, loader, import, script, crash, fatal, segmentation, object-leak, or RID-leak diagnostics.
- A focused RED requires nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL` marker, only the explicitly named assertion failures, and zero infrastructure diagnostics.
- `PF_RIG_FACTORY_CONTRACT_PROBE` must be absent from every normal focused regression, cold import, and full-suite process. Only Task A1's two isolated intentional-error probes may set it, and each probe must clear it before another process begins.
- No downloads, Blender, 3D Gen Studio, asset import into the authoritative worktree, geometry, rigging, weights, UVs, textures, preview, merge, rebase, push, cleanup, deletion, or publication.

---

## File Responsibility Map

| Path | Action | Exact responsibility |
|---|---|---|
| `scripts/presentation/humanoid_rig_mapping_resolution.gd` | Create | Factory-only, read-only structured resolution result; private state, defensive accessors, deterministic factory validation, and pure mapped-rig rejection transformation. |
| `scripts/presentation/humanoid_rig_mapping_loader.gd` | Create | Stateless exact-path `ResourceLoader` adapter with injectable callables for deterministic tests. |
| `scripts/presentation/humanoid_rig_mapping_catalog.gd` | Modify | Replace preset-keyed mapping storage with per-call exact-path resolution, identity checking, and structured results. |
| `scripts/presentation/humanoid_rig_contract.gd` | Modify | Add public pure `validate_mapped_bind_identity()` and route mapped bind slots through it without touching legacy paths. |
| `tests/unit/test_humanoid_rig_mapping_catalog.gd` | Modify | Guard cold resolution; test result factories/accessors, loader calls, catalog paths, categories, messages, statelessness, and no fallback. |
| `tests/unit/test_production_humanoid_rig_mapping.gd` | Modify | Test pure bind identity plus public null/empty-target mapped-validator gaps while retaining every existing mapped-rig assertion. |
| `tests/unit/test_production_humanoid_rest_signature.gd` | Modify | Reconstruct both inspected 52-bone bodies, create 52 unnamed numeric binds, prove mapped success and strict legacy failure. |

No fixture, runner, support, plan, spec, resource, manifest, scene, import sidecar, or asset joins the product path union.

## Exact Interfaces

```gdscript
# humanoid_rig_mapping_resolution.gd
static func succeeded(
		requested_body_preset: StringName,
		selected_resource_path: String,
		mapping: HumanoidRigMapping
	) -> HumanoidRigMappingResolution
static func failed(
		requested_body_preset: StringName,
		selected_resource_path: String,
		failure_categories: Array[StringName],
		error_messages: PackedStringArray
	) -> HumanoidRigMappingResolution
func get_requested_body_preset() -> StringName
func get_selected_resource_path() -> String
func get_mapping() -> HumanoidRigMapping
func get_failure_categories() -> Array[StringName]
func get_error_messages() -> PackedStringArray
func is_success() -> bool
func rejected_by_mapped_rig(validation_errors: PackedStringArray) -> HumanoidRigMappingResolution

# humanoid_rig_mapping_loader.gd
func _init(exists_override: Callable = Callable(), load_override: Callable = Callable()) -> void
func exists_exact(resource_path: String) -> bool
func load_exact(resource_path: String) -> Variant

# humanoid_rig_mapping_catalog.gd
func resolve(
		body_preset_id: StringName,
		loader: HumanoidRigMappingLoader = null
	) -> HumanoidRigMappingResolution

# humanoid_rig_contract.gd
static func validate_mapped_bind_identity(
		bone_names: Array[StringName],
		bind_name: StringName,
		numeric_bone_index: int,
		bind_slot: int
	) -> PackedStringArray
```

Production files preload neighboring scripts into aliases and use those aliases in type annotations. No new implementation relies on a newly generated global `class_name` cache to parse in a cold worktree.

## Exact Category and Resource Tables

Category precedence is immutable:

```text
unknown_body_preset
missing_resource
resource_load_failed
wrong_resource_type
wrong_mapping_id
wrong_canonical_rig_id
wrong_source_hash
wrong_rest_signature
mapped_rig_validation_failed
```

Exact resource URIs are:

```text
masculine -> res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres
feminine  -> res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres
```

The shared URI `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres` is forbidden.

---

### Task 0: Capture the Correction Execution Baseline

**Files:**
- Read only: the repository, approved design, this plan, protected manifest, immutable GLBs, Dawn Bulwark worktree, and Combat HUD worktree.
- Evidence only: a new task-owned directory under `C:\Users\Jacob\AppData\Local\Temp`.

**Interfaces:**
- Consumes: the committed plan review approval.
- Produces: `correctionImplementationBase`, immutable pre-operation hashes, and the exact allowed path set used by every later audit.

- [ ] **Step 1: Revalidate the approved authoring ancestry**

Run:

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
$originalBase = 'd729b520252c7dc2ad2e9ba7182f63f4c33c27dd'
$approvedDesignParent = '295ec988877bf2017ef7fb7b77fda13099d1c23a'
$correctionImplementationBase = git -C $project rev-parse HEAD
git -C $project merge-base --is-ancestor $approvedDesignParent $correctionImplementationBase
git -C $project rev-list --first-parent --count "$originalBase..$correctionImplementationBase"
git -C $project log --first-parent --format='%H%x09%s' "$originalBase..$correctionImplementationBase"
git -C $project status --porcelain=v1 -uno
```

Expected:

- branch is `feat/class-preview-character-model-replacement`;
- `295ec988...` is an ancestor;
- exactly thirteen first-parent commits follow `originalBase`;
- the first eleven are the three existing implementation commits, six original plan corrections, and the two correction-spec commits already verified by the Studio Lead;
- commit twelve is this plan-only commit with subject `docs: plan production rig review corrections`;
- commit thirteen is the plan-only correction with subject `docs: add production rig behavior RED gates`;
- tracked/index state is clean;
- none of the seven product paths differs from `295ec988...`, and the two prospective new production files are absent.

- [ ] **Step 2: Record baseline and containment evidence**

Create a fresh evidence root with `New-Item -ItemType Directory`, record `correctionImplementationBase`, the exact thirteen-commit history, `git status`, `git diff --check`, the seven-path allowlist, the 77-record manifest verification, both GLB hashes, the fixture hash, the three existing spec/plan hashes, all five absent sentinels, and Dawn/Combat HUD read-only snapshots. Store JSON with UTF-8 no BOM. Do not write any repository path.

Stop if any hash, path count, ancestor, sentinel, or protected worktree boundary differs materially.

---

### Task A1: Add Read-Only Resolution Results and the Exact-Path Loader

**Files:**
- Create: `scripts/presentation/humanoid_rig_mapping_resolution.gd`
- Create: `scripts/presentation/humanoid_rig_mapping_loader.gd`
- Modify: `tests/unit/test_humanoid_rig_mapping_catalog.gd`

**Interfaces:**
- Consumes: `HumanoidRigMapping` and the exact body-preset resource table.
- Produces: the result and loader interfaces listed above. Task A2 consumes both through explicit preloads.

- [ ] **Step 1: Add a diagnostic-free missing-file RED guard**

At the start of `test_humanoid_rig_mapping_catalog.gd::run()`, before any `load()` or `preload()` of a prospective file, add:

```gdscript
const RESOLUTION_PATH := "res://scripts/presentation/humanoid_rig_mapping_resolution.gd"
const LOADER_PATH := "res://scripts/presentation/humanoid_rig_mapping_loader.gd"
const MASCULINE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres"
const FEMININE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres"

var resolution_exists := FileAccess.file_exists(RESOLUTION_PATH)
var loader_exists := FileAccess.file_exists(LOADER_PATH)
TestAssertions.truthy(resolution_exists, "read-only mapping resolution exists", failures)
TestAssertions.truthy(loader_exists, "exact-path mapping loader exists", failures)
if not resolution_exists or not loader_exists:
	return failures
```

After the guard, load both scripts by exact path and assert non-null before calling any method. Do not reference either new global class name in the test source.

- [ ] **Step 2: Run the A1 RED once**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd
```

Trustworthy RED requires native nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL (2 failures)`, only `read-only mapping resolution exists` and `exact-path mapping loader exists`, and zero parser, loader, import, script, engine-crash, segmentation, or leak diagnostics. Stop without production files if the RED differs.

- [ ] **Step 3: Add the minimal cold-safe A1 interface shells**

Create `humanoid_rig_mapping_resolution.gd` with exactly this neutral shell. It exposes the approved parse-safe interface and stores supplied values without validation, defensive duplication, success determination, rejection transformation, or error emission:

```gdscript
class_name HumanoidRigMappingResolution
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const _RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}

var _requested_body_preset: StringName
var _selected_resource_path: String
var _mapping: RigMapping
var _failure_categories: Array[StringName]
var _error_messages: PackedStringArray

func _init(requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping, failure_categories: Array[StringName], error_messages: PackedStringArray) -> void:
	_requested_body_preset = requested_body_preset
	_selected_resource_path = selected_resource_path
	_mapping = mapping
	_failure_categories = failure_categories
	_error_messages = error_messages

static func succeeded(requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping) -> HumanoidRigMappingResolution:
	var categories: Array[StringName] = []
	return HumanoidRigMappingResolution.new(requested_body_preset, selected_resource_path, mapping, categories, PackedStringArray())

static func failed(requested_body_preset: StringName, selected_resource_path: String, failure_categories: Array[StringName], error_messages: PackedStringArray) -> HumanoidRigMappingResolution:
	return HumanoidRigMappingResolution.new(requested_body_preset, selected_resource_path, null, failure_categories, error_messages)

func get_requested_body_preset() -> StringName:
	return _requested_body_preset

func get_selected_resource_path() -> String:
	return _selected_resource_path

func get_mapping() -> RigMapping:
	return _mapping

func get_failure_categories() -> Array[StringName]:
	var neutral: Array[StringName] = []
	return neutral

func get_error_messages() -> PackedStringArray:
	return PackedStringArray()

func is_success() -> bool:
	return false

func rejected_by_mapped_rig(_validation_errors: PackedStringArray) -> HumanoidRigMappingResolution:
	return self
```

Create `humanoid_rig_mapping_loader.gd` with exactly this neutral shell. It accepts the approved callables so construction is safe but intentionally does not invoke them:

```gdscript
class_name HumanoidRigMappingLoader
extends RefCounted

func _init(_exists_override: Callable = Callable(), _load_override: Callable = Callable()) -> void:
	pass

func exists_exact(_resource_path: String) -> bool:
	return false

func load_exact(_resource_path: String) -> Variant:
	return null
```

Do not commit these shells. Confirm `git diff --check` and exact three-path working scope, then continue directly to the behavior test slice.

- [ ] **Step 4: Add guarded result and loader behavior assertions**

After the path/load guards, test these exact behaviors against the loaded resolution script:

Add this exact method-shape helper and guard before the first call. The guard must pass against the shells; if it fails, the run returns only `A1 result and loader interfaces have exact method shapes` and is not the behavior RED:

```gdscript
func _method_argument_count(script: Script, method_name: StringName) -> int:
	for method_value: Variant in script.get_script_method_list():
		var method := method_value as Dictionary
		if StringName(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1

var interface_shape_is_exact := (
	_method_argument_count(_resolution_script, &"succeeded") == 3
	and _method_argument_count(_resolution_script, &"failed") == 4
	and _method_argument_count(_resolution_script, &"get_requested_body_preset") == 0
	and _method_argument_count(_resolution_script, &"get_selected_resource_path") == 0
	and _method_argument_count(_resolution_script, &"get_mapping") == 0
	and _method_argument_count(_resolution_script, &"get_failure_categories") == 0
	and _method_argument_count(_resolution_script, &"get_error_messages") == 0
	and _method_argument_count(_resolution_script, &"is_success") == 0
	and _method_argument_count(_resolution_script, &"rejected_by_mapped_rig") == 1
	and _method_argument_count(_loader_script, &"exists_exact") == 1
	and _method_argument_count(_loader_script, &"load_exact") == 1
)
TestAssertions.truthy(interface_shape_is_exact, "A1 result and loader interfaces have exact method shapes", failures)
if not interface_shape_is_exact:
	return failures
```

```gdscript
var mapping := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
var success: RefCounted = _resolution_script.call(
	&"succeeded", &"masculine", MASCULINE_PATH, mapping
)
TestAssertions.truthy(success != null and bool(success.call(&"is_success")), "valid success result is observable", failures)
TestAssertions.equal(success.call(&"get_requested_body_preset"), &"masculine", "success preset is read-only", failures)
TestAssertions.equal(success.call(&"get_selected_resource_path"), MASCULINE_PATH, "success path is exact", failures)
TestAssertions.equal(success.call(&"get_mapping"), mapping, "mapping getter returns the validated Resource reference", failures)
var no_categories: Array[StringName] = []
TestAssertions.equal(success.call(&"get_failure_categories"), no_categories, "success categories are empty", failures)
TestAssertions.equal(success.call(&"get_error_messages"), PackedStringArray(), "success messages are empty", failures)

mapping.set(&"mapping_id", &"mutated_after_resolution")
TestAssertions.equal((success.call(&"get_mapping") as Resource).get(&"mapping_id"), &"mutated_after_resolution", "resolution does not freeze mapping Resource internals", failures)

var categories: Array[StringName] = [&"missing_resource"]
var messages := PackedStringArray(["humanoid rig mapping catalog body preset masculine resource %s does not exist" % MASCULINE_PATH])
var failure: RefCounted = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, categories, messages)
categories.append(&"wrong_resource_type")
messages.append("caller mutation")
var returned_categories: Array = failure.call(&"get_failure_categories")
var returned_messages: PackedStringArray = failure.call(&"get_error_messages")
returned_categories.append(&"wrong_mapping_id")
returned_messages.append("returned-copy mutation")
var expected_missing_categories: Array[StringName] = [&"missing_resource"]
TestAssertions.equal(failure.call(&"get_failure_categories"), expected_missing_categories, "stored categories resist caller mutation", failures)
TestAssertions.equal((failure.call(&"get_error_messages") as PackedStringArray).size(), 1, "stored messages resist caller mutation", failures)
TestAssertions.truthy(not bool(failure.call(&"is_success")), "failed result remains failed after caller mutation", failures)

var validator_errors := PackedStringArray(["first mapped error", "second mapped error"])
var rejected: RefCounted = success.call(&"rejected_by_mapped_rig", validator_errors)
validator_errors.append("caller mutation")
var expected_rejection_categories: Array[StringName] = [
	&"mapped_rig_validation_failed",
	&"mapped_rig_validation_failed",
]
TestAssertions.equal(rejected.call(&"get_failure_categories"), expected_rejection_categories, "mapped rejection preserves category cardinality", failures)
TestAssertions.equal(rejected.call(&"get_error_messages"), PackedStringArray([
	"humanoid rig mapping catalog body preset masculine resource %s mapped rig validation failed: first mapped error" % MASCULINE_PATH,
	"humanoid rig mapping catalog body preset masculine resource %s mapped rig validation failed: second mapped error" % MASCULINE_PATH,
]), "mapped rejection preserves validator order", failures)
TestAssertions.equal(success.call(&"get_mapping"), mapping, "mapped rejection does not mutate successful result", failures)
TestAssertions.equal(success.call(&"rejected_by_mapped_rig", PackedStringArray()), success, "empty mapped rejection returns original success", failures)
TestAssertions.equal(failure.call(&"rejected_by_mapped_rig", PackedStringArray(["ignored"])), failure, "existing failure remains unchanged", failures)

var property_names := PackedStringArray()
for property: Dictionary in success.get_property_list():
	property_names.append(String(property.get("name", "")))
for public_name: String in ["requested_body_preset", "selected_resource_path", "mapping", "failure_categories", "error_messages"]:
	TestAssertions.truthy(public_name not in property_names, "result exposes no public field %s" % public_name, failures)
for setter_name: StringName in [&"set_requested_body_preset", &"set_selected_resource_path", &"set_mapping", &"set_failure_categories", &"set_error_messages"]:
	TestAssertions.truthy(not success.has_method(setter_name), "result exposes no setter %s" % setter_name, failures)
```

Add this test-local recorder at file scope. It is used first to test the loader's real callable seam and then reused by Task A2 to test the catalog; it does not add a production test hook:

```gdscript
class LoaderRecorder:
	extends RefCounted

	var existing_paths: Dictionary = {}
	var values_by_path: Dictionary = {}
	var existence_calls := PackedStringArray()
	var load_calls := PackedStringArray()

	func exists_exact(resource_path: String) -> bool:
		existence_calls.append(resource_path)
		return bool(existing_paths.get(resource_path, false))

	func load_exact(resource_path: String) -> Variant:
		load_calls.append(resource_path)
		return values_by_path.get(resource_path)
```

Instantiate and assert the loader seam with these exact labels:

```gdscript
var recorder := LoaderRecorder.new()
recorder.existing_paths[MASCULINE_PATH] = true
recorder.values_by_path[MASCULINE_PATH] = mapping
var loader: RefCounted = _loader_script.new(Callable(recorder, &"exists_exact"), Callable(recorder, &"load_exact"))
TestAssertions.truthy(bool(loader.call(&"exists_exact", MASCULINE_PATH)), "loader forwards existence callable", failures)
TestAssertions.equal(loader.call(&"load_exact", MASCULINE_PATH), mapping, "loader forwards load callable", failures)
TestAssertions.equal(recorder.existence_calls, PackedStringArray([MASCULINE_PATH]), "loader records exact existence path", failures)
TestAssertions.equal(recorder.load_calls, PackedStringArray([MASCULINE_PATH]), "loader records exact load path", failures)
TestAssertions.truthy(not bool(loader.call(&"exists_exact", FEMININE_PATH)), "loader does not substitute missing feminine existence", failures)
TestAssertions.equal(loader.call(&"load_exact", FEMININE_PATH), null, "loader does not substitute missing feminine value", failures)
TestAssertions.equal(recorder.existence_calls, PackedStringArray([MASCULINE_PATH, FEMININE_PATH]), "loader never substitutes existence path", failures)
TestAssertions.equal(recorder.load_calls, PackedStringArray([MASCULINE_PATH, FEMININE_PATH]), "loader never substitutes load path", failures)
```

Add this `PF_RIG_FACTORY_CONTRACT_PROBE` branch before normal assertions. It exercises one invalid factory call per process so the outer focused runner records exactly one intentional script error:

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
	if factory_probe == "invalid_success":
		invalid_result = _resolution_script.call(&"succeeded", &"unknown", "", null)
	elif factory_probe == "invalid_failure":
		var no_failure_categories: Array[StringName] = []
		invalid_result = _resolution_script.call(&"failed", &"masculine", MASCULINE_PATH, no_failure_categories, PackedStringArray())
	else:
		OS.remove_logger(logger)
		TestAssertions.truthy(false, "factory contract probe value is recognized", failures)
		return failures
	OS.remove_logger(logger)
	var captured: PackedStringArray = logger.call(&"drain_after_detach")
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

Also assert the resolution script's private `_RESOURCE_PATH_BY_BODY_PRESET` constant map equals the catalog's public path map byte-for-byte.

- [ ] **Step 5: Run the A1 behavior RED once**

Run the Step 2 focused command with `PF_RIG_FACTORY_CONTRACT_PROBE` absent. A trustworthy A1 behavior RED requires native nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL (11 failures)`, and exactly these failure labels in suite order:

```text
valid success result is observable
stored categories resist caller mutation
stored messages resist caller mutation
mapped rejection preserves category cardinality
mapped rejection preserves validator order
loader forwards existence callable
loader forwards load callable
loader records exact existence path
loader records exact load path
loader never substitutes existence path
loader never substitutes load path
```

The interface-shape assertion, all other result assertions, the two neutral feminine loader assertions, and the path-table equality must pass. Require zero parser, loader, import, script, engine-crash, segmentation, object-leak, or RID-leak diagnostics. Preserve this RED before replacing either shell. Any extra/missing failure or diagnostic is a stop condition.

- [ ] **Step 6: Replace the result shell with the approved implementation**

Implement the approved spec exactly. The complete structural content is:

```gdscript
class_name HumanoidRigMappingResolution
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const _RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}
const UNKNOWN_BODY_PRESET := &"unknown_body_preset"
const MISSING_RESOURCE := &"missing_resource"
const RESOURCE_LOAD_FAILED := &"resource_load_failed"
const WRONG_RESOURCE_TYPE := &"wrong_resource_type"
const WRONG_MAPPING_ID := &"wrong_mapping_id"
const WRONG_CANONICAL_RIG_ID := &"wrong_canonical_rig_id"
const WRONG_SOURCE_HASH := &"wrong_source_hash"
const WRONG_REST_SIGNATURE := &"wrong_rest_signature"
const MAPPED_RIG_VALIDATION_FAILED := &"mapped_rig_validation_failed"
const _CATEGORY_ORDER := {
	UNKNOWN_BODY_PRESET: 0, MISSING_RESOURCE: 1, RESOURCE_LOAD_FAILED: 2,
	WRONG_RESOURCE_TYPE: 3, WRONG_MAPPING_ID: 4, WRONG_CANONICAL_RIG_ID: 5,
	WRONG_SOURCE_HASH: 6, WRONG_REST_SIGNATURE: 7, MAPPED_RIG_VALIDATION_FAILED: 8,
}
static var _factory_token := RefCounted.new()

var _requested_body_preset: StringName
var _selected_resource_path: String
var _mapping: RigMapping
var _failure_categories: Array[StringName]
var _error_messages: PackedStringArray

func _init(factory_token: RefCounted, requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping, failure_categories: Array[StringName], error_messages: PackedStringArray) -> void:
	assert(factory_token == _factory_token, "humanoid rig mapping resolution constructor is factory-only")
	_requested_body_preset = requested_body_preset
	_selected_resource_path = selected_resource_path
	_mapping = mapping
	_failure_categories.assign(failure_categories)
	_error_messages = error_messages.duplicate()

static func succeeded(requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping) -> HumanoidRigMappingResolution:
	var defects := PackedStringArray()
	if requested_body_preset not in _RESOURCE_PATH_BY_BODY_PRESET:
		defects.append("success body preset %s is invalid" % requested_body_preset)
	elif selected_resource_path != _RESOURCE_PATH_BY_BODY_PRESET[requested_body_preset]:
		defects.append("success resource path does not match body preset %s" % requested_body_preset)
	if mapping == null:
		defects.append("success mapping is missing")
	if not defects.is_empty():
		push_error("humanoid rig mapping resolution factory contract failed: %s" % "; ".join(defects))
		return null
	var categories: Array[StringName] = []
	return HumanoidRigMappingResolution.new(_factory_token, requested_body_preset, selected_resource_path, mapping, categories, PackedStringArray())

static func failed(requested_body_preset: StringName, selected_resource_path: String, failure_categories: Array[StringName], error_messages: PackedStringArray) -> HumanoidRigMappingResolution:
	var categories: Array[StringName] = []
	categories.assign(failure_categories)
	var messages := error_messages.duplicate()
	var defects := _failure_defects(requested_body_preset, selected_resource_path, categories, messages)
	if not defects.is_empty():
		push_error("humanoid rig mapping resolution factory contract failed: %s" % "; ".join(defects))
		return null
	return HumanoidRigMappingResolution.new(_factory_token, requested_body_preset, selected_resource_path, null, categories, messages)

func get_requested_body_preset() -> StringName:
	return _requested_body_preset

func get_selected_resource_path() -> String:
	return _selected_resource_path

func get_mapping() -> RigMapping:
	return _mapping

func get_failure_categories() -> Array[StringName]:
	var copy: Array[StringName] = []
	copy.assign(_failure_categories)
	return copy

func get_error_messages() -> PackedStringArray:
	return _error_messages.duplicate()

func is_success() -> bool:
	return _requested_body_preset in _RESOURCE_PATH_BY_BODY_PRESET and _selected_resource_path == _RESOURCE_PATH_BY_BODY_PRESET[_requested_body_preset] and _mapping != null and _failure_categories.is_empty() and _error_messages.is_empty()

func rejected_by_mapped_rig(validation_errors: PackedStringArray) -> HumanoidRigMappingResolution:
	if not is_success() or validation_errors.is_empty():
		return self
	var copied_errors := validation_errors.duplicate()
	var categories: Array[StringName] = []
	var messages := PackedStringArray()
	for validation_error: String in copied_errors:
		categories.append(MAPPED_RIG_VALIDATION_FAILED)
		messages.append("humanoid rig mapping catalog body preset %s resource %s mapped rig validation failed: %s" % [_requested_body_preset, _selected_resource_path, validation_error])
	return failed(_requested_body_preset, _selected_resource_path, categories, messages)

static func _failure_defects(requested_body_preset: StringName, selected_resource_path: String, categories: Array[StringName], messages: PackedStringArray) -> PackedStringArray:
	var defects := PackedStringArray()
	if categories.is_empty():
		defects.append("failure categories are empty")
	if messages.is_empty():
		defects.append("failure messages are empty")
	if categories.size() != messages.size():
		defects.append("failure category/message cardinality differs: %d categories, %d messages" % [categories.size(), messages.size()])
	var every_category_known := true
	for index: int in categories.size():
		var category := categories[index]
		if not _CATEGORY_ORDER.has(category):
			defects.append("failure category %d is unknown: %s" % [index, category])
			every_category_known = false
		if index < messages.size() and messages[index].strip_edges().is_empty():
			defects.append("failure message %d is empty" % index)
	if every_category_known and not categories.is_empty():
		var first_order := int(_CATEGORY_ORDER[categories[0]])
		if first_order <= 3:
			if categories.size() != 1:
				defects.append("terminal failure category %s must be the only category" % categories[0])
		elif first_order <= 7:
			var previous_order := 3
			for category: StringName in categories:
				var current_order := int(_CATEGORY_ORDER[category])
				if current_order < 4 or current_order > 7 or current_order <= previous_order:
					defects.append("identity failure categories must be unique and strictly ordered")
					break
				previous_order = current_order
		else:
			for category: StringName in categories:
				if category != MAPPED_RIG_VALIDATION_FAILED:
					defects.append("mapped rig validation failures cannot mix with another category")
					break
	if not categories.is_empty() and categories[0] == UNKNOWN_BODY_PRESET:
		if requested_body_preset in _RESOURCE_PATH_BY_BODY_PRESET:
			defects.append("unknown preset failure requires an unknown body preset")
		if not selected_resource_path.is_empty():
			defects.append("unknown preset failure requires an empty resource path")
	elif not categories.is_empty() and _CATEGORY_ORDER.has(categories[0]):
		if requested_body_preset not in _RESOURCE_PATH_BY_BODY_PRESET:
			defects.append("failure requires a known body preset")
		elif selected_resource_path != _RESOURCE_PATH_BY_BODY_PRESET[requested_body_preset]:
			defects.append("failure resource path does not match body preset %s" % requested_body_preset)
	return defects
```

- [ ] **Step 7: Replace the loader shell with the approved implementation**

Use this complete implementation:

```gdscript
class_name HumanoidRigMappingLoader
extends RefCounted

var _exists_override: Callable
var _load_override: Callable

func _init(exists_override: Callable = Callable(), load_override: Callable = Callable()) -> void:
	_exists_override = exists_override
	_load_override = load_override

func exists_exact(resource_path: String) -> bool:
	if _exists_override.is_valid():
		return bool(_exists_override.call(resource_path))
	return ResourceLoader.exists(resource_path)

func load_exact(resource_path: String) -> Variant:
	if _load_override.is_valid():
		return _load_override.call(resource_path)
	return ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
```

The callable constructor is the production dependency seam, not a test-only method. The catalog still receives a loader per call and stores no loader.

- [ ] **Step 8: Run normal A1 GREEN**

Run the Step 2 command with `PF_RIG_FACTORY_CONTRACT_PROBE` absent. Require exit `0`, exactly one `TEST_SUMMARY: PASS (0 failures)`, and zero prohibited diagnostics.

- [ ] **Step 9: Run both isolated intentional factory-contract probes**

Run the same focused command once with `PF_RIG_FACTORY_CONTRACT_PROBE=invalid_success`, clear it, then once with `PF_RIG_FACTORY_CONTRACT_PROBE=invalid_failure`, and clear it again. Each process is independently bounded and preserved. Expected native exit is nonzero because the focused runner captures the intentional `push_error`. For each process require:

- exactly one terminal `TEST_SUMMARY: FAIL (1 failures)`;
- the suite's own null and captured-message assertions produce no `TEST_FAILURE`;
- exactly one captured script error beginning `humanoid rig mapping resolution factory contract failed:`;
- no parser, loader, import, crash, segmentation, or leak diagnostic.

Preserve this as an intentional programmer-contract probe, not a product RED or GREEN. Clear the environment variable immediately afterward.

- [ ] **Step 10: Commit A1**

Run `git diff --check`, rehash the fixture/protected files, and require exact scope:

```text
scripts/presentation/humanoid_rig_mapping_loader.gd
scripts/presentation/humanoid_rig_mapping_resolution.gd
tests/unit/test_humanoid_rig_mapping_catalog.gd
```

Commit only those paths:

```powershell
git -C $project add -- scripts/presentation/humanoid_rig_mapping_loader.gd scripts/presentation/humanoid_rig_mapping_resolution.gd tests/unit/test_humanoid_rig_mapping_catalog.gd
git -C $project commit -m 'feat: add read-only rig mapping results'
```

---

### Task A2: Replace Preset-Keyed Injection with Exact-Path Stateless Resolution

**Files:**
- Modify: `scripts/presentation/humanoid_rig_mapping_catalog.gd`
- Modify: `tests/unit/test_humanoid_rig_mapping_catalog.gd`

**Interfaces:**
- Consumes: `HumanoidRigMappingResolution`, `HumanoidRigMappingLoader`, existing mapping identity constants, and `HumanoidRigContract.CANONICAL_RIG_ID`.
- Produces: the exact two-argument `resolve()` interface. No state survives a call.

- [ ] **Step 1: Add complete catalog behavior tests with a method-shape guard**

Reuse `_method_argument_count()` from Task A1 and add this guard before calling the changed method. It requires `resolve` to have exactly two arguments and returns before invocation when the old one-argument shape remains, preventing an argument-count engine diagnostic during RED:

```gdscript
var resolve_argument_count := _method_argument_count(_catalog_script, &"resolve")
TestAssertions.equal(resolve_argument_count, 2, "catalog exposes per-call exact-path structured resolve", failures)
if resolve_argument_count != 2:
	return failures
```

Reuse the test-local `LoaderRecorder` created in Task A1. After the method-shape guard, construct the production loader script with `loader_script.new(Callable(recorder, &"exists_exact"), Callable(recorder, &"load_exact"))`. For every injected outcome use a fresh recorder so exact call counts cannot leak between cases.

Add this exact snapshot helper. Each matrix row below is one `TestAssertions.equal(actual_snapshot, expected_snapshot, label, failures)` assertion, so the shell RED has one stable failure per incomplete behavior rather than incidental field-level counts:

```gdscript
func _resolution_snapshot(result: RefCounted, recorder: LoaderRecorder = null) -> Dictionary:
	return {
		&"preset": result.call(&"get_requested_body_preset"),
		&"path": result.call(&"get_selected_resource_path"),
		&"mapping": result.call(&"get_mapping"),
		&"categories": result.call(&"get_failure_categories"),
		&"messages": result.call(&"get_error_messages"),
		&"success": bool(result.call(&"is_success")),
		&"existence_calls": recorder.existence_calls.duplicate() if recorder != null else PackedStringArray(),
		&"load_calls": recorder.load_calls.duplicate() if recorder != null else PackedStringArray(),
	}
```

The expected matrix is exact. Each row names `MASCULINE_PATH` or `FEMININE_PATH` directly; there is no placeholder substitution or alternate path. Messages are the literal templates from the Exact Category and Resource Tables with those named constants interpolated:

| Assertion label | Fixture and exact expected snapshot |
|---|---|
| `unknown preset avoids loader and returns exact failure` | Request `&"unknown"`; empty path; null mapping; categories `[&"unknown_body_preset"]`; message `humanoid rig mapping catalog body preset unknown is unknown`; success false; both call arrays empty. |
| `missing resource outcome is exact` | Masculine recorder reports absent; masculine path; null mapping; categories `[&"missing_resource"]`; exact missing-resource message; success false; existence calls `[MASCULINE_PATH]`; load calls empty. |
| `default production loader reports exact missing resource` | Call masculine with no loader while the forbidden resource is absent; same structured missing-resource fields; call arrays empty because no recorder is injected. |
| `failed load outcome is exact` | Masculine recorder reports present and returns null; categories `[&"resource_load_failed"]`; exact failed-load message; existence/load calls each `[MASCULINE_PATH]`. |
| `wrong resource type outcome is exact` | Masculine recorder returns `Resource.new()`; categories `[&"wrong_resource_type"]`; actual type `Resource`; exact wrong-type message; both call arrays `[MASCULINE_PATH]`. |
| `identity mismatch categories and messages are ordered` | Masculine recorder returns a mapping with ID `&"wrong"`, canonical ID `&"wrong"`, feminine source SHA, and feminine rest signature; categories are `[&"wrong_mapping_id", &"wrong_canonical_rig_id", &"wrong_source_hash", &"wrong_rest_signature"]`; the four exact messages use masculine expected values and actual wrong/feminine values in that order; both call arrays `[MASCULINE_PATH]`. |
| `masculine exact path resolution succeeds` | Masculine mapping; masculine path; identical mapping reference; empty categories/messages; success true; both call arrays `[MASCULINE_PATH]`. |
| `feminine exact path resolution succeeds` | Feminine mapping; feminine path; identical mapping reference; empty categories/messages; success true; both call arrays `[FEMININE_PATH]`. |
| `cross-body mapping fails without fallback` | Masculine request returns feminine mapping; categories `[&"wrong_mapping_id", &"wrong_source_hash", &"wrong_rest_signature"]` and exact ordered messages; null mapping; success false; both call arrays contain only `[MASCULINE_PATH]`. |

After the matrix, resolve masculine successfully, retain that result, run a new unknown-preset failure, then assert the retained result still reports success, the same mapping reference, and empty categories/messages with label `later catalog failure does not mutate prior success`. Concatenate every recorder call array and assert the shared resource URI never occurs. Inspect the catalog property list and assert no active/result/error field. Assert the catalog and resolution path tables are exactly equal.

Delete the old `_activate_if_resolved()` test helper and its simulated `active_mapping` assertions. Those assertions are replaced by the result immutability checks above; real active-visual commit/rollback remains intentionally deferred and must not be claimed by this unit suite.

- [ ] **Step 2: Run A2 RED once**

Run the focused catalog command. Trustworthy RED requires nonzero exit, exactly one `TEST_SUMMARY: FAIL (1 failures)`, only `catalog exposes per-call exact-path structured resolve`, and zero infrastructure diagnostics.

- [ ] **Step 3: Install the minimal stateless two-argument catalog shell**

Replace the old constructor state and one-argument method with this exact shell. It returns valid structured unknown/missing failures, ignores the loader, emits no error, stores no state, and never searches another path:

```gdscript
class_name HumanoidRigMappingCatalog
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const MappingResolution := preload("res://scripts/presentation/humanoid_rig_mapping_resolution.gd")
const MappingLoader := preload("res://scripts/presentation/humanoid_rig_mapping_loader.gd")
const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const MAPPING_ID_BY_BODY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA256_BY_BODY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const REST_SIGNATURE_BY_BODY_PRESET := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}
const RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}

func resolve(body_preset_id: StringName, _loader: MappingLoader = null) -> MappingResolution:
	if body_preset_id not in BODY_PRESETS:
		var unknown_categories: Array[StringName] = [&"unknown_body_preset"]
		return MappingResolution.failed(body_preset_id, "", unknown_categories, PackedStringArray(["humanoid rig mapping catalog body preset %s is unknown" % body_preset_id]))
	var resource_path: String = RESOURCE_PATH_BY_BODY_PRESET[body_preset_id]
	var missing_categories: Array[StringName] = [&"missing_resource"]
	return MappingResolution.failed(body_preset_id, resource_path, missing_categories, PackedStringArray(["humanoid rig mapping catalog body preset %s resource %s does not exist" % [body_preset_id, resource_path]]))
```

Do not commit the shell. Confirm it has no instance `var`, constructor, active state, fallback, or loader invocation.

- [ ] **Step 4: Run the A2 behavior RED once**

Run the focused catalog command with `PF_RIG_FACTORY_CONTRACT_PROBE` absent. A trustworthy behavior RED requires native nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL (8 failures)`, and exactly these labels in matrix order:

```text
missing resource outcome is exact
failed load outcome is exact
wrong resource type outcome is exact
identity mismatch categories and messages are ordered
masculine exact path resolution succeeds
feminine exact path resolution succeeds
cross-body mapping fails without fallback
later catalog failure does not mutate prior success
```

The unknown-preset, default-production-loader missing-resource, no-shared-path, stateless-property, and path-table assertions must pass. Require zero parser, loader, import, script, engine-crash, segmentation, object-leak, or RID-leak diagnostics. Preserve this RED before replacing the shell.

- [ ] **Step 5: Replace the catalog shell with the approved implementation**

Remove `_mapping_by_body_preset`, its constructor injection, the mapping-or-null return, and discarded private errors. Implement:

```gdscript
class_name HumanoidRigMappingCatalog
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const MappingResolution := preload("res://scripts/presentation/humanoid_rig_mapping_resolution.gd")
const MappingLoader := preload("res://scripts/presentation/humanoid_rig_mapping_loader.gd")
const RigContract := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const MAPPING_ID_BY_BODY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA256_BY_BODY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const REST_SIGNATURE_BY_BODY_PRESET := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}
const RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}

func resolve(body_preset_id: StringName, loader: MappingLoader = null) -> MappingResolution:
	if body_preset_id not in BODY_PRESETS:
		return _single_failure(body_preset_id, "", &"unknown_body_preset", "humanoid rig mapping catalog body preset %s is unknown" % body_preset_id)
	var resource_path: String = RESOURCE_PATH_BY_BODY_PRESET[body_preset_id]
	var effective_loader := loader if loader != null else MappingLoader.new()
	if not effective_loader.exists_exact(resource_path):
		return _single_failure(body_preset_id, resource_path, &"missing_resource", "humanoid rig mapping catalog body preset %s resource %s does not exist" % [body_preset_id, resource_path])
	var value: Variant = effective_loader.load_exact(resource_path)
	if value == null:
		return _single_failure(body_preset_id, resource_path, &"resource_load_failed", "humanoid rig mapping catalog body preset %s resource %s could not be loaded" % [body_preset_id, resource_path])
	if not value is RigMapping:
		return _single_failure(body_preset_id, resource_path, &"wrong_resource_type", "humanoid rig mapping catalog body preset %s resource %s must be HumanoidRigMapping, got %s" % [body_preset_id, resource_path, _variant_type_name(value)])
	var mapping := value as RigMapping
	var categories: Array[StringName] = []
	var messages := PackedStringArray()
	_append_identity_errors(body_preset_id, mapping, categories, messages)
	if not categories.is_empty():
		return MappingResolution.failed(body_preset_id, resource_path, categories, messages)
	return MappingResolution.succeeded(body_preset_id, resource_path, mapping)

static func _single_failure(body_preset_id: StringName, resource_path: String, category: StringName, message: String) -> MappingResolution:
	var categories: Array[StringName] = [category]
	return MappingResolution.failed(body_preset_id, resource_path, categories, PackedStringArray([message]))

static func _variant_type_name(value: Variant) -> String:
	return value.get_class() if value is Object else type_string(typeof(value))

static func _append_identity_errors(body_preset_id: StringName, mapping: RigMapping, categories: Array[StringName], messages: PackedStringArray) -> void:
	var expected_mapping_id: StringName = MAPPING_ID_BY_BODY_PRESET[body_preset_id]
	if mapping.mapping_id != expected_mapping_id:
		categories.append(&"wrong_mapping_id")
		messages.append("humanoid rig mapping catalog body preset %s mapping id must be %s, got %s" % [body_preset_id, expected_mapping_id, mapping.mapping_id])
	if mapping.canonical_rig_id != RigContract.CANONICAL_RIG_ID:
		categories.append(&"wrong_canonical_rig_id")
		messages.append("humanoid rig mapping catalog body preset %s canonical rig id must be %s, got %s" % [body_preset_id, RigContract.CANONICAL_RIG_ID, mapping.canonical_rig_id])
	var expected_source_hash: String = SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]
	if mapping.source_skeleton_sha256 != expected_source_hash:
		categories.append(&"wrong_source_hash")
		messages.append("humanoid rig mapping catalog body preset %s source skeleton hash must be %s, got %s" % [body_preset_id, expected_source_hash, mapping.source_skeleton_sha256])
	var expected_rest_signature: String = REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]
	if mapping.source_rest_signature != expected_rest_signature:
		categories.append(&"wrong_rest_signature")
		messages.append("humanoid rig mapping catalog body preset %s source rest signature must be %s, got %s" % [body_preset_id, expected_rest_signature, mapping.source_rest_signature])
```

- [ ] **Step 6: Run A2 GREEN and result/catalog regression**

Run the catalog suite, then:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Both commands require pristine GREEN. Confirm the production catalog declares no instance `var` and default resolution is not invoked while the forbidden `.tres` files are absent.

- [ ] **Step 7: Commit A2**

Require exact scope of the catalog and its one test, then commit:

```powershell
git -C $project add -- scripts/presentation/humanoid_rig_mapping_catalog.gd tests/unit/test_humanoid_rig_mapping_catalog.gd
git -C $project commit -m 'feat: resolve rig mappings by exact path'
```

---

### Task B: Add the Pure Bind-Identity Boundary and Public Validator Coverage

**Files:**
- Modify: `scripts/presentation/humanoid_rig_contract.gd`
- Modify: `tests/unit/test_production_humanoid_rig_mapping.gd`

**Interfaces:**
- Consumes: existing mapped bind coverage, transform validation, semantic role, rest-signature, and ancestry behavior.
- Produces: public pure `validate_mapped_bind_identity()` consumed by `_resolve_mapped_skin_binds()`.

- [ ] **Step 1: Add a guarded RED and exact public assertions**

At the beginning of the mapped-rig test after loading the contract, assert `has_method(&"validate_mapped_bind_identity")` with label `public mapped bind identity validator exists`; return before calls when absent. After the method exists, reuse `_method_argument_count()` and assert arity `4` with label `public mapped bind identity validator signature is exact`; return before calls when the arity differs. The missing-method RED must not mention or call the absent method.

After the guard, assert:

```gdscript
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root", &"Dup", &"Dup"] as Array[StringName], &"Dup", 1, 7),
	PackedStringArray(["mapped humanoid Skin bind 7 name Dup must resolve exactly once; found 2"]),
	"duplicate synthetic name array rejects deterministically",
	failures
)
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root"] as Array[StringName], &"", 0, 0),
	PackedStringArray(),
	"empty name accepts valid numeric identity",
	failures
)
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root"] as Array[StringName], &"Missing", 0, 0),
	PackedStringArray(["mapped humanoid Skin bind 0 name Missing must resolve exactly once; found 0"]),
	"zero name match rejects deterministically",
	failures
)
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root"] as Array[StringName], &"Root", -1, 3),
	PackedStringArray(["mapped humanoid Skin bind 3 bone index -1 is out of range"]),
	"pure mapped bind range rejects deterministically",
	failures
)
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root", &"Child"] as Array[StringName], &"Child", 1, 4),
	PackedStringArray(),
	"exact name and numeric identity agree",
	failures
)
TestAssertions.equal(
	_contract.call(&"validate_mapped_bind_identity", [&"Root", &"Child"] as Array[StringName], &"Child", 0, 5),
	PackedStringArray(["mapped humanoid Skin bind 5 name Child resolves to bone 1 but numeric index is 0"]),
	"pure mapped bind name index conflict rejects deterministically",
	failures
)
```

Add these public `validate_mapped_rig()` assertions. `_mapping()` and `_superset_skeleton()` are the existing real fixtures; no duplicate-name skeleton is constructed:

```gdscript
TestAssertions.equal(
	_contract.call(&"validate_mapped_rig", _definition, null, null, null),
	PackedStringArray(["humanoid rig mapping is missing"]),
	"null mapping rejects at public boundary",
	failures
)
var valid_mapping := _mapping()
TestAssertions.equal(
	_contract.call(&"validate_mapped_rig", _definition, valid_mapping, null, null),
	PackedStringArray(["mapped humanoid Skeleton3D is missing"]),
	"null skeleton rejects after valid mapping",
	failures
)
var valid_skeleton := _superset_skeleton(valid_mapping)
_bind_mapping_to_skeleton(valid_mapping, valid_skeleton)
TestAssertions.equal(
	_contract.call(&"validate_mapped_rig", _definition, valid_mapping, valid_skeleton, null),
	PackedStringArray(["mapped humanoid Skin is missing"]),
	"null skin rejects after valid mapping and skeleton",
	failures
)
var empty_target_mapping := _mapping()
var empty_target_roles: Dictionary = empty_target_mapping.get(&"role_to_bone").duplicate(true)
empty_target_roles[&"head"] = &""
empty_target_mapping.set(&"role_to_bone", empty_target_roles)
TestAssertions.truthy(
	_contains(_contract.call(&"validate_mapped_rig", _definition, empty_target_mapping, valid_skeleton, _skin_for(valid_skeleton)), "humanoid rig mapping role head has empty or duplicate bone"),
	"empty mapped target rejects through public validator",
	failures
)
valid_skeleton.free()
```

Retain every existing numeric range, coverage, transform, rest, identity, semantic, and ancestry assertion.

Do not create or mutate a duplicate-name `Skeleton3D`.

- [ ] **Step 2: Run Task B RED once**

Run the mapped-rig suite. Trustworthy RED requires one failure named `public mapped bind identity validator exists`, no call of the missing method, and zero infrastructure diagnostics.

- [ ] **Step 3: Add the minimal pure bind-identity shell**

Add exactly this cold-safe, side-effect-free shell before `_resolve_mapped_skin_binds()`. It has the final public signature, returns a neutral empty error array for every input, and is not yet called by production resolution:

```gdscript
static func validate_mapped_bind_identity(
		_bone_names: Array[StringName],
		_bind_name: StringName,
		_numeric_bone_index: int,
		_bind_slot: int
	) -> PackedStringArray:
	return PackedStringArray()
```

Do not alter `_resolve_mapped_skin_binds()` or remove `_matching_name_indices()` in this scaffold step.

- [ ] **Step 4: Run the Task B behavior RED once**

Run the mapped-rig suite with `PF_RIG_FACTORY_CONTRACT_PROBE` absent. A trustworthy behavior RED requires native nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL (4 failures)`, and exactly these labels in order:

```text
duplicate synthetic name array rejects deterministically
zero name match rejects deterministically
pure mapped bind range rejects deterministically
pure mapped bind name index conflict rejects deterministically
```

The method-signature guard, empty-name authority, exact-one agreement, public null mapping/skeleton/skin, empty target, and every pre-existing mapped-validator assertion must pass. Require zero parser, loader, import, script, engine-crash, segmentation, object-leak, or RID-leak diagnostics. Preserve the RED before changing the shell or bind resolver.

- [ ] **Step 5: Replace the shell and integrate the pure validator**

Add this method before `_resolve_mapped_skin_binds()`:

```gdscript
static func validate_mapped_bind_identity(bone_names: Array[StringName], bind_name: StringName, numeric_bone_index: int, bind_slot: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if numeric_bone_index < 0 or numeric_bone_index >= bone_names.size():
		errors.append("mapped humanoid Skin bind %d bone index %d is out of range" % [bind_slot, numeric_bone_index])
		return errors
	if bind_name.is_empty():
		return errors
	var matching_indices := PackedInt32Array()
	for bone_index: int in bone_names.size():
		if bone_names[bone_index] == bind_name:
			matching_indices.append(bone_index)
	if matching_indices.size() != 1:
		errors.append("mapped humanoid Skin bind %d name %s must resolve exactly once; found %d" % [bind_slot, bind_name, matching_indices.size()])
	elif matching_indices[0] != numeric_bone_index:
		errors.append("mapped humanoid Skin bind %d name %s resolves to bone %d but numeric index is %d" % [bind_slot, bind_name, matching_indices[0], numeric_bone_index])
	return errors
```

Replace `_resolve_mapped_skin_binds()` with this exact integration. It preserves pose validation first, identity/range before duplicate coverage, and final missing-bone order:

```gdscript
static func _resolve_mapped_skin_binds(skeleton: Skeleton3D, skin: Skin, errors: PackedStringArray) -> Dictionary:
	var bind_index_by_bone_index: Dictionary = {}
	var bone_names: Array[StringName] = []
	for bone_index: int in skeleton.get_bone_count():
		bone_names.append(skeleton.get_bone_name(bone_index))
	for bind_index: int in skin.get_bind_count():
		_validate_transform(skin.get_bind_pose(bind_index), "mapped humanoid Skin bind %d pose" % bind_index, errors)
		var bone_index := skin.get_bind_bone(bind_index)
		var identity_errors := validate_mapped_bind_identity(bone_names, skin.get_bind_name(bind_index), bone_index, bind_index)
		errors.append_array(identity_errors)
		if bone_index < 0 or bone_index >= bone_names.size():
			continue
		if bind_index_by_bone_index.has(bone_index):
			errors.append("mapped humanoid Skin bind %d duplicates skeleton bone %d" % [bind_index, bone_index])
		else:
			bind_index_by_bone_index[bone_index] = bind_index
	for bone_index: int in skeleton.get_bone_count():
		if not bind_index_by_bone_index.has(bone_index):
			errors.append("mapped humanoid Skin is missing skeleton bone %s at index %d" % [skeleton.get_bone_name(bone_index), bone_index])
	return bind_index_by_bone_index
```

Remove `_matching_name_indices()` after no production caller remains. Its exact behavior is subsumed by the public pure boundary; the legacy `_bone_indices_named()` helper remains untouched.

Do not alter `validate_rig()`, `validate_skin()`, `_bone_indices_named()`, `_serialize_transform()`, or `_quantized()`.

- [ ] **Step 6: Run Task B GREEN and legacy regression**

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Require pristine GREEN. Compare legacy validator function blobs against `correctionImplementationBase`; they must be byte-identical.

- [ ] **Step 7: Commit Task B**

Commit only the contract and mapped-rig test:

```powershell
git -C $project add -- scripts/presentation/humanoid_rig_contract.gd tests/unit/test_production_humanoid_rig_mapping.gd
git -C $project commit -m 'feat: validate mapped bind identities'
```

---

### Task C: Qualify Both Inspected 52-Bone Candidates End to End

**Files:**
- Modify: `tests/unit/test_production_humanoid_rest_signature.gd`
- Read only: `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json`

**Interfaces:**
- Consumes: the fixture's exact bone index/name/parent/rest records, approved mapping identities, public mapped validator, and unchanged strict legacy validators.
- Produces: deterministic qualification proof only; no production method changes.

- [ ] **Step 1: Rehash and parse the fixture before editing the test**

Require fixture SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`, schema version `1`, exactly two candidates, exact preset IDs, exactly 52 bones each, finite/invertible rests, and approved signatures. Stop if any condition differs.

- [ ] **Step 2: Add exact mapping and source constants**

Add these constants and state to `test_production_humanoid_rest_signature.gd`:

```gdscript
const DEFINITION_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const MAPPING_ID_BY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA_BY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const ROLE_TO_BONE := {
	&"hips": &"mixamorig_Hips",
	&"spine": &"mixamorig_Spine",
	&"chest": &"mixamorig_Spine2",
	&"neck": &"mixamorig_Neck",
	&"head": &"mixamorig_Head",
	&"upper_arm_left": &"mixamorig_LeftArm",
	&"lower_arm_left": &"mixamorig_LeftForeArm",
	&"hand_left": &"mixamorig_LeftHand",
	&"upper_arm_right": &"mixamorig_RightArm",
	&"lower_arm_right": &"mixamorig_RightForeArm",
	&"hand_right": &"mixamorig_RightHand",
	&"upper_leg_left": &"mixamorig_LeftUpLeg",
	&"lower_leg_left": &"mixamorig_LeftLeg",
	&"foot_left": &"mixamorig_LeftFoot",
	&"toe_left": &"mixamorig_LeftToeBase",
	&"upper_leg_right": &"mixamorig_RightUpLeg",
	&"lower_leg_right": &"mixamorig_RightLeg",
	&"foot_right": &"mixamorig_RightFoot",
	&"toe_right": &"mixamorig_RightToeBase",
}

var _mapping_script: Script
var _definition: Resource
```

In `run()`, assert `FileAccess.file_exists(MAPPING_PATH)` and `ResourceLoader.exists(DEFINITION_PATH)` before loading either prospective dependency. Return with the exact labels `production mapping script exists for public qualification` and `canonical definition exists for public qualification` if either guard fails. Then load both, assert non-null, assign `_mapping_script` and `_definition`, and return before qualification calls if either load fails. The existing contract path remains separately loaded and guarded.

- [ ] **Step 3: Add the two-body public qualification helper**

For every candidate, call:

```gdscript
func _assert_public_candidate_validation(candidate: Dictionary, failures: Array[String]) -> void:
	var preset := StringName(candidate.get("body_preset_id", ""))
	var skeleton := _skeleton_for(candidate)
	var skin := Skin.new()
	for bone_index: int in skeleton.get_bone_count():
		skin.add_bind(bone_index, skeleton.get_bone_global_rest(bone_index).affine_inverse())
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", MAPPING_ID_BY_PRESET[preset])
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"role_to_bone", ROLE_TO_BONE.duplicate(true))
	mapping.set(&"source_skeleton_sha256", SOURCE_SHA_BY_PRESET[preset])
	mapping.set(&"source_rest_signature", EXPECTED[preset])
	TestAssertions.equal(skeleton.get_bone_count(), 52, "%s public fixture retains 52 bones" % preset, failures)
	TestAssertions.equal(skin.get_bind_count(), 52, "%s public fixture creates 52 binds" % preset, failures)
	for bind_index: int in skin.get_bind_count():
		TestAssertions.equal(skin.get_bind_bone(bind_index), bind_index, "%s bind %d keeps exact numeric index" % [preset, bind_index], failures)
		TestAssertions.equal(skin.get_bind_name(bind_index), &"", "%s bind %d remains unnamed" % [preset, bind_index], failures)
	TestAssertions.equal(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), PackedStringArray(), "%s inspected candidate passes mapped validation" % preset, failures)
	var pivots := Node3D.new()
	TestAssertions.truthy(_contains(_contract.call(&"validate_rig", _definition, skeleton, pivots), "bone count must be 19, got 52"), "%s strict legacy rig validator still rejects superset" % preset, failures)
	TestAssertions.truthy(_contains(_contract.call(&"validate_skin", _definition, skin), "must be named; numeric-only and unnamed binds are invalid"), "%s strict legacy skin validator still rejects unnamed binds" % preset, failures)
	var incomplete_skin := Skin.new()
	for bone_index: int in 51:
		incomplete_skin.add_bind(bone_index, skeleton.get_bone_global_rest(bone_index).affine_inverse())
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, incomplete_skin), "mapped humanoid Skin is missing skeleton bone mixamorig_RightHandThumb3 at index 51"),
		"%s incomplete 51-bind fixture rejects the exact final bone" % preset,
		failures
	)
	pivots.free()
	skeleton.free()
```

Add this exact helper if the file does not already have it:

```gdscript
func _contains(errors: Variant, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
```

- [ ] **Step 4: Run the fixture qualification**

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd
```

This is a characterization/qualification task: current mapped behavior may pass immediately, so do not manufacture a false RED. Trustworthiness comes from two exact positive mapped assertions, two strict legacy rejection assertions, two incomplete-coverage negative controls, exact fixture bytes, and zero diagnostics. Require pristine GREEN.

- [ ] **Step 5: Rehash fixture and commit Task C**

Require the fixture hash unchanged and commit only the test:

```powershell
git -C $project add -- tests/unit/test_production_humanoid_rest_signature.gd
git -C $project commit -m 'test: qualify inspected production rig candidates'
```

---

### Task D: Verify the Complete Corrective Checkpoint

**Files:**
- No tracked file changes.
- Read-only product scope: the exact seven paths.
- Evidence: new task-owned directories under `C:\Users\Jacob\AppData\Local\Temp` only.

**Interfaces:**
- Consumes: four implementation commits after `correctionImplementationBase`.
- Produces: focused evidence, fresh-from-new-tracked-archive cold-import/full-suite evidence, two independent review verdicts, and exact containment audit.

- [ ] **Step 1: Run the complete focused correction gate**

Before launching Godot, require `Test-Path Env:PF_RIG_FACTORY_CONTRACT_PROBE` to be false and record that absence in the focused-gate evidence. If the variable exists, stop before launch rather than clearing it implicitly.

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
```

Require exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero fail markers, and zero prohibited diagnostics.

- [ ] **Step 2: Audit commit and seven-path scope before archive creation**

Require exactly four first-parent commits after `correctionImplementationBase`, in order:

```text
feat: add read-only rig mapping results
feat: resolve rig mappings by exact path
feat: validate mapped bind identities
test: qualify inspected production rig candidates
```

Require their union to equal the seven File Responsibility Map paths, no merge commits, `git diff correctionImplementationBase..HEAD --check` exit `0`, clean tracked/index state, fixture byte identity, and absent sentinels.

- [ ] **Step 3: Create a new immutable tracked archive after implementation**

Create the evidence paths without reusing an earlier directory:

```powershell
$evidenceRoot = Join-Path $env:TEMP ("pf-rig-review-corrections-" + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$trackedArchive = Join-Path $evidenceRoot 'tracked.zip'
$disposableProject = Join-Path $evidenceRoot 'tracked-project'
$controller = Join-Path $evidenceRoot 'process-controller.ps1'
New-Item -ItemType Directory -LiteralPath $evidenceRoot | Out-Null
git -C $project archive --format=zip --output=$trackedArchive HEAD
```

Hash `tracked.zip`, validate every ZIP entry against traversal, absolute, device, alternate-stream, and duplicate-path hazards, and record a complete archive manifest. This new archive and hash are the only source of truth for future-change full-suite qualification. Earlier Step 4B evidence remains historical controller/process evidence and is not proof of these changes.

- [ ] **Step 4: Expand into a new disposable project and inventory before import**

Expand the validated archive into a brand-new task-owned directory. Record every pre-import file and directory with normalized relative path, SHA-256, byte count, and type. Require no inherited `.godot`, no source-adjacent generated sidecars absent from the tracked archive, zero blank paths, and zero duplicates.

- [ ] **Step 5: Reuse the qualified asynchronous controller exactly**

Source controller:

`C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-controller-qualification-20260901T070102Z-a5e18980\synthetic\process-controller.ps1`

Require source SHA-256 `46b171f14c852bdb05984bf289e19d1ea9091d7ae2892561b22963b5f20ae1aa`. Copy it byte-for-byte into the new evidence root, rehash, syntax-parse, and AST-scan for zero call operators, `Start-Process`, `Stop-Process`, shell redirections, `.Arguments` string use, and case-insensitive variables named `pid`. Require separate `ArgumentList` values, concurrent `ReadToEndAsync`, `WaitForExitAsync`, native exit capture, and exact-process-tree timeout containment.

- [ ] **Step 6: Run one fresh cold registration/import**

Create unused empty import `APPDATA` and `LOCALAPPDATA` roots. Invoke the controller with exact argument vector:

```powershell
$importAppData = Join-Path $evidenceRoot 'import-appdata'
$importLocalAppData = Join-Path $evidenceRoot 'import-localappdata'
New-Item -ItemType Directory -LiteralPath $importAppData | Out-Null
New-Item -ItemType Directory -LiteralPath $importLocalAppData | Out-Null
$importArguments = [string[]]@('--headless', '--editor', '--import', '--quit', '--path', $disposableProject)
& $controller -ExecutablePath $godot -ArgumentVector $importArguments -AppDataPath $importAppData -LocalAppDataPath $importLocalAppData -TimeoutMilliseconds 720000 -StdoutPath (Join-Path $evidenceRoot 'import.stdout.txt') -StderrPath (Join-Path $evidenceRoot 'import.stderr.txt') -ResultPath (Join-Path $evidenceRoot 'import.controller-result.json')
```

Before invoking the controller, require `PF_RIG_FACTORY_CONTRACT_PROBE` to be absent from the parent environment and therefore absent from the controller's inherited environment; record the absence in command metadata. Do not add that variable to `ProcessStartInfo.Environment`. Use `TimeoutMilliseconds=720000`. Require native exit `0`, no timeout/controller failure, and zero prohibited diagnostics. Inventory the project afterward. Permit only:

- `.godot/**` generated products;
- source-adjacent `*.gd.uid` additions when the exact `.gd` sibling existed pre-import;
- source-adjacent `*.png.import` additions when the exact PNG sibling existed pre-import and every declared target is normalized under `res://.godot/imported/` and exists.

Reject every existing source-byte change, deletion, unexplained addition, traversal/external reference, or authoritative-worktree write. Record deterministic manifests and hashes for each generated class.

- [ ] **Step 7: Run one fresh complete suite from the imported copy**

Create a different unused empty suite `APPDATA`/`LOCALAPPDATA` pair. Invoke the same byte-identical controller with:

```powershell
$suiteAppData = Join-Path $evidenceRoot 'suite-appdata'
$suiteLocalAppData = Join-Path $evidenceRoot 'suite-localappdata'
New-Item -ItemType Directory -LiteralPath $suiteAppData | Out-Null
New-Item -ItemType Directory -LiteralPath $suiteLocalAppData | Out-Null
$suiteArguments = [string[]]@('--headless', '--path', $disposableProject, '--script', 'res://tests/test_runner.gd')
& $controller -ExecutablePath $godot -ArgumentVector $suiteArguments -AppDataPath $suiteAppData -LocalAppDataPath $suiteLocalAppData -TimeoutMilliseconds 720000 -StdoutPath (Join-Path $evidenceRoot 'suite.stdout.txt') -StderrPath (Join-Path $evidenceRoot 'suite.stderr.txt') -ResultPath (Join-Path $evidenceRoot 'suite.controller-result.json')
```

Before invoking the controller, require `PF_RIG_FACTORY_CONTRACT_PROBE` to be absent from the parent environment and therefore absent from the controller's inherited environment; record the absence in command metadata and do not add it to `ProcessStartInfo.Environment`. Use `TimeoutMilliseconds=720000`. Require native exit `0`, exactly one terminal `TEST_SUMMARY: PASS` with one positive suite count, zero fail markers, zero `TEST_FAILURE` lines, and zero prohibited diagnostic families.

Use the accepted Step 4B PASS stderr as the normalized known-pass reference:

```text
C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-step4b-20260901T073118Z-5f5655f4\evidence\full-suite.stderr.txt
SHA-256 201609952ff70f2b6e9cd5b249f895e52e1da01ff1af4d414a933ad2b312b7a9
```

Before comparison, also require the accepted reference summary SHA-256 `3a42c8e14669722561202c3b8211a65542d746520cf47ca64ac99bb43a06f382`, analysis SHA-256 `9dd2516d2e086422aad27771a7161bafcfa4a3ff52ab21d80c97a8e525eca2bb`, and marker/diagnostic analysis SHA-256 `ff7507e3249f587340b87be00fd5b5d54e056238a95673111aaabbe7d51520ba`. Reject reference drift. The accepted reference contains 112 `ERROR:` headers, 18 `WARNING:` headers, and 130 `GDScript backtrace` headers; those totals are observations, not a count-only waiver.

Normalize the reference and current suite stderr with the same deterministic algorithm:

1. A diagnostic block begins on a line whose trimmed text starts exactly `ERROR:` or `WARNING:` and continues until the next such header or end of stream.
2. For each block, create one family key in the form `severity|header|backtrace|first_frame`. Preserve the severity and symbolic reason text. Normalize volatile data in the header by replacing `user://` dynamic suffixes with `user://[dynamic]`, absolute Windows paths with `[absolute-path]`, lowercase 64-character hashes with `[sha256]`, GUIDs with `[guid]`, `res://` line suffixes with `:[line]`, and standalone dynamic numeric values with `[number]`.
3. Set `backtrace` to `true` only when the block contains `GDScript backtrace`; otherwise set it to `false`. Set `first_frame` to the normalized first `[0]` frame's function and `res://` path with its line removed, or `none` when absent.
4. Reject every `GDScript backtrace` header that is not consumed by exactly one diagnostic block. Sort family keys ordinally and serialize compact records `{"family":string,"count":integer}` with no BOM and no trailing newline.
5. Require the current and accepted family multisets to be byte-identical after normalization, including multiplicity. This also requires the observed aggregate counts and backtrace cardinality to remain unchanged.

`INTENTIONAL_NEW_FAMILY_BY_LABEL` is an empty map for this correction checkpoint. Any current family absent from the accepted multiset, any missing accepted family, or any count difference is an unexplained diagnostic and fails closed. A future exact intentional negative-control label may be allowed only by a separately approved plan amendment that supplies its expected normalized family and evidence; no runtime absorption or count-based waiver is permitted. Explicit parser, loader, import, script-compile, engine-crash, fatal, segmentation, object-leak, and RID-leak patterns fail regardless of whether any reference family resembles them.

Preserve the reference/current normalized manifests, hashes, family diff, raw aggregate counts, and exact unmatched records. Reinventory the disposable project and reprove authoritative non-mutation.

- [ ] **Step 8: Obtain a fresh read-only requirements review**

After recording the four commit hashes into `$a1Hash`, `$a2Hash`, `$bHash`, and `$cHash`, construct the exact brief through PowerShell interpolation and dispatch it to a fresh read-only reviewer:

```powershell
$requirementsBrief = @"
Review Party Forge production-rig review corrections for requirements compliance only. Do not edit any file. Baseline is correctionImplementationBase=$correctionImplementationBase. Review exactly these four implementation commits in order: $a1Hash, $a2Hash, $bHash, $cHash. Approved design is docs/superpowers/specs/2026-09-01-production-rig-review-correction-design.md at approved SHA-256 4dbd4c70a7732707adfc34d8722518066c9681566b28e0a3b29afa8efff56906. Execution plan is docs/superpowers/plans/2026-09-01-production-rig-review-corrections.md. Evidence root is $evidenceRoot. Product scope is exactly the seven paths listed by the plan. Inspect the base-to-tip diff and evidence. Return PASS or FAIL, mapping every requirement to exact file:line evidence: read-only result invariants and no setters; defensive collection copies; invalid factory null/no-result contract; mapping Resource mutability caveat; exact path-table equality and exact existence/load calls; stable category/message ordering and cardinality; stateless per-call catalog with no active/error history or fallback; pure duplicate-name bind boundary without invalid Skeleton3D construction; public null mapping/skeleton/skin and empty target coverage; both 52-bone fixture candidates with 52 unnamed numeric binds passing validate_mapped_rig; the same candidates failing strict legacy validate_rig and validate_skin; fixture bytes preserved; forbidden resources/sentinels absent; and presentation transaction/rollback still deferred. Report any missing or contradictory evidence as FAIL. Do not review art direction, do not propose implementation, and do not modify the worktree.
"@
```

Stop on FAIL or inadequate evidence; do not dispatch the next reviewer.

- [ ] **Step 9: Obtain a distinct fresh read-only code-quality review**

Dispatch a different fresh read-only reviewer with this exact interpolated brief:

```powershell
$qualityBrief = @"
Review Party Forge production-rig review corrections for code quality only. Do not edit any file and do not repeat the requirements checklist review. Baseline is correctionImplementationBase=$correctionImplementationBase. Review exactly these four implementation commits in order: $a1Hash, $a2Hash, $bHash, $cHash. Ignore the thirteen pre-implementation documentation/history commits except as provenance. Execution plan is docs/superpowers/plans/2026-09-01-production-rig-review-corrections.md and evidence root is $evidenceRoot. Inspect only the exact seven-path product diff plus test and verification evidence. Return PASS or FAIL with exact file:line evidence for: cold-load-safe GDScript typing through explicit preloads; underscore-private state and absence of writable public result state; defensive-copy correctness; factory validation ordering and no partially observable invalid result; exact-path callable loader seam without catalog-held state; existence/load call counts; deterministic category and validator error ordering; loaded Resource reference semantics; Skin and Skeleton3D API correctness; pure duplicate-name handling; byte-identical legacy validate_rig and validate_skin behavior; test isolation without mock-behavior assertions or test-only production APIs; fixture immutability; and commit-based rollback risk. Treat any parser dependence, mutable last-error channel, silent fallback, diagnostic suppression, incomplete negative control, or broader path scope as FAIL. Do not propose edits and do not modify the worktree.
"@
```

Stop on FAIL or inadequate evidence; do not fix without a new gate.

- [ ] **Step 10: Revalidate containment after both PASS verdicts**

Rehash all 77 protected records, both GLBs, fixture JSON, approved specs/plans, and new evidence. Recheck Dawn Bulwark exact three modifications, report read-only Combat HUD drift, verify all five sentinels absent, require clean tracked/index state and exact seven-path union, and preserve every evidence root.

---

### Task E: Stop at the Corrected Pre-Resource Contract Checkpoint

**Files:**
- No changes.

**Interfaces:**
- Consumes: both independent PASS reviews and complete containment evidence.
- Produces: a Studio Lead checkpoint report and no repository mutation.

- [ ] **Step 1: Report the verified checkpoint**

Report:

- branch, worktree, `correctionImplementationBase`, four implementation hashes/parents/subjects, and exact seven-path union;
- all thirteen pre-implementation historical commits after the original base without rewriting them;
- A1/A2/B RED and GREEN markers, intentional factory-contract probe, Task C characterization evidence, focused gate, archive hash, import classification, full-suite exit/marker, and two reviewer verdicts;
- fixture, protected, GLB, spec/plan, Dawn Bulwark, Combat HUD, and sentinel containment;
- rollback boundaries and remaining risks.

- [ ] **Step 2: Mandatory stop**

Do not create masculine, feminine, or shared mapping `.tres` files. Do not begin body qualification, presentation transaction/rollback, active visual integration, heads, armor, Dawn Bulwark production, equipment, Blender, merge, rebase, push, cleanup, or publication. The next action requires a new Studio Lead gate under Jacob's delegation.

## Approved-Requirement Traceability

| Approved correction requirement | Plan task and terminal evidence |
|---|---|
| Read-only atomic result, defensive copies, no setters, exact factories, no observable invalid allocation | Task A1 normal GREEN plus the two isolated factory-contract probes. |
| Mapping getter returns the same mutable Resource reference without freezing it | Task A1 mutation assertion and Task D requirements review. |
| Stateless catalog and exact-path production loader with zero fallback | Task A1 loader-seam tests, Task A2 guarded RED/GREEN, exact call records, and catalog property inspection. |
| Public structured categories/messages in deterministic order | Task A1 result assertions, Task A2 exact failure matrix, and Task D requirements review. |
| Reviewer findings 2 and 3 boundary contradiction | Task A2 replaces preset-keyed injection with exact-path loader injection while explicitly deferring active-presentation transaction/rollback. |
| Public pure duplicate-name/name-index boundary without an invalid Skeleton3D | Task B synthetic duplicate array, real Skeleton3D integration regression, and zero engine diagnostics. |
| Null mapping, null skeleton, null skin, and empty target coverage | Task B exact public assertions and early-return cardinality checks. |
| Both inspected 52-bone/52-unnamed-bind bodies pass mapped validation | Task C fixture-backed masculine and feminine positive assertions. |
| The same two bodies remain outside strict legacy acceptance | Task C exact `validate_rig()` and `validate_skin()` rejection assertions plus legacy function-blob audit. |
| Fixture, immutable sources, protected worktrees, sentinels, and seven-path containment | Task 0 baseline, every commit gate, and Task D final audit. |
| Future changes receive fresh full-suite evidence | Task D new tracked archive, fresh cold import, one imported-copy full suite, and two independent read-only reviews. |
| Mapping resources and real active-visual preservation remain deferred | Task E mandatory stop; no `.tres`, presentation integration, body qualification, or art work occurs. |

## Rollback

- Revert `test: qualify inspected production rig candidates` to remove only the new qualification assertions.
- Revert `feat: validate mapped bind identities` to restore the prior mapped-name helper while preserving result/catalog work and both legacy validators.
- Revert `feat: resolve rig mappings by exact path` to restore the previous preset-keyed injected catalog while preserving the new unused result/loader files.
- Revert `feat: add read-only rig mapping results` to remove the result/loader and their first test slice.
- Reverts occur only under a separate approval. Never amend, rebase, squash, delete evidence, or mutate immutable sources.

## Final Plan Self-Review Checklist

- Every approved design requirement maps to Task A1, A2, B, C, D, or E.
- Every checkbox is one bounded patch, test invocation, audit, evidence capture, reviewer dispatch, or stop/report action; no checkbox hides a second production behavior change.
- The product union is exactly seven paths; the fixture remains read-only.
- Every new type, method, parameter, return type, category, message order, resource URI, and commit subject is defined before use.
- Every production behavior change has a guarded trustworthy RED before implementation; Task C is explicitly a characterization proof and does not manufacture a false RED.
- Invalid factory behavior uses isolated intentional-error probes; `PF_RIG_FACTORY_CONTRACT_PROBE` is absent from every normal focused, cold-import, and full-suite process.
- No catalog active state, mutable last-error state, shared fallback, presentation transaction, or mapping resource is introduced.
- Legacy `validate_rig()` and `validate_skin()` remain byte-identical.
- Fresh full-suite evidence is generated from a new post-implementation tracked archive and cold import; earlier Step 4B is used only as the immutable normalized known-pass diagnostic-family reference, never as proof that future code passes.
- History accounting preserves the original eleven commits, treats the initial corrective plan as commit twelve, and treats this behavior-RED correction as commit thirteen before the dynamic correction baseline.
- No placeholder terms, vague cross-task references, undefined helper, mismatched type, or unbalanced code fence remains.
