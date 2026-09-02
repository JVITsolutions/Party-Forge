# LatticeWright Format-3 City Passive Tree Redesign

**Status:** Approved behavior documented; implementation is not authorized by this document.

**Date:** 2026-09-02

**Verified Party Forge source:** `7f01de83a5ac1acdab2bcb9d4f89cd6aaa0913c9`

**Verified LatticeWright source:** `26098c0da6fa5c60597fc414cd2b4db79d0b1114`

**Scope:** Replace Party Forge's obsolete format-1 City passive-tree data with a LatticeWright format-3 source and runtime export; retain the existing Godot progression domain, profile persistence, allocation, effect, and UI layers; make every currently implemented City node genuinely allocatable; introduce six district gateways; reveal and reward the City tree on victories; and prevent Player Mode item drops until the profile can store and equip them.

## Purpose

The current City tree presents permanent purchases whose gameplay effects are not implemented, while the separate LatticeWright format-3 sample is design-only data with empty effects and no gameplay consumer. This redesign makes format 3 the sole City data truth, exposes only behavior Party Forge can honor, and arranges all City content as six readable districts around City Heart.

The redesign preserves stable node and profile identities so existing profiles do not lose history. It does not replace the existing Party Forge runtime wholesale. That larger decision is deferred until LatticeWright is past version 1.0.

## Decision labels

- **Live fact** describes behavior verified in the source trees above.
- **Approved decision** restates Jacob's approved product or architecture choice.
- **Derived design decision** makes the approved behavior implementable without expanding its scope. These choices remain reviewable at this written-spec gate.

## Live facts

### Current Party Forge City data and runtime

- **Live fact:** `data/passive_trees/city/party-forge-city.pstree` and `party-forge-city.pstree.json` are format-1 documents with 31 nodes and 31 connections.
- **Live fact:** `PassiveTreeLoader` accepts only `format: "passive-skill-tree"`, `formatVersion: 1` and directly constructs the existing `PassiveTreeDefinition` domain.
- **Live fact:** the current UI and mutation services can allocate nodes, charge passive points, persist allocations, project permanent effects, and reconcile profile storage.
- **Live fact:** current presentation marks known effects as `Coming Soon` even when the allocation service can permanently charge the node.
- **Live fact:** current Player Mode City access requires completed prologue state and City discovery. No production flow currently completes the prologue.

### Current implemented City behavior

- **Live fact:** Equipment Registry unlocks the Equipment and Inventory ledger through `equipment_inventory`.
- **Live fact:** Field Pack unlocks profile inventory and adds one five-slot inventory column.
- **Live fact:** Stash Access unlocks the Warehouse, creates one 100-slot stash tab, and discovers the Warehouse building.
- **Live fact:** Extraction License unlocks item extraction and adds one ordinary extraction slot. It already requires both Field Pack and Stash Access.
- **Live fact:** Secured Loadout unlocks bringing profile gear into a run.
- **Live fact:** Leader Loadout Extraction unlocks automatic leader-loadout retention.
- **Live fact:** personal enemy drops already fail closed when the current run inventory has zero capacity. The live gate also requires `equipment_inventory`, but does not independently require the `inventory` feature unlock.

### Current LatticeWright data

- **Live fact:** `samples/party-forge-city.pstree` and its deterministic runtime export are valid format-3 documents with `projectId: "party-forge-city"`, graph `city-passive-tree`, 31 content records, 31 placements, and 31 connections.
- **Live fact:** every current LatticeWright City content record has empty effects and requirements, and the runtime extension declares `gameplayConsumer: "not-yet-wired"`.
- **Live fact:** the sample contains 15 class/building portals from old landmarks. These do not represent the approved six-district gateway design.
- **Live fact:** LatticeWright format 3 exposes native schemas, content, placements, connections, and graph portals. It deliberately does not open, migrate, import, export, or reinterpret format 1 or 2.
- **Live fact:** Party Forge already has a strict runtime-v3 reader/adapter pattern in the City-access tooling, including duplicate-key defense, exact-key validation, and fail-closed translation.

## Approaches considered

### A. Six-district radial — approved

City Heart anchors six visually distinct districts. Each district has a main trunk, optional side services where applicable, and one final charter that unlocks the district-specific passive tree. The live logistics spine occupies the lower half without crossing other district paths.

