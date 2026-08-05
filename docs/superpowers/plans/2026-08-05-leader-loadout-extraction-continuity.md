# Leader Loadout Extraction Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-profile leader loadout continuity, progressive item extraction, an Armoury equipment-and-stash interface, class-compatibility warnings, and safe explicit overflow destruction.

**Architecture:** Extend the Plan 4B owner-scoped item model with fixed equipment containers, then model run resolution as a pure proposal that transfers retained items between run and profile ownership domains before one atomic profile save. Main-menu and class-selection UI consume defensive projections and submit explicit policy commands; they never edit item dictionaries or invoke sandbox-only removal.

**Tech Stack:** Godot 4.7.1, typed GDScript, Resource-backed catalogs, JSON profile schemas, `AtomicJsonStore`, existing profile/item transaction services, Latticewright Passive Skill Tree Creator, Godot headless test runners.

## Global Constraints

- Execute in an isolated Git worktree created through `superpowers:using-git-worktrees`; do not implement directly on authoritative `main`.
- Begin only after Plan 4B item/container ownership is integrated and its final verification is clean.
- Each profile owns its leader loadout, stash, extraction capacity, warnings, and decisions independently.
- An item instance has exactly one owner and one serialized location.
- Equipped leader items do not consume stash slots.
- Before `leader_loadout_extraction`, ordinary extraction may select leader equipment, follower equipment, or run-inventory items.
- After `leader_loadout_extraction`, every leader item is retained automatically, consumes zero ordinary slots, and is excluded from ordinary extraction.
- Class selection never silently deletes equipment.
- Destruction requires an exact-item preview and a separate hold-to-confirm action.
- A rejected validation, cancellation, interrupted operation, replay, or save failure preserves the previous profile bytes and ownership state.
- Production destruction may not call or expose `ItemTransactionRequest.SANDBOX_REMOVE`.
- The Passive Skill Tree Creator remains authoritative for `.pstree` source and deterministic runtime export; do not hand-edit only Party Forge's runtime JSON.
- Player Mode obeys permanent feature unlocks. Developer Mode may preview unfinished UI without mutating production progression.
- Use typed GDScript, defensive copies at public boundaries, strict RED-GREEN-REFACTOR, focused commits, and an independent review after every task.

---

## File and Responsibility Map

- `scripts/items/equipment_slot_index.gd`: canonical integer position mapping for the eleven `EquipmentSlotCatalog` slots.
- `scripts/items/item_slot_container.gd`: recognizes fixed profile/run equipment container kinds.
- `scripts/profile/profile_state.gd`, `profile_codec.gd`, `profile_migrator.gd`: schema-three persistent leader-loadout ownership.
- `scripts/run/player_run_context.gd`: run-owned inventory plus one equipment container per member.
- `scripts/equipment/equipment_assignment_service.gd`: pure equip/unequip proposal using `EquipmentEligibility`.
- `scripts/extraction/extraction_selection.gd`: immutable ordinary extraction request.
- `scripts/extraction/run_extraction_projection.gd`: defensive eligible/automatic/lost item projection.
- `scripts/extraction/run_extraction_policy.gd`: pure precedence and capacity validation.
- `scripts/extraction/run_resolution_service.gd`: atomic transfer from run ownership to profile ownership.
- `scripts/equipment/loadout_compatibility_service.gd`: pure selected-class compatibility projection.
- `scripts/equipment/loadout_transition_service.gd`: atomic stash move or explicitly confirmed overflow destruction.
- `scripts/ui/armoury/*`, `scenes/ui/armoury/*`: equipment-and-stash interface.
- `scripts/ui/loadout_warning/*`, `scenes/ui/loadout_warning/*`: two-stage incompatible-class warning and confirmation.
- `scripts/ui/main_menu/*`, `scripts/game/main.gd`: feature-gated Armoury and run-setup routing.
- `scripts/run/local_run_setup_coordinator.gd`: waits for every participating profile's loadout decision.

### Task 1: Fixed Equipment Container Contract

**Files:**
- Create: `scripts/items/equipment_slot_index.gd`
- Modify: `scripts/items/item_slot_container.gd`
- Modify: `tests/unit/test_item_ownership_state.gd`
- Create: `tests/unit/test_equipment_slot_index.gd`

**Interfaces:**
- Consumes: `EquipmentSlotCatalog.SLOT_IDS`.
- Produces: `EquipmentSlotIndex.capacity() -> int`, `index_for(slot_id: StringName) -> int`, `slot_for(index: int) -> StringName`, plus `ItemSlotContainer.PROFILE_LEADER_EQUIPMENT` and `RUN_MEMBER_EQUIPMENT`.

- [ ] **Step 1: Write the failing slot/container tests**

Create `test_equipment_slot_index.gd` with exact round-trip assertions:

```gdscript
TestAssertions.equal(EquipmentSlotIndex.capacity(), 11, "equipment sheet has eleven canonical positions", failures)
for index: int in EquipmentSlotCatalog.SLOT_IDS.size():
	var slot_id := EquipmentSlotCatalog.SLOT_IDS[index]
	TestAssertions.equal(EquipmentSlotIndex.index_for(slot_id), index, "slot maps to canonical index", failures)
	TestAssertions.equal(EquipmentSlotIndex.slot_for(index), slot_id, "index maps to canonical slot", failures)
TestAssertions.equal(EquipmentSlotIndex.index_for(&"unknown"), -1, "unknown slot is rejected", failures)
TestAssertions.equal(EquipmentSlotIndex.slot_for(11), &"", "out-of-range index is rejected", failures)
```

