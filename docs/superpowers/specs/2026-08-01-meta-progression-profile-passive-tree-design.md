# Party Forge Meta-Progression, Profiles, Passive Trees, and Evolving Main Menu Design

**Date:** 2026-08-01
**Status:** Approved for implementation planning

## Purpose

Build Party Forge's persistent meta-progression spine before implementing the full equipment loop. The milestone introduces versioned player profiles, transactional saves, universal Passive Points, creator-authored passive trees, progressive feature unlocks, per-profile squad ownership, and an evolving city main menu with a one-time cinematic prologue.

The design must preserve the playable arena and the systems already built around it. The current class selection becomes a reusable run-setup destination rather than being discarded. Developer Mode retains a direct route into the arena so development and balance testing remain fast.

## Product Direction

Party Forge is an unlock-heavy incremental ARPG, auto-battler, and survivor-like. The player initially sees a focused fantasy adventure with one character and very few visible systems. Completing runs reveals that the city, classes, mechanics, modes, passive trees, party capacity, equipment, and other progression layers are much larger than they first appeared.

The central progression principle is:

> The player does not only gain power. The player gradually unlocks Party Forge itself.

The initial menu therefore exposes only:

- Play.
- Settings.
- Quit.

The first Play begins a one-time city camera flight and disguised tutorial run. Completing that prologue awards the profile's first Passive Point, reveals the City Heart, and transforms the menu into the normal long-term run hub.

## Superseding Decisions

This design replaces earlier placeholder assumptions where they conflict:

- Party capacity is no longer one shared six-character ceiling. Each active profile contributes its own unlocked squad capacity.
- Six characters is an important normal squad target, not a permanent engine-wide maximum.
- Four local players with six-character squads may field 24 characters. Passive progression may raise this further when performance evidence supports it.
- Inventory, stash access, extraction capacity, gold, Passive Points, owned recruits, and equipment ownership are per profile rather than host-owned or party-wide.
- Gold and XP sharing are distance-gated before their other eligibility rules are evaluated.
- The City tree unlocks the breadth of the game. Dedicated building and mechanic trees deepen systems after discovery.
- Equipment compatibility uses overlapping capability tags and requirements rather than fixed class allowlists.
- `legs` is an independent eleventh equipment slot.
- The Passive Skill Tree Creator is the required authoring source for production passive trees.

## Goals

- Require profile creation on first launch when no profile exists.
- Support multiple local profiles and distinct profile selection for future split-screen seats.
- Store persistent progression safely with explicit schema versions, migrations, backups, and idempotent transactions.
- Introduce one universal profile-owned Passive Point currency shared by all passive trees.
- Load and validate creator-authored passive-tree runtime exports.
- Support connected allocation, progressive fog of war, refunds, permanent feature unlocks, and reversible class-access paths.
- Resolve passive effects through explicit personal, owned-character, party, and world scopes.
- Evolve the main menu after a one-time per-profile cinematic tutorial.
- Make city buildings the immersive primary navigation while retaining an accessible drawer for discovered services.
- Preserve the current arena, character systems, UI foundations, controller support, and Fighter presentation.
- Establish stable data seams for the later equipment, stash, extraction, shop, cart, campaign, and local multiplayer milestones.

## Out of Scope for the First Implementation Slice

- The complete equipment, item generation, affix, loot, comparison, and model-preview experience.
- Functional shops, crafting, item extraction, cart delivery, and bringing stash items into runs.
- The completed Warehouse tree beyond its initial reveal and runtime contract.
- Production-quality city art, character-house art, cinematography, voice, music, or tutorial narrative.
- Final split-screen play, controller joining, profile seat assignment during a running game, or dynamic camera merging.
- Online multiplayer or cross-machine profile synchronization.
- Final numerical balance for Passive Point acquisition, respec prices, fog upgrades, reward-sharing distance, or party-capacity nodes.
- Production cheat-code access to Developer Mode.

