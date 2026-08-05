# Leader Loadout Extraction Continuity Design

## Purpose

Party Forge should let a player carry a successful leader's equipment forward into another run without making the early extraction system irrelevant. The progression starts with scarce, item-by-item extraction and later unlocks automatic retention of the leader's complete equipped loadout.

This design also establishes the main-menu Armoury flow, class-compatibility warnings, and the only circumstance in which incompatible retained equipment may be destroyed for lack of stash space.

## Scope

This milestone designs:

- The relationship between ordinary extraction capacity and leader equipment.
- A persistent per-profile leader loadout.
- The Armoury equipment-and-stash page and city entry point.
- The separation between Armoury, Warehouse, and Barracks progression.
- Run-to-run reuse of compatible leader gear.
- Class-compatibility checks before starting a run.
- Explicit handling when incompatible gear cannot fit in the stash.
- Per-profile behavior during local multiplayer.

It does not implement equipment-slot rules, class requirements, the Armoury passive tree, extraction presentation, run-end rewards, or the main-menu interface. Those belong to a later implementation plan built on the Plan 4B ownership and transaction foundation.

## Progression States

### Equipment Locked

Player Mode does not expose the Armoury equipment-and-stash page or its city building. Developer Mode may expose unfinished equipment tools for testing without granting production progression.

### Equipment and Stash Available

Unlocking equipment exposes an Armoury page on the main menu and a clickable Armoury building in the city. Armoury v1 displays the active leader loadout beside a direct view into the profile's complete Warehouse stash. The player can switch among every unlocked stash tab and equip, unequip, compare, or swap items without moving them into a separate staging container.

The Armoury does not own another stash. Armoury and Warehouse are two purpose-built views over the same profile-owned item registry and stash tabs.

### Building Responsibilities

The **Armoury** answers, "What are my characters wearing?" It owns equipment-sheet presentation, comparison, equip/unequip actions, class compatibility, saved loadout conveniences, and later follower equipment sheets. A later Armoury passive tree expands loadout and equipment-management features.

The **Warehouse** answers, "What items does my profile own?" It owns full stash management, additional 100-slot tabs, searching, sorting, filters, categories, and bulk organization. Its passive tree expands capacity and storage-management features. The Armoury's stash browser consumes the same Warehouse data and supports switching among all unlocked tabs, but it does not duplicate Warehouse ownership or create Armoury-only storage.

The **Barracks** answers, "Who may start a run with me, and may they bring prepared gear?" It owns starting-follower capacity and the global permission for starting followers to bring persistent loadouts. It does not store items or implement equip/unequip actions.

### Ordinary Extraction

The existing `extraction-license` unlock grants the profile's first ordinary extraction slot. Before full leader-loadout extraction is unlocked, each ordinary extraction slot may select exactly one item from any of these sources:

- The leader's equipped items.
- A follower's equipped items.
- Loose items in the profile's run inventory.

Items not retained by another unlocked rule and not selected for ordinary extraction are lost when the run is resolved.

### Bring In Gear

The existing `secured-loadout` node continues to unlock `bring_in_gear`. It permits the active profile loadout to enter a run. It does not automatically retain the loadout at the end of a run.

### Full Leader Gear Extraction

A new permanent City-tree node follows `secured-loadout`:

- ID: `leader-loadout-extraction`
- Display name: **Leader Loadout Extraction**
- Purpose: retain every item equipped by the profile's leader when a run resolves successfully.
- Effect: `feature_unlock(set=true, featureId=leader_loadout_extraction)`

Once active:

- Every equipped leader item is retained automatically.
- Automatic leader retention consumes zero ordinary extraction slots.
- Leader equipment is excluded from the ordinary extraction selection pool.
- Ordinary extraction slots apply only to follower equipment and loose run-inventory items.
- One item can never be selected by both systems.

The ordinary extraction system therefore acts as an early bridge for leader gear, then specializes into follower and inventory recovery after the stronger unlock is earned.