Extend `test_item_ownership_state.gd` with one empty `profile_leader_equipment` container and one sparse `run_member_equipment` container. Require capacity exactly eleven, exact slot preservation, wrong capacity rejection, and unchanged validation of inventory/stash kinds.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_slot_index.gd tests/unit/test_item_ownership_state.gd
```

Expected: failure because `EquipmentSlotIndex` and both container constants are missing.

- [ ] **Step 3: Implement the canonical mapping and container validation**

Create:

```gdscript
class_name EquipmentSlotIndex
extends RefCounted

static func capacity() -> int:
	return EquipmentSlotCatalog.SLOT_IDS.size()

static func index_for(slot_id: StringName) -> int:
	return EquipmentSlotCatalog.SLOT_IDS.find(slot_id)

static func slot_for(index: int) -> StringName:
	return EquipmentSlotCatalog.SLOT_IDS[index] if index >= 0 and index < capacity() else &""
```

Add container kinds `&"profile_leader_equipment"` and `&"run_member_equipment"`. Both require capacity `EquipmentSlotIndex.capacity()`. Preserve the existing zero-to-forty inventory rule and exact 100-slot stash rule.

- [ ] **Step 4: Run GREEN and item regressions**

Run the Task 1 command, then item codec, ownership, transaction, and equipment-contract suites. Expected: exit `0`, no failure markers.

- [ ] **Step 5: Commit**

```powershell
git add scripts/items/equipment_slot_index.gd scripts/items/item_slot_container.gd tests/unit/test_equipment_slot_index.gd tests/unit/test_item_ownership_state.gd
git commit -m "feat: define fixed equipment containers"
```

### Task 2: Profile Schema Three Leader Loadout

**Files:**
- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_migrator.gd`
- Modify: `scripts/profile/profile_storage_reconciler.gd`
- Modify: `tests/unit/test_profile_state.gd`
- Modify: `tests/unit/test_profile_item_schema_migration.gd`
- Modify: `tests/unit/test_atomic_profile_store.gd`

**Interfaces:**
- Consumes: `ItemSlotContainer.PROFILE_LEADER_EQUIPMENT`.
- Produces: `ProfileState.leader_loadout: Dictionary`, schema version `3`, and v2-to-v3 atomic migration.

- [ ] **Step 1: Write RED profile and migration tests**

Require a new profile to encode this exact container:

```gdscript
{
	"schema_version": 1,
	"container_id": "leader-loadout",
	"container_kind": "profile_leader_equipment",
	"owner_id": profile.profile_id,
	"capacity": 11,
	"slots": {},
}
```

Add tests that populate two leader slots with real item IDs, round-trip exact placement, reject wrong owner/kind/capacity/orphan items, and prove returned profiles are defensive. Migrate a v2 profile with item-bearing stash and require the stash bytes/placements, item records, sequence, transactions, and every existing progression field to survive while the empty leader loadout is added. Inject failed promotion/current verification and prove the v2 primary/backup bytes remain recoverable.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd
```

Expected: schema/version/field failures for missing `leader_loadout`.

- [ ] **Step 3: Implement schema three and strict ownership decoding**

Set `ProfileState.SCHEMA_VERSION := 3`, add `leader_loadout`, and initialize it from the profile ID in `new_profile()`. Extend the exact codec field list. Build the synthetic profile ownership state from `[leader_loadout] + stash_tabs`; decode through authoritative catalogs and assign only after all validation succeeds.

```gdscript
const SCHEMA_VERSION := 3
var leader_loadout: Dictionary = {}

static func _empty_leader_loadout(profile_id: String) -> Dictionary:
	return ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile_id,
		EquipmentSlotIndex.capacity(),
	).to_dictionary()
```

Add v2 migration that preserves all v2 fields byte-semantically and creates only the empty exact leader container. Keep the existing v1-to-v2 migration, then apply v2-to-v3 so v1 documents migrate through both steps in memory before one atomic promotion. `ProfileStorageReconciler` validates the combined loadout/stash ownership proposal and never rewrites the existing loadout.

- [ ] **Step 4: Run GREEN and complete profile regressions**

Run the Task 2 command plus profile manager, mutation, storage reconciliation, storage service, and boot integration suites. Expected: exit `0` and no partial-artifact leakage.

- [ ] **Step 5: Commit**

```powershell
git add scripts/profile tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd
git commit -m "feat: persist profile leader loadouts"
```

### Task 3: Run Member Equipment Ownership and Assignment

**Files:**
- Create: `scripts/equipment/equipment_assignment_result.gd`
- Create: `scripts/equipment/equipment_assignment_service.gd`
- Modify: `scripts/run/player_run_context.gd`
- Modify: `tests/unit/test_player_run_context.gd`
- Modify: `tests/unit/test_run_item_ownership.gd`
- Create: `tests/unit/test_equipment_assignment_service.gd`

**Interfaces:**
- Consumes: `PlayerRunContext.item_state()`, `EquipmentEligibility.validate_equip(...)`, `EquipmentSlotIndex`, authoritative catalogs.
- Produces: `PlayerRunContext.equipment_for(member_id: int) -> ItemSlotContainer` and `assign_equipment(member_id, item_id, slot_id, equipment, foundation) -> EquipmentAssignmentResult`.

- [ ] **Step 1: Write RED run-equipment and assignment tests**

Require configuration to create `run-equipment-%03d` for every existing party member, owned by `run_player_id`, with capacity eleven and empty slots. Recruit after configuration and require exactly one new validated container without resetting inventory, journal, sequence, or other member equipment.

Create inventory items covering compatible armour, incompatible weight, two-handed main hand, matching/mismatching quiver, attribute failure, occupied destination, and unequip back to inventory. Assert failed proposals leave the entire ownership document byte-equivalent. Mutate every returned container/result and prove context state is unchanged.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_player_run_context.gd tests/unit/test_run_item_ownership.gd tests/unit/test_equipment_assignment_service.gd
```

