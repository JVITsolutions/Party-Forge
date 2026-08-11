# Party Forge Live Personal Loot and Equipment Ledger Design

Date: 2026-08-11

Status: Approved design for weighted-loot Increment 5

Parent designs:

- `docs/superpowers/specs/2026-08-08-weighted-loot-generation-and-equipment-stats-design.md`
- `docs/superpowers/specs/2026-08-10-weighted-loot-production-content-and-weapon-damage-design.md`
- `docs/superpowers/specs/2026-08-10-developer-loot-lab-design.md`
- `docs/superpowers/specs/2026-08-04-plan-4b-item-container-ownership-foundation-design.md`

This document is authoritative where it is more specific than its parent designs. It connects the existing deterministic item generator to live Arena gameplay and turns the Character Ledger's Equipment & Inventory page into a functional, player-owned equipment surface. The thirty-minute Battle Mode director, five-minute boss checkpoints, extraction voting, and run-summary history are the immediately following increment rather than part of this implementation.

## Goal

Complete Party Forge's first usable production loot loop:

1. an enemy dies;
2. each nearby player receives a separate deterministic drop-chance roll;
3. a successful roll produces one personal item in one world chest;
4. the owning player manually inspects and collects the chest;
5. the item enters that player's run inventory atomically;
6. the player equips it onto any compatible character they own;
7. stats and the isolated 3D Character Ledger preview update from the accepted equipment state.

The implementation must reuse the production generator, item identity, ownership containers, equipment transitions, stat projection, item cards, tooltips, profile feature gates, and modular character-presentation contracts. It must not create a second loot, equipment, or stat system.

## Approved decisions

- Use live ground drops before performing a first final balance pass.
- Ordinary enemy deaths roll independently for every eligible player.
- One player's successful or failed roll never changes another player's chance or generated item.
- A player's leader must be within the configured reward radius when the enemy dies to receive a roll.
- Drops are personal: everyone can see them, but only the owning player can target or collect them.
- Player ownership uses both a profile-selected color and an explicit `P1` through `P4` marker; color is never the only ownership signal.
- Profiles store a preferred player color. Players in the same local session must use unique active colors.
- Represent one item with one small 3D loot chest/cache, a rarity glow, and a floating owner pennant.
- Ground chests persist until collected or the run ends. They do not expire between waves.
- Pickup is always manual. Mouse players hover and click; controller players cycle targets with the D-pad and collect with the south face button.
- Collection requires interaction range and never auto-walks the character.
- A full inventory leaves the chest and item untouched in the world.
- Expand the current increment to include the production Character Ledger Equipment & Inventory page.
- Keep one shared run inventory per player and a separate equipment sheet per character owned by that player.
- Use a Party Forge-original spatial paper-doll equipment layout inspired by familiar ARPG equipment screens.
- Display an isolated live 3D preview of the selected character and update supported equipment visuals after accepted equipment changes.
- Equipped items that lose attribute requirements remain visibly worn but become mechanically disabled through the existing activation system.
- Keep final loot art, rarity spectacle, and audio replaceable so the asset pipeline can upgrade presentation without replacing gameplay contracts.

## Scope

Included:

- deterministic per-player drop-event rolls on supported ordinary enemy deaths;
- leader-distance eligibility using the run's reward-radius policy;
- production item generation using source, domain, item level, difficulty, Heat, party archetype tags, Charisma, and unlock tags;
- personal world-ground ownership containers;
- one-item loot chest entities with owner and rarity presentation;
- stable mouse and controller targeting and manual pickup;
- atomic world-to-run-inventory transfers;
- inventory-full and invalid-owner failure behavior;
- profile preferred-color persistence and safe migration for existing profiles;
- unique active color assignment for future local-session participants;
- a functional Character Ledger Equipment & Inventory page;
- access to every owned party member, including the current developer limit of 24;
- per-player run inventory and per-character equipment sheets;
- existing tooltip, comparison, advanced-affix, drag-and-drop, and controller movement contracts;
- isolated 3D character preview and modular equipment-visual refresh;
- Developer Mode drop tuning and ground-loot diagnostics;
- responsive layouts at 1920x1080, 2560x1440, and 3840x2160;
- cold-import, startup, save compatibility, ownership, controller, performance, and full-suite verification.

Deferred:

- the thirty-minute Battle Mode encounter director;
- bosses at five-minute checkpoints;
- boss reward chests and the post-boss extraction/continue intermission;
- majority extraction voting and five-second extraction holds;
- the end-of-run summary and persistent Run History feature/building;
- elite enemies, elite-specific rewards, or elite presentation;
- final drop-rate, item-level, rarity, or economy balance;
- final ground-item models, rarity beams, slot-machine effects, sounds, and celebratory animation;
- item filters, automatic cleanup, automatic pickup, loot vacuuming, or pity systems;
- player-to-player ground-item transfer and deliberate item dropping;
- live split-screen cameras, profile joining, or drop-in multiplayer;
- mid-run save and restoration of ground chests;
- vendors, crafting, salvage, corruption, enchanting, carts, or extraction-policy changes.

The current boss-to-victory transition remains unchanged in Increment 5. Boss reward generation is exposed through a clean reward-source seam but is not activated until Increment 6 can provide an accessible post-boss reward and extraction phase.

## Feature gates

Production ground loot and the functional Equipment & Inventory ledger remain behind the appropriate profile equipment/item unlocks. Before those unlocks, Player Mode preserves the existing hidden or `Coming Soon` presentation and does not spawn equipment chests.

Developer Mode and `Unlock All` expose the complete increment immediately for testing. Developer bypasses must affect feature visibility only; they may not write permanent unlocks into the player's profile.

Existing profiles without a preferred player color migrate to the Player 1 default color without changing unrelated profile bytes or progression. New profile creation includes a curated, accessibility-checked color selection. Active local-session assignment rejects duplicate colors and asks the joining player to choose another; actual multi-profile joining remains part of the split-screen increment.

## Player eligibility and independent rolls

Every supported enemy death produces a stable reward-event identity derived from the run seed and the enemy's deterministic spawn/death identity. The event evaluates every active participant independently in stable player-slot order.

A player is eligible when:

- the player is active in the run;
- the player's leader is available;
- the leader is within the configured reward radius of the defeated enemy at death time;
- the profile/run rules expose item drops;
- the source is permitted to award equipment.

Followers do not extend reward range. A distant follower cannot qualify its owner.

Each eligible participant receives an independent deterministic chance roll. A successful roll builds that player's own `ItemGenerationRequest` using the same enemy reward event but a player-specific deterministic stream. The request includes:

- stable source ID and ordinary-drop generation domain;
- source-derived item level;
- difficulty and Heat;
- that player's party archetype tags and Charisma;
- that profile's unlock tags;
- run seed, reward-event identity, player slot, and stable per-player generation sequence.

The implementation must guarantee all of the following:

- adding or removing another player does not reroll an existing player's outcome;
- changing participant iteration order does not change results;
- one player succeeding does not force another player to succeed;
- two successful players receive independent base, rarity, affix, tier, and value rolls;
- the same frozen run, event, participants, and configuration reproduce byte-equivalent item payloads.

Generation failure produces a structured diagnostic and no ground entity. It does not consume another player's outcome or create an orphaned item.

## Initial Arena tuning

Initial values are provisional and data-driven:

- ordinary melee enemy: 1% personal drop chance per eligible player;
- ordinary ranged/specialist enemy: 2% personal drop chance per eligible player.

There is no active elite category in the current game. The reward policy supports future enemy categories without inventing an elite runtime now.

Item level comes from encounter time/wave, enemy category, difficulty, and Heat. It is never copied from character level. Source modifiers may bias rarity and item level through the existing generator request and weight contracts; they may not bypass eligibility, manufacture illegal tiers, or reroll an issued item.

Developer Mode exposes bounded controls for:

- global drop-chance multiplier;
- forced successful personal rolls;
- deterministic source/item-level override;
- visible ground-chest count by owner and rarity;
- generation failures and pickup rejection counts.

These controls are session/run rules and must not mutate profile progression or production tuning resources.

## Ground ownership and chest lifecycle

One successful generated item enters one typed personal ground container owned by the receiving run participant. Creation of the item instance, registration, container placement, and chest binding are one validated transition. The system may not persist or present an item that lacks exactly one ownership location.

The chest is a lightweight gameplay-owned entity containing only stable references needed to address its owner, container slot, item instance, and presentation. It does not own a second copy of the item document.

The chest remains until:

- its item transfers successfully to the owner's run inventory; or
- the run terminates and run-owned world containers are discarded by normal run cleanup.

Chests do not expire, become free-for-all, move between owners, or automatically enter inventory. Closing the Character Ledger, changing camera composition, or beginning another ordinary wave does not change ownership or lifetime.

For performance, the visual uses pooled/lightweight meshes, bounded animation, a spatial targeting index, and no continuing rigid-body simulation after its initial placement settles. Persistence does not justify per-frame full-world scans.

## Ground presentation

The first presentation uses:

- a small replaceable 3D chest/cache model;
- a subtle rarity-colored ground glow;
- a floating banner/pennant pointing to the chest;
- the owner's active profile color;
- an explicit `P1`, `P2`, `P3`, or `P4` label;
- selection outline and distance feedback;
- the existing item tooltip card for item details.

Owned chests render at full emphasis. Other players' chests remain visible but are visually subdued and cannot enter the local player's target list. The marker shape and label remain readable against supported arena backgrounds and at the high-angle 3D camera.

Final chest art, lights, beams, rarity animation, and audio can replace the presentation layer later. They must not change item identity, ownership, deterministic rolls, or pickup transactions.

## Input and targeting

### Mouse and keyboard

- Hovering an owned chest displays the normal item tooltip.
- Alt displays comparison against the relevant currently equipped item for the selected/leader character.
- Shift displays affix names, tiers, exact rolls, and roll ranges.
- Clicking an owned chest attempts collection when the leader is in interaction range.
- Clicking an out-of-range chest selects/highlights it and displays `Move closer`; it never issues movement input.
- Other players' chests may show owner information on hover but cannot be collected.

### Controller

- D-pad left/right cycles the local player's personal chests in a deterministic nearest-first order, with stable identity as the tie-breaker.
- The selected chest receives an outline, distance indicator, and tooltip.
- The south face button attempts pickup.
- An out-of-range attempt displays `Move closer` and retains the selection.
- The target list excludes other players' chests and invalid/despawned entries.
- If a selected chest is collected or removed, selection advances predictably to the nearest remaining owned chest.

Loot interaction yields to upgrade selection, pause, Character Ledger, settings, and any other modal that owns input. Opening and closing the ledger preserves a still-valid targeted chest.

## Pickup transaction

Pickup is a world-container-to-run-inventory transaction addressed by:

- participant owner ID;
- source ground-container ID and slot;
- expected item instance ID;
- destination run-inventory container and chosen/first valid slot;
- unique transaction ID.

The transaction validates owner, source identity, item identity, destination capacity, duplicate references, and current state before committing.

On success:

- the exact immutable generated item moves into the player's run inventory;
- the ground source becomes empty;
- the chest presentation is released;
- pickup feedback names the item and rarity;
- no reroll or reconstruction occurs.

On failure:

- ownership state is unchanged;
- the chest remains;
- the player receives a concise reason such as `Inventory Full`, `Reserved for P2`, or `Item Unavailable`;
- the same transaction ID is idempotent;
- no partial registry, slot, chest, or equipment mutation survives.

## Character Ledger information architecture

The full-screen Character Ledger retains its page/tab structure:

- Character Stats;
- Current Upgrades;
- Equipment & Inventory;
- future pages added through the same page contract.

The Equipment & Inventory page uses three primary regions:

1. **Party rail:** party count, scrollable owned-character list, portraits, class, and level. It supports every active member through the current developer maximum of 24.
2. **Selected-character equipment:** spatial paper-doll slots around an isolated 3D character preview, plus a compact combat summary.
3. **Player run inventory:** the owning player's current unlocked grid capacity, occupancy count, item icons, and movement interactions.

The party rail remains visible because switching among many recruited characters is more important than maximizing raw inventory width. At supported desktop resolutions, all three regions remain visible. Narrower layouts stack the run inventory beneath the party/equipment region instead of compressing equipment slots into unreadable columns.

The page uses Party Forge's existing eleven-slot contract:

- helmet;
- body armour;
- legs;
- gloves;
- boots;
- amulet;
- left ring;
- right ring;
- belt;
- main hand;
- off hand.

This is an original Party Forge layout using genre-familiar spatial placement. It does not copy another game's textures, frames, proportions, icons, or ornamental expression.

## Inventory and equipment interaction

Each player has one run inventory shared by all characters that player owns. Each owned character has its own equipment container.

Selecting a party member changes the equipment sheet, 3D preview, combat summary, requirement evaluation, and comparison target. It does not change which player owns the run inventory.

Keyboard/mouse interaction:

- drag and drop moves items between run inventory and equipment;
- hover displays the standard item tooltip;
- Alt displays comparison;
- Shift displays advanced affix information.

Controller interaction:

- the west face button picks up/moves the focused item;
- the south face button places it;
- D-pad navigation follows an explicit closed graph across party members, equipment slots, inventory cells, page tabs, and Close;
- right-stick vertical input scrolls the focused party or inventory region.

All movements use the existing equipment ownership/transition service. Slot, class, weapon, dual-wield, attribute, and ownership rules are not duplicated in the UI.

Removing an item that grants required attributes is allowed. Any remaining equipped item that loses its requirements stays in its equipment slot and remains visually worn, while the existing activation resolver disables all of its mechanical contributions. Tooltips and slot state explain the missing requirements.

