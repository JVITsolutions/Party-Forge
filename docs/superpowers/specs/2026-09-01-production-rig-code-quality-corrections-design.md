# Production Rig Code-Quality Corrections Design

**Status:** Corrective design only. No implementation, test, plan, resource, import, or asset change is authorized by this document.

**Authoritative worktree:** `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement`

**Branch and design baseline:** `feat/class-preview-character-model-replacement` at `ba218c216330ec077446c02c620bd2499e8d1f67`

## Purpose

This design closes the two code-quality findings accepted after the production-rig contract checkpoint reviews:

1. `HumanoidRigMappingResolution._init()` currently relies on a debug-only assertion before unconditionally storing caller-supplied state. Release builds can therefore bypass the intended factory-only boundary.
2. `HumanoidRigContract._matching_name_indices()` has no production caller. Its only remaining caller is a unit-test assertion that duplicates the public `validate_mapped_bind_identity()` contract.

The correction preserves the approved cold-load-safe `RefCounted` result API, exact factory allocation path, deterministic structured results, public bind-identity validator, legacy rig validators, immutable fixture and source assets, and all deferred presentation/resource work.

## Verified Checkpoint and Review Evidence

The design starts from this verified local checkpoint:

- branch `feat/class-preview-character-model-replacement` at `ba218c216330ec077446c02c620bd2499e8d1f67`;
- tracked worktree and index clean;
- exactly 77 protected untracked records, all matching manifest SHA-256 `9f7d8b800e27f94d2bc1f7798a88c9bda73c65d0429c3c072bbe00daeafbe2bd`;
- production rig fixture SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`;
- immutable masculine GLB SHA-256 `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4`;
- immutable feminine GLB SHA-256 `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`;
- all five mapping/body-qualification sentinels absent;
- Dawn Bulwark worktree at `8617495a2ea7ce9f0d1af86e4fa35766df86d735` with exactly its three preserved modifications;
- Combat HUD read-only concurrent snapshot at `83cbf79ffd52abf69c6dbfe2fd89237980aa5b30` with 68 status entries. Its concurrent non-overlapping drift is not owned by this correction.

Accepted review evidence is under:

`C:\Users\Jacob\AppData\Local\Temp\pf-rig-step7b-verifier-qualifier-v2-20260901T135139Z-d4b3c3b2`

Exact evidence identities:

- corrected independent verifier result: `step7b-independent-verifier-result-v2.json`, SHA-256 `0e275eeb2bf1e270850f10e01f5965f875202f3bf14b370b2a51afbe527c51d2`;
- requirements review result: `requirements-review-result.md`, SHA-256 `c7179da6fd84f6cdacffad13db637394fddf426a140e40d03934bb22ad838b2a`, verdict `PASS`;
- code-quality review result: `code-quality-review-result.md`, SHA-256 `c8b679ce663905936600c94e6431eedf9e87d39e287873b535c846b343f2578b`, verdict `FAIL` with the two accepted findings above.

All prior Task D, Step 7A, Step 7B, verifier, qualifier, and reviewer evidence roots remain immutable provenance. This design does not replace or reinterpret their results.

Current prospective file hashes are:

| Path | SHA-256 |
|---|---|
| `scripts/presentation/humanoid_rig_mapping_resolution.gd` | `1a4a45dd64b13d20d7219e1c5e33715e9418f99b88e7064aa0178d3ca55b579d` |
| `scripts/presentation/humanoid_rig_contract.gd` | `ed7c6e814ed50f8497f65501a290015ead4bb47fcd82d9ae3a61e6c66ce8ecc3` |
| `tests/unit/test_humanoid_rig_mapping_catalog.gd` | `00ce474a30fbd2aa58c35986f94e4ba860689c933fad19c2eccc3a0a0d0dc1b1` |
| `tests/unit/test_production_humanoid_rig_mapping.gd` | `7fbf4c19deb349c4010ae54245073929671f08ca4bc4a9233f616a773c308747` |

## Review-Finding Disposition

### Finding 1: release-unsafe constructor boundary — accepted

The current assertion is not a release-safe authorization check. The correction replaces assertion-only enforcement with an ordinary `if`/`push_error`/`return` guard that executes in debug and release builds. No caller-supplied field is assigned before that guard passes.

GDScript allocates the `RefCounted` wrapper before `_init()` executes and `_init()` cannot return a replacement object. Invalid direct construction therefore cannot return `null`. The supported fail-closed boundary is explicit: it returns at most the already allocated inert wrapper, stores none of the caller's values, reports one deterministic programmer-contract error, and cannot satisfy either the success invariant or the valid-failure invariant.

### Finding 2: obsolete duplicate name helper — accepted

`validate_mapped_bind_identity()` already performs the exact name scan used by production. `_matching_name_indices()` has no production caller and is unnecessary. The correction deletes that helper and deletes only the unit-test block that calls it. The public duplicate-name, zero-match, numeric-range, exact-agreement, and name/index-conflict assertions remain the authoritative coverage.

## Considered Approaches

### A. Explicit runtime guard plus inert invalid wrapper — selected

This approach preserves the current result script, `RefCounted` API, factories, and runtime identity. A private construction-validity flag starts false. `_init()` rejects an invalid token before assigning any caller data, then sets the flag true only after every valid scalar assignment and defensive copy completes.

Advantages:

- build-independent behavior;
- no new script identity or class-cache dependency;
- no public mutable error state;
- no test-only production seam;
- minimal four-path prospective scope;
- exact rollback boundary.

The unavoidable trade-off is that invalid direct construction yields a non-null inert wrapper because allocation precedes `_init()`.

### B. Retain assertion enforcement and add a secondary guard — rejected

The ordinary guard would provide release safety, but retaining the assertion would introduce a different debug-only diagnostic and complicate exact probe behavior. The assertion supplies no additional authorization once the explicit guard exists. `_init()` must contain no assertion-based authorization path.

### C. Replace the result with a nested class, alternate wrapper, or injectable constructor — rejected

A nested result or alternate wrapper changes the accepted runtime script identity. A constructor-loader injection exists only to make tests easier and would be a test-only production seam. A global-class return/downcast restores the cold-load dependency already rejected. These approaches broaden the architecture without improving the runtime guarantee.

## Release-Safe Construction Architecture

### Private default state

`HumanoidRigMappingResolution` retains the same public accessors and factory signatures. Its backing fields receive explicit inert defaults and it adds one underscore-private validity bit:

```gdscript
var _requested_body_preset := StringName()
var _selected_resource_path := ""
var _mapping: RigMapping = null
var _failure_categories: Array[StringName] = []
var _error_messages := PackedStringArray()
var _construction_valid := false
```

`_construction_valid` is internal state, not a public setter, mutable error channel, result category, or new consumer API. No `is_construction_valid()` method is added.

### Exact constructor guard

The prospective `_init()` behavior is:

```gdscript
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

