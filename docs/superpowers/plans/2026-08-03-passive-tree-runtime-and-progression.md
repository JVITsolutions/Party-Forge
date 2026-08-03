# Party Forge Passive-Tree Runtime and Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the revised creator-authored City tree into Party Forge, provide strict profile-owned allocation/fog/refund/effect services and a reusable Developer Mode tree screen, and restore left-stick leader movement.

**Architecture:** The Passive Skill Tree Creator remains authoritative for the editable project and deterministic runtime export. Party Forge copies those inert artifacts, validates them into typed immutable domain records, computes progression through pure services, and persists allocation/refund operations through the existing idempotent profile mutation boundary. A blockout UI consumes view data and never edits profile dictionaries or interprets effects.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot `Control`/`CanvasLayer`, JSON, the existing Party Forge custom test runner, Electron/React/TypeScript/Vitest in the Passive Skill Tree Creator, Git worktrees, PowerShell.

## Global Constraints

- Work only in isolated worktrees. Do not write to Party Forge's dirty live `main` checkout or to the Passive Skill Tree Creator's normal checkout.
- Recheck both repositories and active worktrees before Task 1 and before each merge. Preserve all unrelated user/editor changes.
- Party Forge authoritative repository: `F:\Projects(root)\Game dev\Projects\party-forge`.
- Passive Skill Tree Creator authoritative repository: `E:\Projects\Passive Skill Tree Creator`.
- Party Forge baseline for this plan: commit `e27323f`; the plan/design branch begins at `ee1531b`.
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.
- Use a task-specific `APPDATA` under the active worktree for every Godot import, runner, and manual test. Never use the user's live profile/settings directory for automation.
- Snapshot untracked files before Godot runs. Remove only newly generated `.import` and `.uid` sidecars after verification.
- The creator is the source of truth for topology, positions, labels, costs, effects, requirements, connections, and metadata. Do not hand-edit only the Party Forge copy.
- The editable `.pstree`, creator runtime export, creator Godot-demo copy, and Party Forge runtime copy must remain deterministic and semantically equal as specified by their tests.
- Retain `treeId = party-forge-city-v1`, `formatVersion = 1`, and `city-heart` as the starting node.
- Retain the ProfileState schema. `tree_allocations` remains `tree_id -> node ID array`; `tree_visibility_progress` remains `tree_id -> non-negative integer`.
- All Passive Points are profile-owned and shared across trees.
- Unknown effects, requirements, active parameter shapes, or malformed trees fail closed. Future contracts are valid only when explicitly registered.
- Unknown saved node IDs are preserved as unresolved; never silently delete, refund, rename, or reassign them.
- Inventory, stash, extraction, equipment, building, tree, mode, region, and other data-bearing unlock nodes are permanent.
- Final assets, the functional main menu, the cinematic prologue, actual inventory/stash/extraction services, split-screen routing, and final respec economy are outside this plan.
- The blockout UI must support 1920x1080, 2560x1440, and 3840x2160.
- Existing arena, profiles, settings, ledger, upgrades, popup pinning, combat, presentation, and controller behavior must remain functional.

Before any Party Forge command block, define the executable exactly:

```powershell
$godot='F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
```

---

## Repository and File Map

### Passive Skill Tree Creator

- `samples/party-forge-city.pstree`: editable creator-owned City tree.
- `samples/party-forge-city.pstree.json`: canonical deterministic runtime export.
- `integrations/godot/demo/party-forge-city.pstree.json`: byte-identical demo copy.
- `src/core/serialization/party-forge-city-fixture.test.ts`: exact 30-node semantic contract and deterministic-export test.
- `docs/superpowers/specs/2026-07-31-party-forge-city-test-tree-design.md`: updated pre-production fixture contract rationale.
- `samples/README.md`: updated player/profile ownership and logistics notes.

### Party Forge domain

- `data/passive_trees/city/party-forge-city.pstree`: committed editable source copy.
- `data/passive_trees/city/party-forge-city.pstree.json`: committed runtime copy.
- `scripts/progression/passive_tree/passive_tree_effect.gd`: typed effect record.
- `scripts/progression/passive_tree/passive_tree_requirement.gd`: typed requirement record.
- `scripts/progression/passive_tree/passive_tree_node.gd`: typed node record.
- `scripts/progression/passive_tree/passive_tree_connection.gd`: typed connection record.
- `scripts/progression/passive_tree/passive_tree_definition.gd`: immutable tree aggregate and lookups.
- `scripts/progression/passive_tree/passive_tree_load_result.gd`: complete tree-or-errors result.
- `scripts/progression/passive_tree/passive_tree_loader.gd`: strict JSON and topology loader.
- `scripts/progression/passive_tree/passive_effect_registry.gd`: active/future effect contracts, profile unlock projection, and FeatureAccessPolicy IDs.
- `scripts/progression/passive_tree/passive_requirement_registry.gd`: typed requirement contracts.
- `scripts/progression/passive_tree/city_passive_tree_policy.gd`: exact City/logistics invariants.
- `scripts/progression/passive_tree/passive_tree_catalog.gd`: load-defaults boundary for creator-authored trees.
- `scripts/progression/passive_tree/passive_tree_graph.gd`: directed allocation and undirected visibility graph operations.
- `scripts/progression/passive_tree/passive_tree_snapshot.gd`: reconciled allocations, unresolved IDs, visibility, and effective values.
- `scripts/progression/passive_tree/passive_tree_action_decision.gd`: stable allocation/refund result codes and next-state projection.
- `scripts/progression/passive_tree/passive_tree_progression_service.gd`: pure visibility/allocation/refund decisions.
- `scripts/progression/passive_tree/passive_effect_resolution.gd`: immutable grouped effect projection.
- `scripts/progression/passive_tree/passive_effect_resolver.gd`: resolve allocated effects by typed contract and scope.
- `scripts/progression/passive_tree/passive_tree_mutation_service.gd`: idempotent allocate/refund persistence adapter.

### Party Forge UI

