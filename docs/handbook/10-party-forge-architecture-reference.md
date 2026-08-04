# 10. Party Forge Architecture Reference

> **Runtime architecture:** Functional Main Menu Plan 3A automation candidate through `ce057a949f8f64bfb661aded26dcfec3cdcdb44c`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-08-04`

## How to use this reference

Use this chapter after you understand the concepts in Chapters 1–9. Start with the change-owner decision table, follow its path to the owning data, scene, or script, then use the matching verification checklist.

This is a map of the architecture at the immutable Plan 3A automation-candidate commit above. Its automated verification is recorded in `docs/verification/2026-08-03-functional-main-menu.md`; connected manual windowed acceptance remains a separate gate. The map is not a promise that every folder is automatically discovered or every exported field is consumed. Confirm the live source before extending it.

> **Party Forge convention:** Data definitions describe content, scenes compose runtime nodes, focused scripts own behavior, and `PartyForgeMain` wires front-end routing and the main run.

## Top-level project map

| Path | Purpose |
| --- | --- |
| `data/` | External `.tres` definitions for attacks, classes, enemies, traits, and upgrade tuning |
| `scenes/` | Saved node trees for the main game, actors, enemies, combat effects, UI, arena, camera, progression, and developer sandbox |
| `scripts/` | Typed GDScript behavior and data classes, organized by gameplay responsibility |
| `tests/` | Custom headless runner, assertions, and the discoverable unit suites in `tests/unit/` |
| `tools/` | One-off data generation and validation scripts; not ordinary runtime systems |
| `docs/` | Handbook, development guidance, design/plan records, and validation evidence |
| `project.godot` | Main scene, display/stretch settings, input actions, renderer, and project identity |

The configured main scene is `res://scenes/game/main.tscn`. There is no `[autoload]` section in the verified `project.godot`; Party Forge's service-like nodes are children of the main scene, not global autoload singletons.

## Runtime scene tree

The saved main tree begins as:

1. `Main` — scripted by `PartyForgeMain`.
2. `Main/GameRun` — owns run-state transitions.
3. `Main/PartyManager` — owns party composition, ranks, traits, and upgrades.
4. `Main/ExperienceSystem` — owns experience and pending level-ups.
5. `Main/SpawnDirector` — owns timed regular-enemy spawning and reward-orb creation.
6. `Main/PartyActorSpawner` — creates companions after recruitment.
7. `Main/Arena` — instanced arena, player start, and enemy spawn markers.
8. `Main/Actors` — runtime leader and companions.
9. `Main/Enemies` — runtime regular enemies and boss.
10. `Main/Effects` — projectiles, area bursts, heal visuals, experience orbs, and boss telegraphs.
11. `Main/LeaderCamera` — follows the selected leader.
12. `Main/HUD` — status, catalog-driven `ClassSelectionPanel`, level-up panel, run-result panel, and boss banner.

13. `Main/CharacterLedger` — full-screen paused character inspection, instanced from `scenes/ui/ledger/character_ledger.tscn`.
14. `Main/RunPauseMenu` — separate Resume, Settings Coming Soon, and confirmed Quit Run overlay, instanced from `scenes/ui/run_pause_menu.tscn`.

15. `Main/MainMenuScreen` - Plan 3A front door on canvas layer 5.
16. `Main/SettingsScreen` - Settings and Profiles child route on layer 10.
17. `Main/PassiveTreeScreen` - production City tree or Developer preview child route on layer 12.
18. `Main/ProfileManager` - composed profile persistence and selection service.
19. `Main/DeveloperModeBadge` - applied run-rule mode indicator above the front-end backdrop.

Boot opens `MainMenuScreen`; class selection remains hidden until a profile-aware route opens it as run setup. After leader selection, `PartyForgeMain` instances `Leader` under `Actors`, configures it from a `ClassDefinition`, attaches one `HealthBar3D`, configures the camera and spawn director, hides run setup, reveals the run HUD, and starts the run. Recruits create `Companion` instances under `Actors`; enemies and effects appear only at runtime. Use the Remote tree to see them.

## System ownership table

