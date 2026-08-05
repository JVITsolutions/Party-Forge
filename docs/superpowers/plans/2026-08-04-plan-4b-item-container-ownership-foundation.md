# Party Forge Plan 4B Item and Container Ownership Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add versioned immutable item instances, owner-scoped registries, fixed-slot inventory and stash containers, atomic idempotent mutations, profile migration/reconciliation, and an isolated 99-item Developer Sandbox while keeping production Equipment and Inventory unavailable.

**Architecture:** Authored `EquipmentBaseDefinition` resources remain templates. One canonical `ItemInstance` record lives in a profile/run-owned `ItemOwnershipState`, while fixed-slot containers store only instance IDs. All state changes produce and validate a defensive candidate through `ItemContainerTransactionService`; persistent candidates commit through the existing atomic `ProfileMutationService` boundary.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Godot `Resource` catalogs, JSON-safe profile documents, existing atomic profile stores, Control-container UI, custom unit/integration runners.

## Global Constraints

- Execute in an isolated Git worktree created with `superpowers:using-git-worktrees`; do not implement directly on the authoritative `main` checkout.
- Begin from clean `main` at or after design commit `1df6f9d` and test-isolation commit `2e56ad9`.
- Preserve all 99 definitions in `data/equipment/core_equipment_catalog.tres`; the exact count is an acceptance contract.
- Preserve exact item placement. No automatic compaction is permitted.
- Preserve explicit item levels, affix tiers, operations, and rolls after issuance. Loading must not recalculate them from current balance data.
- One item instance may have exactly one serialized location in its ownership domain.
- Player Simulation keeps Equipment and Inventory in Coming Soon state and cannot open the Developer Item Sandbox.
- The Developer Item Sandbox uses an isolated profile/root and may not mutate the active player profile's values or serialized bytes.
- Run inventory capacity is `5 * inventory_columns`, with zero through eight columns.
- Every Plan 4B stash tab has exactly 100 slots.
- Common, Uncommon, Rare, Epic, and Legendary are functional development rarities. Mythic and Eternal are registered future rarities and are not issued by the default sandbox fixture.
- Do not implement equipment application, randomized production loot, ground pickup, extraction, run loss, cross-player transfer, shops, crafting, salvage, or rarity audiovisual presentation.
- Use typed GDScript and defensive copies at all public ownership boundaries.
- Every behavior change follows RED-GREEN-REFACTOR and ends in a focused commit.
- Use `apply_patch` for authored file edits. Do not delete or overwrite unrelated user work.
- Use this command prefix for every Godot gate:

```powershell
$project = (Get-Location).Path
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
```

## Planned file structure

### Item definitions and values

- `scripts/items/item_rarity_definition.gd` — one typed rarity and its development availability.
- `scripts/items/item_affix_definition.gd` — one affix contract, tier range, and allowed modifier specifications.
- `scripts/items/item_foundation_catalog.gd` — rarity/affix lookup and validation.
- `scripts/items/item_modifier_roll.gd` — one explicit immutable rolled modifier.
- `scripts/items/item_affix_instance.gd` — one explicit affix ID, kind, tier, and rolls.
- `scripts/items/item_instance.gd` — one versioned issued item value.
- `scripts/items/item_instance_decode_result.gd` — strict decode result without partial item state.
- `scripts/items/item_instance_codec.gd` — JSON-safe encode/decode and catalog-backed validation.
- `scripts/items/item_issue_result.gd` — issuance result without a partially valid item.
- `scripts/items/item_instance_issuer.gd` — opaque namespace-and-sequence instance IDs shared by profile, run, and sandbox domains.
- `data/items/core_item_foundation_catalog.tres` — functional and future rarity records plus deterministic affix fixtures.

### Ownership and transactions

- `scripts/items/item_registry.gd` — canonical instance-ID-to-item records.
- `scripts/items/item_slot_container.gd` — fixed capacity and sparse exact placement.
- `scripts/items/item_ownership_state.gd` — one registry plus owner-scoped containers.
- `scripts/items/item_transaction_request.gd` — canonical create/move/swap/remove request.
- `scripts/items/item_transaction_result.gd` — stable result code, candidate state, and duplicate marker.
- `scripts/items/item_transaction_journal.gd` — request fingerprints and replay results for run/sandbox state.
- `scripts/items/item_container_transaction_service.gd` — atomic candidate validation and mutation.

### Profile and run integration

- `scripts/profile/profile_migrator.gd` — validated version-one to version-two migration, including nested result snapshots.
- `scripts/profile/profile_migration_result.gd` — migration result, source schema, and current profile candidate.
- `scripts/profile/profile_storage_reconciler.gd` — monotonic passive-effect-to-storage projection.
- `scripts/profile/profile_item_storage_service.gd` — persistent item transaction wrapper around `ProfileMutationService`.
- `scripts/profile/profile_state.gd` — version-two persistent item records, stash containers, and issuance sequence.
- `scripts/profile/profile_codec.gd` — current/loadable document validation and version-two item validation.
- `scripts/profile/profile_store.gd` — verified migration promotion and current-schema reload.
- `scripts/profile/profile_load_result.gd` — migration evidence.
- `scripts/run/player_run_context.gd` — run item state, inventory, and run transaction journal.

### Developer Sandbox and UI

- `scripts/dev/developer_item_fixture_issuer.gd` — deterministic instances for all 99 equipment bases.
- `scripts/dev/developer_item_sandbox_state.gd` — isolated ownership state and sandbox actions.
- `scripts/dev/developer_item_sandbox_store.gd` — isolated atomic save/reload.
- `scripts/ui/developer_item_sandbox.gd` — modal developer-only interface.
- `scenes/ui/developer_item_sandbox.tscn` — responsive five-slot inventory, 100-slot stash, inspector, and actions.
- `scripts/ui/settings/additional_settings_page.gd` — Developer Item Sandbox request.
- `scenes/ui/settings/additional_settings_page.tscn` — developer-only launch button.
- `scripts/ui/settings/settings_screen.gd` — sandbox request forwarding.
- `scripts/game/main.gd` and `scenes/game/main.tscn` — route ownership and modal composition.

