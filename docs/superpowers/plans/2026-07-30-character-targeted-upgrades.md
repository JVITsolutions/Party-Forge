# Party Forge Character-Targeted Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 25 data-driven upgrade cards, stable per-member targeting and names, matching-party synergies, registry-backed tooltips, and the approved accelerating XP curve without disturbing the clean live Godot integration checkout.

**Architecture:** Immutable `UpgradeDefinition` Resources describe eligibility and typed stat effects. `UpgradeApplicationService` revalidates, previews, and atomically records run-local ranks by stable member ID or party scope while `PartyManager` remains the single source used by combat and future Stat UI breakdowns. A presentation service turns the same Resources into card, recipient-preview, and tooltip data consumed by a modal upgrade-first UI.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Godot Resources, the existing stat resolver and custom headless test runner, Git worktrees.

## Global Constraints

- Work only on `feature/character-targeted-upgrades` in `.worktrees/character-targeted-upgrades`; the live `main` checkout remains the integration/QA copy.
- Preserve projectile speed/lifetime tuning, responsive class selection, GodotSteam, handbook files, and the tracked Godot AI plugin.
- Do not edit `project.godot`, `scenes/ui/hud.tscn`, or `scenes/game/main.tscn` unless a failing acceptance test proves the approved feature requires it.
- Authored cards are immutable Resources; never store run ranks or ownership in them.
- Content contains no arbitrary per-card scripts; new behavior uses shared typed effect handlers.
- Character ownership keys by `PartyMemberState.member_id`, never class, party index, node name, or display name.
- Action-restricted effects use explicit action tags and must not match merely because a class possesses the same capability.
- Open parties receive exactly one recruit offer; full parties receive no recruit offers; every offer contains three unique usable choices.
- Deadeye is exactly 30% more Physical Damage, 20% increased Attack Range, +0.25 Critical Strike Multiplier, and 15% less Attack Speed.
- Flat percentage-point values use decimal ratios (`0.10` means ten percentage points); increased/reduced/more/less values also use decimal ratios.
- The default XP sequence is exactly `20, 30, 44, 62, 84, 110`.
- Mouse hover and keyboard/controller focus produce identical tooltip content.
- The final suite count is discovered dynamically; require exit code `0` and `TEST_SUMMARY: PASS`, not a hard-coded count.

---

### Task 1: Typed Upgrade Schema and Action-Only Modifier Tags

**Files:**
- Create: `scripts/data/upgrade_effect_definition.gd`
- Create: `scripts/data/stat_upgrade_effect.gd`
- Create: `scripts/data/upgrade_definition.gd`
- Modify: `scripts/stats/stat_modifier.gd`
- Modify: `scripts/stats/stat_resolver.gd`
- Modify: `scripts/party/party_member_state.gd`
- Test: `tests/unit/test_upgrade_definition.gd`
- Test: `tests/unit/test_stat_resolver.gd`

**Interfaces:**
- Consumes: `StatModifier.Operation`, `PartyMemberState.capability_tags`, and `StatResolver.resolve(member_id, catalog, base_values, capabilities, sources, action_tags, revision)`.
- Produces: `UpgradeDefinition`, `StatUpgradeEffect`, and action-only modifier constraints used by all later tasks.

- [ ] **Step 1: Write failing schema and resolver tests**

Add tests that instantiate these exact contracts and assert that a projectile-only modifier affects `stats_for_action(member_id, [&"projectile"])` but not `stats_for_action(member_id, [])` even when the member has `projectile` capability:

```gdscript
var effect := StatUpgradeEffect.new()
effect.stat_id = &"damage"
effect.operation = StatModifier.Operation.INCREASED
effect.value_per_rank = 0.08
effect.required_action_tags = [&"projectile"]
TestAssertions.near(effect.value_for_rank(1), 0.08, 0.001, "rank one value", failures)

var definition := UpgradeDefinition.new()
definition.id = &"fixture_projectile"
definition.display_name = "Fixture Projectile"
definition.summary = "Fixture summary"
definition.scope = UpgradeDefinition.Scope.CHARACTER
definition.max_rank = 3
definition.selection_weight = 1.0
definition.effects = [effect]
TestAssertions.truthy(definition.is_single_recipient(), "character scope selects one member", failures)
```

Extend the resolver fixture with a `StatModifier` whose `required_action_tags = [&"projectile"]`; require base damage for `action_tags=[]` and increased damage for `[&"projectile"]`.

- [ ] **Step 2: Run the suite and verify RED**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

Expected: non-zero exit with missing `StatUpgradeEffect`, `UpgradeDefinition`, or `required_action_tags` failures.

- [ ] **Step 3: Implement the typed schema**

Use these public contracts:

```gdscript
class_name UpgradeEffectDefinition
extends Resource

enum EffectType { STAT_MODIFIER }
@export var effect_type := EffectType.STAT_MODIFIER
```