Expected: missing equipment accessor/service and missing run equipment containers.

- [ ] **Step 3: Implement atomic assignment**

Build all initial member equipment containers before `configure()` commits any context field. Extend `_on_member_added()` to preview and validate a copied ownership state before committing the new container.

`EquipmentAssignmentService.preview(...)` resolves the item instance to its base, constructs the currently equipped base-definition map, calls `EquipmentEligibility.validate_equip`, applies reserved-slot rules, and returns a new state only on success. It moves exact instance IDs between existing run containers; it never issues, destroys, extracts, or persists items.

```gdscript
func equipment_for(member_id: int) -> ItemSlotContainer:
	return _item_state.container(StringName("run-equipment-%03d" % member_id)) if _item_state != null else null

func assign_equipment(
	member_id: int,
	item_id: String,
	slot_id: StringName,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentAssignmentResult:
	var result := _equipment_assignment_service.preview(_item_state, member_id, item_id, slot_id, equipment, foundation)
	if result.ok():
		_item_state = result.state()
	return result
```

Return stable diagnostics prefixed `PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR`. `PlayerRunContext.assign_equipment()` replaces its private state only from an OK result.

- [ ] **Step 4: Run GREEN and context regressions**

Run Task 3 plus run registry, reward distribution, progression, actor/presentation, and main-wiring suites. Expected: exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/equipment/equipment_assignment_result.gd scripts/equipment/equipment_assignment_service.gd scripts/run/player_run_context.gd tests/unit/test_player_run_context.gd tests/unit/test_run_item_ownership.gd tests/unit/test_equipment_assignment_service.gd
git commit -m "feat: own equipment by run member"
```

### Task 4: Durable Run Loadout Checkout and Loss

**Files:**
- Create: `scripts/run/run_item_bootstrap.gd`
- Create: `scripts/run/resumable_run_item_codec.gd`
- Create: `scripts/run/run_loadout_checkout_request.gd`
- Create: `scripts/run/run_loadout_checkout_service.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/run/player_run_context.gd`
- Create: `tests/unit/test_run_loadout_checkout_service.gd`
- Modify: `tests/unit/test_player_run_context.gd`

**Interfaces:**
- Consumes: profile leader loadout, `bring_in_gear`, `ProfileMutationService`, strict item ownership.
- Produces: `RunLoadoutCheckoutService.checkout(profile_id, request, root) -> ProfileMutationResult`, `forfeit(profile_id, run_id, root) -> ProfileMutationResult`, and `RunItemBootstrap`.

- [ ] **Step 1: Write RED checkout, replay, and loss tests**

Build a profile with a compatible leader loadout and `bring_in_gear`. Checkout must atomically remove those instances from profile `item_records`/`leader_loadout`, create an exact strict run ownership snapshot under `resumable_run`, and return a defensive bootstrap that places the same item instances into `run-equipment-001`. There must be no moment when durable profile bytes serialize the same instance in both ownership domains.

Cover empty loadout; absent `bring_in_gear`; incompatible class; transaction replay and collision; active resumable run; wrong profile/run/player/leader identity; injected save failure; defensive request/bootstrap results; and starting a context from the bootstrap. Every failure preserves profile bytes and creates no configured context item state.

Call `forfeit()` for a full-death fixture and require the matching resumable run and every checked-out item to be removed in one profile mutation. Wrong/stale run ID, replay, collision, and save failure must preserve the resumable run and its items. Forfeit does not call `SANDBOX_REMOVE`; loss occurs by committing a profile candidate that deliberately clears the entire closed run ownership document.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
```

Expected: missing checkout/bootstrap/codec APIs.

- [ ] **Step 3: Implement strict resumable ownership and atomic checkout**

`RunItemBootstrap` contains `run_id`, `run_seed`, `run_player_id`, `leader_member_id`, and a defensive `ItemOwnershipState`. `ResumableRunItemCodec` encodes/decodes those exact fields and validates the item state through authoritative catalogs.

`checkout()` fingerprints the complete canonical request with operation `run_loadout_checkout`. Inside one profile mutation it validates no active resumable run, rechecks the selected class against the loadout, copies the equipped instances into the run registry/equipment container, removes them from the profile registry/loadout candidate, stores the exact encoded bootstrap in `resumable_run`, and validates both ownership domains before save.