- `scripts/ui/passive_tree/passive_tree_node_view_data.gd`: immutable per-node presentation data.
- `scripts/ui/passive_tree/passive_tree_view_model.gd`: domain-to-screen projection.
- `scripts/ui/passive_tree/passive_tree_node_control.gd`: blockout node rendering and pointer/focus behavior.
- `scripts/ui/passive_tree/passive_tree_canvas.gd`: connections, pan/zoom, spatial selection, and connected navigation.
- `scripts/ui/passive_tree/passive_tree_screen.gd`: lifecycle, confirmation, mutation, pause lease, status, and focus restoration.
- `scenes/ui/passive_tree/passive_tree_node_control.tscn`: reusable blockout node control.
- `scenes/ui/passive_tree/passive_tree_screen.tscn`: full-screen reusable tree surface.
- `scripts/ui/settings/additional_settings_page.gd`: Developer Mode tree-request signal and button availability.
- `scripts/ui/settings/settings_screen.gd`: forwards the request and reopens Additional Settings after tree close.
- `scenes/ui/settings/additional_settings_page.tscn`: `Open City Passive Tree` button.
- `scenes/game/main.tscn`: tree screen instance.
- `scripts/game/main.gd`: loads/configures the catalog and composes settings/profile/tree services.
- `project.godot`: movement and passive-tree input actions.

---

### Task 1: Restore Left-Stick Leader Movement

**Files:**
- Modify: `project.godot`
- Modify: `tests/unit/test_controls_settings_page.gd`
- Create: `tests/unit/test_controller_movement_bindings.gd`

**Interfaces:**
- Consumes: `Leader._physics_process()` and its existing `Input.get_vector("move_left", "move_right", "move_forward", "move_back")` call.
- Produces: `move_left/right/forward/back` actions with left-stick axis events and unchanged keyboard bindings/deadzone.

- [ ] **Step 1: Write the failing action-map regression test**

Create `tests/unit/test_controller_movement_bindings.gd` with a `run() -> Array[String]` suite. For each action, assert exactly one matching `InputEventJoypadMotion`:

```gdscript
extends RefCounted

const EXPECTED := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}

func run() -> Array[String]:
	var failures: Array[String] = []
	for action_id: StringName in EXPECTED:
		var expected: Array = EXPECTED[action_id]
		var matching := InputMap.action_get_events(action_id).filter(func(event: InputEvent) -> bool:
			return event is InputEventJoypadMotion \
				and (event as InputEventJoypadMotion).axis == expected[0] \
				and is_equal_approx((event as InputEventJoypadMotion).axis_value, expected[1])
		)
		TestAssertions.equal(matching.size(), 1, "%s has its left-stick direction" % action_id, failures)
		TestAssertions.near(InputMap.action_get_deadzone(action_id), 0.2, 0.001, "%s retains movement deadzone" % action_id, failures)
	return failures
```

In `test_controls_settings_page.gd`, replace the old assertions that `move_left` has a missing controller binding with assertions that all four movement rows report a controller axis and `missing_binding == false`.

- [ ] **Step 2: Run the suite to verify RED**

Run:

```powershell
$env:APPDATA=(Join-Path (Get-Location) '.superpowers\sdd\task-1-controller-red-appdata')
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_controller_movement_bindings.gd res://tests/unit/test_controls_settings_page.gd
```

Expected: nonzero exit; failures name the four missing left-stick directions and the obsolete `Missing binding` expectation.

- [ ] **Step 3: Add the four axis events to the existing movement actions**

In `project.godot`, append these `InputEventJoypadMotion` values while preserving the W/A/S/D events and `deadzone = 0.2`:

```text
move_left    -> axis JOY_AXIS_LEFT_X (0), axis_value -1.0
move_right   -> axis JOY_AXIS_LEFT_X (0), axis_value  1.0
move_forward -> axis JOY_AXIS_LEFT_Y (1), axis_value -1.0
move_back    -> axis JOY_AXIS_LEFT_Y (1), axis_value  1.0
```

Use controller device `0`, matching the existing first-player controller bindings. Do not change `scripts/characters/leader.gd`.

- [ ] **Step 4: Run GREEN and the complete Party Forge suite**

Run the focused command again, then:

```powershell
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: focused exit 0; complete suite exits 0 with `TEST_SUMMARY: PASS` and no `SCRIPT ERROR` or `TEST_FAILURE`.

- [ ] **Step 5: Commit Task 1**

```powershell
git add -- project.godot tests/unit/test_controller_movement_bindings.gd tests/unit/test_controls_settings_page.gd
git commit -m "fix: add controller leader movement"
```

---

### Task 2: Revise the City Tree Through the Passive Skill Tree Creator

**Repository:** `E:\Projects\Passive Skill Tree Creator`

**Files:**
- Modify: `samples/party-forge-city.pstree`
- Modify: `samples/party-forge-city.pstree.json`
- Modify: `integrations/godot/demo/party-forge-city.pstree.json`
- Modify: `src/core/serialization/party-forge-city-fixture.test.ts`
- Modify: `docs/superpowers/specs/2026-07-31-party-forge-city-test-tree-design.md`
- Modify: `samples/README.md`

**Interfaces:**
- Consumes: `parseProjectText(text)`, `stringifyRuntime(project)`, production creator UI Save/Export, and the version-1 runtime schema.
- Produces: `party-forge-city-v1` with exactly 30 nodes, 30 connections, explicit logistics requirements/effects, and byte-identical canonical/demo exports.

- [ ] **Step 1: Create an isolated creator worktree**

Recheck active creator work first. From the creator normal checkout, create an ignored worktree without disturbing `main`:

```powershell
git worktree add .worktrees/party-forge-city-logistics -b feat/party-forge-city-logistics
```

Run `npx.cmd vitest run src/core/serialization/party-forge-city-fixture.test.ts`, `npm.cmd run typecheck`, and `npm.cmd run lint`. Expected: all exit 0 before edits.

- [ ] **Step 2: Update the golden contract test first**

Extend `allowedEffectIds` with:

```ts
"building_discovery",
"extraction_capacity",
"inventory_columns",
"stash_tabs",
"tree_discovery"
```

Change expected counts to 30 nodes and 30 connections. Replace `shared-stash` with `stash-access`, then add these exact node contracts:

```ts
["field-pack", "small", [300, -30], "profile-logistics", [
  effect("feature_unlock", "set", true, { featureId: "inventory" }),
  effect("inventory_columns", "add_flat", 1, { scope: "profile" })
]],
["extraction-license", "large", [-180, 270], "profile-logistics", [
  effect("feature_unlock", "set", true, { featureId: "item_extraction" }),
  effect("extraction_capacity", "add_flat", 1, { scope: "profile" })
]],
["secured-loadout", "large", [-360, 540], "profile-logistics", [
  effect("feature_unlock", "set", true, { featureId: "bring_in_gear" })
]]
```

Set `stash-access` at `[-360, 180]` with:

```ts
[
  effect("feature_unlock", "set", true, { featureId: "stash" }),
  effect("stash_tabs", "add_flat", 1, { scope: "profile", slotsPerTab: 100 }),
  effect("building_discovery", "set", true, { buildingId: "warehouse" }),
  effect("tree_discovery", "set", true, { treeId: "party-forge-warehouse-v1" })
]
```

Give `extraction-license` these exact requirements:

```ts
[
  { requirementId: "allocated_node", operator: "contains", value: "field-pack", parameters: { treeId: "party-forge-city-v1" } },
  { requirementId: "allocated_node", operator: "contains", value: "stash-access", parameters: { treeId: "party-forge-city-v1" } }
]
```

Add connections `city-edge-27` through `city-edge-30` exactly as approved in the focused design. Update `city-edge-20` through `city-edge-22` to reference `stash-access`.

Set logistics node metadata to:

```ts
{
  district: "profile-logistics",
  integrationStatus: "future-contract",
  integrationTarget: "party-forge",
  developmentState: "coming-soon",
  refundPolicy: "permanent"
}
```

Update `expectedProjectedNodeContracts` so it preserves authored requirement arrays and accepts the explicit logistics metadata instead of forcing one metadata object for every node.

- [ ] **Step 3: Run the creator fixture test to verify RED**

```powershell
npx.cmd vitest run src/core/serialization/party-forge-city-fixture.test.ts
```

Expected: failure names the old 27/26 fixture, missing logistics nodes/effects, and `shared-stash` mismatch.

- [ ] **Step 4: Author the revision in the Creator application**

Open `samples/party-forge-city.pstree` in the Passive Skill Tree Creator. Rename/re-ID Stash Access, author the three nodes, effects, requirements, metadata, and four connections exactly as above. Use Save for the `.pstree` source and Export for the runtime JSON. Copy the exported runtime text byte-for-byte to `integrations/godot/demo/party-forge-city.pstree.json`.

Do not edit only the runtime JSON. The `.pstree` source must round-trip through `parseProjectText` and reproduce the runtime file through `stringifyRuntime`.

- [ ] **Step 5: Update creator documentation**

Change the older 27-node references to the reviewed 30-node pre-production contract. Explain that this is the approved pre-runtime integration revision of v1; once Party Forge ships profiles with allocations, semantic node-ID changes require an explicit migration or new tree ID.

Document profile-owned Stash Access, Field Pack, Extraction License, Secured Loadout, and the fact that building-specific capacity lives outside the City tree.

- [ ] **Step 6: Run creator GREEN gates**

```powershell
npx.cmd vitest run src/core/serialization/party-forge-city-fixture.test.ts src/core/serialization/godot-contract.test.ts
npm.cmd run typecheck
npm.cmd run lint
npm.cmd test
```

Expected: all exit 0. `Get-FileHash` must show identical SHA-256 values for the canonical runtime and demo runtime copies.

- [ ] **Step 7: Commit Task 2 in the creator worktree**

```powershell
git add -- samples/party-forge-city.pstree samples/party-forge-city.pstree.json integrations/godot/demo/party-forge-city.pstree.json src/core/serialization/party-forge-city-fixture.test.ts docs/superpowers/specs/2026-07-31-party-forge-city-test-tree-design.md samples/README.md
git commit -m "feat: expand Party Forge city logistics tree"
```

Record the creator commit SHA in the Party Forge verification document in Task 13.

---

### Task 3: Import and Pin the Creator Artifacts in Party Forge

**Files:**
- Create: `data/passive_trees/city/party-forge-city.pstree`
- Create: `data/passive_trees/city/party-forge-city.pstree.json`
- Create: `tests/unit/test_passive_tree_artifact_sync.gd`

**Interfaces:**
- Consumes: committed creator artifacts from Task 2.
- Produces: Party Forge-owned inert source/runtime copies whose embedded tree content is semantically identical and whose runtime copy is byte-identical to the creator canonical runtime.

- [ ] **Step 1: Write the missing-artifact test**

Create `tests/unit/test_passive_tree_artifact_sync.gd`. Read both files with `FileAccess.get_file_as_string`, parse with `JSON.parse_string`, and assert:

```gdscript
const SOURCE := "res://data/passive_trees/city/party-forge-city.pstree"
const RUNTIME := "res://data/passive_trees/city/party-forge-city.pstree.json"