## Barracks Starting-Follower Progression

The Barracks passive tree contains two independent progression paths:

- `starting_follower_capacity`: every allocated point permits `+1` owned follower to be selected before a run.
- `followers_bring_gear`: one permanent feature unlock permits every selected starting follower to bring a persistent equipment loadout into the run.

`starting_follower_capacity` begins at zero. Starting followers remain subject to the profile's overall squad capacity after accounting for human players. Unlocking one or more starting-follower slots does not grant `followers_bring_gear`, and unlocking `followers_bring_gear` does not increase the number of starting followers.

The existing City-tree `expanded-barracks` concept becomes the discovery gateway for the dedicated Barracks building/tree. Repeated `+1 starting follower` nodes and the separate `followers_bring_gear` node live in the Barracks tree rather than filling the City tree.

Armoury v1 remains leader-only. Once the profile has at least one starting-follower slot, the Armoury may reveal its follower-sheet selector. Before `followers_bring_gear`, every selected starting follower enters without persistent gear. After the unlock, every selected starting follower may check their saved loadout into the run. Followers may still find and equip items during the run regardless of the unlock.

Until persistent follower loadouts are implemented, ordinary extraction may still recover follower equipment into the Warehouse stash under the existing extraction-capacity rules. This design does not grant automatic full-follower extraction.

## Persistent Ownership Model

Each profile owns one persistent active leader-loadout container. Equipped items occupy that container rather than general stash slots, so a completed run can preserve a full equipped loadout even when the stash is full.

An item still has exactly one owner and one serialized location. Run resolution moves leader items from the run equipment container to the profile leader-loadout container in one atomic profile mutation. Ordinary extractions and automatic leader retention are planned together before any mutation is committed.

The resolver must reject any proposal that assigns an item to both paths, duplicates an item, references an item outside the profile's run ownership domain, or exceeds an ordinary extraction capacity. A rejected resolution changes neither the run snapshot nor the profile document.

## Successful Run Resolution

The extraction resolver follows this order:

1. Read the profile's permanent feature unlocks and extraction capacity.
2. If `leader_loadout_extraction` is active, reserve all equipped leader items for automatic retention and remove them from the ordinary eligible-item projection.
3. Otherwise, expose leader equipment alongside follower equipment and run-inventory items as ordinary extraction candidates.
4. Validate the player's ordinary selections against the remaining eligible projection and capacity.
5. Build one destination proposal covering the active leader loadout, stash placements, retained item records, and intentionally lost items.
6. Validate the complete ownership state.
7. Commit the complete profile mutation once.

A failed validation or save commits nothing. Deliberate destruction caused by an incompatible next-run loadout is handled separately and cannot occur during normal run resolution.

## Run-to-Run Loadout Continuity

After a successful run with full leader extraction unlocked, the final leader gear populates the active equipment section of the profile's Armoury page. Starting another run with a class compatible with every equipped item carries those items forward without requiring the player to move them through the stash.

This supports consecutive runs with the same class, allowing a player to improve one loadout over multiple runs.

Before run creation commits, the selected leader class validates every active-loadout item against equipment-slot and class-use rules. Compatible items remain equipped. If any item is incompatible, the run does not start immediately.

## Incompatible-Class Warning Flow

The first warning lists every incompatible item and explains why the selected class cannot use it. It offers:

- **Go to Armoury**: cancel run creation and open the equipment-and-stash page with the incompatible items highlighted.
- **Choose Another Class**: return to class selection without changing any item.
- **Continue Anyway**: preflight moving every incompatible item into available profile stash slots.

If the stash has enough space, **Continue Anyway** moves all incompatible items to deterministic first-empty stash positions in one atomic mutation, preserves compatible equipped items, and then starts the run.

If the stash lacks enough space, no item moves yet. A second destructive warning:

- Lists the exact incompatible items that fit in the stash.
- Lists the exact incompatible items that will be destroyed.
- States that destroyed equipment cannot be recovered.
- Offers **Return to Armoury** and **Cancel** as safe exits.
- Requires a deliberate hold-to-confirm action for **Destroy Items and Continue**.

The preflight uses canonical equipment-slot order to choose and display destinations and overflow consistently. Confirmation commits all stash moves and approved destructions atomically. The initial warning, ordinary accept input, dismissal, a save failure, or interruption never deletes an item.

There is no automatic overflow or recovery container. Stash capacity remains meaningful, while the high-friction confirmation prevents accidental loss of valuable equipment.

## Main-Menu and City Presentation

Once equipment is unlocked, the profile can reach the same equipment-and-stash page through:

- An Armoury destination on the main menu.
- The clickable Armoury building in the city.
- The incompatible-class warning's **Go to Armoury** action.

The Armoury page presents the active leader equipment sheet and a tab-switchable view of every unlocked Warehouse stash tab. The active loadout remains visually distinct from stored items because equipped items do not consume stash capacity. The Warehouse page uses the same underlying data but prioritizes storage-wide search, organization, and bulk actions rather than a character sheet.

Follower equipment sheets remain hidden in the initial Armoury release. They become available only with the later Barracks starting-follower/loadout milestone. Player Mode obeys progression visibility; Developer Mode may reveal unfinished pages and future controls for testing.

## Local Multiplayer

Every participating profile owns its own:

- Active leader loadout.
- Stash tabs and available space.
- Extraction capacity and selected ordinary extractions.
- `bring_in_gear` and `leader_loadout_extraction` unlocks.

Run resolution and next-run compatibility are evaluated independently per profile. One player's stash capacity, warning decision, or destroyed item cannot affect another profile. A local multiplayer run begins only after every participating profile has resolved its own incompatible-loadout gate.

## Stable Safety Rules

- Automatic leader extraction and ordinary extraction are mutually exclusive for leader items after the full unlock.
- Ordinary extraction can select leader gear before the full unlock.
- Equipped leader items do not consume stash slots while in the active loadout.
- Class selection never silently deletes equipment.
- Destruction requires an exact-item preview and a separate hold-to-confirm action.
- All equipment, stash, extraction, and destruction mutations are atomic and idempotent.
- Save or validation failure preserves the previous profile bytes and ownership state.
- Production item destruction is exposed only through the later approved policy service, never through sandbox-only transaction operations.

## Verification Requirements

The future implementation plan must prove at minimum:

- One ordinary extraction slot can retain one leader item before the full unlock.
- The same slot can instead retain one follower or run-inventory item.
- Full leader extraction retains every equipped leader item without consuming ordinary capacity.
- Leader items disappear from the ordinary eligible projection after the full unlock.
- Duplicate selection across automatic and ordinary paths is impossible.
- Compatible gear persists through consecutive same-class runs.
- An incompatible class blocks run creation before any mutation.
- Armoury redirection preserves the complete loadout.
- Sufficient stash space moves all incompatible items without destruction.
- Insufficient space identifies deterministic exact items and deletes nothing before the second confirmation.
- Confirmed destruction affects only the listed overflow items.
- Cancellation, save failure, replay, or interruption leaves item ownership and profile bytes unchanged.
- Each local profile resolves its loadout and extraction independently.
- Armoury and Warehouse views always project the same profile-owned stash records and exact tab placements.
- Repeated `+1 starting follower` nodes and the global `followers_bring_gear` permission are independent Barracks effects; starting followers never exceed overall squad constraints.

## Relationship to Plan 4B

Plan 4B remains responsible only for immutable item records, owner-scoped containers, fixed inventory and stash placement, atomic storage transactions, profile reconciliation, and the isolated developer sandbox. It does not implement extraction or equipment destruction.

This future design consumes those foundations by adding typed equipment containers and a policy-level run-resolution service. The Task 6 persistent storage wrapper must continue to reject sandbox-only removal so destructive behavior cannot bypass the explicit warning and confirmation flow defined here.