These systems are deferred, not ignored. Their ownership and persistence boundaries are defined now so later implementation does not require rewriting profile storage.

## Design Principles

### Progressive Revelation

Locked systems should usually remain hidden until the player has enough context to understand them. Developer Mode can expose implemented systems for testing without permanently unlocking them in a player profile.

### Breadth Before Depth

The City tree discovers buildings, mechanics, modes, and foundational capabilities. Each discovered building or mechanic may reveal its own passive tree for capacity, specialization, automation, and advanced behavior.

Examples:

- City tree unlocks Stash Access; Warehouse tree unlocks additional tabs and warehouse services.
- City tree unlocks a class or class route; completing that class's milestone reveals its dedicated class tree.
- City tree unlocks a crafting building; its later tree expands recipes, quality, automation, and risk/reward options.

### Persistent Data Must Not Be Orphaned

Unlocks that make new persistent data legal cannot be refunded. Inventory columns, equipment access, stash access, extraction, and similar feature nodes are permanent once purchased.

Build choices may be respecable when doing so does not invalidate stored data or disconnect retained allocations.

### Ownership Is Explicit

Every persistent currency, character, item, allocation, reward, and mutation has a profile owner. Shared gameplay effects do not imply shared ownership.

### Data-Driven, Creator-Authored Expansion

Passive-tree topology and generic effects live in deterministic creator projects and runtime exports. Godot owns validation, effect mapping, persistence, and gameplay consumers. Production trees are not hand-authored directly in JSON.

## High-Level Architecture

```text
Machine Settings
      |
      v
Profile Manager ---- Profile Index
      |
      +---- Transactional Profile Store ---- Backups / Migrations
      |                    |
      |                    v
      |              Profile State
      |                    |
      |          +---------+----------+
      |          |                    |
      v          v                    v
Main Menu   Passive Tree Runtime   Progression / Unlock Service
      |          |                    |
      |          v                    v
      |     Scoped Effect Resolver -> FeatureAccessPolicy
      |                                   |
      +----------------+------------------+
                       v
          Per-Player Run Contexts
                       |
                       v
              Host World Context
                       |
                       v
      Arena / Campaign / Ledger / Equipment / Other Consumers
```

### Machine Settings

Machine settings continue to own graphics, audio, controls, additional settings, and Developer Mode options. Developer overrides are machine-local testing tools and must not write permanent unlocks into the selected profile.

### Profile Manager

The Profile Manager owns:

- Profile discovery and index recovery.
- Profile creation and unique local display names.
- Last-active profile selection.
- Future assignment of distinct profiles to local player seats.
- Prevention of assigning one profile to multiple seats in the same session.
- Safe profile deletion or archival only after a later dedicated design.

### Transactional Profile Store

The store exposes typed profile mutations rather than allowing arbitrary systems to write profile files. It owns:

- Schema versions and explicit migrations.
- Atomic write-to-temporary, verification, promotion, and backup rotation.
- Idempotent transaction IDs for value-bearing mutations.
- Read-back verification for important saves.
- Recovery without silently replacing a damaged profile with an empty one.
- Grep-friendly diagnostics that identify profile ID, operation, and failure stage without leaking or dumping unrelated data.

### Progression and Unlock Service

This service is the authoritative query and mutation boundary for:

- Passive Points.
- Tree allocations.
- Feature and building unlocks.
- Character and class access.
- Milestones and one-time rewards.
- Fog-reveal upgrades.
- Profile squad capacity.
- Stash, inventory, and extraction capacity.
- Mode and region access.

### FeatureAccessPolicy

Existing feature gates evolve to resolve access from:

```text
development state
+ profile progression
+ current run context
+ machine-local Developer Mode override
```

The policy preserves these rules:

- Coming Soon never becomes functional.
- Developer Preview can be tested only when Developer Mode permits it.
- Unlock All bypasses player progression only for implemented content.
- Player Mode follows real profile unlocks.
- Direct access attempts are revalidated; hidden UI is not a security or correctness boundary.