| Owner | File | Owns | Does not own |
| --- | --- | --- | --- |
| `PartyForgeMain` | `scripts/game/main.gd` | Profile-aware boot, menu/Settings/run-setup/City routing, desktop quit, catalog gate, leader selection, run-rule capture, service wiring, upgrade application, boss creation, result UI | Definition values, profile schema rules, passive-tree rules, or low-level combat math |
| `GameRun` | `scripts/game/game_run.gd` | Run-state facade, pause policy, elapsed-time forwarding, debug time scale, victory/defeat signals | Enemy weights or UI layout |
| `RunStateMachine` | `scripts/game/run_state_machine.gd` | `SETUP`, `RUNNING`, `LEVEL_UP`, `BOSS`, `VICTORY`, `DEFEAT`; five-minute boss transition; terminal lock | Scene instancing |
| `PartyManager` | `scripts/party/party_manager.gd` | Members, class ranks, trait counts/tiers, party-stat ranks, per-trait upgrades, action-aware stat snapshots, shared party combat dependencies, four-member cap | Actor node movement or rendering |
| `ExperienceSystem` | `scripts/progression/experience_system.gd` | Experience totals, increasing thresholds, pending levels, `level_ready` | Choice generation or applying upgrades |
| `SpawnDirector` | `scripts/game/spawn_director.gd` | Regular spawn timing, weighted ID sampling, two regular scene preloads, spawn markers, reward-orb creation | Catalog discovery or boss behavior |
| `PartyActorSpawner` | `scripts/party/party_actor_spawner.gd` | Companion instancing, initial placement, combat configuration, companion health bars | Leader creation or party membership decisions |
| `PartyActor` | `scripts/characters/party_actor.gd` | Definition-driven health/combat setup, target collection, attacks, visual health feedback, team identity, and combat-target record | Formation movement policy for companions |
| `AttackController` | `scripts/combat/attack_controller.gd` | Attack definition, cooldown advancement, in-range target selection, `attack_ready` signal | Damage/projectile/heal execution |
| `AttackExecutor` | `scripts/combat/attack_executor.gd` | Party packet preparation/delivery, melee/projectile/area execution, separate healing, effect spawning | Defense formulas or choosing new unsupported attack kinds |
| `DamageResolver` | `scripts/combat/damage_resolver.gd` | Typed packet preparation; crit, dodge, mitigation, incoming multiplier, block, final health application, and overkill-safe life steal order | Target selection, movement, or visual effects |
| `RecoveryController` | `scripts/combat/recovery_controller.gd` | Frame-rate-independent regeneration from current resolved stats | Damage mitigation or revive timing |
| `HealthComponent` | `scripts/combat/health_component.gd` | Final health application, down/death state, healing, revive timing, and health signals | Armor/resistance/dodge/block formulas, actor movement, targeting, or rewards |
| `HUD` | `scripts/ui/hud.gd` and `scenes/ui/hud.tscn` | Status text, party/trait display, boss status and banner, composition of panels | Applying an upgrade choice |
| `MainMenuViewModel` | `scripts/ui/main_menu/main_menu_view_model.gd` | Pure projection of active profile, applied settings, and City runtime availability into stable route IDs and visible actions | Nodes, files, routing side effects, or profile mutation |
| `MainMenuScreen` | `scripts/ui/main_menu/main_menu_screen.gd` and `scenes/ui/main_menu/main_menu_screen.tscn` | Blockout presentation, copied projections, route intents, accessibility text, responsive geometry, and visible-action focus loop | Profiles, settings files, run initialization, passive-tree rules, or desktop quit |
| `ProfileManager` | `scripts/profile/profile_manager.gd` | Profile bootstrap, active-profile selection, refresh, and change signals over the profile store | Main-menu presentation or scene routing |
| `ClassSelectionPanel` | `scripts/ui/class_selection_panel.gd` and `scenes/ui/hud.tscn` | Reusable run-setup lifecycle, Back intent, ordered runtime buttons, stable `Class_<id>` names, and `class_selected(class_id)` | Catalog registration, ID validation, profile mutation, or starting the run |
| `LevelUpPanel` | `scripts/ui/level_up_panel.gd` and `scenes/ui/level_up_panel.tscn` | Three upgrade cards, shared hover/focus tooltip presentation, recipient selection, confirmation/rejection state, guarded `confirmation_requested` signal | Final revalidation or mutating party state |
| `RunResultPanel` | `scripts/ui/run_result_panel.gd` and `scenes/ui/run_result_panel.tscn` | Victory/defeat display and restart/quit requests | Deciding the run result |
| `CharacterLedger` | `scripts/ui/ledger/character_ledger.gd` and `scenes/ui/ledger/character_ledger.tscn` | Open/close and pause lease, page registry, selected member/page context, tab and party-rail focus, responsive mode, page instancing | Stat formulas, upgrade eligibility/application, profile unlocks, multiplayer input assignment |
| `LedgerDataProvider` | `scripts/ui/ledger/ledger_data_provider.gd` | Page-facing member, stat, stat-detail, applicable-upgrade, and upgrade-detail records over current domain state | Combat recalculation, gameplay mutation, direct UI composition |
| `RunPauseMenu` | `scripts/ui/run_pause_menu.gd` and `scenes/ui/run_pause_menu.tscn` | Separate pause action, Resume, disabled Settings explanation, Quit Run confirmation, pause lease | Front-end destination, save behavior, ledger state |