### Verification and documentation

- New `tests/unit/test_item_*.gd`, profile migration/reconciliation tests, run-context coverage, and sandbox UI coverage.
- `tests/integration/item_storage_profile_runner.gd` — profile isolation and active-profile byte proof.
- `tests/integration/item_storage_performance_runner.gd` — one-profile and four-profile baselines.
- `tests/integration/developer_item_sandbox_runner.gd` — UI, resolution, controller, save/reload, and reset smoke.
- `docs/handbook/11-item-instances-and-storage.md` — self-service item foundation guide.
- `docs/handbook/README.md` — chapter index.
- `docs/verification/2026-08-04-plan-4b-item-container-ownership.md` — exact final evidence.

---

### Task 1: Typed rarity and affix catalogs

**Files:**
- Create: `scripts/items/item_rarity_definition.gd`
- Create: `scripts/items/item_affix_definition.gd`
- Create: `scripts/items/item_foundation_catalog.gd`
- Create: `data/items/core_item_foundation_catalog.tres`
- Modify: `scripts/data/game_catalog.gd`
- Test: `tests/unit/test_item_foundation_catalog.gd`

**Interfaces:**
- Consumes: `StatCatalog.definition(id: StringName) -> StatDefinition`, `StatModifier.Operation`, and `EquipmentCatalog` through `GameCatalog`.
- Produces: `ItemFoundationCatalog.rarity(id: StringName) -> ItemRarityDefinition`, `affix(id: StringName) -> ItemAffixDefinition`, `validate(stat_catalog: StatCatalog) -> PackedStringArray`, and `functional_rarity_ids() -> Array[StringName]`.

- [ ] **Step 1: Write the failing catalog test**

Create `tests/unit/test_item_foundation_catalog.gd` with a `run()` method that loads `res://data/items/core_item_foundation_catalog.tres` and asserts:

```gdscript
extends RefCounted

const EXPECTED_FUNCTIONAL: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_FUTURE: Array[StringName] = [&"mythic", &"eternal"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(catalog != null, "item foundation catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(stats), PackedStringArray(), "item foundation catalog validates", failures)
	TestAssertions.equal(catalog.functional_rarity_ids(), EXPECTED_FUNCTIONAL, "functional rarity order", failures)
	for rarity_id: StringName in EXPECTED_FUTURE:
		TestAssertions.truthy(catalog.rarity(rarity_id) != null and not catalog.rarity(rarity_id).functional, "%s remains future" % rarity_id, failures)
	TestAssertions.truthy(catalog.affix(&"stout") != null, "stout fixture affix resolves", failures)
	TestAssertions.truthy(catalog.affix(&"of_embers") != null, "fire fixture affix resolves", failures)
	return failures
```

Add negative copies that reject duplicate rarity IDs, duplicate affix IDs, an affix referencing `&"unknown_stat"`, an operation outside `StatModifier.Operation`, a tier range below one, and a minimum roll greater than its maximum.

- [ ] **Step 2: Run RED**

Run:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_foundation_catalog.gd
```

Expected: nonzero exit because `ItemFoundationCatalog` and the resource do not exist.

- [ ] **Step 3: Implement the typed definitions and catalog**

`ItemRarityDefinition` must expose `id`, `display_name`, `functional`, `minimum_affixes`, and `maximum_affixes`, with `validate()` rejecting empty IDs/names, negative bounds, and `minimum_affixes > maximum_affixes`.

`ItemAffixDefinition` must expose:

```gdscript
@export var id: StringName
@export var display_name: String
@export_enum("implicit", "prefix", "suffix", "special") var affix_kind := "prefix"
@export_range(1, 100, 1) var minimum_tier := 1
@export_range(1, 100, 1) var maximum_tier := 1
@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var minimum_roll_by_tier: Array[float] = []
@export var maximum_roll_by_tier: Array[float] = []
@export var required_tags: Array[StringName] = []
```

`roll_bounds(tier: int) -> Vector2` returns the exact configured bounds or `Vector2(INF, -INF)` for an invalid tier. `validate(stat_catalog)` rejects nonfinite values and requires one minimum/maximum pair for every tier.

Create `core_item_foundation_catalog.tres` with exactly seven rarity subresources in the approved order. Add at least these deterministic fixture affixes with valid canonical stat IDs: `stout` (`constitution`, FLAT), `keen` (`dexterity`, FLAT), `wise` (`wisdom`, FLAT), `of_embers` (`fire_damage`, INCREASED), `of_rime` (`cold_damage`, INCREASED), and `of_reach` (`attack_range`, INCREASED). Give every affix three finite tiers with ascending nonoverlapping ranges.

Add `const ITEM_FOUNDATION_CATALOG` and `var item_foundation_catalog` to `GameCatalog`; append its validation errors after the equipment catalog errors.

- [ ] **Step 4: Run GREEN and the catalog regressions**

Run the focused test, then:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_foundation_catalog.gd tests/unit/test_equipment_contract.gd tests/unit/test_game_catalog.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit Task 1**

After a complete Godot import, stage the three new script UID files generated for this task plus the authored files:

```powershell
git add scripts/items data/items scripts/data/game_catalog.gd tests/unit/test_item_foundation_catalog.gd
git commit -m "feat: add item rarity and affix catalogs"
```

### Task 2: Immutable item values and codec

**Files:**
- Create: `scripts/items/item_modifier_roll.gd`
- Create: `scripts/items/item_affix_instance.gd`
- Create: `scripts/items/item_instance.gd`
- Create: `scripts/items/item_instance_decode_result.gd`
- Create: `scripts/items/item_instance_codec.gd`
- Create: `scripts/items/item_issue_result.gd`
- Create: `scripts/items/item_instance_issuer.gd`
- Test: `tests/unit/test_item_instance_codec.gd`

**Interfaces:**
- Consumes: `EquipmentCatalog.definition(id)`, `ItemFoundationCatalog.rarity(id)`, and `affix(id)`.
- Produces: `ItemInstance.copy()`, `to_dictionary()`, `ItemInstanceCodec.decode(document, equipment, foundation) -> ItemInstanceDecodeResult`, `validate(item, equipment, foundation) -> String`, and `ItemInstanceIssuer.issue(issuer_namespace, sequence, source, seed, item_data, equipment, foundation) -> ItemIssueResult`.

- [ ] **Step 1: Write the failing immutable-round-trip test**

Create one Legendary `ItemInstance` for `forge_vanguard_sword` with two affixes and explicit rolls. Assert that:

```gdscript
var encoded := ItemInstanceCodec.encode(item)
var decoded := ItemInstanceCodec.decode(JSON.parse_string(encoded), equipment, foundation)
TestAssertions.truthy(decoded.ok(), "explicit item round trip succeeds", failures)
TestAssertions.equal(decoded.item.to_dictionary(), item.to_dictionary(), "round trip preserves exact item bytes", failures)

