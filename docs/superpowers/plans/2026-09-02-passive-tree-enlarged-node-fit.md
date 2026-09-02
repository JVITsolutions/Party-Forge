# Passive Tree Enlarged Node Reflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-author only the 37 Party Forge City placement coordinates in LatticeWright, then render the unchanged graph through uniformly enlarged 168-by-120 Party Forge controls that fit the production canvas without overlap, crossing, obstruction, perpendicular junctions, or truncated labels.

**Architecture:** LatticeWright's `party-forge-city-v3-contract.mjs` remains the single coordinate authority and deterministically regenerates the format-3 source/runtime pair. Party Forge copies the generated pair, validates the same production-sized geometry profile, and uses `PassiveTreeCanvas.fit_to_content` to project the reflowed coordinates at the largest contained uniform zoom. No gameplay semantic, topology, portal, allocation, or activation contract changes.

**Tech Stack:** Node.js ESM, Vitest, TypeScript, ESLint, LatticeWright format-3/runtime-v3, Godot 4.7.1 Mono, GDScript, Party Forge focused/unit/integration runners.

## Global Constraints

- The approved design is `docs/superpowers/specs/2026-09-02-passive-tree-enlarged-node-fit-design.md` at commit `d682e66e`.
- LatticeWright worktree: `E:\Projects\Passive Skill Tree Creator\.worktrees\party-forge-city-v3-runtime`, branch `feature/party-forge-city-v3-runtime`, starting HEAD `fe75ac7d367fcc55c1523c57c3e5811c0733b228`.
- Party Forge worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-city-v3-foundation`, branch `feature/latticewright-city-v3-foundation`.
- Use portable Godot `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`; never invoke the WinGet Godot executable.
- Preserve every user-owned worktree and the Party Forge baseline of exactly 87 untracked `.gd.uid` files, 1,717 bytes, canonical sorted path/length/content digest `6f5807853fd248c0675bd45d2720b133f1d915b8c83bdd11586a34b9dde7192b`. Never stage those sidecars.
- Preserve the frozen four-runner Party Forge index and all existing TDD edits; do not reset, clean, delete, rewrite history, force-push, or touch art/HUD/attack-windup/Review Batch 1 scope.
- Preserve all 37 placement/content IDs, names, descriptions, point costs, activation states, effects, requirements, 37 connection IDs and endpoint pairs, six portal identities and targets, starting placement, allocation behavior, and gameplay semantics.
- Change exactly the 37 LatticeWright placement positions and the matching 37 source/runtime positions. No format migration or coordinate fork is allowed.
- Production geometry is one 168-by-120 rectangle per node, 12 units minimum rectangle clearance, 8 units minimum edge-to-nonendpoint-rectangle clearance, no proper nonincident edge crossing, and no shared-node edge-angle difference in the closed interval 86 through 94 degrees.
- Production fit uses the 1472-by-863 canvas, one 168-by-120 control footprint, and 24 px margin on each side. The accepted layout span is 1252 by 695 and its fitted zoom is exactly 1.0.
- Node labels use `TextServer.AUTOWRAP_WORD_SMART`, `TextServer.OVERRUN_NO_TRIMMING`, and one uniform `Vector2(168, 120)` footprint.
- Use strict RED-GREEN-REFACTOR. Do not weaken geometry, connection-pixel, label-pixel, viewport, or overlap assertions and do not add a test-only production API.

---

### Task 1: Freeze and generate the exact LatticeWright coordinate reflow

**Files:**
- Modify: `scripts/party-forge/party-forge-city-v3-contract.mjs`
- Modify: `scripts/party-forge/party-forge-city-v3-contract.test.mjs`
- Verify: `scripts/party-forge/create-party-forge-portfolio.mjs`
- Verify: `scripts/party-forge/create-party-forge-portfolio.test.mjs`
- Replace deterministically: `samples/party-forge-city.pstree`
- Replace deterministically: `samples/party-forge-city.pstree.json`

**Interfaces:**
- `CITY_NODES` remains a frozen 37-row contract with identical non-position fields; only `position.x` and `position.y` change.
- `validateCityGeometry(graph)` keeps its public diagnostic shape and validates the City contract with `NODE_WIDTH = 168`, `NODE_HEIGHT = 120`, `NODE_CLEARANCE = 12`, `EDGE_CLEARANCE = 8`, and `RIGHT_ANGLE_EXCLUSION_DEGREES = 4`.
- `buildPartyForgeCityProject()` and `serializePartyForgePortfolio()` remain the only builders for both committed City samples.

- [ ] **Step 1: Write the exact failing coordinate and footprint contracts**

Replace the coordinate portion of `EXPECTED_NODE_ROWS` with this exact ID-to-position mapping while preserving every existing name, cost, and activation-state expectation:

```text
arena-charter = (14, 139)
artificers-hall = (1041, 556)
blueprint-library = (253, 556)
city-heart = (619, 278)
civic-archive = (239, 417)
contract-ledger = (1182, 0)
endless-gate = (197, 0)
equipment-registry = (633, 417)
expanded-barracks = (591, 0)
expedition-board = (1013, 278)
expedition-district-charter = (1252, 695)
extraction-license = (450, 556)
field-pack = (647, 556)
forge-district-charter = (858, 695)
grand-exchange = (1196, 139)
grand-workshop = (1055, 695)
hall-of-heroes = (225, 278)
hero-district-charter = (985, 0)
hero-registry = (788, 0)
leader-loadout-extraction = (267, 695)
logistics-district-charter = (70, 695)
market-district-charter = (1210, 278)
merchant-permits = (999, 139)
north-road-charter = (1027, 417)
open-market = (802, 139)
pathfinders-charter = (1238, 556)
reclamation-bench = (844, 556)
secured-loadout = (464, 695)
shared-lessons-1 = (605, 139)
shared-lessons-2 = (394, 0)
smiths-guild = (830, 417)
stash-access = (436, 417)
surveyors-office = (816, 278)
training-yard = (408, 139)
trial-monument = (211, 139)
trials-district-charter = (0, 0)
waystone-network = (1224, 417)
```

Update the existing geometry boundary fixtures so horizontal centers at 180 units pass and 179.999 fail, while an edge 68 units from a node center passes and 67.999 fails. Add exact assertions that the City placement span is `{ width: 1252, height: 695 }`, all six charter placements have degree one, and `validateCityGeometry(cityGraph())` returns four empty diagnostic arrays.

- [ ] **Step 2: Run RED against the old positions and old 92-by-34 profile**

Run from the exact LatticeWright worktree:

```powershell
node --test scripts/party-forge/party-forge-city-v3-contract.test.mjs scripts/party-forge/create-party-forge-portfolio.test.mjs
```

Expected: nonzero exit. The exact-coordinate assertion and 168-by-120 boundary fixtures fail against the old contract; unrelated semantic expectations remain green.

- [ ] **Step 3: Apply only the exact approved coordinate table and geometry footprint**

Update the 37 `node(...)` coordinate pairs in `CITY_NODES` to Step 1 verbatim. Set only the geometry footprint constants to:

```js
const NODE_WIDTH = 168;
const NODE_HEIGHT = 120;
const NODE_CLEARANCE = 12;
const EDGE_CLEARANCE = 8;
const RIGHT_ANGLE_EXCLUSION_DEGREES = 4;
```

Do not change the `CITY_CONNECTIONS`, `CITY_PORTALS`, activation partitions, effects, requirements, identity, vocabulary, or serialization code.

- [ ] **Step 4: Regenerate both canonical City samples from the builder**

Generate the portfolio into a fresh empty directory below the current user's temp root:

```powershell
$evidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ("lw-city-reflow-{0}-{1}" -f (Get-Date -Format 'yyyyMMddTHHmmssZ'), [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $evidenceRoot | Out-Null
node scripts/party-forge/create-party-forge-portfolio.mjs $evidenceRoot
Copy-Item -LiteralPath (Join-Path $evidenceRoot 'party-forge-city.pstree') -Destination 'samples/party-forge-city.pstree'
Copy-Item -LiteralPath (Join-Path $evidenceRoot 'party-forge-city.pstree.json') -Destination 'samples/party-forge-city.pstree.json'
```

Expected generator marker: `WROTE_PARTY_FORGE_PORTFOLIO:35`. Leave the exact evidence root available for later hash comparison.

- [ ] **Step 5: Verify GREEN, determinism, and semantic containment**

Run:

```powershell
node --test scripts/party-forge/party-forge-city-v3-contract.test.mjs scripts/party-forge/create-party-forge-portfolio.test.mjs
npm run typecheck
npm run lint
git diff --check
```

Expected: all 24 Node tests pass; typecheck, lint, and diff-check exit 0. Generate once more into a second fresh directory and require byte identity for both City samples. Compare parsed before/after projections after deleting only `graphs[*].placements[*].position`; require deep equality, exactly 37 changed positions in the source and runtime, 37/37 preserved IDs, 37/37 preserved edges, six degree-one charters, zero geometry diagnostics, minimum rectangle distance at least 12, minimum edge clearance at least 8, and every shared angle outside `[86,94]`.

- [ ] **Step 6: Review and commit Task 1**

Obtain requirements review before code-quality review. Resolve every Critical/Important finding, repeat Step 5, and stage only the two contract files plus the two regenerated City samples. The verified generator files remain unstaged unless a failing contract proves a production change is required.

Commit: `feat: reflow Party Forge City layout`

---

### Task 2: Consume the exact runtime and finish enlarged Party Forge rendering

**Files:**
- Replace from Task 1: `data/passive_trees/city/party-forge-city.pstree`
- Replace from Task 1: `data/passive_trees/city/party-forge-city.pstree.json`
- Modify: `scripts/progression/passive_tree/city_tree_geometry_validator.gd`
- Modify: `tests/unit/test_latticewright_runtime_v3_city_adapter.gd`
- Modify: `tests/unit/test_passive_tree_readability.gd`
- Modify: `tests/unit/test_passive_tree_screen.gd`
- Modify: `scenes/ui/passive_tree/passive_tree_node_control.tscn`
- Modify: `scripts/ui/passive_tree/passive_tree_canvas.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_screen.gd`
- Modify: `tests/integration/passive_tree_responsive_runner.gd`
- Add/finalize: `tests/integration/latticewright_city_v3_runner.gd`
- Add/finalize: `tests/integration/city_victory_progression_runner.gd`
- Add/finalize: `tests/integration/city_item_drop_gate_runner.gd`
- Add/finalize: `tests/integration/city_tree_v3_visual_runner.gd`

**Interfaces:**
- `CityTreeGeometryValidator.validate(nodes, connections) -> Array[String]` uses the same 168-by-120/12/8/four-degree contract as LatticeWright.
- `PassiveTreeCanvas.fit_to_content(margin: Vector2 = Vector2(24.0, 24.0)) -> bool` returns false without mutation for missing views, nonpositive canvas size, or nonpositive available area; otherwise it applies one finite clamped zoom/pan and returns true.
- `PassiveTreeScreen` fits only after rebuild/open/settled viewport resize; manual pan and zoom remain available afterward.

- [ ] **Step 1: Extend RED for the production-sized runtime contract**

In `test_latticewright_runtime_v3_city_adapter.gd`, change the exact node-clearance centers from 104/103.999 to 180/179.999 and the edge-corridor node-center distances from 25/24.999 to 68/67.999. Preserve the exact 86/85.999 degree exclusion checks.

Keep the existing RED rendering contracts:

```gdscript
TestAssertions.equal(node_control.custom_minimum_size, Vector2(168.0, 120.0), "passive nodes use the approved enlarged uniform footprint", failures)
TestAssertions.equal(node_control.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "passive node names wrap at word boundaries", failures)
TestAssertions.equal(node_control.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "passive node names never ellipsize", failures)
```

The visual runner must continue requiring: all 37 connections have at least 95 percent centerline pixel coverage and maximum internal gap 2; every control is contained and nonoverlapping; every full charter label fits and produces foreground pixels for every word; the serialized production geometry validator returns no diagnostics.

- [ ] **Step 2: Run RED before importing the reflowed samples**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_latticewright_runtime_v3_city_adapter.gd res://tests/unit/test_passive_tree_readability.gd res://tests/unit/test_passive_tree_screen.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
```

Expected: nonzero exit from at least the updated 168-by-120 geometry boundary and current old-coordinate visual overlap proof. Record the terminal summary and exact failures.

- [ ] **Step 3: Import the exact LatticeWright pair and align the production validator**

Copy the exact Task 1 `samples/party-forge-city.pstree` and `.pstree.json` into the two Party Forge data paths. Require runtime bytes to be identical and source JSON to be structurally identical after line-ending normalization. Set only these constants in `city_tree_geometry_validator.gd`:

```gdscript
const NODE_WIDTH := 168.0
const NODE_HEIGHT := 120.0
const NODE_CLEARANCE := 12.0
const EDGE_CLEARANCE := 8.0
const RIGHT_ANGLE_EXCLUSION_DEGREES := 4.0
```

Keep the existing enlarged node scene and production fit implementation. Refactor only if a current test exposes a real defect; do not alter the approved footprint, margins, wrap mode, or fit lifecycle.

- [ ] **Step 4: Run focused GREEN and the four Task 8 acceptance runners**

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_latticewright_runtime_v3_city_adapter.gd res://tests/unit/test_passive_tree_readability.gd res://tests/unit/test_passive_tree_screen.gd res://tests/unit/test_passive_tree_contracts.gd res://tests/unit/test_passive_tree_artifact_sync.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/latticewright_city_v3_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_victory_progression_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_item_drop_gate_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
```

Expected markers exactly once with exit 0:

```text
TEST_SUMMARY: PASS (0 failures)
LATTICEWRIGHT_CITY_V3_SUMMARY: PASS
CITY_VICTORY_PROGRESSION_SUMMARY: PASS
CITY_ITEM_DROP_GATE_SUMMARY: PASS
CITY_TREE_V3_VISUAL_SUMMARY: PASS
```

The visual runner reports an absolute PNG path outside the repository. Render that exact image and inspect it before claiming completion.

- [ ] **Step 5: Run owning UI/profile regression gates**

```powershell
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_responsive_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_input_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_profile_runner.gd
git diff --check
```

Expected markers exactly once with exit 0: `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)`, `PASSIVE_TREE_INPUT_SUMMARY: PASS`, and `PASSIVE_TREE_PROFILE_SUMMARY: PASS`. Scan every log for `TEST_FAILURE`, `TEST_SUMMARY: FAIL`, `SCRIPT ERROR`, `Parse Error`, failed script loading/compilation, crashes, ObjectDB leaks, and RID leaks; disclose any root-certificate diagnostic separately.

- [ ] **Step 6: Prove containment, review, and commit Task 2**

Recompute the canonical 87-UID manifest and require the exact baseline digest. Require zero staged UIDs, no unrelated tracked paths, identical LatticeWright/Party Forge runtime bytes, exact 37/37 position sync, and `git diff --check` exit 0. Obtain requirements review before code-quality review and resolve every Critical/Important finding. Repeat Steps 4 and 5 after fixes.

Stage only the listed Task 2 files and the already frozen four Task 8 runner additions.

Commit: `fix: fit enlarged City tree layout`

---

### Task 3: Whole-branch qualification and conflict-safe publication

**Files:**
- Create outside repositories: immutable review packages, exact-commit archives, test logs, hash manifests, and the final PNG/inline visualization evidence.
- Do not modify production files during this task.

- [ ] **Step 1: Sequential whole-branch review**

Build separate LatticeWright and Party Forge merge-base-to-HEAD review packages. Run requirements review first and code-quality review second. Resolve every Critical/Important finding in the owning worktree, repeat the affected task gates, rebuild the package, and re-review.

- [ ] **Step 2: Full LatticeWright qualification**

Run `npm test`, `npm run typecheck`, `npm run lint`, the real format-3 open/save/reopen/runtime-v3 export acceptance, and the owning Electron City acceptance. Require deterministic sample hashes, zero semantic drift outside positions, and a clean worktree at the exact candidate commit.

- [ ] **Step 3: Full Party Forge exact-commit qualification**

Archive the exact Party Forge candidate commit to an isolated source directory with isolated `APPDATA` and `LOCALAPPDATA`. Run cold Godot import, the focused union, every owning integration runner, and `res://tests/test_runner.gd`. Success requires native exit 0, each required PASS marker exactly once, zero forbidden diagnostics, and final `TEST_SUMMARY: PASS (...)`. Preserve and compare registered-worktree and UID manifests before/after.

- [ ] **Step 4: Show the accepted tree and publish only pristine candidates**

Render the exact passing Godot PNG inline for Jacob's remote view and update the existing inline City visualization from the same frozen format-3 coordinates. If both repositories remain pristine, fetch normally, verify live remote ancestry, integrate LatticeWright first and Party Forge second without conflict, rerun the bounded post-integration gates, and push normally. Stop on conflict, remote drift, scope drift, inadequate evidence, or a required product/visual choice. Never force-push.
