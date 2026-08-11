# Live Personal Loot and Equipment Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver deterministic owner-scoped item drops from ordinary enemies, manual mouse/controller chest pickup, profile-colored owner markers, and a fully functional Character Ledger Equipment & Inventory page backed by each player's real run inventory and each party member's real equipment sheet.

**Architecture:** Enemy defeat events remain separate from experience rewards and feed a pure personal-loot policy that evaluates every registered player independently. Successful rolls issue items through the production weighted generator into a run-only ground container inside the owning `PlayerRunContext`; world chests are projections of those authoritative records, and pickup moves the item into the existing run inventory transactionally. The ledger reuses `StorageSlotButton`, layered item tooltips, `EquipmentTransitionService`, and `CharacterPresentation` through owner-scoped providers and a presentation-only 3D preview.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot `Control` and 3D scenes, existing weighted-loot/item-ownership/equipment/presentation services, deterministic SHA-256-derived random draws, PowerShell, Git worktrees, and custom headless unit/integration runners.

## Global Constraints

- At execution time, use the `using-git-worktrees` skill to create `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\live-personal-loot` on branch `feat/live-personal-loot`; do not implement directly on `main`.
- Create the feature worktree from the then-current clean `main`, which must contain approved spec commit `2231958`. Preserve unrelated user work and every tracked or untracked `.gd.uid` sidecar; never batch-stage, delete, regenerate, or hand-author sidecars.
- Follow strict RED/GREEN TDD. Before each commit, run the task's focused command, run `git diff --check`, and stage only the paths named by that task.
- Keep `ItemGenerationService` as the only item generator and `PlayerRunContext` as the only live owner mutation boundary. Do not create a second inventory, equipment, or affix implementation in UI or world code.
- Keep experience-orb behavior unchanged. Loot rolls are a separate consequence of the same defeat and must not alter XP eligibility, follower XP linking, or orb pickup.
- Roll independently for every eligible registered player. Eligibility requires an active context, available leader, valid leader position, and leader distance within `RewardDistributionTuning.leader_event_share_radius`.
- Followers never extend personal-loot eligibility. One player's success, failure, full inventory, or chest lifetime never affects another player's roll or item.
- Ordinary melee enemies use 100 basis points (1%); ordinary ranged/specialist enemies use 200 basis points (2%). Boss chance stays zero in this increment, and boss defeat still transitions directly to the existing victory screen.
- Use a run-only ground container in `ItemOwnershipState` to reserve generated item IDs immediately. A world chest is a projection; it never owns the canonical `ItemInstance`.
- Ground items persist until collected or the run ends. Do not add timed despawn, ground-item save/resume, trading, player item dropping, crafting, vendors, extraction changes, or the 30-minute checkpoint loop.
- Player Mode must not roll or expose item drops until the equipment/item feature is permanently unlocked. Developer Mode plus Unlock All exposes the completed system without persisting an unlock.
- Preserve the 11 canonical equipment slots from `EquipmentSlotCatalog.SHEET_SLOT_IDS`, disabled-item visual wear, stat/affix deactivation rules, and existing comparison semantics.
- Preserve `StorageSlotButton`, `ItemTooltipPanel`, Alt/LT compare, Shift/RT advanced affix view, green-better/red-worse comparison rows, mouse drag/drop, west-face pickup/move, south-face placement, and right-stick scrolling.
- World pickup is mouse hover/click or controller D-pad left/right selection plus south-face activation. An out-of-range activation keeps the chest selected and reports `Move closer`; it never auto-walks.
- All owner distinctions use both a pennant shape and `P1` through `P4`; color is additional information, never the only signal.
- Target responsive validation at 1920x1080, 2560x1440, and 3840x2160. The party rail must retain direct and directional access to member 24.
- Performance evidence must include at least 2,000 simultaneous chest projections across four synthetic owners without per-frame full-registry sorting or tooltip construction for off-screen/unselected chests.
- Every task receives spec-compliance review and code-quality review before the next task. The completed branch receives an independent final review and fresh verification before any local merge.

---

## File Responsibility Map

### Profile color and local owner identity

- Create `scripts/profile/player_color_palette.gd`: stable color IDs, display names, accessibility-checked colors, and deterministic display order.
- Modify `scripts/profile/profile_state.gd`, `profile_codec.gd`, and `profile_migrator.gd`: schema-4 `preferred_player_color_id` persistence and schema-1/2/3 migration.
- Modify `scripts/profile/profile_manager.gd`: optional color on creation without breaking the existing timestamp argument.
- Modify `scripts/ui/settings/profiles_settings_page.gd` and `scenes/ui/settings/profiles_settings_page.tscn`: profile-color choice during creation and preferred-color display.
- Create `scripts/run/local_player_identity_assignment.gd` and `local_player_identity_service.gd`: stable session identity assignment that rejects duplicate active colors so the future join UI can request another choice.

### Defeat facts, item level, and deterministic personal rolls

- Create `scripts/loot/enemy_defeat_event.gd`: immutable defeat identity, source category, encounter time, position, and boss seam.
- Create `scripts/loot/personal_loot_tuning.gd` and `data/items/personal_loot_tuning.tres`: basis-point chances and item-level curve.
- Create `scripts/loot/encounter_item_level_policy.gd`: time/category/difficulty/Heat item-level resolution.
- Modify `scripts/data/enemy_definition.gd` and `data/enemies/*.tres`: explicit validated loot source category.
- Create `scripts/loot/personal_loot_decision.gd` and `personal_loot_roll_service.gd`: one deterministic decision per eligible context.

### Authoritative ground ownership and pickup

- Modify `scripts/items/item_slot_container.gd`: run-ground container kind and capacity contract.
- Modify `scripts/run/run_item_bootstrap.gd`, `run_loadout_checkout_service.gd`, and `player_run_context.gd`: create the ground container, issue generated drops into it, and transactionally collect them.
- Create `scripts/loot/ground_item_record.gd` and `ground_item_registry.gd`: stable world projection records indexed by drop ID, item ID, owner, and spatial cell.
- Create `scripts/loot/ground_loot_ownership_result.gd` and `ground_loot_ownership_service.gd`: preflight and atomically commit generated item, ground location, and registry record.
- Create `scripts/loot/personal_loot_drop_coordinator.gd`: convert successful decisions into production requests and delegate the single ownership transition.

### Runtime defeat wiring and world presentation

- Modify `scripts/enemies/enemy_actor.gd`: emit one typed defeat fact while preserving `reward_dropped`.
- Modify `scripts/game/spawn_director.gd`: stamp spawn/defeat sequence and encounter time; forward typed defeat events.
- Create `scripts/loot/ground_item_pickup_result.gd` and `ground_item_pickup_service.gd`: range/full-inventory/ownership checks and authoritative collection.
- Create `scripts/loot/ground_item_spatial_index.gd` and `ground_item_targeting_service.gd`: bounded nearby/visible owner queries with nearest-first ordering and stable drop-ID tie-breaking.
- Create `scripts/world/ground_item_chest.gd`, `scenes/world/ground_item_chest.tscn`, and `scripts/world/player_owner_marker_3d.gd`: small chest, rarity glow, pennant, `P#`, hover/click, selection, and accessibility text.
- Create `scripts/world/ground_item_world_controller.gd`: registry-to-node projection, mouse/controller targeting, and status events.

### Ledger equipment, inventory, and preview

