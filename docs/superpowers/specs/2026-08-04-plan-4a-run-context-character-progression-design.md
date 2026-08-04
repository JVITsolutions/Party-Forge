# Party Forge Plan 4A: Run Context and Character Progression Design

**Date:** 2026-08-04
**Status:** Approved design; awaiting written-spec review
**Applies to:** Party Forge Godot 4.7.1 authoritative checkout

## Purpose

Plan 4A introduces the ownership and progression boundary required for future local multiplayer, inventory, equipment, rewards, Arena progression, and Adventure Mode. Every participating profile receives an independent run context and party. Every character receives an independent run-scoped level, XP balance, and core-attribute progression state.

The current arena remains playable as a single-player compatibility route. Plan 4A proves multiple contexts through domain tests and a developer harness; it does not yet implement playable split-screen.

## Product decisions

- Use a dedicated multi-profile run-context layer rather than expanding `PartyManager` into a global multiplayer coordinator.
- The normal arena remains single-player during Plan 4A, but a developer harness proves at least two simultaneous profile contexts.
- XP is awarded only to available characters. Dead, downed, or spatially separated followers do not receive an award.
- Reward eligibility is two-stage: the player-controlled leader must qualify near the reward event, then each follower must remain within the leader's squad-link radius.
- Eligible characters receive the full XP award. XP is not divided by party size.
- Every level grants deterministic class-authored core-attribute growth.
- Every fifth level also grants `+1` to one class-weighted core attribute through deterministic run RNG.
- Leaders receive class growth and queue an upgrade-card choice. Followers receive class growth without an upgrade card.
- XP orbs remain part of the game as collectible reward packets.
- Arena Mode permits player joining only before a run. Adventure Mode may later permit drop-in at authored safe checkpoints.

## Ownership architecture

### RunContextRegistry

`RunContextRegistry` is the run-level authority for participating local players. It maps stable run-player IDs to `PlayerRunContext` instances and rejects duplicate run-player IDs, duplicate profile ownership, and invalid registrations without partial mutation.

Controller device numbers are not ownership identities. A controller can be reassigned or reconnected without changing the profile or run context it controls.

### PlayerRunContext

Each `PlayerRunContext` owns:

- Stable run-player ID and player-slot index.
- Persistent profile ID and a read-only profile snapshot needed to construct the run.
- One `PartyManager` containing that player's leader and recruits.
- Member-to-actor mappings for the context's live characters.
- One `CharacterProgressionState` per party member.
- Deterministic progression RNG derived from run seed and stable ownership identity.
- That player's pending leader-upgrade queue.
- Future inventory, equipment, gold, viewport, and save/resume seams.

The context boundary, not a controller ID or scene-tree location, is canonical for profile ownership.

### PartyManager compatibility

`PartyManager` continues to own squad membership, capacity, class ranks, traits, run upgrades, stat modifier sources, and resolved-stat caches. It does not coordinate other players or inspect other profiles.

During Plan 4A, the normal single-player route keeps `PartyForgeMain.party_manager` as a compatibility reference to its active context's party. Existing HUD, ledger, level-up, arena, and combat callers therefore continue to function while later milestones migrate to context-aware routing. The multi-context developer harness accesses parties through `RunContextRegistry` and must not treat this compatibility reference as a global authority.

Actors and combat events must carry or resolve a stable run-context identity so later contribution, inventory, and reward systems do not infer ownership from proximity or controller state.

## Character progression

### CharacterProgressionState

Each party member owns a run-scoped progression state containing:

- Member ID.
- Current character level.
- Current XP toward the next level.
- Current level's XP requirement.
- Accumulated core-attribute gains.
- Guaranteed class-growth history.
- Recorded milestone bonus outcomes.

Character progression resets at the beginning of a new run. Plan 4A provides deterministic snapshot and restore contracts for future manual save/resume work, but it does not persist active-run progression into `ProfileState` yet.

### Core attributes

The six core attributes are:

- Strength
- Dexterity
- Constitution
- Intelligence
- Wisdom
- Charisma

`ClassGrowthDefinition` is validated, data-driven content. Each implemented class must explicitly author:

- A repeatable guaranteed-growth cycle.
- Positive milestone weights for one or more core attributes.
- Stable display metadata for ledger and tooltip projection.

Guaranteed gains and milestone gains enter the existing stat pipeline as owned `StatModifierSource` records with stable source IDs. No progression code writes directly into resolved snapshots or duplicates `StatResolver` arithmetic.

The first Plan 4A tuning is provisional but complete for every currently implemented class. Later passive trees, equipment, effects, and profile unlocks may add or modify growth through additional typed sources rather than rewriting the base class definitions.

### Deterministic milestone rolls

Levels divisible by five grant one additional attribute point. The selected attribute is weighted by the character's `ClassGrowthDefinition`.

Each character uses a deterministic stream derived from:

- Run seed.
- Stable run-player ID or profile-derived run identity.
- Member ID.
- Milestone level.

Creating another context, recruiting another character, changing UI order, or resolving another player's reward first cannot change an existing character's milestone outcome.

### Leader and follower behavior

Every level applies class growth.

- A leader additionally queues one upgrade-card choice for its owning player context.
- A follower queues no upgrade card.
- Separate player contexts maintain separate pending leader-upgrade queues.
- A player can never spend or dismiss another player's pending upgrade.
- Simultaneous levels preserve stable queue order and lose no XP overflow.

The existing single-player level-up interface continues to consume the active context's leader queue. Multi-player upgrade presentation is deferred to the split-screen UI sequence.

## XP orbs and reward distribution

XP orbs remain spatial pickups and preserve pickup-radius upgrades, attraction behavior, collection feedback, and future pickup conversion effects.

An orb no longer writes directly to one global `ExperienceSystem`. It submits an idempotent reward packet to `RewardDistributionService` when collected.

For every registered run context, reward resolution performs these steps:

1. Confirm the context and leader are valid.
2. Confirm the leader is alive, available, and within the leader reward-share radius.
3. Award the orb's full XP value to the leader.
4. Evaluate every follower independently.
5. Award the full value only when that follower is alive, available, and within the squad-link radius of its own leader.
6. Record one resolution for the orb/context pair so retries cannot duplicate XP.

Eligibility is evaluated at collection time. A follower that was previously downed but is alive when the orb is collected can qualify; a follower downed before collection cannot.

`RewardDistributionTuning` owns the leader reward-share and follower squad-link distances. Both values must be positive, visible in Developer Mode diagnostics, and covered at inside, exact-boundary, and outside distances.

The same eligibility result can later distribute profile-owned gold and other shared rewards. Plan 4A implements XP only.

## Ledger and UI projection

The character ledger displays every member's:

- Character level.
- Current XP and next-level requirement.
- Progress bar or equivalent numeric projection.
- Core-attribute totals.
- Guaranteed-growth and milestone sources in the existing source breakdown.

The run HUD continues showing the active single-player leader's level and XP. Plan 4A does not add per-player HUD quadrants or split-screen overlays.

## Controller and profile ownership contract

### Arena lobby policy

Arena Mode locks player ownership before the run starts.

- Player 1 begins with the active host profile.
- The keyboard/mouse or controller that initiates Play becomes Player 1's assigned input.
- An unassigned controller can hold A/Cross to reserve the next available player slot.
- That device alone controls its profile-selection panel.
- The player selects an existing unused profile or creates a new one.
- Confirming the profile creates that slot's `PlayerRunContext`.
- Holding B/Circle before ready releases the slot and device claim.
- Starting the Arena locks controllers, profiles, player slots, leaders, and run contexts.
- Arena Mode permits no mid-run join, leave, profile swap, or controller transfer.
- A disconnected controller pauses the run and receives a reconnect prompt instead of silently transferring ownership.

Plan 4A defines these contracts and stable result codes but does not build the lobby UI or playable multi-controller routing.

### Future Adventure policy

Adventure Mode may later accept profile join and leave requests only at authored safe checkpoints. It will reuse the same player-slot, device-claim, profile-uniqueness, and run-context contracts rather than inventing a second ownership model.

## Profile onboarding contract