This provides the clearest city metaphor, preserves the stable node identities, and leaves each district room to grow without putting all future specialization into the City graph.

### B. Civic avenues — rejected

Six horizontal lanes make prerequisites easy to scan, but the result reads as a conventional technology tree rather than a city. The long lanes also make cross-district logistics less natural.

### C. Concentric wards — rejected

Concentric tiers communicate depth well, but the center becomes denser and the live logistics spine competes with the tier rings. The radial design communicates both district identity and progression more clearly.

## Approved architecture

The City data path is:

```text
LatticeWright editable format-3 project
        |
        v
Deterministic runtime-v3 export
        |
        v
Strict JSON document reader
        |
        v
LatticeWright adapter registry
        |
        +-- format 3 adapter now
        +-- format 4+ adapter later
        |
        v
Stable Party Forge passive-tree domain
        |
        v
Existing allocation, effects, profiles, and UI
```

- **Approved decision:** format 3 replaces the City data layer now.
- **Approved decision:** the existing Party Forge allocation, profile, effect, and UI runtime remains in place until LatticeWright is past version 1.0.
- **Approved decision:** Party Forge uses a version-adapter registry. A future LatticeWright format change requires a new adapter, not another gameplay or UI redesign.
- **Approved decision:** there is no format-3-to-format-1 downgrade, compatibility projection, or format-1 fallback.
- **Derived design decision:** the domain tree ID remains `party-forge-city-v1`. LatticeWright's `projectId` remains `party-forge-city`, and its graph ID remains `city-passive-tree`.
- **Derived design decision:** the adapter obtains the domain tree ID from validated top-level runtime metadata rather than from a Party Forge filename or a second hard-coded node catalog.
- **Derived design decision:** the old format-1 City authoring file, loader route, sync checks, and format-1-specific City contracts are retired only after the format-3 replacement passes all qualification gates.

### Runtime-v3 identity and metadata

The approved runtime export has these exact top-level identity values:

```json
{
  "format": "latticewright-progression",
  "formatVersion": 3,
  "projectId": "party-forge-city",
  "extensions": {
    "gameplayConsumer": "party-forge",
    "partyForgeDomainTreeId": "party-forge-city-v1",
    "partyForgeStatus": "runtime-integrated"
  }
}
```

Every content record has the required LatticeWright field `party-forge-activation-state` with one of:

- `implemented`: Party Forge has complete production behavior for the node.
- `future`: the node is visible but cannot be allocated.
- `portal-gated`: the node can be allocated only when its one exact target project and graph are registered and valid.

This authored field is the sole production readiness truth. Party Forge must not maintain a second independent list of ready node IDs. The adapter projects the value into the stable domain, and both presentation and mutation authority consume that projection.

The existing placement-owned `node-cost` field remains authoritative. City Heart costs 0. Every other node, including all six district charters, costs 1.

### Format-3 effect and requirement schemas

The LatticeWright project defines only the schemas the City tree presently needs:

| LatticeWright definition | Required values | Party Forge domain projection |
| --- | --- | --- |
| `party-forge-feature-unlock` | `feature-id` text | `feature_unlock`, `set`, `true`, `featureId` |
| `party-forge-inventory-columns-add` | `amount` number, `scope` enum | `inventory_columns`, `add_flat` |
| `party-forge-stash-tabs-add` | `amount` number, `scope` enum, `slots-per-tab` number | `stash_tabs`, `add_flat` |
| `party-forge-building-discovery` | `building-id` text | `building_discovery`, `set`, `true`, `buildingId` |
| `party-forge-extraction-capacity-add` | `amount` number, `scope` enum | `extraction_capacity`, `add_flat` |
| `party-forge-tree-discovery` | `tree-id` text | `tree_discovery`, `set`, `true`, `treeId` |
| `party-forge-allocated-node` | `tree-id` text, `node-id` text | `allocated_node`, `contains` |

The adapter rejects unknown definitions, missing or extra values, invalid value types, unsupported operations, and non-integral values where the Party Forge domain requires integers. It does not execute extension-defined behavior.

## Final 37-node radial layout

