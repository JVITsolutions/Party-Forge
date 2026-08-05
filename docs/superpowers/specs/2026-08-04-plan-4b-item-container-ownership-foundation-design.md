# Party Forge Plan 4B: Item and Container Ownership Foundation Design

**Status:** Approved design

**Date:** 2026-08-04

**Depends on:** Plan 4A run-context and character-progression foundation

## Purpose

Plan 4B establishes trustworthy item identity, profile/run ownership, fixed-slot storage, persistence, and development tooling. It turns the existing 99 authored equipment bases into real versioned item instances without yet exposing the production equipment or inventory loop.

The design deliberately separates immutable item data from mutable location. Each item instance exists once in an owner-scoped registry. Inventory and stash containers reference that instance by ID. All mutations go through idempotent transactions that either complete in full or change nothing.

Plan 4B keeps the player-facing Equipment and Inventory ledger page in **Coming Soon**. The new behavior is exposed only through an isolated Developer Item Sandbox and automated tests.

## Approved decisions

- Inventory and stash preserve exact manual slot placement.
- Created items preserve their explicit rolled values when balance definitions change.
- The 99 existing equipment bases are exercised through a separate Developer Item Sandbox.
- The sandbox uses an isolated disposable profile and never mutates the selected player profile.
- Plan 4B implements typed rarity and affix foundations with deterministic fixtures, not the full randomized loot generator.
- Item records live once in an owner-scoped registry; containers store only instance IDs.
- Container changes are atomic, idempotent transactions.

## Existing foundations

Plan 4B builds on these accepted project contracts:

- `EquipmentCatalog` resolves and validates 99 `EquipmentBaseDefinition` resources.
- Equipment bases already define slot compatibility, weight, capability requirements, attribute requirements, handedness, reserved slots, implicit-family hooks, and presentation links.
- `PlayerRunContext` gives every local profile an independent run ownership boundary.
- `ProfileState` already records `inventory_columns`, `stash_tabs`, `extraction_capacity`, permanent unlocks, passive allocations, and applied transaction IDs.
- The City passive tree already defines typed `inventory_columns`, `stash_tabs`, and extraction contracts.
- `stash-access` grants one 100-slot profile stash tab.
- `field-pack` grants the first five-slot inventory column.
- The current ledger keeps Equipment and Inventory visible but unavailable as Coming Soon.
- The profile store already provides atomic save, verification, backup recovery, and idempotent mutation boundaries.

The current presentation resources are authored base templates, not owned loot. Plan 4B adds the missing runtime distinction between a base definition and one rolled, movable item.

## Scope

Plan 4B implements:

- Versioned immutable item instances.
- Typed affix-instance and rarity definitions sufficient for deterministic fixtures.
- Owner-scoped canonical item registries.
- Fixed-capacity, fixed-position slot containers.
- Run inventory capacity derived from profile unlocks.
- Persistent stash tabs derived from profile unlocks.
- Atomic create, move, swap, and sandbox-removal transactions.
- Profile schema migration and storage reconciliation.
- An isolated 99-item Developer Item Sandbox.
- Integrity diagnostics and performance baselines.

Plan 4B does not implement:

- Equipping items or applying item modifiers to character stats.
- A production randomized loot generator or finalized rarity/affix balance.
- Ground drops, pickup targeting, or cleanup limits.
- Extraction, run-loss resolution, or bringing stash gear into a run.
- Cross-player transfers, dropping, production discard, or production destroy flows.
- Player-facing inventory, stash, or equipment interfaces.
- Rarity lights, sounds, animation, or other reward presentation.
- Shops, carts, crafting, salvage, or Warehouse-tree expansion.
- Stackable consumables, currencies represented as items, or item quantity fields.

## Architecture

The ownership chain is:

```text
EquipmentBaseDefinition (authored template)
        |
        v
ItemInstance (one immutable rolled item)
        |
        v
ItemRegistry (canonical record owned by one profile or run)
        |
        v
SlotContainer (fixed slot -> instance ID)
        |
        v
ItemContainerTransactionService (the only mutation boundary)
```

The item registry and its containers form one ownership domain. A registry never shares mutable item records with another profile or run context. Container accessors return defensive copies or read-only projections.