- Modify `scripts/ui/ledger/ledger_data_provider.gd` and `ledger_player_context.gd`: owner-scoped run item/equipment projections and held-item state.
- Create `scripts/ui/ledger/equipment_inventory_ledger_page.gd` and `scenes/ui/ledger/equipment_inventory_ledger_page.tscn`: three-region equipment/inventory page.
- Modify `data/ui/ledger_pages/equipment_inventory.tres`, `scripts/ui/ledger/character_ledger.gd`, and `scenes/ui/ledger/character_ledger.tscn`: make the page available under the feature gate and preserve 24-member navigation.
- Create `scripts/ui/ledger/character_equipment_preview.gd` and `scenes/ui/ledger/character_equipment_preview.tscn`: isolated selected-character render target.
- Modify `scripts/presentation/character_presentation.gd`: idempotent full-equipment visual refresh API built from existing slot methods.

### Main routing, developer controls, input, and evidence

- Modify `scripts/settings/party_forge_settings.gd`, `party_forge_settings_store.gd`, `scripts/ui/settings/additional_settings_page.gd`, and `scenes/ui/settings/additional_settings_page.tscn`: developer drop controls and diagnostics.
- Modify `scripts/game/run_rules_snapshot.gd`, `scripts/game/main.gd`, and `scenes/game/main.tscn`: feature gate, service lifecycle, world controller, ledger dependencies, and run cleanup.
- Create `tools/configure_live_loot_inputs.gd` and modify `project.godot`: owner-scoped world target/pickup actions without changing movement bindings.
- Add focused unit suites under `tests/unit/`, integration runners under `tests/integration/`, and `docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md`.

---

### Task 1: Persist preferred profile colors and assign unique session identities

**Files:**
- Create: `scripts/profile/player_color_palette.gd`
- Create: `scripts/run/local_player_identity_assignment.gd`
- Create: `scripts/run/local_player_identity_service.gd`
- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_migrator.gd`
- Modify: `scripts/profile/profile_manager.gd`
- Modify: `scripts/ui/settings/profiles_settings_page.gd`
- Modify: `scenes/ui/settings/profiles_settings_page.tscn`
- Modify: `tests/unit/test_profile_item_schema_migration.gd`
- Modify: `tests/unit/test_profiles_settings_page.gd`
- Create: `tests/unit/test_local_player_identity_service.gd`

**Interfaces:**
- `PlayerColorPalette.DEFAULT_ID == &"red"` and `entries() -> Array[Dictionary]` return the fixed order red, blue, yellow, green, purple, orange, cyan, white.
- `ProfileState.preferred_player_color_id: StringName` is schema-4 persistent data.
- Preserve `ProfileManager.create_profile(display_name, now_unix = -1, preferred_color_id = PlayerColorPalette.DEFAULT_ID)` so existing calls with a numeric second argument remain valid.
- `LocalPlayerIdentityService.assign(contexts) -> LocalPlayerIdentityAssignment` maps `run_player_id` to `{player_number, color_id, color}` or returns a stable duplicate-color error naming the joining slot/profile.

- [ ] **Step 1: Write failing schema, UI, and identity tests**

Add exact assertions for schema-3 migration, schema-4 round trip, invalid color rejection, UI-created preferred color, duplicate active preferences being rejected, stable P1-P4 numbering by `player_slot_index`, and defensive copies:

```gdscript
var legacy := ProfileState.new_profile("legacy", "Legacy", 1000).to_dictionary()
legacy["schema_version"] = 3
legacy.erase("preferred_player_color_id")
var migrated := ProfileCodec.decode_document(legacy)
TestAssertions.truthy(migrated.ok(), "schema 3 profile migrates", failures)
TestAssertions.equal(migrated.profile.preferred_player_color_id, &"red", "legacy profile receives P1 default", failures)

var assigned := LocalPlayerIdentityService.new().assign([_context(&"player_1", 0, &"red"), _context(&"player_2", 1, &"red")])
TestAssertions.truthy(not assigned.ok(), "duplicate active preference is rejected", failures)
TestAssertions.truthy(assigned.error.contains("player_2"), "error identifies the joining player", failures)
```

- [ ] **Step 2: Run RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_local_player_identity_service.gd
```

Expected: non-zero exit because schema 4, the palette, and the identity service do not exist.

- [ ] **Step 3: Implement schema-4 migration and bounded palette selection**

Use strings in the JSON document and `StringName` in runtime state:

```gdscript
class_name PlayerColorPalette
extends RefCounted

const DEFAULT_ID := &"red"
const ORDER: Array[StringName] = [&"red", &"blue", &"yellow", &"green", &"purple", &"orange", &"cyan", &"white"]
const COLORS := {
	&"red": Color("e45454"), &"blue": Color("4f8cff"), &"yellow": Color("f0cf4a"), &"green": Color("59bd72"),
	&"purple": Color("a66be8"), &"orange": Color("e58b45"), &"cyan": Color("52c7cf"), &"white": Color("e8edf2"),
}

static func is_valid(color_id: StringName) -> bool:
	return color_id in ORDER
```

Advance the migrator one schema at a time, including transaction snapshots, and add the new field to `CURRENT_FIELDS`, validation, encode, decode, normalization, and copy paths. Populate the profile-creation `OptionButton` from `PlayerColorPalette.entries()` and show the preferred color beside each healthy profile.

- [ ] **Step 4: Run GREEN and profile navigation integration**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_profile_manager.gd tests/unit/test_local_player_identity_service.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/settings_profiles_navigation_runner.gd
```

Expected: both commands exit `0`; the focused runner prints `TEST_SUMMARY: PASS (0 failures)` and navigation prints its PASS marker.

- [ ] **Step 5: Commit**

```powershell
git add scripts/profile/player_color_palette.gd scripts/run/local_player_identity_assignment.gd scripts/run/local_player_identity_service.gd scripts/profile/profile_state.gd scripts/profile/profile_codec.gd scripts/profile/profile_migrator.gd scripts/profile/profile_manager.gd scripts/ui/settings/profiles_settings_page.gd scenes/ui/settings/profiles_settings_page.tscn tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profiles_settings_page.gd tests/unit/test_local_player_identity_service.gd
git diff --cached --check
git commit -m "feat: persist player marker colors"
```

---

### Task 2: Define typed defeat events, source categories, and encounter item levels

**Files:**
- Create: `scripts/loot/enemy_defeat_event.gd`
- Create: `scripts/loot/personal_loot_tuning.gd`
- Create: `scripts/loot/encounter_item_level_policy.gd`
- Create: `data/items/personal_loot_tuning.tres`
- Modify: `scripts/data/enemy_definition.gd`
- Modify: `data/enemies/swarmer.tres`
- Modify: `data/enemies/spitter.tres`
- Modify: `data/enemies/boltcaster.tres`
- Modify: `data/enemies/forge_guardian.tres`
- Create: `tests/unit/test_enemy_defeat_event.gd`
- Create: `tests/unit/test_encounter_item_level_policy.gd`
- Modify: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Source IDs: `ordinary_melee`, `ordinary_specialist`, `elite`, and `boss`; elite and boss are data seams only here.
- `EnemyDefeatEvent.create(run_seed, defeat_sequence, enemy_sequence, enemy_id, source_category, world_position, encounter_seconds) -> EnemyDefeatEvent`.
- `EncounterItemLevelPolicy.resolve(event, difficulty_id, heat, tuning) -> int` returns `1..1000` and never reads character level.

- [ ] **Step 1: Write failing validation and boundary tests**

Cover negative/non-finite time, zero sequences, unknown categories, exact production enemy mappings, monotonic time/Heat/difficulty scaling, boss-category support without a positive boss chance, and clamping at item levels 1 and 1000.

```gdscript
var event := EnemyDefeatEvent.create(1337, 7, 9, &"spitter", &"ordinary_specialist", Vector3(2, 0, 4), 300.0)
TestAssertions.truthy(event.validate().is_empty(), "typed defeat event validates", failures)
var level := EncounterItemLevelPolicy.resolve(event, &"normal", 0.0, preload("res://data/items/personal_loot_tuning.tres"))
TestAssertions.equal(level, 27, "five-minute specialist item level follows the approved curve", failures)
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_enemy_defeat_event.gd tests/unit/test_encounter_item_level_policy.gd tests/unit/test_game_catalog.gd
```

Expected: non-zero exit because the loot-domain types and enemy category field do not exist.

- [ ] **Step 3: Implement immutable event creation and the explicit curve**

Use this initial tuning contract:

```gdscript
class_name PersonalLootTuning
extends Resource