## Persistent Profile Model

The exact GDScript types belong in the implementation plan, but the saved contract must represent at least:

```text
profile_id
display_name
schema_version
created_at / updated_at

prologue_state
last_safe_checkpoint

gold
passive_points_available
passive_points_lifetime_earned

milestones
permanent_feature_unlocks
discovered_buildings
discovered_trees

tree_allocations by tree_id
tree_visibility_progress by tree_id

owned_characters
character levels / XP / fractional attribute growth
character equipment presets

profile squad capacity
inventory capacity
stash tabs and stored item IDs
extraction capacity

run history and resumable run reference
transaction ledger / applied mutation IDs
```

Items and characters require stable IDs. Saved tree allocations reference stable tree and node IDs, never visual positions or labels.

## Profile Creation and Local Player Selection

### First Launch

When no valid profile exists, the sunrise city menu still appears, but Play requires creation of a uniquely named local profile. Settings and Quit remain accessible.

Creation is committed atomically before the cinematic begins.

### Profiles Settings Tab

Settings gains a Profiles tab that supports:

- Viewing local profiles.
- Creating a profile.
- Switching the active profile outside a run.
- Future assignment of a distinct profile to each split-screen player.
- Clear display of invalid, damaged, or recovery-required profiles.

Profile names are player-facing labels; internal IDs remain immutable and unique even if later renaming is supported.

### Multiplayer Selection Rule

One profile cannot occupy two local player seats in the same session. Each selected profile retains independent progression, gold, characters, items, stash, and extraction rules.

## Prologue and Evolving Main Menu

### Prologue States

Each profile records exactly one of:

- `not_started`
- `in_progress`
- `completed`

### First Menu

A profile in `not_started` sees only Play, Settings, and Quit. City services, passive trees, run modes, and profile power are not exposed as a wall of locked icons.

### One-Time Cinematic

Selecting Play:

1. Atomically marks the prologue `in_progress`.
2. Fades the menu UI while preserving the live city scene.
3. Flies through the blocked-out 3D city.
4. Moves to the Red Fighter's house.
5. Tilts and enters the house.
6. Hands control into the disguised tutorial run.

Skipping the camera may shorten presentation but never skips tutorial state or rewards.

### Tutorial Recovery

Adventure-style checkpoints allow Manual Save and Save & Quit. A crash or restart resumes the last valid checkpoint without replaying grants or duplicating items.

Restart Prologue may later be exposed from profile management with confirmation. It must not duplicate one-time rewards.

### First Reveal

Completing the scripted tutorial endpoint performs one atomic transaction:

- Mark prologue `completed`.
- Award the first Passive Point exactly once.
- Reveal the City Heart.
- Reveal the City tree.
- Change the menu into its returning-player state.

If any part fails, the transaction is retried safely rather than partially applied.

### Returning Menu

After completion:

- Begin Run opens normal run setup.
- The cinematic flight does not auto-play again for that profile.
- Discovered city buildings become direct in-world destinations.
- An accessibility drawer mirrors discovered services for fast keyboard, mouse, and controller navigation.
- A future Memories or Gallery feature may allow optional cinematic replay.

## Saving and Run Continuation

### Save Triggers

Transactional autosaves occur after meaningful persistent mutations, including:

- Profile creation or settings-affecting profile selection.
- Passive allocation or refund.
- Feature or class unlock changes.
- Currency grants and purchases.
- Item ownership transfer, extraction, or destruction.
- Prologue checkpoint and completion.
- Run completion and durable milestone rewards.

Manual Save remains available.

### Mode Rules

- Campaign and Adventure use resumable safe checkpoints and support Save & Quit.
- Arena and Survival preserve already committed profile-safe changes, but unfinished runs do not resume.
- An ordinary Quit Run abandons the active run after confirmation.

The pause menu initially says **Quit Run**. Save & Quit appears only when the active mode can produce a valid resumable checkpoint.