```gdscript
func checkout(profile_id: String, request: RunLoadoutCheckoutRequest, root: String) -> ProfileMutationResult:
	return _mutations.apply(
		profile_id,
		request.transaction_id,
		&"run_loadout_checkout",
		request.canonical_document(),
		func(candidate: ProfileState) -> String: return _apply_checkout(candidate, request),
		root,
	)

func forfeit(profile_id: String, run_id: StringName, root: String) -> ProfileMutationResult:
	var request_document := {"run_id": String(run_id)}
	return _mutations.apply(profile_id, "forfeit:%s" % run_id, &"run_loadout_forfeit", request_document, _forfeit_candidate.bind(run_id), root)
```

Extend `PlayerRunContext.configure(...)` with an optional final `item_bootstrap: RunItemBootstrap = null` parameter. Existing callers remain source-compatible. A supplied bootstrap must exactly match profile ID, seed, run-player ID, and leader member; its state replaces only the empty candidate run item state after strict validation. Failed matching leaves the context fully unconfigured and retryable.

`forfeit()` uses operation `run_loadout_forfeit`, requires exact run ID, and clears the entire matching resumable run candidate. It never reconstructs those items in profile storage.

- [ ] **Step 4: Run GREEN and durability regressions**

Run Task 4 plus profile codec/migration/store/mutation, run context/registry, item ownership, and class eligibility suites. Expected: exit `0`, replay performs no write, and failure hashes remain identical.

- [ ] **Step 5: Commit**

```powershell
git add scripts/run scripts/profile/profile_codec.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_player_run_context.gd
git commit -m "feat: check leader loadout into runs"
```

### Task 5: Creator-Authored Leader Extraction Unlock

**Files in `E:\Projects\Passive Skill Tree Creator`:**
- Modify: `samples/party-forge-city.pstree`
- Modify: `samples/party-forge-city.pstree.json`
- Modify: `integrations/godot/demo/party-forge-city.pstree.json`
- Modify: `src/core/serialization/party-forge-city-fixture.test.ts`

**Files in Party Forge:**
- Modify: `data/passive_trees/city/party-forge-city.pstree`
- Modify: `data/passive_trees/city/party-forge-city.pstree.json`
- Modify: `tests/unit/test_passive_tree_artifact_sync.gd`
- Modify: `tests/unit/test_passive_tree_contracts.gd`
- Modify: `tests/unit/test_passive_tree_progression_service.gd`

**Interfaces:**
- Consumes: existing `secured-loadout` node and deterministic Creator serialization.
- Produces: node `leader-loadout-extraction` with `feature_unlock(featureId=leader_loadout_extraction)`.

- [ ] **Step 1: Reconcile the authoritative Creator fixture before editing**

Create an isolated Creator worktree from current Creator `main`. Copy the already reviewed 30-node Party Forge `.pstree` and runtime export into the Creator sample/demo locations, then update the Creator fixture test to match those exact semantics. Run:

```powershell
npm test -- src/core/serialization/party-forge-city-fixture.test.ts
npm run typecheck
```

Expected: both pass before the new node is authored. Do not use or delete any pre-existing `.autosave` file.

- [ ] **Step 2: Write the failing new-node contract**

Require one new large permanent node and one new bidirectional connection:

```ts
expect(node("leader-loadout-extraction")).toMatchObject({
  name: "Leader Loadout Extraction",
  type: "large",
  cost: 1,
  effects: [{
    effectId: "feature_unlock",
    operation: "set",
    value: true,
    parameters: { featureId: "leader_loadout_extraction" }
  }],
  metadata: {
    developmentState: "coming-soon",
    refundPolicy: "permanent"
  }
});
expect(connectionFromTo("secured-loadout", "leader-loadout-extraction")).toBe(true);
```

Run the fixture test. Expected: failure because the node and connection do not exist.

- [ ] **Step 3: Author and export through Latticewright**

Open `samples/party-forge-city.pstree` in Latticewright. Add the exact node/effect/metadata and a bidirectional zero-cost connection after `secured-loadout`. Place it at deterministic coordinates beyond that branch without moving existing nodes. Save the `.pstree`, export canonical runtime JSON, and copy identical runtime bytes to the Godot demo.

Run fixture, complete Creator unit tests, typecheck, and lint. Commit the Creator change before copying artifacts into Party Forge.

- [ ] **Step 4: Copy exact artifacts and run Party Forge RED/GREEN**

First extend Party Forge tests to require semantic source/runtime equality, the new node/effect, permanent refund policy, adjacency to `secured-loadout`, and allocation only after its path is satisfied. Confirm RED against old artifacts. Then copy the committed Creator source/export byte-for-byte into Party Forge and rerun.

Expected: artifact, loader, contract, progression, mutation, view-model, and screen suites pass.

- [ ] **Step 5: Commit Party Forge artifacts**

```powershell
git add data/passive_trees/city tests/unit/test_passive_tree_artifact_sync.gd tests/unit/test_passive_tree_contracts.gd tests/unit/test_passive_tree_progression_service.gd
git commit -m "feat: add leader loadout extraction unlock"
```

### Task 6: Pure Extraction Eligibility and Precedence

**Files:**
- Create: `scripts/extraction/extraction_selection.gd`
- Create: `scripts/extraction/run_extraction_projection.gd`
- Create: `scripts/extraction/run_extraction_policy.gd`
- Create: `tests/unit/test_run_extraction_policy.gd`

