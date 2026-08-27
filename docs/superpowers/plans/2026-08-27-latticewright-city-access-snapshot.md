# Latticewright City Access Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove one replaceable Latticewright-to-Party-Forge authoring slice for City tutorial visibility and access while keeping gameplay, profile saves, and the format-1 City path independent of Latticewright.

**Architecture:** Latticewright 0.5 produces a dedicated runtime-v3 City Access document. An explicit, version-specific Godot importer translates it into a deterministic, checked-in Party Forge snapshot. Strict Party Forge types load and evaluate that snapshot against an immutable view of existing `ProfileState`; a default-off developer setting exposes a provider-selection seam without wiring City scenes or player builds to the candidate.

**Tech Stack:** TypeScript/Node.js and Vitest in Latticewright; Godot 4.7.1, typed GDScript, the Party Forge custom test runners, `AtomicJsonStore`, ConfigFile-backed `PartyForgeSettings`, JSON fixtures, Git.

## Global Constraints

- Work only in these retained worktrees:
  - Latticewright: `E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge`
  - Party Forge: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-v3-portfolio`
- Do not merge either branch, push, delete a retained worktree, alter main, enable the candidate by default, or produce a release.
- Do not modify City scenes, navigation routing, profile schema 4, `ProfileCodec`, passive allocation behavior, or the current format-1 City runtime.
- Party Forge runtime code must not load `.pstree` or `.pstree.json`, reference Latticewright classes, or branch on Latticewright versions.
- The only Latticewright-specific production code belongs to the explicit development importer.
- Keep the existing 16-project Latticewright portfolio definition intact. The City Access authoring project is a separate seventeenth design artifact, not a new gameplay progression tree.
- Treat `party-forge-access-snapshot` version 1 as the stable boundary. A future Latticewright format gets a separate adapter.
- Use test-driven development for every behavior change: write one focused failing assertion, run it and record the expected failure, add the smallest production change, rerun to green, then commit.
- Before each commit, inspect `git diff --check` and `git status --short`. Stage only paths named by that task.
- Use this Godot executable for all Party Forge commands:

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  ```

- Use `npm.cmd`, not `npm`, for Latticewright commands on Windows.
- Expected Godot focused-test success marker: `TEST_SUMMARY: PASS (0 failures)`.
- Expected Party Forge complete-suite success marker: one `TEST_SUMMARY: PASS (` line and no `TEST_SUMMARY: FAIL`, `TEST_FAILURE`, parse, script, or loader error.
- Do not call implementation complete until Task 8's fresh verification is captured.

---

## Contract Identities

Use these exact identifiers throughout the source, importer, snapshot, and tests:

| Location ID | Destination ID | Visibility | Availability |
| --- | --- | --- | --- |
| `city.apothecary` | `city.apothecary.interior` | always visible | always |
| `city.coliseum_road` | `city.coliseum_road.route` | always visible | always |
| `city.scholars_archive` | `city.scholars_archive.interior` | hidden until available | `prologue_state=completed` |
| `city.inn` | `city.inn.interior` | always visible | `permanent_unlock=service:hero_registry` |
| `city.merchant` | `city.merchant.interior` | always visible | `permanent_unlock=service:city_vendors` |
| `city.warehouse` | `city.warehouse.interior` | always visible | `permanent_unlock=stash` |
| `city.smithy` | `city.smithy.interior` | always visible | `permanent_unlock=service:equipment_upgrading` |

Latticewright schema IDs:

- content type: `party-forge-access-location`
- placement type: `party-forge-access-location-placement`
- fields: `party-forge-location-id`, `party-forge-destination-id`, `party-forge-visibility-policy`
- requirements: `party-forge-prologue-state`, `party-forge-permanent-unlock`
- requirement value key: `value`
- visibility values: `visible`, `hidden_until_available`
- project ID: `party-forge-city-access`
- graph ID: `city-access`
- export profile ID: `party-forge-runtime-v3`

The importer mapping is exact:

```text
content requirements -> availableWhen
visibility_policy=visible -> visibleWhen=[always]
visibility_policy=hidden_until_available -> visibleWhen=copy(availableWhen)
```

No other inference is permitted.

---

### Task 1: Author the dedicated Latticewright City Access project

**Repository:** `E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge`

**Files:**

- Modify: `scripts/party-forge/create-party-forge-portfolio.mjs`
- Modify: `scripts/party-forge/create-party-forge-portfolio.test.mjs`
- Modify: `tests/party-forge/portfolio.test.ts`

**Purpose:** Add a separately exported City Access project without changing the existing 16-project portfolio contract.

- [ ] **Step 1: Add a failing Node contract test for the separate project**

  Import a new `buildPartyForgeCityAccessProject()` export in `create-party-forge-portfolio.test.mjs` and assert:

  ```js
  const access = buildPartyForgeCityAccessProject();
  assert.equal(access.projectId, "party-forge-city-access");
  assert.equal(access.graphs.length, 1);
  assert.equal(access.graphs[0].id, "city-access");
  assert.equal(access.content.length, 7);
  assert.equal(access.graphs[0].placements.length, 7);
  assert.deepEqual(access.schemas.effects, []);
  assert.deepEqual(access.content.flatMap(row => row.effects), []);
  assert.equal(buildPartyForgePortfolio().length, 16);
  ```

