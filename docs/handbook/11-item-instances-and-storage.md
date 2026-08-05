# 11. Item Instances and Fixed-Slot Storage

> **Item ownership foundation:** Plan 4B implementation through `d4688b9a9744fb06dce2e9e051e7b93f6d569204`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-08-05`

## What you will learn

By the end of this chapter, you will be able to:

- distinguish an authored equipment base from one issued item;
- add a development rarity or deterministic affix fixture without implying a production loot generator;
- trace item identity, location, transactions, and persistent commits through their owners;
- read a fixed-slot container document without mistaking omitted empty slots for compaction;
- explain how the City passive tree materializes run-inventory and profile-stash capacity;
- open and operate the isolated Developer Item Sandbox with mouse, keyboard, or controller; and
- identify what Plan 4B deliberately leaves unavailable and which later plan owns named follow-up work.

## Equipment bases are templates; item instances are owned records

Party Forge keeps authored equipment content and issued item state separate:

| Concern | `EquipmentBaseDefinition` | `ItemInstance` |
| --- | --- | --- |
| Schema | `scripts/equipment/equipment_base_definition.gd` | `scripts/items/item_instance.gd` |
| Current data source | One of 99 definitions in `data/equipment/core_equipment_catalog.tres` | Created by `scripts/items/item_instance_issuer.gd` and serialized in an owner registry |
| Identity | Stable content ID such as `forge_vanguard_sword` | Opaque `instance_id` unique within the complete item system |
| Describes | Name, item type, compatible/reserved slots, weight, requirements, handedness, weapon/implicit family hooks, and presentation | Base-definition reference, item level, rarity, ordered affix instances with exact rolls, and issuance origin |
| Changes when moved | No | Its record still does not change; only a container's instance-ID reference moves |
| Ownership | Shared read-only catalog content | Exactly one record in one owner-scoped `ItemRegistry`, referenced by exactly one slot |

An `EquipmentBaseDefinition` is therefore not loot. It is the reusable template that says what a Forge Vanguard Sword is. Two issued swords can reference the same base while owning different instance IDs, levels, rarities, affix tiers, rolls, and origins.

`ItemInstance` is a `RefCounted` runtime value, not a saved `.tres` Resource. Its schema-one document has the exact fields `affixes`, `base_definition_id`, `instance_id`, `item_level`, `origin`, `rarity_id`, and `schema_version`. It intentionally has no mutable `owner_id`, `container_id`, or `slot` field. Ownership and location come from the enclosing `ItemOwnershipState` and its containers, so there is no second location to drift out of agreement.

> **Party Forge convention:** Definitions are shared read-only templates. Issued items are copied at public boundaries, live once in an owner registry, and move only by changing a validated container reference.

## Why issued affix rolls stay explicit

The authored definitions in `data/items/core_item_foundation_catalog.tres` describe what may be issued. For example, the current `stout` prefix declares Constitution, the `FLAT` operation, tiers 1 through 3, and one minimum/maximum range per tier. An issued affix stores the chosen definition ID, kind, tier, operation, stat, required tags, and exact numeric roll:

```json
{
  "affix_kind": "prefix",
  "definition_id": "stout",
  "rolls": [{
    "operation": 0,
    "required_tags": [],
    "stat_id": "constitution",
    "value": 3.0
  }],
  "tier": 1
}
```

`origin.seed` records reproducible provenance; it is not an instruction to reroll during load. `scripts/items/item_instance_codec.gd` validates the serialized affix and then copies its explicit tier and roll into the item. It does not ask the catalog to generate a replacement value. `tests/unit/test_item_instance_codec.gd` pins the byte-equivalent round trip and proves that changing a definition after decode does not rewrite the already issued roll.

This separation matters whenever balance data changes. New issuance may use new ranges, but an ordinary load must not silently improve or weaken saved gear. If a definition change would make historical documents invalid under current validation, handle that as a reviewed item-schema/data migration; do not turn load into a hidden reroll.

> **Current limitation:** Plan 4B validates and preserves modifier records but does not apply them to character stats.

## Add a development rarity

The rarity schema is `scripts/items/item_rarity_definition.gd`; the current catalog is `data/items/core_item_foundation_catalog.tres` and is loaded as `GameCatalog.ITEM_FOUNDATION_CATALOG` in `scripts/data/game_catalog.gd`.

To add a rarity safely:

1. Open `data/items/core_item_foundation_catalog.tres` in the Inspector.
2. Add an `ItemRarityDefinition` entry to `rarities` and give it a unique lowercase `snake_case` `id`, a non-empty display name, and a nonnegative inclusive affix-count range.
3. Decide deliberately whether `functional` is enabled. Current functional development rarities are Common, Uncommon, Rare, Epic, and Legendary. Mythic and Eternal are registered with `functional = false` and cannot be issued by the current codec or default sandbox fixture.
4. Save and review the exact `.tres` diff. Registration is the ordered `rarities` array; merely creating a Resource elsewhere does not add it to the catalog.
5. Run the foundation, codec, and sandbox-state suites before accepting the change.

The default fixture in `scripts/dev/developer_item_fixture_issuer.gd` requires exactly five functional rarity IDs and cycles through them in catalog order. Adding another functional rarity is therefore a behavior and fixture-contract change, not a data-only append. Update that issuer and its tests intentionally or keep the new future rarity nonfunctional.

## Add a deterministic affix fixture

The affix schema is `scripts/items/item_affix_definition.gd`. Each current entry in `data/items/core_item_foundation_catalog.tres` declares:

- a unique ID and display name;
- one kind: `implicit`, `prefix`, `suffix`, or `special`;
- an inclusive tier range;
- a registered `stat_id` from `data/stats/core_stats.tres`;
- one supported `StatModifier.Operation`;
- exactly one minimum and maximum roll for every tier; and
- optional required tags.

Use the current `of_reach` suffix as a concrete pattern: tiers 1 through 3 target `attack_range` with the `INCREASED` operation and nonoverlapping roll ranges. Add the new built-in `ItemAffixDefinition` to the catalog's ordered `affixes` array, validate its stat and tier rows, and review the `.tres` diff.

The sandbox fixture is deterministic without a second authored fixture file. `DeveloperItemFixtureIssuer._fixture_affixes()`:

1. chooses definitions by `(equipment_definition_index + affix_index) % foundation.affixes.size()`;
2. chooses a tier by the same stable index pattern within the definition's tier range;
3. uses the midpoint of that tier's minimum and maximum as the explicit roll; and
4. copies the definition's kind, stat, operation, and required tags into the issued record.

Rarity `minimum_affixes` decides how many fixture affixes an item receives. Adding or reordering an affix changes that deterministic sequence and the canonical 99-item fixture. Use **Reset** in the Developer Item Sandbox after the catalog change, and expect the deterministic fixture hash to change in focused acceptance evidence.

From the repository root, a focused authoring check is:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_foundation_catalog.gd
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_instance_codec.gd
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox_state.gd
```