## Passive Skill Tree Authoring Pipeline

Every new or revised production tree follows this pipeline:

1. Open the Passive Skill Tree Creator at `E:\Projects\Passive Skill Tree Creator`.
2. Create or revise the deterministic `.pstree` project.
3. Keep the editable `.pstree` source under version control with Party Forge integration assets or an explicitly linked source location.
4. Export `.pstree.json` using the creator.
5. Validate the runtime export in Godot.
6. Map generic exported effects through Party Forge-owned typed handlers.
7. Add tree-specific validation and gameplay tests before enabling player allocation.

The creator remains the source of truth for topology, node IDs, layout, labels, costs, requirements, generic effects, and connections. Godot remains the source of truth for profile state, effect semantics, feature policies, game-world consumers, and save compatibility.

## Existing City Tree

The existing creator export is:

```text
E:\Projects\Passive Skill Tree Creator\samples\party-forge-city.pstree
E:\Projects\Passive Skill Tree Creator\samples\party-forge-city.pstree.json
tree_id: party-forge-city-v1
format_version: 1
start: city-heart
```

At design time it contains 27 nodes and 26 connections covering equipment, stash, markets, crafting, salvage, party capacity, XP, modes, regions, and other future contracts.

Before runtime integration, revise the tree through the creator to match this approved design:

- Replace party-wide/shared-stash language with per-profile Stash Access.
- Make first Stash Access create one 100-slot tab and reveal the Warehouse tree.
- Add or reserve progression for the one-column starting inventory and later expansion to eight columns.
- Add or reserve extraction unlocks and capacity progression.
- Add or reserve bring-in gear access after sufficient inventory and extraction progression.
- Ensure squad-capacity effects are profile-scoped.
- Mark data-bearing feature unlocks permanent and nonrefundable.
- Keep unimplemented systems behind Coming Soon or Developer Preview states.

## Tree Loading and Validation

The runtime loader validates before presenting a tree:

- Supported format and format version.
- Non-empty stable tree ID and name.
- Unique node IDs.
- Valid starting node IDs.
- Connection endpoints exist.
- No duplicate or malformed connections.
- Supported node costs and requirement shapes.
- Known effect operations.
- Effect IDs are registered or explicitly future-contract-only.
- Saved allocation IDs are reconciled without destructive deletion.

Invalid trees fail closed with actionable diagnostics. They do not grant partial effects.

Unknown saved node IDs are retained in recovery metadata or an unresolved allocation list until migration can decide their fate. Loading a newer or changed tree must never silently refund, delete, or reassign spent points.

## Passive Point Currency and Acquisition

All passive trees spend the same profile-owned Passive Point currency.

Points come from a hybrid model:

- Major one-time milestones, such as tutorial completion, bosses, achievements, class accomplishments, regions, and difficulty milestones.
- A slow renewable source tied to appropriately difficult repeatable content.

The one-time source drives discovery. The renewable source prevents a profile from becoming permanently unable to explore alternative trees.

Exact award rates are tuning data and require a later economy pass.

## Allocation Rules

A node can be allocated only when:

- The tree is discovered and available to the profile.
- The node is visible or otherwise legally discoverable.
- All node-specific requirements pass.
- The profile has enough unspent Passive Points.
- A connected allocated path reaches the node from a valid starting node.

Allocation and point spending are one transaction.

## Fog of War

Most trees begin with fog of war.

- Full node details are initially visible within graph distance two of any allocated node.
- Distant areas may display obscured silhouettes or landmarks without readable values.
- Later profile progression can expand the reveal distance beyond two.
- Developer Mode may reveal the entire tree for testing without permanently changing the profile.
- Visibility is graph-based, not screen-distance-based.

The exact reveal-radius upgrade path is authored through the appropriate passive tree rather than hard-coded in the UI.

## Refunds and Connectivity

Normal refunds require an unlocked city respec service and an escalating profile-owned cost, paid in gold or a future respec resource. Developer Mode may perform free resets through the same validation path.