- [ ] **Step 2: Run the new Node test and confirm RED**

  ```powershell
  node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
  ```

  Expected: failure because `buildPartyForgeCityAccessProject` is not exported.

- [ ] **Step 3: Implement the smallest deterministic project builder**

  Add `buildPartyForgeCityAccessProject()` beside, but not inside, `buildPartyForgePortfolio()`.

  The project must contain:

  - the exact schema and identities listed above;
  - seven content rows and seven placements;
  - one graph and no portals, collections, currencies, ranks, categories, tags, assets, or effects;
  - a `custom` archetype and Access/Locations vocabulary;
  - all three fields owned by content and required;
  - visibility as an enum restricted to `visible` and `hidden_until_available`;
  - prologue-state as an enum restricted to `not_started`, `in_progress`, and `completed`;
  - permanent unlock as required text;
  - stable ordinal IDs such as `location-city-apothecary` and `placement-city-apothecary`;
  - one strict runtime-v3 export profile; and
  - deterministic workspace positions used only for authoring.

  Keep `buildPartyForgePortfolio()` returning exactly 16 projects.

- [ ] **Step 4: Add a failing Vitest semantic contract**

  Extend `tests/party-forge/portfolio.test.ts` to validate the separate project with production v3 validation and runtime resolution. Assert the exact field types, exact requirement definitions, zero validation errors, no effects, unique semantic IDs/destinations, and the seven availability requirements.

  Add an assertion that `stringifyRuntimeV3(accessProject)` is stable after reordering the source's semantically unordered arrays. Also parse the generator's runtime text and compare it to `resolveRuntimeV3(accessProject)` so the script cannot drift from the production runtime contract.

- [ ] **Step 5: Run the two focused Latticewright tests and confirm GREEN**

  ```powershell
  node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
  npm.cmd test -- tests/party-forge/portfolio.test.ts
  ```

  Expected: Node test passes; Vitest reports the portfolio test file passed.

- [ ] **Step 6: Extend the generator CLI with explicit access outputs**

  Make the existing generator write these additional files when given its output directory:

  ```text
  party-forge-city-access.pstree
  party-forge-city-access.pstree.json
  ```

  Reuse the generator's canonical project serializer. Extend `runtimeFor()` so requirement definitions are projected with the same `parameter()` helper used by the runtime schema and content requirement instances survive unchanged. The Vitest comparison to `resolveRuntimeV3()` is the authority; do not hand-write JSON fixtures or rename the existing 16 portfolio outputs.

  Extend the Node test's temporary-directory assertions to require 35 total outputs: 32 existing project/runtime files, the existing portfolio README, and the two access files. Compare both access files against their builder serialization.

- [ ] **Step 7: Run Latticewright qualification for this task**

  ```powershell
  node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
  npm.cmd test -- tests/party-forge/portfolio.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/resolve-runtime.test.ts
  npm.cmd run typecheck
  npm.cmd run lint
  git diff --check
  ```

  Expected: all commands exit 0.

- [ ] **Step 8: Commit only the Latticewright builder and tests**

  ```powershell
  git add scripts/party-forge/create-party-forge-portfolio.mjs scripts/party-forge/create-party-forge-portfolio.test.mjs tests/party-forge/portfolio.test.ts
  git commit -m "feat: author Party Forge City access graph"
  ```

---

### Task 2: Build the strict Party Forge snapshot model and loader

**Repository:** `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-v3-portfolio`

**Files:**

- Create: `scripts/world/access/city_access_condition.gd`
- Create: `scripts/world/access/city_access_location.gd`
- Create: `scripts/world/access/city_access_snapshot.gd`
- Create: `scripts/world/access/city_access_load_result.gd`
- Create: `scripts/world/access/city_access_snapshot_codec.gd`
- Create: `scripts/world/access/city_access_snapshot_loader.gd`
- Create: `tests/unit/test_city_access_snapshot_loader.gd`

**Purpose:** Establish the stable, Latticewright-free Party Forge contract first.

- [ ] **Step 1: Write failing loader happy-path assertions**

  Create `test_city_access_snapshot_loader.gd` using the standard `run() -> Array[String]` suite contract. Build an in-memory seven-location snapshot and assert:

  ```gdscript
  var result := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
  TestAssertions.truthy(result.ok(), "valid access snapshot loads atomically", failures)
  TestAssertions.equal(result.snapshot.locations.size(), 7, "all seven locations load", failures)
  TestAssertions.equal(String(result.snapshot.locations[0].id), "city.apothecary", "locations use ordinal ID order", failures)
  ```