## Content definition table

| Type | Schema | External instances | Describes |
| --- | --- | --- | --- |
| `ClassDefinition` | `scripts/data/class_definition.gd` | `data/classes/*.tres` | Identity, role, color, trait IDs, capability tags, base-stat overrides, health/movement fallbacks, revive settings, formation distances, primary attack, optional support action |
| `AttackDefinition` | `scripts/data/attack_definition.gd` | `data/attacks/*.tres` | Attack kind, typed damage components or heal power, action tags, crit permission, cooldown, range, projectile speed, and area radius |
| `DamageTypeDefinition` | `scripts/data/damage_type_definition.gd` | `data/damage_types/core_damage_types.tres` | Damage-type identity, offense/defense stat mappings, mitigation rule, and resistance bounds |
| `TraitDefinition` | `scripts/data/trait_definition.gd` | `data/traits/*.tres` | Trait identity, supported stat ID, count thresholds, bonus values, and optional effect radius |
| `EnemyDefinition` | `scripts/data/enemy_definition.gd` | `data/enemies/*.tres` | Enemy identity, behavior enum, health, speed, typed stat overrides, linked attacks, and experience |
| `UpgradeTuning` | `scripts/data/upgrade_tuning.gd` | `data/upgrades/default_upgrades.tres` | Party-stat maximum rank and per-rank party/trait upgrade steps |
| `UpgradeDefinition` / `StatUpgradeEffect` | `scripts/data/upgrade_definition.gd`, `scripts/data/stat_upgrade_effect.gd` | `data/upgrades/cards/*.tres` | Card identity, scope, eligibility, rank/weight metadata, tooltip keywords, and stat effects |
| `ExperienceTuning` | `scripts/data/experience_tuning.gd` | `data/progression/default_experience.tres` | Base, linear, and accelerating next-level experience costs |
| `StatCatalog` / `StatDefinition` | `scripts/stats/stat_catalog.gd`, `scripts/stats/stat_definition.gd` | `data/stats/core_stats.tres` | Registered stat defaults, limits, precision, formatting, visibility, capability tags, and keyword IDs |

Definitions are Resources, not running actors. `GameCatalog` explicitly loads class, trait, enemy, damage-type, keyword, and required upgrade definitions; `PartyManager.STAT_CATALOG` loads the stat catalog. Party attacks are reached through class references; enemy definitions link their behavior-required attacks explicitly. Card source rows live in `tools/character_upgrade_content_rows.gd`; `tools/create_character_upgrade_data.gd` generates their `.tres` files, whose exact paths must also be added to `GameCatalog.REQUIRED_UPGRADE_PATHS`.

## Front-end and main run data flow