**Interfaces:**
- Consumes: configured `PlayerRunContext`, `ProfileState.extraction_capacity`, `permanent_feature_unlocks`, party leader/member IDs.
- Produces: `RunExtractionPolicy.project(context, profile, selections) -> RunExtractionProjection`.

- [ ] **Step 1: Write the RED extraction matrix**

Build one leader item, two follower items, and two inventory items. Without `leader_loadout_extraction`, require all five to be eligible and no automatic items. With the unlock, require the leader item automatic, exactly four ordinary eligible items, and zero leader IDs in the eligible set.

Test capacities zero, one, and three; duplicate selections; unknown item; item outside the profile's context; selection of automatic leader gear; more selections than capacity; repeated allocation/unlock strings; defensive results; and deterministic ordering by member role/member ID/equipment index, then inventory slot.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd
```

Expected: missing extraction domain classes.

- [ ] **Step 3: Implement immutable selection/projection records and pure policy**

`ExtractionSelection` contains `item_id` and its expected source container/slot. `RunExtractionProjection` contains defensive arrays `automatic_item_ids`, `eligible_items`, `selected_item_ids`, `lost_item_ids`, plus `capacity`, `valid`, and stable errors.

The policy deduplicates profile unlocks, derives the leader from `PartyManager`, and applies automatic leader precedence before validating ordinary selections. It reads only defensive context/profile projections. It never mutates a context, profile, container, registry, or item.

```gdscript
static func project(
	context: PlayerRunContext,
	profile: ProfileState,
	selections: Array[ExtractionSelection],
) -> RunExtractionProjection:
	var automatic_leader := "leader_loadout_extraction" in profile.permanent_feature_unlocks
	return _build_projection(context.item_state(), context.party, profile.extraction_capacity, automatic_leader, selections)
```

- [ ] **Step 4: Run GREEN and ownership regressions**

Run Task 5 twice, then context ownership, item ownership, passive resolution, and profile state suites. Expected: identical ordering and exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/extraction tests/unit/test_run_extraction_policy.gd
git commit -m "feat: project extraction eligibility"
```

### Task 7: Atomic Successful-Run Resolution

**Files:**
- Create: `scripts/extraction/run_resolution_request.gd`
- Create: `scripts/extraction/run_resolution_result.gd`
- Create: `scripts/extraction/run_resolution_service.gd`
- Modify: `scripts/run/player_run_context.gd`
- Create: `tests/unit/test_run_resolution_service.gd`

**Interfaces:**
- Consumes: `RunExtractionPolicy.project(...)`, `ProfileMutationService`, strict run/profile ownership states.
- Produces: `RunResolutionService.resolve(profile_id, context, request, root) -> RunResolutionResult`, `PlayerRunContext.item_resolution_error(transaction_id) -> String`, and `mark_items_resolved(transaction_id) -> void`.

- [ ] **Step 1: Write RED atomic-resolution tests**

Cover one ordinary leader extraction before the unlock; one follower and one inventory choice; full automatic leader extraction after the unlock; automatic leader plus ordinary follower; exact instance data preservation; loadout slot preservation; deterministic first-empty stash placement; lost items omitted; replay; transaction collision; stale expected source; insufficient stash; invalid profile; injected save failure; and a context already resolved.

For every failure assert no returned profile, unchanged profile file hash/bytes, unchanged context ownership, and unresolved context. On replay assert no new write and no second context mutation.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_resolution_service.gd
```

Expected: missing request/result/service.

- [ ] **Step 3: Implement proposal-first cross-domain transfer**

The request contains a stable resolution transaction ID and exact ordinary selections. The service fingerprints the complete canonical request through `ProfileMutationService`. Inside one candidate mutation it:

1. Requires `profile.resumable_run` to decode successfully and exactly match the request/context run identity.
2. Revalidates the extraction projection against that checked-out ownership snapshot and the live context.
3. Copies selected and automatic `ItemInstance` records without rerolling.
4. Places automatic leader items into their matching profile equipment indices.
5. Places ordinary selections into deterministic first-empty stash slots.
6. Clears the matching `resumable_run` candidate so no item remains serialized in two ownership domains.
7. Builds and strictly validates the complete profile registry/loadout/stash ownership state.
8. Returns the candidate for one atomic save.

Before saving, the service calls `context.item_resolution_error(transaction_id)`; an already resolved context accepts only the same ID. After that successful preflight, `mark_items_resolved()` is an infallible local assignment and runs only after save success. Run-only lost items require no production remove operation because the resolved context becomes closed and is discarded as a whole.

```gdscript
func resolve(
	profile_id: String,
	context: PlayerRunContext,
	request: RunResolutionRequest,
	root: String,
) -> RunResolutionResult:
	var marker_error := context.item_resolution_error(request.transaction_id)
	if not marker_error.is_empty():
		return RunResolutionResult.failure(marker_error)
	var mutation := _mutations.apply(profile_id, request.transaction_id, &"run_resolution", request.canonical_document(), _resolve_candidate.bind(context, request), root)
	if not mutation.ok():
		return RunResolutionResult.failure(mutation.error)
	context.mark_items_resolved(request.transaction_id)
	return RunResolutionResult.success(mutation.profile, mutation.duplicate)