- [ ] **Step 2: Run the focused suite and confirm RED**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_snapshot_loader.gd
  ```

  Expected: the suite cannot load the missing production scripts.

- [ ] **Step 3: Implement immutable value types**

  Use private backing fields, read-only getters that return scalar values or defensive copies, and static constructors that validate before construction.

  Required interfaces:

  ```gdscript
  CityAccessCondition.create(kind: StringName, value: String) -> CityAccessCondition
  CityAccessLocation.create(id: StringName, destination_id: StringName, visible_when: Array[CityAccessCondition], available_when: Array[CityAccessCondition]) -> CityAccessLocation
  CityAccessSnapshot.create(adapter: StringName, source_format: StringName, source_format_version: int, source_sha256: String, locations: Array[CityAccessLocation]) -> CityAccessSnapshot
  CityAccessLoadResult.ok() -> bool
  CityAccessSnapshotCodec.encode_document(document: Dictionary) -> PackedByteArray
  ```

  Constants belong in `CityAccessSnapshotLoader`:

  ```gdscript
  const FORMAT := "party-forge-access-snapshot"
  const VERSION := 1
  const MAX_BYTES := 1024 * 1024
  const MAX_LOCATIONS := 256
  const MAX_CONDITIONS := 8
  const MAX_TEXT_UNITS := 128
  const CONDITION_KINDS := [&"always", &"prologue_state", &"permanent_unlock", &"discovered_building", &"discovered_tree"]
  ```

- [ ] **Step 4: Implement exact structural validation**

  `load_bytes(bytes)` must:

  - reject byte size 1 MiB plus one before decoding;
  - reject invalid UTF-8 by requiring `text.to_utf8_buffer() == bytes` after allowing neither BOM nor replacement characters;
  - parse one JSON dictionary;
  - require exact root keys `format`, `version`, `source`, `locations`;
  - require exact source keys `adapter`, `format`, `formatVersion`, `sha256`;
  - require exact location keys `id`, `destinationId`, `visibleWhen`, `availableWhen`;
  - require exact condition keys `kind`, `value`;
  - require adapter `latticewright-runtime-v3-city-access` for snapshot v1;
  - validate the SHA-256 as 64 lowercase hexadecimal characters;
  - validate nonempty stable IDs/values at no more than 128 UTF-16 code units;
  - reject duplicate location and destination IDs;
  - accept 256 locations and eight conditions, reject plus one;
  - require `always` to have an empty value and forbid mixing `always` with other conditions;
  - require `prologue_state` values from the three exact strings;
  - sort locations by ordinal ID and conditions by kind/value; and
  - return no partial snapshot on any error.

  Add `load_path(path)` as a thin byte-reading wrapper for runtime/provider use.

  `CityAccessSnapshotCodec` must rebuild, not mutate, the validated dictionary in this exact insertion order before pretty-printing with two-space indentation and one final newline:

  ```text
  root: format, version, source, locations
  source: adapter, format, formatVersion, sha256
  location: id, destinationId, visibleWhen, availableWhen
  condition: kind, value
  ```

  It sorts location records by ordinal `id` and condition records by ordinal `kind`, then `value`. Encoding the same logical document twice must return identical bytes.

- [ ] **Step 5: Add RED/GREEN cases for every boundary**

  Add one failing assertion at a time for:

  - unknown keys at every nesting level;
  - wrong root format/version/source adapter;
  - malformed SHA;
  - wrong JSON primitive types;
  - empty/too-long IDs and values;
  - duplicate location/destination IDs;
  - unknown condition kind;
  - malformed `always`;
  - exact and plus-one byte/location/condition/text limits;
  - malformed UTF-8 and BOM;
  - missing file and unreadable file; and
  - defensive-copy behavior.

  Run after each small production increment:

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_snapshot_loader.gd
  ```

- [ ] **Step 6: Commit the stable snapshot contract**

  ```powershell
  git diff --check
  git add scripts/world/access/city_access_condition.gd scripts/world/access/city_access_location.gd scripts/world/access/city_access_snapshot.gd scripts/world/access/city_access_load_result.gd scripts/world/access/city_access_snapshot_codec.gd scripts/world/access/city_access_snapshot_loader.gd tests/unit/test_city_access_snapshot_loader.gd
  git commit -m "feat: add strict City access snapshot contract"
  ```

---

### Task 3: Add strict source reading and tool-confined atomic generation

**Repository:** Party Forge worktree

**Files:**

- Modify: `.gitignore`
- Modify: `scripts/profile/atomic_json_store.gd`
- Modify: `scripts/world/access/city_access_snapshot_loader.gd`
- Modify: `tests/unit/test_atomic_profile_store.gd`
- Modify: `tests/unit/test_city_access_snapshot_loader.gd`
- Create: `scripts/tools/strict_json_document_reader.gd`
- Create: `scripts/tools/generated_json_document_writer.gd`
- Create: `tests/unit/test_strict_json_document_reader.gd`
- Create: `tests/unit/test_generated_json_document_writer.gd`

**Purpose:** Reuse Party Forge's persistence boundary while ensuring importer artifacts never sit beside runtime data.

