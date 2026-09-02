# LatticeWright City Tree v3 Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Party Forge's obsolete format-1 City-tree data path with the approved 37-node LatticeWright runtime-v3 tree, make every presently implemented node safely allocatable, reveal City on the first victory and award one passive point per subsequent unique victory, and prevent Player Mode item drops until both item features and positive run-inventory capacity are available.

**Architecture:** LatticeWright remains the sole editable City-tree source and exports deterministic runtime-v3 JSON. Party Forge strictly reads that envelope, selects a versioned adapter, and projects it into the existing stable passive-tree domain. A portfolio registry supplies live portal-target health to one activation policy used by both presentation and commit-time mutation. Victory rewards join the existing idempotent terminal-resolution transaction, while one centralized item-drop access policy runs before any random roll or item-generation state is derived.

**Tech Stack:** LatticeWright 0.5.0, TypeScript 6, Node.js, Vitest, Party Forge on Godot 4.7.1 Mono, GDScript, the existing focused/unit/integration runners, Godot AI for editor-backed checks, Git worktrees, PowerShell.

## Global Constraints

- The approved design is `docs/superpowers/specs/2026-09-02-latticewright-city-tree-v3-design.md` at Party Forge commit `e0b5460b0f10bd0fe52fc94a001645ee6c626964`.
- This plan implements **Milestone 1 only**. Milestones 2-5 remain design-gated. Do not invent effects, tuning, target runtimes, or detailed behavior for the 24 `future` nodes or activate any of the six `portal-gated` charters without its exact registered target.
- Authoritative repositories are `E:\Projects\Passive Skill Tree Creator` for LatticeWright and `F:\Projects(root)\Game dev\Projects\party-forge` for Party Forge. Never treat the saved parent project as the Party Forge repository.
- Execute in dedicated isolated worktrees. Do not use or alter LatticeWright's existing `party-forge-city-logistics` worktree or its untracked autosave. Do not alter any other user-owned worktree.
- This task may use exactly two reusable subagents under `superpowers:subagent-driven-development`: one `gpt-5.6-luna` agent at `max` reasoning for bounded implementation/fix work, and one `gpt-5.6-sol` agent at `high` reasoning for sequential task and whole-branch reviews. The root agent retains worktree, containment, integration, visual-handoff, and publication control. Never run two write-heavy implementation tasks in parallel.
- Use strict TDD: demonstrate each new test failing for the intended reason, implement only enough to pass, then refactor without changing behavior.
- Do not invoke the WinGet Godot executable. Use `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` for shell gates and the already approved Godot AI connection for focused editor-backed checks.
- The old Party Forge format-1 City data path is obsolete. There is no format-3-to-format-1 conversion, compatibility projection, or fallback. Unsupported format 4+ must produce an adapter-unavailable error until a future adapter is approved.
- Preserve the stable Party Forge domain tree ID `party-forge-city-v1`, all 31 old node IDs, every existing valid allocation, every unknown saved allocation as unresolved history, and all monotonic permanent unlock/building/tree data. Do not auto-refund or revoke anything.
- Preserve and hash authoritative main's 68 pre-existing untracked `.gd.uid` files before and after every integration boundary. Do not stage or modify them. Keep any feature-worktree-generated `.gd.uid` sidecars untracked and record them separately.
- Do not touch active art, body-model, presentation-asset, Blender, HUD, Review Batch 1, Frost recruitment, attack-windup, or run-seed paths.
- Do not reset, clean, delete worktrees, rewrite history, force-push, or perform destructive cleanup. Stop on conflict, remote drift, scope drift, missing evidence, a new product/visual choice, or a permission boundary. Do not request a sandbox/network bypass.
- Every commit must pass its focused tests, touched-language static checks, and `git diff --check`. Do not hide expected failures with broad error suppression.
- Visual acceptance is required in both LatticeWright and Party Forge. Because Jacob is remote, copy final screenshots to the task's visualization directory and render them inline in the task; a local editor window alone is not acceptance evidence.
- Normal conflict-free fetch, integration, and push are permitted only after both repositories are pristine at the exact reviewed commits and all required qualification gates pass.

## Execution Setup and Containment Baseline

- [ ] Record exact heads, branches, remotes, worktree registrations, tracked/index status, and submodule status for both authoritative repositories. Every Git command names either `E:\Projects\Passive Skill Tree Creator` or `F:\Projects(root)\Game dev\Projects\party-forge` explicitly with `git -c safe.directory='*' -C`.
- [ ] Recompute the authoritative Party Forge `.gd.uid` manifest as sorted records of relative path, byte length, and SHA-256. Confirm exactly 68 records and compare their aggregate digest to the latest validated baseline before doing any write.
- [ ] Record all non-UID status entries separately. Stop if either authoritative repository or a selected worktree has unaccounted user-owned dirt.
- [ ] Create a dedicated LatticeWright worktree and branch from verified `main` (suggested branch `feature/party-forge-city-v3-runtime`) and a dedicated Party Forge implementation worktree/branch based on the approved design/plan commit (suggested branch `feature/latticewright-city-v3-foundation`). Use `superpowers:using-git-worktrees`; do not reuse the design-only worktree for production edits.
- [ ] In each worktree, rerun the status and manifest checks and record the exact baseline commit. If the current sandbox cannot write the authoritative LatticeWright repository's worktree metadata, stop at that permission boundary without creating a substitute repository.
- [ ] Define task-specific shell variables only inside the execution shell:

```powershell
$partyForgeRepo = 'F:\Projects(root)\Game dev\Projects\party-forge'
$partyForgeWorktree = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-city-v3-foundation'
$latticeWrightRepo = 'E:\Projects\Passive Skill Tree Creator'
$latticeWrightWorktree = 'E:\Projects\Passive Skill Tree Creator\.worktrees\party-forge-city-v3-runtime'
$partyForgeGodot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
```

---

### Task 1: Author and deterministically export the approved City runtime in LatticeWright

**Files:**
- Modify: `scripts/party-forge/create-party-forge-portfolio.mjs`
- Modify: `scripts/party-forge/create-party-forge-portfolio.d.mts`
- Add: `scripts/party-forge/party-forge-city-v3-contract.mjs`
- Add: `scripts/party-forge/party-forge-city-v3-contract.test.mjs`
- Modify: `scripts/party-forge/create-party-forge-portfolio.test.mjs`
- Modify: `tests/party-forge/portfolio.test.ts`
- Replace: `samples/party-forge-city.pstree`
- Replace: `samples/party-forge-city.pstree.json`

**Interfaces and exact authored truth:**

```js
export const CITY_IDENTITY = Object.freeze({
  projectId: "party-forge-city",
  graphId: "city-passive-tree",
  domainTreeId: "party-forge-city-v1",
});

export const CITY_ACTIVATION = Object.freeze({
  implemented: Object.freeze([
    "city-heart", "equipment-registry", "field-pack", "stash-access",
    "extraction-license", "secured-loadout", "leader-loadout-extraction",
  ]),
  portalGated: Object.freeze([
    "hero-district-charter", "trials-district-charter",
    "market-district-charter", "expedition-district-charter",
    "forge-district-charter", "logistics-district-charter",
  ]),
  future: Object.freeze([
    "shared-lessons-1", "shared-lessons-2", "expanded-barracks", "hero-registry",
    "training-yard", "trial-monument", "arena-charter", "endless-gate",
    "open-market", "merchant-permits", "contract-ledger", "grand-exchange",
    "surveyors-office", "expedition-board", "north-road-charter", "waystone-network",
    "pathfinders-charter", "smiths-guild", "reclamation-bench", "artificers-hall",
    "grand-workshop", "civic-archive", "blueprint-library", "hall-of-heroes",
  ]),
});

export const CITY_PORTALS = Object.freeze([
  ["city-to-hero-district", "hero-district-charter", "party-forge-hero-district", "hero-district-passive-tree", "party-forge-hero-district-v1"],
  ["city-to-trials-district", "trials-district-charter", "party-forge-trials-district", "trials-district-passive-tree", "party-forge-trials-district-v1"],
  ["city-to-market-district", "market-district-charter", "party-forge-market-district", "market-district-passive-tree", "party-forge-market-district-v1"],
  ["city-to-expedition-district", "expedition-district-charter", "party-forge-expedition-district", "expedition-district-passive-tree", "party-forge-expedition-district-v1"],
  ["city-to-forge-district", "forge-district-charter", "party-forge-forge-district", "forge-district-passive-tree", "party-forge-forge-district-v1"],
  ["city-to-logistics-district", "logistics-district-charter", "party-forge-building-warehouse", "warehouse-passive-tree", "party-forge-warehouse-v1"],
]);
```

- [ ] **Step 1: Add red City-contract tests**

Assert exact identity/extensions, 37 unique content records, 37 one-to-one placements, 37 unique endpoint pairs, one start (`city-heart`), activation counts 7/24/6, exact placement costs, exact coordinates from the approved spec, exact six portals, no obsolete 15 direct portals, and exact live effects/Extraction License requirements.

The runtime top-level extensions must equal:

```js
{
  gameplayConsumer: "party-forge",
  partyForgeDomainTreeId: "party-forge-city-v1",
  partyForgeStatus: "runtime-integrated",
}
```

Run:

```powershell
node --test scripts/party-forge/party-forge-city-v3-contract.test.mjs scripts/party-forge/create-party-forge-portfolio.test.mjs
npx.cmd vitest run tests/party-forge/portfolio.test.ts
```

Expected RED: the current City has 31 placements/connections, 15 obsolete portals, empty effect/requirement schemas, and `not-yet-wired` extensions.

- [ ] **Step 2: Add the shared serialized-geometry validator**

Implement pure helpers that consume placement centers and connections from the serialized project/runtime documents. Use the normative 92-by-34 node footprint, 12-unit node clearance, 8-unit protected edge corridor, and 4-degree right-angle exclusion. Return sorted diagnostic records for node overlap, proper edge crossing, edge-through-non-endpoint-node, and near-perpendicular shared-node junction.

```js
export function validateCityGeometry(graph) {
  return Object.freeze({
    nodeOverlaps: findNodeOverlaps(graph.placements, 92, 34, 12),
    edgeCrossings: findProperCrossings(graph.connections, graph.placements),
    edgeNodeCollisions: findEdgeNodeCollisions(graph.connections, graph.placements, 92, 34, 8),
    perpendicularJunctions: findNearRightAngleJunctions(graph.connections, graph.placements, 4),
  });
}
```

Test boundary fixtures as well as the approved 37-node graph. Expected result for the approved graph is four empty arrays.

- [ ] **Step 3: Refactor the generator around one normative City contract**

Keep the other 15 retained portfolio projects byte-identical. Replace only the City arrays/schema/content/placements/connections/portals/extensions. Add the required content field definition `party-forge-activation-state`, the six exact effect definitions, and `party-forge-allocated-node` requirement definition from the spec. Author effects on only the six paid implemented nodes and the six charters; City Heart has none.