var changed_affix := foundation.affix(&"stout")
changed_affix.minimum_roll_by_tier[0] = 999.0
TestAssertions.equal(decoded.item.affixes[0].rolls[0].value, 3.0, "catalog changes do not rewrite issued rolls", failures)
```

Add rejection cases for an empty/invalid instance ID, unknown base, nonpositive item level, future rarity, unknown affix, kind mismatch, tier out of range, wrong stat/operation, nonfinite value, roll outside the issued definition bounds, duplicate affix IDs, unexpected dictionary fields, and non-JSON values.

Add issuer assertions proving the same namespace/sequence pair is stable, different namespaces or sequences produce different IDs, negative sequences and empty namespaces fail without an item, the origin document preserves exact namespace/sequence/source/seed values, and moving an issued item never changes its ID.

- [ ] **Step 2: Run RED**

Run the focused codec test. Expected: failure because the item value classes and codec do not exist.

- [ ] **Step 3: Implement immutable values and strict decode**

Use `RefCounted` value classes. `ItemModifierRoll` contains `stat_id`, `operation`, `value`, and `required_tags`. `ItemAffixInstance` contains `definition_id`, `affix_kind`, `tier`, and `rolls: Array[ItemModifierRoll]`. `ItemInstance` contains exactly the fields approved in the spec and deep-copies every nested value.

Add `ItemInstanceDecodeResult` in `scripts/items/item_instance_decode_result.gd` with `item`, `error`, and `ok()`. Decode must validate exact field sets before constructing values. For example, an empty instance ID emits `PARTY_FORGE_ITEM_ERROR field=instance_id reason=must be a non-empty string`.

Add `ItemIssueResult` with `item`, `error`, and `ok()`. `ItemInstanceIssuer` accepts only a nonempty issuer namespace and nonnegative JSON-safe sequence. It constructs the opaque ID with `"item-%s-%016d" % [issuer_namespace.sha256_text(), sequence]`, records `issuer_namespace`, `sequence`, `source`, and `seed` in the immutable origin dictionary, then routes the candidate through `ItemInstanceCodec.validate()` before returning it. Domain namespace expressions are exact: persistent profile issuance uses `"profile:%s" % profile_id`, run issuance uses `"run:%s:%s:%s" % [profile_id, run_seed, run_player_id]`, and the sandbox uses `sandbox:developer-item-sandbox`.

Encode dictionaries with lexical keys where dictionaries are used and stable array order where order is authored. Do not store Godot `Resource` objects, `StringName`, `Vector2`, or enum objects in the JSON document; convert them to strings, numbers, booleans, arrays, and dictionaries.

- [ ] **Step 4: Run GREEN plus catalog/equipment regression batch**

Run:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_instance_codec.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_equipment_contract.gd
```

Expected: exit `0`, no `TEST_FAILURE`, parse, script, or loader matches.

- [ ] **Step 5: Commit Task 2**

```powershell
git add scripts/items tests/unit/test_item_instance_codec.gd
git commit -m "feat: add immutable item instance codec"
```

### Task 3: Canonical registry and fixed-slot ownership state

**Files:**
- Create: `scripts/items/item_registry.gd`
- Create: `scripts/items/item_slot_container.gd`
- Create: `scripts/items/item_ownership_state.gd`
- Test: `tests/unit/test_item_ownership_state.gd`

**Interfaces:**
- Consumes: validated `ItemInstance` values and the Task 2 codec.
- Produces: defensive registry/container accessors, strict snapshot encode/decode, and `ItemOwnershipState.validate(equipment, foundation) -> String`.

- [ ] **Step 1: Write RED tests for exact placement and uniqueness**

Build a state with one registry item, a five-slot `run_inventory`, and a 100-slot `profile_stash_tab`. Use test-only fixture construction through public constructors, not production test hooks. Assert:

```gdscript
TestAssertions.equal(state.container(&"stash-tab-000").capacity, 100, "stash capacity is exact", failures)
TestAssertions.equal(state.container(&"stash-tab-000").item_id_at(42), item.instance_id, "slot 42 is preserved", failures)
TestAssertions.equal(state.container(&"stash-tab-000").occupied_slots(), [42], "sparse slots remain exact", failures)

var round_trip := ItemOwnershipState.decode(state.to_dictionary(), equipment, foundation)
TestAssertions.equal(round_trip.state.to_dictionary(), state.to_dictionary(), "ownership state round trip is exact", failures)
```

Mutate returned copies and prove the original registry, item, slot dictionary, and container list do not change. Add invalid snapshots for duplicate instance IDs, two slots referencing one ID, an unknown referenced ID, an orphan registry item, negative/oversized capacities, out-of-bounds slots, duplicate container IDs, unknown container kinds, and owner mismatch.