Each command must exit `0` and print `TEST_SUMMARY: PASS (0 failures)`. A catalog load alone does not prove the 99-item reset contract.

## Registry, container, and transaction ownership flow

The runtime flow is:

```text
EquipmentBaseDefinition
        |
        v
ItemInstanceIssuer -> ItemInstance
        |
        v
ItemRegistry -- complete item records keyed by instance_id
        |
        +-> ItemSlotContainer -- fixed slot -> instance_id only
        |
        v
ItemOwnershipState -- one owner, one registry, all of that owner's containers
        |
        v
ItemContainerTransactionService -- validate -> copy -> mutate candidate -> validate
        |
        +-> run: PlayerRunContext accepts the returned candidate
        +-> profile: ProfileItemStorageService commits through ProfileMutationService
        +-> sandbox: DeveloperItemSandboxState atomically saves, then commits memory
```

The responsibilities are intentionally narrow:

| Owner | Current path | Responsibility |
| --- | --- | --- |
| Item record | `scripts/items/item_instance.gd` | Immutable-by-convention issued values and defensive deep copies |
| Registry | `scripts/items/item_registry.gd` | One canonical copied record per unique instance ID; sorted serialization |
| Container | `scripts/items/item_slot_container.gd` | Owner, kind, capacity, and sparse fixed slot-to-ID references |
| Ownership aggregate | `scripts/items/item_ownership_state.gd` | Matching owner IDs and exactly one container reference for every registry item |
| Transaction request | `scripts/items/item_transaction_request.gd` | Canonical create, move, swap, or sandbox-removal intent and fingerprint |
| Candidate mutation | `scripts/items/item_container_transaction_service.gd` | Replay/collision checks, preconditions, copy-on-write mutation, and complete candidate validation |
| Persistent profile commit | `scripts/profile/profile_item_storage_service.gd` | Rebuild strict profile ownership and save one successful candidate through the profile mutation boundary |

Public registry, container, item, journal, and ownership accessors return copies. A caller cannot obtain a mutable reference and bypass the transaction service. A successful transaction returns a new validated state; a rejection returns no partial state. Reusing a transaction ID with the same request is a replay, while reusing it for different request bytes is a collision.

The four Plan 4B operations are `create_and_place`, `move_to_empty`, `swap_occupied`, and `sandbox_remove`. The last operation is restricted to disposable sandbox behavior. It is not a production discard or destruction API.

## How fixed slot indices serialize

`ItemSlotContainer.to_dictionary()` writes six exact fields: `schema_version`, `container_id`, `container_kind`, `owner_id`, `capacity`, and `slots`. The `slots` object contains only occupied slots, using canonical unsigned decimal strings:

```json
{
  "schema_version": 1,
  "container_id": "stash-tab-000",
  "container_kind": "profile_stash_tab",
  "owner_id": "profile-storage01",
  "capacity": 100,
  "slots": {
    "0": "item-first",
    "42": "item-existing-placement"
  }
}
```

Slots are zero-based and valid from `0` through `capacity - 1`. In this example, slot 42 remains slot 42 after save/reload. Missing keys mean empty positions; they do not cause later items to slide left. Keys such as `"042"`, `"+42"`, or `"-1"` are rejected, and serialization orders occupied numeric indices ascending.

The registry separately stores the complete `ItemInstance` documents. A slot stores only an instance ID, and `ItemOwnershipState.validate()` rejects unknown IDs, orphan registry items, and IDs referenced by more than one slot.

> **Party Forge convention:** Never compact item containers automatically. Search, sort, or filter may change a future view, but only an explicit transaction may change serialized placement.

## How passive storage capacity materializes

The current City passive-tree runtime artifact is `data/passive_trees/city/party-forge-city.pstree.json`. Its editable Creator project is `data/passive_trees/city/party-forge-city.pstree`; update and export through the Passive Skill Tree Creator rather than hand-editing only the runtime JSON.

Two City nodes supply the current storage contracts:

| Node | Effect | Materialized result |
| --- | --- | --- |
| `field-pack` | `inventory_columns`, `add_flat`, value `1`, scope `profile` | `ProfileState.inventory_columns` becomes at least 1; a new `PlayerRunContext` creates `run-inventory` with `5 * inventory_columns` slots |
| `stash-access` | `stash_tabs`, `add_flat`, value `1`, scope `profile`, `slotsPerTab = 100` | The profile receives `stash-tab-000`, kind `profile_stash_tab`, capacity 100 |

`scripts/progression/passive_tree/passive_tree_mutation_service.gd` calls `scripts/profile/profile_storage_reconciler.gd` inside the same profile mutation that changes an allocation. The reconciler resolves the complete allocation set, builds proposed capacity, validates the complete ownership document, and only then changes the candidate profile.

Inventory columns are clamped to zero through eight. Run capacity is therefore zero through 40; a locked inventory has zero usable slots rather than a hidden free row. Existing granted columns never shrink.

Each stash tab has exactly 100 slots. New IDs use `stash-tab-%03d` from zero, and Plan 4B caps materialization at 100 tabs. Reconciliation is idempotent and monotonic: repeated allocation creates nothing extra, refunding a permanent storage node does not delete granted storage, and existing item records and exact placements are preserved.

> **Current limitation:** Capacity exists in profile/run domain state, but the player-facing Equipment & Inventory ledger page remains `Coming Soon` at `data/ui/ledger_pages/equipment_inventory.tres`.

## Open the Developer Item Sandbox

The sandbox scene is `scenes/ui/developer_item_sandbox.tscn`, its UI controller is `scripts/ui/developer_item_sandbox.gd`, and its disposable domain state/store live in `scripts/dev/developer_item_sandbox_state.gd` and `scripts/dev/developer_item_sandbox_store.gd`.

To open it from the running main scene:

1. Open **Settings** from the main menu.
2. Select the **Additional Settings** tab.
3. Change **Mode** to **Developer Mode**.
4. Choose **Apply and Return**. The sandbox route checks saved settings, so an unsaved Developer Mode draft is not enough.
5. Reopen **Settings > Additional Settings** and choose **Open Developer Item Sandbox**.

Player Simulation disables the sandbox button, and `scripts/game/main.gd` rechecks the saved mode before opening. The sandbox is not reachable from the production Equipment & Inventory ledger page.

On first open, if neither a primary sandbox document nor a valid backup exists, the sandbox creates the canonical fixture automatically. Later opens reload existing state. The fixture has owner `developer-item-sandbox`, an empty five-slot `developer-inventory`, a 100-slot `developer-stash-000`, and one item for each of the 99 equipment bases in stash slots 0 through 98. Slot 99 is empty.

## Inspect and move items

Focus or click a populated slot. The inspector shows base name, instance ID, rarity, item level, each affix/tier/operation/roll, and the derived owner, container, and slot.

Current controls are:

| Device | Inspect and navigate | Move or swap | Cancel or close |
| --- | --- | --- | --- |
| Mouse | Click a slot to inspect; click an action button to invoke it | Drag a populated slot onto an empty slot to move or an occupied slot to swap | Release outside a valid target to cancel the drag; click **Close** to close |
| Keyboard | Arrow keys or `Tab` / `Shift+Tab` move focus; `Enter` or `Space` activates the focused slot/button | Press `X` on a focused populated slot, focus a destination, then press `Enter` or `Space` | `Escape` cancels a held item first; press it again to close |
| Controller | D-pad/left stick moves focus; A/Cross activates the focused slot/button | X/Square picks up a focused populated slot; A/Cross places it on the focused destination | B/Circle cancels a held item first; press it again to close |