- [ ] **Approved prerequisite: expose strict in-memory validation**

  Add and independently test:

  ```gdscript
  CityAccessSnapshotLoader.validate_document(document: Dictionary) -> CityAccessLoadResult
  ```

  It must apply the same exact structural and semantic rules as `load_bytes()`
  without reading, encoding, hashing, or mutating disk state. Refactor
  `load_bytes()` to delegate to it after strict byte/UTF-8/JSON parsing so the
  two validation paths cannot drift. Commit this prerequisite separately
  before the remaining Task 3 work.

- [ ] **Step 1: Ignore the fixed tool-owned staging root**

  Add exactly this entry to `.gitignore`:

  ```gitignore
  .party-forge-tools/
  ```

  Runtime loaders must never read that directory.

- [ ] **Step 2: Write failing raw-source reader tests**

  Specify this interface:

  ```gdscript
  StrictJsonDocumentReader.read(path: String, maximum_bytes: int) -> StrictJsonDocumentResult
  ```

  The result owns exact bytes, decoded text, parsed dictionary, lowercase SHA-256, and a sanitized stage/reason. Tests must cover missing file, directory path, 64 MiB exact/plus-one, invalid UTF-8, BOM, malformed JSON, duplicate root and nested keys, and exact-byte hashing.

- [ ] **Step 3: Implement a small JSON token scanner before Godot parsing**

  Godot's JSON parser does not provide duplicate-member diagnostics, so scan the UTF-8-decoded text with a deterministic state machine that recognizes strings/escapes, objects, arrays, numbers, booleans, and null, and maintains one key set per object. Reject a duplicate before calling `JSON.parse`.

  Do not use regex to parse JSON. Do not normalize source bytes before hashing.

- [ ] **Step 4: Run the reader suite to GREEN**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_strict_json_document_reader.gd
  ```

- [ ] **Step 5: Write failing generated-write tests against `AtomicJsonStore`**

  Add a narrowly named method to `AtomicJsonStore`:

  ```gdscript
  save_generated_document(
      path: String,
      document: Dictionary,
      validator: Callable,
      staging_root: String,
      encoder: Callable,
  ) -> Dictionary
  ```

  The returned dictionary has exact keys `ok`, `committed`, `cleanupDebt`,
  `stage`, and `reason`. Booleans are used for the first three values; stage
  and reason are sanitized strings. Rejection before promotion reports
  `committed=false`; verified promotion reports `committed=true`; cleanup
  failure after verified promotion reports `ok=true`, `committed=true`, and
  `cleanupDebt=true`.

  Tests must inject write/promote/read/cleanup failures and assert:

  - validation occurs before disk mutation;
  - all temporary, backup, displaced, and cleanup-debt paths are beneath `staging_root`;
  - pre-promotion failures preserve exact target bytes;
  - promotion and post-promotion verification use the validated canonical candidate;
  - failed promoted-byte verification restores exact previous bytes;
  - no prior target plus failure leaves no target;
  - cleanup failure returns success with a `committed=true` warning/diagnostic; and
  - ordinary `save_document`, `save_irreversible_document`, and `replace_document` behavior is unchanged.

- [ ] **Step 6: Implement the generated-document method and wrapper**

  Keep existing methods byte-for-byte behavior-compatible. The new method should:

  1. validate the in-memory dictionary;
  2. call the required encoder and reject empty or invalid encoded bytes;
  3. create a per-invocation directory below `res://.party-forge-tools/latticewright-city-access/`;
  4. stage and re-read the candidate there;
  5. copy any existing target bytes into that staging directory;
  6. promote only the verified candidate to the fixed target;
  7. re-read and compare exact promoted bytes;
  8. restore the captured prior bytes on verification failure; and
  9. distinguish rejection from committed cleanup debt.

  `GeneratedJsonDocumentWriter` fixes the root and target so the importer cannot redirect them:

  ```gdscript
  const TARGET := "res://data/world/access/party-forge-city-access.snapshot.json"
  const STAGING_ROOT := "res://.party-forge-tools/latticewright-city-access"
  ```

  It always supplies `CityAccessSnapshotCodec.encode_document` as the encoder and `CityAccessSnapshotLoader.validate_document` as the validator.

- [ ] **Step 7: Run atomic regression coverage**

  ```powershell
  & $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_strict_json_document_reader.gd
  ```

  Expected: all suites pass; existing profile-store assertions remain green.

- [ ] **Step 8: Commit the tooling boundary**

  ```powershell
  git diff --check
  git add .gitignore scripts/profile/atomic_json_store.gd scripts/tools/strict_json_document_reader.gd scripts/tools/generated_json_document_writer.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd
  git commit -m "feat: add atomic generated JSON boundary"
  ```

---

### Task 4: Implement the runtime-v3 City Access importer

**Repository:** Party Forge worktree

**Files:**

- Modify: `scripts/profile/atomic_json_store.gd`
- Modify: `scripts/tools/generated_json_document_writer.gd`
- Modify: `tests/unit/test_atomic_profile_store.gd`
- Modify: `tests/unit/test_generated_json_document_writer.gd`
- Create: `scripts/tools/latticewright_runtime_v3_city_access_importer.gd`
- Create: `scripts/tools/city_access_import_result.gd`
- Create: `tools/import_latticewright_access_snapshot.gd`
- Create: `tests/unit/test_latticewright_runtime_v3_city_access_importer.gd`
- Create: `tests/unit/test_latticewright_access_import_cli.gd`