The coordinates below are the normative LatticeWright placement centers. The design uses a 92-by-34 node footprint, at least 12 units of node-to-node clearance, and an 8-unit protected edge corridor for geometry validation.

| District | Node ID | Display name | Position | Role | Activation state |
| --- | --- | --- | ---: | --- | --- |
| Center | `city-heart` | City Heart | 700, 550 | free start | implemented |
| Heroes & Growth | `shared-lessons-1` | Shared Lessons I | 700, 420 | trunk | future |
| Heroes & Growth | `shared-lessons-2` | Shared Lessons II | 700, 310 | trunk | future |
| Heroes & Growth | `expanded-barracks` | Expanded Barracks | 700, 220 | trunk | future |
| Heroes & Growth | `hero-registry` | Hero Registry | 700, 165 | trunk end | future |
| Heroes & Growth | `hero-district-charter` | Hero District Charter | 700, 40 | district gateway | portal-gated |
| Trials & Modes | `training-yard` | Training Yard | 570, 450 | trunk | future |
| Trials & Modes | `trial-monument` | Trial Monument | 450, 365 | trunk | future |
| Trials & Modes | `arena-charter` | Arena Charter | 330, 300 | optional side node | future |
| Trials & Modes | `endless-gate` | Endless Gate | 430, 250 | trunk end | future |
| Trials & Modes | `trials-district-charter` | Trials District Charter | 290, 175 | district gateway | portal-gated |
| Trade & Commerce | `open-market` | Open Market | 830, 450 | trunk | future |
| Trade & Commerce | `merchant-permits` | Merchant Permits | 950, 365 | trunk | future |
| Trade & Commerce | `contract-ledger` | Contract Ledger | 1070, 290 | optional side node | future |
| Trade & Commerce | `grand-exchange` | Grand Exchange | 1090, 420 | trunk end | future |
| Trade & Commerce | `market-district-charter` | Market District Charter | 1260, 440 | district gateway | portal-gated |
| Exploration & Travel | `surveyors-office` | Surveyor's Office | 860, 620 | trunk | future |
| Exploration & Travel | `expedition-board` | Expedition Board | 1000, 675 | trunk | future |
| Exploration & Travel | `north-road-charter` | North Road Charter | 1110, 620 | optional side node | future |
| Exploration & Travel | `waystone-network` | Waystone Network | 1110, 750 | trunk | future |
| Exploration & Travel | `pathfinders-charter` | Pathfinder's Charter | 1220, 840 | trunk end | future |
| Exploration & Travel | `expedition-district-charter` | Expedition District Charter | 1340, 950 | district gateway | portal-gated |
| Forge & Equipment | `equipment-registry` | Equipment Registry | 720, 720 | live trunk and logistics prerequisite | implemented |
| Forge & Equipment | `smiths-guild` | Smiths' Guild | 840, 835 | trunk | future |
| Forge & Equipment | `reclamation-bench` | Reclamation Bench | 945, 930 | optional side node | future |
| Forge & Equipment | `artificers-hall` | Artificers' Hall | 960, 770 | trunk | future |
| Forge & Equipment | `grand-workshop` | Grand Workshop | 1150, 930 | trunk end | future |
| Forge & Equipment | `forge-district-charter` | Forge District Charter | 1260, 1080 | district gateway | portal-gated |
| Civic Logistics | `stash-access` | Stash Access | 500, 760 | live trunk | implemented |
| Civic Logistics | `civic-archive` | Civic Archive | 540, 620 | optional side node | future |
| Civic Logistics | `blueprint-library` | Blueprint Library | 370, 710 | optional side node | future |
| Civic Logistics | `hall-of-heroes` | Hall of Heroes | 270, 800 | optional side node | future |
| Civic Logistics | `field-pack` | Field Pack | 580, 830 | live trunk, requires Equipment Registry path | implemented |
| Civic Logistics | `extraction-license` | Extraction License | 540, 915 | live merge, requires Field Pack and Stash Access | implemented |
| Civic Logistics | `secured-loadout` | Secured Loadout | 440, 970 | live trunk | implemented |
| Civic Logistics | `leader-loadout-extraction` | Leader Loadout Extraction | 280, 1030 | live trunk end | implemented |
| Civic Logistics | `logistics-district-charter` | Logistics District Charter | 120, 1150 | district gateway | portal-gated |