TestAssertions.truthy(FileAccess.file_exists(SOURCE), "editable City source is committed", failures)
TestAssertions.truthy(FileAccess.file_exists(RUNTIME), "runtime City export is committed", failures)
TestAssertions.equal(source_document.get("projectFormat"), "passive-tree-project", "source format", failures)
TestAssertions.equal(runtime_document.get("format"), "passive-skill-tree", "runtime format", failures)
TestAssertions.equal(source_document.get("tree"), runtime_document, "source tree matches runtime export semantically", failures)
TestAssertions.equal((runtime_document.get("nodes") as Array).size(), 30, "City node count", failures)
TestAssertions.equal((runtime_document.get("connections") as Array).size(), 30, "City connection count", failures)
```

- [ ] **Step 2: Run RED**

Run the focused runner for `test_passive_tree_artifact_sync.gd`. Expected: nonzero exit with both artifact paths missing.

- [ ] **Step 3: Copy the exact committed artifacts**

Copy from the creator feature worktree:

```powershell
New-Item -ItemType Directory -Force -Path 'data\passive_trees\city'
Copy-Item -LiteralPath 'E:\Projects\Passive Skill Tree Creator\.worktrees\party-forge-city-logistics\samples\party-forge-city.pstree' -Destination 'data\passive_trees\city\party-forge-city.pstree'
Copy-Item -LiteralPath 'E:\Projects\Passive Skill Tree Creator\.worktrees\party-forge-city-logistics\samples\party-forge-city.pstree.json' -Destination 'data\passive_trees\city\party-forge-city.pstree.json'
```

Before copying, require `git -C 'E:\Projects\Passive Skill Tree Creator\.worktrees\party-forge-city-logistics' status --porcelain` to be empty and record its exact HEAD SHA.

- [ ] **Step 4: Verify GREEN and cross-repository identity**

Run the focused test. Then use `Get-FileHash -Algorithm SHA256` and require the creator canonical runtime and Party Forge runtime hashes to match. Parse both JSON files and require deep semantic equality between creator source `.tree`, creator runtime, and Party Forge runtime.

- [ ] **Step 5: Commit Task 3**

```powershell
git add -- data/passive_trees/city tests/unit/test_passive_tree_artifact_sync.gd
git commit -m "feat: import creator authored city tree"
```

---

### Task 4: Add Typed Tree Records and Strict Structural Loading

**Files:**
- Create: `scripts/progression/passive_tree/passive_tree_effect.gd`
- Create: `scripts/progression/passive_tree/passive_tree_requirement.gd`
- Create: `scripts/progression/passive_tree/passive_tree_node.gd`
- Create: `scripts/progression/passive_tree/passive_tree_connection.gd`
- Create: `scripts/progression/passive_tree/passive_tree_definition.gd`
- Create: `scripts/progression/passive_tree/passive_tree_load_result.gd`
- Create: `scripts/progression/passive_tree/passive_tree_loader.gd`
- Create: `tests/unit/test_passive_tree_loader.gd`

**Interfaces:**
- Produces: `PassiveTreeLoader.load_path(path: String) -> PassiveTreeLoadResult`, `load_dictionary(document: Dictionary, source_path: String) -> PassiveTreeLoadResult`, `PassiveTreeDefinition.node(id: StringName) -> PassiveTreeNode`, `connection(id: StringName) -> PassiveTreeConnection`, and typed arrays/lookups.

- [ ] **Step 1: Write structural loader tests**

Build in-memory valid and invalid version-1 dictionaries. Cover exact format/version, non-empty IDs/names, finite positions, non-negative integer costs, unique IDs, start-node type, endpoint existence, no self-edge, duplicate unordered endpoint rejection, `bidirectional|forward`, and valid JSON object/array shapes.

Assert the production artifact loads as:

```gdscript
var result := PassiveTreeLoader.new().load_path("res://data/passive_trees/city/party-forge-city.pstree.json")
TestAssertions.truthy(result.ok(), "City runtime loads structurally", failures)
TestAssertions.equal(result.tree.id, &"party-forge-city-v1", "tree ID", failures)
TestAssertions.equal(result.tree.nodes.size(), 30, "node count", failures)
TestAssertions.equal(result.tree.connections.size(), 30, "connection count", failures)
```

- [ ] **Step 2: Run RED**

Expected: parser failure because `PassiveTreeLoader` and record classes do not exist.

- [ ] **Step 3: Implement typed records**

Each record extends `RefCounted`, copies arrays/dictionaries on construction, and exposes typed fields. `PassiveTreeDefinition` builds private node/connection lookup dictionaries and returns `null` for unknown IDs.

`PassiveTreeLoadResult` must expose:

```gdscript
class_name PassiveTreeLoadResult
extends RefCounted

var tree: PassiveTreeDefinition
var errors: Array[String] = []

func ok() -> bool:
	return tree != null and errors.is_empty()