- [ ] **Step 2: Run RED**

Expected: failure because registry/container/state classes do not exist.

- [ ] **Step 3: Implement the ownership aggregate**

`ItemRegistry` owns a private `Dictionary` and exposes `has`, `item`, `ids`, `size`, `copy`, and `to_dictionary`. `ItemSlotContainer` declares these exact kinds:

```gdscript
const RUN_INVENTORY := &"run_inventory"
const PROFILE_STASH_TAB := &"profile_stash_tab"
const DEVELOPER_INVENTORY := &"developer_inventory"
const DEVELOPER_STASH_TAB := &"developer_stash_tab"
```

It exposes `item_id_at(slot)`, `occupied_slots()`, `first_empty_slot()`, `copy()`, and `to_dictionary()`. `occupied_slots()` returns ascending integers. The sparse JSON `slots` dictionary uses decimal string keys so it is JSON-safe.

`ItemOwnershipState` contains `owner_id`, one registry, and a dictionary of containers. Its validation walks every container reference, counts each instance ID, requires exactly one reference per registry item, and returns the first stable `PARTY_FORGE_ITEM_REGISTRY_ERROR` or `PARTY_FORGE_CONTAINER_ERROR`.

Keep mutation helpers prefixed and scoped for Task 4; do not expose dictionary references.

- [ ] **Step 4: Run GREEN and defensive-copy regressions**

Run the focused ownership-state, codec, and profile codec suites. Expected: exit `0`.

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/items tests/unit/test_item_ownership_state.gd
git commit -m "feat: add fixed-slot item ownership state"
```

### Task 4: Atomic and idempotent container transactions

**Files:**
- Create: `scripts/items/item_transaction_request.gd`
- Create: `scripts/items/item_transaction_result.gd`
- Create: `scripts/items/item_transaction_journal.gd`
- Create: `scripts/items/item_container_transaction_service.gd`
- Test: `tests/unit/test_item_container_transactions.gd`

**Interfaces:**
- Consumes: `ItemOwnershipState`, Task 2 item codec, and catalogs.
- Produces: `apply(state, request, journal, equipment, foundation) -> ItemTransactionResult` and stable `ItemTransactionResult.Code` values.

- [ ] **Step 1: Write RED transaction matrix tests**

Cover create-and-place, move-to-empty, swap-occupied, and sandbox-remove. For every operation, snapshot `JSON.stringify(state.to_dictionary())` before the call. Assert successful exact placement and item-record preservation.

Add one table-driven failure case for each code:

```gdscript
enum Code {
	OK,
	INVALID_REQUEST,
	UNKNOWN_OWNER,
	UNKNOWN_CONTAINER,
	SLOT_OUT_OF_BOUNDS,
	SOURCE_MISMATCH,
	DESTINATION_OCCUPIED,
	DUPLICATE_INSTANCE,
	DUPLICATE_REFERENCE,
	INVALID_ITEM,
	TRANSACTION_REPLAY,
	TRANSACTION_COLLISION,
}
```

For failures assert `result.next_state == null` and byte-equivalent original state. Apply a successful request twice and require the second result to set `duplicate = true`, return `TRANSACTION_REPLAY`, and preserve the first result state. Reuse the same transaction ID with a changed destination and require `TRANSACTION_COLLISION`.

- [ ] **Step 2: Run RED**

Expected: missing transaction types.

- [ ] **Step 3: Implement candidate-based transactions**

`ItemTransactionRequest` has exact constructors `create`, `move`, `swap`, and `sandbox_remove`. Its `canonical_document()` sorts keys and contains the operation, owner, source/destination fields, expected item ID, and create payload. `fingerprint()` is `canonical_document().sha256_text()`.

`ItemTransactionJournal` maps transaction ID to `{fingerprint, code, state}` and returns defensive copies. `ItemContainerTransactionService.apply()` must:

1. Validate request and replay state.
2. Copy the ownership state.
3. Apply exactly one candidate mutation.
4. Validate the complete candidate.
5. Record and return the candidate only after validation passes.

Create-and-place must add the registry record and slot in the same candidate. Sandbox-remove must erase both the slot reference and registry record in the same candidate. Move and swap must not touch the registry item document.

- [ ] **Step 4: Run GREEN and repeat with randomized request ordering**

Run the focused transaction and ownership tests twice. Expected: both runs exit `0` with identical markers.

- [ ] **Step 5: Commit Task 4**

```powershell
git add scripts/items tests/unit/test_item_container_transactions.gd
git commit -m "feat: add atomic item container transactions"
```

### Task 5: Version-two profile migration and item persistence

**Files:**
- Create: `scripts/profile/profile_migrator.gd`
- Create: `scripts/profile/profile_migration_result.gd`
- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_store.gd`
- Modify: `scripts/profile/profile_load_result.gd`
- Test: `tests/unit/test_profile_item_schema_migration.gd`
- Modify tests: `tests/unit/test_profile_state.gd`
- Modify tests: `tests/unit/test_atomic_profile_store.gd`
- Modify tests: all fixtures that construct literal profile documents and assert schema version one.

**Interfaces:**
- Consumes: `ItemOwnershipState` profile-stash documents and existing atomic document store.
- Produces: current `ProfileState.SCHEMA_VERSION == 2`, `ProfileMigrator.migrate_document(document) -> ProfileMigrationResult`, and `ProfileLoadResult.migrated`/`source_schema_version`.

- [ ] **Step 1: Write RED migration tests from captured version-one documents**

Construct a complete valid version-one dictionary using current fields, including gold, passive allocations, owned characters, run history, and one `applied_transactions` record whose nested `result_profile` is also version one. Require migration to:

```gdscript
TestAssertions.equal(migrated.profile.schema_version, 2, "profile migrates to schema two", failures)
TestAssertions.equal(migrated.profile.gold, 77, "gold survives migration", failures)
TestAssertions.equal(migrated.profile.tree_allocations, original["tree_allocations"], "allocations survive migration", failures)
TestAssertions.equal(migrated.profile.item_records, {}, "migration invents no items", failures)
TestAssertions.equal(migrated.profile.stash_tabs, [], "migration invents no stash", failures)
TestAssertions.equal(migrated.profile.next_item_sequence, 0, "issuance starts empty", failures)
```

Require the nested `result_profile` snapshot to become schema two with empty item fields. Require a nonempty version-one `stash_tabs` array to fail with `PARTY_FORGE_PROFILE_MIGRATION_ERROR field=stash_tabs reason=unsupported legacy storage` and leave the input dictionary unchanged.

Use an injected failing promotion in `AtomicJsonStore` to prove a failed migration write preserves the version-one primary and verified backup bytes. Prove a successful migration produces a version-two primary and retains the valid version-one generation as backup.

- [ ] **Step 2: Run RED**

Expected: schema-two fields and `ProfileMigrator` are missing.

- [ ] **Step 3: Implement strict loadable/current validation and atomic promotion**

Add to `ProfileState`:

```gdscript
const SCHEMA_VERSION := 2
var item_records: Dictionary = {}
var stash_tabs: Array[Dictionary] = []
var next_item_sequence := 0
```

Keep `inventory_columns` and `extraction_capacity` unchanged. Include item fields in `to_dictionary()` and defensive copy behavior.

Split codec validation into:

- `validate_current_document(document)` — schema two only, including strict item/container state.
- `validate_loadable_document(document)` — complete schema one or schema two.
- `decode_document(document)` — migrate first, then construct only a schema-two `ProfileState`.

Do not accept arbitrary extra keys. Validate `next_item_sequence` as `0..JSON_SAFE_INTEGER_MAX`. Validate persistent item records and every stash container through Tasks 2 and 3 with the authoritative catalogs.

`ProfileStore.load_profile()` must load with `validate_loadable_document`. When decode reports migration, atomically save the schema-two profile and perform a second current-schema load/verification before returning it. Set `ProfileLoadResult.migrated = true` and `source_schema_version = 1`. If promotion or verification fails, return an error and preserve the old generation.

