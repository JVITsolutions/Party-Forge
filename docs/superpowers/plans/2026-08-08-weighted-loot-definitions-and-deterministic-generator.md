# Weighted Loot Definitions and Deterministic Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Increment 1 of the approved loot design: validated data-driven rarity/affix definitions and a deterministic staged generator that issues immutable Common-through-Legendary equipment without changing item-instance schema or ownership.

**Architecture:** Keep `ItemInstance` schema 1 and the existing pure `ItemInstanceIssuer`. Expand authored Resources into explicit rarity patterns, multi-effect affixes, tier records, and manifest-backed catalogs; then run a typed request through stable base, rarity, pattern, affix, tier, and roll stages. Generator provenance lives inside the existing JSON-safe `origin.source` value, and every failed stage returns a structured failure before issuance.

**Tech Stack:** Godot 4.7.1, typed GDScript, `.tres` Resources, existing `TestAssertions` unit harness, PowerShell verification, Git worktree branch `docs/weighted-loot-generation-design`.

## Global Constraints

- Preserve `ItemInstance.SCHEMA_VERSION == 1`; do not require a profile or item migration in this increment.
- Preserve exact existing IDs and roll ranges for `stout`, `keen`, `wise`, `of_embers`, `of_rime`, and `of_reach` so saved fixture items remain loadable.
- Register exactly ten rarity ranks in order: Common, Uncommon, Rare, Epic, Legendary, Mythic, Exotic, Ascendant, Divine, Eternal.
- `instance_supported` is true for all ten ranks; `ordinary_generation_enabled` is true only for Common through Legendary.
- Rarity patterns are data-authored; do not hardcode a universal three-prefix/three-suffix cap.
- Guaranteed implicits do not consume explicit prefix/suffix slots.
- The initial schema supports any positive number of affix tiers; fixture content uses three tiers and production content will use twelve in Increment 3.
- Item level is supplied by content and validated in the initial range `1..1000`; never derive it from character level.
- Filter eligibility before calculating weights. No weight modifier may restore an ineligible candidate.
- Party archetype tags may bias only equipment-base selection.
- Charisma uses diminishing returns and cannot bypass rarity, tier, tag, source, domain, unlock, or modifier-family gates.
- A generation failure must not call `ItemInstanceIssuer`, consume a caller-owned issuance sequence, or mutate profile/run/container state.
- Every deterministic candidate list is sorted by stable ID before weighted selection.
- Use exact structured diagnostics beginning with `PARTY_FORGE_ITEM_GENERATION_ERROR`.
- Do not add Loot Lab UI, equipment-stat projection, the 75-100 production affixes, or production ground-drop wiring in this increment.
- Use `apply_patch` for repository edits. Preserve unrelated generated `.gd.uid` sidecars and stage only named task files.
- Use this Godot executable for verification:

```powershell
$godot = 'C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
```

---

## File structure

### New production scripts

- `scripts/items/item_affix_pattern_definition.gd` — one weighted prefix/suffix/special capacity pattern.
- `scripts/items/item_modifier_effect_definition.gd` — one stat operation inside an affix.
- `scripts/items/item_affix_tier_definition.gd` — one item-level gate, tier weight, and per-effect roll range.
- `scripts/items/item_generation_vocabulary.gd` — supported domains and stable archetype tags.
- `scripts/items/item_generation_request.gd` — canonical immutable-by-convention generator input.
- `scripts/items/item_generation_failure.gd` — structured stage failure.
- `scripts/items/item_generation_trace.gd` — developer-safe accepted/rejected/weight trace.
- `scripts/items/item_generation_result.gd` — complete issued item or failure plus trace.
- `scripts/items/item_deterministic_random.gd` — stage-salted unit rolls and weighted selection.
- `scripts/items/item_generation_weight_policy.gd` — item-level, party-bias, Heat, and Charisma formulas.
- `scripts/items/item_base_selector.gd` — eligible equipment-base filtering and soft party bias.
- `scripts/items/item_rarity_selector.gd` — permitted ordinary rarity filtering and weighting.
- `scripts/items/item_pattern_selector.gd` — weighted pattern selection.
- `scripts/items/item_affix_assembly_result.gd` — affix assembly success/failure value.
- `scripts/items/item_affix_assembler.gd` — implicit, family, tier, and exact-roll assembly.
- `scripts/items/item_generation_service.gd` — staged orchestration and final issuer call.

### Modified production scripts

- `scripts/items/item_rarity_definition.gd` — rarity rank, support flags, base weight, unlocks, and patterns.
- `scripts/items/item_affix_definition.gd` — multi-effect, families, tags, domains, sources, ranks, weight, and tier records.
- `scripts/items/item_foundation_catalog.gd` — explicit manifest lookups, vocabulary, and cross-resource validation.
- `scripts/items/item_instance_codec.gd` — validate one roll per authored effect while preserving schema 1.
- `scripts/equipment/equipment_base_definition.gd` — default generation weight/tags and explicit implicit-affix IDs.
- `scripts/data/game_catalog.gd` — cross-validate item foundation against equipment and stats.
- `data/items/core_item_foundation_catalog.tres` — explicit external-resource manifest.
- `data/equipment/bases/forge_vanguard/forge_vanguard_sword.tres` — one deterministic implicit fixture.

### New authored Resources

- `data/items/rarities/*.tres` — ten separate rarity Resources.
- `data/items/patterns/*.tres` — eleven active Common-through-Legendary patterns.
- `data/items/affixes/fixtures/*.tres` — six compatibility fixtures plus `tempered_edge` implicit.

### Tests