```

- [ ] **Step 4: Implement fail-closed structural loading**

`load_path` reads UTF-8 text, requires a JSON dictionary, delegates to `load_dictionary(document, source_path)`, collects every structural error with `PARTY_FORGE_PASSIVE_TREE_ERROR path=...`, and sets `result.tree` only when the error array is empty.

Accept operations only from `add_flat`, `add_percent`, `multiply`, `set`, and `custom` at this layer. Semantic effect IDs/parameters are Task 5.

- [ ] **Step 5: Run GREEN and commit**

Run the focused loader/artifact suites, then the full suite. Commit:

```powershell
git add -- scripts/progression/passive_tree tests/unit/test_passive_tree_loader.gd
git commit -m "feat: load typed passive tree documents"
```

---

### Task 5: Register Typed Effects, Requirements, and City Invariants

**Files:**
- Create: `scripts/progression/passive_tree/passive_effect_registry.gd`
- Create: `scripts/progression/passive_tree/passive_requirement_registry.gd`
- Create: `scripts/progression/passive_tree/city_passive_tree_policy.gd`
- Create: `scripts/progression/passive_tree/passive_tree_catalog.gd`
- Create: `tests/unit/test_passive_tree_contracts.gd`

**Interfaces:**
- Produces: `PassiveEffectRegistry.validate(effect: PassiveTreeEffect) -> String`, `development_state(effect_id: StringName) -> int`, `is_permanent(effect: PassiveTreeEffect) -> bool`, `unlock_id(effect: PassiveTreeEffect) -> StringName`, `PassiveRequirementRegistry.validate(requirement: PassiveTreeRequirement) -> String`, `CityPassiveTreePolicy.validate(tree: PassiveTreeDefinition) -> Array[String]`, and `PassiveTreeCatalog.load_defaults() -> PassiveTreeLoadResult`.

- [ ] **Step 1: Write RED contract tests**

Assert all existing City effects plus the five new IDs validate only with exact operations/value types/parameters. Assert unknown IDs, extra parameters, missing scope, invalid scope, non-integer additive values, and unknown requirements fail.

Register `allocated_node` only for:

```text
operator: contains
value: non-empty kebab-case node ID string
parameters: exactly { treeId: non-empty kebab-case string }
```

Assert City policy requires 30 nodes, 30 connections, the four logistics IDs, both Extraction License requirements, permanent/Coming Soon metadata, and exact stash tab size 100.

- [ ] **Step 2: Run RED**

Expected: missing registry/policy/catalog types.

- [ ] **Step 3: Implement the effect registry**

Register these exact effect contracts:

```text
city_service_unlock:set(bool):serviceId
experience_gain:add_percent(int):scope
feature_unlock:set(bool):featureId
mode_unlock:set(bool):modeId
party_capacity:add_flat(int):scope
region_unlock:set(bool):regionId
vendor_inventory_slots:add_flat(int):scope
vendor_reroll_count:add_flat(int):scope
building_discovery:set(bool):buildingId
extraction_capacity:add_flat(int):scope
inventory_columns:add_flat(int):scope
stash_tabs:add_flat(int):scope,slotsPerTab
tree_discovery:set(bool):treeId
```

All current City contracts are `future-contract`; registry development state maps them to `FeatureAccessPolicy.State.COMING_SOON` unless a later task explicitly marks an implementation active. Data-bearing set/capacity contracts report permanent.

Canonical profile unlock IDs are:

```text
feature_unlock -> the exact `featureId` value
mode_unlock -> `mode:` followed by the exact `modeId` value
city_service_unlock -> `service:` followed by the exact `serviceId` value
region_unlock -> `region:` followed by the exact `regionId` value
```

- [ ] **Step 4: Implement requirement and City policy validation**

Validate every node effect/requirement before catalog success. `PassiveTreeCatalog.load_defaults()` loads the City JSON, applies the generic registries and City policy, and returns a `PassiveTreeLoadResult`; no partial tree is cached after errors.

- [ ] **Step 5: Run GREEN and commit**

Run `test_passive_tree_contracts.gd`, `test_passive_tree_loader.gd`, and full suite. Commit:

```powershell
git add -- scripts/progression/passive_tree tests/unit/test_passive_tree_contracts.gd
git commit -m "feat: validate passive effect contracts"
```

---

### Task 6: Reconcile Profile Allocations and Compute Graph Visibility

**Files:**
- Create: `scripts/progression/passive_tree/passive_tree_graph.gd`
- Create: `scripts/progression/passive_tree/passive_tree_snapshot.gd`
- Create: `tests/unit/test_passive_tree_graph.gd`
- Create: `tests/unit/test_passive_tree_snapshot.gd`

**Interfaces:**
- Produces: `PassiveTreeGraph.neighbors(node_id: StringName, directed: bool) -> Array[StringName]`, `distances_from(sources: Array[StringName]) -> Dictionary`, `candidate_reachable(allocated: Array[StringName], candidate: StringName) -> bool`, `retained_reach_start(allocated: Array[StringName]) -> bool`, and `PassiveTreeSnapshot.build(tree: PassiveTreeDefinition, profile: ProfileState, developer_reveal: bool, graph: PassiveTreeGraph = null) -> PassiveTreeSnapshot`.

- [ ] **Step 1: Write graph and reconciliation tests**

Cover bidirectional traversal, forward-only allocation, undirected visibility distance, multiple starts, disconnected retained sets, base radius two, visibility bonus, and Developer reveal.

For a profile containing `city-heart`, `field-pack`, and `removed-old-node`, assert:

```gdscript
TestAssertions.equal(snapshot.allocated, [&"city-heart", &"field-pack"], "known allocation projection", failures)
TestAssertions.equal(snapshot.unresolved, [&"removed-old-node"], "unknown saved IDs remain unresolved", failures)
TestAssertions.truthy(&"removed-old-node" in profile.tree_allocations[tree.id], "snapshot does not mutate profile", failures)
```

Also cover a discovered tree with no saved start allocation: `city-heart` appears in `implicit_start_nodes` and acts as a visibility/allocation root.

- [ ] **Step 2: Run RED**

Expected: missing graph/snapshot types.

- [ ] **Step 3: Implement graph indexes and snapshot construction**

Build adjacency dictionaries once per graph. Sort all returned node IDs lexicographically for deterministic tests/UI. Visibility uses undirected neighbors and radius:

```gdscript
var reveal_radius := 2 + int(profile.tree_visibility_progress.get(String(tree.id), 0))
```

Developer reveal returns all node IDs in `visible` but does not alter `profile` or `tree_visibility_progress`.

- [ ] **Step 4: Run GREEN and commit**

Run focused tests and full suite. Commit:

```powershell
git add -- scripts/progression/passive_tree/passive_tree_graph.gd scripts/progression/passive_tree/passive_tree_snapshot.gd tests/unit/test_passive_tree_graph.gd tests/unit/test_passive_tree_snapshot.gd
git commit -m "feat: resolve passive tree visibility"
```

---

### Task 7: Decide Allocation and Refund Actions Purely

**Files:**
- Create: `scripts/progression/passive_tree/passive_tree_action_decision.gd`
- Create: `scripts/progression/passive_tree/passive_tree_progression_service.gd`
- Create: `tests/unit/test_passive_tree_progression_service.gd`

**Interfaces:**
- Produces: `PassiveTreeProgressionService._init(effect_registry: PassiveEffectRegistry, requirement_registry: PassiveRequirementRegistry)`, `allocation_decision(tree: PassiveTreeDefinition, profile: ProfileState, node_id: StringName, developer_context: bool) -> PassiveTreeActionDecision`, `refund_decision(tree: PassiveTreeDefinition, profile: ProfileState, node_id: StringName, developer_context: bool, has_respec_service: bool) -> PassiveTreeActionDecision`, stable result codes/messages, point delta, next allocations, and implicit roots to persist.

- [ ] **Step 1: Write table-driven RED decisions**

Cover these exact codes:

```text
ok
tree_not_discovered
unknown_node
already_allocated
node_obscured
requirement_failed
not_connected
insufficient_points
not_allocated
permanent_node
respec_service_required
retained_path_disconnected
retained_requirement_failed
```

Assert Extraction License rejects until both `field-pack` and `stash-access` are allocated. Assert Developer reveal may inspect all nodes but only `developer_context=true` operations may allocate an otherwise obscured node. Assert refunds never remove unresolved IDs from the saved projection.

- [ ] **Step 2: Run RED**

Expected: missing decision/service types.

- [ ] **Step 3: Implement allocation decisions**

`PassiveTreeActionDecision` exposes:

```gdscript
var allowed := false
var code: StringName = &""
var message := ""
var point_delta := 0
var next_allocations: Array[StringName] = []
var implicit_start_nodes: Array[StringName] = []

func ok() -> bool:
	return allowed and code == &"ok"
```

Allocation validates tree discovery, visibility, typed requirements, available points, and directed connection before projecting `point_delta = -node.cost`.

- [ ] **Step 4: Implement refund decisions**

Permanent metadata/effects reject first. Player Mode requires `has_respec_service`; Developer Mode bypasses price/service only. Remove the candidate from a copy, then require every retained known allocation to reach a start and every retained requirement to pass. Project `point_delta = node.cost` only after all checks.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add -- scripts/progression/passive_tree/passive_tree_action_decision.gd scripts/progression/passive_tree/passive_tree_progression_service.gd tests/unit/test_passive_tree_progression_service.gd
git commit -m "feat: decide passive allocation and refunds"
```