### Exact connections

All 37 connections are bidirectional, have zero connection cost, and have no connection-level conditions.

Heroes & Growth:

```text
City Heart
  -> Shared Lessons I
  -> Shared Lessons II
  -> Expanded Barracks
  -> Hero Registry
  -> Hero District Charter
```

Trials & Modes:

```text
City Heart -> Training Yard -> Trial Monument -> Endless Gate -> Trials District Charter
                                           \-> Arena Charter
```

Trade & Commerce:

```text
City Heart -> Open Market -> Merchant Permits -> Grand Exchange -> Market District Charter
                                         \-> Contract Ledger
```

Exploration & Travel:

```text
City Heart -> Surveyor's Office -> Expedition Board -> Waystone Network
                                            |            -> Pathfinder's Charter
                                            |                 -> Expedition District Charter
                                            \-> North Road Charter
```

Forge & Equipment:

```text
City Heart -> Equipment Registry -> Smiths' Guild -> Artificers' Hall
                                               |        -> Grand Workshop
                                               |             -> Forge District Charter
                                               \-> Reclamation Bench
```

Civic Logistics:

```text
City Heart -> Stash Access -> Civic Archive
                          -> Blueprint Library
                          -> Hall of Heroes
                          -> Extraction License

Equipment Registry -> Field Pack -> Extraction License
                                      -> Secured Loadout
                                      -> Leader Loadout Extraction
                                      -> Logistics District Charter
```

Extraction License therefore remains a true two-prerequisite merge. Its content record has exactly two `party-forge-allocated-node` requirements: `field-pack` and `stash-access`, both in `party-forge-city-v1`.

The existing connection IDs remain stable where their endpoint pair is unchanged. `city-edge-19` changes from City Heart/Civic Archive to City Heart/Stash Access. The existing bidirectional Civic Archive/Stash Access connection remains. New gateway connections use `city-edge-32` through `city-edge-37` in Hero, Trials, Market, Expedition, Forge, and Logistics order.

### Geometry acceptance

The approved coordinates and connections produce:

- 37 nodes and 37 connections;
- zero proper segment crossings;
- zero node-box overlaps;
- zero protected edge corridors intersecting a non-endpoint node box; and
- zero shared-node path junctions within 4 degrees of a 90-degree angle.

LatticeWright save/reopen/export and the Party Forge renderer must independently re-run the same geometry checks against the exact exported coordinates. A manual-looking screenshot is not a substitute for those checks.

## District gateways and portals

Each gateway is the last node on the district's main trunk. Optional side nodes do not block the gateway.

| Portal ID | Source charter | Label | Target project | Target graph | Discovered domain tree |
| --- | --- | --- | --- | --- | --- |
| `city-to-hero-district` | `hero-district-charter` | Open Hero District | `party-forge-hero-district` | `hero-district-passive-tree` | `party-forge-hero-district-v1` |
| `city-to-trials-district` | `trials-district-charter` | Open Trials District | `party-forge-trials-district` | `trials-district-passive-tree` | `party-forge-trials-district-v1` |
| `city-to-market-district` | `market-district-charter` | Open Market District | `party-forge-market-district` | `market-district-passive-tree` | `party-forge-market-district-v1` |
| `city-to-expedition-district` | `expedition-district-charter` | Open Expedition District | `party-forge-expedition-district` | `expedition-district-passive-tree` | `party-forge-expedition-district-v1` |
| `city-to-forge-district` | `forge-district-charter` | Open Forge District | `party-forge-forge-district` | `forge-district-passive-tree` | `party-forge-forge-district-v1` |
| `city-to-logistics-district` | `logistics-district-charter` | Open Logistics District | `party-forge-building-warehouse` | `warehouse-passive-tree` | `party-forge-warehouse-v1` |