- `tests/unit/test_item_generation_definitions.gd`
- `tests/unit/test_item_foundation_manifest.gd`
- `tests/unit/test_item_generation_request.gd`
- `tests/unit/test_item_base_and_rarity_selection.gd`
- `tests/unit/test_item_affix_assembler.gd`
- `tests/unit/test_item_generation_service.gd`
- `tests/unit/test_item_generation_distribution.gd`
- Modify `tests/unit/test_item_foundation_catalog.gd`
- Modify `tests/unit/test_item_instance_codec.gd`
- Modify `tests/unit/test_game_catalog.gd`

---

### Task 1: Add typed rarity-pattern, effect, tier, and vocabulary definitions

**Files:**
- Create: `scripts/items/item_affix_pattern_definition.gd`
- Create: `scripts/items/item_modifier_effect_definition.gd`
- Create: `scripts/items/item_affix_tier_definition.gd`
- Create: `scripts/items/item_generation_vocabulary.gd`
- Modify: `scripts/items/item_rarity_definition.gd`
- Modify: `scripts/items/item_affix_definition.gd`
- Test: `tests/unit/test_item_generation_definitions.gd`

**Interfaces:**
- Produces: `ItemAffixPatternDefinition.validate() -> PackedStringArray`
- Produces: `ItemModifierEffectDefinition.validate(StatCatalog) -> PackedStringArray`
- Produces: `ItemAffixTierDefinition.roll_bounds(effect_index: int) -> Vector2`
- Produces: `ItemAffixTierDefinition.validate(effect_count: int) -> PackedStringArray`
- Produces: `ItemRarityDefinition.validate() -> PackedStringArray`
- Produces: `ItemAffixDefinition.validate(stat_catalog, known_families, known_domains, known_sources, known_rarities, known_item_tags) -> PackedStringArray`

- [ ] **Step 1: Write the failing definition tests**

Create a suite whose `run()` covers exact success and rejection cases:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_pattern_contract(failures)
	_test_multi_effect_tiers(failures)
	_test_affix_cross_references(failures)
	return failures

func _test_pattern_contract(failures: Array[String]) -> void:
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"rare_balanced"
	pattern.prefix_count = 1
	pattern.suffix_count = 1
	pattern.weight = 2.0
	TestAssertions.equal(pattern.explicit_count(), 2, "pattern totals explicit slots", failures)
	TestAssertions.equal(pattern.validate(), PackedStringArray(), "valid pattern passes", failures)
	pattern.weight = NAN
	TestAssertions.truthy(not pattern.validate().is_empty(), "nonfinite pattern weight fails", failures)

func _test_multi_effect_tiers(failures: Array[String]) -> void:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 4
	tier.minimum_item_level = 250
	tier.base_weight = 30.0
	tier.minimum_rolls = [10.0, 0.08]
	tier.maximum_rolls = [18.0, 0.12]
	TestAssertions.equal(tier.validate(2), PackedStringArray(), "two-effect tier validates", failures)
	TestAssertions.equal(tier.roll_bounds(1), Vector2(0.08, 0.12), "second effect bounds resolve", failures)

func _test_affix_cross_references(failures: Array[String]) -> void:
	var affix := ItemAffixDefinition.new()
	affix.id = &"tempered_focus"
	affix.display_name = "Tempered Focus"
	affix.affix_kind = "prefix"
	affix.base_weight = 100.0
	affix.modifier_family_ids = [&"caster_power"]
	affix.allowed_generation_domains = [&"ordinary_drop"]
	affix.allowed_rarity_ids = [&"rare"]
	affix.required_item_tags = [&"caster"]
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"intelligence"
	effect.operation = StatModifier.Operation.FLAT
	affix.effects = [effect]
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = 1
	tier.base_weight = 100.0
	tier.minimum_rolls = [1.0]
	tier.maximum_rolls = [3.0]
	affix.tiers = [tier]
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.equal(affix.validate(stats, [&"caster_power"], [&"ordinary_drop"], [&"enemy"], [&"rare"], [&"caster"]), PackedStringArray(), "valid affix validates", failures)
	affix.allowed_generation_domains = [&"unknown_domain"]
	TestAssertions.truthy(not affix.validate(stats, [&"caster_power"], [&"ordinary_drop"], [&"enemy"], [&"rare"], [&"caster"]).is_empty(), "unknown domain fails", failures)
```

- [ ] **Step 2: Run the new suite and verify RED**

Run:

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd
```

Expected: nonzero exit or `TEST_SUMMARY: FAIL` because the four new classes and expanded properties do not exist.

- [ ] **Step 3: Implement the four focused value types**

Use these exact public fields and core methods:

```gdscript
# item_affix_pattern_definition.gd
class_name ItemAffixPatternDefinition
extends Resource

@export var id: StringName
@export_range(0, 64, 1) var prefix_count := 0
@export_range(0, 64, 1) var suffix_count := 0
@export_range(0, 64, 1) var special_count := 0
@export var weight := 1.0
@export var allowed_generation_domains: Array[StringName] = []

func explicit_count() -> int:
	return prefix_count + suffix_count

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("pattern id is empty")
	if prefix_count < 0 or suffix_count < 0 or special_count < 0: errors.append("pattern %s has a negative count" % id)
	if not is_finite(weight) or weight <= 0.0: errors.append("pattern %s weight must be finite and positive" % id)
	return errors
```

```gdscript
# item_modifier_effect_definition.gd
class_name ItemModifierEffectDefinition
extends Resource

@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var required_tags: Array[StringName] = []

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if stat_id.is_empty() or stats == null or stats.definition(stat_id) == null: errors.append("unknown stat %s" % stat_id)
	if operation not in ItemAffixDefinition.VALID_OPERATIONS: errors.append("unsupported operation %d" % operation)
	if required_tags.any(func(tag: StringName) -> bool: return tag.is_empty()): errors.append("required tag is empty")
	return errors
```