---

### Task 8: Resolve Typed Effects and Feature Availability

**Files:**
- Create: `scripts/progression/passive_tree/passive_effect_resolution.gd`
- Create: `scripts/progression/passive_tree/passive_effect_resolver.gd`
- Create: `tests/unit/test_passive_effect_resolver.gd`
- Modify: `tests/unit/test_feature_access_integration.gd`

**Interfaces:**
- Produces: `PassiveEffectResolver._init(registry: PassiveEffectRegistry)`, `resolve(tree: PassiveTreeDefinition, allocated_ids: Array[StringName]) -> PassiveEffectResolution`, deterministic flat/percent/set values by scope, permanent unlock IDs, building/tree discoveries, and future-contract feature states.

- [ ] **Step 1: Write RED effect-resolution tests**

Allocate Shared Lessons I/II and Expanded Barracks, then require:

```gdscript
TestAssertions.equal(resolution.percent_value(&"experience_gain", &"all_run_experience"), 4, "XP adds deterministically", failures)
TestAssertions.equal(resolution.flat_value(&"party_capacity", &"profile"), 1, "capacity adds flat", failures)
```

Allocate Stash Access and assert unlock `stash`, building `warehouse`, discovered tree `party-forge-warehouse-v1`, and a future stash-tab contract with one 100-slot tab. Unknown allocated IDs grant nothing and remain the snapshot's unresolved responsibility.

Assert `FeatureAccessPolicy` returns Coming Soon in Player Mode and Developer Preview availability only when Developer Mode is active.

- [ ] **Step 2: Run RED**

Expected: missing resolver/resolution types.

- [ ] **Step 3: Implement deterministic typed aggregation**

Sort allocated IDs, then effects by effect ID and canonicalized parameters. Keep `personal`, `owned_characters`, `party`, `world`, `profile`, and `all_run_experience` scopes explicit. Do not infer scope from labels.

`PassiveEffectResolution` returns copies from every public accessor. It never mutates class resources, PartyManager, inventory fields, or the active run.

- [ ] **Step 4: Wire registry IDs into FeatureAccessPolicy tests**