1. Godot instances `scenes/game/main.tscn` from `project.godot`.
2. `PartyForgeMain._ready()` bootstraps profiles, loads applied machine settings, loads catalog/passive-tree services, wires intents once, and presents `MainMenuScreen`. It does not auto-open Profiles or class selection.
3. `MainMenuViewModel.build()` creates a copy-owned projection. With no active profile, the player sees Play, Settings, and Quit; Play opens Settings directly on Profiles and focuses profile creation.
4. Profile creation or activation emits manager signals. `PartyForgeMain` refreshes the projection, returns to the menu, and displays the selected profile without starting a run.
5. `NOT_STARTED` and `IN_PROGRESS` primary actions use named temporary prologue seams; `COMPLETED` uses Begin Run. Plan 3A routes all three to existing run setup without mutating prologue state.
6. A completed profile with durable City discovery can open the production passive-tree projection. Applied Developer Mode exposes a full-visibility City preview and Developer Quick Start; neither override grants durable profile progress.
7. Run setup calls `ClassSelectionPanel.configure(catalog.classes)` for the nine ordered buttons. Back returns to the menu; Settings and passive-tree children restore their exact originating controls.
8. A runtime `Class_<id>` button emits `class_selected(class_id)`, connected once to `select_leader_class(class_id)`. Developer Quick Start delegates to the same Fighter launch path after saved-mode/profile/catalog guards.
9. The selected definition initializes `PartyManager`; the leader, health bar, camera, HUD, `PartyActorSpawner`, and `SpawnDirector` are configured. `GameRun.start_run()` moves `SETUP` to `RUNNING`.
10. `GameRun` advances elapsed time while `SpawnDirector` advances its regular spawn schedule. Level-ready signals pause in `LEVEL_UP`; selecting a valid choice resumes the prior running or boss state.
11. At 300 seconds, `RunStateMachine` enters `BOSS` and emits `boss_requested`; `PartyForgeMain` instances the Forge Guardian.
12. Leader terminal death locks `DEFEAT`; boss defeat during `BOSS` locks `VICTORY`. The result panel appears and hostile transient effects are cancelled.

## Character Ledger and run-pause flow

`CharacterLedger` is the full-screen shell at `scripts/ui/ledger/character_ledger.gd`, composed by `scenes/ui/ledger/character_ledger.tscn` and instanced as `Main/CharacterLedger` in `scenes/game/main.tscn`. It owns opening and closing, its `RunPauseLease`, page registration/instancing, the party-member rail, selected member and page state, focus routing, and the desktop/compact policy in `scripts/ui/ledger/ledger_responsive_layout.gd`. Page-specific rendering remains in independent scenes behind `scripts/ui/ledger/character_ledger_page.gd`:

- Stats: `scripts/ui/ledger/stats_ledger_page.gd` and `scenes/ui/ledger/stats_ledger_page.tscn`.
- Current Upgrades: `scripts/ui/ledger/upgrades_ledger_page.gd` and `scenes/ui/ledger/upgrades_ledger_page.tscn`.

### Page descriptors and availability

`scripts/ui/ledger/ledger_page_definition.gd` defines stable IDs, labels, display order, optional page scenes, feature/unlock IDs, unavailable text, and four development states: `HIDDEN`, `COMING_SOON`, `DEVELOPER_PREVIEW`, and `AVAILABLE`. `scripts/ui/ledger/ledger_page_catalog.gd` validates, deduplicates, and orders those descriptors. The current catalog is `data/ui/ledger_pages/default_ledger_pages.tres`:

| Descriptor | Current state | Runtime result |
| --- | --- | --- |
| `data/ui/ledger_pages/stats.tres` | `AVAILABLE` | Instantiates the Stats page |
| `data/ui/ledger_pages/current_upgrades.tres` | `AVAILABLE` | Instantiates the Current Upgrades page |
| `data/ui/ledger_pages/equipment_inventory.tres` | `COMING_SOON` | Focusable explanation; no page scene and no activation or cycle target |

`scripts/ui/ledger/ledger_feature_gate.gd` resolves descriptor state conservatively. The shell currently constructs it with Developer Preview disabled. Feature and unlock IDs are reserved integration points; there is no profile, unlock, or Developer Mode provider in this milestone.

### Only page-facing domain adapter

`scripts/ui/ledger/ledger_data_provider.gd` is the only domain adapter consumed by ledger pages. `PartyForgeMain` configures the shell in `scripts/game/main.gd` with `GameRun`, `PartyManager`, `GameCatalog`, and the `_ledger_health_for_member()` callback. The provider converts those sources into page-ready `member_rows()`, `stat_rows()`, `stat_detail()`, `upgrade_rows()`, and `upgrade_detail()` records. Pages do not search the SceneTree, read private party dictionaries, mutate gameplay, or implement combat formulas.

The Stats flow is:

1. The shell activates a member through `scripts/ui/ledger/ledger_player_context.gd`.
2. `StatsLedgerPage` requests provider rows for that member and the Show All state.
3. The provider reads `PartyManager.stats_for(member_id)`, `StatCatalog`/`StatDefinition`, and `ResolvedStatSnapshot`.
4. Detail records use `ResolvedStatSnapshot.breakdown()` and canonical stat/keyword metadata; `StatDefinition.format_value()` supplies display formatting.
5. The page renders grouped rows and named source lines. It does not calculate armor estimates or any second version of a combat value.

The Current Upgrades flow is:

1. `LedgerDataProvider.upgrade_rows()` combines the registered upgrade definitions with the selected member's current class, personal, party, and applicable trait state.
2. Repeated ownership records collapse deterministically by upgrade ID/rank and exclude records that do not affect the member.
3. `LedgerDataProvider.upgrade_detail()` delegates canonical copy and resolved effects to `scripts/progression/upgrade_presentation_service.gd`.
4. `UpgradesLedgerPage` renders the provider record or the deliberate `No upgrades acquired yet` state; it never reads private upgrade-rank/source collections.

### Input, pause ownership, and front-end return

Character inspection and ordinary pausing are separate:

- `character_ledger` (`Tab`, `I`, or controller View/Back) toggles the ledger during `RUNNING`, `BOSS`, or `LEVEL_UP`; `ui_cancel` closes it. Its lease records whether another system had already paused the tree, so closing a ledger opened over level-up preserves that pause.
- `pause_menu` (`Escape` or controller Menu/Start) opens `scripts/ui/run_pause_menu.gd` only during `RUNNING` or `BOSS`. It refuses to open while the ledger is visible. Its own lease prevents Resume from clearing a pause it did not add, and Quit confirmation handles Cancel before the surrounding menu.

`scripts/game/main.gd` connects `RunPauseMenu.quit_run_confirmed` to `_return_to_front_end()`. The current route unpauses and reloads `scenes/game/main.tscn`, returning to the functional main menu with the active profile reloaded. It is not save-and-quit or the desktop `_quit()` path.

### Current single-player boundary

`scripts/ui/ledger/ledger_player_context.gd` stores a local-player ID, selected member, active page, last focus path, and opener state. The shell accepts a context collection, but this milestone creates and uses only local player `0`, with the current leader as the initial controlled member. The responsive policy supports one desktop layout and a compact boundary below `1100x650`; it does not create per-player viewports.

The following remain explicitly deferred: functional Equipment and Inventory; resumable run checkpoints/history; final character-ownership filtering; local multiplayer profile seats, controller assignment, and close arbitration; multiple ledger panes; and split, merged, or dynamic gameplay cameras. Profiles, applied Developer Mode, production City-tree access, and the blockout main-menu routes are now composed outside the ledger.

## Class and party flow

1. `GameCatalog` loads nine ordered `ClassDefinition` Resources with trait IDs, capabilities, base-stat overrides, and linked attacks.
2. `PartyManager.initialize()` creates the leader's `PartyMemberState`, records class rank one, and recalculates trait counts.
3. `PartyForgeMain` configures the leader `PartyActor` from that member state.
4. A recruit choice calls `PartyManager.recruit()` while fewer than four members exist.
5. `member_added` reaches `PartyActorSpawner`, which instances and configures a companion plus health bar.
6. Trait counts are recalculated from every member's class trait IDs; the highest achieved threshold becomes active.
7. Class-rank, party-stat, and per-trait upgrades invalidate manager snapshots; action-aware stats feed `DamageResolver`, while `CombatModifiers` retains movement/timing values.
8. Companion movement uses role, preferred distance, tether distance, leader position, hostile position, and party separation.

`class_rank_power_step` scales typed attack damage for ranks above one. Recruiting a duplicate class contributes another member and its traits but does not itself increment the class rank.

## Combat flow

