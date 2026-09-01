# Production Rig Review Correction Amendment

**Status:** Approved corrective direction; written-spec review pending

**Date:** 2026-09-01

**Branch at authoring:** `feat/class-preview-character-model-replacement`

**Parent checkpoint:** `ee750b60663860e959696bf06904bdbe51374779`

## Purpose and Amendment Boundary

This document corrects the gaps and boundary contradictions found by the independent requirements review of the pre-resource production-rig checkpoint. It preserves the catalog as a stateless resolver and amends, but does not replace or rewrite:

- `docs/superpowers/specs/2026-09-01-body-specific-production-rig-mapping-amendment-design.md`
- `docs/superpowers/plans/2026-09-01-body-specific-production-rig-mapping-amendment.md`
- `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`

The existing approved spec remains authoritative for body-specific source hashes, rest signatures, the 19 semantic roles, complete numeric-bind coverage, native-rest preservation, and the prohibition on a shared mapping resource. This amendment takes precedence only for:

1. the responsibility boundary between stateless mapping resolution and later presentation transactions;
2. the catalog's exact-path loader seam and public structured result;
3. the missing inspected 52-bone end-to-end proof and public-validator null/empty-target coverage; and
4. duplicate-name validation at the pure bind-identity boundary required by Godot's `Skeleton3D` naming invariant.

No implementation is authorized by this document. The existing implementation plan must remain byte-identical during this gate and requires a separately approved corrective plan amendment before any code or test work.

## Verified Checkpoint and Provenance

At authoring, the isolated worktree is at `ee750b60663860e959696bf06904bdbe51374779` with a clean tracked index and 77 preserved untracked paths. The nine existing first-parent commits after implementation base `d729b520252c7dc2ad2e9ba7182f63f4c33c27dd` remain unchanged. The three implementation commits remain:

- `d33270851f50121b61ec50df3026baeab4e64a4a` — `feat: accept complete numeric production skin binds`
- `1718b115caf17ee448d5a566d9a6ad6c4385ac7d` — `feat: verify body-specific production rig identity`
- `942991105c1ac86e34aaaa71cadbeef06e889d20` — `feat: resolve body-specific humanoid rig mappings`

The six existing documentation-only plan corrections remain unchanged. This amendment appends a new documentation-only commit; it does not rewrite the nine-commit history or recategorize any prior commit.

Preservation references at authoring:

- approved spec SHA-256: `e8a9eba54b410cecd98161cfa2f3032fa9390a697e6a286995e1c394f28e2c87`
- current implementation plan SHA-256: `c7f179ba3c90ef974f1f04afed3afdd388e5bc5d62f455e3bb68ab9a21463440`
- original production-character plan SHA-256: `047dc28ce0c851227b80f9f63ec9abd2a0b060fd144a0041e03a1748ceedb00d`
- protected untracked manifest: `C:\Users\Jacob\AppData\Local\Temp\pf-character-task2-reconcile-gate-0001\premerge-untracked-manifest.json`
- protected manifest SHA-256: `9f7d8b800e27f94d2bc1f7798a88c9bda73c65d0429c3c072bbe00daeafbe2bd`
- pristine Step 4B evidence: `C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-step4b-20260901T073118Z-5f5655f4`
- Step 4B result: native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (265 suites)`, zero fail markers, zero unexplained diagnostics

The immutable rig inputs remain:

| Body preset | Immutable SHA-256 | Native rest signature |
|---|---|---|
| `&"masculine"` | `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` | `1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda` |
| `&"feminine"` | `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667` | `fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85` |

## Review-Finding Disposition

| Step 5 finding | Disposition | Evidence and rationale | Corrective responsibility |
|---|---|---|---|
| The inspected 52-bone, 52-unnamed-bind public-validator proof is absent. | Accepted gap | `test_production_humanoid_rest_signature.gd` reconstructs both 52-bone skeletons but never constructs a `Skin` or calls `validate_mapped_rig()`. The numeric-only public-validator proof in `test_production_humanoid_rig_mapping.gd` uses a 22-bone synthetic skeleton. | Add path-free 52-bone skeleton and 52-bind `Skin` reconstruction for both inspected candidates and call the public mapped and legacy validators. |
| Failed resolution must prove that the prior active visual survives. | Rejected as a current resolver responsibility; deferred integration responsibility | The approved plan requires a stateless catalog with no active visual, model, transaction, or presentation ownership. The existing test-side `_activate_if_resolved()` helper proves only its own assignment behavior and must not be presented as production integration proof. | The correction proves fail-closed stateless resolution only. Prepared-body commit and preservation of the prior active visual remain mandatory in the separately approved presentation-integration phase. |
| Exact mapping paths are constants but are not part of the production selection seam. | Accepted gap and resolved boundary contradiction | The current catalog selects a preset-keyed injected mapping. Its exact path constants are inspected separately, so no production call proves which resource path was requested. Loading forbidden production `.tres` files is outside the current phase. | Replace preset-keyed mapping injection with an exact-path loader boundary. Tests inject a loader, record the requested path, and return in-memory mappings without writing or loading forbidden resources. |
| Catalog errors are discarded as `null`. | Accepted gap | `_identity_errors()` creates useful details, but `resolve()` discards them and exposes only mapping-or-null. | Return a structured public result with deterministic categories and readable messages; never store mutable last-error state. |
| Null mapping, null skeleton, null skin, and empty mapped target lack direct public-validator tests. | Accepted gap | The production code rejects the null inputs and mapping validation rejects empty targets, but the public `validate_mapped_rig()` boundary lacks explicit coverage. | Add direct public-validator assertions for each input and preserve deterministic early-return behavior. |
| Duplicate `Skeleton3D` names need a public-validator fixture. | Rejected literal interpretation; accepted pure-boundary obligation | Godot rejects duplicate bone names during `Skeleton3D.add_bone()`/`set_bone_name()` fixture construction. The preserved failed RED already demonstrated that an attempted duplicate-name skeleton emits an engine diagnostic. Suppressing that diagnostic or serializing a corrupted skeleton would create an invalid test. | Introduce a production pure bind-identity validator consumed by `validate_mapped_rig()`. Test duplicate names through an `Array[StringName]` snapshot, and retain real `Skeleton3D` integration tests for zero-match and exact-one-match cases. |
| Original plan non-modification was not independently provable from implementation commit scope alone. | No product-code gap; preservation obligation retained | None of the three implementation commits touches the original untracked plan. Its current bytes are protected by the 77-file manifest and its authoring SHA-256 above. | Rehash the original plan and all protected paths before and after every future correction gate. Do not stage or edit it. |

## Corrected Architecture

The corrected contract has four independent units:

1. `HumanoidRigContract` validates a supplied mapping, skeleton, and skin. It owns mapped bind identity, complete numeric coverage, mapped rest identity, semantic coverage, and ancestry. It does not load resources or manage presentation state.
2. `HumanoidRigMappingLoader` is a stateless exact-path production adapter around `ResourceLoader`. It reports path existence and loads exactly the requested Godot resource URI. It does not choose a body preset or fallback path.
3. `HumanoidRigMappingCatalog` maps a body preset to exactly one resource URI, invokes an injected or default exact-path loader, validates mapping identity, and returns a structured result. It owns no active selection, visual, body, model, transaction, error history, or fallback.
4. `HumanoidRigMappingResolution` is a per-call value object. It carries success or failure data without mutating the catalog. A later presentation transaction may transform a successful resolution into a mapped-rig-validation failure result, but that transaction is not implemented or tested in this correction phase.

The data flow is:

```text
body preset
  -> exact RESOURCE_PATH_BY_BODY_PRESET lookup
  -> loader.exists_exact(path)
  -> loader.load_exact(path)
  -> exact type and body identity checks
  -> HumanoidRigMappingResolution
  -> later presentation phase validates prepared Skeleton3D/Skin
  -> later presentation phase commits or rejects the visual transaction
```

There is no cross-body lookup, shared-resource alias, secondary path, class-based override, or current-active fallback.

## Exact-Path Loader Contract

Prospective interface:

```gdscript
class_name HumanoidRigMappingLoader
extends RefCounted