- **Approved decision:** allocating a charter permanently discovers the corresponding domain tree.
- **Approved decision:** a charter is allocatable only when the exact target project and graph are loaded, registered, valid, and resolve through the runtime portfolio registry.
- **Derived design decision:** each portal-gated content record must have exactly one matching graph portal and exactly one matching `party-forge-tree-discovery` effect. Any mismatch invalidates that charter.
- **Derived design decision:** a missing target disables only its charter and presents a clear `District tree not installed` reason. It does not invalidate the City tree or other districts.
- **Approved decision:** the existing 15 class/building portals are obsolete. The redesigned City runtime contains only these six district portals. Class, building, and specialization routing belongs inside the district projects.

## Implemented effects and activation

### Live effects

| Node | Exact effect projection |
| --- | --- |
| City Heart | no paid effect; free implicit root |
| Equipment Registry | `feature_unlock equipment_inventory` |
| Field Pack | `feature_unlock inventory`; `inventory_columns +1`, profile scope |
| Stash Access | `feature_unlock stash`; `stash_tabs +1`, profile scope, 100 slots; `building_discovery warehouse` |
| Extraction License | `feature_unlock item_extraction`; `extraction_capacity +1`, profile scope |
| Secured Loadout | `feature_unlock bring_in_gear` |
| Leader Loadout Extraction | `feature_unlock leader_loadout_extraction` |
| Each district charter | `tree_discovery` for the exact tree in the portal table |

Stash Access no longer discovers the Warehouse passive tree. That discovery moves to Logistics District Charter. Existing profiles that already discovered `party-forge-warehouse-v1` retain it; permanent profile progression is not revoked.

### Allocation rules

- **Approved decision:** implemented nodes are visible and can be allocated in Player Mode when ordinary graph, requirement, point, and profile rules pass.
- **Approved decision:** future nodes remain visible with `Coming Soon` and cannot be allocated or charge a point.
- **Approved decision:** portal-gated nodes remain visible and cannot be allocated until their target is registered.
- **Approved decision:** Developer Preview may inspect every node and portal but may not persist a Player Mode-invalid allocation.
- **Derived design decision:** mutation authority revalidates readiness at commit time. A disabled button is never the only protection against an invalid purchase.
- **Derived design decision:** a readiness change between presentation and commit rejects the transaction without charging a point or changing any profile field.

The immediate Player Mode allocation route is:

```text
City Heart
├─ Equipment Registry -> Field Pack ---------┐
└─ Stash Access ------------------------------┴-> Extraction License
                                                  -> Secured Loadout
                                                  -> Leader Loadout Extraction
                                                  -> Logistics District Charter
```

The seven non-charter nodes in this diagram are immediately implemented. Logistics District Charter becomes allocatable only after its format-3 target is installed and registered.

## Player Mode City discovery and passive-point rewards

- **Approved decision:** Player Mode reveals and activates the City passive tree when the selected profile commits its first victory.
- **Approved decision:** the first committed victory also grants 1 passive point.
- **Approved decision:** every later unique committed victory grants 1 additional passive point.
- **Approved decision:** this is temporary progression until a later design replaces it.

### Atomic victory transaction

The reward is part of the existing irreversible terminal run-resolution transaction. It is not a post-result UI callback and does not use the obsolete prologue-completion transaction.

For a terminal snapshot whose outcome is `VICTORY`, the transaction atomically:

1. adds `party-forge-city-v1` to `discovered_trees` if absent;
2. ensures `city-heart` is present in `tree_allocations["party-forge-city-v1"]` without charging a point;
3. increments `passive_points_available` by 1; and
4. increments `passive_points_lifetime_earned` by 1.

For `DEFEAT`, abandonment, or any non-victory terminal outcome, none of those fields changes.

The existing terminal transaction identity derived from stable `run_id` is the idempotency key. Resolution replay, recovery replay, repeated signals, result reconstruction, or application restart cannot award a second point for the same run. No second victory ledger is introduced.

If the City is already discovered, the victory still grants exactly one point. If an older profile has City discovery but is missing City Heart, the same transaction repairs the free root and grants only the normal one point. Existing untyped `run_history` entries do not trigger retroactive points.

Point overflow, invalid City identity, malformed existing allocations, or a failed profile save rejects the complete resolution mutation. Extraction, discovery, root allocation, and point award cannot commit partially. The durable terminal recovery record remains the retry authority.

Once discovered, all 37 City placements are visible. Existing `tree_visibility_progress` data is preserved for compatibility but is not a second readiness or City-layout authority.