1. `PartyActor` advances its `AttackController` cooldown and collects live `CombatTarget` records from `party_actors` and `hostile_actors`.
2. Primary target selection rejects unavailable and same-team targets and applies range; support healing separately chooses an injured, available same-team target in range.
3. A ready controller emits `attack_ready(definition, target)`.
4. `AttackExecutor` gets the source combat adapter with normalized action tags. Healing reads `healing_power` directly and creates no damage packet.
5. A damaging execution prepares one immutable `DamagePacket`; a shared crit result belongs to that execution.
6. Melee, projectile, and area delivery obtain current target adapters, deduplicate and sort multi-target IDs, then call `DamageResolver.resolve()` independently per defender.
7. The resolver performs target dodge, typed mitigation/resistance, incoming modifiers such as Vanguard, block, final `HealthComponent.apply_damage()`, and actual-health-based life steal in that order.
8. Party and enemy projectiles carry packets plus the shared RNG/type dependencies; timed effects clean themselves up after impact or lifetime.
9. `RecoveryController` advances continuous regeneration before attacks, while health signals drive flash, down/revive presentation, bars, leader defeat, and enemy defeat.

Damage and healing are separate: Party Damage scales damaging packets, while heals use action-aware `healing_power` without entering `DamageResolver`.

## Enemy and reward flow

1. `SpawnSchedule.sample(elapsed)` returns the current interval plus Swarmer and Spitter weights for times from zero to under 300 seconds.
2. `SpawnDirector.sample_enemy_id()` selects `swarmer` or `spitter` from those weights.
3. `SpawnDirector.spawn_enemy()` accepts only those two regular IDs, chooses an off-camera marker, instances the matching preloaded scene, assigns a deterministic `enemy:<sequence>` combat identity plus shared RNG/type dependencies, configures target/effects support, and connects `reward_dropped`.
4. The scene's attached script—not `EnemyDefinition.behavior`—runs Swarmer or Spitter behavior.
5. `EnemyActor.configure()` applies definition health and connects terminal health to guarded defeat; behavior scripts prepare exact linked attack IDs and resolve them through adapters.
6. On defeat, `EnemyActor` emits one reward with the definition's experience and queues itself for deletion.
7. `SpawnDirector._on_reward_dropped()` instances an experience orb under `Effects`.
8. The orb follows the leader within pickup radius; collection adds experience to `ExperienceSystem` and frees the orb.

The Forge Guardian is boss-only. `PartyForgeMain` instances it in response to the five-minute boss request; it is not one of `SpawnDirector`'s two regular IDs.

## Level-up flow

1. An experience orb calls `ExperienceSystem.add_experience()` when collected.
2. `ExperienceSystem` gets each requirement from `data/progression/default_experience.tres`; crossing one or more thresholds increments the level, records every pending level, and emits `level_ready` for each threshold without discarding excess experience.
3. `PartyForgeMain` asks `GameRun` to enter `LEVEL_UP`, which pauses the SceneTree.
4. `LevelUpChoiceService.generate()` builds eligible authored cards from the explicit upgrade catalog and preserves the legacy recruit/class-rank/trait/party-stat candidates needed by existing runs.
5. Authored `CHARACTER` and `CLASS_SPECIFIC` cards require one eligible member; `PARTY` and `TRAIT` cards use party ownership. Personal ranks are keyed by stable member ID, while party-owned matching sources also affect eligible future recruits.
6. `LevelUpPanel` displays three offers. Cards and tooltips use `UpgradePresentationService`; hover and focus share the same tooltip formatter. A personal card goes through the recipient picker, whose health values are read from at most four live direct `PartyActor` children.
7. The confirmation view emits guarded `confirmation_requested(choice, member_id)`. `PartyForgeMain._apply_choice_for_member()` rechecks the catalog definition, member eligibility, and rank cap, then calls `UpgradeApplicationService`.
8. Success completes the panel and consumes exactly one pending level. A queued level receives its own next offer while the run stays paused; otherwise the run resumes its previous `RUNNING` or `BOSS` state. Rejection consumes nothing and leaves the confirmation visible with an error.

## Explicit registries and current limitations