func exists_exact(resource_path: String) -> bool
func load_exact(resource_path: String) -> Variant
```

The production implementation is exact:

- `exists_exact(path)` delegates to `ResourceLoader.exists(path)` without substituting a type-specific or alternate path.
- `load_exact(path)` delegates to `ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_REUSE)` exactly once.
- The loader does not normalize to another preset, search directories, retry another path, or return a shared fallback.
- The catalog checks existence before loading so an absent approved `.tres` produces the stable `missing_resource` category rather than an avoidable loader diagnostic.
- If existence is true but loading returns `null`, resolution uses `resource_load_failed`.
- If loading returns a non-`HumanoidRigMapping` resource, resolution uses `wrong_resource_type`.

`HumanoidRigMappingCatalog.resolve()` accepts a loader per call:

```gdscript
func resolve(
		body_preset_id: StringName,
		loader: HumanoidRigMappingLoader = null
	) -> HumanoidRigMappingResolution
```

When `loader` is `null`, the method constructs the production loader locally for that call. The catalog stores no loader, injected mapping dictionary, active mapping, selected preset, result, or last error. Tests inject a deterministic fake loader that records every `exists_exact()` and `load_exact()` path and returns in-memory resources keyed by exact resource URI. The fake may have recording state; the production catalog may not.

The catalog selects only these canonical Godot repository-relative resource URIs:

| Body preset | Exact requested URI |
|---|---|
| `&"masculine"` | `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` |
| `&"feminine"` | `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres` |

An unknown preset has no selected path and must not call either loader method. The shared URI `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres` is never selected.

## Structured Resolution Result

Prospective interface:

```gdscript
class_name HumanoidRigMappingResolution
extends RefCounted

const _RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}
static var _factory_token := RefCounted.new()

var _requested_body_preset: StringName
var _selected_resource_path: String
var _mapping: HumanoidRigMapping
var _failure_categories: Array[StringName]
var _error_messages: PackedStringArray

func _init(
		factory_token: RefCounted,
		requested_body_preset: StringName,
		selected_resource_path: String,
		mapping: HumanoidRigMapping,
		failure_categories: Array[StringName],
		error_messages: PackedStringArray
	) -> void

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
func rejected_by_mapped_rig(
		validation_errors: PackedStringArray
	) -> HumanoidRigMappingResolution