**Purpose:** Isolate all Latticewright knowledge in one replaceable development adapter.

- [ ] **Approved prerequisite: preserve generated-write outcome state**

  Update the Task 3 generated-write method and fixed wrapper to return the
  exact structured result defined above. Preserve ordinary profile-store
  APIs byte-for-byte. Add direct regression tests for rejection,
  pre-promotion failure, verified commit, exact rollback, and committed
  cleanup debt. Commit this prerequisite separately before the remaining
  Task 4 review fixes.

- [ ] **Step 1: Write a failing exact-source translation test**

  Construct a minimal runtime-v3 dictionary with the exact schema and seven locations. Assert the importer returns an in-memory snapshot dictionary matching the approved contract and provenance:

  ```gdscript
  TestAssertions.equal(candidate["format"], "party-forge-access-snapshot", "output owns Party Forge format", failures)
  TestAssertions.equal(candidate["version"], 1, "output owns Party Forge version", failures)
  TestAssertions.equal(candidate["source"]["adapter"], "latticewright-runtime-v3-city-access", "adapter is traceable", failures)
  TestAssertions.equal(candidate["source"]["sha256"], source_sha, "exact source bytes are traceable", failures)
  ```

- [ ] **Step 2: Run importer tests and confirm RED**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_latticewright_runtime_v3_city_access_importer.gd
  ```

- [ ] **Step 3: Implement exact runtime-v3 validation**

  Accept only:

  - root `format=latticewright-progression`, `formatVersion=3`, `projectId=party-forge-city-access`;
  - one graph with ID `city-access`;
  - the exact content/placement/field/requirement definitions from Contract Identities;
  - seven content records, each referenced by exactly one placement;
  - no effects, graph portals, assets, unrelated content types, placement types, fields, or requirements;
  - root extensions exactly equal
    `{gameplayConsumer: "not-yet-wired", partyForgeStatus: "authoring-design-data"}`;
  - empty extensions everywhere else the adapter inspects;
  - unique source record, semantic location, and destination IDs; and
  - requirements only on content, never connection conditions.

  Reject unknown required fields and any extra semantic records. Ignore only layout values explicitly outside the contract: positions, connection geometry/topology, groups, decorations, names, descriptions, and vocabulary display strings. Validate their containing runtime records structurally before ignoring them.

- [ ] **Step 4: Implement exact requirement translation**

  Translate:

  ```text
  party-forge-prologue-state {value:"completed"}
      -> {kind:"prologue_state", value:"completed"}

  party-forge-permanent-unlock {value:"service:hero_registry"}
      -> {kind:"permanent_unlock", value:"service:hero_registry"}
  ```

  Empty requirements become `[{"kind":"always","value":""}]`. `hidden_until_available` copies the canonical availability conditions into `visibleWhen`; `visible` uses `always`.

- [ ] **Step 5: Add rejection and canonicalization cases one at a time**

  Cover unsupported format/version, wrong project/graph, duplicate IDs, dangling/duplicate placements, duplicate destinations, missing fields, invalid visibility, unknown requirements, unknown requirement parameters, effects, connection conditions, portals, assets, missing/extra/mismatched root extension entries, nonempty nested inspected extensions, and invalid generated snapshot.

  Prove that reordering content, placements, requirements, and schema arrays produces byte-identical candidate output while changing source whitespace changes only `source.sha256`.

- [ ] **Step 6: Implement the CLI as a fixed workflow**

  `tools/import_latticewright_access_snapshot.gd` must:

  - parse exactly one `--source <path>` from `OS.get_cmdline_user_args()`;
  - reject missing, repeated, or unknown arguments;
  - call `StrictJsonDocumentReader` with 64 MiB;
  - translate in memory;
  - validate through `CityAccessSnapshotLoader`;
  - canonicalize once through `CityAccessSnapshotCodec`;
  - return `UNCHANGED` without writing on exact target-byte parity;
  - otherwise call `GeneratedJsonDocumentWriter`;
  - re-read exact target bytes; and
  - print exactly one terminal marker:

  ```text
  PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
  PARTY_FORGE_CITY_ACCESS_IMPORT status=IMPORTED adapter=latticewright-runtime-v3-city-access stage=verified
  PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage=<sanitized-stage>
  ```

  Exit 0 for `UNCHANGED` and `IMPORTED`; exit 1 for `REJECTED`. Do not print arbitrary source content or embed source paths in output JSON.

- [ ] **Step 7: Test zero-write outcomes through the CLI seam**

  Inject source reader/importer/writer callables in the CLI service, not in the `SceneTree` wrapper. Assert exact target byte preservation at read, translate, validate, stage, promote, and verify failures. Assert truthful committed cleanup debt.

- [ ] **Step 8: Run focused importer qualification**

  ```powershell
  & $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd
  ```

- [ ] **Step 9: Commit the version-specific adapter**

  ```powershell
  git diff --check
  git add scripts/tools/latticewright_runtime_v3_city_access_importer.gd scripts/tools/city_access_import_result.gd tools/import_latticewright_access_snapshot.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd
  git commit -m "feat: import Latticewright City access snapshots"
  ```

---

### Task 5: Add the immutable access evaluator

**Repository:** Party Forge worktree

**Files:**

- Create: `scripts/world/access/city_access_projection.gd`
- Create: `scripts/world/access/city_access_evaluator.gd`
- Create: `tests/unit/test_city_access_evaluator.gd`

**Purpose:** Evaluate only hidden/locked/available access over existing profile state.

- [ ] **Step 1: Write the failing tutorial-state matrix**

  Load the seven-location fixture and assert:

  - NOT_STARTED and IN_PROGRESS: Apothecary/Coliseum road AVAILABLE, Scholar HIDDEN, four gated buildings LOCKED;
  - COMPLETED: Scholar AVAILABLE without any unlock mutation;
  - each exact unlock exposes only its intended building; and
  - unknown unlocks expose nothing.

- [ ] **Step 2: Run the suite and confirm RED**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_evaluator.gd
  ```