```

- [ ] **Step 4: Run GREEN and persistence regressions**

Run Task 7 plus profile mutation/storage, atomic store, extraction policy, context ownership, checkout, and item codec suites. Expected: exit `0`, no profile writes on failure/replay.

- [ ] **Step 5: Commit**

```powershell
git add scripts/extraction scripts/run/player_run_context.gd tests/unit/test_run_resolution_service.gd
git commit -m "feat: resolve successful run extraction"
```

### Task 8: Class Compatibility and Explicit Loadout Transition

**Files:**
- Create: `scripts/equipment/loadout_compatibility_projection.gd`
- Create: `scripts/equipment/loadout_compatibility_service.gd`
- Create: `scripts/equipment/loadout_transition_request.gd`
- Create: `scripts/equipment/loadout_transition_service.gd`
- Create: `tests/unit/test_loadout_transition_service.gd`

**Interfaces:**
- Consumes: profile leader loadout, stash, item registry, `EquipmentEligibility`, selected `ClassDefinition`.
- Produces: `LoadoutCompatibilityService.project(profile, class_definition, equipment, foundation) -> LoadoutCompatibilityProjection` and `LoadoutTransitionService.apply(profile_id, request, root) -> ProfileMutationResult`.

- [ ] **Step 1: Write RED compatibility and overflow tests**

Require projection of compatible and incompatible items with exact eligibility reasons. Test same-class fully compatible, mixed loadout, enough stash, partially full multi-tab stash, no stash space, deterministic canonical equipment-slot order, and defensive results.

The transition request includes selected class ID, exact incompatible item/source list, exact planned stash destinations, exact overflow IDs, and a confirmation token. Prove that missing/stale token, changed stash, changed loadout, wrong class, cancellation, replay collision, and save failure preserve bytes and items. A valid nonoverflow request moves all incompatible items. A valid overflow request destroys only exact confirmed overflow IDs.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_loadout_transition_service.gd
```

Expected: missing compatibility/transition services.

- [ ] **Step 3: Implement preflight and policy-level destruction**

The compatibility service resolves each equipped instance's base and calls `EquipmentEligibility.validate_equip` with the accumulating compatible loadout. The projection sorts by `EquipmentSlotIndex` and derives deterministic first-empty stash destinations.

The transition service recomputes the projection inside `ProfileMutationService`, compares the complete canonical request/fingerprint, and commits either all stash moves or all moves plus the exact confirmed overflow deletions. Overflow deletion rebuilds the candidate registry/container documents and strictly validates them; it never calls `SANDBOX_REMOVE` and is callable only with a valid confirmation token equal to the SHA-256 of the canonical selected-class/source/destination/overflow projection.

```gdscript
func project(
	profile: ProfileState,
	class_definition: ClassDefinition,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> LoadoutCompatibilityProjection:
	return _project_exact(profile, class_definition, equipment, foundation)

func apply(profile_id: String, request: LoadoutTransitionRequest, root: String) -> ProfileMutationResult:
	return _mutations.apply(profile_id, request.transaction_id, &"loadout_transition", request.canonical_document(), _apply_candidate.bind(request), root)
```

- [ ] **Step 4: Run GREEN and destructive-boundary regressions**

Run Task 8 plus profile storage, item transactions, codec, atomic-store, checkout, and class/equipment contract suites. Expected: exit `0`; a repository search shows no production call to `SANDBOX_REMOVE` outside the isolated developer sandbox.

- [ ] **Step 5: Commit**

```powershell
git add scripts/equipment tests/unit/test_loadout_transition_service.gd
git commit -m "feat: validate retained loadout transitions"
```

### Task 9: Armoury Equipment and Stash Interface

**Files:**
- Create: `scripts/ui/armoury/armoury_projection.gd`
- Create: `scripts/ui/armoury/armoury_screen.gd`
- Create: `scenes/ui/armoury/armoury_screen.tscn`
- Modify: `scripts/ui/main_menu/main_menu_projection.gd`
- Modify: `scripts/ui/main_menu/main_menu_view_model.gd`
- Modify: `scripts/ui/main_menu/main_menu_screen.gd`
- Modify: `scenes/ui/main_menu/main_menu_screen.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_armoury_screen.gd`
- Modify: `tests/unit/test_main_menu_view_model.gd`
- Modify: `tests/unit/test_main_menu_screen.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: defensive profile item/loadout/stash projections and FeatureAccessPolicy.
- Produces: `MainMenuViewModel.ROUTE_ARMOURY`, `ArmouryScreen.open(profile, return_focus)`, `close_requested`, and item move/equip intent signals.

- [ ] **Step 1: Write RED route and screen tests**

Require Armoury hidden before equipment unlock, visible/available after the implemented equipment unlock, and visible as Developer Preview only in Developer Mode. Direct route invocation must recheck access.

Instantiate the screen and require eleven equipment buttons in canonical slot order, every materialized 100-slot stash tab, icon/name/rarity/item-level/affix inspector, controller focus containment, mouse/controller selection, move/equip intent emission, and no direct mutation of the supplied profile. Closing returns focus to the Armoury main-menu action.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_armoury_screen.gd tests/unit/test_main_menu_view_model.gd tests/unit/test_main_menu_screen.gd tests/unit/test_main_wiring.gd
```

Expected: missing route, projection fields, scene, and screen.

- [ ] **Step 3: Implement feature-gated Armoury composition**

