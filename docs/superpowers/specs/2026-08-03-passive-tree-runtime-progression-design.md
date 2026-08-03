# Party Forge Passive-Tree Runtime and Progression Design

**Date:** 2026-08-03

**Status:** Approved for implementation planning

**Parent design:** `docs/superpowers/specs/2026-08-01-meta-progression-profile-passive-tree-design.md`

## Purpose

Build Party Forge's first creator-authored passive-tree runtime on top of the completed profile-persistence foundation. The milestone imports a revised City/Profile tree, validates it strictly, supports persistent allocation and refund rules, resolves typed effects, and provides a reusable blockout tree screen that developers can test before final city art and the cinematic menu are available.

This milestone also restores missing controller movement by binding the existing movement actions to the left analog stick. It does not introduce a second movement system.

## Approved Scope

The milestone includes:

- A small logistics expansion of the existing 27-node City tree.
- Creator-owned `.pstree` source and deterministic `.pstree.json` runtime export.
- Party Forge-owned copies of both artifacts.
- Strict runtime loading, topology validation, effect validation, and diagnostics.
- Universal profile-owned Passive Points.
- Tree discovery and starting-node handling.
- Connected allocation with node requirements and atomic profile persistence.
- Graph-distance fog with a base reveal radius of two.
- Profile-owned reveal-radius progression.
- Refund previews, permanent-node protection, retained-path validation, and Developer Mode free refunds.
- Typed active and future-contract effect registration.
- Effective passive resolution without directly mutating gameplay resources.
- A reusable developer-accessible passive-tree screen.
- Keyboard/mouse and controller interaction at 1080p, 1440p, and 4K.
- Left-stick movement bindings for the current single-player leader.

The milestone does not include:

- Final city art, final passive-node art, or high-quality effects from the asset pipeline.
- The opening city flight, house entry, body transition, or tutorial cinematic.
- The production main menu.
- Actual inventory grids, item extraction, stash storage, or bringing equipment into runs.
- Building-specific passive trees such as the Warehouse tree.
- Split-screen player routing.
- Final respec prices or renewable Passive Point economy tuning.

## Delivery Sequence Update

The prior combined menu/cinematic milestone is split:

1. **Plan 2 — Passive-Tree Runtime and Progression:** this design.
2. **Plan 3A — Functional Main Menu:** blockout Play, Settings, Quit, profiles, passive-tree routing, returning-player routing, and Developer Quick Start.
3. **Plan 3B — Cinematic Prologue Presentation:** final city backdrop, camera flight, house entry, tutorial transition, and high-quality presentation after the local asset pipeline is ready.
4. **Plan 4 — Per-Profile Run Context and First Services:** squad contexts, distance-gated rewards, inventory seams, first stash tab, extraction, and ownership-safe item transfer.

## Source Ownership

The Passive Skill Tree Creator at `E:\Projects\Passive Skill Tree Creator` remains authoritative for:

- Tree and node IDs.
- Node positions, names, descriptions, costs, tags, and icons.
- Effects, requirements, connections, and generic metadata.
- Editable `.pstree` project data.
- Deterministic `.pstree.json` runtime export.

Party Forge remains authoritative for:

- Profile state and persistence.
- Effect and requirement semantics.
- Feature availability and development-state policy.
- Allocation, visibility, and refund rules.
- Save compatibility and unresolved-allocation handling.
- Runtime UI and gameplay consumers.

The approved creator artifacts are copied without hand-editing into:

```text
data/passive_trees/city/party-forge-city.pstree
data/passive_trees/city/party-forge-city.pstree.json
```

The implementation verifies byte equality between the creator export and Party Forge's committed runtime copy. Godot code never writes either artifact.

## City Tree Revision

The tree retains `treeId = party-forge-city-v1`, `formatVersion = 1`, and `city-heart` as its starting node.

The existing `shared-stash` node is renamed and re-identified as `stash-access` before Party Forge runtime allocation exists. Its player-facing name becomes **Stash Access** and its copy explicitly describes profile ownership.

The resulting fixture contains 30 nodes and 30 connections. Existing connections `city-edge-20`, `city-edge-21`, and `city-edge-22` replace their `shared-stash` endpoint with `stash-access`. Four connections are added:

- `city-edge-27`: `equipment-registry` to `field-pack`.
- `city-edge-28`: `field-pack` to `extraction-license`.
- `city-edge-29`: `stash-access` to `extraction-license`.
- `city-edge-30`: `extraction-license` to `secured-loadout`.

All four are bidirectional with zero connection cost. Extraction remains unreachable as an allocation until both of its explicit `allocated_node` requirements pass, even though either adjacent branch can reveal it.

Three nodes are added:

### Field Pack

- ID: `field-pack`
- Purpose: permanently unlock the profile's first inventory column.
- Effect contracts:
  - `feature_unlock(set=true, featureId=inventory)`
  - `inventory_columns(add_flat=1, scope=profile)`
- Development state: future contract / Coming Soon in Player Mode.

### Extraction License

- ID: `extraction-license`
- Purpose: permanently unlock item extraction with one extraction slot.
- Requirements: both `field-pack` and `stash-access` must be allocated.
- Effect contracts:
  - `feature_unlock(set=true, featureId=item_extraction)`
  - `extraction_capacity(add_flat=1, scope=profile)`
- Development state: future contract / Coming Soon in Player Mode.

### Secured Loadout

- ID: `secured-loadout`
- Purpose: reserve bringing profile-owned equipment into future runs.
- Path: follows `extraction-license`.
- Effect contract:
  - `feature_unlock(set=true, featureId=bring_in_gear)`
- Development state: future contract / Coming Soon in Player Mode.

### Stash Access Effects

`stash-access` permanently records the contracts required by Plan 4:

- `feature_unlock(set=true, featureId=stash)`
- `stash_tabs(add_flat=1, scope=profile, slotsPerTab=100)`
- `building_discovery(set=true, buildingId=warehouse)`
- `tree_discovery(set=true, treeId=party-forge-warehouse-v1)`

The first stash tab is defined as 100 slots by Party Forge's typed effect handler, not by display text. The actual tab is created only when the Plan 4 storage service exists; until then the effect is a validated future contract.

Later inventory columns, extraction slots, stash tabs, sorting, search, and warehouse specialization belong to dedicated building trees. They do not expand the City tree.

## Runtime Domain Boundaries

The runtime is divided into focused units:

### Passive Tree Document

Immutable typed records represent the tree, nodes, effects, requirements, and connections. They retain only validated runtime data and expose lookup helpers without profile knowledge.

### Passive Tree Loader

The loader reads UTF-8 JSON, validates exact schema shapes, and returns either a complete typed document or an actionable error list. It never returns a partially usable tree.

Validation covers:

- Exact `format = passive-skill-tree` and `formatVersion = 1`.
- Non-empty stable tree ID and name.
- Unique, valid node and connection IDs.
- Valid starting-node references and start-node types.
- Finite positions and non-negative integer costs.
- Valid connection endpoints, direction, and undirected duplicate detection.
- Supported requirement operators and parameter shapes.
- Supported effect operations and parameter shapes.
- Registered active effects or explicitly registered future contracts.
- Tree-specific City invariants and logistics-node contracts.

### Passive Effect Registry

The registry owns typed contracts for each effect ID. Every contract specifies allowed operations, value type, required parameter keys, allowed scopes, permanence behavior, and development state.

Effects are classified as:

- **Active:** resolvable by the current game.
- **Future contract:** valid authored data that resolves to Coming Soon or Developer Preview without mutating unavailable systems.
- **Unknown:** invalid; the whole tree fails closed.

The registry never infers scope or permanence from display names.

### Passive Requirement Registry

The first registered node requirement is `allocated_node`. It validates a stable tree ID and node ID and checks the profile's retained allocations. Unsupported requirements fail closed.

### Passive Progression Service

This pure service receives a validated tree and a profile snapshot. It provides:

- Reconciled allocations and unresolved saved IDs.
- Graph distances and visible nodes.
- Allocation eligibility and rejection reasons.
- Refund consequences and rejection reasons.
- Effective passive effects grouped by scope.
- Immutable view data for the UI.

It does not save profiles, modify scenes, or read global input.

### Passive Profile Mutation Service

Allocation and refund operations adapt the pure progression decisions to the existing `ProfileMutationService.apply(...)` transaction boundary.

Allocation atomically:

1. Reloads the current profile.
2. Revalidates tree discovery, visibility, requirements, connectivity, and available points.
3. Deducts the complete node cost.
4. Adds the node ID once.
5. Records permanent unlock identifiers and discovery records represented by registered contracts, including future contracts, without instantiating unavailable downstream storage or equipment systems.
6. Saves the entire result under an idempotent transaction ID.

Refund atomically:

1. Reloads the current profile.
2. Revalidates ownership and refund policy.
3. Rejects removal that disconnects retained allocations, removes permanent data-bearing effects, or breaks retained requirements.
4. Requires the `passive_respec` service in Player Mode.
5. Allows a free Developer Mode quote through the same validation path.
6. Returns refunded Passive Points only after successful validation.

The UI never edits `ProfileState.tree_allocations`, `passive_points_available`, or unlock arrays directly.

## Profile Compatibility

The existing schema is retained:

- `tree_allocations[tree_id]` remains an array of node IDs.
- `tree_visibility_progress[tree_id]` remains a non-negative integer and represents additional reveal distance beyond the base radius.
- `discovered_trees` determines whether a tree is available to the profile.
- `permanent_feature_unlocks` stores permanent unlock identities.
- Passive Points remain profile-owned and shared by all passive trees.

The existing prologue completion transaction discovers the City tree and records the `city-heart` feature, but older profiles may not contain `city-heart` in `tree_allocations`. Plan 2 updates prologue completion for new profiles and treats missing starting nodes as implicit zero-cost roots for existing discovered trees. The first successful tree mutation persists any missing starting node IDs without spending points.

Saved IDs absent from a newer tree are retained as unresolved allocation records. They remain saved, spend no additional points, grant no effects, and produce diagnostics until a deliberate migration resolves them. The loader never silently deletes, refunds, renames, or reallocates them.

## Visibility and Fog

Player Mode reveals complete node details within graph distance:

```text
2 + tree_visibility_progress[tree_id]
```

The distance originates from any allocated node. Connections participate according to their authored direction for allocation, while visibility treats connected endpoints as graph neighbors so the player can inspect nearby branches.

Beyond the reveal radius:

- Nodes render as obscured silhouettes.
- Names, descriptions, costs, effects, and requirements render as `???` or remain hidden.
- Connections may remain faintly visible for orientation.
- Obscured nodes cannot be allocated.

Developer Mode can reveal the complete tree for inspection. This override is held in the active view context and never changes profile visibility data.

## Allocation and Connectivity

A node is allocatable only when:

- The tree is discovered.
- The node is visible without relying on a write-time Developer reveal override, unless the operation is explicitly a Developer test transaction.
- All typed requirements pass.
- The profile has enough Passive Points.
- At least one legal connection reaches it from an allocated node whose retained path reaches a valid start.
- The node is not already allocated.

All starting nodes are legal roots. Bidirectional connections allow traversal both ways; forward connections allow allocation only from `from` to `to`.

The result object carries a stable rejection code and player-readable explanation. UI strings do not parse diagnostic logs.

## Refund Policy

Permanent nodes include:

- Equipment, inventory, stash, and extraction access.
- Inventory columns, extraction slots, and stash tabs.
- Persistent buildings and discovered trees.
- Modes, regions, services, and data-bearing feature unlocks.
- Secured Loadout and other item-persistence mechanics.

Numeric modifiers that do not own persistent data, including experience bonuses and next-run squad capacity, may be respecable.

Player Mode refunds require the future `passive_respec` service. Plan 2 registers and tests that requirement but does not add a respec node to the logistics expansion. Developer Mode may issue free refund/reset requests through the same connectivity and permanence validator.

Final gold prices and renewable respec currencies remain economy tuning. Plan 2 exposes a quote boundary without fixing production prices.

## Developer-Accessible Tree Screen

The first screen is functional blockout UI designed for reuse by Plan 3A. It opens from an **Open City Passive Tree** button in Additional Settings when Developer Mode is selected.

The screen provides:

- Zoomable and pannable 2D tree canvas.
- Distinct allocated, allocatable, unavailable, permanent, and obscured states.
- Stable selected-node detail panel.
- Name, description, cost, effects, requirements, refund policy, and keyword explanations.
- Current and lifetime Passive Point totals.
- Allocate and refund confirmations.
- Exact rejection explanations and save errors.
- Unresolved saved-allocation disclosure.
- Safe unavailable presentation when the City export is invalid.