A refund is rejected when it would:

- Disconnect any retained allocation from a valid start node.
- Remove a permanent feature unlock.
- Invalidate persistent stored data.
- Violate a retained node's requirements.

The UI previews the consequences and explains why a refund is unavailable.

## Permanent Feature Unlocks

Nodes that enable data-bearing systems are permanent and nonrefundable. Examples include:

- Equipment access.
- Inventory columns.
- Stash access and tabs.
- Extraction access and slots.
- Persistent item-related mechanics.
- Other profile structures whose removal could orphan saved data.

The City tree is therefore mostly or entirely permanent. Dedicated class trees are mostly respecable.

## Reversible Class Access and Dormancy

Class unlocks belong near the edges of related class trees and should often have several incoming routes. For example, Fighter may reach Paladin through three different attached paths.

Rules:

- At least one fully allocated connected route must reach the class unlock node.
- A player may refund one route if another complete route remains.
- Losing the final route removes the class from new-run selection.
- Losing access never deletes class progression.
- Character levels, passive allocations, equipment presets, milestones, history, and other class-owned data become dormant and are restored when access returns.
- System and feature unlocks do not use this reversible behavior.

This prevents a rush-unlock-refund exploit while avoiding destructive save behavior.

A class's own tree may require a class-specific accomplishment before discovery. Example: unlock Paladin through the Fighter tree, then complete one Survival run as Paladin to reveal the Paladin tree.

## Passive Effect Scopes

Every Party Forge passive effect declares one scope:

- `personal`: affects only the profile's human-controlled leader.
- `owned_characters`: affects the leader and followers recruited by that profile.
- `party`: may affect all allied players and party members.
- `world`: changes host-authoritative modes, routes, encounters, difficulty, or global rules.

The scope is part of the typed effect contract, not inferred from the node label.

World effects are resolved by the host context. A non-host profile may retain world-scoped progression, but it cannot independently change the shared session's world routing.

## Building and Mechanic Trees

The City tree should not absorb every future capacity and specialization node. When a mechanic is unlocked:

1. The feature becomes available according to its development state.
2. A physical building or service can appear in the city.
3. The City accessibility drawer adds the discovered service.
4. The mechanic's dedicated passive tree becomes discoverable immediately or through a related milestone.

### Warehouse Example

Stash Access performs these permanent changes:

- Reveal the Warehouse building.
- Create the profile's first stash tab.
- Give that tab 100 item slots.
- Register the Warehouse tree as discovered or ready for its reveal condition.

The creator-authored Warehouse tree later controls:

- Additional 100-slot tabs.
- Sorting and search improvements.
- Item-category organization.
- Future shared-view or transfer conveniences that do not merge profile ownership.
- Other warehouse-specific services.

Every other building or mechanic may follow the same pattern.

## Multiplayer Profile and Run Contexts

### Per-Player Run Context

Each local player context contains:

- Selected profile ID.
- Human-controlled leader.
- Recruits owned by that profile.
- Inventory and equipment ownership.
- Profile progression and passive effects.
- Gold and other persistent resources.
- Stash and extraction access.
- Input and future viewport assignment.

### Host World Context

The host controls shared world decisions:

- Mode.
- Region and route.
- Difficulty and heat modifiers.
- Encounter seed.
- World-scoped unlock requirements.
- Campaign state shared by the active session.

The host does not own other players' gold, items, characters, stash, extraction, or personal progression.

## Squad Capacity

Squad capacity is profile-owned and includes the leader:

```text
profile squad size = 1 human-controlled leader + owned recruits in the run
```

The total number of active characters is:

```text
run character count = sum(active profile squad sizes)
```

Examples:

- One profile with capacity 4 may field one leader and three recruits.
- Four profiles with capacity 4 may field up to 16 characters.
- Four profiles with capacity 6 may field up to 24 characters.