```gdscript
# item_affix_tier_definition.gd
class_name ItemAffixTierDefinition
extends Resource

@export_range(1, 1000, 1) var tier := 1
@export_range(1, 1000, 1) var minimum_item_level := 1
@export var base_weight := 1.0
@export var minimum_rolls: Array[float] = []
@export var maximum_rolls: Array[float] = []
@export var allowed_rarity_ids: Array[StringName] = []
@export var allowed_source_ids: Array[StringName] = []
@export var allowed_generation_domains: Array[StringName] = []

func roll_bounds(effect_index: int) -> Vector2:
	if effect_index < 0 or effect_index >= minimum_rolls.size() or effect_index >= maximum_rolls.size(): return Vector2(INF, -INF)
	return Vector2(minimum_rolls[effect_index], maximum_rolls[effect_index])

func validate(effect_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if tier < 1: errors.append("tier must be positive")
	if minimum_item_level < 1: errors.append("minimum item level must be positive")
	if not is_finite(base_weight) or base_weight <= 0.0: errors.append("tier %d weight must be finite and positive" % tier)
	if minimum_rolls.size() != effect_count or maximum_rolls.size() != effect_count: errors.append("tier %d requires one range per effect" % tier)
	for index: int in mini(minimum_rolls.size(), maximum_rolls.size()):
		if not is_finite(minimum_rolls[index]) or not is_finite(maximum_rolls[index]) or minimum_rolls[index] > maximum_rolls[index]: errors.append("tier %d effect %d range is invalid" % [tier, index])
	return errors
```

```gdscript
# item_generation_vocabulary.gd
class_name ItemGenerationVocabulary
extends RefCounted

const DOMAINS: Array[StringName] = [&"ordinary_drop", &"boss_drop", &"raid_drop", &"vendor", &"crafting", &"developer"]
const ARCHETYPES: Array[StringName] = [&"melee", &"ranged", &"caster", &"global"]
const AFFIX_KINDS: PackedStringArray = ["implicit", "prefix", "suffix", "special"]
```

- [ ] **Step 4: Expand rarity and affix definitions without legacy parallel fields**

Replace rarity minimum/maximum fields with exact patterns and support flags. Replace affix single-stat/parallel-tier arrays with effects and tier Resources. Preserve `roll_bounds(tier, effect_index := 0)` as a compatibility helper used by the codec and UI.

```gdscript
# ItemRarityDefinition public contract
@export_range(1, 100, 1) var rarity_rank := 1
@export var instance_supported := true
@export var ordinary_generation_enabled := true
@export var base_weight := 1.0
@export var required_unlock_tags: Array[StringName] = []
@export var patterns: Array[ItemAffixPatternDefinition] = []
@export_range(0, 64, 1) var reserved_special_slots := 0
```

```gdscript
# ItemAffixDefinition public contract
@export var id: StringName
@export var display_name: String
@export_enum("implicit", "prefix", "suffix", "special") var affix_kind := "prefix"
@export var base_weight := 1.0
@export var modifier_family_ids: Array[StringName] = []
@export var required_item_tags: Array[StringName] = []
@export var excluded_item_tags: Array[StringName] = []
@export var allowed_generation_domains: Array[StringName] = []
@export var allowed_source_ids: Array[StringName] = []
@export var allowed_rarity_ids: Array[StringName] = []
@export var required_unlock_tags: Array[StringName] = []
@export var effects: Array[ItemModifierEffectDefinition] = []
@export var tiers: Array[ItemAffixTierDefinition] = []

func tier_definition(tier_number: int) -> ItemAffixTierDefinition:
	for value: ItemAffixTierDefinition in tiers:
		if value != null and value.tier == tier_number: return value
	return null

func roll_bounds(tier_number: int, effect_index: int = 0) -> Vector2:
	var value := tier_definition(tier_number)
	return value.roll_bounds(effect_index) if value != null else Vector2(INF, -INF)
```

Validation must reject empty effects/families, duplicate families/tier numbers, nonascending tier numbers or minimum item levels, unknown references, overlapping required/excluded tags, and later-tier maximums below earlier-tier maximums for the same effect.

- [ ] **Step 5: Run focused GREEN and commit**

Run the focused suite and existing foundation suite. Expected: `TEST_SUMMARY: PASS (0 failures)`.

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd tests/unit/test_item_foundation_catalog.gd
git add scripts/items/item_affix_pattern_definition.gd scripts/items/item_modifier_effect_definition.gd scripts/items/item_affix_tier_definition.gd scripts/items/item_generation_vocabulary.gd scripts/items/item_rarity_definition.gd scripts/items/item_affix_definition.gd tests/unit/test_item_generation_definitions.gd
git commit -m "feat: add weighted loot definition types"
```

---

### Task 2: Convert the item foundation into an explicit ten-rarity manifest

**Files:**
- Create: `data/items/rarities/common.tres` through `data/items/rarities/eternal.tres`
- Create: `data/items/patterns/common_zero.tres`, `uncommon_prefix.tres`, `uncommon_suffix.tres`, `rare_two_prefix.tres`, `rare_balanced.tres`, `rare_two_suffix.tres`, `epic_prefix_heavy.tres`, `epic_suffix_heavy.tres`, `legendary_prefix_heavy.tres`, `legendary_balanced.tres`, `legendary_suffix_heavy.tres`
- Create: `data/items/affixes/fixtures/stout.tres`, `keen.tres`, `wise.tres`, `of_embers.tres`, `of_rime.tres`, `of_reach.tres`, `tempered_edge.tres`
- Modify: `data/items/core_item_foundation_catalog.tres`
- Modify: `scripts/items/item_foundation_catalog.gd`
- Modify: `scripts/items/item_instance_codec.gd`
- Modify: `tests/unit/test_item_foundation_catalog.gd`
- Modify: `tests/unit/test_item_instance_codec.gd`
- Test: `tests/unit/test_item_foundation_manifest.gd`

**Interfaces:**
- Produces: `ItemFoundationCatalog.supported_rarity_ids() -> Array[StringName]`
- Produces: `ItemFoundationCatalog.ordinary_rarity_ids() -> Array[StringName]`
- Produces: `ItemFoundationCatalog.validate(StatCatalog, EquipmentCatalog = null) -> PackedStringArray`
- Consumes: Task 1 definition types.

- [ ] **Step 1: Write RED tests for exact manifest and compatibility**

Assert the exact ten-rarity order, all ten `instance_supported`, only the first five ordinary-enabled, eleven exact active patterns, seven external affix resource paths, and upper-rarity issuance through the existing issuer. Update the codec test so a two-effect in-memory affix validates two ordered rolls and a saved legacy fixture still round-trips byte-equivalently.

```gdscript
const EXPECTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"exotic", &"ascendant", &"divine", &"eternal"]
const EXPECTED_ORDINARY: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]