```gdscript
class_name StatUpgradeEffect
extends UpgradeEffectDefinition

@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var value_per_rank := 0.0
@export var rank_values: Array[float] = []
@export var required_capability_tags: Array[StringName] = []
@export var excluded_capability_tags: Array[StringName] = []
@export var required_action_tags: Array[StringName] = []
@export var excluded_action_tags: Array[StringName] = []
@export var source_label: String

func value_for_rank(rank: int) -> float:
	if rank <= 0:
		return 0.0
	if rank <= rank_values.size():
		return rank_values[rank - 1]
	return value_per_rank
```

```gdscript
class_name UpgradeDefinition
extends Resource

enum Scope { CHARACTER, CLASS_SPECIFIC, PARTY, TRAIT }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName
@export var display_name: String
@export var summary: String
@export_multiline var description: String
@export var tooltip_keyword_ids: Array[StringName] = []
@export var scope := Scope.CHARACTER
@export var allowed_class_ids: Array[StringName] = []
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var max_rank := 1
@export var selection_weight := 1.0
@export var rarity := Rarity.COMMON
@export var effects: Array[UpgradeEffectDefinition] = []

func is_single_recipient() -> bool:
	return scope in [Scope.CHARACTER, Scope.CLASS_SPECIFIC]

func is_member_eligible(member: PartyMemberState) -> bool:
	if member == null or member.class_definition == null:
		return false
	if not allowed_class_ids.is_empty() and member.class_definition.id not in allowed_class_ids:
		return false
	var tags := member.capability_tags
	for tag: StringName in required_all_tags:
		if tag not in tags:
			return false
	if not required_any_tags.is_empty() and not required_any_tags.any(func(tag: StringName) -> bool: return tag in tags):
		return false
	return not excluded_tags.any(func(tag: StringName) -> bool: return tag in tags)
```

Extend `StatModifier` with four exported arrays: `required_capability_tags`, `excluded_capability_tags`, `required_action_tags`, and `excluded_action_tags`. Preserve the old `required_tags`/`excluded_tags` fields and behavior for existing content. Change `applies_to` to receive capabilities and action tags separately, and update `StatResolver.resolve` accordingly.

- [ ] **Step 4: Run GREEN verification**

Run the full suite. Expected: `TEST_SUMMARY: PASS`, with the new schema and action-only test passing. Run `git diff --check`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/data/upgrade_effect_definition.gd scripts/data/stat_upgrade_effect.gd scripts/data/upgrade_definition.gd scripts/stats/stat_modifier.gd scripts/stats/stat_resolver.gd scripts/party/party_member_state.gd tests/unit/test_upgrade_definition.gd tests/unit/test_stat_resolver.gd
git commit -m "feat: define typed character upgrades"
```

---

### Task 2: Keyword, Name, XP, and Authored Upgrade Resources

**Files:**
- Create: `scripts/data/keyword_definition.gd`
- Create: `scripts/data/keyword_catalog.gd`
- Create: `scripts/data/character_name_pool.gd`
- Create: `scripts/data/experience_tuning.gd`
- Create: `tools/character_upgrade_content_rows.gd`
- Create: `tools/create_character_upgrade_data.gd`
- Create: `data/keywords/core_keywords.tres`
- Create: `data/progression/default_experience.tres`
- Create: `data/names/generic.tres`
- Create: `data/names/fighter.tres`, `data/names/ranger.tres`, `data/names/mage.tres`, `data/names/cleric.tres`, `data/names/paladin.tres`, `data/names/rogue.tres`, `data/names/frost_mage.tres`, `data/names/warlock.tres`, `data/names/marksman.tres`
- Create: `data/upgrades/cards/hold_the_line.tres`, `quickdraw.tres`, `living_flame.tres`, `sacred_conduit.tres`, `consecrated_bulwark.tres`, `cutthroat_instinct.tres`, `heart_of_winter.tres`, `blood_covenant.tres`, `deadeye.tres`
- Create: `data/upgrades/cards/martial_training.tres`, `ranged_calibration.tres`, `caster_discipline.tres`, `skirmishers_rhythm.tres`, `projectile_mastery.tres`, `expanding_power.tres`, `elemental_attunement.tres`
- Create: `data/upgrades/cards/vanguard_wall.tres`, `arcane_convergence.tres`, `divine_covenant.tres`, `vitality.tres`, `tempered_armor.tres`, `ferocity.tres`, `alacrity.tres`, `fleetfoot.tres`, `precision.tres`
- Modify: `scripts/data/class_definition.gd`
- Modify: `scripts/data/game_catalog.gd`
- Modify: `data/classes/fighter.tres`, `data/classes/ranger.tres`, `data/classes/mage.tres`, `data/classes/cleric.tres`, `data/classes/paladin.tres`, `data/classes/rogue.tres`, `data/classes/frost_mage.tres`, `data/classes/warlock.tres`, `data/classes/marksman.tres`
- Modify: `tools/create_default_data.gd`
- Test: `tests/unit/test_upgrade_catalog.gd`
- Test: `tests/unit/test_game_catalog.gd`
- Test: `tests/unit/test_experience_tuning.gd`

**Interfaces:**
- Consumes: Task 1 schemas, existing stat catalog, classes, traits, and attacks.
- Produces: exact validated baseline content exposed through `GameCatalog.upgrades`, `keywords`, and `generic_name_pool`.

- [ ] **Step 1: Write failing catalog/content tests**

Require:

```gdscript
var catalog := GameCatalog.load_defaults()
TestAssertions.equal(catalog.upgrades.size(), 25, "twenty-five authored upgrades", failures)
TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC).size(), 9, "nine signatures", failures)
TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CHARACTER and (not card.required_any_tags.is_empty() or not card.required_all_tags.is_empty())).size(), 7, "seven shared character cards", failures)
TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.TRAIT).size(), 3, "three matching-party synergies", failures)
TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CHARACTER and card.required_any_tags.is_empty() and card.required_all_tags.is_empty()).size(), 6, "six universal character cards", failures)
for class_definition: ClassDefinition in catalog.classes:
	TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC and class_definition.id in card.allowed_class_ids).size(), 1, "%s has one signature" % class_definition.id, failures)