```

The five underscore-prefixed fields are private implementation state. No public property, setter, mutable collection reference, active-result field, or last-error field is exposed. Callers inspect results only through the five `get_*()` methods, `is_success()`, and `rejected_by_mapped_rig()`.

`get_requested_body_preset()` and `get_selected_resource_path()` return scalar values. `get_mapping()` returns the validated `HumanoidRigMapping` Resource reference. The wrapper does not make that Resource immutable: later presentation code must still run `validate_mapped_rig()` against the prepared skeleton and skin and must not treat the wrapper as freezing mapping internals. `get_failure_categories()` and `get_error_messages()` return new defensive duplicates on every call, so caller mutation cannot change stored result state or break category/message cardinality.

Instances are created atomically through `succeeded()` or `failed()`. Each factory first copies every collection input into a local snapshot, validates the complete snapshot against the applicable invariant in deterministic field order, and allocates the result only after validation succeeds. The result's private path table contains the same two exact values as the catalog; prospective tests require the two tables to be equal so the success factory can enforce preset/path consistency without calling the catalog or creating a circular dependency.

The internal constructor requires the private `_factory_token` plus the complete validated state, assigns all five backing fields during initialization, and does not publish `self` during construction. Both factories invoke it only as `HumanoidRigMappingResolution.new(_factory_token, ...)` after validation. Direct `.new()` is not a supported public construction path; a missing or incorrect factory token triggers `assert(false, "humanoid rig mapping resolution constructor is factory-only")` before state assignment. No public API returns the token.

Invalid factory input is also a programmer-contract failure, not a normal catalog-resolution failure. The factory emits exactly one `push_error()` beginning `humanoid rig mapping resolution factory contract failed:` followed by ordered validation details, returns `null`, and allocates no result. It never returns a partially initialized or contradictory wrapper and never converts programmer misuse into one of the runtime resolution categories. Prospective tests capture the intentional factory error through the existing test error-capture boundary and require the exact null result and deterministic message without leaving an unexplained engine diagnostic.

Factory validation order is exact:

- `succeeded()` validates known preset, exact preset/path match, then non-null mapping. It supplies empty category/message snapshots to the constructor.
- `failed()` duplicates categories and messages, validates non-empty arrays, equal cardinality, each category against the nine-category allowlist in input order, each paired message as non-empty in the same order, exact category shape, then path semantics. Categories 1 through 4 are terminal and must be the sole category. Identity categories 5 through 8 are unique and strictly ascending when combined. Category 9 may repeat once per validator error but may not be mixed with another category. `unknown_body_preset` requires an unknown preset and an empty path; every other category requires a known preset and that preset's exact path. It supplies `mapping = null` to the constructor.
- If multiple programmer-contract defects are present, the one `push_error()` joins every ordered detail with `; ` and returns `null` before `_init()` is called.

Success has one invariant:

- `requested_body_preset` is `&"masculine"` or `&"feminine"`;
- `selected_resource_path` is that preset's exact URI;
- `mapping` is non-null;
- `failure_categories` and `error_messages` are empty.

`is_success()` reads only private backing state and returns `true` if and only if all four conditions above hold. Caller-owned arrays previously returned by either collection accessor cannot affect this result.

Failure has one invariant:

- `mapping` is `null`;
- `failure_categories` is non-empty;
- `failure_categories.size() == error_messages.size()`;
- every category and message is non-empty;
- `selected_resource_path` is empty only for `unknown_body_preset`, otherwise it is the exact attempted URI; and
- `is_success()` returns `false`.

Stable categories are `StringName` constants with these exact values and ordering precedence:

1. `&"unknown_body_preset"`
2. `&"missing_resource"`
3. `&"resource_load_failed"`
4. `&"wrong_resource_type"`
5. `&"wrong_mapping_id"`
6. `&"wrong_canonical_rig_id"`
7. `&"wrong_source_hash"`
8. `&"wrong_rest_signature"`
9. `&"mapped_rig_validation_failed"`

Unknown preset, missing resource, failed load, and wrong type are terminal single-category failures because no valid mapping identity is available. For a valid mapping type, identity failures accumulate in category order 5 through 8. Messages include requested preset, exact selected path, expected value, and actual value. They never contain machine-specific staging paths.

Message templates are exact. Braced names below identify the value inserted at that position:

| Category | Exact message template |
|---|---|
| `unknown_body_preset` | `humanoid rig mapping catalog body preset {preset} is unknown` |
| `missing_resource` | `humanoid rig mapping catalog body preset {preset} resource {path} does not exist` |
| `resource_load_failed` | `humanoid rig mapping catalog body preset {preset} resource {path} could not be loaded` |
| `wrong_resource_type` | `humanoid rig mapping catalog body preset {preset} resource {path} must be HumanoidRigMapping, got {actual_type}` |
| `wrong_mapping_id` | `humanoid rig mapping catalog body preset {preset} mapping id must be {expected}, got {actual}` |
| `wrong_canonical_rig_id` | `humanoid rig mapping catalog body preset {preset} canonical rig id must be {expected}, got {actual}` |
| `wrong_source_hash` | `humanoid rig mapping catalog body preset {preset} source skeleton hash must be {expected}, got {actual}` |
| `wrong_rest_signature` | `humanoid rig mapping catalog body preset {preset} source rest signature must be {expected}, got {actual}` |
| `mapped_rig_validation_failed` | `humanoid rig mapping catalog body preset {preset} resource {path} mapped rig validation failed: {validator_error}` |

`preset`, `expected`, and `actual` use their deterministic string representations. `path` is the selected canonical `res://` URI. `actual_type` is `null` only for a failed load and otherwise is the loaded object's Godot class name; the failed-load branch prevents `null` from reaching the wrong-type branch. `validator_error` is the unchanged `HumanoidRigContract` error string.