func _assert_external_affixes(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	for definition: ItemAffixDefinition in catalog.affixes:
		TestAssertions.truthy(definition.resource_path.begins_with("res://data/items/affixes/"), "%s is an external manifest resource" % definition.id, failures)
```

Expected RED: current catalog has seven rarities, embedded affixes, and single-roll codec validation.

- [ ] **Step 2: Author exact rarity and pattern data**

Use this exact data table:

| Rarity | Rank | Ordinary | Base weight | Pattern IDs | Reserved specials |
| --- | ---: | --- | ---: | --- | ---: |
| common | 1 | true | 1000 | common_zero `(0P,0S,w=1)` | 0 |
| uncommon | 2 | true | 450 | uncommon_prefix `(1P,0S,w=1)`, uncommon_suffix `(0P,1S,w=1)` | 0 |
| rare | 3 | true | 180 | rare_two_prefix `(2P,0S,w=1)`, rare_balanced `(1P,1S,w=2)`, rare_two_suffix `(0P,2S,w=1)` | 0 |
| epic | 4 | true | 55 | epic_prefix_heavy `(2P,1S,w=1)`, epic_suffix_heavy `(1P,2S,w=1)` | 0 |
| legendary | 5 | true | 10 | legendary_prefix_heavy `(3P,1S,w=1)`, legendary_balanced `(2P,2S,w=2)`, legendary_suffix_heavy `(1P,3S,w=1)` | 1 |
| mythic | 6 | false | 1 | none | 0 |
| exotic | 7 | false | 1 | none | 0 |
| ascendant | 8 | false | 1 | none | 0 |
| divine | 9 | false | 1 | none | 0 |
| eternal | 10 | false | 1 | none | 0 |

All ten set `instance_supported = true`. Rare through Legendary use `required_unlock_tags = [&"rarity_<id>_unlocked"]`; Common and Uncommon have no rarity unlock tag. Upper ranks have no ordinary patterns because their acquisition systems are inactive.

- [ ] **Step 3: Externalize the seven fixture affixes**

Preserve the six existing IDs, kinds, three tier ranges, operations, and exact roll bounds. Set prefix families to `attribute_constitution`, `attribute_dexterity`, and `attribute_wisdom`; suffix families to `damage_fire`, `damage_cold`, and `attack_range`. Use `base_weight = 100.0`, domains `ordinary_drop`, `boss_drop`, and `developer`, sources `ordinary_enemy`, `boss`, and `developer`, and active rarities Common-through-Legendary. Add `tempered_edge` as an implicit with one `physical_damage` increased effect, family `implicit_forge_vanguard`, and tiers `(1, ilvl 1, w100, 0.05..0.10)`, `(2, ilvl 100, w40, 0.11..0.20)`, `(3, ilvl 500, w10, 0.21..0.30)`.

- [ ] **Step 4: Make the catalog the explicit manifest and expand codec validation**

The catalog exports these registries and derives known IDs from them:

```gdscript
@export var modifier_family_ids: Array[StringName] = []
@export var known_source_ids: Array[StringName] = []
@export var known_item_tags: Array[StringName] = []
@export var rarities: Array[ItemRarityDefinition] = []
@export var affixes: Array[ItemAffixDefinition] = []
```

Set manifest families to the seven exact family IDs above, sources to `ordinary_enemy`, `boss`, and `developer`, and item tags to `melee`, `ranged`, `caster`, `global`, all current item-type IDs, all weight-class IDs, and all current weapon-family IDs. Validation rejects embedded production affixes/rarities (`resource_path.is_empty()`), duplicate paths, unknown cross-references, impossible enabled rarity patterns, and invalid resource order.

Change codec rarity validation from `functional` to `instance_supported`. Change affix roll validation to require `definition.effects.size()` ordered rolls and validate each roll against the corresponding effect and tier bounds:

```gdscript
if not data["rolls"] is Array or (data["rolls"] as Array).size() != definition.effects.size():
	return _field_error("%s.rolls" % path, "must contain one roll per authored effect")
for effect_index: int in definition.effects.size():
	var error := _validate_roll((data["rolls"] as Array)[effect_index], "%s.rolls[%d]" % [path, effect_index], definition.effects[effect_index], definition.roll_bounds(int(data["tier"]), effect_index))
	if not error.is_empty(): return error
```

Do not validate affix counts against rarity patterns during decode; historical deterministic fixtures may have counts that were valid before the production generator existed.

- [ ] **Step 5: Run compatibility suites and commit**

Run:

```powershell
& $godot --headless --path . --import
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_item_instance_codec.gd tests/unit/test_item_ownership_state.gd tests/unit/test_profile_item_schema_migration.gd
```

Expected: import exit 0 without loader/parse errors and `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add data/items scripts/items/item_foundation_catalog.gd scripts/items/item_instance_codec.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_item_instance_codec.gd
git commit -m "feat: register production loot manifest"
```

---

### Task 3: Add canonical request, failure, trace, result, and deterministic random primitives

**Files:**
- Create: `scripts/items/item_generation_request.gd`
- Create: `scripts/items/item_generation_failure.gd`
- Create: `scripts/items/item_generation_trace.gd`
- Create: `scripts/items/item_generation_result.gd`
- Create: `scripts/items/item_deterministic_random.gd`
- Test: `tests/unit/test_item_generation_request.gd`

**Interfaces:**
- Produces: `ItemGenerationRequest.create(seed, generation_sequence, item_level, source_id, domain, permitted_rarities) -> ItemGenerationRequest`
- Produces: `ItemGenerationRequest.validate(ItemFoundationCatalog) -> String`
- Produces: `ItemGenerationRequest.canonical_document() -> Dictionary`
- Produces: `ItemDeterministicRandom.unit(seed, sequence, stage, draw) -> float`
- Produces: `ItemDeterministicRandom.weighted_id(seed, sequence, stage, draw, weights) -> StringName`
- Produces: `ItemGenerationTrace.record(stage, eligible, rejected, weights, selected) -> void`

- [ ] **Step 1: Write RED tests for strict request shape and stable substreams**

Cover JSON-safe canonical fields, item-level bounds, known domain/source/rarity/unlock validation, nonnegative Heat and Charisma, required/excluded contradictions, same-seed reproduction, candidate-order independence, and stage isolation.

```gdscript
var request := ItemGenerationRequest.create(991, 4, 250, &"ordinary_enemy", &"ordinary_drop", [&"common", &"uncommon"])
request.party_archetype_tags = [&"melee"]
request.charisma_value = 25.0
TestAssertions.equal(request.validate(foundation), "", "valid request passes", failures)
TestAssertions.equal(ItemDeterministicRandom.unit(991, 4, &"rarity", 0), ItemDeterministicRandom.unit(991, 4, &"rarity", 0), "same stage roll repeats", failures)
TestAssertions.equal(ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"b": 1.0, &"a": 2.0}), ItemDeterministicRandom.weighted_id(991, 4, &"base", 0, {&"a": 2.0, &"b": 1.0}), "weight dictionary order is irrelevant", failures)
```

- [ ] **Step 2: Implement exact request fields and canonicalization**

```gdscript
class_name ItemGenerationRequest
extends RefCounted