Use `strict: false` for the City export profile because five district targets intentionally do not exist yet. Tests must assert that unresolved external-target warnings are exactly the expected five targets; all other validation errors/warnings fail.

- [ ] **Step 4: Replace the committed sample pair from one serialization call**

Write the City authoring/runtime pair to a fresh temporary directory, parse both through public format-3 codecs, compare the runtime to `resolveRuntimeV3`, then replace only `samples/party-forge-city.pstree` and `.pstree.json`. Export a second time and require byte identity plus matching SHA-256.

- [ ] **Step 5: Verify the LatticeWright candidate**

```powershell
node --test scripts/party-forge/party-forge-city-v3-contract.test.mjs scripts/party-forge/create-party-forge-portfolio.test.mjs
npx.cmd vitest run tests/party-forge/portfolio.test.ts src/core/project-v3/resolve-runtime.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/validation.test.ts
npm.cmd run typecheck
npm.cmd run lint
git diff --check
```

Expected: all pass; two consecutive City exports are byte-identical; geometry has zero diagnostics; non-City accepted hashes are unchanged.

- [ ] **Step 6: Commit**

```powershell
git add scripts/party-forge tests/party-forge samples/party-forge-city.pstree samples/party-forge-city.pstree.json
git commit -m "feat: redesign Party Forge City runtime v3"
```

Record the exact commit and both sample hashes for Party Forge provenance.

---

### Task 2: Add a strict, versioned Party Forge runtime-adapter boundary

**Files:**
- Add: `scripts/progression/passive_tree/latticewright_runtime_adapter_registry.gd`
- Add: `scripts/progression/passive_tree/latticewright_runtime_portfolio_registry.gd`
- Add: `scripts/progression/passive_tree/latticewright_runtime_header.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_load_result.gd`
- Add: `tests/unit/test_latticewright_runtime_adapter_registry.gd`
- Add: `tests/unit/test_latticewright_runtime_portfolio_registry.gd`
- Modify: `tests/test_runner.gd` only if the runner uses an explicit suite inventory

**Interfaces:**

```gdscript
class_name LatticewrightRuntimeAdapterRegistry
extends RefCounted

const MAX_RUNTIME_JSON_BYTES := 64 * 1024 * 1024

func register_adapter(format_version: int, adapter: Callable) -> bool
func load_path(path: String) -> PassiveTreeLoadResult
func load_document(document: Dictionary, source_path: String, source_sha256: String) -> PassiveTreeLoadResult
```

```gdscript
class_name LatticewrightRuntimePortfolioRegistry
extends RefCounted

func register_runtime(runtime: Dictionary) -> String
func has_graph(project_id: StringName, graph_id: StringName) -> bool
func unregister_runtime(project_id: StringName) -> void
func copy() -> LatticewrightRuntimePortfolioRegistry
```

- [ ] **Step 1: Add red registry and strict-reader tests**

Cover exact 64 MiB acceptance/one-byte-over rejection, malformed UTF-8, BOM, duplicate keys, malformed JSON, non-object root, unexpected/missing root keys, wrong format, nonintegral/unsupported versions, format 4 without adapter, format 3 selection, adapter failure propagation, and proof that no format-1 loader or fallback is invoked.

For the portfolio registry, cover duplicate project rejection, duplicate graph IDs, malformed runtime headers, deep-copy isolation, exact `{projectId, graphId}` lookup, unregister drift, and no filesystem discovery.

Run:

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_latticewright_runtime_adapter_registry.gd res://tests/unit/test_latticewright_runtime_portfolio_registry.gd
```

Expected RED: the versioned adapter and portfolio registries do not exist.

- [ ] **Step 2: Implement header validation and adapter dispatch**

Reuse `StrictJsonDocumentReader` for bytes, UTF-8, duplicate-key, parse, hash, and size authority. `LatticewrightRuntimeHeader` validates only the exact generic runtime-v3 root envelope needed before adapter dispatch; it must not interpret City gameplay content.

```gdscript
var header := LatticewrightRuntimeHeader.validate(document)
if not header.ok():
    return PassiveTreeLoadResult.failure(header.error)
var adapter: Callable = _adapters.get(header.format_version, Callable())
if not adapter.is_valid():
    return PassiveTreeLoadResult.failure(
        "PARTY_FORGE_PASSIVE_TREE_ADAPTER_ERROR format_version=%d reason=adapter unavailable" % header.format_version
    )
return adapter.call(document, source_path, source_sha256)
```

- [ ] **Step 3: Implement the inert portfolio registry**

Store defensive copies of already validated runtime dictionaries. It may answer only whether an exact project and graph are registered. It must not open paths, scan directories, download targets, or treat a portal declaration as proof the target exists.

- [ ] **Step 4: Verify and commit**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_latticewright_runtime_adapter_registry.gd res://tests/unit/test_latticewright_runtime_portfolio_registry.gd res://tests/unit/test_city_access_generated_artifacts.gd res://tests/unit/test_latticewright_runtime_v3_city_access_importer.gd
git diff --check
git add scripts/progression/passive_tree/latticewright_runtime_adapter_registry.gd scripts/progression/passive_tree/latticewright_runtime_portfolio_registry.gd scripts/progression/passive_tree/latticewright_runtime_header.gd scripts/progression/passive_tree/passive_tree_load_result.gd tests/unit/test_latticewright_runtime_adapter_registry.gd tests/unit/test_latticewright_runtime_portfolio_registry.gd tests/test_runner.gd
git commit -m "feat: add LatticeWright passive tree adapter registry"
```