The guard dominates every assignment from a parameter. The validity bit changes last. The constructor contains no `assert()` authorization, source mutation, loader injection, nested class, alternate script, or global-class downcast.

If an assignment or defensive copy cannot complete, `_construction_valid` never becomes true. The implementation must not catch an assignment failure and expose a valid-looking partial object.

### Observable inert behavior

An invalid direct construction has these exact observable properties:

- the returned value is a non-null `RefCounted` whose script is the exact loaded `humanoid_rig_mapping_resolution.gd` script;
- exactly one error is emitted: `humanoid rig mapping resolution constructor contract failed: invalid factory token`;
- `is_success()` returns `false`;
- `get_requested_body_preset()` returns empty `StringName()`;
- `get_selected_resource_path()` returns `""`;
- `get_mapping()` returns `null`;
- `get_failure_categories()` returns an empty defensive array;
- `get_error_messages()` returns an empty defensive `PackedStringArray`;
- `rejected_by_mapped_rig()` returns the same inert wrapper and cannot populate it;
- mutating the caller's supplied mapping or collections cannot change any accessor result.

The wrapper is not a valid failure result because valid failures require non-empty, equally sized categories and messages. It is not a success because `_construction_valid` is false, mapping is null, and `is_success()` explicitly begins with `_construction_valid`.