var seed := 0
var generation_sequence := 0
var item_level := 1
var source_id: StringName
var generation_domain: StringName
var difficulty_id: StringName = &"normal"
var heat := 0.0
var permitted_rarity_ids: Array[StringName] = []
var party_archetype_tags: Array[StringName] = []
var charisma_value := 0.0
var unlock_tags: Array[StringName] = []
var required_base_tags: Array[StringName] = []
var excluded_base_tags: Array[StringName] = []
var required_affix_tags: Array[StringName] = []
var excluded_affix_tags: Array[StringName] = []
var forced_base_id: StringName
var forced_rarity_id: StringName
```

`canonical_document()` sorts every StringName array and emits only JSON strings/numbers/arrays with exact field names matching the properties above. `validate()` returns the first exact `PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=<field> reason=<reason>` and accepts only `difficulty_id == &"normal"` in this increment.

- [ ] **Step 3: Implement structured outcome values**

```gdscript
class_name ItemGenerationFailure
extends RefCounted

var stage: StringName
var code: StringName
var source_id: StringName
var seed := 0
var generation_sequence := 0
var details: Dictionary = {}

func message() -> String:
	return "PARTY_FORGE_ITEM_GENERATION_ERROR stage=%s code=%s source=%s seed=%d sequence=%d" % [stage, code, source_id, seed, generation_sequence]
```

```gdscript
class_name ItemGenerationResult
extends RefCounted

var item: ItemInstance
var failure: ItemGenerationFailure
var trace: ItemGenerationTrace

func ok() -> bool:
	return item != null and failure == null
```

Trace records canonical stage dictionaries. It sorts eligible IDs and weight keys and deep-copies details so callers cannot mutate recorded evidence.

- [ ] **Step 4: Implement stage-salted randomness**

Derive a positive 60-bit seed from the first 15 hexadecimal characters of `SHA256("<seed>|<sequence>|<stage>|<draw>")`, seed a new `RandomNumberGenerator`, and take exactly one draw. `weighted_id` sorts IDs, rejects nonfinite/nonpositive weights, rolls `unit * total`, and returns the last ID only for floating-point boundary fallback.

- [ ] **Step 5: Run focused GREEN and commit**

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_request.gd
git add scripts/items/item_generation_request.gd scripts/items/item_generation_failure.gd scripts/items/item_generation_trace.gd scripts/items/item_generation_result.gd scripts/items/item_deterministic_random.gd tests/unit/test_item_generation_request.gd
git commit -m "feat: add deterministic item generation request"
```

Expected: `TEST_SUMMARY: PASS (0 failures)`.

---

### Task 4: Implement normalized equipment tags, weight policy, and base selection

**Files:**
- Modify: `scripts/equipment/equipment_base_definition.gd`
- Modify: `data/equipment/bases/forge_vanguard/forge_vanguard_sword.tres`
- Create: `scripts/items/item_generation_weight_policy.gd`
- Create: `scripts/items/item_base_selector.gd`
- Test: `tests/unit/test_item_base_and_rarity_selection.gd`

**Interfaces:**
- Produces: `EquipmentBaseDefinition.normalized_generation_tags() -> Array[StringName]`
- Produces: `ItemGenerationWeightPolicy.base_weight(base, request) -> float`
- Produces: `ItemBaseSelector.select(request, equipment, trace) -> EquipmentBaseDefinition`