Six is not a permanent hard-coded product ceiling. Passive trees may permit larger profile squads if performance tests show acceptable frame time, memory, navigation, collision, UI, and visual readability on the supported hardware targets.

Developer Mode's existing 24-character control is a current testing boundary, not the final progression contract. Any raised production or developer ceiling requires recorded performance evidence.

## Character Ownership, Inventory, and Equipment

- Each profile owns its leader and the followers it recruits.
- Each character has an independent equipment sheet.
- Each profile has its own in-run inventory.
- The Character Ledger can navigate every owned/current party member, including parties larger than six.
- A player can equip and modify characters they own.
- A player can drop an item for another player.
- Picking up a dropped item transfers run ownership to the recipient profile.
- Discarding or destroying an item requires explicit confirmation and permanently removes it.

Item ownership changes use idempotent transactions so a crash cannot duplicate an exchanged, destroyed, or extracted item.

## Gold and XP Reward Sharing

Distance is the first reward eligibility gate.

### Gold

When a creature grants gold:

- Each active player profile with an eligible squad inside the configured reward-sharing distance receives the same amount.
- Profiles outside the distance receive none.
- The gold is newly granted to each eligible profile; it is not divided from one shared wallet.
- Every profile spends only its own balance.

### XP

Each character has separate XP and a separate level shown in the Character Ledger.

XP processing is:

1. Reject squads outside reward-sharing distance.
2. Grant an eligible role-aware baseline so support characters are not punished.
3. Add weighted contribution for damage, healing, prevention, control, buffs, debuffs, and kills.
4. Apply other explicit XP modifiers.

Distance and contribution calculations use authoritative world positions and stable event records. The precise reward radius and weighting values are tunable data.

This prevents players on a large campaign map from separating into unrelated regions while multiplying each other's farm.

## Character Level Results

Only human-controlled leader characters produce upgrade-card selections when they level.

Every character, including leaders and followers, gains deterministic class-weighted growth in:

- Strength.
- Dexterity.
- Constitution.
- Intelligence.
- Wisdom.
- Charisma.

Fractional growth accumulates rather than being discarded. Followers level without presenting upgrade cards. Leaders receive both their class attribute growth and their upgrade choice.

## Stash, Inventory, and Extraction Progression

### Stash

- Stash is persistent and per profile.
- It is stored in the city, outside the run inventory.
- Initial Stash Access creates one tab with 100 item slots.
- Additional tabs and features come from the Warehouse tree.

### Inventory

- Each player profile begins with one inventory column of five slots once inventory exists.
- Passive progression expands the inventory to eight columns by five rows, or 40 slots.
- Inventory capacity belongs to each profile independently.

### Extraction

- Extraction begins locked.
- The first extraction unlock permits one item.
- Further progression increases extraction capacity.
- Late progression can extract complete equipment sheets and full inventories.
- Each player extracts only through their own profile's unlocked capacity into their own stash.
- One player may be able to extract when another cannot.

### Loss and Bring-In Gear

- A full party wipe loses everything still equipped or carried in the run.
- Items already secured in the city stash survive.
- Bringing stash gear into a run remains locked until sufficient inventory and extraction progression has been unlocked.
- Later Campaign and Adventure events include shops and an upgradable cart that can send limited items back to base.

## Future Equipment Contract Preserved by This Design

The equipment implementation is deferred, but profile and feature storage must preserve these approved rules:

- Eleven equipment slots: helmet, body armour, legs, gloves, boots, amulet, two rings, belt, main hand, and offhand.
- A two-handed item occupies main hand and reserves offhand unless a tagged rule overrides it.
- Bows may pair with quivers through compatibility tags.
- Eligibility uses overlapping capability tags, attribute requirements, equipment weight, and item-specific rules.
- Equipped items are stored separately from inventory.
- Equipping can swap directly; unequipping requires free inventory space.
- Keyboard/mouse pickup uses hover and click.
- Controller pickup highlights a directional candidate, cycles with the D-pad, and confirms with the south face button.
- Arena and Survival use a rarity-aware ground-item soft cap, initially 60 and Developer Mode adjustable from 10 through 500.
- Highlighted or hovered items receive cleanup protection.
- Common through Legendary are functional in Developer Mode; Player Mode initially exposes Common and Uncommon.
- Mythic through Eternal are registered future rarities.
- Affixes use prefix and suffix pools, item-level/content tier gates, rarity-specific minimum and maximum tiers, and tagged Legendary powers.