Expected: focused suite prints exactly one `TEST_SUMMARY: PASS (0 failures)` and exits 0.

---

### Task 3: Adapt the exact runtime-v3 City document into the stable Party Forge domain

**Files:**
- Add: `scripts/progression/passive_tree/latticewright_runtime_v3_city_adapter.gd`
- Add: `scripts/progression/passive_tree/passive_tree_portal.gd`
- Add: `scripts/progression/passive_tree/city_tree_geometry_validator.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_definition.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_node.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_catalog.gd`
- Modify: `scripts/progression/passive_tree/city_passive_tree_policy.gd`
- Delete: `scripts/progression/passive_tree/passive_tree_loader.gd`
- Delete: `tests/unit/test_passive_tree_loader.gd`
- Replace: `tests/unit/test_passive_tree_artifact_sync.gd`
- Add: `tests/unit/test_latticewright_runtime_v3_city_adapter.gd`
- Modify: `tests/unit/test_passive_tree_contracts.gd`
- Replace: `data/passive_trees/city/party-forge-city.pstree`
- Replace: `data/passive_trees/city/party-forge-city.pstree.json`

**Stable domain extension:**

```gdscript
class_name PassiveTreePortal
extends RefCounted

var id: StringName
var source_node_id: StringName
var label: String
var role: StringName
var target_project_id: StringName
var target_graph_id: StringName
var discovered_tree_id: StringName
```

`PassiveTreeDefinition` gains a defensively copied `portals` array plus `portal_for_source_node(node_id)`. Each node's existing `metadata` receives exactly `activationState` and source provenance values produced by the adapter; no second ready-node list is added.

- [ ] **Step 1: Add red exact-adapter contract tests**

Build one valid in-memory 37-node fixture from the committed runtime and then mutate one field per case. Cover exact root identity/extensions, exact schema definitions, exact graph identity/count/start, unique content/placement/connection IDs, one-to-one content placement, integral nonnegative costs, finite coordinates, supported placement shapes, exact activation values, effect/requirement instance shapes, two Extraction License requirements, six charter portal/effect pairs, no extra portals/assets, and the four geometry invariants.

Also assert exact projection:

```gdscript
TestAssertions.equal(result.tree.id, &"party-forge-city-v1", "stable domain tree ID", failures)
TestAssertions.equal(result.tree.nodes.size(), 37, "all City nodes project", failures)
TestAssertions.equal(result.tree.connections.size(), 37, "all City connections project", failures)
TestAssertions.equal(result.tree.portals.size(), 6, "only district portals project", failures)
TestAssertions.equal(result.tree.node(&"field-pack").metadata["activationState"], "implemented", "readiness projects", failures)
```

Expected RED: runtime-v3 City adapter and typed portal do not exist.

- [ ] **Step 2: Implement exact schema/effect/requirement projection**

Map LatticeWright definitions to the current domain without executing extensions:

```gdscript
const EFFECT_MAP := {
    "party-forge-feature-unlock": [&"feature_unlock", &"set"],
    "party-forge-inventory-columns-add": [&"inventory_columns", &"add_flat"],
    "party-forge-stash-tabs-add": [&"stash_tabs", &"add_flat"],
    "party-forge-building-discovery": [&"building_discovery", &"set"],
    "party-forge-extraction-capacity-add": [&"extraction_capacity", &"add_flat"],
    "party-forge-tree-discovery": [&"tree_discovery", &"set"],
}
const REQUIREMENT_MAP := {
    "party-forge-allocated-node": [&"allocated_node", &"contains"],
}
```

Reject unknown definitions, missing/extra values, nonintegral numbers for integer domain fields, invalid scopes, invalid stable IDs, and effect/portal/readiness mismatches. Preserve exact source path and SHA-256 in tree metadata for diagnostics.

- [ ] **Step 3: Implement independent Party Forge geometry validation**

Port the same numeric contract rather than sharing JavaScript output. Validate the serialized centers after projection: 92-by-34 boxes, 12 clearance, 8 protected corridor, and shared-junction angle not within 4 degrees of 90. Return stable sorted Party Forge diagnostics.

- [ ] **Step 4: Replace City data and catalog dispatch atomically**

Copy the exact committed LatticeWright City source/runtime bytes, verify both hashes, and register only adapter version 3 in `PassiveTreeCatalog`. Register the loaded raw City runtime with the portfolio registry separately from adapting it. Delete the obsolete format-1 loader route and replace its tests with registry/adapter contracts. There is no conditional fallback.

```gdscript
const CITY_PATH := "res://data/passive_trees/city/party-forge-city.pstree.json"

static func load_defaults(portfolio: LatticewrightRuntimePortfolioRegistry = null) -> PassiveTreeLoadResult:
    var adapters := LatticewrightRuntimeAdapterRegistry.new()
    adapters.register_adapter(3, Callable(LatticewrightRuntimeV3CityAdapter, "translate"))
    var result := adapters.load_path(CITY_PATH)
    if result.ok() and portfolio != null:
        portfolio.register_runtime(result.source_document)
    return result
```

- [ ] **Step 5: Verify and commit**

```powershell
& $partyForgeGodot --headless --editor --path $partyForgeWorktree --import --quit-after 600
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_latticewright_runtime_adapter_registry.gd res://tests/unit/test_latticewright_runtime_v3_city_adapter.gd res://tests/unit/test_passive_tree_artifact_sync.gd res://tests/unit/test_passive_tree_contracts.gd res://tests/unit/test_passive_tree_graph.gd res://tests/unit/test_passive_effect_resolver.gd
git diff --check
```