TestAssertions.equal(catalog.upgrade_by_id(&"deadeye").max_rank, 1, "Deadeye one-time", failures)
TestAssertions.near((catalog.upgrade_by_id(&"deadeye").effects[0] as StatUpgradeEffect).value_for_rank(1), 0.30, 0.001, "Deadeye thirty percent more", failures)
TestAssertions.equal(catalog.keywords.validate().size(), 0, "keywords validate", failures)
TestAssertions.equal(catalog.generic_name_pool.names.size(), 12, "generic fallback count", failures)
TestAssertions.equal(catalog.validate().size(), 0, "expanded catalog validates", failures)
TestAssertions.equal(catalog.upgrades.all(func(card: UpgradeDefinition) -> bool: return card.rarity == UpgradeDefinition.Rarity.COMMON), true, "reserved rarity is inert common metadata", failures)
```

Also construct invalid definitions for empty/duplicate IDs, missing summary/keywords, unknown stats/classes/tags/keywords, contradictory requirements, nonpositive rank/weight, unsupported effect type/operation, and non-finite values. Every reported line must begin `PARTY_FORGE_UPGRADE_ERROR id=<id> path=<path> reason=`. Remove one required path in a catalog fixture and require validation failure; add one missing optional path and require safe exclusion.

Test XP defaults, monotonicity, invalid-field diagnostics, and safe fallback with:

```gdscript
var tuning := ExperienceTuning.new()
var actual := PackedInt32Array()
for level: int in range(1, 7):
	actual.append(tuning.requirement_for_level(level))
TestAssertions.equal(actual, PackedInt32Array([20, 30, 44, 62, 84, 110]), "approved XP sequence", failures)
var invalid := ExperienceTuning.new()
invalid.acceleration = -1.0
TestAssertions.equal(invalid.validate(), PackedStringArray(["PARTY_FORGE_XP_ERROR field=acceleration"]), "invalid XP diagnostic", failures)
TestAssertions.equal(invalid.requirement_for_level(6), 110, "invalid XP term uses safe fallback", failures)
```

- [ ] **Step 2: Run the suite and verify RED**

Expected: missing registries/resources and catalog fields.

- [ ] **Step 3: Implement registry and tuning Resources**

Implement:

```gdscript
class_name KeywordDefinition
extends Resource
@export var id: StringName
@export var display_name: String
@export_multiline var explanation: String
@export var is_capability_tag := false
```

```gdscript
class_name KeywordCatalog
extends Resource
@export var definitions: Array[KeywordDefinition] = []
func definition(id: StringName) -> KeywordDefinition:
	for entry: KeywordDefinition in definitions:
		if entry != null and entry.id == id:
			return entry
	return null
func has_definition(id: StringName) -> bool:
	return definition(id) != null
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for entry: KeywordDefinition in definitions:
		if entry == null or entry.id.is_empty() or entry.display_name.is_empty() or entry.explanation.is_empty():
			errors.append("invalid keyword definition")
		elif seen.has(entry.id):
			errors.append("duplicate keyword %s" % entry.id)
		else:
			seen[entry.id] = true
	return errors