- [ ] **Step 3: Implement the projection and pure evaluator**

  `CityAccessProjection` owns:

  ```gdscript
  enum State { HIDDEN, LOCKED, AVAILABLE }
  var location_id: StringName
  var state: State
  var reason_id: StringName
  var destination_id: StringName # empty unless AVAILABLE
  var diagnostic: String
  ```

  `CityAccessEvaluator.evaluate(snapshot, profile, location_id)` evaluates all-of conditions from defensive set projections of:

  - `ProfileState.prologue_state` mapped to `not_started`, `in_progress`, `completed`;
  - `permanent_feature_unlocks`;
  - `discovered_buildings`; and
  - `discovered_trees`.

  Stable reason IDs:

  - `visible`
  - `visibility_conditions_failed`
  - `availability_conditions_failed`
  - `unknown_location`
  - `invalid_input`

  Unknown locations and invalid input return HIDDEN with no destination.

- [ ] **Step 4: Prove immutability and order insensitivity**

  Before and after every matrix evaluation, compare:

  ```gdscript
  var before_dictionary := profile.to_dictionary()
  var before_bytes := ProfileCodec.encode(profile).to_utf8_buffer()
  # evaluate repeatedly
  TestAssertions.equal(profile.to_dictionary(), before_dictionary, "evaluation leaves profile dictionary unchanged", failures)
  TestAssertions.equal(ProfileCodec.encode(profile).to_utf8_buffer(), before_bytes, "evaluation leaves encoded profile bytes unchanged", failures)
  ```

  Also prove repeated/reshuffled profile arrays produce the same projections.

- [ ] **Step 5: Run loader/evaluator GREEN and commit**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_evaluator.gd
  git diff --check
  git add scripts/world/access/city_access_projection.gd scripts/world/access/city_access_evaluator.gd tests/unit/test_city_access_evaluator.gd
  git commit -m "feat: evaluate immutable City access snapshots"
  ```

---

### Task 6: Add the developer-only provider selection seam

**Repository:** Party Forge worktree

**Files:**

- Modify: `scripts/settings/party_forge_settings.gd`
- Modify: `scripts/settings/party_forge_settings_store.gd`
- Modify: `scripts/ui/settings/additional_settings_page.gd`
- Modify: `scenes/ui/settings/additional_settings_page.tscn`
- Create: `scripts/world/access/city_access_provider_result.gd`
- Create: `scripts/world/access/city_access_provider.gd`
- Modify: `tests/unit/test_party_forge_settings.gd`
- Modify: `tests/unit/test_settings_screen.gd`
- Create: `tests/unit/test_city_access_provider.gd`

**Purpose:** Select the candidate explicitly in Developer Mode without wiring it into gameplay or silently falling back.

- [ ] **Step 1: Write failing settings round-trip/default tests**

  Add `use_city_access_snapshot := false` to the expected settings surface. Assert default false, copy preservation, ConfigFile round trip, wrong-type fail-closed behavior, inactive value retention in Player Simulation, and reset-to-false behavior.

  Keep `PartyForgeSettings.SCHEMA_VERSION == 1`: ConfigFile fields are additive and the absent field defaults false. This is not a profile/save migration.

- [ ] **Step 2: Run settings tests and confirm RED**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
  ```

- [ ] **Step 3: Implement the setting and UI control**

  Add `Layout/UseCityAccessSnapshot` as a `CheckButton` with text:

  ```text
  Use candidate City access snapshot
  ```

  Bind/write/reset it with the other developer controls. Disable it outside Developer Mode, retain its value visibly, include the inactive tooltip, and insert it in deterministic focus traversal immediately before `OpenCityPassiveTree`.