Expected: import exits 0 without parse/load diagnostics; focused suite has one PASS marker and exit 0; committed Party Forge runtime hash equals the exact LatticeWright runtime hash.

Commit: `feat: load City tree from LatticeWright runtime v3`

---

### Task 4: Make authored activation state and portal health authoritative at view and commit time

**Files:**
- Add: `scripts/progression/passive_tree/passive_tree_activation_policy.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_action_decision.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_progression_service.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_mutation_service.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_snapshot.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_view_model.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_screen.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_node_view_data.gd`
- Modify: `tests/unit/test_passive_tree_progression_service.gd`
- Modify: `tests/unit/test_passive_tree_mutation_service.gd`
- Modify: `tests/unit/test_passive_tree_snapshot.gd`
- Modify: `tests/unit/test_passive_tree_view_model.gd`
- Modify: `tests/unit/test_passive_tree_screen.gd`

**Interface:**

```gdscript
class_name PassiveTreeActivationPolicy
extends RefCounted

func decision(
    tree: PassiveTreeDefinition,
    tree_node: PassiveTreeNode,
    portfolio: LatticewrightRuntimePortfolioRegistry,
) -> PassiveTreeActionDecision
```

Stable decisions:

```gdscript
&"ok"                       # implemented
&"future_node"              # future -> "Coming Soon"
&"district_target_missing"  # portal-gated target absent/invalid
```

- [ ] **Step 1: Add red readiness tests before changing services**

Cover implemented allocation, future rejection without point/profile/timestamp change, portal missing rejection, exact portal present success, wrong project, wrong graph, target unregister between view and commit, existing historical future allocation remains allocated/path-valid, unknown saved ID remains unresolved, and Developer Preview reveals all but cannot persist an otherwise invalid allocation.

Also assert a discovered City displays all 37 nodes regardless of legacy `tree_visibility_progress`; non-City snapshot behavior stays unchanged.

- [ ] **Step 2: Inject one shared activation policy and portfolio registry**

The progression service evaluates activation after identity/already-allocated checks but before requirements, points, and graph reachability. The mutation service calls that same progression service inside `ProfileMutationService.apply`, so readiness is live at commit time.

```gdscript
var activation := _activation.decision(tree, tree_node, _portfolio)
if not activation.ok():
    return _decision(activation.code, false, 0, current, snapshot.implicit_start_nodes)
```

Do not cache a ready-node set in Main, UI, profile, or mutation request.

- [ ] **Step 3: Separate Developer reveal from durable authority**

`PassiveTreeViewModel.build(..., developer_reveal)` may reveal all copy and portal diagnostics. `PassiveTreeScreen` must send Player Mode authority for allocation commits even from Developer Preview:

```gdscript
result = _mutations.allocate(
    profile.profile_id,
    transaction_id,
    _tree_definition,
    node_id,
    false,
    _profile_root,
)
```

Keep the existing bounded developer refund/respec behavior unless a test proves it conflicts with this allocation rule.

- [ ] **Step 4: Project explicit UI states**

Future nodes are visible with `Coming Soon`; a missing charter target adds `District tree not installed`; portal-gated nodes become ordinary allocatable nodes only while the exact target is registered. Existing allocated future nodes display `allocated`, with `Coming Soon` disclosure but no invented effects.

- [ ] **Step 5: Verify and commit**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_passive_tree_snapshot.gd res://tests/unit/test_passive_tree_progression_service.gd res://tests/unit/test_passive_tree_mutation_service.gd res://tests/unit/test_passive_tree_view_model.gd res://tests/unit/test_passive_tree_screen.gd
git diff --check
```

Expected: one PASS marker, exit 0, no mutation on every denied path.

Commit: `feat: enforce City node activation readiness`

---

### Task 5: Award City discovery/free root on the first victory and one point on each later unique victory

**Files:**
- Add: `scripts/progression/passive_tree/city_victory_reward_policy.gd`
- Modify: `scripts/extraction/run_resolution_service.gd`
- Modify: `scripts/profile/profile_mutation_service.gd`
- Modify: `tests/unit/test_run_resolution_service.gd`
- Modify: `tests/unit/test_profile_mutation_service.gd`
- Modify: `tests/unit/test_run_terminal_flow.gd`
- Modify: `tests/integration/terminal_extraction_flow_runner.gd`
- Modify: `tests/integration/run_recovery_profile_lifecycle_runner.gd`

**Pure candidate mutation:**

```gdscript
class_name CityVictoryRewardPolicy
extends RefCounted

const CITY_TREE_ID := "party-forge-city-v1"
const CITY_ROOT_ID := "city-heart"

static func apply(candidate: ProfileState, outcome: RunTerminalSnapshot.Outcome) -> String:
    if outcome != RunTerminalSnapshot.Outcome.VICTORY:
        return ""
    # Validate overflow and existing allocation shape before changing candidate.
    # Add discovery/root canonically; increment available/lifetime only if City was already discovered.
    return ""