@export var drop_basis_points := {&"ordinary_melee": 100, &"ordinary_specialist": 200, &"elite": 0, &"boss": 0}
@export var seconds_per_item_level := 12.0
@export var specialist_item_level_bonus := 1
@export var elite_item_level_bonus := 5
@export var boss_item_level_bonus := 10
@export var difficulty_item_level_bonus := {&"normal": 0}
@export var heat_item_levels_per_point := 0.25
@export var pickup_interaction_radius := 3.5
@export var controller_target_query_radius := 30.0
```

Resolve with `1 + floor(encounter_seconds / seconds_per_item_level) + category bonus + difficulty bonus + floor(heat * heat_item_levels_per_point)`, then clamp to `ItemGenerationRequest.MIN_ITEM_LEVEL..MAX_ITEM_LEVEL`. Add `@export var loot_source_category: StringName` to `EnemyDefinition` and reject unknown IDs.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_enemy_defeat_event.gd tests/unit/test_encounter_item_level_policy.gd tests/unit/test_game_catalog.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/loot/enemy_defeat_event.gd scripts/loot/personal_loot_tuning.gd scripts/loot/encounter_item_level_policy.gd data/items/personal_loot_tuning.tres scripts/data/enemy_definition.gd data/enemies/swarmer.tres data/enemies/spitter.tres data/enemies/boltcaster.tres data/enemies/forge_guardian.tres tests/unit/test_enemy_defeat_event.gd tests/unit/test_encounter_item_level_policy.gd tests/unit/test_game_catalog.gd
git diff --cached --check
git commit -m "feat: define encounter loot sources"
```

---

### Task 3: Roll independently for every eligible player

**Files:**
- Create: `scripts/loot/personal_loot_decision.gd`
- Create: `scripts/loot/personal_loot_roll_service.gd`
- Create: `tests/unit/test_personal_loot_roll_service.gd`
- Modify: `tests/unit/test_reward_distribution.gd`

**Interfaces:**
- `PersonalLootRollService.configure(registry, reward_tuning, loot_tuning, feature_access_provider) -> PackedStringArray`; the provider resolves item-drop access separately for each context.
- `resolve(event, force_success = false, drop_multiplier = 1.0) -> Array[PersonalLootDecision]` returns one sorted decision per registered context, including ineligible/no-drop decisions for diagnostics.
- Decision fields: `run_player_id`, `profile_id`, `player_slot`, `eligible`, `success`, `reason`, `basis_points`, `roll_basis_points`, `generation_seed`, `generation_sequence`, `item_level`, and copied world/source facts.
- Idempotency key: `defeat_sequence|run_player_id`.

- [ ] **Step 1: Write failing independent-roll tests**

Create four synthetic contexts at inside/outside distances. Assert leader-only distance, unavailable leader rejection, one unlocked and one locked profile at the same position receive different eligibility, stable context ordering, one decision per player, independent deterministic draws, multiplier clamping, force-success applying only to eligible contexts, and replay returning byte-equivalent decisions without rerolling.

```gdscript
var decisions := service.resolve(event)
TestAssertions.equal(decisions.size(), 4, "all registered players receive an independent decision", failures)
TestAssertions.truthy(decisions[0].eligible, "near P1 is eligible", failures)
TestAssertions.truthy(not decisions[2].eligible, "far P3 is ineligible", failures)
TestAssertions.equal(service.resolve(event)[0].to_dictionary(), decisions[0].to_dictionary(), "replay is deterministic", failures)
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_personal_loot_roll_service.gd tests/unit/test_reward_distribution.gd
```

Expected: non-zero exit because the personal-loot service does not exist.

- [ ] **Step 3: Implement deterministic per-player basis-point rolls**

Derive each draw without shared mutable RNG:

```gdscript
var player_stage := StringName("personal_drop:%s" % context.run_player_id)
var roll := floori(ItemDeterministicRandom.unit(event.run_seed, event.defeat_sequence, player_stage, 0) * 10000.0)
var effective_basis_points := clampi(roundi(float(base_basis_points) * maxf(drop_multiplier, 0.0)), 0, 10000)
decision.success = decision.eligible and (force_success or roll < effective_basis_points)
```

Use `RunContextRegistry.all_contexts()`, sort by `player_slot_index` then `run_player_id`, call the access provider for each context, and duplicate decisions on replay. Reuse `RewardDistributionTuning.leader_event_share_radius`; do not duplicate the radius in loot tuning.

Derive `generation_seed` from SHA-256 of `run_seed|defeat_sequence|run_player_id|item`, keep `generation_sequence` equal to the stable defeat sequence, and include `player_slot` in the canonical decision document. This gives each player an independent generator stream even when their party tags and Charisma are identical.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_personal_loot_roll_service.gd tests/unit/test_reward_distribution.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/loot/personal_loot_decision.gd scripts/loot/personal_loot_roll_service.gd tests/unit/test_personal_loot_roll_service.gd tests/unit/test_reward_distribution.gd
git diff --cached --check
git commit -m "feat: roll personal loot per player"
```

---

### Task 4: Add authoritative run-ground item ownership

**Files:**
- Modify: `scripts/items/item_slot_container.gd`
- Modify: `scripts/run/run_item_bootstrap.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Modify: `scripts/run/player_run_context.gd`
- Modify: `tests/unit/test_item_container_transactions.gd`
- Modify: `tests/unit/test_run_item_ownership.gd`
- Modify: `tests/unit/test_run_loadout_checkout_service.gd`

**Interfaces:**
- Add `ItemSlotContainer.RUN_GROUND_ITEMS := &"run_ground_items"`, container ID `&"run-ground-items"`, and capacity 2048.
- `PlayerRunContext.ground_items() -> ItemSlotContainer` returns a defensive copy.
- `issue_ground_item(request, equipment, foundation) -> ItemGenerationResult` generates with the context's canonical run issuer namespace, transactionally creates in the first ground slot, and consumes one sequence only on success.
- `collect_ground_item(item_id, transaction_id, equipment, foundation) -> ItemTransactionResult` moves that item from ground to the first empty run-inventory slot.

- [ ] **Step 1: Write failing ownership tests**

Assert bootstrap creates an empty ground container, two outstanding drops receive different sequences/IDs, failed generation consumes no sequence, pickup moves rather than copies, a full inventory preserves the ground item, wrong owner/unknown item fails, replay is idempotent, and item state remains valid after each accepted transaction.