Player Mode City routing therefore checks active profile plus City discovery. It no longer requires `prologue_state == COMPLETED`, and player-facing copy no longer tells the player to complete an unavailable prologue.

## Player Mode item-drop gate

- **Approved decision:** Player Mode item drops activate only after Field Pack is allocated.
- **Approved decision:** because Field Pack follows Equipment Registry, the player must be able to equip and store items before receiving them.

The shared production access policy requires all three conditions:

1. `equipment_inventory` is in the profile's permanent feature unlocks;
2. `inventory` is in the profile's permanent feature unlocks; and
3. the owner-scoped run inventory has positive capacity.

Before all three pass, an enemy or other production ground-item source produces no item-drop chance outcome, item instance, personal ground container, registry record, or chest. It returns the stable `feature_locked` eligibility reason and leaves combat rewards unrelated to items unchanged.

The policy is centralized and is used by every production equipment-drop source. A future boss, container, or encounter source may not bypass it by calling item generation directly.

An inconsistent Player Mode profile with capacity but without one of the two feature unlocks, or both unlocks but zero capacity, fails closed and reports a diagnostic. It is not silently repaired during a run.

Developer Mode with `Unlock All` retains its bounded, non-persistent testing bypass and temporary minimum inventory capacity. That bypass must not write either permanent feature unlock or an inventory column into the profile.

Passive points, experience, gold, and other non-item rewards are outside this gate.

## Existing-profile compatibility

- Existing IDs for all 31 old City nodes remain unchanged.
- Existing valid allocations remain allocated, including allocations on nodes now marked future. They may satisfy path continuity but do not gain invented effects.
- Existing permanent unlocks, storage, discovered buildings, and discovered trees remain monotonic. Removing an effect from the new source never revokes an already projected profile value.
- Existing allocations on future nodes are not automatically refunded. Refund policy is a separate product decision.
- Unknown saved allocation IDs are retained as unresolved profile history and reported. They are never silently deleted, treated as graph authority, or used to unlock a path.
- Existing `prologue_state`, `run_history`, and unrelated profile fields remain byte-equivalent except when an ordinary authorized profile transaction changes its own fields.
- The domain tree ID stays `party-forge-city-v1`, so the format change does not fork profile progression into a second City tree.

## Error handling and invariants

### Runtime document boundary

The strict reader accepts only UTF-8 JSON no larger than LatticeWright's exact 64 MiB runtime ceiling. It rejects malformed UTF-8, duplicate object keys, non-finite numbers, a non-object root, unexpected root keys, unsupported format/version, and invalid identity before the adapter sees gameplay data.

The format-3 adapter then validates:

- exact project, graph, and domain-tree identities;
- exactly one graph and exactly one start placement, `city-heart`;
- exactly 37 unique content records, 37 unique placements, and 37 unique connections;
- exactly one placement per content record and no dangling reference;
- unique connection endpoint pairs with no self-edge;
- finite coordinates and nonnegative integral point costs;
- exact effect and requirement definitions and typed instance values;
- exact activation-state values;
- the two Extraction License prerequisites;
- the six charter effect/portal pairs and exact targets; and
- the geometry invariants above.

Any structural, semantic, readiness, effect, portal, or geometry failure makes the City runtime unavailable as a whole. Party Forge does not load a partial tree and does not fall back to format 1.

An unsupported future format fails with an actionable adapter-unavailable diagnostic. When LatticeWright introduces format 4 or later, a separately reviewed adapter can map it into the same domain. The runtime and UI are not redesigned merely because the source envelope changes.

### Mutation boundary

- Every allocation is an idempotent profile mutation addressed by tree ID, node ID, and transaction ID.
- Readiness, discovery, visibility, prerequisites, graph reachability, passive points, portal target health, and permanent effect contracts are revalidated inside the mutation.
- A rejected allocation changes no point, allocation, unlock, discovery, storage, or timestamp field.
- Storage reconciliation remains atomic with allocations that change capacity.
- A missing district target disables the charter before mutation and is rechecked during mutation.
- Developer-only presentation state is never durable profile truth.

## Milestone map for unimplemented City content

This sequencing maps every unimplemented City node without inventing its final numeric effect or detailed product behavior. Each later district milestone requires its own focused design approval before implementation.