```

- [ ] **Step 1: Add red victory-settlement tests**

Cover point-free first victory, later unique victory, same-transaction duplicate, recovery replay/restart, defeat, City-already-discovered, discovered-but-root-missing repair, duplicate root canonicalization, malformed allocation rejection, subsequent-victory point overflow, evaluator failure, terminal-mark failure, and store-save failure. Assert extraction/discovery/root/points/terminal stage commit together or not at all.

Expected RED: terminal resolution currently changes no City/point fields.

- [ ] **Step 2: Implement the pure policy**

Validate first; mutate second. Capture whether City was already discovered before canonical discovery/root repair. Do not read `run_history`, add a victory ledger, change `prologue_state`, grant a point on the first victory, or grant more than one point on a later victory. Canonicalize only the City allocation array required by this transaction and preserve unknown IDs.

- [ ] **Step 3: Call it inside the existing terminal mutation**

After the recovery record/source/transaction checks and successful extraction evaluation, but before `mark_resolved_candidate`, apply the reward using `record.snapshot.outcome`:

```gdscript
var reward_error := CityVictoryRewardPolicy.apply(candidate, record.snapshot.outcome)
if not reward_error.is_empty():
    return reward_error
return terminal_recovery.mark_resolved_candidate(candidate, request, evaluation.extraction)
```

The outer `apply_with_resumable_run_revocation` transaction remains the only idempotency and save boundary.

- [ ] **Step 4: Remove City rewards from obsolete prologue completion**

`ProfileMutationService.complete_prologue` may still set the legacy prologue state for existing flows, but it must no longer grant a point, discover City, or seed City Heart. Update its tests to prove those fields stay unchanged.

- [ ] **Step 5: Verify and commit**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_profile_mutation_service.gd res://tests/unit/test_run_resolution_service.gd res://tests/unit/test_run_terminal_flow.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/terminal_extraction_flow_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
git diff --check
```

Expected: focused PASS; each integration prints its exact PASS marker once and exits 0; duplicate/recovery paths keep the first victory point-free and retain exactly one point per subsequent unique run.

Commit: `feat: grant City progression on committed victories`

---

### Task 6: Wire Player Mode routing and the seven live allocation/effect paths

**Files:**
- Modify: `scripts/game/main.gd`
- Modify: `scripts/ui/main_menu/main_menu_view_model.gd`
- Modify: `scripts/ui/warehouse/warehouse_locked_dialog.gd`
- Modify: `scripts/progression/passive_tree/city_passive_tree_policy.gd`
- Modify: `tests/support/profile_test_support.gd`
- Modify: `tests/unit/test_main_menu_view_model.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_passive_effect_resolver.gd`
- Modify: `tests/unit/test_profile_storage_reconciler.gd`
- Modify: `tests/integration/passive_tree_profile_runner.gd`
- Modify: `tests/integration/passive_tree_input_runner.gd`
- Modify: `tests/integration/passive_tree_responsive_runner.gd`
- Modify: `tests/integration/main_menu_navigation_runner.gd`
- Modify: `tests/integration/main_menu_responsive_runner.gd`
- Modify: `tests/integration/warehouse_locked_dialog_focus_runner.gd`

- [ ] **Step 1: Add red routing and live-path tests**

Assert Player Mode City is hidden before discovery and visible/enabled after a committed first victory regardless of prologue state. Assert route denial checks profile plus City discovery only. Replace player copy with first-victory guidance.

Exercise the exact immediate route:

```text
City Heart
|- Equipment Registry -> Field Pack ---------|
`- Stash Access ------------------------------+-> Extraction License
                                                   -> Secured Loadout
                                                   -> Leader Loadout Extraction
```

Verify each allocation costs exactly one point, both Extraction License prerequisites are required, storage reconciliation is atomic, and effects project exactly:

```gdscript
{
    "equipment-registry": ["equipment_inventory"],
    "field-pack": ["inventory", "inventory_columns:+1"],
    "stash-access": ["stash", "stash_tabs:+1x100", "building:warehouse"],
    "extraction-license": ["item_extraction", "extraction_capacity:+1"],
    "secured-loadout": ["bring_in_gear"],
    "leader-loadout-extraction": ["leader_loadout_extraction"],
}
```

- [ ] **Step 2: Wire Main through the adapter and shared registry**

Construct one `LatticewrightRuntimePortfolioRegistry`, pass it to the catalog, progression service, mutation service, and view model. Do not register district targets that are not actually loaded. `_city_runtime_available` validates the projected domain identity and service availability.

- [ ] **Step 3: Remove the City prologue gate and stale copy**

`MainMenuViewModel` uses `CITY_TREE_ID in profile.discovered_trees` for durable City visibility. `main.gd::_city_route_denial` does the same for Player Mode. Rename Warehouse guidance from `PROLOGUE_REQUIRED` to `FIRST_VICTORY_REQUIRED` and use copy equivalent to: `Win a run to reveal the City tree. Then unlock Stash Access to open the Warehouse.`

Do not redesign the separate primary Play/prologue routes in this milestone.

- [ ] **Step 4: Preserve profile compatibility in production projections**

Tests must prove known old allocations remain allocated, future allocations remain connected/path-valid, unknown IDs remain unresolved, Stash Access no longer discovers Warehouse tree, pre-existing Warehouse discovery remains, and no load/open operation mutates profile bytes.

- [ ] **Step 5: Verify and commit**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_main_menu_view_model.gd res://tests/unit/test_main_wiring.gd res://tests/unit/test_passive_effect_resolver.gd res://tests/unit/test_profile_storage_reconciler.gd res://tests/unit/test_passive_tree_progression_service.gd res://tests/unit/test_passive_tree_mutation_service.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_profile_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_input_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_responsive_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/main_menu_navigation_runner.gd
git diff --check
```

Expected: all markers appear once, exits are 0, Player Mode can purchase all six paid implemented nodes, no future/charter purchase persists.

Commit: `feat: enable live City tree progression paths`

---