Moving an item changes only the source and destination slot references. It does not clone or rewrite the item record. Rebalancing an authored base or affix definition does not silently change an existing instance's explicit rolled values.

## Item data model

### Item instance

`ItemInstance` is a versioned JSON-safe value object with these fields:

- `schema_version`
- `instance_id`
- `base_definition_id`
- `item_level`
- `rarity_id`
- `affixes`
- `origin`

`instance_id` is an opaque globally unique string. Production issuance uses an owner/run issuer namespace plus a monotonic issuance component. Deterministic fixtures use a stable sandbox namespace and sequence. An instance ID never changes when the item moves.

`base_definition_id` must resolve through the authoritative `EquipmentCatalog`. The item instance does not embed presentation resources or copy authored compatibility rules.

`item_level` is a positive integer. It is recorded now because later affix tier gates, drop sources, vendors, crafting, and content tiers depend on it.

`rarity_id` resolves through the item-rarity catalog. Common through Legendary are functional development rarities. Higher future rarities remain registered but cannot be generated by normal Plan 4B fixture rules.

`affixes` is an ordered array of explicit `ItemAffixInstance` values. Ordering is stable for serialization, display, hashing, and deterministic comparison.

`origin` is a small JSON-safe record containing the issuance source, deterministic seed or provenance token, and issuance sequence. It exists for debugging and reproduction; it does not determine the item's current values after creation.

### Affix instance

Each `ItemAffixInstance` contains:

- `definition_id`
- `affix_kind`
- `tier`
- `rolls`

`definition_id` resolves through a typed affix-definition catalog. `affix_kind` is validated against the definition and distinguishes the supported fixture categories such as implicit, prefix, suffix, and special power. `tier` is a positive integer within the definition's allowed range.

`rolls` stores exact explicit `ItemModifierRoll` values rather than a seed-only reconstruction. Each roll identifies its canonical stat or capability key, operation, finite value, and required tags. Definitions validate allowed keys, operations, value types, and tier ranges. Plan 4B does not yet apply these modifiers to characters.

### Preservation rule

Existing instances retain their exact affix tiers and values when catalogs change. A later explicit migration may alter existing items, but ordinary load and definition refresh do not. This permits stable saves and intentional legacy items.

## Registry model

Each ownership domain has one `ItemRegistry`:

- A profile registry owns persistent stash items.
- A player run context owns that profile's current run items.
- The Developer Item Sandbox owns an isolated disposable registry.

The registry maps `instance_id` to one immutable item record. It rejects duplicate IDs and invalid records. It never infers ownership from controller number, proximity, active UI focus, or character class.

An item must have exactly one serialized location in its ownership domain. Creation and placement happen in one transaction, so a persisted registry cannot contain an orphaned item. Future equipment sheets, ground-item collections, extraction carts, and transfer escrows will be modeled as additional typed containers rather than bypassing this invariant.

## Fixed-slot container model

`ItemSlotContainer` is a versioned value object with:

- Stable `container_id`.
- Typed `container_kind`.
- Ownership-domain identity.
- Fixed nonnegative `capacity`.
- Sparse `slot -> instance_id` placement.

Slots are zero-based integers in `[0, capacity)`. Serialization writes only occupied slots, but the slot number is stable and exact. Empty slots are not compacted automatically.

Plan 4B container kinds are:

- `run_inventory`
- `profile_stash_tab`
- `developer_inventory`
- `developer_stash_tab`

The first production run inventory has `5 * inventory_columns` slots. The current progression range is zero through eight columns, producing zero through 40 slots. A locked inventory therefore has zero accessible slots rather than a hidden default capacity.

Every profile stash tab has exactly 100 slots in Plan 4B. `stash-access` materializes the first tab. Later Warehouse progression may add more tabs and organization features without changing the container contract.

## Ownership domains

Persistent and run storage remain deliberately separate:

- The profile registry and stash are persisted through `ProfileStore`.
- The run registry and run inventory live in `PlayerRunContext`.
- Starting a run derives inventory capacity from the immutable run-rules/profile snapshot.
- Ending a run does not move items into the stash in Plan 4B.
- No Plan 4B transaction crosses profile/run ownership domains.