- [ ] **Step 4: Run GREEN in focused profile batches**

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profile_state.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_manager.gd tests/unit/test_profile_mutation_service.gd
```

Expected: exit `0`; backup recovery tests remain green.

- [ ] **Step 5: Commit Task 5**

```powershell
git add scripts/profile/profile_migrator.gd scripts/profile/profile_migration_result.gd scripts/profile/profile_state.gd scripts/profile/profile_codec.gd scripts/profile/profile_store.gd scripts/profile/profile_load_result.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profile_state.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_manager.gd tests/unit/test_profile_mutation_service.gd
git commit -m "feat: migrate profiles to item storage schema"
```

### Task 6: Passive storage reconciliation and persistent transaction wrapper

**Files:**
- Create: `scripts/profile/profile_storage_reconciler.gd`
- Create: `scripts/profile/profile_item_storage_service.gd`
- Test: `tests/unit/test_profile_storage_reconciler.gd`
- Test: `tests/unit/test_profile_item_storage_service.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_mutation_service.gd`
- Modify tests: `tests/unit/test_passive_tree_mutation_service.gd`

**Interfaces:**
- Consumes: `PassiveEffectResolver.resolve(tree, allocations)`, `flat_value(&"inventory_columns", &"profile")`, `stash_tab_contracts()`, and Task 4 transaction service.
- Produces: `ProfileStorageReconciler.reconcile(profile, tree, resolver) -> String` and `ProfileItemStorageService.apply(profile_id, request, root) -> ProfileMutationResult`.

- [ ] **Step 1: Write RED reconciliation and persistence tests**

Build profiles with no allocations, `field-pack`, `stash-access`, both, repeated duplicate allocation strings, pre-existing valid placed items, and refunded permanent nodes. Require:

```gdscript
TestAssertions.equal(field_pack.inventory_columns, 1, "field pack grants one column", failures)
TestAssertions.equal(field_pack_run_capacity, 5, "one column means five run slots", failures)
TestAssertions.equal(stash.stash_tabs.size(), 1, "stash access grants one tab", failures)
TestAssertions.equal(int(stash.stash_tabs[0]["capacity"]), 100, "stash tab has 100 slots", failures)
TestAssertions.equal(stash.stash_tabs[0]["container_id"], "stash-tab-000", "first stash id is stable", failures)
```

Run reconciliation twice and require byte-equivalent results. Reconcile a profile whose allocations no longer contain a permanent storage node and prove capacity/items are not removed.

For `ProfileItemStorageService`, persist a create request, reload the profile, and prove one item/slot. Replay it and prove `duplicate = true`. Reuse the transaction ID with different data and prove no file hash change.

- [ ] **Step 2: Run RED**

Expected: missing reconciler/storage service.

- [ ] **Step 3: Implement monotonic reconciliation and persistent wrapper**

`reconcile()` loads the profile's allocation strings for the supplied tree ID, resolves typed effects, and computes:

```gdscript
var resolved_columns := clampi(resolution.flat_value(&"inventory_columns", &"profile"), 0, 8)
profile.inventory_columns = maxi(profile.inventory_columns, resolved_columns)
```

For each profile-scope stash contract, require `slotsPerTab == 100`; create stable tabs until the existing tab count reaches the resolved count. Never shrink, reorder, or recreate an existing tab.

Call reconciliation inside successful permanent passive allocation candidates after `_project_permanent_effects()`. A reconciliation error aborts the entire passive allocation transaction.

`ProfileItemStorageService.apply()` wraps one Task 4 transaction inside `ProfileMutationService.apply()` with operation `item_storage_transaction` and the transaction's canonical document as the request fingerprint source. It reconstructs the profile stash ownership state, applies, writes the resulting `item_records`/`stash_tabs`, and returns the committed profile.

For a create request, require item origin namespace `"profile:%s" % profile_id` and origin sequence equal to `profile.next_item_sequence`. Increment `next_item_sequence` exactly once inside the same successful candidate transaction. Failed, colliding, or replayed requests do not consume a sequence; an idempotent replay returns the already committed sequence/result.

- [ ] **Step 4: Run GREEN plus passive/profile regression batch**

Run both new suites plus passive-effect, passive-tree-mutation, profile-mutation, and atomic-store suites. Expected: exit `0`.

- [ ] **Step 5: Commit Task 6**

```powershell
git add scripts/profile/profile_storage_reconciler.gd scripts/profile/profile_item_storage_service.gd scripts/progression/passive_tree/passive_tree_mutation_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_passive_tree_mutation_service.gd
git commit -m "feat: reconcile profile inventory and stash storage"
```

### Task 7: Run-context inventory ownership

**Files:**
- Modify: `scripts/run/player_run_context.gd`
- Modify: `tests/unit/test_player_run_context.gd`
- Modify: `tests/unit/test_run_context_registry.gd`
- Test: `tests/unit/test_run_item_ownership.gd`

**Interfaces:**
- Consumes: profile `inventory_columns`, `ItemOwnershipState`, `ItemTransactionJournal`, and transaction service.
- Produces: `PlayerRunContext.item_state() -> ItemOwnershipState`, `run_inventory() -> ItemSlotContainer`, and `apply_item_transaction(request, equipment, foundation) -> ItemTransactionResult`.

- [ ] **Step 1: Write RED run-isolation tests**

Create contexts for profiles with zero, one, and eight inventory columns. Assert exact capacities `0`, `5`, and `40`. Create two contexts, issue one item into the first context, mutate every returned copy, and prove the second context and both profile snapshots remain unchanged. Assert that run issuance starts at sequence zero, uses namespace `"run:%s:%s:%s" % [profile_id, run_seed, run_player_id]`, advances only after successful create transactions, and never advances the persistent profile sequence.

Reject a request whose owner ID is the other context's `run_player_id`. Prove repeated transaction IDs are isolated per context. Extend invalid-configure/retry tests to prove failed configuration commits no item state or journal and valid retry creates them once.

- [ ] **Step 2: Run RED**

Expected: missing run item APIs.

- [ ] **Step 3: Integrate run ownership atomically into configure**

Build candidate run item state before writing any context identity fields:

```gdscript
var inventory := ItemSlotContainer.create(
	&"run-inventory",
	ItemSlotContainer.RUN_INVENTORY,
	run_player_id_value,
	owned_profile.inventory_columns * 5,
)
var next_item_state := ItemOwnershipState.create(run_player_id_value, ItemRegistry.new(), [inventory])
```

Validate it, then commit it with party/progression fields plus `_next_item_sequence := 0`. Clear both item fields on the existing abort path. Public accessors return copies. `apply_item_transaction()` uses the context-owned journal and replaces `_item_state` only when the result succeeds. Create requests must use the context namespace `"run:%s:%s:%s" % [profile_id, run_seed, run_player_id]` and current run sequence; increment the run sequence only when a nonduplicate create succeeds.

Do not persist run inventory into `ProfileState.resumable_run` in Plan 4B.

- [ ] **Step 4: Run GREEN plus complete run-context/reward batch**

Run player-run-context, run-registry, reward-distribution, experience-orb, progression, and main-wiring suites. Expected: exit `0`.

- [ ] **Step 5: Commit Task 7**

```powershell
git add scripts/run/player_run_context.gd tests/unit/test_player_run_context.gd tests/unit/test_run_context_registry.gd tests/unit/test_run_item_ownership.gd
git commit -m "feat: own fixed inventory by run context"
```

### Task 8: Deterministic isolated 99-item sandbox domain

**Files:**
- Create: `scripts/dev/developer_item_fixture_issuer.gd`
- Create: `scripts/dev/developer_item_sandbox_state.gd`
- Create: `scripts/dev/developer_item_sandbox_store.gd`
- Test: `tests/unit/test_developer_item_sandbox_state.gd`

**Interfaces:**
- Consumes: all 99 `EquipmentCatalog.definitions`, functional rarity IDs, fixture affixes, ownership state, transaction service, and `AtomicJsonStore`.
- Produces: `DeveloperItemSandboxState.reset()`, `save()`, `reload()`, `registry()`, `inventory()`, `stash()`, `to_dictionary()`, `integrity_error()`, `move_to_first_empty_inventory(item_id)`, and `move_to_first_empty_stash(item_id)`.

- [ ] **Step 1: Write RED deterministic fixture tests**

Reset two independent sandboxes and assert:

```gdscript
TestAssertions.equal(first.registry().size(), 99, "sandbox issues all equipment bases", failures)
TestAssertions.equal(first.inventory().capacity, 5, "sandbox inventory is five slots", failures)
TestAssertions.equal(first.stash().capacity, 100, "sandbox stash is 100 slots", failures)
TestAssertions.equal(first.stash().occupied_slots().size(), 99, "sandbox fills 99 stash slots", failures)
TestAssertions.equal(first.stash().first_empty_slot(), 99, "last stash slot remains empty", failures)
TestAssertions.equal(first.to_dictionary(), second.to_dictionary(), "reset is deterministic", failures)
```

Require every equipment base ID exactly once. Require all five functional rarities to appear and Mythic/Eternal never to appear. Require every non-Common fixture to contain valid explicit affixes.

Save, move/swap items, reload, and prove exact placement. Reset and prove byte-equivalent starting state. Inject an atomic-save failure and prove the previous sandbox document remains loadable.

- [ ] **Step 2: Run RED**

Expected: sandbox domain classes missing.

- [ ] **Step 3: Implement deterministic issuance and isolated storage**

Use the fixed sandbox identity `developer-item-sandbox` and root `user://developer_item_sandbox`. The sandbox never calls `ProfileManager.bootstrap()` and never writes under `ProfileStore.DEFAULT_ROOT`.