```

```gdscript
class_name CharacterNamePool
extends Resource
@export var id: StringName
@export var names: PackedStringArray = []
func validate(minimum_size: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("name pool id is empty")
	if names.size() < minimum_size: errors.append("name pool %s requires %d names" % [id, minimum_size])
	if names.any(func(name: String) -> bool: return name.strip_edges().is_empty()): errors.append("name pool %s contains an empty name" % id)
	return errors
```

```gdscript
class_name ExperienceTuning
extends Resource
const SAFE_BASE := 20.0
const SAFE_LINEAR := 8.0
const SAFE_ACCELERATION := 2.0
@export var base_cost := SAFE_BASE
@export var linear_growth := SAFE_LINEAR
@export var acceleration := SAFE_ACCELERATION
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(base_cost) or base_cost < 0.0: errors.append("PARTY_FORGE_XP_ERROR field=base_cost")
	if not is_finite(linear_growth) or linear_growth < 0.0: errors.append("PARTY_FORGE_XP_ERROR field=linear_growth")
	if not is_finite(acceleration) or acceleration < 0.0: errors.append("PARTY_FORGE_XP_ERROR field=acceleration")
	return errors
func requirement_for_level(current_level: int) -> int:
	var n := float(maxi(current_level, 1) - 1)
	var base := base_cost if is_finite(base_cost) and base_cost >= 0.0 else SAFE_BASE
	var linear := linear_growth if is_finite(linear_growth) and linear_growth >= 0.0 else SAFE_LINEAR
	var curve := acceleration if is_finite(acceleration) and acceleration >= 0.0 else SAFE_ACCELERATION
	return maxi(ceili(base + linear * n + curve * n * n), 1)
```

- [ ] **Step 4: Author deterministic content rows and generator**

The generator must emit these exact files and values:

| ID/file | Scope / eligibility | Max | Effects per rank |
|---|---|---:|---|
| `hold_the_line` | class-specific Fighter | 1 | max_health INCREASED .20; armor FLAT 5 |
| `quickdraw` | class-specific Ranger | 1 | attack_speed INCREASED .20; projectile_speed INCREASED .25 |
| `living_flame` | class-specific Mage | 1 | fire_damage INCREASED .25; area_size INCREASED .20 |
| `sacred_conduit` | class-specific Cleric | 1 | healing_power INCREASED .25; lightning_damage INCREASED .25 |
| `consecrated_bulwark` | class-specific Paladin | 1 | block_chance FLAT .10; health_regeneration FLAT 1.5 |
| `cutthroat_instinct` | class-specific Rogue | 1 | crit_chance FLAT .10; crit_multiplier FLAT .25; life_steal FLAT .05 |
| `heart_of_winter` | class-specific Frost Mage | 1 | cold_damage INCREASED .25; area_size INCREASED .20 |
| `blood_covenant` | class-specific Warlock | 1 | chaos_damage INCREASED .30; life_steal FLAT .08; max_health REDUCED .15 |
| `deadeye` | class-specific Marksman | 1 | physical_damage MORE .30; attack_range INCREASED .20; crit_multiplier FLAT .25; attack_speed LESS .15 |
| `martial_training` | character required `martial` | 3 | physical_damage INCREASED .08; armor FLAT 1 |
| `ranged_calibration` | character required `ranged` | 3 | attack_range INCREASED .10; projectile_speed INCREASED .10 |
| `caster_discipline` | character required `caster` | 3 | damage INCREASED .08; attack_speed INCREASED .08 |
| `skirmishers_rhythm` | character required `skirmisher` | 3 | dodge_chance FLAT .04; move_speed INCREASED .05 |
| `projectile_mastery` | character required `projectile` | 3 | projectile_speed INCREASED .12; damage INCREASED .08 with required action `projectile` |
| `expanding_power` | character required `area` | 3 | area_size INCREASED .10; damage INCREASED .08 with required action `area` |
| `elemental_attunement` | character any `fire,cold,lightning,chaos` | 3 | four matching typed-damage INCREASED .12 effects, each capability-gated |
| `vanguard_wall` | trait required `vanguard` | 1 | armor FLAT 3; max_health INCREASED .10 |
| `arcane_convergence` | trait required `arcane` | 1 | area_size INCREASED .12; four matching typed-damage INCREASED .10 effects |
| `divine_covenant` | trait required `divine` | 1 | healing_power INCREASED .15; health_regeneration FLAT 1 |
| `vitality` | universal character | 5 | max_health INCREASED .08 |
| `tempered_armor` | universal character | 5 | armor FLAT 2 |
| `ferocity` | universal character | 5 | damage INCREASED .08 |
| `alacrity` | universal character | 5 | attack_speed INCREASED .06 |
| `fleetfoot` | universal character | 5 | move_speed INCREASED .05 |
| `precision` | universal character | 5 | crit_chance FLAT .03 |

Use selection weight `1.0` and inactive rarity `COMMON` for every baseline card. Every signature has its class in `allowed_class_ids`. Every shared/synergy card uses the exact normalized trait/capability IDs above. Exact display names are `Hold the Line`, `Quickdraw`, `Living Flame`, `Sacred Conduit`, `Consecrated Bulwark`, `Cutthroat Instinct`, `Heart of Winter`, `Blood Covenant`, `Deadeye`, `Martial Training`, `Ranged Calibration`, `Caster Discipline`, `Skirmisher's Rhythm`, `Projectile Mastery`, `Expanding Power`, `Elemental Attunement`, `Vanguard Wall`, `Arcane Convergence`, `Divine Covenant`, `Vitality`, `Tempered Armor`, `Ferocity`, `Alacrity`, `Fleetfoot`, and `Precision`. Store these exact nonnumeric summaries (and use the same sentence as the baseline narrative description); all numbers are assembled from effects by the presentation service:

```text
hold_the_line: Stand firm with greater health and armor.
quickdraw: Loose faster arrows with greater projectile velocity.
living_flame: Intensify fire magic and expanding blasts.
sacred_conduit: Channel stronger healing and lightning.
consecrated_bulwark: Block more attacks and recover health steadily.
cutthroat_instinct: Strike critically and steal life from wounded foes.
heart_of_winter: Deepen cold magic and widen frozen bursts.
blood_covenant: Trade vitality for chaos power and life steal.
deadeye: Trade attack speed for devastating long-range physical shots.
martial_training: Reinforce martial offense and armor.
ranged_calibration: Extend range and accelerate projectiles.
caster_discipline: Cast harder and faster.
skirmishers_rhythm: Evade attacks while moving more quickly.
projectile_mastery: Empower projectiles and the attacks that launch them.
expanding_power: Enlarge area effects and their damage.
elemental_attunement: Strengthen every element the character can wield.
vanguard_wall: Fortify every Vanguard, including later recruits.
arcane_convergence: Expand and empower every Arcane member's elements, including later recruits.
divine_covenant: Improve healing and regeneration for every Divine member, including later recruits.
vitality: Build greater maximum health.
tempered_armor: Add reliable armor.
ferocity: Deal greater damage.
alacrity: Attack more quickly.
fleetfoot: Move more quickly.
precision: Gain critical strike chance.
```

Name rows are exact and editable:

```text
fighter: Aldric, Branna, Cedric, Dagna, Garrick, Hilda, Rowan, Thane
ranger: Ash, Briar, Elowen, Fen, Linden, Robin, Sylvi, Wren
mage: Alaric, Circe, Elara, Isolde, Lucan, Mira, Orin, Selene
cleric: Ansel, Beatrix, Clement, Faith, Mercy, Sabine, Tobias, Verity
paladin: Aegis, Armand, Galahad, Helena, Roland, Seraphine, Tristan, Valora
rogue: Corvin, Flick, Jax, Nyx, Rook, Shade, Talia, Vesper
frost_mage: Boreas, Eira, Iskra, Lumi, Neve, Rime, Skadi, Ylva
warlock: Azrael, Belladonna, Dorian, Hex, Lilith, Malachar, Morwen, Sable
marksman: Arlen, Blythe, Cora, Fletcher, Hawke, Ivo, Petra, Quinn
generic: Ada, Bram, Celine, Dax, Erin, Finn, Gia, Hugo, Iris, Joren, Kara, Leon
```

`core_keywords.tres` must cover all stat `keyword_id` values, damage types, class/attack capabilities, all trait eligibility IDs, and `increased`, `reduced`, `more`, and `less`. Each explanation is non-empty and plain language.

- [ ] **Step 5: Integrate catalog and class consistency**

Add `name_pool: CharacterNamePool` and a deduped/sorted `normalized_eligibility_tags()` union to `ClassDefinition`. Add explicit capabilities:

```text
Fighter: area, melee, physical
Ranger: physical, projectile, ranged
Mage: area, fire, projectile
Cleric: healing, lightning, projectile
```

Keep the existing five expanded-class capabilities. `GameCatalog` gains `REQUIRED_UPGRADE_PATHS`, `STAT_CATALOG`, `KEYWORD_CATALOG`, `GENERIC_NAME_POOL`, `upgrades`, `keywords`, `generic_name_pool`, `upgrade_by_id(id)`, and structured `PARTY_FORGE_UPGRADE_ERROR id=<id> path=<path> reason=<reason>` validation. Required missing content blocks validation; optional paths may be skipped safely.

- [ ] **Step 6: Run the generator in a disposable copy, then verify GREEN**

Run the generator twice in a temporary Git archive, compare hashes, then run it once in the feature worktree. Run import and the full suite. Expected: deterministic outputs, `TEST_SUMMARY: PASS`, exactly 25 valid cards, no unrelated diff.

- [ ] **Step 7: Commit**

Stage only Task 2 paths and generated UID sidecars belonging to new scripts. Commit:

```powershell
git commit -m "feat: author character upgrade catalog"
```

---

### Task 3: Data-Driven XP and Deterministic Character Names

**Files:**
- Create: `scripts/progression/character_name_service.gd`
- Modify: `scripts/progression/experience_system.gd`
- Modify: `scripts/party/party_member_state.gd`
- Modify: `scripts/party/party_manager.gd`
- Modify: `scripts/game/main.gd`
- Test: `tests/unit/test_character_names.gd`
- Test: `tests/unit/test_progression.gd`
- Test: `tests/unit/test_party_manager.gd`

**Interfaces:**
- Consumes: class/generic name pools and `ExperienceTuning` from Task 2.
- Produces: stored mutable `character_name`, deterministic party identity, and queued earned-level numbers.

- [ ] **Step 1: Write failing naming and XP tests**

Assert same seed/member ID yields the same name; duplicate class recruits avoid used names; empty class pools use generic names; member state stores the chosen name. Update progression XP input from 70 to 74 and assert overflow plus one pending choice per earned level.

- [ ] **Step 2: Run and verify RED**

Expected: missing naming service/name field and old linear XP result.

- [ ] **Step 3: Implement naming and XP**

Use:

```gdscript
class_name CharacterNameService
extends RefCounted
static func choose_name(class_pool: CharacterNamePool, fallback_pool: CharacterNamePool, run_seed: int, member_id: int, used_names: PackedStringArray) -> String:
	var candidates := class_pool.names.duplicate() if class_pool != null else PackedStringArray()
	for fallback: String in fallback_pool.names if fallback_pool != null else PackedStringArray():
		if fallback not in candidates:
			candidates.append(fallback)
	if candidates.is_empty():
		push_warning("PARTY_FORGE_NAME_WARNING member=%d reason=no available names" % member_id)
		return "Unnamed #%d" % member_id
	var start := abs(hash("%d:%d" % [run_seed, member_id])) % candidates.size()
	for offset: int in candidates.size():
		var candidate := candidates[(start + offset) % candidates.size()]
		if candidate not in used_names:
			return candidate
	return candidates[start]
```

Preserve constructor callers with:

```gdscript
func _init(id_value: int, definition: ClassDefinition, leader: bool, generated_name: String = "") -> void
```

Add `PartyManager.configure_identity(run_seed: int, fallback_names: CharacterNamePool)` and call it before `initialize()` in `main.gd`. `ExperienceSystem` preloads default tuning, delegates `experience_for_next_level()`, preserves overflow, and queues the earned level numbers so multiple pending offers use stable distinct seeds.

- [ ] **Step 4: Verify GREEN and commit**

Run the full suite and `git diff --check`; commit as:

```powershell
git commit -m "feat: add run-local names and XP tuning"
```

---

### Task 4: Atomic Upgrade Ownership, Synergies, and Preview

**Files:**
- Create: `scripts/progression/upgrade_application_service.gd`
- Modify: `scripts/party/party_member_state.gd`
- Modify: `scripts/party/party_manager.gd`
- Test: `tests/unit/test_upgrade_application.gd`
- Test: `tests/unit/test_member_stats.gd`

**Interfaces:**
- Consumes: validated catalog cards, typed effects, stable member IDs, and stat resolver.
- Produces: eligibility, rank/cap enforcement, atomic application, current/future matching-party sources, and before/after previews.

- [ ] **Step 1: Write failing ownership/application tests**

Cover: duplicate Fighters with different Vitality ranks; Deadeye only on Marksman; current/future Vanguard Wall matches; ineligible members unchanged; max caps; every operation order; stable breakdown labels; Projectile Mastery action-only behavior; unknown upgrade ID rejection; stale recipient rejection; and invalid multi-effect application leaving ranks/sources unchanged.

- [ ] **Step 2: Run and verify RED**

Expected: missing application service and upgrade rank state.

- [ ] **Step 3: Implement the service and private ownership helpers**

Public API:

```gdscript
class_name UpgradeApplicationService
extends RefCounted
static func eligible_member_ids(definition: UpgradeDefinition, party: PartyManager) -> Array[int]
static func eligibility_reason(definition: UpgradeDefinition, party: PartyManager, member_id: int) -> String
static func validate_application(definition: UpgradeDefinition, party: PartyManager, member_id: int = 0) -> PackedStringArray
static func apply(upgrade_id: StringName, catalog: GameCatalog, party: PartyManager, member_id: int = 0) -> bool
static func source_for_rank(definition: UpgradeDefinition, rank: int, owner_member_id: int) -> StatModifierSource
static func preview_values(definition: UpgradeDefinition, party: PartyManager, member_id: int) -> Array[Dictionary]
```

Personal source ID: `upgrade:<upgrade_id>:member:<member_id>`. Party source ID: `upgrade:<upgrade_id>:party`. One stable cumulative source replaces the prior same-ID source; repeated ranks never append duplicate cumulative sources. Build and validate every prospective source before changing any rank/source. `PartyManager._sources_for(member)` derives party/matching sources dynamically so later recruits inherit them. Preview uses the same prospective source builder without mutating live state.

- [ ] **Step 4: Verify GREEN and commit**

Expected: full suite passes and breakdown rows contain the exact card label/rank. Commit:

```powershell
git commit -m "feat: apply targeted and party upgrades"
```

---

### Task 5: Deterministic Three-Choice Generation

**Files:**
- Modify: `scripts/progression/upgrade_choice.gd`
- Modify: `scripts/progression/level_up_choice_service.gd`
- Modify: `scripts/game/main.gd`
- Test: `tests/unit/test_upgrade_choices.gd`
- Test: `tests/unit/test_progression.gd`

**Interfaces:**
- Consumes: Task 4 eligibility/ranks and `GameCatalog.upgrades`.
- Produces: deterministic upgrade-first offers with recruit guarantee and universal fallback.

- [ ] **Step 1: Write failing offer tests**

Require exact three choices, deterministic ordered keys for the same seed, one recruit while space exists, no recruit when full, no capped/unusable cards, no duplicate keys, recipient-independent authored keys, universal authored fallback before legacy party-stat fallback, and identical ordered keys when only inactive rarity metadata changes.

- [ ] **Step 2: Run and verify RED**

Expected: missing `AUTHORED` kind and authored candidates.

- [ ] **Step 3: Implement offer generation**

Extend without breaking existing constructors:

```gdscript
enum Kind { RECRUIT, CLASS_RANK, TRAIT, PARTY_STAT, AUTHORED }
var definition: UpgradeDefinition
static func authored(card: UpgradeDefinition) -> UpgradeChoice:
	var choice := UpgradeChoice.new(Kind.AUTHORED, card.id, card.display_name)
	choice.definition = card
	return choice
func requires_recipient() -> bool:
	return kind == Kind.AUTHORED and definition != null and definition.is_single_recipient()
```

Sort stable candidates by ID before seeded weighted selection without replacement. A single `LevelUpChoiceService.generate(party, catalog, seed)` call returns the complete offer; remove `main.gd`'s 32-seed accumulation. Do not add recipient member ID to `choice.key()`.

- [ ] **Step 4: Verify GREEN and commit**

```powershell
git commit -m "feat: generate targeted upgrade offers"
```

---

### Task 6: Data-Derived Card and Tooltip Presentation

**Files:**
- Create: `scripts/progression/upgrade_presentation_service.gd`
- Create: `scripts/ui/upgrade_card.gd`
- Create: `scripts/ui/upgrade_tooltip_panel.gd`
- Create: `scenes/ui/upgrade_card.tscn`
- Create: `scenes/ui/upgrade_tooltip_panel.tscn`
- Test: `tests/unit/test_upgrade_presentation.gd`
- Test: `tests/unit/test_upgrade_tooltip_ui.gd`

**Interfaces:**
- Consumes: Task 4 preview plus stat/keyword catalogs.
- Produces: dictionaries rendered by UI without recalculating values.

- [ ] **Step 1: Write failing presentation and placement tests**

Test exact Deadeye 30% more/trade-off text, percentage-point formatting, matching-later-recruit language, every keyword explanation, `Missing definition: <id>`, hover/focus parity, and clamped placement at all viewport edges.

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement presentation and widgets**

Use:

```gdscript
class_name UpgradePresentationService
extends RefCounted
static func card(definition: UpgradeDefinition, party: PartyManager) -> Dictionary
static func tooltip(definition: UpgradeDefinition, rank: int, stats: StatCatalog, keywords: KeywordCatalog) -> Dictionary
static func recipient_rows(definition: UpgradeDefinition, party: PartyManager, health_provider: Callable) -> Array[Dictionary]
static func role_name(role: ClassDefinition.Role) -> String
```

Initial character-card rank text is exact when all eligible recipients share a rank and `Rank varies / <max>` when they differ. Each recipient row contains `member_id`, stored `character_name`, `class_name`, `role_name`, `health_current`, `health_maximum`, `class_rank`, `eligible`, `disabled_reason`, `current_rank`, `next_rank`, and data-derived `preview_lines`. The UI never generates a name or performs modifier arithmetic.

`UpgradeCard.bind_choice(choice, presentation, disabled_reason="")` renders only dictionary fields and emits `activated`, `detail_requested`, and `detail_dismissed`. Maintain combined hover/focus state. `UpgradeTooltipPanel.show_content(content, anchor)` and `hide_content()` share:

```gdscript
static func clamped_position(anchor_rect: Rect2, popup_size: Vector2, viewport_size: Vector2, margin: float = 16.0) -> Vector2
```

Prefer right of the card, then left, and clamp both axes inside the viewport.

- [ ] **Step 4: Verify GREEN and commit**

```powershell
git commit -m "feat: present upgrade cards and tooltips"
```

---

### Task 7: Upgrade-First Recipient and Confirmation UI

**Files:**
- Create: `scripts/ui/upgrade_recipient_picker.gd`
- Create: `scenes/ui/upgrade_recipient_picker.tscn`
- Modify: `scripts/ui/level_up_panel.gd`
- Modify: `scenes/ui/level_up_panel.tscn`
- Test: `tests/unit/test_level_up_targeting_ui.gd`
- Test: `tests/unit/test_responsive_ui.gd`

**Interfaces:**
- Consumes: exact choices, PartyManager, catalog, presentation/application services, and a health provider.
- Produces: one `confirmation_requested(choice, recipient_member_id)` handshake while preserving the unchanged offer through cancel/rejection.

- [ ] **Step 1: Write failing targeting and responsive tests**

Require three exact cards; first enabled focus; all members visible; ineligible rows disabled with reason; duplicate-class stored names/member IDs distinct; cancel restores the same choice instances/keys; confirmation emits once; rejection remains visible/usable; success hides. At 1280x720, 1920x1080, and 3840x2160, the modal root is full rect and its 1120x680 `ContentPanel` remains centered with scrollable content.

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement recipient picker and panel state coordinator**

Use:

```gdscript
signal confirmation_requested(choice: UpgradeChoice, recipient_member_id: int)
func configure(catalog: GameCatalog, upgrade_service: UpgradeApplicationService, health_provider: Callable) -> void
func show_choices(exact_choices: Array[UpgradeChoice], party: PartyManager, invalid_choice_keys: Dictionary = {}) -> void
func complete_selection() -> void
func reject_selection(reason: String) -> void
func cancel_subflow() -> void
```

`recipient_member_id == 0` denotes non-character choices. Root becomes a full-rect modal `Control` with `mouse_filter=STOP` and `PROCESS_MODE_ALWAYS`; `ContentPanel` contains mutually exclusive `OfferView`, `RecipientView`, and `ConfirmationView`. Do not hide before central application succeeds and do not regenerate the offer when navigating views.

Recipient picker API:

```gdscript
class_name UpgradeRecipientPicker
extends Control
signal recipient_selected(choice: UpgradeChoice, member_id: int)
signal cancelled
func show_for(choice: UpgradeChoice, recipient_rows: Array[Dictionary]) -> void
```

- [ ] **Step 4: Verify GREEN and commit**

```powershell
git commit -m "feat: add upgrade recipient flow"
```

---

### Task 8: Main Integration, Queued Levels, Documentation, and Acceptance

**Files:**
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Create: `tests/unit/test_character_upgrade_integration.gd`
- Modify: `docs/handbook/04-resources-and-content-data.md`
- Modify: `docs/handbook/08-visuals-audio-effects-and-ui.md`
- Modify: `docs/handbook/10-party-forge-architecture-reference.md`

**Interfaces:**
- Consumes: Tasks 1-7 complete milestone.
- Produces: live central revalidation, correct pending-level consumption, and documented extension points.

- [ ] **Step 1: Write failing central-wiring and integration tests**

Cover request -> central revalidation -> success/rejection; stale/invalid member consumes no pending level; success consumes exactly one; queued levels remain paused and show separately; boss-level completion resumes boss state; two same-class members can hold different cards/names; matching synergy affects later recruit; tooltip values equal resolved values; action-only damage uses actual attack tags.

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Wire central application and live health provider**

Preserve old callers with:

```gdscript
func _apply_choice(choice: UpgradeChoice, report_error: bool = true) -> bool:
	return _apply_choice_for_member(choice, 0, report_error)

func _apply_choice_for_member(choice: UpgradeChoice, recipient_member_id: int, report_error: bool = true) -> bool
func _on_choice_confirmation_requested(choice: UpgradeChoice, recipient_member_id: int) -> void
func _health_for_member(member_id: int) -> Vector2
```

`_on_choice_confirmation_requested` calls `complete_selection()` only after success and `reject_selection(reason)` on failure. Build health from the at-most-four live `PartyActor` children; never store scene-node references in member state.

- [ ] **Step 4: Update handbook facts**

Document how to add a card Resource through the generator rows, how scopes/eligibility/effects work, why member IDs own personal ranks, how matching-party sources reach future recruits, how the XP tuning Resource works, and how hover/focus share the tooltip formatter. Do not document deferred inventory, rarity scaling, passive trees, saves, or renaming controls as implemented.

- [ ] **Step 5: Run complete automated verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
& $godot --headless --path $worktree --editor --quit-after 2
git diff --check
git status --short
```

Expected: test exit `0` with `TEST_SUMMARY: PASS`; parser/import exit `0`; no `SCRIPT ERROR` or unexpected `TEST_FAILURE`; only milestone paths are changed before the final commit.

- [ ] **Step 6: Commit integration**

```powershell
git commit -m "feat: integrate character targeted upgrades"
```

- [ ] **Step 7: Manual acceptance in the feature worktree**

Open the worktree project separately from the live main editor. At 1920x1080 and 3840x2160 verify the ten approved cases: recruit offer, duplicate-class distinct names, hover/focus keywords, personal-only universal card, signature identity, restricted shared card, current/future matching synergy, visible benefit/trade-off, separate queued levels without XP loss, and correctly positioned UI. Stop the feature editor, require clean logs and `git status --short`, then request final review before integrating into `main`.