Any consumer that receives a non-success result with empty categories or messages must treat it as a programmer-contract defect, not a catalog failure. Production catalog calls remain factory-only and therefore never return the inert direct-construction state.

### Factory behavior remains unchanged

`succeeded()` and `failed()` retain:

- their current `RefCounted` return annotations;
- pre-allocation validation and deterministic invalid-factory `null` behavior;
- exact `SCRIPT_PATH`;
- exactly one validated `result_script := load(SCRIPT_PATH) as Script` per factory call;
- the deterministic null branch when that script cannot load;
- allocation only through `result_script.new(_factory_token, ...)`;
- existing defensive copying and runtime script identity.

The only constructor-related change to valid factory outcomes is that `_construction_valid` becomes true after their copied state is complete. Existing success, failure, rejected-result, defensive-copy, and mutable-Resource-reference behavior remains unchanged.

## Obsolete Bind-Name Helper Removal

Delete only:

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

Delete only the helper-specific test block that:

- creates `duplicate_name_snapshot` inside `_assert_numeric_bind_resolution()`;
- checks `_contract.has_method(&"_matching_name_indices")`;
- directly calls `_matching_name_indices()` and compares `[1, 2]`.

Retain every assertion that calls public `validate_mapped_bind_identity()`, including:

- synthetic duplicate names reject deterministically;
- zero matches reject deterministically;
- empty bind name plus valid numeric index passes;
- out-of-range numeric index rejects;
- exact name/index agreement passes;
- name/index conflict rejects.

Retain `_resolve_mapped_skin_binds()` integration and every mapped-rig, rest, bind, ancestry, coverage, and legacy regression. No other helper or validator changes.

## TDD and Verification Expectations

### Release-safe constructor correction

A future implementation plan must add one isolated `invalid_direct_constructor` branch to the existing test-side `PF_RIG_FACTORY_CONTRACT_PROBE` mechanism. This is a test branch, not a production seam. It loads the real result script and directly invokes `Script.new()` with:

- a newly allocated invalid token;
- non-empty preset and path values;
- a non-null mapping Resource;
- non-empty caller-owned category and message collections.

The probe must prove the complete inert behavior listed above, one exact captured error, no caller-state exposure, and exact runtime script identity. It must also mutate the caller-owned values after construction and recheck the inert accessors.

The existing `invalid_success` and `invalid_failure` factory probes remain unchanged and must still return `null` with their exact existing ordered errors. Normal focused, regression, import, and full-suite processes must keep `PF_RIG_FACTORY_CONTRACT_PROBE` absent.

Before production changes, the future plan must obtain trustworthy RED from the direct-constructor probe. The current debug assertion may produce an assertion diagnostic instead of the required constructor-contract error. RED is trustworthy only when preserved evidence identifies that exact missing behavior and contains no unrelated parser, loader, import, crash, segmentation, object-leak, or RID-leak failure. If the runner cannot distinguish the expected pre-fix assertion boundary without weakening diagnostic policy, execution stops for a plan correction rather than waiving the evidence.

GREEN requires:

- native exit and marker behavior defined by the later plan;
- exactly one intentional constructor-contract error block;
- no assertion diagnostic;
- every inert-state assertion passing;
- zero unrelated diagnostics;
- the probe environment cleared afterward;
- no rerun of consumed prior probes.

Because a debug runtime probe alone cannot prove release compilation semantics, verification also requires an independent source/AST dominance audit:

- `_init()` contains an ordinary invalid-token `if` guard;
- its failure branch contains the exact `push_error` then `return`;
- zero caller-parameter assignment precedes the guard;
- `_construction_valid = true` is the final valid-construction assignment;
- `is_success()` begins with `_construction_valid`;
- `_init()` contains no `assert()` call;
- no public setter or writable result field is added.

### Dead-helper correction

The future plan must preserve public validator tests before deleting the obsolete block. A focused RED is not manufactured for dead-code deletion. Instead, use characterization and structural verification:

- the public duplicate/zero/range/agreement/conflict assertions pass before removal;
- delete the helper and only its helper-specific assertion block;
- the same public assertions and mapped-rig regressions pass afterward;
- repository search finds zero `_matching_name_indices` references.

### Regression and completion gates

After both corrections, run the focused catalog and production-mapped-rig suites, the complete rig regression set named by the current plan, a newly qualified full-suite checkpoint for the changed code, `git diff --check`, exact path-union audits, and two distinct fresh read-only reviews. A prior Task D or Step 7B pass cannot stand in for post-change verification.

All final gates require the exact terminal PASS contract, native exit `0`, no unexpected `TEST_FAILURE`, and no unexplained parser, loader, import, script-compile, crash, fatal, segmentation, object-leak, or RID-leak diagnostics. Intentional constructor probe output is isolated from normal runs and classified by its exact label and message.

## Exact Prospective File Scope

No path in this table is authorized for modification by this design gate. A later implementation plan may propose exactly these four paths:

| Path | Prospective responsibility |
|---|---|
| `scripts/presentation/humanoid_rig_mapping_resolution.gd` | Replace assertion-only constructor authorization with the explicit runtime guard, inert defaults, private validity bit, and validity-aware `is_success()`. |
| `tests/unit/test_humanoid_rig_mapping_catalog.gd` | Add the isolated invalid-direct-constructor probe while retaining all factory identity, failure, rejection, defensive-copy, and catalog tests. |
| `scripts/presentation/humanoid_rig_contract.gd` | Remove only `_matching_name_indices()`; preserve the public validator and all production behavior. |
| `tests/unit/test_production_humanoid_rig_mapping.gd` | Remove only the obsolete direct helper assertion block; retain public bind-identity and mapped-rig coverage. |

The fixture JSON, existing specs and plans, mapping resources, scenes, manifests, imports, caches, and assets remain byte-identical.

## Migration, Commits, and Rollback

A later implementation plan should keep the two corrections independently reviewable:

1. release-safe result construction: resolution script plus catalog test;
2. obsolete bind-name helper removal: rig contract plus mapped-rig test.

Each correction requires its own TDD/characterization evidence and local checkpoint commit. Exact subjects are deferred to the implementation plan. No existing commit is amended, rebased, squashed, or rewritten.

Rollback is commit-based:

- reverting the dead-helper commit restores only the obsolete helper and its direct helper test;
- reverting the constructor commit restores the prior assertion-only boundary and is therefore allowed only as an explicit acknowledged regression under a separate approval;
- neither rollback touches the four earlier implementation commits, four plan-only corrections, this design commit, any Task D/Step 7A/Step 7B evidence, protected files, GLBs, fixture, Dawn Bulwark, Combat HUD, or absent resources.

Historical and failed-attempt evidence is never deleted or overwritten as part of rollback.

## Exclusions and Approval Gates

This design does not authorize:

- implementation or test changes;
- modification of any existing spec or plan;
- Godot execution, import, cache generation, archive creation, or suite execution;
- mapping `.tres` resources, body qualification, or presentation integration;
- heads, armor, Dawn Bulwark production, equipment, assets, downloads, Blender, 3D Gen Studio, geometry, rigging, weights, UVs, materials, or textures;
- changes to Combat HUD or another worktree;
- merge, rebase, push, cleanup, deletion, publication, or Task E completion.

This gate ends after this one new design document is self-reviewed, committed alone, and verified. The next gate is Studio Lead written-spec review. No implementation plan or code change starts automatically.