These rules require stable item IDs, versioned item data, and profile-owned containers from the beginning.

## Developer Mode Contract

Developer Mode supports fast implementation and testing through:

- Unlock All Implemented Content.
- God Mode.
- Free passive resets.
- Full tree visibility.
- Expanded party/squad limits.
- Enemy-density controls.
- Direct arena quick start.
- Visibility of implemented Developer Preview pages and mechanics.

Developer Mode does not:

- Make Coming Soon features functional.
- Permanently grant feature unlocks.
- Spend or grant production Passive Points unless an explicit test action requests it.
- Mark milestones complete.
- Contaminate a profile's normal progression.

The active run captures effective overrides in an immutable rules snapshot.

## First Implementation Slice

### Phase 1: Protect the Baseline

- Record the live branch, worktree state, and user-owned changes.
- Run the current automated suites and arena smoke path.
- Preserve gameplay wrappers, collision, fallback visuals, and CharacterPresentation boundaries.
- Keep the existing class selection accessible as the run-setup destination.

### Phase 2: Profiles and Transactions

- Implement profile index and profile creation.
- Implement versioned profile state and explicit migrations.
- Implement atomic saves, verified backups, and recovery.
- Implement idempotent transaction IDs.
- Add the Profiles Settings tab and last-active profile.
- Add Manual Save and mode-aware Save & Quit seams.

### Phase 3: Passive Runtime and Unlocks

- Revise the City tree through the Passive Skill Tree Creator.
- Store its editable source and runtime export in an agreed Party Forge-owned location.
- Integrate the loader and Party Forge effect mapping.
- Implement Passive Points, allocation, progressive fog, refunds, permanent nodes, class dormancy, effect scopes, and feature policies.

### Phase 4: Evolving Menu and Prologue

- Build the blocked-out live city menu.
- Build the complete one-time camera path and tutorial handoff.
- Implement prologue checkpoints and completion transaction.
- Implement the returning menu, building routing, and accessibility drawer.
- Retain Developer Quick Start.

### Phase 5: First Active Services

- Wire selected City nodes to real consumers.
- Implement profile squad-capacity resolution.
- Implement Stash Access with one 100-slot tab.
- Reveal the Warehouse building and tree shell.
- Ensure player-mode concealment and Developer Mode access behave consistently.

## Migration and Compatibility

- Existing saves/settings must load with safe defaults where no profile data exists.
- The current machine settings file remains separate from profile progression.
- Current class resources and stat backend remain authoritative for their implemented domains.
- The Character Ledger retains scrolling access beyond six members.
- The existing start flow is routed behind the new menu rather than deleted until replacement paths are proven.
- Current arena access remains available throughout implementation.
- The Fighter `CharacterPresentation` adapter and fallback contracts remain intact.
- Existing user-owned changes in `scenes/game/main.tscn` and `assets/ui/currency/` must be inspected and preserved rather than overwritten.

## Failure Handling

### Profile Failure

- Never silently create a blank replacement for a damaged profile.
- Verify and recover the newest valid backup when possible.
- Preserve damaged originals for diagnosis.
- Present a clear recovery-required state when automated recovery is unsafe.

### Passive Tree Failure

- Reject invalid exports before allocation.
- Report tree ID, node ID, connection, or effect mapping involved.
- Preserve saved allocation identifiers.
- Fail unknown effects closed.
- Do not partially grant a node whose effects cannot be fully validated.

### Transaction Failure