```gdscript
var first := context.issue_ground_item(request, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
var second := context.issue_ground_item(request.copy_with_sequence(2), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
TestAssertions.truthy(first.item.instance_id != second.item.instance_id, "outstanding drops reserve unique IDs", failures)
var collected := context.collect_ground_item(first.item.instance_id, "pickup-001", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
TestAssertions.truthy(collected.ok(), "ground item moves into inventory", failures)
TestAssertions.equal(context.ground_items().item_id_at(0), "", "ground slot clears", failures)
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_container_transactions.gd tests/unit/test_run_item_ownership.gd tests/unit/test_run_loadout_checkout_service.gd
```

Expected: non-zero exit because run-ground ownership is absent.

- [ ] **Step 3: Extend the existing transaction boundary**

Keep `ItemContainerTransactionService` unchanged. Permit only these new `PlayerRunContext.apply_item_transaction()` shapes:

```gdscript
var source_is_ground := request.source_container_id == "run-ground-items"
var destination_is_ground := request.destination_container_id == "run-ground-items"
var destination_is_inventory := request.destination_container_id == "run-inventory"
var allowed := (
	(request.operation == ItemTransactionRequest.CREATE_AND_PLACE and destination_is_ground)
	or (request.operation == ItemTransactionRequest.MOVE_TO_EMPTY and source_is_ground and destination_is_inventory)
	or (not source_is_ground and not destination_is_ground and destination_is_inventory)
)
```

`issue_ground_item()` must generate first, submit `CREATE_AND_PLACE`, and expose a failed `ItemGenerationResult` with stage `ground_storage` if no ground slot remains. `collect_ground_item()` finds the authoritative source slot and inventory destination at call time so stale UI indexes cannot duplicate an item.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_container_transactions.gd tests/unit/test_run_item_ownership.gd tests/unit/test_run_loadout_checkout_service.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/items/item_slot_container.gd scripts/run/run_item_bootstrap.gd scripts/run/run_loadout_checkout_service.gd scripts/run/player_run_context.gd tests/unit/test_item_container_transactions.gd tests/unit/test_run_item_ownership.gd tests/unit/test_run_loadout_checkout_service.gd
git diff --cached --check
git commit -m "feat: reserve run ground items"
```

---

### Task 5: Coordinate successful rolls into stable ground records

**Files:**
- Create: `scripts/loot/ground_item_record.gd`
- Create: `scripts/loot/ground_item_registry.gd`
- Create: `scripts/loot/ground_loot_ownership_result.gd`
- Create: `scripts/loot/ground_loot_ownership_service.gd`
- Create: `scripts/loot/personal_loot_drop_coordinator.gd`
- Create: `tests/unit/test_ground_item_registry.gd`
- Create: `tests/unit/test_ground_loot_ownership_service.gd`
- Create: `tests/unit/test_personal_loot_drop_coordinator.gd`

**Interfaces:**
- `GroundItemRecord` holds `drop_id`, `item_id`, `run_player_id`, `profile_id`, `player_number`, `color_id`, `world_position`, `rarity_id`, `source_id`, and `ground_slot`.
- `GroundItemRegistry.add(record)`, `remove(drop_id)`, `record(drop_id)`, `for_owner(run_player_id)`, `all_records()`, and signals `record_added`, `record_removed`, `cleared`.
- `GroundLootOwnershipService.create_drop(context, request, record_identity, equipment, foundation, registry) -> GroundLootOwnershipResult` validates every identity/capacity constraint before committing the context transaction and infallible registry insertion.
- `PersonalLootDropCoordinator.resolve_defeat(event) -> Dictionary` returns `decisions`, `spawned_drop_ids`, and `diagnostics`.

- [ ] **Step 1: Write failing registry/coordinator tests**

Assert duplicate drop/item IDs are rejected, owner queries are stable copies, a successful decision issues exactly one production-generated item, generation failure creates no record, registry preflight failure creates no ground item, source/item-level provenance matches the event, two otherwise-identical owners receive byte-distinct generated payload streams, per-owner issuance is independent, and `clear()` affects only session records.

```gdscript
var report := coordinator.resolve_defeat(event)
TestAssertions.equal(report.spawned_drop_ids.size(), 2, "two independent successes create two owner drops", failures)
for drop_id: StringName in report.spawned_drop_ids:
	var record := registry.record(drop_id)
	var context := contexts.context_for(record.run_player_id)
	TestAssertions.truthy(context.item_state().registry().has(record.item_id), "record references authoritative owner item", failures)
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_registry.gd tests/unit/test_ground_loot_ownership_service.gd tests/unit/test_personal_loot_drop_coordinator.gd
```

Expected: non-zero exit because registry/coordinator types do not exist.

- [ ] **Step 3: Implement failure-atomic coordination**

Use stable IDs and the production request:

```gdscript
var request := ItemGenerationRequest.create(
	decision.generation_seed,
	decision.generation_sequence,
	decision.item_level,
	&"ordinary_enemy",
	&"ordinary_drop",
	_ordinary_rarity_ids(foundation),
)
request.difficulty_id = difficulty_id
request.heat = heat
var generated := context.issue_ground_item(request, equipment, foundation)
var drop_id := StringName("drop:%s:%d" % [decision.run_player_id, event.defeat_sequence])