`rejected_by_mapped_rig()` is a pure result transformation reserved for the later presentation transaction. It duplicates `validation_errors` before inspection. On a successful result plus non-empty copied errors, it calls `failed()` with private backing-state scalars, retains the preset and selected path, clears the mapping through the failure factory, and supplies one `mapped_rig_validation_failed` category for each validator message in original order. It does not mutate the original result, the caller's array, or the catalog. Passing an empty validation array returns the unchanged successful result. Calling it on an existing failure returns that failure unchanged. The correction phase may test this value behavior, but it must not claim that a real active visual was preserved.

## Catalog Resolution Algorithm

For `resolve(body_preset_id, loader)`:

1. If the preset is not `&"masculine"` or `&"feminine"`, return `unknown_body_preset` with an empty selected path and make zero loader calls.
2. Select the exact URI from `RESOURCE_PATH_BY_BODY_PRESET`.
3. Use the supplied loader or create one default production loader for this call.
4. Call `exists_exact(selected_path)` exactly once. If false, return `missing_resource`; do not call `load_exact()`.
5. Call `load_exact(selected_path)` exactly once. If null, return `resource_load_failed`.
6. If the value is not `HumanoidRigMapping`, return `wrong_resource_type`.
7. Validate identity in this order: mapping ID, canonical rig ID, source skeleton SHA-256, source rest signature. Accumulate every mismatch in the same order.
8. If any identity error exists, return failure with `mapping = null` and the accumulated categories/messages.
9. Otherwise return success with the exact loaded mapping.

Expected identities remain those already approved in the original amendment. A masculine request can succeed only with the masculine mapping ID, source hash, and rest signature; the equivalent rule holds for feminine. A cross-body mapping therefore reports the applicable identity mismatches and never falls back.

## Pure Bind-Identity Boundary

Godot's public `Skeleton3D` API rejects duplicate bone names during construction. That engine invariant is verified by the preserved failed RED and must not be bypassed, suppressed, or encoded into a corrupted resource.

`HumanoidRigContract` gains this production pure boundary:

```gdscript
static func validate_mapped_bind_identity(
		bone_names: Array[StringName],
		bind_name: StringName,
		numeric_bone_index: int,
		bind_slot: int
	) -> PackedStringArray
```

The method is used by `_resolve_mapped_skin_binds()` for every bind slot. It is deterministic and side-effect free:

1. Validate `numeric_bone_index` against `bone_names.size()`. An invalid numeric index returns the existing slot-specific out-of-range error immediately; a name never repairs it.
2. If `bind_name` is empty and the numeric index is valid, return no error.
3. Otherwise collect all exact matching indices from `bone_names` in ascending index order.
4. Zero or multiple matches return exactly one `must resolve exactly once; found N` error.
5. One match at a different numeric index returns exactly one name/index-conflict error.
6. One matching index equal to the numeric index returns no error.

The pure unit test supplies a synthetic duplicate-name array and proves the multiple-match error without creating a `Skeleton3D`. Real public-validator integration tests use valid `Skeleton3D` instances to prove empty-name numeric authority, zero-name-match rejection, exact-one agreement, name/index conflict, range checks, duplicate numeric coverage, and complete coverage. The engine guarantees that a valid live `Skeleton3D` snapshot has unique names; the pure boundary guarantees fail-closed behavior if a duplicate-name list is ever supplied by another validated adapter or a future engine behavior changes.

This boundary does not alter `validate_rig()`, `validate_skin()`, `_bone_indices_named()`, the six-decimal legacy serializer, or any existing legacy error text.

## Inspected 52-Bone End-to-End Qualification

The existing path-free fixture `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json` remains byte-identical. For each of its masculine and feminine candidates, a prospective test must:

1. reconstruct all 52 bones in inspected index order with exact names, direct parents, and local rests;
2. construct a `Skin` with exactly 52 binds;
3. set bind slot `i` to numeric bone index `i`;
4. set bind pose `i` to the inverse of `skeleton.get_bone_global_rest(i)`, producing a deterministic finite, invertible skin-space bind from the reconstructed hierarchy;
5. leave every bind name empty;
6. construct the exact 19-role mapping with the candidate's approved mapping ID, canonical ID, immutable source SHA-256, and fixture rest signature;
7. require `validate_mapped_rig(definition, mapping, skeleton, skin)` to return an empty error array;
8. require `validate_rig(definition, skeleton, pivot_root)` to retain the strict `bone count must be 19, got 52` failure; and
9. require `validate_skin(definition, skin)` to retain named-only failures for the same unnamed 52-bind skin.