Comparisons show improved values in green and worse values in red while retaining explicit labels and signs for accessibility. Color is supportive, not the sole comparison signal.

## Isolated 3D character preview

The equipment page displays a presentation-only copy of the selected character rather than moving or reparenting the live combat actor.

The preview:

- uses the selected character's class/body/palette presentation contract;
- supports bounded rotation/inspection without affecting gameplay input;
- applies accepted equipment visuals by stable equipment slot and presentation ID;
- updates only after the authoritative equipment transaction succeeds;
- removes a visual when its slot becomes empty;
- leaves mechanically disabled equipment visibly worn;
- uses a clear slot-aware fallback when final equipment art is unavailable;
- cannot run combat AI, collisions, health, attacks, rewards, or gameplay signals.

The preview consumes the same accepted loadout projection used by gameplay presentation. It may not infer equipment by reading UI button state.

## Multiplayer ownership seams

The current runtime remains single-local-player, but all new services accept stable participant ownership rather than assuming one global inventory.

Future local multiplayer behavior is preserved in the design:

- each joined profile supplies its own preferred color, inventory capacity, unlocks, Charisma, party tags, and equipment sheets;
- active session colors are unique;
- item rolls, ground containers, targeting, pickup, and ledger mutation remain owner-scoped;
- merged cameras can show every chest because ownership is represented by both color and player number;
- opening a Character Ledger pauses the run for all local players, while each player can inspect and mutate only their own party and inventory.

Actual controller-to-profile joining, split/merged camera composition, and simultaneous per-player ledger presentation remain in the split-screen increment.

## Component boundaries

Exact names may change during implementation planning, but responsibilities must remain separated:

- **Enemy reward emitter:** publishes one stable enemy-defeat reward event and does not generate or place items itself.
- **Personal drop policy:** evaluates source category, run rules, feature gates, and per-player chance.
- **Reward eligibility service:** resolves active players and leader-distance eligibility.
- **Personal loot generation coordinator:** creates canonical player-specific requests and invokes the production `ItemGenerationService`.
- **Ground loot ownership service:** creates the item and typed personal ground location atomically.
- **Ground loot registry/spatial index:** tracks active chests by owner, identity, and position without scanning the scene tree.
- **Ground loot target controller:** owns local mouse/controller selection and interaction-range feedback.
- **Ground loot pickup service:** performs the idempotent ground-to-inventory transaction.
- **Ground loot presentation:** renders the replaceable chest, rarity glow, owner pennant, selection, and tooltip anchor.
- **Equipment Ledger controller:** projects the selected player's party, inventory, equipment, comparisons, and transactions into the UI.
- **Character preview controller:** owns the presentation-only actor and consumes accepted equipment-visual projections.

Enemy scripts, chest nodes, and Ledger controls must remain thin callers of these boundaries.

## Error handling and recovery

- Invalid reward configuration fails closed for the affected source and emits a stable diagnostic.
- Invalid/non-finite drop chances are rejected before a run starts or treated as no-drop with a diagnostic if discovered at runtime.
- Item-generation failure creates no chest and leaves no registry entry.
- Ground ownership creation is atomic; no item may exist without exactly one container location.
- A missing chest visual does not delete its item. The registry can recreate presentation from authoritative ground state.
- A missing item or stale chest reference removes only the invalid presentation and reports integrity debt.
- Inventory-full, wrong-owner, out-of-range, and stale-selection failures preserve the item and chest.
- Equipment rejection leaves inventory, equipment, stats, and preview unchanged.
- Preview asset failure falls back visually without changing equipment state.
- Existing profile migration failure preserves original profile bytes.
- Player Mode cannot access developer drop overrides or bypass feature unlocks.

Increment 5 does not serialize live ground chests for mid-run resume. Its run-owned state is cleaned up only through the normal run termination path.

## Performance strategy

The system must remain proportional to relevant events and visible/nearby loot rather than total scene-tree size.

- Enemy death evaluates active participants once in stable order.
- Per-player chance failures do not invoke item generation.
- Active ground items are indexed by owner and spatial region.
- Controller targeting queries only the local owner's relevant nearby/visible entries.
- Chest visuals avoid active physics after placement and use bounded animation.
- Tooltips are created/reused through existing shared presentation contracts.
- The Ledger virtualizes or incrementally binds party and inventory controls where necessary; it does not rebuild all item cards every frame.
- Character previews are created on Ledger open, reused while navigating, and released cleanly on close.

Developer tests cover sustained ground-chest counts beyond expected initial five-minute play without automatically deleting player loot.