- [ ] **Step 1: Write RED base-filtering and soft-bias tests**

Build an in-memory three-base catalog: melee, caster, and global. Assert required/excluded tags are hard filters; a melee party gives the melee base exactly a `3.0` multiplier; global remains unchanged; caster remains positive; forced unknown/filtered bases return null; and repeated selection is stable.

- [ ] **Step 2: Add normalized generation fields**

```gdscript
@export var generation_weight := 100.0
@export var generation_tags: Array[StringName] = []
@export var implicit_affix_ids: Array[StringName] = []

func normalized_generation_tags() -> Array[StringName]:
	var tags := generation_tags.duplicate()
	for tag: StringName in required_all_tags + required_any_tags:
		if tag not in tags: tags.append(tag)
	for tag: StringName in [item_type_id, weight_class_id, weapon_family_id]:
		if not tag.is_empty() and tag not in tags: tags.append(tag)
	if required_all_tags.is_empty() and required_any_tags.is_empty() and &"global" not in tags: tags.append(&"global")
	tags.sort()
	return tags
```

Validation rejects nonfinite/nonpositive generation weight, empty/duplicate explicit generation tags, duplicate implicit IDs, and any overlap between normalized tags and `excluded_tags`. Add `implicit_affix_ids = [&"tempered_edge"]` to only `forge_vanguard_sword.tres`; Increment 3 authors the complete 99-base implicit set.

- [ ] **Step 3: Implement exact baseline weight formulas**

```gdscript
class_name ItemGenerationWeightPolicy
extends RefCounted

const PARTY_MATCH_MULTIPLIER := 3.0
const MAX_ITEM_LEVEL := 1000

static func progress(item_level: int) -> float:
	return clampf(float(item_level - 1) / float(MAX_ITEM_LEVEL - 1), 0.0, 1.0)

static func diminishing_charisma(charisma: float) -> float:
	var value := maxf(charisma, 0.0)
	return value / (value + 100.0) if value > 0.0 else 0.0

static func base_weight(base: EquipmentBaseDefinition, request: ItemGenerationRequest) -> float:
	var weight := base.generation_weight
	var tags := base.normalized_generation_tags()
	if request.party_archetype_tags.any(func(tag: StringName) -> bool: return tag in tags): weight *= PARTY_MATCH_MULTIPLIER
	return weight

static func rarity_weight(rarity: ItemRarityDefinition, request: ItemGenerationRequest) -> float:
	return rarity.base_weight * (1.0 + progress(request.item_level) * float(rarity.rarity_rank - 1) * 0.15) * (1.0 + maxf(request.heat, 0.0) * float(rarity.rarity_rank - 1) * 0.01)

static func affix_weight(affix: ItemAffixDefinition, request: ItemGenerationRequest) -> float:
	var scarcity := clampf((1000.0 - minf(affix.base_weight, 1000.0)) / 1000.0, 0.0, 1.0)
	return affix.base_weight * (1.0 + progress(request.item_level) * 0.75 * scarcity) * (1.0 + diminishing_charisma(request.charisma_value) * 0.25 * scarcity)

static func tier_weight(tier: ItemAffixTierDefinition, request: ItemGenerationRequest) -> float:
	return tier.base_weight * (1.0 + progress(request.item_level) * float(tier.tier - 1) * 0.20)

static func roll_quality(base_unit: float, charisma: float) -> float:
	return 1.0 - pow(1.0 - clampf(base_unit, 0.0, 1.0), 1.0 + 0.25 * diminishing_charisma(charisma))
```

- [ ] **Step 4: Implement stable base filtering and selection**

Filter forced ID, required/excluded request tags, and positive weight. Record every rejection under stable codes (`unknown_forced_base`, `missing_required_tag`, `excluded_tag`, `invalid_weight`). Sort by base ID, record weights, and call `ItemDeterministicRandom.weighted_id(..., &"base", 0, weights)`.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_base_and_rarity_selection.gd tests/unit/test_equipment_contract.gd tests/unit/test_expanded_catalog.gd
git add scripts/equipment/equipment_base_definition.gd data/equipment/bases/forge_vanguard/forge_vanguard_sword.tres scripts/items/item_generation_weight_policy.gd scripts/items/item_base_selector.gd tests/unit/test_item_base_and_rarity_selection.gd
git commit -m "feat: add smart equipment base selection"
```

---

### Task 5: Implement rarity and pattern selection with hard gates

**Files:**
- Create: `scripts/items/item_rarity_selector.gd`
- Create: `scripts/items/item_pattern_selector.gd`
- Modify: `tests/unit/test_item_base_and_rarity_selection.gd`

**Interfaces:**
- Produces: `ItemRaritySelector.select(request, foundation, trace) -> ItemRarityDefinition`
- Produces: `ItemPatternSelector.select(request, rarity, trace) -> ItemAffixPatternDefinition`
- Consumes: Task 3 deterministic random and Task 4 weight policy.

- [ ] **Step 1: Add RED tests for authorization versus weighting**

Assert Common-through-Legendary selection only from `permitted_rarity_ids`; missing rarity unlocks reject Rare/Epic/Legendary; forced Mythic fails in `ordinary_drop`; forced Mythic also fails in `developer` generator because upper special patterns are intentionally unavailable in Increment 1; direct `ItemInstanceIssuer` upper-rarity fixtures remain valid; selected patterns always match domain and exact rarity list.

- [ ] **Step 2: Implement rarity selection**

Eligibility order is: registered -> `instance_supported` -> request permitted -> `ordinary_generation_enabled` -> required unlock tags -> forced ID. Developer domain does not bypass missing pattern/special-system support in this increment. Weight only survivors with `ItemGenerationWeightPolicy.rarity_weight`; stage salt is `rarity`.

- [ ] **Step 3: Implement pattern selection**

Filter the selected rarity's patterns by domain, validate exact positive weight, and select using stage salt `pattern:<rarity_id>`. Record `no_eligible_pattern` when empty. Do not synthesize a prefix/suffix split.

- [ ] **Step 4: Run GREEN and commit**

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_base_and_rarity_selection.gd
git add scripts/items/item_rarity_selector.gd scripts/items/item_pattern_selector.gd tests/unit/test_item_base_and_rarity_selection.gd
git commit -m "feat: gate weighted rarity patterns"
```