Input contract:

- Mouse drag pans.
- Mouse wheel zooms.
- Mouse click selects nodes and UI actions.
- Keyboard focus supports node traversal and action buttons.
- Left stick or D-pad selects linked nodes.
- Right stick pans.
- Triggers zoom.
- South face inspects or confirms allocation.
- West face requests a refund.
- East face closes or returns.

The screen uses temporary geometric nodes and existing theme primitives. Final textures, lighting, sound, rarity-like celebration effects, and City presentation wait for the asset pipeline and later UI polish.

## Controller Movement Prerequisite

The leader already reads:

```gdscript
Input.get_vector("move_left", "move_right", "move_forward", "move_back")
```

The root cause of missing controller movement is that all four actions contain keyboard events only. Plan 2 adds:

- Left-stick X negative to `move_left`.
- Left-stick X positive to `move_right`.
- Left-stick Y negative to `move_forward`.
- Left-stick Y positive to `move_back`.

The existing `0.2` movement deadzone remains the initial value. `Input.get_vector` continues to normalize diagonal input. The Controls page must show the new controller bindings instead of `Missing binding`.

This task targets the existing single-player leader. Device-to-player routing remains part of the later split-screen input architecture.

## Error Handling

- Invalid creator exports disable only passive-tree access.
- Diagnostics name the tree, node, connection, effect, requirement, or profile field involved.
- Unknown effects and requirements fail closed.
- Allocation never spends points without persisting the node.
- Save failure returns the unchanged profile projection to the UI.
- Duplicate transaction IDs return the original committed result; conflicting reuse fails.
- Unknown saved node IDs remain preserved and visible in recovery disclosure.
- Missing optional UI assets use blockout fallbacks.
- Arena launch, profiles, Settings, the Character Ledger, and Developer Quick Start remain functional if passive-tree loading fails.

## Verification

Automated coverage includes:

- Creator project/export semantic equality and deterministic runtime export.
- Party Forge source/export byte equality.
- Strict schema and City-invariant rejection cases.
- Effect and requirement registry contracts.
- Graph traversal, connection direction, and duplicate edges.
- Base and expanded fog distance.
- Developer reveal non-persistence.
- Connected allocation, insufficient points, visibility, and multi-requirement rejection.
- Atomic spending, save/reload, idempotent retry, and transaction conflicts.
- Permanent refund rejection and retained-path connectivity.
- Player respec-service enforcement and Developer free-refund validation.
- Unresolved saved allocation preservation.
- FeatureAccessPolicy active, Coming Soon, and Developer Preview results.
- Tree screen geometry and focus at 1920x1080, 2560x1440, and 3840x2160.
- Keyboard/mouse and controller tree interaction.
- Left-stick movement action bindings and Controls-page display.
- Existing arena, profile, ledger, presentation, locomotion, and full unit suites.

Manual approval covers:

- Analog leader movement and diagonal normalization.
- Open City Passive Tree from Developer Mode.
- Pan, zoom, selection, tooltips, allocation, and refund attempts with keyboard/mouse.
- Equivalent controller interaction.
- Save, restart, and retained allocation state.
- Player Mode fog and Coming Soon presentation.
- Developer full reveal without profile contamination.
- Corrupted-export safe failure.
- Layout and readability at 1080p, 1440p, and 4K.

## Acceptance Criteria

The milestone is complete when:

1. The revised creator source and deterministic runtime export are committed and semantically tested.
2. Party Forge loads the exact committed export through strict typed validation.
3. Profiles can allocate visible connected nodes with atomic Passive Point spending and save/reload persistence.
4. Fog reveals two graph links plus profile-owned visibility progression.
5. Unknown saved IDs remain preserved and disclosed.
6. Refund previews protect permanent data and retained connectivity.
7. Future logistics effects remain valid Coming Soon contracts rather than active incomplete systems.
8. Developer Mode exposes the reusable tree screen and non-persistent full reveal.
9. Keyboard/mouse and controller can navigate the tree at all target resolutions.
10. The left analog stick moves the leader and the Controls page reports those bindings.
11. Existing arena, profile, settings, ledger, controller, and presentation behavior remains verified.
12. The production main menu and cinematic remain separate later milestones.