Add projection fields `armoury_label/visible/enabled/route_id`, action button/focus wiring, and the exact route ID `&"armoury"`. Build the screen as a process-always modal above the main menu with equipment sheet left, scrollable stash right, inspector, profile label, status, and Close.

```gdscript
# main_menu_view_model.gd
const ROUTE_ARMOURY: StringName = &"armoury"

# armoury_screen.gd
signal close_requested
signal move_requested(item_id: String, destination_container_id: StringName, destination_slot: int)
signal equip_requested(item_id: String, equipment_slot_id: StringName)

func open(profile: ProfileState, return_focus: Control = null) -> void:
	_projection = ArmouryProjection.from_profile(profile)
	_return_focus = return_focus
	visible = true
	_render_projection()
```

`PartyForgeMain` loads the current profile, rechecks the unlock/developer policy, hides the main menu, opens Armoury, delegates move/equip intents through profile services, refreshes from a newly loaded defensive profile, and restores focus on close. No screen script edits item dictionaries.

Add a labelled blockout Armoury hotspot/action representing the future clickable city building. Its route is identical to the menu Armoury route; later city art may replace the button without changing the signal contract.

- [ ] **Step 4: Run GREEN and responsive UI gate**

Run Task 9 plus settings, feature-access, ledger, main-menu navigation, and controller-input suites. Add an integration runner at 1920x1080, 2560x1440, and 3840x2160 proving equipment/stash/inspector reachability and focus containment.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ui/armoury scenes/ui/armoury scripts/ui/main_menu scenes/ui/main_menu scripts/game/main.gd scenes/game/main.tscn tests/unit tests/integration
git commit -m "feat: add profile Armoury interface"
```

### Task 10: Two-Stage Incompatible-Class Warning

**Files:**
- Create: `scripts/ui/loadout_warning/loadout_warning_dialog.gd`
- Create: `scenes/ui/loadout_warning/loadout_warning_dialog.tscn`
- Modify: `scripts/ui/class_selection_panel.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_loadout_warning_dialog.gd`
- Modify: `tests/unit/test_class_selection_panel.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: `LoadoutCompatibilityProjection`, `LoadoutTransitionService`.
- Produces: warning actions `go_to_armoury`, `choose_another_class`, `continue_anyway`, `destroy_confirmed`, and `cancelled`.

- [ ] **Step 1: Write RED warning-state tests**

Require compatible selection to start normally. For incompatible gear, require the first warning to list exact item names/reasons and expose Go to Armoury, Choose Another Class, and Continue Anyway. If stash fits, Continue submits the nonoverflow transition. If stash does not fit, it opens a second warning with exact moved and destroyed item lists.

Require the destructive control to ignore a tap, ordinary accept, and hold shorter than 1.25 seconds. Holding the explicit destroy action for at least 1.25 seconds emits one confirmation with the exact token. Cancel/back at either stage changes nothing. Controller and mouse paths must be equivalent.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_loadout_warning_dialog.gd tests/unit/test_class_selection_panel.gd tests/unit/test_main_wiring.gd
```

Expected: missing warning dialog and class-selection gate.

- [ ] **Step 3: Implement the explicit state machine**

Use states `CLOSED`, `INCOMPATIBLE`, and `DESTRUCTIVE_CONFIRMATION`. The dialog consumes only a defensive projection. It resets hold progress on release, focus loss, cancel, projection replacement, or close. It emits intents and never calls storage services.

```gdscript
enum State { CLOSED, INCOMPATIBLE, DESTRUCTIVE_CONFIRMATION }
const DESTRUCTIVE_HOLD_SECONDS := 1.25

signal go_to_armoury
signal choose_another_class
signal continue_anyway
signal destroy_confirmed(confirmation_token: String)
signal cancelled

func advance_destroy_hold(delta: float, held: bool) -> void:
	_hold_seconds = _hold_seconds + delta if held and _state == State.DESTRUCTIVE_CONFIRMATION else 0.0
	if _hold_seconds >= DESTRUCTIVE_HOLD_SECONDS:
		destroy_confirmed.emit(_projection.confirmation_token)
		_hold_seconds = 0.0
```

`PartyForgeMain.select_leader_class()` projects compatibility before creating the run. Compatible selection invokes `RunLoadoutCheckoutService.checkout()` and configures the context only from its committed bootstrap. Incompatible selection opens the dialog. Armoury redirection preserves the selected class ID only for display, and returning requires the player to select/confirm again. A successful transition reloads the profile, revalidates compatibility, performs the same atomic checkout, then starts the run from the committed bootstrap.

- [ ] **Step 4: Run GREEN and live input regression**

Run Task 10 plus class selection, pause/settings modal focus, main-menu, and controller suites. Add a windowed runner proving keyboard/mouse and controller warnings, cancellation, hold duration, Armoury redirect, and focus restoration.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ui/loadout_warning scenes/ui/loadout_warning scripts/ui/class_selection_panel.gd scripts/game/main.gd scenes/game/main.tscn tests/unit tests/integration
git commit -m "feat: warn before incompatible loadout loss"
```

### Task 11: Per-Profile Local Multiplayer Coordination