---

### Task 6: Assemble implicits, explicit affixes, tiers, and exact rolls

**Files:**
- Create: `scripts/items/item_affix_assembly_result.gd`
- Create: `scripts/items/item_affix_assembler.gd`
- Test: `tests/unit/test_item_affix_assembler.gd`

**Interfaces:**
- Produces: `ItemAffixAssembler.assemble(request, base, rarity, pattern, foundation, trace) -> ItemAffixAssemblyResult`
- Produces: ordered `Array[ItemAffixInstance]` with implicits first, then prefixes, suffixes, and specials.

- [ ] **Step 1: Write RED tests for complete affix assembly**

Cover: base implicit does not consume explicit slots; required/excluded tags; domain/source/rank/item-level/unlock filtering; exact prefix/suffix counts; duplicate definition prevention; family blocking across pure and hybrid candidates; ascending eligible tiers; same seed exact rolls; high item level broadens tiers but does not guarantee the top tier; Charisma roll quality remains within range; empty slot pool returns `no_eligible_affix` without partial affixes.

- [ ] **Step 2: Implement eligibility helpers**

`_eligible_affixes(kind, request, base_tags, rarity_id, blocked_families, foundation)` applies all hard filters before weights. `required_affix_tags` join the base tag requirement; `excluded_affix_tags` reject candidates. Allowed arrays mean unrestricted only when empty. Every selected definition ID and every family it declares become blocked for subsequent slots.

- [ ] **Step 3: Implement tier and roll selection**

Filter tiers by item level, rarity, source, and domain. Weight survivors with `tier_weight` and stage salt `tier:<slot>:<affix_id>`. For each effect, compute one stage-salted unit, transform it with `roll_quality`, then calculate `lerpf(bounds.x, bounds.y, quality)`. Preserve the exact float in `ItemModifierRoll`; copy the effect's required tags.

- [ ] **Step 4: Implement all-or-nothing assembly**

```gdscript
class_name ItemAffixAssemblyResult
extends RefCounted

var affixes: Array[ItemAffixInstance] = []
var error_code: StringName
var details: Dictionary = {}

func ok() -> bool:
	return error_code.is_empty()
```

Assemble every base `implicit_affix_id` first, requiring `affix_kind == "implicit"`. Then fill exact prefix, suffix, and active special counts. Build in a local array and return an empty array on any failure. Legendary's reserved special slot is not part of `pattern.special_count`, so it remains unfilled.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_affix_assembler.gd tests/unit/test_item_instance_codec.gd
git add scripts/items/item_affix_assembly_result.gd scripts/items/item_affix_assembler.gd tests/unit/test_item_affix_assembler.gd
git commit -m "feat: assemble weighted item affixes"
```

---

### Task 7: Orchestrate generation and issue immutable schema-1 items

**Files:**
- Create: `scripts/items/item_generation_service.gd`
- Test: `tests/unit/test_item_generation_service.gd`

**Interfaces:**
- Produces: `ItemGenerationService.generate(request, issuer_namespace, item_sequence, equipment, foundation) -> ItemGenerationResult`
- Consumes: all prior task interfaces and existing `ItemInstanceIssuer.issue(...)`.

- [ ] **Step 1: Write end-to-end RED tests**

Test exact fixed-seed item dictionaries for Common, Uncommon, Rare, Epic, and Legendary; repeated requests; different generation sequence; implicit-first ordering; canonical origin provenance; invalid request; no eligible base/rarity/pattern/affix/tier; invalid issuer namespace; and unchanged caller sequence variable on failure.

- [ ] **Step 2: Implement staged orchestration**

```gdscript
class_name ItemGenerationService
extends RefCounted

const GENERATOR_VERSION := 1