Party Forge distinguishes machine onboarding from profile onboarding.

### First profile on an installation

- When no profile exists and machine onboarding has not completed, the normal menu yields to a narrator introduction.
- The narrator asks the player's name. Confirming creates a valid profile with setup marked incomplete.
- The narrator asks which archetype best represents the player: Fighter, Ranger, or Mage.
- The selected starter becomes the profile's initial unlocked class, tutorial leader, and remembered story identity.
- Closing the game between questions resumes at the incomplete setup checkpoint.
- Completing the introduction records a machine-level onboarding flag.

### Later profiles

Profiles created from Settings or the multiplayer lobby offer:

- **Play Introduction:** run the narrator sequence.
- **Quick Create:** enter a name and choose Fighter, Ranger, or Mage directly.

Both routes produce equivalent valid profile data. Quick Create skips presentation, not required identity or unlock initialization. Deleting all profiles does not erase the machine onboarding flag. Developer Mode can preview or reset onboarding in isolated test state.

The narrator scene and production onboarding presentation are future work, not Plan 4A implementation scope.

## Arena Mode contract

Arena Mode is the first main mode unlocked after the tutorial.

`ArenaRunDefinition` will eventually author:

- Duration tier and wave schedule.
- Enemy, elite, and boss pools.
- Spawn and effect budgets.
- Wave-clear conditions and breather duration.
- Early-call availability and reward multiplier.
- Enabled mechanics, heat modifiers, and unlock requirements.
- Victory, defeat, and exceptional-result rewards.

Initial Arena runs last approximately five minutes. Progression unlocks longer and more complex variants until late-game configurations last approximately 30–60 minutes.

Wave acceleration uses a hybrid model:

- Clearing a wave advances automatically after a short breather.
- Players may propose **Call Next Wave** while enemies remain.
- Multiplayer requires shared confirmation.
- Confirmed early calls permit controlled wave overlap.
- A successfully accelerated wave grants one authored risk-based reward bonus.
- Repeated calls cannot duplicate wave-completion rewards.
- Spawn, enemy, projectile, and effect budgets remain enforced.

This full Arena loop is future work. Plan 4A provides only the run-context and mode-policy seams it will consume.

## Tutorial and Adventure relationship

The tutorial is a hybrid vertical slice:

```text
Profile introduction
-> starter-class awakening
-> city traversal and guided objectives
-> arrival at the coliseum
-> tutorial Arena battle
-> defeat or exceptional victory
-> meta-progression reveal
-> Arena Mode unlocked
```

The city portion previews future Adventure Mode exploration, interaction, objectives, and traversal without presenting Adventure as a selectable mode. The coliseum finale introduces Arena Mode's fixed roster, escalating combat, and results flow.

The final tutorial fight is expected to defeat a new player but is mechanically winnable. Both outcomes complete the prologue transition. An exceptional victory additionally grants:

- Two universal Passive Points.
- One future secret character.

After the tutorial, Arena Mode becomes the player's primary activity for the next progression phase. Arena accomplishments unlock characters, systems, duration tiers, city changes, and eventually full Adventure Mode.

The tutorial implementation, final city traversal, narrator presentation, coliseum encounter, and Adventure content are explicitly deferred.

## Split-screen implementation sequence

Split-screen work is divided into separately reviewable plans:

1. **Device and player-slot contracts:** unique device claims, profile uniqueness, reconnect reservations, join policies, and stable result codes.
2. **Hold-to-join lobby:** Player 1 host assignment, hold A/Cross join, per-controller profile creation/selection, ready/leave, and roster lock.
3. **Simultaneous player actors:** independent movement, input routing, leaders, recruits, targeting, and pause ownership.
4. **Adaptive split/merge cameras:** shared camera for nearby players; dynamic horizontal, vertical, or quadrant regions as groups separate and reunite.
5. **Per-player interfaces:** each player can view and control only their own ledger, upgrades, inventory, equipment, and profile-scoped interactions while the global game remains paused as required.
6. **Certification:** physical-controller combinations, disconnect/reconnect, keyboard-plus-controller, Steam Remote Play Together, 1080p/1440p/4K layouts, four-player performance, and 24-plus total party-character stress cases.