Use exact feature IDs from `feature_unlock` effects as `known_unlocks`/`unlocked`; prefixed mode/service/region IDs remain available to later consumers without collision.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add -- scripts/progression/passive_tree/passive_effect_resolution.gd scripts/progression/passive_tree/passive_effect_resolver.gd tests/unit/test_passive_effect_resolver.gd tests/unit/test_feature_access_integration.gd
git commit -m "feat: resolve profile passive effects"
```

---

### Task 9: Persist Allocation and Refund Transactions Atomically

**Files:**
- Create: `scripts/progression/passive_tree/passive_tree_mutation_service.gd`
- Create: `tests/unit/test_passive_tree_mutation_service.gd`
- Modify: `scripts/profile/profile_mutation_service.gd`
- Modify: `tests/unit/test_profile_mutation_service.gd`

**Interfaces:**
- Produces: `PassiveTreeMutationService._init(mutations: ProfileMutationService, progression: PassiveTreeProgressionService, resolver: PassiveEffectResolver)`, `allocate(profile_id: String, transaction_id: String, tree: PassiveTreeDefinition, node_id: StringName, developer_context: bool, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult`, and `refund(profile_id: String, transaction_id: String, tree: PassiveTreeDefinition, node_id: StringName, developer_context: bool, has_respec_service: bool, root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult`; new prologue completions seed `city-heart` explicitly.

- [ ] **Step 1: Write RED persistence tests**

Using `ProfileTestSupport` disposable roots, cover:

- Successful allocation deducts exact cost and stores the node once.
- Missing implicit root is persisted for a discovered older profile.
- Duplicate transaction returns `duplicate=true` and identical committed result.
- Same ID/different node conflicts.
- Insufficient points and save failure leave the original profile unchanged.
- Stash Access records `stash`, `warehouse`, and Warehouse tree discovery but does not create `stash_tabs` storage yet.
- Refund returns points only after the pure decision passes.
- Permanent nodes cannot refund in Developer Mode.
- New `complete_prologue` stores City discovery, `city-heart` unlock, and `tree_allocations["party-forge-city-v1"] = ["city-heart"]`.

- [ ] **Step 2: Run RED**

Expected: missing mutation service and missing prologue allocation assertion.

- [ ] **Step 3: Implement allocation through `ProfileMutationService.apply`**

Use operation `allocate_passive_node` and request fingerprint:

```gdscript
{
	"tree_id": String(tree.id),
	"node_id": String(node_id),
	"developer_context": developer_context,
}
```

Inside the mutation Callable, re-run the pure decision against the freshly loaded profile, apply its next allocations and point delta, persist implicit starts, and project permanent registered unlock/discovery contracts. Return the decision message as the mutation error without partial writes.

- [ ] **Step 4: Implement refund and prologue compatibility**

Use operation `refund_passive_node`. Include `developer_context` and `has_respec_service` in the transaction request. Preserve unresolved node IDs when replacing the known allocation projection.

Update `complete_prologue` to add `city-heart` to the City allocation array for new transactions while retaining idempotent stored results for older completed transaction IDs.

- [ ] **Step 5: Run focused cleanup-sensitive GREEN**

Run the mutation/profile suites with a fresh isolated APPDATA and assert zero residual `user://tests/profile_*` roots after exit. Then run the full suite.

- [ ] **Step 6: Commit Task 9**

```powershell
git add -- scripts/progression/passive_tree/passive_tree_mutation_service.gd scripts/profile/profile_mutation_service.gd tests/unit/test_passive_tree_mutation_service.gd tests/unit/test_profile_mutation_service.gd
git commit -m "feat: persist passive tree transactions"
```

---

### Task 10: Build Immutable Tree View Data

**Files:**
- Create: `scripts/ui/passive_tree/passive_tree_node_view_data.gd`
- Create: `scripts/ui/passive_tree/passive_tree_view_model.gd`
- Create: `tests/unit/test_passive_tree_view_model.gd`

**Interfaces:**
- Produces: `PassiveTreeViewModel._init(progression: PassiveTreeProgressionService, resolver: PassiveEffectResolver, effects: PassiveEffectRegistry, requirements: PassiveRequirementRegistry)`, `build(tree: PassiveTreeDefinition, profile: ProfileState, developer_reveal: bool) -> Dictionary` with point totals, sorted node views, connections, unresolved IDs, and no mutable domain references.

- [ ] **Step 1: Write RED view-model tests**

Assert allocated, allocatable, unavailable, permanent, and obscured states. Obscured data must expose:

```gdscript
{
	"display_name": "???",
	"description": "???",
	"cost_text": "?",
	"effect_lines": [],
	"requirement_lines": [],
}
```

Assert visible details include keyword explanations, exact decision message, `Passive Points: available / lifetime`, and isolated copies after caller mutation.

- [ ] **Step 2: Run RED**

Expected: missing view types.

- [ ] **Step 3: Implement immutable presentation projection**

`PassiveTreeNodeViewData` stores ID, position, type, state, title/copy, cost, effects, requirements, permanence, and decision. It has `copy()` and no profile mutation methods.

Use registry-provided effect/requirement labels; do not parse creator descriptions to infer behavior.

- [ ] **Step 4: Run GREEN and commit**

```powershell
git add -- scripts/ui/passive_tree/passive_tree_node_view_data.gd scripts/ui/passive_tree/passive_tree_view_model.gd tests/unit/test_passive_tree_view_model.gd
git commit -m "feat: project passive tree view data"
```

---

### Task 11: Build the Reusable Blockout Tree Canvas and Screen

**Files:**
- Create: `scripts/ui/passive_tree/passive_tree_node_control.gd`
- Create: `scripts/ui/passive_tree/passive_tree_canvas.gd`
- Create: `scripts/ui/passive_tree/passive_tree_screen.gd`
- Create: `scenes/ui/passive_tree/passive_tree_node_control.tscn`
- Create: `scenes/ui/passive_tree/passive_tree_screen.tscn`
- Create: `tests/unit/test_passive_tree_screen.gd`

**Interfaces:**
- Produces: `PassiveTreeScreen.configure(tree: PassiveTreeDefinition, profiles: ProfileManager, mutations: PassiveTreeMutationService, view_model: PassiveTreeViewModel, developer_context: bool, profile_root: String = ProfileStore.DEFAULT_ROOT)`, `open(return_focus: Control = null)`, `close()`, `is_open() -> bool`, `tree_closed` signal; canvas pan/zoom and `select_connected(direction: Vector2) -> bool`.

- [ ] **Step 1: Write RED scene/lifecycle tests**

Assert:

- Both scenes load and have typed scripts.
- Screen process mode is `PROCESS_MODE_ALWAYS`.
- Opening acquires a `RunPauseLease`; closing releases only its lease and restores prior pause ownership.
- Tree nodes are created from view data and connections render behind nodes.
- Selected detail panel is stable rather than hover-only.
- Obscured nodes never reveal hidden strings through labels or tooltips.
- Allocate/refund buttons require confirmation and display exact decision/save errors.
- Invalid catalog shows `City passive tree unavailable` and disables mutations.

- [ ] **Step 2: Run RED**

Expected: scenes/scripts missing.

- [ ] **Step 3: Implement blockout node and canvas controls**

Use Godot theme primitives and `_draw()` for circles/diamonds/connections. Clamp zoom to `0.45..2.25`. Keep pan in canvas-local coordinates. Choose connected navigation by highest normalized dot product with the requested direction, then shortest distance, then lexicographic node ID.

- [ ] **Step 4: Implement screen lifecycle and confirmations**

The screen receives a `PassiveTreeDefinition`, active `ProfileManager`, `PassiveTreeMutationService`, `PassiveTreeViewModel`, and Developer view context. After every successful mutation it calls `ProfileManager.refresh_profile(result.profile.profile_id)`, rebuilds the immutable view model, and restores selected node/focus when still valid.

Use `RunPauseLease`; never set `SceneTree.paused` directly. `NOTIFICATION_PREDELETE` releases an active lease.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add -- scripts/ui/passive_tree scenes/ui/passive_tree tests/unit/test_passive_tree_screen.gd
git commit -m "feat: add passive tree blockout screen"
```

---

### Task 12: Add Tree Inputs and Developer Settings Composition

**Files:**
- Modify: `project.godot`
- Modify: `scripts/ui/settings/additional_settings_page.gd`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `scenes/ui/settings/additional_settings_page.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_passive_tree_input_map.gd`
- Modify: `tests/unit/test_settings_screen.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_run_pause_menu.gd`

**Interfaces:**
- Produces: Additional Settings `city_tree_requested(developer_preview: bool)` signal, Settings forwarding/reopen behavior, main composition, and complete keyboard/controller input map.

- [ ] **Step 1: Write RED InputMap and composition tests**

Require these actions/events:

```text
passive_tree_navigate_left/right/up/down -> D-pad plus left-stick axes
passive_tree_pan_left/right/up/down       -> right-stick axes
passive_tree_zoom_in/out                  -> right/left trigger axes
passive_tree_allocate                     -> south face plus Enter
passive_tree_refund                       -> west face plus R
passive_tree_close                        -> east face plus Escape
```

Assert Additional Settings contains `OpenCityPassiveTree`, disables it in Player Simulation, includes it in Developer Mode focus order, and emits only when enabled. Assert `Main` contains/configures `PassiveTreeScreen` and preserves profile gating when no active profile exists.

- [ ] **Step 2: Run RED**

Expected: missing actions/button/screen composition.

- [ ] **Step 3: Add exact input actions**

Use device `0` controller events, `0.2` deadzones for navigation/pan, and trigger thresholds represented by positive motion events. Keep all existing actions unchanged.

- [ ] **Step 4: Add Developer Mode request flow**

`AdditionalSettingsPage` emits `city_tree_requested(true)` only while its draft mode equals `DEVELOPER_MODE`. `SettingsScreen` forwards the signal, closes itself, and provides `open_additional(return_focus)` for restoration. It does not apply unrelated draft settings automatically.

`PartyForgeMain` loads `PassiveTreeCatalog` after profile/catalog bootstrap, reports load errors once, configures the tree screen with the active profile and services, and opens it in Developer reveal context. Closing returns to Additional Settings and restores focus to `OpenCityPassiveTree`.

- [ ] **Step 5: Run GREEN and commit**

Run input/settings/main/passive-screen focused suites, responsive geometry runner, then the full suite. Commit:

```powershell
git add -- project.godot scripts/ui/settings/additional_settings_page.gd scripts/ui/settings/settings_screen.gd scenes/ui/settings/additional_settings_page.tscn scripts/game/main.gd scenes/game/main.tscn tests/unit/test_passive_tree_input_map.gd tests/unit/test_settings_screen.gd tests/unit/test_main_wiring.gd tests/unit/test_run_pause_menu.gd
git commit -m "feat: expose developer city passive tree"
```

---

### Task 13: Add End-to-End Smokes, Manual Approval, and Verification Evidence

**Files:**
- Create: `tests/integration/passive_tree_profile_runner.gd`
- Create: `tests/integration/passive_tree_input_runner.gd`
- Create: `tests/integration/passive_tree_responsive_runner.gd`
- Create: `docs/verification/2026-08-03-passive-tree-runtime-and-progression.md`

**Interfaces:**
- Produces: restart/persistence, controller/mouse interaction, responsive UI, safe-failure evidence, and exact creator/game commit traceability.

- [ ] **Step 1: Write integration runners**

`passive_tree_profile_runner.gd` must create a disposable profile, discover City, grant points through `grant_passive_points`, allocate through the mutation service, restart profile services, verify allocations/points, retry the transaction idempotently, and remove its exact test root.

`passive_tree_input_runner.gd` must open the composed screen, simulate linked-node navigation, pan, zoom, allocate, refund rejection, close, and focus restoration using both keyboard and controller events.

`passive_tree_responsive_runner.gd` must validate 1920x1080, 2560x1440, and 3840x2160: canvas/detail/point header remain visible, confirmation buttons stay reachable, and node selection can scroll/pan into view.

- [ ] **Step 2: Witness runner failures before final fixes**

Run all three once. If they pass without production changes, record characterization passes; do not create artificial failures. If a real composition gap appears, add the smallest failing assertion and correct only that gap.

- [ ] **Step 3: Run the complete automated gate**

With fresh task-specific APPDATA:

```powershell
& $godot --headless --path . --import
& $godot --headless --path . --script res://tests/test_runner.gd
& $godot --headless --path . --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path . --script res://tests/integration/settings_profiles_navigation_runner.gd
& $godot --headless --path . --script res://tests/integration/responsive_ui_geometry_runner.gd
& $godot --headless --path . --script res://tests/integration/passive_tree_profile_runner.gd
& $godot --headless --path . --script res://tests/integration/passive_tree_input_runner.gd
& $godot --headless --path . --script res://tests/integration/passive_tree_responsive_runner.gd
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tests/integration/character_locomotion_smoke.gd
git diff --check
```

Expected: every command exits 0; full suite prints `TEST_SUMMARY: PASS`; each integration runner prints its exact `...SUMMARY: PASS` or `...SMOKE_OK` marker; zero `SCRIPT ERROR`/`TEST_FAILURE`; only established intentional negative-path diagnostics may appear.

- [ ] **Step 4: Perform live manual approval**

In Godot 4.7.1 with disposable APPDATA:

1. Create/select a disposable profile.
2. Confirm left-stick cardinal and diagonal movement in the arena.
3. Confirm Controls displays left-stick bindings.
4. Enable Developer Mode and open City Passive Tree from Additional Settings.
5. Test mouse pan/wheel/select and keyboard allocation controls.
6. Test controller navigation, right-stick pan, trigger zoom, allocate/refund/back.
7. Confirm full Developer reveal does not change saved visibility.
8. Allocate a valid node, restart, and confirm persistence/point balance.
9. Confirm Extraction License explains both prerequisites.
10. Confirm Stash/Inventory/Extraction/Bring-In Gear display Coming Soon, not working storage UI.
11. Use the integration runner's disposable invalid-tree fixture to open the safe unavailable screen and confirm arena/profile/settings access remains functional; do not replace the committed runtime export.
12. Repeat layout checks at 1080p, 1440p, and 4K.

- [ ] **Step 5: Record verification and repository preservation**

The verification document records:

- Party Forge task commit range.
- Creator logistics commit SHA and exact artifact hashes.
- Every automated command, exit code, marker, and log path.
- Manual approval matrix.
- Unresolved/future-contract/error-path evidence.
- Pre/post live-main status comparison proving unrelated user changes were untouched.
- Generated-sidecar cleanup comparison.
- Explicit deferred scope: Plan 3A functional menu, Plan 3B cinematic, Plan 4 storage/run services.

- [ ] **Step 6: Request independent review and correct findings test-first**

Review the complete Party Forge range and the creator artifact commit for Critical/Important/Minor findings. For every accepted finding, add a failing focused test, implement the minimal correction, rerun focused and complete gates, and append evidence.

- [ ] **Step 7: Commit final verification**

```powershell
git add -- tests/integration/passive_tree_profile_runner.gd tests/integration/passive_tree_input_runner.gd tests/integration/passive_tree_responsive_runner.gd docs/verification/2026-08-03-passive-tree-runtime-and-progression.md
git commit -m "test: verify passive tree runtime progression"
```

Do not merge either repository until the final review is clean, both worktrees are clean after generated-sidecar cleanup, and the user chooses the local merge option.

---

## Final Acceptance Checklist

- [ ] Creator source, canonical export, demo export, and Party Forge runtime export satisfy the recorded equality contracts.
- [ ] City tree contains exactly 30 nodes and 30 connections with the approved logistics branch.
- [ ] Strict loading rejects all malformed or unknown active contracts without partial state.
- [ ] Discovered-tree roots, unresolved saved IDs, fog radius, and Developer reveal behave as designed.
- [ ] Allocation/refund decisions are pure, deterministic, and explain rejection codes.
- [ ] Profile transactions are atomic and idempotent.
- [ ] Permanent/future contracts record progression without exposing incomplete storage systems.
- [ ] Developer Mode tree UI works with keyboard/mouse and controller at all target resolutions.
- [ ] Left-stick leader movement works and appears in Controls.
- [ ] Full Party Forge regression and retained smokes pass.
- [ ] Creator full tests, typecheck, and lint pass.
- [ ] Live main checkout and unrelated user/editor state remain untouched.
- [ ] Functional main menu and cinematic remain explicitly queued as Plan 3A and Plan 3B.