static func generate(request: ItemGenerationRequest, issuer_namespace: String, item_sequence: int, equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> ItemGenerationResult:
	var result := ItemGenerationResult.new()
	result.trace = ItemGenerationTrace.new()
	var request_error := request.validate(foundation) if request != null else "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=request reason=missing"
	if not request_error.is_empty(): return _fail(result, request, &"request", &"invalid_request", {"message": request_error})
	var base := ItemBaseSelector.select(request, equipment, result.trace)
	if base == null: return _fail(result, request, &"base", &"no_eligible_base", {})
	var rarity := ItemRaritySelector.select(request, foundation, result.trace)
	if rarity == null: return _fail(result, request, &"rarity", &"no_eligible_rarity", {})
	var pattern := ItemPatternSelector.select(request, rarity, result.trace)
	if pattern == null: return _fail(result, request, &"pattern", &"no_eligible_pattern", {"rarity_id": String(rarity.id)})
	var assembled := ItemAffixAssembler.assemble(request, base, rarity, pattern, foundation, result.trace)
	if not assembled.ok(): return _fail(result, request, &"affix", assembled.error_code, assembled.details)
	var source := {"generation": {"generator_version": GENERATOR_VERSION, "domain": String(request.generation_domain), "source_id": String(request.source_id), "item_level": request.item_level, "request_sequence": request.generation_sequence}}
	var issued := ItemInstanceIssuer.issue(issuer_namespace, item_sequence, source, request.seed, {"affixes": assembled.affixes.map(func(value: ItemAffixInstance) -> Dictionary: return value.to_dictionary()), "base_definition_id": String(base.id), "item_level": request.item_level, "rarity_id": String(rarity.id)}, equipment, foundation)
	if not issued.ok(): return _fail(result, request, &"issuance", &"issuer_rejected", {"message": issued.error})
	result.item = issued.item
	return result
```

Implement `_fail` to construct `ItemGenerationFailure`, copy the request provenance when available, attach no item, and preserve the trace. The service is pure: it receives a numeric item sequence and cannot increment external state.

- [ ] **Step 3: Verify immutable compatibility**

Encode each generated item, decode it through `ItemInstanceCodec`, and assert exact dictionary equality. Change duplicated catalog tier ranges after decode and assert issued rolls do not change. Confirm `origin` retains the existing four top-level fields and generator provenance is nested inside `origin.source`.

- [ ] **Step 4: Run GREEN and commit**

```powershell
& $godot --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_service.gd tests/unit/test_item_instance_codec.gd tests/unit/test_item_container_transactions.gd
git add scripts/items/item_generation_service.gd tests/unit/test_item_generation_service.gd
git commit -m "feat: generate immutable weighted equipment"
```

---

### Task 8: Add cross-catalog reachability, deterministic distribution tests, and final verification

**Files:**
- Modify: `scripts/data/game_catalog.gd`
- Modify: `scripts/items/item_foundation_catalog.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Create: `tests/unit/test_item_generation_distribution.gd`
- Create: `docs/verification/2026-08-08-weighted-loot-definitions-and-generator.md`

**Interfaces:**
- Produces: startup validation that proves enabled rarity patterns and fixture affixes are reachable against the live 99-base equipment catalog.
- Consumes: all prior tasks.

- [ ] **Step 1: Write RED cross-catalog reachability tests**

Duplicate the real catalogs and inject: unknown implicit ID, impossible required item tag, enabled rarity with no patterns, pattern with unavailable kind, affix whose every tier is unreachable in `1..1000`, duplicate manifest resource path, and ordinary-enabled upper rank. Assert exact structured catalog errors and no partial acceptance.

- [ ] **Step 2: Cross-validate foundation and equipment catalogs**

Change `GameCatalog._validate_foundation` to call:

```gdscript
errors.append_array(item_foundation_catalog.validate(STAT_CATALOG, equipment_catalog))
```

The foundation builds the live known-item-tag union from `EquipmentBaseDefinition.normalized_generation_tags()`, validates every explicit catalog tag against it, validates every base implicit against an implicit definition, and checks that every ordinary-enabled rarity pattern can fill each declared kind from at least one live base at some item level in `1..1000`. During Increment 1, only the explicitly authored `forge_vanguard_sword` implicit is required; bases with an empty `implicit_affix_ids` array remain valid until Increment 3.

- [ ] **Step 3: Add bounded deterministic distribution tests**

Generate fixed batches of 5,000 selections without issuing/placing items. Assert exact replay hashes and broad directional invariants:

```gdscript
TestAssertions.truthy(high_level_average_tier > low_level_average_tier, "high item level trends upward", failures)
TestAssertions.truthy(high_charisma_rare_family_rate > zero_charisma_rare_family_rate, "Charisma improves rare-family rate", failures)
TestAssertions.truthy(charisma_1000_gain < charisma_100_gain * 2.0, "Charisma gains diminish", failures)
TestAssertions.truthy(melee_party_melee_base_rate > neutral_melee_base_rate, "party bias increases matching bases", failures)
TestAssertions.truthy(melee_party_off_archetype_count > 0, "party bias preserves off-party drops", failures)
```

Also assert every generated rarity/pattern/affix/tier passes all hard gates. Do not assert one random item must be strong.

- [ ] **Step 4: Run focused and complete verification**

```powershell
& $godot --headless --path . --import
& $godot --headless --path . --quit-after 240 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_item_generation_request.gd tests/unit/test_item_base_and_rarity_selection.gd tests/unit/test_item_affix_assembler.gd tests/unit/test_item_generation_service.gd tests/unit/test_item_generation_distribution.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_instance_codec.gd tests/unit/test_game_catalog.gd
& $godot --headless --path . --quit-after 420 --script res://tests/test_runner.gd
& $godot --headless --path . --quit-after 10
```

Required evidence:

- Import exit 0 and no `SCRIPT ERROR`, `Parse Error`, `No loader found`, or failed-resource line.
- Focused runner prints exactly `TEST_SUMMARY: PASS (0 failures)`.
- Full runner prints exactly one `TEST_SUMMARY: PASS (<count> suites)` and no `TEST_FAILURE`.
- Startup prints `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY`.
- Known intentional error-path logs may appear only when their enclosing tests pass.

- [ ] **Step 5: Write the verification record and inspect repository scope**

Record exact commit IDs, commands, durations, summary markers, suite counts, and any known shutdown warnings in `docs/verification/2026-08-08-weighted-loot-definitions-and-generator.md`. Run:

```powershell
git diff --check
git status --short
git diff --stat main...HEAD
```

Confirm no profile data, user save data, imported `.godot` cache, or generated `.gd.uid` sidecar is staged.

- [ ] **Step 6: Commit final validation and documentation**

```powershell
git add scripts/data/game_catalog.gd scripts/items/item_foundation_catalog.gd tests/unit/test_game_catalog.gd tests/unit/test_item_generation_distribution.gd docs/verification/2026-08-08-weighted-loot-definitions-and-generator.md
git commit -m "test: verify deterministic weighted loot generation"
```

Expected deliverable: Increment 1 is independently testable and reviewable. It provides deterministic immutable generation foundations while leaving equipment-stat application, production-scale affix content, Loot Lab UI, and production drop integration to their separately approved increments.