- Grants, purchases, exchanges, destruction, extraction, allocation, refund, and prologue completion use idempotent transaction IDs.
- A retry returns the previous committed result rather than applying value twice.
- A failed write does not claim success to the UI.

### Runtime Consumer Failure

- Feature consumers revalidate access when opening and when mutating state.
- Missing optional UI content falls back to a safe unavailable state.
- Gameplay remains launchable through the last proven route when a new menu or passive surface fails during development.

## Verification Strategy

### Automated Domain Tests

Cover:

- Profile creation and unique IDs.
- Schema migrations.
- Atomic-save promotion and backup recovery.
- Corrupt-primary recovery without silent data loss.
- Transaction idempotency.
- One-time prologue reward behavior.
- Passive export validation.
- Connected allocation and refund rejection.
- Graph-distance fog and progression-expanded reveal radius.
- Permanent-node protection.
- Conditional class access and dormant-state restoration.
- Effect-scope resolution.
- FeatureAccessPolicy behavior in Player and Developer modes.
- Per-profile squad-cap calculations.
- Reward-distance eligibility.

### Godot Integration Smokes

Cover:

- Fresh launch with no profiles.
- Profile creation and restart.
- First cinematic handoff.
- Tutorial checkpoint resume.
- Atomic tutorial completion and first Passive Point.
- Returning-player menu.
- City tree open, allocate, save, restart, and refund.
- Developer Quick Start.
- Existing arena launch and combat.
- Character Ledger access.
- Fighter presentation and downstream attack/damage behavior.

### UI and Input Matrix

Validate keyboard/mouse and controller at:

- 1920x1080.
- 2560x1440.
- 3840x2160.

Verify focus order, tab navigation, controller cancel behavior, hidden/Coming Soon presentation, drawer navigation, tree navigation, tooltips, and profile selection.

### Performance Baselines

Record frame time, memory, physics load, navigation load, UI behavior, and entity count at progressive squad sizes. Include a four-player 24-character target simulation before treating that capacity as production-safe.

Higher passive-tree capacity unlocks require updated evidence on the supported hardware tiers.

## Acceptance Criteria

The milestone is complete when:

1. A fresh install can create and safely reload a profile.
2. The first profile sees only Play, Settings, and Quit before the prologue.
3. The city flight plays automatically only for that profile's first tutorial.
4. Tutorial completion atomically grants one Passive Point and reveals the City tree.
5. Returning profiles reach normal run setup without replaying the flight.
6. The City tree is loaded from creator-authored data and supports validated allocation, save/reload, progressive fog, and legal refunds.
7. FeatureAccessPolicy distinguishes Player Mode, Developer Preview, Coming Soon, and Unlock All correctly.
8. Developer Mode can quick-start the current arena without permanently changing profile progression.
9. Per-profile ownership, squad capacity, gold, and persistent progression boundaries exist even before split-screen is fully playable.
10. Stash Access creates one profile-owned 100-slot tab and reveals the Warehouse progression seam.
11. Existing arena, stats, upgrades, ledger, pause/settings, controller, projectile, and Fighter presentation behavior remain functional.
12. Profile or tree corruption produces an explicit safe failure or verified recovery, never silent data loss.
13. The approved automated, integration, UI, and performance evidence is recorded before the milestone is declared complete.

## Deferred Tuning Decisions

These values remain data-driven and require later playtesting rather than blocking architecture:

- Reward-sharing distance and whether specific modes modify it.
- Passive Point milestone frequency and renewable acquisition rate.
- Respec price curve and eventual dedicated respec resources.
- Exact nodes and costs that expand fog visibility.
- Exact squad-capacity node cadence and production-tested ceiling.
- Warehouse tree topology and tab-unlock costs.
- Tutorial encounter pacing and narrative.
- Final city layout, building art, camera duration, skip behavior, and accessibility presentation.

## Recommended Next Step

After the user reviews this committed design document, create a separate implementation plan with small, testable tasks and explicit approval checkpoints. Do not begin production implementation from this design document alone.