The focus loop includes all 105 slots, the inspector, all six action buttons, and Close. The stash scroll follows focus. **First Empty Inventory** and **First Empty Stash** move the selected item to the other container's first empty index; selecting an item already in that destination reports an error instead of rearranging it.

Every successful move or swap is immediately validated and atomically saved. You do not need to press **Save** after each move.

## Save, reload, integrity-scan, and reset

The sandbox document path is `user://developer_item_sandbox/sandbox.json`, deliberately outside `ProfileStore.DEFAULT_ROOT`. It owns no active-profile object, store, or root reference.

| Action | Current behavior |
| --- | --- |
| **Save** | Validates the complete in-memory ownership state, issuance metadata, and journal; writes a verified `.tmp`; preserves a valid previous generation as `.bak`; promotes and verifies the new primary; then clears the current integrity error. |
| **Reload** | Loads and validates the primary, falling back to a valid `.bak` when the primary is missing or invalid; only a complete decoded state replaces memory. A failed reload preserves the usable in-memory state. |
| **Integrity Scan** | Read-only validation of the complete in-memory document followed by the persisted primary document. It does not move items, rewrite bytes, or repair corruption. |
| **Reset** | Reissues the exact deterministic 99-item fixture, empties the inventory, restores stash slots 0 through 98 in catalog order, clears the move journal and transaction sequence, atomically saves, then commits the saved document to memory. |

Reset replaces disposable sandbox state; it does not reset a player profile. A failed save or failed transaction preserves the previous in-memory state and previous loadable bytes. An existing corrupt document is not silently treated as a first launch: the sandbox reports the stable `PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR` or `JSON_STORE_*` diagnostic so you can inspect it, then use **Reset** deliberately if the disposable fixture should be rebuilt.

> **Checkpoint:** Move one item from stash slot 0 to inventory slot 0, close and reopen the sandbox, and confirm the same instance returns to inventory slot 0. Run **Integrity Scan**, then **Reset**, and confirm inventory slot 0 is empty, stash slots 0 through 98 are occupied, and slot 99 is empty.

## Unavailable systems and named future ownership

Plan 4B supplies item identity, storage contracts, transactions, persistence, and a developer-only interface. It does not make the production item loop available.

| Capability unavailable in Plan 4B | Current future owner |
| --- | --- |
| Fixed equipment containers, leader equip/unequip and class eligibility, persistent leader loadout, bring-in checkout/forfeit, successful-run extraction and loss resolution, profile/run transfer, explicitly confirmed incompatible-overflow destruction, Armoury and Warehouse interfaces, and per-profile local setup coordination | Named implementation plan: **Leader Loadout Extraction Continuity** at `docs/superpowers/plans/2026-08-05-leader-loadout-extraction-continuity.md` |
| Starting followers, follower persistent equipment sheets, and permission for followers to bring prepared gear | Explicitly reserved for a separate later Barracks-tree design; the Leader Loadout plan does not claim them |
| Applying issued affix modifiers to character stats; randomized production loot and weighted affix/tier generation; ground drops and pickup; cross-player item transfer; shops and carts; crafting and salvage; rarity lights, sounds, animation, and reward presentation | Future seams only. No approved named implementation plan in the current repository owns these yet |

The production `Equipment & Inventory` page remains a focusable `Coming Soon` explanation, and Player Simulation cannot open the Developer Item Sandbox. Mythic and Eternal remain registered future rarities and are not issued. Do not describe any of these systems as complete merely because their data contracts or transaction seams now exist.

## Verification after an item-foundation change

At minimum:

1. Run `tests/unit/test_item_foundation_catalog.gd` for rarity/affix registration and validation.
2. Run `tests/unit/test_item_instance_codec.gd` for explicit values, strict decode, and deterministic issuance.
3. Run `tests/unit/test_item_ownership_state.gd` and `tests/unit/test_item_container_transactions.gd` for one-location and atomic transaction rules.
4. Run `tests/unit/test_profile_storage_reconciler.gd` for capacity materialization and exact-placement preservation.
5. Run `tests/unit/test_developer_item_sandbox_state.gd` and `tests/unit/test_developer_item_sandbox.gd` for the canonical fixture, isolation, persistence, controls, and focus.
6. Open the sandbox and inspect the changed rarity/affix at the intended resolutions and input devices.
7. Run the complete import and full test suite before integrating a production catalog change.

> **Party Forge convention:** A valid catalog is only the first layer. Item changes require identity, ownership, persistence, sandbox, and complete-suite evidence appropriate to their impact.