### Milestone 1 — Format-3 City foundation and live progression

- Author and export the approved 37-node LatticeWright City project.
- Add the version-adapter registry and format-3 City adapter.
- Retire the qualified format-1 City data route.
- Make City Heart, Equipment Registry, Field Pack, Stash Access, Extraction License, Secured Loadout, and Leader Loadout Extraction allocatable.
- Add first-victory reveal/root/point behavior and subsequent-victory points.
- Enforce the Player Mode item-drop gate.
- Render and visually approve the exact new City tree in LatticeWright and Party Forge.

### Milestone 2 — Civic Logistics district expansion

- Design and implement Civic Archive, Blueprint Library, and Hall of Heroes.
- Create and register the format-3 Logistics/Warehouse district tree.
- Activate Logistics District Charter only after that target qualifies.

### Milestone 3 — Forge and Market districts

- Design and implement Smiths' Guild, Reclamation Bench, Artificers' Hall, Grand Workshop, and the Forge district target.
- Design and implement Open Market, Merchant Permits, Contract Ledger, Grand Exchange, and the Market district target.
- Activate each charter only with its independently qualified format-3 target.

### Milestone 4 — Exploration and Trials districts

- Design and implement Surveyor's Office, Expedition Board, North Road Charter, Waystone Network, Pathfinder's Charter, and the Expedition district target.
- Design and implement Training Yard, Trial Monument, Arena Charter, Endless Gate, and the Trials district target.

### Milestone 5 — Heroes and Growth district

- Design and implement Shared Lessons I, Shared Lessons II, Expanded Barracks, Hero Registry, and the Hero district target.
- Put class-specific and hero-specialization expansion inside the Hero district tree rather than restoring old direct City portals.

## Verification design for later implementation

### LatticeWright authoring and export

- Use strict test-driven changes for any editor or schema support needed by the real effects/readiness data.
- Validate the editable `.pstree`, save it, reopen it, export runtime v3, and confirm deterministic byte parity on a second export.
- Assert exact project/graph identity, 37 content records, 37 placements, 37 connections, one start, six portals, and no obsolete portals.
- Assert zero crossings, node overlaps, protected edge-node collisions, and near-right-angle junctions from the serialized coordinates.
- Run LatticeWright focused tests, complete tests, typecheck, lint, and diff checks from an exact committed candidate.

### Party Forge unit and service coverage

- Strict reader: size boundaries, malformed UTF-8, duplicate keys, extra keys, invalid numbers, and invalid JSON.
- Adapter registry: format 3 selection, missing adapter, unsupported format 4, and no format-1 fallback.
- Format-3 adapter: exact identity, schemas, effects, requirements, placements, connections, portals, activation states, counts, and geometry.
- Stable domain parity: all seven immediate nodes project the exact effects and requirements above.
- Readiness: implemented allocation, future rejection, portal-missing rejection, portal-present allocation, and commit-time readiness drift.
- Profiles: stable old IDs, retained known allocations, quarantined unknown IDs, monotonic permanent progression, and no automatic refunds.
- Victory reward: first victory, later victory, duplicate resolution, recovery replay, defeat, abandonment, root repair, overflow, and save failure.
- Item drops: each unlock/capacity combination, no-roll/no-item/no-chest behavior, Developer Unlock All bypass, and unrelated reward preservation.

### Party Forge integration and presentation

- City route visibility before and after a committed first victory.
- First-victory result flow through terminal recovery and profile reload.
- Allocation flow from City Heart through both logistics prerequisites and the extraction merge.
- Player Mode future-node and missing-charter-target rejection through real UI input.
- Developer Preview inspection without invalid durable allocations.
- Personal-loot defeat runner before and after Field Pack.
- Existing equipment, Warehouse, extraction, secured-loadout, leader-loadout extraction, run recovery, and profile deletion regressions.
- LatticeWright and Godot screenshots of the exact 37-node radial layout, shown in this task for remote review.
- Focused City/passive-tree suites, owning integration runners, and the complete Godot suite with terminal PASS markers and exit 0.

### Reviews and containment