| Boundary | Verified implementation | Consequence |
| --- | --- | --- |
| Catalog | `GameCatalog.CLASS_PATHS`, `TRAIT_PATHS`, and `ENEMY_PATHS` are explicit arrays | New files under `data/` are not discovered automatically |
| Upgrade cards | `GameCatalog.REQUIRED_UPGRADE_PATHS` explicitly lists cards generated from `tools/character_upgrade_content_rows.gd`; scope and eligibility live on each `UpgradeDefinition` | Add a row, run the generator, register the exact path, then test application and presentation |
| Upgrade ownership | Character/class-specific ranks use stable member IDs; party/trait cards use owner ID zero and matching modifier sources | Same-class members can diverge, and eligible later recruits inherit already-owned party synergies |
| Upgrade presentation | `UpgradePresentationService` supplies card, tooltip, recipient, and confirmation dictionaries | Hover and focus remain consistent; UI controls do not own combat math |
| Progression tuning | `ExperienceSystem` preloads `data/progression/default_experience.tres` | Change the Resource for supported curve tuning and validate queued-level behavior |
| Leader selection | `ClassSelectionPanel.configure(catalog.classes)` creates all runtime buttons and emits exact IDs | A valid registered party-supported class enters leader selection without a class-specific HUD path |
| Attack kinds | Party: `MELEE_CLEAVE`, `PROJECTILE`, `AREA_PROJECTILE`, `HEAL`; enemy behaviors additionally use `DIRECT` and `AREA` | A new kind needs validation, owning behavior/delivery support, and tests |
| Trait effects | Thirteen registered traits cover attack speed, Vanguard reduction, ranged speed/range, area, cooldown, healing/revive, support, Fire, Cold, dodge, life steal, Chaos, and Bow range | A new stat ID still needs a registered stat definition, modifier/party behavior, and tests |
| Regular enemy scenes | `SWARMER_SCENE` and `SPITTER_SCENE`; accepted IDs `swarmer` and `spitter` | Catalog registration alone cannot make a regular enemy spawn |
| Spawn weights | `SpawnBand` has only `swarmer_weight` and `spitter_weight` | A third weighted enemy changes schedule and sampling architecture |
| Enemy behavior enum | Stored on `EnemyDefinition`, but no runtime factory selects scripts from it | The instantiated scene's attached script supplies behavior |
| Formation data | `engagement_distance` is exported but not consumed by verified runtime movement/targeting | Editing it alone has no gameplay effect |
| Presentation | Damage flash expects a direct `MeshInstance3D` | Nested imported hierarchies need an adapter or recursive handling |
| Audio | No reviewed custom bus layout or established audio integration | Verify actual buses; do not assume Music/SFX/UI names |
| Profiles and City progression | `ProfileManager` persists active profiles; the City passive tree uses typed runtime services and profile mutations | Inventory/stash/extraction UI, resumable runs, and final player-facing progression presentation remain separate future systems |

> **Current limitation:** These are implementation facts, not Godot restrictions. Change them deliberately with source, tests, and updated handbook guidance.

## Change-owner decision table

| Desired change | Primary owner | Additional integration |
| --- | --- | --- |
| Tune an existing number | Owning `.tres` definition, `UpgradeTuning`, or documented script constant | Relevant unit suite and controlled observation |
| Add an authored upgrade card | Row in `tools/character_upgrade_content_rows.gd`, then `tools/create_character_upgrade_data.gd` | Generated `.tres`/registry review, catalog validation, choice/application/presentation tests |
| Tune the experience curve | `data/progression/default_experience.tres` | Requirement boundaries, excess-XP and queued-level tests, ordinary progression run |
| Add an existing-kind attack | New `AttackDefinition` in `data/attacks/`; link from class | Definition/catalog-link tests and combat sandbox |
| Add a party-supported class | Class/attack/trait Resources plus `GameCatalog` class/trait arrays | Catalog, selector, leader, progression recruitment/tier, and ordinary-run checks |
| Add a supported trait | `TraitDefinition` plus class trait IDs and `GameCatalog.TRAIT_PATHS` | Catalog, party-manager, modifier tests |
| Add a new trait effect | `TraitDefinition.SUPPORTED_STAT_IDS` plus consuming modifier/party behavior | Focused behavior tests and sandbox observation |
| Add an existing-behavior enemy | Enemy definition plus copied compatible enemy scene | Catalog, SpawnDirector ID/preload/selection, schedule, sandbox action, tests |
| Add genuinely new enemy behavior | New `EnemyActor`-derived script and scene | Deterministic movement/attack/effect tests, then all production registration |
| Replace a model | Game-owned wrapper's presentation child/imported Resource | Preserve root, components, collision, groups, flash target, health-bar contract |
| Add positional sound | `AudioStreamPlayer3D` owned by actor/effect | Imported stream, listener/attenuation tests, verified bus |
| Change UI layout | Relevant `scenes/ui/*.tscn` Control hierarchy | Responsive tutorial, layout tests, three 16:9 sizes and non-16:9 framing |
| Alter run timing | `RunStateMachine`, `GameRun`, `SpawnSchedule`, or boss/spawn constants according to the timer | Boundary tests, ordinary run through changed transition, HUD timing check |