The test must run for both body presets. It proves the inspected topology/rest data and complete unnamed numeric-bind behavior through the public mapped validator without importing, copying, or opening either GLB.

The public mapped-validator suite also adds exact tests for:

- null mapping returns only `humanoid rig mapping is missing`;
- valid mapping plus null skeleton returns `mapped humanoid Skeleton3D is missing` after mapping validation;
- valid mapping/skeleton plus null skin returns `mapped humanoid Skin is missing` after mapping validation and skeleton presence checks, before live rest or bind validation;
- an empty mapped target reaches `validate_mapped_rig()` and reports the mapping role's empty-or-duplicate target error;
- all existing order, range, duplicate coverage, finite/invertible bind, finite/invertible rest, source/rest identity, semantic coverage, and ancestry tests remain present.

The null-skin expectation preserves current ordering: mapping validity, skeleton presence, then skin presence. No test may suppress engine diagnostics or rely on a corrupted skeleton.

## Statelessness and Deferred Presentation Transaction

The catalog is stateless in the precise sense that it contains no mutable fields for active preset, active mapping, active body, active model, current result, prior result, or last error. Each `resolve()` call depends only on its arguments and the exact resources returned by that call's loader.

Current correction tests may prove:

- exact requested path and call count;
- deterministic result contents;
- repeated calls do not contaminate one another;
- a successful result object is unchanged after a later failed call; and
- `rejected_by_mapped_rig()` returns a new result instead of mutating its input;
- mutating arrays returned by `get_failure_categories()` or `get_error_messages()` does not alter later accessor results, cardinality, or `is_success()`; and
- the public API exposes no setter for preset, path, mapping, categories, messages, active state, or last error.

They must not claim to prove:

- a `ForgeHumanoidModel` swap;
- a scene-tree or rendering transaction;
- retention of an active body, mesh, skeleton, skin, equipment set, animation, or camera;
- rollback after a partially prepared visual commit; or
- production fallback presentation behavior.

Those behaviors remain mandatory acceptance criteria for the separately approved presentation-integration phase. That phase must prepare the candidate body off the active presentation, resolve the exact mapping, run `validate_mapped_rig()`, translate any validation errors into the structured result, and commit the prepared visual only after success. On failure it must dispose of the prepared candidate and prove with integration evidence that the prior active visual remains unchanged.

## Prospective File Scope

No file below is authorized in this documentation gate. A later corrective implementation plan may propose only this coherent scope unless a new design amendment is approved:

| Path | Prospective responsibility |
|---|---|
| `scripts/presentation/humanoid_rig_mapping_resolution.gd` | New factory-created, read-only, structured per-call result with private backing state, defensive accessors, and pure mapped-rig rejection transformation. |
| `scripts/presentation/humanoid_rig_mapping_loader.gd` | New stateless exact-path `ResourceLoader` adapter. |
| `scripts/presentation/humanoid_rig_mapping_catalog.gd` | Replace preset-keyed injected mappings with exact-path resolution, loader injection, identity validation, and structured results. |
| `scripts/presentation/humanoid_rig_contract.gd` | Add the pure bind-identity boundary and route mapped bind resolution through it without altering legacy validators. |
| `tests/unit/test_humanoid_rig_mapping_catalog.gd` | Prove exact path calls, structured categories/messages, identity ordering, no fallback, stateless calls, and no mutable last-error channel. |
| `tests/unit/test_production_humanoid_rig_mapping.gd` | Add public null/empty-target coverage and pure duplicate-name identity coverage while retaining all existing mapped-validator cases. |
| `tests/unit/test_production_humanoid_rest_signature.gd` | Extend the path-free two-candidate fixture test to construct 52 unnamed numeric binds and exercise mapped plus strict legacy validators end to end. |

The fixture JSON does not change. The approved spec, current implementation plan, original production-character plan, mapping resources, manifests, scenes, imports, and assets do not change in the correction implementation checkpoint.