## Verification strategy

### Unit and service tests

- Stable reward-event and per-player random-stream identity.
- Independent success/failure outcomes for multiple players.
- Participant iteration-order invariance.
- Leader-distance boundary behavior; followers do not extend eligibility.
- Feature-gate and Developer Mode behavior.
- Ordinary and specialist data-driven chance selection.
- Canonical generation request fields and deterministic result parity.
- Generation failure leaves no item, container, registry, or chest.
- Ground ownership creation and exactly-one-location invariants.
- Owner-only targeting and pickup.
- Idempotent pickup and stale-item rejection.
- Full inventory preserves byte-equivalent ground ownership state.
- Successful pickup preserves exact immutable item payload.
- Profile preferred-color migration and local uniqueness validation.
- Party/member selection, 24-member navigation, and inventory ownership isolation.
- Equipment transitions, requirements, disabled equipment, and stat projection.
- Preview refresh only after accepted transitions and fallback behavior on missing art.

### UI and integration tests

- Mouse hover, compare, advanced-affix, click, and out-of-range feedback.
- Controller target cycling, stable ordering, south-face pickup, modal suppression, and selection recovery.
- Other-player chest visibility without targetability.
- Inventory-full message and persistent chest.
- Ledger open/close focus restoration and preserved chest target.
- Party rail, paper-doll slots, inventory grid, tooltip layers, and controller focus graph.
- Drag/drop and west-face/south-face equipment movement.
- Responsive validation at 1920x1080, 2560x1440, and 3840x2160.
- Player Mode locked presentation and Developer Mode complete presentation.
- Isolated preview rotation, character switching, and equipment-visual refresh.
- Startup, normal Arena combat, upgrade selection, victory, and return-to-menu regressions.

### Performance and resilience

- High ground-chest counts with four synthetic owners.
- Twenty-four owned characters and expanded inventory capacity.
- Rapid enemy-death batches without nondeterministic ordering.
- Repeated Ledger open/close and character switching without leaked preview actors.
- Cold import and class-cache initialization.
- Full project suite and focused integrations from the final tracked tree.

Physical-controller acceptance and human visual review are recorded as deferred unless actually performed. Headless input simulation does not satisfy either gate.

## Acceptance criteria

Increment 5 is complete when:

1. Every supported ordinary enemy death evaluates each eligible nearby player independently and deterministically.
2. One player's drop outcome cannot change another player's chance or generated item.
3. A successful outcome creates exactly one personal world chest containing exactly one valid production item.
4. Every chest visibly communicates owner and rarity, remains persistent, and is targetable only by its owner.
5. Mouse and controller players can inspect and manually collect in-range owned chests without auto-walk or auto-pickup.
6. Pickup is atomic and idempotent; full inventory or invalid ownership leaves the chest unchanged.
7. The Character Ledger exposes a functional Equipment & Inventory page for every owned member through the developer limit of 24.
8. Each player has one owner-scoped run inventory and separate equipment sheets for their characters.
9. Equipment movement reuses authoritative transition, requirement, activation, stat, tooltip, and comparison contracts.
10. The selected character appears in an isolated 3D preview whose supported equipment visuals update only after accepted transactions.
11. Player Mode respects progression gates and Developer Mode exposes bounded testing controls without persisting unlocks.
12. Existing profile/save data migrates safely, normal Arena behavior remains functional, and the complete automated suite passes from a tracked-clean tree.
13. Manual visual and physical-controller status is reported truthfully rather than inferred from headless tests.

## Immediate follow-up: Battle Mode duration, extraction, and run summary

Increment 6 extends the current Battle/Arena prototype to a thirty-minute run with bosses at the 5, 10, 15, 20, 25, and 30 minute marks. After each boss dies, combat time stops and an extraction icon/circle appears. A majority standing in the circle for five continuous seconds extracts the group. If no player enters for ten seconds, or a majority explicitly readies to continue, the next segment begins. The final thirty-minute checkpoint ends the run rather than extending it indefinitely.

That increment also adds a versioned per-player run summary for extraction, completion, and defeat containing:

- outcome, duration, and furthest checkpoint;
- kills by enemy type;
- gold earned;
- items earned with rarity/source breakdowns;
- total damage and DPS using active combat time;
- damage by owned character and ability;
- extensible healing, damage taken, death, and revive metrics;
- selected class, recruited party, difficulty, Heat, and run seed.

The summary document is designed for later storage and browsing through a profile Run History feature/building. The exact building name and unlock presentation remain future narrative/UI decisions; the telemetry identity and versioned record do not depend on that name.