Ownership displayed by the sandbox is derived from the registry/container domain, not duplicated as a mutable field inside every item. This avoids a second owner value that could disagree with container ownership.

## Transaction service

`ItemContainerTransactionService` is the only public mutation boundary for registries and containers.

Supported Plan 4B operations are:

- Create an item and place it into an empty slot atomically.
- Move an item to an empty slot in the same ownership domain.
- Swap two occupied slots in the same ownership domain.
- Remove an item atomically for sandbox reset and fixture teardown.

Production destruction, discard, extraction, and cross-player transfer are not exposed even though they can later reuse the same transaction primitives.

### Transaction request

A transaction request includes:

- Unique transaction ID.
- Operation kind.
- Ownership-domain identity.
- Source container and slot when applicable.
- Expected source instance ID when applicable.
- Destination container and slot when applicable.
- Item payload only for create operations.

The expected source ID provides optimistic concurrency protection. A stale UI action cannot move whichever item happens to occupy the old slot later.

### Validation order

Before mutation, the service validates:

1. The transaction ID and request shape.
2. The ownership domain and both container identities.
3. The registry and complete item record.
4. Source slot bounds and expected item identity.
5. Destination slot bounds and occupancy rules.
6. Unique instance placement across the domain.
7. The final candidate registry/container state as a complete invariant set.

The service commits the candidate state only after every validation passes. Any failure returns a stable result code and leaves all original state byte-equivalent.

### Idempotency

Repeating the same transaction ID with the same canonical request returns the recorded result without applying it twice. Reusing an ID with different request data returns a transaction-collision error and mutates nothing.

Run-only transaction results live in the run context. Persistent stash mutations use the existing profile mutation and atomic-save boundary. The implementation must not write the profile once per validation stage.

## Profile schema and migration

Plan 4B increments the profile schema version. The new profile representation adds:

- Canonical persistent item records.
- Versioned stash-tab container records.
- Stable item issuance state required for unique IDs.

The existing `inventory_columns`, `extraction_capacity`, passive allocations, permanent unlocks, and applied-transaction history remain authoritative profile progression fields.

The version-one migration:

1. Validates the complete version-one profile first.
2. Copies every existing field without semantic changes.
3. Initializes an empty item registry and issuance state.
4. Requires version-one `stash_tabs` to be empty because no earlier production storage service created item-bearing tabs. A nonempty version-one value fails migration as unsupported legacy storage and leaves the source generation untouched.
5. Produces a complete version-two candidate.
6. Verifies an encode/decode round trip before atomic promotion.

Migration does not invent unlocks or items.

## Storage reconciliation

`ProfileStorageReconciler` turns approved passive-effect contracts into real storage. It consumes the authoritative City tree allocation and typed passive-effect resolution instead of trusting display strings or ad hoc booleans.

Reconciliation rules are:

- `field-pack` grants one inventory column, or five run slots.
- Typed passive resolution accepts zero through eight inventory columns.
- `stash-access` grants one 100-slot profile stash tab.
- Missing granted storage is created.
- Existing valid storage and exact item placement are preserved.
- Repeating reconciliation creates no extra capacity or tabs.
- Removing/refunding a permanent storage unlock does not delete containers or items.

This reconciliation also handles profiles that allocated the passive nodes before Plan 4B existed and therefore have the unlock record but no materialized storage.

## Persistence and recovery

Persistent item and stash mutations use the existing atomic profile flow:

1. Load and validate the current profile generation.
2. Verify transaction idempotency.
3. Build a defensive candidate copy.
4. Apply the complete registry/container transaction to the candidate.
5. Normalize and validate the full candidate profile.
6. Write a temporary file.
7. Verify the temporary file through the profile codec.
8. Promote it while preserving the verified backup.

A damaged primary generation is never silently normalized into data loss. Verified-backup recovery runs first. If no valid generation exists, the profile is marked unavailable with a stable diagnostic.

Load validation rejects:

- Duplicate instance IDs.
- Duplicate references to one instance.
- Missing referenced records.
- Persisted orphan records.
- Unknown equipment, rarity, or affix IDs.
- Invalid item levels or affix tiers.
- Nonfinite or wrongly typed rolls.
- Unknown containers or malformed ownership.
- Negative capacity or out-of-bounds slots.
- Invalid transaction records.

Production recovery does not auto-delete a questionable item. The disposable sandbox offers Reset because it is not player data.

## Developer Item Sandbox

The sandbox is a Developer Mode tool opened from **Additional Settings -> Developer Tools**. It is not the production Equipment and Inventory page.

### Isolation

The sandbox uses a dedicated storage root and disposable profile identity that never appears in the normal profile index. It receives no reference to the active profile's mutable state or store path. Opening, saving, reloading, and resetting the sandbox must leave the active profile's values and serialized bytes unchanged.

### Deterministic starting state

Reset creates:

- One five-slot developer run inventory.
- One 100-slot developer stash tab.
- One valid item instance for each of the 99 equipment bases.
- Ninety-nine occupied stash slots in stable catalog order.
- One empty stash slot.

The fixture issuer uses stable IDs, item levels, rarities, affix tiers, and exact rolls. Repeated resets produce byte-equivalent item/container documents.

Common through Legendary fixtures cover functional rarity contracts. Higher registered future rarities remain visible in catalog diagnostics but are not assigned by the default fixture issuer. A small typed affix fixture catalog exercises implicit, prefix, suffix, tier, operation, capability, and exact-roll validation without claiming final loot balance.

### Sandbox interface

The sandbox displays:

- Five-slot inventory.
- 100-slot stash grid.
- Selected-item inspector.
- Transaction status and integrity diagnostics.
- Save/Reload, Integrity Scan, and Reset actions.

The selected-item inspector shows:

- Display name and base ID.
- Instance ID.
- Item level and rarity.
- Affix names, kinds, tiers, operations, and exact values.
- Provenance.
- Derived owner, container, and slot.

Sandbox actions include exact-slot move, occupied-slot swap, move to first empty inventory slot, move to first empty stash slot, save/reload, integrity scan, and deterministic reset.

Keyboard/mouse and controller behavior follows the existing Settings and Character Ledger conventions. The sandbox must be operable at 1920x1080, 2560x1440, and 3840x2160. Player Simulation continues to show Equipment and Inventory as Coming Soon and exposes no sandbox route.

## Diagnostics

Errors use stable grep-friendly prefixes and field identifiers:

- `PARTY_FORGE_ITEM_ERROR`
- `PARTY_FORGE_ITEM_REGISTRY_ERROR`
- `PARTY_FORGE_CONTAINER_ERROR`
- `PARTY_FORGE_ITEM_TRANSACTION_ERROR`
- `PARTY_FORGE_PROFILE_MIGRATION_ERROR`
- `PARTY_FORGE_ITEM_SANDBOX_ERROR`

Transaction results expose stable machine-readable codes for invalid request, unknown owner, unknown container, slot out of bounds, source mismatch, destination occupied, duplicate instance, duplicate reference, invalid item, transaction replay, and transaction collision.

User-facing sandbox status translates these codes into concise explanations while retaining the code in developer diagnostics.

## Verification strategy

### Unit coverage

- Validate every item-instance and affix-instance field.
- Reject unknown base, rarity, affix, operation, and modifier identifiers.
- Prove exact rolled values survive encode/decode.
- Prove catalog changes do not rewrite serialized instance rolls.
- Validate fixed-slot bounds, sparse serialization, and exact placement.
- Prove registry and container accessors are defensive.
- Prove create, move, swap, and sandbox removal are atomic.
- Prove same-payload replay is idempotent.
- Prove transaction-ID collisions fail without mutation.
- Prove stale source IDs, wrong owners, locked capacity, duplicate IDs, duplicate references, missing records, and orphans fail closed.
- Prove storage reconciliation is idempotent and monotonic.

### Profile coverage

- Migrate representative version-one profiles to version two.
- Preserve every pre-existing profile field through migration.
- Reconcile pre-existing `field-pack` and `stash-access` allocations.
- Verify one stash tab contains exactly 100 slots of capacity.
- Verify run inventory capacity is exactly five times the resolved column count.
- Recover a valid backup when the primary item/container document is malformed.
- Reject invalid primary and backup generations without destructive repair.
- Prove failed persistent transactions leave saved bytes unchanged.