## Deterministic Test and Error Requirements

A future TDD plan must define trustworthy RED before each production change. It must preserve the existing fixed-nine-decimal serializer tests and all prior numeric-bind/legacy regressions. New tests must prove:

- the result success/failure invariants and one-to-one category/message arrays;
- the result's private preset/path table remains byte-for-byte equal to the catalog's public `RESOURCE_PATH_BY_BODY_PRESET` table;
- invalid success/failure factory inputs produce the exact programmer-contract error and `null` without allocating an observable result;
- the result exposes only read accessors, collection accessors return defensive duplicates, and caller mutation cannot change stored categories, messages, cardinality, or `is_success()`;
- `get_mapping()` returns the validated Resource reference without claiming to freeze that Resource's mutable internals;
- exact category order and exact requested path for every catalog failure;
- zero loader calls for unknown presets;
- one existence call and zero load calls for missing resources;
- exactly one existence and one load call for all later catalog outcomes;
- wrong type, wrong mapping ID, wrong canonical ID, wrong source hash, wrong rest signature, and cross-body identity failures;
- both masculine and feminine successes through their exact paths only;
- no shared-path or cross-body fallback;
- repeated resolution calls have no active/result/error history;
- mapped-rig failure transformation preserves validation-error order without mutating the successful result;
- both inspected 52-bone candidates pass public mapped validation with 52 complete unnamed numeric binds;
- the same candidates remain rejected by both strict legacy boundaries;
- public null and empty-target failure coverage; and
- duplicate-name ambiguity at `validate_mapped_bind_identity()` with no invalid `Skeleton3D` construction or engine diagnostic.

Catalog identity error order is mapping ID, canonical rig ID, source hash, then rest signature. Mapped-rig validation messages retain `HumanoidRigContract` order. Every focused and full-suite run must still require native exit `0`, exactly one terminal pass marker, zero fail markers, and no unexplained parser, loader, import, script, crash, segmentation, object-leak, or RID-leak diagnostics.

## Migration and Rollback

The approved correction sequence is:

1. Commit this amendment only and stop for written-spec review.
2. After explicit written-spec approval, write a corrective implementation-plan amendment. That plan must account for this new documentation commit without rewriting the existing nine commits.
3. Implement result and exact-path catalog tests through trustworthy RED/GREEN.
4. Implement the pure bind-identity boundary and missing public-validator tests through trustworthy RED/GREEN.
5. Add both inspected 52-bone end-to-end tests through trustworthy RED/GREEN.
6. Run focused regression, fresh full-suite, independent requirements review, and independent code-quality review.
7. Stop at a new pre-resource contract checkpoint.
8. Only a later separate gate may authorize the two exact `.tres` writes.
9. Only a later presentation-integration plan may implement prepared-body commit and prior-active-visual preservation.

Rollback is commit-based and never mutates accepted history:

- reverting the future corrective implementation commit restores the current catalog and validator behavior;
- reverting this documentation commit removes only this amendment;
- the three existing implementation commits and six existing plan-correction commits remain intact;
- no rollback touches the two immutable GLBs, protected untracked files, Step 4B evidence, Dawn Bulwark worktree, Combat HUD worktree, or absent production resources.

## Exclusions and Stop Gates

This amendment does not authorize:

- code, test, fixture, existing spec, plan, resource, manifest, scene, import, cache, or asset changes;
- either body-specific mapping `.tres` or a shared mapping `.tres`;
- body qualification, heads, armor, Dawn Bulwark production, equipment, Blender, 3D Gen Studio, geometry, rigging, weights, UVs, materials, or textures;
- presentation transactions, active-body mutation, Godot integration, previews, or runtime asset promotion;
- suite execution, reviewer dispatch, merge, rebase, push, cleanup, deletion, publication, or Task 5 work.

This gate ends after this one-file design correction is committed separately from `78893389adc084bc376fb82eb1ba267e11e35c79` and its exact scope, API/type consistency, factory invariants, defensive-copy behavior, absence of mutable last-error state, preservation hashes, protected-worktree snapshots, and absent sentinels are verified. The next gate is renewed written-spec review. Writing-plans and implementation do not start automatically.