### Task 7: Gate every production item drop before chance or generation work

**Files:**
- Add: `scripts/loot/player_item_drop_access_policy.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scripts/loot/personal_loot_roll_service.gd`
- Modify: `scripts/loot/personal_loot_drop_coordinator.gd`
- Modify: `scripts/loot/personal_loot_decision.gd`
- Modify: `tests/unit/test_personal_loot_roll_service.gd`
- Modify: `tests/unit/test_personal_loot_drop_coordinator.gd`
- Modify: `tests/integration/personal_loot_defeat_runner.gd`
- Modify: `tests/integration/developer_loot_lab_runner.gd`
- Modify: `tests/integration/live_loot_lifecycle_runner.gd`

**Central policy:**

```gdscript
class_name PlayerItemDropAccessPolicy
extends RefCounted

static func allows(
    profile: ProfileState,
    run_inventory: ItemSlotContainer,
    feature_policy: FeatureAccessPolicy,
) -> bool:
    return (
        feature_policy.resolve(&"equipment_inventory", FeatureAccessPolicy.State.AVAILABLE, &"equipment_inventory") == FeatureAccessPolicy.State.AVAILABLE
        and feature_policy.resolve(&"inventory", FeatureAccessPolicy.State.AVAILABLE, &"inventory") == FeatureAccessPolicy.State.AVAILABLE
        and run_inventory != null
        and run_inventory.capacity > 0
    )
```

- [ ] **Step 1: Add the red eligibility matrix**

Test all eight combinations of `equipment_inventory`, `inventory`, and positive capacity. Only all three passes. For each denied case assert stable `feature_locked`, `eligible == false`, `success == false`, and zero/default `basis_points`, `roll_basis_points`, `generation_seed`, `generation_sequence`, and `item_level`.

At coordinator/integration level assert no item instance, personal container, ground registry record, spawned drop ID, or chest. Confirm XP/gold/passive-point paths are unchanged.

- [ ] **Step 2: Move access evaluation before random/chance/generation derivation**

In `_resolve_context`, copy only identity/event facts first, then call the shared access provider. Return immediately on `feature_locked`. Compute effective source, basis points, deterministic roll, generation seed, sequence, and item level only after access passes; then evaluate leader availability/range.

- [ ] **Step 3: Make Main use the centralized policy**

Replace `_personal_loot_access_for`'s one-feature check with `PlayerItemDropAccessPolicy`. Continue to obtain the live owner-scoped run inventory from the context and the existing run rules' feature policy.

- [ ] **Step 4: Preserve bounded Developer Unlock All**

Test Developer Mode with Unlock All and temporary minimum capacity. It may produce a test drop, but profile reload must show neither permanent unlock added and no durable inventory column. Ordinary Player Mode inconsistent profiles fail closed with diagnostics.