### Ownership and integration coverage

- Maintain two or more simultaneous profile/run registries with no shared mutable item or container state.
- Reject cross-profile and cross-run requests.
- Verify all 99 base IDs produce valid deterministic instances.
- Verify the 99 instances occupy stable stash slots and leave slot 99 empty.
- Save/reload the sandbox without placement or roll drift.
- Reset the sandbox to byte-equivalent state.
- Hash the active profile before and after sandbox operations and require identical values and bytes.

### Interface coverage

- Player Simulation cannot open the sandbox.
- Developer Mode can open it from Additional Settings.
- Equipment and Inventory remains Coming Soon in the player ledger.
- Keyboard, mouse, and controller can select slots and invoke sandbox actions.
- Focus cannot escape the sandbox modal while it is open.
- Layout remains usable at 1080p, 1440p, and 4K.

### Performance baseline

Record deterministic timing, serialized size, and memory observations for:

- One isolated profile with 99 instances.
- Four independent profiles with 99 instances each.
- Maximum current inventory capacity plus one 100-slot stash tab per profile.

The baseline fails on invalid state, ownership contamination, nonfinite metrics, timeout, or incomplete round trips. Plan 4B records measurements rather than inventing an arbitrary product FPS threshold for a non-rendered domain service.

### Final gates

- Complete Godot import exits zero with no unexpected loader, parse, script, or resource failures.
- All focused item/container/profile/sandbox suites pass.
- The complete automated suite passes.
- Normal Arena startup and gameplay smoke remain functional.
- Main menu, Settings, City passive tree, and existing Developer Quick Start remain functional.
- Sandbox visual and controller smoke passes.
- Active player profile sandbox-isolation proof passes.
- `git diff --check` is empty and the implementation worktree is clean.

## Completion criteria

Plan 4B is complete when:

1. Every authored equipment base can issue a valid versioned item instance.
2. Existing items preserve explicit affix tiers and values across save/load and catalog changes.
3. Each item has one canonical record and exactly one serialized location.
4. Fixed inventory and stash placement survives every round trip.
5. All supported mutations are atomic and idempotent.
6. Profile and run ownership cannot be crossed accidentally.
7. Existing profiles migrate without losing current data.
8. Existing storage unlocks materialize their exact capacity once.
9. The isolated sandbox exercises all 99 bases without touching active profiles.
10. The player-facing Equipment and Inventory page remains Coming Soon.
11. Required responsive, controller, integration, and recovery tests pass.
12. Future equipment, extraction, ground loot, and transfer systems can consume these contracts without replacing item identity or container ownership.

## Future expansion seams

Later plans add new container kinds and transaction policies around this foundation:

- Character equipment sheets.
- Ground-item collections.
- Extraction selection and transfer escrow.
- Player-to-player drops and ownership transfer.
- Vendor inventories and carts.
- Data-driven weighted production affix pools and tier selection.
- Crafting, salvage, and destruction confirmation.
- Persistent bring-in loadouts.
- Warehouse tabs, sorting, search, and organization.

The later production affix generator will first filter eligible modifiers by item/base tags, item level, affix kind and available prefix/suffix capacity, generation domain, and mutually exclusive modifier families. It will then select from that eligible pool by relative spawn weight. Stronger, more synergistic affixes and higher tiers should generally carry lower weights so they are materially rarer, while future difficulty, item rarity, crafting, passive-tree, and special-drop systems may apply explicit weight modifiers. Selection must use deterministic seeded randomness for reproducible tests and runs; after issuance, the chosen affix IDs, tiers, operations, and rolled values remain explicit and immutable.

Design inspiration includes Path of Exile 1/2's tagged spawn weights and modifier groups, Lootun's affix-driven build variety, Last Epoch's prefix/suffix and drop-only high-tier structure, and Grim Dawn's relative affix-combination weights. The dedicated generator design will compare those systems before choosing Party Forge's exact tables and tuning.

Those systems may add rules around a transaction, but they must not create a second item identity system or mutate containers directly.