- [ ] **Step 4: Write failing provider-selection tests**

  Specify:

  ```gdscript
  CityAccessProvider.resolve(settings: PartyForgeSettings, profile: ProfileState) -> CityAccessProviderResult
  ```

  Result modes:

  - `LEGACY`: flag false, regardless of mode;
  - `CANDIDATE`: Developer Mode plus flag true plus valid checked-in snapshot;
  - `CANDIDATE_FAILED`: flag true in Developer Mode but snapshot missing/invalid;
  - `LEGACY`: flag true outside Developer Mode, with diagnostic `candidate_requires_developer_mode`.

  `CANDIDATE_FAILED` must expose no snapshot and no legacy fallback. The result must never load Latticewright source data.

- [ ] **Step 5: Implement the provider with an injected snapshot loader**

  Fix the production snapshot path:

  ```gdscript
  const SNAPSHOT_PATH := "res://data/world/access/party-forge-city-access.snapshot.json"
  ```

  The provider returns a validated `CityAccessSnapshot` only in CANDIDATE mode. It has no scene, router, passive-tree, or profile-store dependencies.

- [ ] **Step 6: Run provider/settings qualification**

  ```powershell
  & $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_city_access_provider.gd
  ```

- [ ] **Step 7: Commit the default-off seam**

  ```powershell
  git diff --check
  git add scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd scripts/ui/settings/additional_settings_page.gd scenes/ui/settings/additional_settings_page.tscn scripts/world/access/city_access_provider_result.gd scripts/world/access/city_access_provider.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_provider.gd
  git commit -m "feat: add developer City access provider seam"
  ```

---

### Task 7: Generate and check in the exact source, runtime, and snapshot

**Repositories:** Both retained worktrees

**Files:**

- Create: `design/progression/latticewright/party-forge-city-access.pstree`
- Create: `design/progression/latticewright/party-forge-city-access.pstree.json`
- Create: `data/world/access/party-forge-city-access.snapshot.json`
- Create: `tests/unit/test_city_access_generated_artifacts.gd`

**Purpose:** Produce the reviewable Git diff through the real toolchain, not copied hand-authored JSON.

- [ ] **Step 1: Snapshot both worktrees before generation**

  ```powershell
  git -C 'E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge' status --short --branch
  git -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-v3-portfolio' status --short --branch
  ```

  Expected: both clean at the commits produced by Tasks 1-6.

- [ ] **Step 2: Generate into an isolated temporary directory**

  ```powershell
  $generatedRoot = Join-Path $env:TEMP ("party-forge-city-access-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $generatedRoot | Out-Null
  node 'E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge\scripts\party-forge\create-party-forge-portfolio.mjs' $generatedRoot
  $designRoot = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-v3-portfolio\design\progression\latticewright'
  New-Item -ItemType Directory -Force -Path $designRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $generatedRoot 'party-forge-city-access.pstree') -Destination (Join-Path $designRoot 'party-forge-city-access.pstree')
  Copy-Item -LiteralPath (Join-Path $generatedRoot 'party-forge-city-access.pstree.json') -Destination (Join-Path $designRoot 'party-forge-city-access.pstree.json')
  ```

  Do not copy or replace the existing 16 portfolio artifacts.

- [ ] **Step 3: Run the explicit importer against the checked-in source path**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tools/import_latticewright_access_snapshot.gd -- --source design/progression/latticewright/party-forge-city-access.pstree.json
  ```

  Expected: exit 0 and exactly one `status=IMPORTED` marker.

- [ ] **Step 4: Prove identical repeat import**

  Capture snapshot bytes before the second run, rerun the same command, and compare bytes afterward.

  Expected: exactly one `status=UNCHANGED` marker and byte equality.

- [ ] **Step 5: Add generated-artifact parity tests**

  `test_city_access_generated_artifacts.gd` must:

  - require all three paths;
  - load the runtime through `StrictJsonDocumentReader`;
  - retranslate it in memory;
  - compare canonical candidate bytes to checked-in snapshot bytes;
  - verify `source.sha256` against exact runtime bytes;
  - load the snapshot through the production loader;
  - assert the exact seven location/destination/condition rows; and
  - assert no runtime code path references the `.pstree` paths.

- [ ] **Step 6: Run artifact tests and inspect the diff**

  ```powershell
  & $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_city_access_snapshot_loader.gd
  git diff --check
  git diff --stat
  git diff -- design/progression/latticewright/party-forge-city-access.pstree design/progression/latticewright/party-forge-city-access.pstree.json data/world/access/party-forge-city-access.snapshot.json
  ```

  Verify no timestamp, absolute path, installed-app path, or workspace state entered the Party Forge snapshot.

- [ ] **Step 7: Commit only generated artifacts and parity test**

  ```powershell
  git add design/progression/latticewright/party-forge-city-access.pstree design/progression/latticewright/party-forge-city-access.pstree.json data/world/access/party-forge-city-access.snapshot.json tests/unit/test_city_access_generated_artifacts.gd
  git commit -m "data: add generated City access snapshot"
  ```

---

### Task 8: Add end-to-end headless acceptance and qualify rollback

**Repository:** Party Forge worktree

**Files:**

- Create: `tests/integration/city_access_snapshot_runner.gd`
- Create: `docs/verification/2026-08-27-latticewright-city-access-snapshot.md`

**Purpose:** Prove the exact checked-in source-to-snapshot-to-evaluator flow and record truthful evidence without activating gameplay.

- [ ] **Step 1: Write a failing integration runner**

  The runner must execute, in one isolated process:

  1. read and hash the checked-in runtime-v3 source;
  2. translate it through the production importer;
  3. compare the candidate to checked-in snapshot bytes;
  4. load the production snapshot;
  5. evaluate NOT_STARTED, IN_PROGRESS, COMPLETED, and each single-unlock profile;
  6. compare profile dictionaries and `ProfileCodec.encode()` bytes before/after;
  7. prove flag-off is LEGACY;
  8. prove Player Mode plus flag-on is LEGACY with the developer-only diagnostic;
  9. prove Developer Mode plus flag-on is CANDIDATE;
  10. inject invalid snapshot loading and prove CANDIDATE_FAILED without fallback;
  11. turn the flag off and prove immediate LEGACY rollback; and
  12. verify `data/passive_trees/city/party-forge-city.pstree.json` remains present and loadable by `PassiveTreeLoader`.

  Print only on success:

  ```text
  CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
  ```

- [ ] **Step 2: Run the integration runner and fix only in-scope failures**

  ```powershell
  & $godot --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
  ```

  Expected: exit 0 and the exact success marker.

- [ ] **Step 3: Run the complete focused feature batch**

  ```powershell
  & $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
  ```

  Expected: `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 4: Run the full Party Forge suite from the retained worktree**

  ```powershell
  & $godot --headless --path . --quit-after 2400 --script res://tests/test_runner.gd
  ```

  Expected: one complete-suite PASS marker and no failure/parse/script/loader markers. Record the actual suite count; do not predict it in the verification document.