Issue definitions in the exact `EquipmentCatalog.definitions` order through `ItemInstanceIssuer` with namespace `sandbox:developer-item-sandbox` and sequence equal to the definition index. Use item level `1 + (index % 100)`, rarity `functional_rarity_ids()[index % 5]`, and deterministic affix selection from the fixture catalog. Clamp fixture rolls inside the chosen tier bounds and store explicit values. Tests derive their expected IDs through the issuer rather than depending on a display-friendly sequential ID.

Create inventory `developer-inventory` with capacity five and stash `developer-stash-000` with capacity 100. Place item index `0..98` into the matching stash slot through create transactions, not direct dictionary writes.

The store document contains a sandbox schema version, ownership state, issuance metadata, and transaction journal. It uses `AtomicJsonStore` with a strict sandbox validator.

- [ ] **Step 4: Run GREEN and determinism twice**

Run the sandbox-state suite twice and compare its printed deterministic SHA-256 marker. Expected: identical hash and exit `0`.

- [ ] **Step 5: Commit Task 8**

```powershell
git add scripts/dev tests/unit/test_developer_item_sandbox_state.gd
git commit -m "feat: add deterministic developer item sandbox state"
```

### Task 9: Developer Item Sandbox interface and routing

**Files:**
- Create: `scripts/ui/developer_item_sandbox.gd`
- Create: `scenes/ui/developer_item_sandbox.tscn`
- Modify: `scripts/ui/settings/additional_settings_page.gd`
- Modify: `scenes/ui/settings/additional_settings_page.tscn`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Test: `tests/unit/test_developer_item_sandbox.gd`
- Modify tests: `tests/unit/test_settings_screen.gd`
- Modify tests: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: `DeveloperItemSandboxState` and active `PartyForgeSettings.Mode`.
- Produces: `AdditionalSettingsPage.item_sandbox_requested`, `SettingsScreen.item_sandbox_requested`, and modal `DeveloperItemSandbox.open(return_focus)`/`close()`.

- [ ] **Step 1: Write RED route and interface tests**

Assert the Additional Settings launch button is disabled in Player Simulation and enabled in Developer Mode. Emitting the request in Player Simulation must not open the sandbox. In Developer Mode, require one modal sandbox at a layer above Settings, Settings hidden while the sandbox is active, and focus returned to the launch button on close.

Instantiate the sandbox and require five inventory slot buttons, 100 stash slot buttons, one inspector, Save/Reload, Integrity Scan, and Reset controls. Select a populated slot and verify displayed base name, instance ID, rarity, item level, affix details, owner, container, and slot. Exercise move-to-first-empty inventory and swap through UI signals.

Hash the configured active profile before opening and after sandbox close; require identical values and bytes.

- [ ] **Step 2: Run RED**

Expected: missing sandbox scene/route.

- [ ] **Step 3: Build the modal UI and explicit developer-only route**

Compose `DeveloperItemSandbox` as a process-always `CanvasLayer` at layer 14:

```text
Overlay (full rect)
└── Frame (safe margins)
    └── Layout
        ├── Header (title, status, close)
        ├── Body (responsive split)
        │   ├── InventoryPanel (5 slot buttons)
        │   ├── StashScroll (10-column GridContainer, 100 buttons)
        │   └── InspectorScroll
        └── Actions (First Empty Inventory, First Empty Stash, Save/Reload, Integrity Scan, Reset)
```

Slot buttons store `container_id` and `slot` metadata. First activation selects a source; activating a second slot requests move/swap. Labels and inspector read defensive projections only. Status always includes the stable transaction/error code on failure.

Add `signal item_sandbox_requested` to both settings scripts. The Additional page emits only while its mode selector is Developer Mode and the button is enabled. `PartyForgeMain` rechecks `saved_settings.mode == DEVELOPER_MODE` before opening, closes Settings, and owns focus restoration. No `unlock_all_implemented_content` bypass is allowed.

- [ ] **Step 4: Run GREEN plus front-end regression batch**

Run sandbox UI, settings-screen, main-wiring, feature-access, ledger-shell, main-menu, pause-menu, and temporary-popup suites. Expected: exit `0`.

- [ ] **Step 5: Commit Task 9**

```powershell
git add scripts/ui scripts/game/main.gd scenes/ui scenes/game/main.tscn tests/unit
git commit -m "feat: expose isolated developer item sandbox"
```

### Task 10: Responsive, controller, profile-isolation, and performance runners

**Files:**
- Create: `tests/integration/developer_item_sandbox_runner.gd`
- Create: `tests/integration/item_storage_profile_runner.gd`
- Create: `tests/integration/item_storage_performance_runner.gd`
- Test: `tests/unit/test_item_storage_responsive_contract.gd`

**Interfaces:**
- Consumes: complete Plan 4B production interfaces.
- Produces: exact acceptance markers documented below.

- [ ] **Step 1: Write RED integration runners and responsive geometry tests**

The UI runner opens the production-composed sandbox at `1920x1080`, `2560x1440`, and `3840x2160`. At each size it asserts every main panel lies inside the viewport, stash scrolling works, the inspector remains reachable, and focus traversal covers all action buttons without leaving the modal.

Inject `InputEventJoypadButton` events for south-face accept and east-face cancel, plus D-pad navigation. Emit:

```text
ITEM_SANDBOX_RESOLUTION_PASS size=1920x1080 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=2560x1440 slots=105
ITEM_SANDBOX_RESOLUTION_PASS size=3840x2160 slots=105
ITEM_SANDBOX_CONTROLLER_PASS
ITEM_SANDBOX_UI_SUMMARY: PASS
```

The profile runner creates two normal profiles and one isolated sandbox, records both profile values and SHA-256 bytes, performs sandbox save/reload/move/swap/reset, then requires both normal profiles unchanged. Emit `ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99`.