- Requirements review completes before code-quality review.
- Both reviews use the exact committed candidate and include LatticeWright data, adapter behavior, runtime behavior, and tests.
- The 68 pre-existing untracked `.gd.uid` sidecars in authoritative main are hashed before and after work and remain byte-identical.
- Existing worktrees, user-owned dirt, and all active art/body-model/presentation-asset paths remain untouched.
- Final qualification compares tracked state, index state, worktree registration, UID manifests, and surviving processes before integration.

## Acceptance criteria

1. The sole City source is a valid LatticeWright format-3 project with a deterministic runtime-v3 export.
2. Party Forge consumes the export through a version-adapter registry into its existing stable passive-tree domain.
3. The City contains exactly the approved 37 nodes, 37 connections, six districts, and six district portals.
4. Exact serialized geometry has no overlapping nodes, crossing paths, edge-through-node collisions, or near-perpendicular path junctions.
5. Existing 31 node IDs and `party-forge-city-v1` profile identity remain stable.
6. City Heart and the six currently implemented paid nodes are allocatable and project their exact live effects.
7. Future nodes are visible but cannot charge a point. Charters additionally require a valid registered target.
8. Stash Access connects directly to City Heart. Civic Archive is optional. Extraction License still requires both Field Pack and Stash Access.
9. Stash Access no longer discovers the Warehouse tree; Logistics District Charter owns that discovery.
10. A profile's first committed victory reveals the City, seeds City Heart, and grants 1 passive point exactly once.
11. Every later unique committed victory grants exactly 1 point; defeat and abandonment grant none.
12. Player Mode produces no item drop until `equipment_inventory`, `inventory`, and positive run-inventory capacity all pass.
13. Existing profiles retain allocations and permanent progression without silent deletion, revocation, or automatic refund.
14. Malformed, unsupported, incomplete, or geometrically invalid runtime data fails closed without partial load or format-1 fallback.
15. LatticeWright, Party Forge focused/integration/full suites, sequential reviews, visual review, and repository/UID containment all pass from exact committed candidates before integration.

## Risks and mitigations

- **Format churn before LatticeWright 1.0:** isolate envelope translation in the adapter registry and keep the stable domain unchanged.
- **A stale readiness list diverges from authoring data:** store readiness only in runtime v3 and make both UI and mutation consume the adapter projection.
- **Old profiles bought no-op nodes:** preserve allocations and paths; prohibit new purchases; leave refunds to a separately approved product decision.
- **A portal appears usable before its target exists:** require registry resolution in presentation and mutation, with a specific unavailable reason.
- **Victory replay duplicates points:** include the reward inside the existing idempotent terminal resolution transaction.
- **Victory save failure partially extracts or rewards:** mutate one profile candidate and promote it atomically through existing recovery-aware storage.
- **Players receive unusable items:** centralize the exact two-unlock-plus-capacity policy and require every production item source to use it.
- **The visual layout drifts during authoring:** validate serialized geometry after save/reopen and deterministic export, then compare the Godot render.
- **Cross-repository scope collides with active work:** use isolated worktrees, exact manifests, sequential commits/reviews, and stop on overlap or conflict.

## Explicit exclusions

- No active art, body model, presentation asset, Blender, attack-windup, HUD, Review Batch 1, Frost recruitment, or run-seed work.
- No final effects, tuning, or product behavior for nodes marked future.
- No automatic passive-point refund for historical no-op allocations.
- No retroactive victory-point backfill from untyped run-history records.
- No class/building direct portals in the City graph.
- No LatticeWright format-1 or format-2 import, migration, downgrade, or compatibility export.
- No wholesale replacement of the Party Forge passive runtime before LatticeWright passes version 1.0.
- No production code, tests, LatticeWright data mutation, implementation plan, generated qualification evidence, merge, push, cleanup, worktree removal, or release is authorized by this design-document commit.

## Approval gates

1. **Current gate:** Jacob reviews this committed written specification.
2. After written-spec approval, the brainstorming workflow transitions only to a detailed implementation plan.
3. Implementation begins only from the approved plan and uses strict TDD.
4. Requirements review completes before code-quality review.
5. Visual review of the exact LatticeWright and Godot candidates is required before final qualification.
6. Integration and normal push occur only at a pristine, conflict-free, fully qualified milestone under the already stated repository safeguards.