**Files:**
- Create: `scripts/run/local_run_setup_participant.gd`
- Create: `scripts/run/local_run_setup_coordinator.gd`
- Create: `tests/unit/test_local_run_setup_coordinator.gd`
- Modify: `tests/unit/test_run_context_registry.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: joined profile/device assignments, selected classes, compatibility projections, transition results.
- Produces: `LocalRunSetupCoordinator.begin(participants)`, `decision_required(profile_id, projection)`, `submit(profile_id, decision)`, and `ready_contexts()`.

- [ ] **Step 1: Write RED independent-profile tests**

Create four profiles with different unlocks, extraction capacities, loadouts, stash space, selected classes, and devices. Require each compatibility gate to use only its profile. One unresolved warning blocks run start without blocking another participant's Armoury inspection. Cancellation returns the entire setup to editable state without mutating any profile. Successful decisions produce contexts in player-slot order.

Prove one player's stash move/destruction cannot affect another profile's bytes or item IDs. Reject duplicate profile, duplicate device, stale decision, profile swap during pending setup, and submissions after coordinator lock.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_local_run_setup_coordinator.gd tests/unit/test_run_context_registry.gd tests/unit/test_main_wiring.gd
```

Expected: missing coordinator/participant types.

- [ ] **Step 3: Implement the coordinator**

Each participant record contains profile ID, device ID, player slot, selected class ID, and current decision state. `begin()` validates uniqueness and captures defensive inputs. `submit()` applies/reloads only the named profile, refreshes that participant's projection, and marks readiness only after compatibility is clean. `ready_contexts()` returns an empty array until every participant is ready, then locks the coordinator and returns stable player-slot order.

```gdscript
signal decision_required(profile_id: String, projection: LoadoutCompatibilityProjection)

func begin(participants: Array[LocalRunSetupParticipant]) -> PackedStringArray:
	return _validate_and_capture(participants)

func submit(profile_id: String, decision: Dictionary) -> PackedStringArray:
	return _apply_profile_decision(profile_id, decision)

func ready_contexts() -> Array[PlayerRunContext]:
	if _locked or _participants.any(func(value: LocalRunSetupParticipant) -> bool: return not value.ready):
		return []
	_locked = true
	return _contexts_in_slot_order()
```

The coordinator stores no shared inventory, stash, loadout, extraction capacity, or gold. Arena mode remains join-before-run; Adventure drop-in behavior remains outside this plan.

- [ ] **Step 4: Run GREEN and four-player regression**

Run Task 11 plus profiles settings, run registry, reward distribution, main wiring, and controller ownership suites. Expected: exit `0` with stable participant ordering.

- [ ] **Step 5: Commit**

```powershell
git add scripts/run/local_run_setup_participant.gd scripts/run/local_run_setup_coordinator.gd tests/unit/test_local_run_setup_coordinator.gd tests/unit/test_run_context_registry.gd tests/unit/test_main_wiring.gd
git commit -m "feat: coordinate per-profile loadout setup"
```

### Task 12: Documentation, Full Verification, and Final Review

**Files:**
- Create: `docs/handbook/11-equipment-stash-and-extraction.md`
- Create: `docs/verification/2026-08-05-leader-loadout-extraction-continuity.md`
- Modify: `docs/handbook/README.md`

**Interfaces:**
- Consumes: all Tasks 1-11.
- Produces: player/developer behavior guide, content-authoring guide, and reproducible verification evidence.

- [ ] **Step 1: Write the handbook acceptance checklist before documentation**

Create a focused documentation test or static assertions requiring the new handbook page to name the exact profile/run containers, extraction precedence, Creator artifact path, Armoury route, class warning states, 1.25-second destructive hold, per-profile multiplayer isolation, and Developer Mode behavior. Confirm RED while the page is absent.

- [ ] **Step 2: Write the handbook page**

Document how to:

- Inspect active loadout and stash data without editing JSON.
- Add equipment eligibility tags and verify them.
- Modify the City node through Latticewright and re-export safely.
- Test ordinary versus full leader extraction.
- Diagnose a rejected transition using stable error prefixes.
- Use Developer Mode without granting Player Mode unlocks.

Include the warning that sandbox removal is never a production destruction API.

- [ ] **Step 3: Run complete automated verification**

Run a clean Godot import, resource probe, all focused new suites, the complete suite, and `git diff --check`. Run Creator fixture/unit/typecheck/lint gates against its exact committed artifact SHA. Reject any run with a crash, timeout, absent summary, or unexpected parse/script/loader failure even if a PASS marker printed.

- [ ] **Step 4: Run rendered/controller acceptance**

At 1080p, 1440p, and 4K verify Armoury layout, stash scrolling, item inspection, compatible repeated-class start, incompatible warning, Armoury redirect, safe cancellation, sufficient-stash move, exact overflow list, destructive hold, and focus restoration. Repeat with two and four local profiles using distinct controllers. Record physical-controller checks separately from synthetic input.

- [ ] **Step 5: Independent complete-range review and commit**

Review the entire implementation range plus the Creator artifact commit for Critical, Important, and Minor findings. Correct every Critical/Important finding test-first and re-review the complete range. Commit the handbook/verification documents only after final evidence is recorded:

```powershell
git add docs/handbook docs/verification
git commit -m "docs: verify leader loadout extraction continuity"
```

Final acceptance requires a clean worktree, no verification-created sidecars, exact Creator/game artifact equality, and no unresolved Critical or Important findings.