This sequence is recorded now so Plan 4A ownership decisions remain compatible with later local multiplayer. None of these six plans is implemented by Plan 4A.

The join interaction is inspired by Brotato's local-co-op slot claim, while Party Forge adds explicit per-player profiles and adaptive split/merge cameras. Brotato officially supports up to four local players and Steam Remote Play Together; public instructions describe holding the controller's south face button to join. Relevant references:

- https://steamcommunity.com/ogg/1942280/announcements/detail/4529024857187287257
- https://brotato-builds.com/coop
- https://steamcommunity.com/app/1942280/discussions/0/651430500729111266/

## Plan 4A implementation scope

Plan 4A implements:

- `RunContextRegistry` and independently owned `PlayerRunContext` instances.
- A two-profile developer harness without playable split-screen.
- Per-character level, XP, threshold, and core-attribute progression.
- Validated class-growth content for all currently implemented classes.
- Deterministic milestone bonuses every five levels.
- Leader-only upgrade queues and follower growth without cards.
- XP-orb routing through reward distribution.
- Ledger level, XP, and attribute-source projection.
- Single-player compatibility adapters.
- Join-policy, device-assignment, and mode-policy interfaces required by later plans.
- A recorded correctness and performance baseline through the current 24-character Developer Mode target.

Plan 4A explicitly does not implement:

- Tutorial scenes or city traversal.
- Narrator cinematics or final onboarding presentation.
- Hold-to-join or profile-selection lobby UI.
- Multiple playable humans or adaptive cameras.
- Reworked Arena waves, duration tiers, or Call Next Wave.
- Inventory, interactive equipment, gold, stash, extraction, shops, or item loss.
- Adventure Mode.

## Failure handling

- Duplicate profile ownership fails without creating or modifying a context.
- Duplicate controller claims fail without stealing an existing slot.
- Missing or invalid class-growth definitions prevent the affected run context from starting and report stable identifiers.
- Invalid or unavailable members receive no reward and do not block other valid awards.
- Reward packet/context pairs are idempotent.
- XP overflow and simultaneous level gains are never discarded.
- Invalid milestone weights fail closed before a run starts.
- A failed stat-source application rolls back that character's level transaction instead of leaving attributes and level out of sync.
- One context's failure cannot partially mutate another context.

## Verification

Plan 4A requires:

- Pure unit coverage for registry uniqueness, context lifecycle, progression transactions, growth definitions, deterministic milestone outcomes, and reward eligibility.
- RED/GREEN regression coverage for every production behavior change.
- Multi-context tests proving one player's registration, XP, RNG, level, upgrade queue, or failure cannot mutate another player's state.
- Distance tests inside, exactly on, and outside both eligibility radii.
- Dead, downed, revived-before-collection, and separated-follower cases.
- Simultaneous multi-level awards with exact overflow and queue ordering.
- Orb retry/idempotency and pickup-radius compatibility.
- Ledger projection for every party member through the current 24-member developer target.
- A developer harness with at least two independent profile contexts.
- Recorded frame-time, physics, memory, and UI behavior at progressive party sizes through 24 total characters.
- Fresh Godot import, focused integration runners, the complete existing suite, and startup smoke.
- Physical-controller checks remain deferred until the playable local-multiplayer plan.

## Acceptance criteria

Plan 4A is complete when:

1. Multiple profile-owned run contexts can coexist without shared mutable party or progression state.
2. The current single-player arena still starts, awards orb XP, queues leader upgrades, and renders its HUD and ledger.
3. Every character levels independently and receives only its authored growth.
4. Followers never create upgrade cards.
5. Every fifth-level bonus is deterministic and isolated from other contexts.
6. Reward eligibility follows the approved leader-range plus follower-link rule.
7. Downed, dead, or separated followers receive no XP.
8. The two-profile developer harness and 24-character baseline are recorded.
9. Future split-screen, Arena, tutorial, and Adventure work can consume the new contracts without rewriting ownership.
10. Deferred systems remain hidden, unavailable, or honestly labeled rather than exposed as functional content.