## Verification checklist by change type

| Change category | Definition/catalog validation | Focused automated test | Sandbox/visual check | Parser/import | Ordinary run |
| --- | --- | --- | --- | --- | --- |
| Existing numeric data | Required when definition/catalog-backed; otherwise inspect the owning constant and its consumer | Owner/consumer suite | Required for observable effect | Required before commit | Required if pacing/progression changes |
| New class/attack/trait using supported behavior | Required in isolation and after registration | Catalog, party, progression, combat | Required | Required | Required for recruitment/leader flow |
| New attack kind or trait effect | Required | New behavior plus regression suites | Required | Required | Required |
| Existing-behavior enemy | Required | Catalog, spawn, schedule, enemy, sandbox contract | Required | Required | Required for wave pacing |
| New enemy behavior | Required | Deterministic movement/attack/reward/effect tests | Required | Required | Required |
| Model/material/import | Resource/reference check | Scene contract and affected actor tests | Required with collision and two instances | Required after reimport | Required if production actor changed |
| Audio | Stream/reference check | Ownership/cleanup test where practical | Required listening from multiple positions | Required | Required for production mix/context |
| UI layout | Not applicable unless data-linked | Main wiring and responsive UI suites | Required at target sizes | Required | Required for full interaction flow |
| Run timing/spawn weights | Schedule/state validation | Boundary and deterministic sampling/state tests | Useful for accelerated focused check | Required | Required through affected time |
| Documentation only | Link/path/source-fact audit | Existing full suite once at milestone | Not required unless instructions changed behavior claims | Required at milestone | Not required |

For every production change, also inspect `git diff --check`, `git status --short`, and the exact staged names. A check marked “not applicable” does not remove the need to validate the layers the change actually touches.

## Glossary

- **Node:** One runtime object in a SceneTree, with a type, name, properties, methods, signals, and optional children.
- **Scene:** A saved tree with one root node, usually stored as `.tscn`, that can be instantiated like a reusable node type.
- **Instance:** A live or editor copy created from a scene or class. Multiple instances can share Resource data.
- **Resource:** Reference-counted data, built into an owner or saved externally as `.tres`; it does not need to live in the SceneTree.
- **Signal:** A typed or untyped message an object emits so connected receivers can react without the sender calling their implementation directly.
- **Method:** A named function belonging to a class or object, such as `PartyManager.recruit()`.
- **Inspector:** The editor dock for viewing and editing exported properties on the selected node or Resource.
- **SceneTree:** The live hierarchy managed by Godot, including the current root, nodes, groups, processing, and pause state.
- **Local:** The editor-side scene currently open in the Scene dock, including changes that may not have been saved yet.
- **Remote:** The running SceneTree shown by the editor, including spawned and modified runtime nodes.
- **Autoload:** A scene or script configured in Project Settings to be added globally when the project starts. Party Forge's verified service nodes are main-scene children, not autoloads.
- **`res://`:** Godot's project-root path prefix. `res://scripts/game/main.gd` resolves inside the current Party Forge project.
- **`.tscn`:** Godot's text scene format.
- **`.tres`:** Godot's text Resource format.
- **`.gd`:** A GDScript source file.
- **`.uid`:** A Godot-generated identity sidecar used to keep Resource references stable when paths change.
- **`.import`:** Import metadata associated with a source asset inside the project.
- **Group:** A SceneTree label used to find or classify nodes without hard-coding every path, such as `party_actors` or `hostile_transient_effects`.
- **Collision layer/mask:** A layer says what physics category an object occupies; a mask says which layers it checks for interactions.
- **Typed GDScript:** GDScript with declared parameter, return, variable, collection, and signal types so intent and many mismatches are checked earlier.

## Official Godot references

- [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html)
- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Using signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Groups](https://docs.godotengine.org/en/4.7/tutorials/scripting/groups.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