The performance runner records elapsed milliseconds, encoded bytes, and instance/container counts for one profile with 99 items and four independent profiles with 99 items each. It fails on timeout, nonfinite measurements, invalid state, incorrect counts, or cross-profile references. Emit `ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396`.

- [ ] **Step 2: Run RED**

Run each runner before production support is complete. Expected: nonzero exit or missing required marker.

- [ ] **Step 3: Add only the layout/input hooks required by the runners**

Implement `apply_viewport_size(size: Vector2i)` on the sandbox to switch the Body container between wide horizontal and compact vertical layout using the same breakpoint policy as Settings/ledger tests. Use Godot anchors, containers, size flags, and scroll containers; do not add resolution-specific coordinates.

Expose read-only diagnostic methods `slot_button_count()`, `selected_item_detail()`, and `integrity_error()` only when they are useful to the real developer sandbox as well as the runner. Do not add test-only production methods.

- [ ] **Step 4: Run GREEN for all three runners**

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/developer_item_sandbox_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_performance_runner.gd
```

Expected: exit `0` and all exact summary markers above.

- [ ] **Step 5: Commit Task 10**

```powershell
git add scripts/ui/developer_item_sandbox.gd scenes/ui/developer_item_sandbox.tscn tests/integration/developer_item_sandbox_runner.gd tests/integration/item_storage_profile_runner.gd tests/integration/item_storage_performance_runner.gd tests/unit/test_item_storage_responsive_contract.gd
git commit -m "test: verify item sandbox ownership and layouts"
```

### Task 11: Handbook, complete review, and final verification

**Files:**
- Create: `docs/handbook/11-item-instances-and-storage.md`
- Modify: `docs/handbook/README.md`
- Create: `docs/verification/2026-08-04-plan-4b-item-container-ownership.md`
- Modify: only files required by confirmed Critical or Important review findings, with a failing regression first.

**Interfaces:**
- Consumes: complete Plan 4B implementation.
- Produces: user-facing authoring guidance and exact reproducible acceptance evidence.

- [ ] **Step 1: Write the handbook chapter**

Document, with exact current paths and examples:

- Difference between `EquipmentBaseDefinition` and `ItemInstance`.
- How to add a rarity or deterministic affix fixture.
- Why issued rolls remain explicit.
- Registry/container/transaction ownership flow.
- How fixed slot indices serialize.
- How passive inventory/stash capacity materializes.
- How to open, inspect, save/reload, integrity-scan, and reset the Developer Item Sandbox.
- Which systems remain unavailable and which future plan owns them.

Add chapter 11 to the handbook index.

- [ ] **Step 2: Run a complete independent code review**

Use `superpowers:requesting-code-review` against the full implementation range from the design commit through Task 10. Review for:

- Duplicate or orphan item paths.
- Mutable references escaping registries/containers.
- Non-atomic candidate commits.
- Replay/collision ambiguity.
- Schema-one migration loss, including nested transaction snapshots.
- Sandbox access from Player Simulation.
- Any active-profile store/root reference in sandbox code.
- UI focus leaks and resolution-specific layout.

For every confirmed Critical or Important finding, add one focused failing regression, run RED, implement one root-cause fix, and rerun GREEN. Record deferred Minor findings explicitly.

- [ ] **Step 3: Run the genuine import and full automated gate**

Run:

```powershell
& $godot --headless --path $project --import
& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd
```

Required evidence:

- Both commands exit `0`.
- Import contains no unexpected `No loader found`, parse, script, or failed-resource errors.
- Full suite prints one `TEST_SUMMARY: PASS (N suites)` marker where `N` equals the suite count discovered from `tests/unit` during that exact run.
- Do not hard-code the suite count in the verification document; record the observed number.

- [ ] **Step 4: Run focused final gates and gameplay smokes**

Run all three Task 10 integration runners again, the existing production Arena progression smoke, main-menu navigation smoke, all three City passive-tree smokes, 24-member ledger smoke, and startup smoke. Capture exact commands, exit codes, elapsed times, and summary markers.

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/developer_item_sandbox_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_storage_performance_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/progression_arena_smoke_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/main_menu_navigation_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_profile_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_input_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/passive_tree_responsive_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path $project --quit-after 10
git diff --check
git status --short
```

Expected markers: `ITEM_SANDBOX_UI_SUMMARY: PASS`, `ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99`, `ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396`, `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`, `MAIN_MENU_NAVIGATION_SUMMARY: PASS`, `PASSIVE_TREE_PROFILE_SUMMARY: PASS`, `PASSIVE_TREE_INPUT_SUMMARY: PASS`, `PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)`, `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)`, `PARTY_FORGE_BOOT_OK`, and `PARTY_FORGE_CLASS_SELECTION_READY`. Every command must exit `0`.

Expected before the documentation commit: only the intended handbook/verification files are dirty, with no generated `.png.import` noise and no unrelated paths.

- [ ] **Step 5: Write the verification document and commit final evidence**

Name the verification file with the actual day. Record:

- Tested commit/range.
- Godot version.
- Exact import, focused, full-suite, integration, and smoke commands.
- Exit codes and required markers.
- One-profile/four-profile performance numbers.
- Active-profile before/after SHA-256 proof.
- 99-item deterministic fixture hash.
- 1080p/1440p/4K and controller results.
- Review findings and corrections.
- Explicit deferred scope.
- Generated-sidecar disposition.
- Final clean-worktree proof.

Commit:

```powershell
git add docs/handbook docs/verification
git commit -m "docs: verify Plan 4B item ownership foundation"
```

- [ ] **Step 6: Perform the branch-finish gate**

Use `superpowers:verification-before-completion`, then `superpowers:finishing-a-development-branch`. Re-run any gate whose evidence predates the final code commit. Present the tested head, commits, exact pass markers, known deferred work, and integration options. Do not merge into a dirty authoritative checkout without preserving and comparing its state.