func _ordinary_rarity_ids(foundation: ItemFoundationCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	for rarity: ItemRarityDefinition in foundation.rarities:
		if rarity != null and rarity.instance_supported and rarity.ordinary_generation_enabled:
			result.append(rarity.id)
	result.sort()
	return result
```

Set party archetype tags by taking the sorted unique union of `caster` and `ranged` capability tags and treating members with neither as `melee`. Read Charisma from the leader's `context.party.stats_for(leader_id).value(&"charisma")`. Set unlock tags to the sorted intersection of `context.profile_snapshot.permanent_feature_unlocks` and `foundation.generation_unlock_tags()`. Use the session identity map for `player_number`/`color_id`, and pass the prepared record identity to `GroundLootOwnershipService`. The ownership service preflights drop ID, item issuer identity, ground capacity, owner, and registry capacity before generation; after a successful context transaction it performs a private registry commit that cannot reject validated data. Never roll rarity/base/affixes in this coordinator.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_registry.gd tests/unit/test_ground_loot_ownership_service.gd tests/unit/test_personal_loot_drop_coordinator.gd tests/unit/test_item_generation_service.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/loot/ground_item_record.gd scripts/loot/ground_item_registry.gd scripts/loot/ground_loot_ownership_result.gd scripts/loot/ground_loot_ownership_service.gd scripts/loot/personal_loot_drop_coordinator.gd tests/unit/test_ground_item_registry.gd tests/unit/test_ground_loot_ownership_service.gd tests/unit/test_personal_loot_drop_coordinator.gd
git diff --cached --check
git commit -m "feat: coordinate personal ground drops"
```

---

### Task 6: Emit typed enemy defeats without disturbing XP or victory

**Files:**
- Modify: `scripts/enemies/enemy_actor.gd`
- Modify: `scripts/game/spawn_director.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_spawn_schedule.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Create: `tests/integration/personal_loot_defeat_runner.gd`

**Interfaces:**
- `EnemyActor` adds `signal enemy_defeated(definition: EnemyDefinition, drop_position: Vector3)` and emits it once from the same guarded defeat path as `reward_dropped`.
- `SpawnDirector` adds `signal enemy_defeated(event: EnemyDefeatEvent)` and converts the actor signal using run seed, monotonically increasing defeat sequence, original spawn sequence, and `elapsed_seconds`.
- `PartyForgeMain` connects the director to `PersonalLootDropCoordinator` for the run; the roll service then evaluates feature access independently for each registered context and fails closed for locked players.

- [ ] **Step 1: Write failing once-only and boss-regression tests**

Assert repeated `defeat()` emits one XP reward and one defeat event, event sequences increase in kill order, elapsed time is captured, source category comes from data, Player Mode without unlock produces no drop, Developer Unlock All does, Forge Guardian still calls existing victory behavior, and boss chance zero produces no chest.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_spawn_schedule.gd tests/unit/test_main_wiring.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/personal_loot_defeat_runner.gd
```

Expected: non-zero exit or integration FAIL because defeat events are not wired.

- [ ] **Step 3: Wire defeat sequencing beside the preserved reward signal**

Bind immutable spawn facts when connecting:

```gdscript
var spawn_sequence := _enemy_sequence
enemy.enemy_defeated.connect(_on_enemy_defeated.bind(spawn_sequence), CONNECT_ONE_SHOT)

func _on_enemy_defeated(definition: EnemyDefinition, position: Vector3, spawn_sequence: int) -> void:
	_defeat_sequence += 1
	var event := EnemyDefeatEvent.create(run_seed, _defeat_sequence, spawn_sequence, definition.id, definition.loot_source_category, position, elapsed_seconds)
	enemy_defeated.emit(event)
```

Do not remove or rename `reward_dropped`; both signals must be emitted before `queue_free()`. In `main.gd`, keep the Forge Guardian `defeated`/victory connection unchanged and let the zero boss basis points suppress ground rewards.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_spawn_schedule.gd tests/unit/test_main_wiring.gd tests/unit/test_personal_loot_drop_coordinator.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/personal_loot_defeat_runner.gd
```

Expected: both exit `0`; XP assertions, personal-loot marker, and victory-regression marker pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/enemies/enemy_actor.gd scripts/game/spawn_director.gd scripts/game/main.gd tests/unit/test_spawn_schedule.gd tests/unit/test_main_wiring.gd tests/integration/personal_loot_defeat_runner.gd
git diff --cached --check
git commit -m "feat: wire enemy defeats to personal loot"
```

---

### Task 7: Project owner-marked chests into the arena

**Files:**
- Create: `scripts/world/player_owner_marker_3d.gd`
- Create: `scripts/world/ground_item_chest.gd`
- Create: `scripts/world/ground_item_world_controller.gd`
- Create: `scenes/world/ground_item_chest.tscn`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_ground_item_chest.gd`
- Create: `tests/unit/test_ground_item_world_controller.gd`

**Interfaces:**
- `GroundItemChest.bind(record, detail, owner_color)`, `set_selected(active)`, `tooltip_anchor() -> Control`, and signal `pickup_requested(drop_id, input_owner)`.
- `GroundItemWorldController.configure(registry, identities, presentation_projector, camera, chests_parent, tooltip_layer)` and signals `pickup_requested`, `status_changed`.
- The chest contains one mesh/collision target, rarity light/glow, billboard pennant, and billboard `P#` label.

- [ ] **Step 1: Write failing projection and accessibility tests**

Assert add/remove signals activate/return exactly one pooled chest, all observers can see every chest, owner number and color bind correctly, rarity palette maps correctly, missing icon/model falls back without error, selection is visually distinct, hover/focus uses one shared `ItemTooltipPanel`, Alt/LT and Shift/RT update its standard layers, only owner input emits pickup, and accessibility text includes item name, rarity, owner number, and distance.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_chest.gd tests/unit/test_ground_item_world_controller.gd tests/unit/test_item_presentation_projector.gd
```

Expected: non-zero exit because the world projection does not exist.

- [ ] **Step 3: Implement a bounded projection layer**

Use `ItemRarityPalette` for rarity color and a deterministic low-poly chest built from Godot primitives. Store nodes by `drop_id`, reuse inactive chest nodes from a bounded pool, update only changed/selected records, and never rebuild item tooltip detail during `_process()`:

```gdscript
func _on_record_added(record: GroundItemRecord) -> void:
	var chest := _inactive_chests.pop_back() as GroundItemChest if not _inactive_chests.is_empty() else CHEST_SCENE.instantiate() as GroundItemChest
	if chest.get_parent() == null:
		_chests_parent.add_child(chest)
	_chest_by_drop[record.drop_id] = chest
	chest.bind(record, _detail_for(record), _identities[record.run_player_id].color)
	chest.pickup_requested.connect(_on_chest_pickup_requested)
```

The pennant silhouette must remain readable when rendered grayscale; the `P#` label remains visible above the chest and does not depend on glow. Project the chest's 3D position into screen space for a lightweight tooltip anchor and reuse one `ItemTooltipPanel` for every chest; never create one tooltip per chest. Alt/LT comparisons target the owning leader's applicable equipment slot or slots, using `EquipmentComparisonProjectionService`, because the leader is the controlled world character.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_chest.gd tests/unit/test_ground_item_world_controller.gd tests/unit/test_item_presentation_projector.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/world/player_owner_marker_3d.gd scripts/world/ground_item_chest.gd scripts/world/ground_item_world_controller.gd scenes/world/ground_item_chest.tscn scenes/game/main.tscn tests/unit/test_ground_item_chest.gd tests/unit/test_ground_item_world_controller.gd
git diff --cached --check
git commit -m "feat: show owner marked loot chests"
```

---

### Task 8: Add mouse/controller targeting and transactional pickup

**Files:**
- Create: `scripts/loot/ground_item_spatial_index.gd`
- Create: `scripts/loot/ground_item_targeting_service.gd`
- Create: `scripts/loot/ground_item_pickup_result.gd`
- Create: `scripts/loot/ground_item_pickup_service.gd`
- Create: `tools/configure_live_loot_inputs.gd`
- Modify: `scripts/world/ground_item_world_controller.gd`
- Modify: `project.godot`
- Create: `tests/unit/test_ground_item_targeting_service.gd`
- Create: `tests/unit/test_ground_item_pickup_service.gd`
- Create: `tests/integration/ground_item_pickup_input_runner.gd`

**Interfaces:**
- `GroundItemSpatialIndex` maintains owner/cell buckets from registry add/remove signals and queries bounded cells without scene-tree scans.
- `GroundItemTargetingService.ordered_for_owner(index, run_player_id, leader_position, query_radius, visibility_filter) -> Array[GroundItemRecord]` filters nearby/visible records and sorts squared distance then `drop_id`.
- `cycle(current_drop_id, direction, ...) -> StringName` wraps owned records only.
- `GroundItemPickupService.collect(drop_id, input_run_player_id) -> GroundItemPickupResult` reports `OK`, `MOVE_CLOSER`, `INVENTORY_FULL`, `NOT_OWNER`, `MISSING`, or `TRANSACTION_REJECTED`.
- Input actions: `world_loot_previous` = D-pad left, `world_loot_next` = D-pad right, and existing `ui_accept` = south face pickup.

- [ ] **Step 1: Write failing selection/pickup tests**

Cover spatial-cell boundaries, incremental add/remove, nearest-first ordering, stable equal-distance tie, wraparound, foreign drops excluded from cycling, off-camera/far entries excluded from controller cycling, mouse owner check, exact range boundary, out-of-range selection persistence, `Move closer`, full inventory leaving the chest/state unchanged, accepted pickup removing record after transaction success, modal input suppression, ledger-close target preservation, and keyboard/controller event device ownership.

```gdscript
var ordered := targeting.ordered_for_owner(registry, &"player_1", Vector3.ZERO)
TestAssertions.equal(ordered.map(func(row): return row.drop_id), [&"drop-a", &"drop-b"], "distance ties use stable drop ID", failures)
var result := pickup.collect(&"drop-a", &"player_1")
TestAssertions.equal(result.code, GroundItemPickupResult.Code.MOVE_CLOSER, "out-of-range activation is explicit", failures)
TestAssertions.truthy(registry.record(&"drop-a") != null, "out-of-range chest remains", failures)
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_spatial_index.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/ground_item_pickup_input_runner.gd
```

Expected: non-zero exit or integration FAIL because targeting and actions are absent.

- [ ] **Step 3: Implement owner-scoped input and success-after-commit removal**

The pickup service checks owner/range/capacity, calls `context.collect_ground_item()`, and removes the `GroundItemRecord` only after `result.ok()`. The world controller keeps one selection per `run_player_id`; mouse clicks pass the chest owner identity and are rejected if the active pointer owner is different.

Generate input actions idempotently with `tools/configure_live_loot_inputs.gd`; do not rewrite unrelated `project.godot` input entries. D-pad actions must use device `-1` in the map, with runtime routing resolving the actual `RunContextRegistry.device_for()` owner.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_spatial_index.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_run_item_ownership.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/ground_item_pickup_input_runner.gd
```

Expected: both exit `0`; integration covers mouse, controller, full inventory, and foreign-owner rejection.

- [ ] **Step 5: Commit**

```powershell
git add scripts/loot/ground_item_spatial_index.gd scripts/loot/ground_item_targeting_service.gd scripts/loot/ground_item_pickup_result.gd scripts/loot/ground_item_pickup_service.gd tools/configure_live_loot_inputs.gd scripts/world/ground_item_world_controller.gd project.godot tests/unit/test_ground_item_spatial_index.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd tests/integration/ground_item_pickup_input_runner.gd
git diff --cached --check
git commit -m "feat: collect personal loot manually"
```

---

### Task 9: Expose real owner inventory and member equipment through the ledger provider

**Files:**
- Modify: `scripts/ui/ledger/ledger_data_provider.gd`
- Modify: `scripts/ui/ledger/ledger_player_context.gd`
- Create: `tests/unit/test_ledger_item_provider.gd`
- Modify: `tests/unit/test_character_ledger_foundation.gd`

**Interfaces:**
- Extend `LedgerDataProvider.configure(..., progression_context, item_context, equipment_catalog, item_foundation)` without breaking existing callers by keeping new arguments optional.
- `inventory_rows() -> Array[Dictionary]`, `equipment_rows(member_id) -> Array[Dictionary]`, `item_detail(item_id, member_id) -> Dictionary`, `comparison_rows(item_id, member_id) -> Array[Dictionary]`, and `move_or_equip(request) -> Dictionary`.
- `LedgerPlayerContext` stores held source container/slot/item ID per local player, never globally.

- [ ] **Step 1: Write failing owner-projection tests**

Assert inventory rows cover every unlocked run slot, equipment rows follow `EquipmentSlotCatalog.SHEET_SLOT_IDS`, member selection changes only equipment, inventory stays player-wide, details use `ItemPresentationProjector`, comparisons use `EquipmentComparisonProjectionService`, disabled equipped items retain visual detail with inactive reasons, foreign owner IDs never project, and returned dictionaries are defensive copies.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ledger_item_provider.gd tests/unit/test_character_ledger_foundation.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_resolved_stat_comparison_service.gd
```

Expected: non-zero exit because item projection methods are absent.

- [ ] **Step 3: Implement an adapter over existing context/services**

Project slots without mutating state:

```gdscript
func equipment_rows(member_id: int) -> Array[Dictionary]:
	var container := item_context.equipment_for(member_id) if item_context != null else null
	var rows: Array[Dictionary] = []
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		var slot := EquipmentSlotIndex.index_for(slot_id)
		var item_id := container.item_id_at(slot) if container != null else ""
		rows.append({"slot_id": slot_id, "slot": slot, "item_id": item_id, "detail": _project_item(item_id, member_id)})
	return rows
```

Movement/equip requests must call `PlayerRunContext.apply_item_transaction()` or `assign_equipment()` and emit `data_changed(member_id)` only after an accepted result.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ledger_item_provider.gd tests/unit/test_character_ledger_foundation.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_resolved_stat_comparison_service.gd
```

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ui/ledger/ledger_data_provider.gd scripts/ui/ledger/ledger_player_context.gd tests/unit/test_ledger_item_provider.gd tests/unit/test_character_ledger_foundation.gd
git diff --cached --check
git commit -m "feat: project run items into ledger"
```

---

### Task 10: Build the functional Equipment & Inventory ledger page

**Files:**
- Create: `scripts/ui/ledger/equipment_inventory_ledger_page.gd`
- Create: `scenes/ui/ledger/equipment_inventory_ledger_page.tscn`
- Modify: `data/ui/ledger_pages/equipment_inventory.tres`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scenes/ui/ledger/character_ledger.tscn`
- Create: `tests/unit/test_equipment_inventory_ledger_page.gd`
- Modify: `tests/unit/test_ledger_responsive_input.gd`
- Create: `tests/integration/equipment_ledger_responsive_runner.gd`

**Interfaces:**
- Page regions: scrollable party rail owned by `CharacterLedger`, spatial 11-slot paper doll around preview, and the active player's run inventory grid.
- Mouse drag/drop uses `StorageSlotButton.item_dropped`.
- Controller west face uses existing `item_sandbox_pickup` to hold/release a slot; `ui_accept` places into the focused valid target; right stick scrolls the focused inventory/party region.
- Page implements `initial_focus()`, `apply_compact()`, `pin_active_detail()`, and `dismiss_pinned_detail()`.

- [ ] **Step 1: Write failing page, focus, and responsive tests**

Assert the resource is no longer `Coming Soon` when available, all 11 named slots appear spatially, slot buttons use icons instead of slot numbers/cutoff names, inventory capacity and empty cells render, the existing combat estimate service supplies a compact selected-member combat summary, selecting members 1 and 24 refreshes equipment, mouse swap/equip and controller hold/place use accepted transactions, invalid targets remain unchanged, tooltip compare/advanced modes work, and focus neighbors form a closed graph.

Run exact viewport assertions at 1920x1080, 2560x1440, and 3840x2160. No control may extend outside a 24-pixel safe margin, and no slot may overlap another slot or the preview's protected center rectangle.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_ledger_responsive_input.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_tooltip_panel.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/equipment_ledger_responsive_runner.gd
```

Expected: non-zero exit or integration FAIL because the page scene is absent.

- [ ] **Step 3: Implement the page with shared slot/tooltip controls**

Instantiate `StorageSlotButton` for each slot and inventory cell; do not create a ledger-specific item button. Use this slot layout contract:

```gdscript
const PAPER_DOLL_POSITIONS := {
	&"helmet": Vector2(0.18, 0.08), &"amulet": Vector2(0.82, 0.06),
	&"main_hand": Vector2(0.06, 0.46), &"body_armour": Vector2(0.18, 0.30), &"off_hand": Vector2(0.94, 0.46),
	&"gloves": Vector2(0.82, 0.22), &"belt": Vector2(0.82, 0.70), &"ring_left": Vector2(0.82, 0.38),
	&"legs": Vector2(0.18, 0.52), &"ring_right": Vector2(0.82, 0.54), &"boots": Vector2(0.18, 0.74),
}
```

The page owns one `ItemTooltipPanel`. `inspection_started` supplies detail/comparisons; `inspection_ended` honors the existing grace/pin contract. In compact mode, inventory becomes a lower scroll region; equipment positions retain their normalized arrangement.

In this task, set `equipment_inventory.tres` to `development_state = AVAILABLE`, assign its `page_scene`, and set `unlock_id = &"equipment_inventory"`. The page exists as completed content, while Task 12 supplies the authoritative per-profile policy inputs that decide whether Player Mode can see it.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_ledger_responsive_input.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_tooltip_panel.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/equipment_ledger_responsive_runner.gd
```

Expected: both exit `0`; the integration prints PASS for all three target resolutions and member 24.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ui/ledger/equipment_inventory_ledger_page.gd scenes/ui/ledger/equipment_inventory_ledger_page.tscn data/ui/ledger_pages/equipment_inventory.tres scripts/ui/ledger/character_ledger.gd scenes/ui/ledger/character_ledger.tscn tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_ledger_responsive_input.gd tests/integration/equipment_ledger_responsive_runner.gd
git diff --cached --check
git commit -m "feat: add equipment inventory ledger page"
```

---

### Task 11: Render the selected character and accepted equipment visuals

**Files:**
- Create: `scripts/ui/ledger/character_equipment_preview.gd`
- Create: `scenes/ui/ledger/character_equipment_preview.tscn`
- Modify: `scripts/presentation/character_presentation.gd`
- Modify: `scripts/ui/ledger/equipment_inventory_ledger_page.gd`
- Modify: `scenes/ui/ledger/equipment_inventory_ledger_page.tscn`
- Create: `tests/unit/test_character_equipment_preview.gd`
- Modify: `tests/unit/test_character_presentation.gd`
- Create: `tests/integration/equipment_ledger_preview_runner.gd`

**Interfaces:**
- `CharacterPresentation.refresh_equipment_visuals(definitions_by_slot: Dictionary) -> PackedStringArray` clears absent slots, applies present definitions, and returns deterministic diagnostics for fallbacks.
- `CharacterEquipmentPreview.show_member(member, equipment_rows) -> bool` replaces only the presentation copy and never reparents/duplicates the live combat actor.
- Preview scene uses `SubViewport`, `Camera3D`, controlled lighting, and `SubViewportContainer`/`TextureRect` inside the ledger.
- Preview rotation is bounded to a full horizontal turn with a fixed safe vertical angle, accepts mouse drag while the pointer is over the preview, and consumes preview input so gameplay movement never receives it.

- [ ] **Step 1: Write failing isolation and refresh tests**

Assert preview selection matches class/body/palette, bounded mouse-drag rotation never affects the leader, live actor parent/transform/health remain unchanged, equipping/unequipping refreshes only after accepted transactions, all 11 slots clear idempotently, disabled items remain visually worn, missing visual definitions retain a slot-aware body fallback and emit one diagnostic, and repeated member switching reuses one preview host without leaking old models.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_equipment_preview.gd tests/unit/test_character_presentation.gd tests/unit/test_equipment_inventory_ledger_page.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/equipment_ledger_preview_runner.gd
```

Expected: non-zero exit or integration FAIL because the preview does not exist.

- [ ] **Step 3: Implement presentation-only reconstruction**

Build the preview from the member's `CharacterVisualProfile` and current equipment rows:

```gdscript
func show_member(member: PartyMemberState, rows: Array[Dictionary]) -> bool:
	_clear_preview()
	var copy := PRESENTATION_SCENE.instantiate() as CharacterPresentation
	_preview_root.add_child(copy)
	if not copy.apply_profile(member.class_definition.visual_profile, member.class_definition.color):
		return false
	copy.refresh_equipment_visuals(_visuals_by_slot(rows))
	_active_preview = copy
	return true
```

Resolve `EquipmentVisualDefinition` through existing item base/presentation data. Never use the live actor node as the viewport subject. Preserve disabled equipment in `_visuals_by_slot()` because activation status affects mechanics, not worn appearance.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_equipment_preview.gd tests/unit/test_character_presentation.gd tests/unit/test_equipment_inventory_ledger_page.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/equipment_ledger_preview_runner.gd
```

Expected: both exit `0`; preview isolation and accepted-transaction refresh markers pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ui/ledger/character_equipment_preview.gd scenes/ui/ledger/character_equipment_preview.tscn scripts/presentation/character_presentation.gd scripts/ui/ledger/equipment_inventory_ledger_page.gd scenes/ui/ledger/equipment_inventory_ledger_page.tscn tests/unit/test_character_equipment_preview.gd tests/unit/test_character_presentation.gd tests/integration/equipment_ledger_preview_runner.gd
git diff --cached --check
git commit -m "feat: preview equipped party members"
```

---

### Task 12: Add feature gating, developer controls, diagnostics, and lifecycle cleanup

**Files:**
- Modify: `scripts/settings/party_forge_settings.gd`
- Modify: `scripts/settings/party_forge_settings_store.gd`
- Modify: `scripts/ui/settings/additional_settings_page.gd`
- Modify: `scenes/ui/settings/additional_settings_page.tscn`
- Modify: `scripts/game/run_rules_snapshot.gd`
- Modify: `scripts/ui/developer_mode_badge.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Modify: `tests/unit/test_party_forge_settings.gd`
- Modify: `tests/unit/test_settings_screen.gd`
- Modify: `tests/unit/test_feature_access_integration.gd`
- Modify: `tests/unit/test_developer_mode_integration.gd`
- Create: `tests/integration/live_loot_lifecycle_runner.gd`

**Interfaces:**
- Settings fields: `personal_drop_multiplier_percent` in `0..10000`, `force_personal_drops`, `personal_drop_source_category_override`, `personal_drop_item_level_override` in `0..1000` where zero means automatic, and `show_ground_chest_diagnostics`; active only in Developer Mode.
- `RunRulesSnapshot` exposes immutable normalized accessors and resets all four to production defaults in Player Mode.
- Diagnostics show live/peak chest count, successes/failures by source, generation failures, and collection outcomes; no item or report persistence.
- Run start constructs registry/coordinator/world controller once; victory, defeat, restart, front-end return, and aborted startup clear all ground records/nodes and disconnect signals.

- [ ] **Step 1: Write failing settings/gate/lifecycle tests**

Assert store round trip and malformed-value defaults, Player Mode ignores saved dev controls, Player Mode without `equipment_inventory` unlock hides the ledger page and rolls no loot, permanent unlock enables both, Developer Unlock All exposes both without profile mutation, deterministic source override changes item level/source only in Developer Mode, all five run-exit paths clear records/chests, and a subsequent run starts at zero.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_feature_access_integration.gd tests/unit/test_developer_mode_integration.gd tests/unit/test_main_wiring.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/live_loot_lifecycle_runner.gd
```

Expected: non-zero exit or integration FAIL because controls/gates/cleanup are incomplete.

- [ ] **Step 3: Implement immutable run controls and one cleanup function**

Centralize teardown:

```gdscript
func _clear_live_loot() -> void:
	if ground_item_world_controller != null:
		ground_item_world_controller.clear_projection()
	if ground_item_registry != null:
		ground_item_registry.clear()
	personal_loot_drop_coordinator = null
	personal_loot_roll_service = null
	ground_item_registry = null
```

Call it before context destruction in every exit/abort path. Determine feature access from the active profile's `permanent_feature_unlocks` and the immutable `active_run_rules.feature_policy(...)`; never write an unlock because Developer Unlock All is active.

Pass both known unlock IDs and the active profile's permanent unlock IDs into `RunRulesSnapshot.feature_policy()`. Provide the same per-context access resolver to `PersonalLootRollService`, rather than conditionally connecting the defeat signal once for a global player. A locked Player Mode profile therefore cannot instantiate/focus the page or roll ground loot; Developer Unlock All resolves the same implemented page as available without changing the profile.

- [ ] **Step 4: Run GREEN**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_feature_access_integration.gd tests/unit/test_developer_mode_integration.gd tests/unit/test_main_wiring.gd
& $godot --headless --path . --quit-after 180 --script res://tests/integration/live_loot_lifecycle_runner.gd
```

Expected: both exit `0`; Player/Developer gating and all cleanup paths pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd scripts/ui/settings/additional_settings_page.gd scenes/ui/settings/additional_settings_page.tscn scripts/game/run_rules_snapshot.gd scripts/ui/developer_mode_badge.gd scripts/game/main.gd scenes/game/main.tscn tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_feature_access_integration.gd tests/unit/test_developer_mode_integration.gd tests/integration/live_loot_lifecycle_runner.gd
git diff --cached --check
git commit -m "feat: gate and tune live personal loot"
```

---

### Task 13: Validate multiplayer ownership, scale, resolutions, import, and full regression

**Files:**
- Create: `tests/integration/live_personal_loot_multiplayer_runner.gd`
- Create: `tests/integration/live_personal_loot_performance_runner.gd`
- Modify: `tests/unit/test_item_storage_responsive_contract.gd`
- Create: `docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md`

**Required evidence:**
- Four synthetic profiles/contexts with distinct devices and colors.
- Independent successes/failures from the same defeat.
- Foreign chest visible but not cycle-targetable/collectible.
- Owner pickup changes only that owner's inventory.
- Full inventory leaves only that owner's chest.
- 24-member ledger selection and equipment refresh.
- 1920x1080, 2560x1440, and 3840x2160 screenshots/geometry markers.
- 2,000 simultaneous chest projections across four owners with peak frame and memory observations.
- Cold import, all focused integrations, complete unit suite, and boot smoke.

- [ ] **Step 1: Write the multiplayer and performance runners**

The multiplayer runner must create real `PlayerRunContext` objects, register them in `RunContextRegistry`, use deterministic forced success for selected defeat IDs, and verify canonical owner states after pickups. The performance runner must add 2,000 records before frame measurement and report deterministic markers:

```gdscript
print("LIVE_LOOT_SCALE_SUMMARY: chests=%d owners=%d peak_frame_ms=%.3f" % [registry.all_records().size(), 4, peak_frame_ms])
if registry.all_records().size() != 2000 or peak_frame_ms > 33.4:
	quit(1)
else:
	print("LIVE_LOOT_PERFORMANCE_SUMMARY: PASS")
	quit(0)
```

- [ ] **Step 2: Run the focused acceptance batch**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_personal_loot_roll_service.gd tests/unit/test_ground_item_registry.gd tests/unit/test_personal_loot_drop_coordinator.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_ledger_item_provider.gd tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_character_equipment_preview.gd tests/unit/test_main_wiring.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/personal_loot_defeat_runner.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/ground_item_pickup_input_runner.gd
& $godot --headless --path . --quit-after 300 --script res://tests/integration/equipment_ledger_responsive_runner.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/equipment_ledger_preview_runner.gd
& $godot --headless --path . --quit-after 240 --script res://tests/integration/live_loot_lifecycle_runner.gd
& $godot --headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_multiplayer_runner.gd
& $godot --headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_performance_runner.gd
```

Expected: every command exits `0`, focused tests print `TEST_SUMMARY: PASS (0 failures)`, and every integration prints its named PASS marker.

- [ ] **Step 3: Run cold import, complete suite, and boot smoke**

Archive the final committed branch to a fresh temporary directory without `.godot`, `.git`, `.worktrees`, or untracked UID sidecars. Tracked `.superpowers` evidence and tracked UID sidecars remain because they are part of the accepted tree. Then run:

```powershell
$coldRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("party-forge-live-loot-" + [guid]::NewGuid().ToString("N"))
$coldProject = Join-Path $coldRoot 'party-forge'
New-Item -ItemType Directory -Path $coldProject -Force | Out-Null
git archive HEAD -o (Join-Path $coldRoot 'tracked.zip')
Expand-Archive -LiteralPath (Join-Path $coldRoot 'tracked.zip') -DestinationPath $coldProject
& $godot --headless --path $coldProject --import
& $godot --headless --path $coldProject --quit-after 600 --script res://tests/test_runner.gd
& $godot --headless --path $coldProject --quit-after 20
```

Expected: all exit `0`; import output contains no `SCRIPT ERROR`, `Parse Error`, `No loader found`, or unexpected `ERROR:`; the full suite prints exactly one `TEST_SUMMARY: PASS (` line; boot prints `PARTY_FORGE_BOOT_OK` and the expected front-end-ready marker.

- [ ] **Step 4: Perform visual/controller acceptance where hardware is available**

At all three target resolutions, capture the arena chest, owner pennant/label, mouse hover/click, Equipment & Inventory page, member 24, pinned tooltip, Alt/Shift layers, and accepted visual equipment refresh. With a physical controller, verify D-pad cycling, south-face pickup/place, west-face hold, LT/RT tooltip layers, right-stick scroll, and `Move closer` selection persistence.

If physical controller or visual capture is not actually performed, mark those rows `DEFERRED` in the verification document; do not convert automated input simulation into a manual-pass claim.

- [ ] **Step 5: Record exact evidence and audit scope**

Write command, exit code, PASS marker, duration, suite count, viewport, caveat, and log path for every run in `docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md`. Then run:

```powershell
rg -n "boss.*drop|extract|trading|drop item|despawn|save.*ground" scripts tests docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md
git status --short
git diff --check
```

Expected: no accidental boss-drop activation, extraction-loop implementation, trading, timed despawn, or ground-save implementation; only planned tracked changes plus preserved untracked `.gd.uid` sidecars appear.

- [ ] **Step 6: Commit the acceptance evidence**

```powershell
git add tests/integration/live_personal_loot_multiplayer_runner.gd tests/integration/live_personal_loot_performance_runner.gd tests/unit/test_item_storage_responsive_contract.gd docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md
git diff --cached --check
git commit -m "test: verify live personal loot and ledger"
```

- [ ] **Step 7: Request independent final review and prepare integration choices**

Review the complete branch against `docs/superpowers/specs/2026-08-11-live-personal-loot-and-equipment-ledger-design.md`, resolve every confirmed finding with RED/GREEN evidence, rerun Step 2 and Step 3 after the final fix, and use the `finishing-a-development-branch` skill. Do not merge until the user chooses the integration option.

---

## Deferred Increment 6 Seams

The implementation may expose typed events/data for these consumers, but it must not implement their behavior in Increment 5:

- Boss ground reward activation after victory/extraction sequencing is redesigned.
- Thirty-minute Battle Mode with bosses at 5/10/15/20/25/30 minutes.
- Timer pause after boss death, extraction circle/icon, five-second majority extraction, ten-second no-entry continuation, and majority ready-to-continue.
- Per-player run summary and a versioned Run History record containing outcome, duration, checkpoint, kills by enemy type, gold, item rarity/source, total damage/DPS, damage by character/ability, and future healing/damage-taken/death/revive fields.

Keep these seams typed and owner-scoped: `EnemyDefeatEvent`, generated item provenance, ground collection outcome, and player identity must be reusable without changing Increment 5 persisted schemas again.