- [ ] **Step 5: Verify and commit**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_personal_loot_roll_service.gd res://tests/unit/test_personal_loot_drop_coordinator.gd res://tests/unit/test_passive_tree_mutation_service.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/personal_loot_defeat_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/developer_loot_lab_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/live_loot_lifecycle_runner.gd
git diff --check
```

Expected: all markers once, exits 0, no pre-access random/generation facts, no Player Mode item objects before Field Pack.

Commit: `fix: gate item drops on Player inventory access`

---

### Task 8: Add end-to-end City v3 acceptance and remote visual evidence

**Files:**
- Add: `tests/integration/latticewright_city_v3_runner.gd`
- Add: `tests/integration/city_victory_progression_runner.gd`
- Add: `tests/integration/city_item_drop_gate_runner.gd`
- Add: `tests/integration/city_tree_v3_visual_runner.gd`
- Modify: `tests/integration/passive_tree_profile_runner.gd`
- Modify: `tests/integration/passive_tree_input_runner.gd`
- Modify: `tests/integration/passive_tree_responsive_runner.gd`
- Modify: `tests/test_runner.gd` only if explicit suite registration is required
- Do not commit generated screenshots or user-data evidence

- [ ] **Step 1: Write red end-to-end acceptance runners**

`latticewright_city_v3_runner.gd` reads the committed runtime through production catalog/adapter wiring and asserts exact identity, source hash, counts, portals, geometry, states, effects, and no fallback.

`city_victory_progression_runner.gd` creates a clean profile, wins through the real terminal flow, reloads, verifies discovery/root/one point, resolves a second unique victory for a second point, and replays both without duplication. It verifies defeat grants none.

`city_item_drop_gate_runner.gd` proves no ground item/chest before Field Pack, allocates Equipment Registry then Field Pack through production mutation, starts a fresh run context, and proves ordinary drops can then follow normal chance rules.

- [ ] **Step 2: Add the exact visual runner**

Open the real City screen with a discovered profile and the production 37-node tree. Capture at the supported desktop viewport with all 37 nodes and six district labels visible. The runner also reasserts serialized geometry before capture and prints:

```text
CITY_TREE_V3_VISUAL_SUMMARY: PASS
```

The runner prints the absolute path with:

```gdscript
print("CITY_TREE_V3_VISUAL_PATH: %s" % ProjectSettings.globalize_path("user://tests/city-tree-v3-visual.png"))
```

- [ ] **Step 3: Run LatticeWright save/reopen/export visual acceptance**

Open the exact authoring file in LatticeWright, save without semantic changes, close/reopen, export runtime again, and compare the export hash to the committed sample. Capture the full graph at a legible zoom. Run the JavaScript geometry validator against the reopened source and export.

- [ ] **Step 4: Run Party Forge editor-backed visual acceptance**

Use the connected Godot AI session for focused editor/run checks. Use the visual runner for deterministic capture. Copy both final PNGs into the current task's visualization directory and show them inline to Jacob. Do not treat an editor-only view or local file link as remote approval.

- [ ] **Step 5: Run the acceptance runners**

```powershell
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/latticewright_city_v3_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_victory_progression_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_item_drop_gate_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
```

Expected: each exact summary marker appears once, every exit is 0, and both screenshots visibly match the approved radial layout. Stop for visual/product choice if Jacob rejects either view.

- [ ] **Step 6: Commit tests after visual approval**

Commit: `test: qualify City tree v3 milestone 1`

---

### Task 9: Sequential review, full qualification, containment, and authorized publication

**Files:**
- Review all committed Task 1-8 diffs in both repositories
- No production changes unless a review finding is returned to the owning task and reverified
- Evidence is written outside registered repositories/worktrees

- [ ] **Step 1: Freeze exact candidates**

Record each repository's commit, parents, branch, status, diff-check, worktree fingerprint, sample/runtime hashes, and Party Forge UID manifests. Confirm no test or editor process is still writing.

- [ ] **Step 2: Perform the requirements review first**

The authorized Sol-high reviewer creates a 15-row trace against every acceptance criterion in the approved spec. For each row cite exact production file/line, test, command, PASS marker, and evidence hash. Explicitly scan for excluded work, format-1 fallback, stale 31-node counts, obsolete 15 portals, stale prologue copy, a second readiness list, and any item-generation call reachable before access.

If any criterion lacks direct evidence, return to its owning task. Do not begin code-quality review until all 15 rows pass.

- [ ] **Step 3: Perform the code-quality review second**

After requirements pass, the same Sol-high reviewer examines the same immutable commits for defensive copies, exact-key validation, overflow, error atomicity, duplicate/replay behavior, dependency ownership, mutation-time revalidation, nonpersistent developer behavior, geometry numerical boundaries, test isolation, and absence of test-only production APIs. The Luna-max implementer resolves findings through red tests and new commits, then the Sol-high reviewer repeats requirements review before repeating code-quality review.

- [ ] **Step 4: Run full LatticeWright qualification**

```powershell
npm.cmd test
npm.cmd run typecheck
npm.cmd run lint
npm.cmd run integration:godot
git diff --check
```

Expected: all commands exit 0. Record exact suite counts and hashes from the candidate; do not reuse older 2,792-test evidence.

- [ ] **Step 5: Run focused and owning Party Forge gates from a cold exact-commit archive**

Use isolated `APPDATA` and `LOCALAPPDATA`, cold import first, then the union of all changed owning unit files through `focused_test_runner.gd`. Run these owning integrations at minimum:

```text
latticewright_city_v3_runner.gd
city_victory_progression_runner.gd
city_item_drop_gate_runner.gd
city_tree_v3_visual_runner.gd
passive_tree_profile_runner.gd
passive_tree_input_runner.gd
passive_tree_responsive_runner.gd
terminal_extraction_flow_runner.gd
run_recovery_profile_lifecycle_runner.gd
personal_loot_defeat_runner.gd
developer_loot_lab_runner.gd
live_loot_lifecycle_runner.gd
item_storage_profile_runner.gd
main_menu_navigation_runner.gd
main_menu_responsive_runner.gd
warehouse_locked_dialog_focus_runner.gd
```

Require exact PASS markers once, exit 0, and zero `TEST_FAILURE`, failing summary, script/parse/load errors, segmentation, ObjectDB leaks, RID leaks, or certificate-load diagnostics.

- [ ] **Step 6: Run the complete Party Forge suite**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 7200 --script res://tests/test_runner.gd
```

Expected: exactly one current-candidate `TEST_SUMMARY: PASS` line containing the runner's emitted integer suite count, exit 0, and zero forbidden diagnostics. Record that emitted count; do not reuse the earlier 265-suite count as current evidence.

- [ ] **Step 7: Recheck containment**

Compare authoritative repository/worktree registrations, tracked/index status, UID paths/bytes/hashes, and surviving Godot/LatticeWright processes to baseline. Confirm authoritative Party Forge still has exactly the original 68 untracked UID sidecars and nothing else before integration. Confirm no art-lane path changed in either candidate.

- [ ] **Step 8: Integrate LatticeWright conflict-safely**

Fetch normally. Verify local main, tracking ref, and live remote have not drifted from the reviewed base. Merge the exact reviewed LatticeWright candidate into `main` with a normal merge. Stop on any conflict or unexpected diff. Re-run the focused sample/contract tests plus typecheck/lint/diff-check on the merge commit, then normal-push `main` and verify local/tracking/live heads match.

- [ ] **Step 9: Integrate Party Forge conflict-safely**

Only after LatticeWright publication is verified, fetch Party Forge normally and repeat the exact base/remote/UID checks. Merge the exact reviewed Party Forge candidate into `main` with a normal merge. Stop on conflict or unexpected scope. Re-run cold import, focused suite, owning integrations, full suite, diff-check, and UID containment on the exact merge commit. Normal-push `main` and verify local/tracking/live heads match with the same 68 UID manifest.

- [ ] **Step 10: Final report**

Report exact commits and parents, runtime/source SHA-256 values, suite counts, every integration marker, requirements/code-quality review verdicts, visual evidence paths rendered inline, containment hashes, publication output, remote-head verification, and the intentionally inactive Milestone 2-5 nodes/charters. Do not claim those later milestones implemented.