- [ ] **Step 5: Rerun Latticewright source qualification**

  ```powershell
  Set-Location 'E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge'
  node --test scripts/party-forge/create-party-forge-portfolio.test.mjs
  npm.cmd test -- tests/party-forge/portfolio.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/resolve-runtime.test.ts
  npm.cmd run typecheck
  npm.cmd run lint
  ```

  Expected: all exit 0.

- [ ] **Step 6: Write the verification record**

  In `docs/verification/2026-08-27-latticewright-city-access-snapshot.md`, record:

  - exact branch and HEAD for both worktrees;
  - exact commands, exit codes, elapsed times, and success markers;
  - exact generated source/runtime/snapshot SHA-256 values;
  - the focused and full suite counts actually observed;
  - source-to-snapshot parity and repeat-import `UNCHANGED` evidence;
  - profile dictionary and encoded-byte immutability evidence;
  - default-off/Developer-only/CANDIDATE_FAILED/rollback results;
  - confirmation that format-1 City data remains present and qualified;
  - confirmation that no City scene, profile schema, player activation, merge, push, or release occurred; and
  - any expected negative-path error lines, clearly labeled as test evidence rather than product failure.

- [ ] **Step 7: Commit acceptance coverage and evidence**

  ```powershell
  Set-Location 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-v3-portfolio'
  git diff --check
  git add tests/integration/city_access_snapshot_runner.gd docs/verification/2026-08-27-latticewright-city-access-snapshot.md
  git commit -m "test: qualify City access snapshot rollback"
  ```

- [ ] **Step 8: Perform the final read-only audit**

  ```powershell
  git status --short --branch
  git log --oneline -8
  git diff HEAD~7..HEAD --name-status
  git -C 'E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge' status --short --branch
  git -C 'E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge' log --oneline -3
  ```

  Confirm:

  - both retained worktrees are clean;
  - only the planned Latticewright and Party Forge paths changed;
  - no main branch was changed;
  - no remote push occurred;
  - the candidate remains default-off;
  - format-1 City data remains intact; and
  - implementation is ready for user review, not merge or activation.

---

## Coverage Self-Review

- Approved source artifacts: Task 7.
- Dedicated Latticewright City Access graph: Task 1.
- Stable Party Forge snapshot v1 and bounds: Task 2.
- Duplicate-key, UTF-8, size, and exact-hash source handling: Task 3.
- Version-specific runtime-v3 translation and zero-write rejection: Task 4.
- Hidden/locked/available pure evaluation: Task 5.
- Existing profile fields and byte immutability: Tasks 5 and 8.
- Default-off developer-only provider and no silent fallback: Task 6.
- Fixed format-1 rollback: Tasks 6 and 8.
- Deterministic checked-in artifacts and explicit import: Task 7.
- Full headless acceptance and truthful verification evidence: Task 8.
- Excluded scene work, save migration, balance/effects, merge, activation, and release: Global Constraints and Task 8 audit.

## Stop Boundary

Completing this plan authorizes only a clean, tested implementation on the two retained feature worktrees. Stop and request separate user approval before any merge, push, main-branch change, default activation, player-build wiring, City/world scene integration, format-1 removal, public release, or additional Latticewright domain.
