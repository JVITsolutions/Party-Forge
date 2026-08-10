# Weighted Loot Production Content and Weapon Damage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver weighted-loot Increment 3 with exactly 96 explicit affixes, 99 unique base implicits, twelve-tier progression, immutable typed weapon ranges, schema-1 migration, weapon-aware combat estimates, shared tooltip presentation, and deterministic balance evidence.

**Architecture:** Typed source rows and a deterministic Godot builder generate all production affix resources, implicit assignments, weapon profiles, and catalog registration. Issued schema-2 items own exact base-damage rolls; active equipment projects one immutable main-hand weapon snapshot alongside the existing equipment stat source, and a shared action-component projector feeds both runtime damage and UI estimates. Existing ownership, profile, extraction, and UI surfaces consume the expanded item contract without gaining a second item or stat identity.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot `.tres` Resources, JSON-safe immutable item documents, the existing item/equipment/stat/combat/UI services, PowerShell, Git worktrees, and the custom headless test runners.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\weighted-loot-production-content` on `feat/weighted-loot-production-content`.
- Preserve unrelated user files and all 135 pre-existing untracked `.gd.uid` files; never stage them as a batch.
- Do not author `.gd.uid` text manually. Inventory sidecars before and after Godot runs and stage only a sidecar proven necessary for a newly added script.
- Keep exactly 96 explicit affixes: 64 focused, 24 standard hybrids, 8 premium hybrids; keep exactly 48 prefixes and 48 suffixes.
- Keep exactly 99 distinct base-specific implicit IDs and display names, with exactly twelve tiers per production explicit and implicit.
- Preserve `stout`, `keen`, `wise`, `of_embers`, `of_rime`, `of_reach`, and `tempered_edge`; the first six retain their historical affix kinds so schema-1 records remain valid.
- Use shared minimum item levels `[1, 10, 30, 60, 100, 160, 240, 340, 460, 600, 770, 950]` and tier weights `[1000, 800, 640, 500, 380, 280, 200, 140, 90, 55, 30, 15]`.
- Enforce rarity ceilings Common T3, Uncommon T5, Rare T8, Epic T10, Legendary T12; a ceiling never guarantees its highest tier.
- Use affix weight bands 1000 core focused, 500 specialized focused, 150 standard hybrid, and 25 premium hybrid.
- Scale standard-hybrid components to 70% and premium-hybrid components to 85% of their focused curves.
- Use weapon rarity multipliers Common 1.00, Uncommon 1.08, Rare 1.18, Epic 1.32, Legendary 1.50.
- Never reroll or recalculate an issued item from current catalog data. Schema-1 items migrate with empty base-damage components and retain authored action fallback.
- Keep enemy drops, pickup presentation, Loot Lab, crafting, upper-rarity acquisition, conditional effects, dual-wield damage selection, and the Character Ledger Equipment & Inventory page outside this increment.
- Before each commit, run the task's focused tests and `git diff --check`; stage only the paths named by that task.

---

## File map

### Item and weapon definitions

- Create `scripts/items/item_base_damage_component.gd`: immutable issued typed range value.
- Create `scripts/items/weapon_damage_component_curve.gd`: one damage-type level curve.
- Create `scripts/items/weapon_damage_profile.gd`: validated profile, rarity multipliers, and quality bounds.
- Create `scripts/items/weapon_base_damage_roll_result.gd`: pure roller result or stable failure.
- Create `scripts/items/weapon_base_damage_roller.gd`: named-substream deterministic range generation.
- Modify `scripts/items/item_instance.gd`, `item_instance_codec.gd`, `item_instance_issuer.gd`, and `item_generation_service.gd`: schema 2 and `base_damage` generation stage.
- Modify `scripts/equipment/equipment_base_definition.gd`: optional damage profile link.

### Deterministic content

- Create `tools/weighted_loot_content_rows.gd`: sole authoring source for explicit rows, implicit templates, base assignments, and weapon-profile rows.
- Create `tools/build_weighted_loot_content.gd`: deterministic `.tres` and catalog writer.
- Rewrite the six retained explicit resources under `data/items/affixes/fixtures/`; generate the other 58 focused resources under `data/items/affixes/production/focused/`, 24 under `standard_hybrid/`, 8 under `premium_hybrid/`, and 98 new implicits under `implicits/` while retaining `fixtures/tempered_edge.tres`.
- Generate `data/items/weapon_profiles/*.tres`.
- Modify `data/items/core_item_foundation_catalog.tres` and all 99 `data/equipment/bases/**/*.tres` assignment fields.
- Modify `scripts/items/item_foundation_catalog.gd` and `scripts/equipment/equipment_catalog.gd`: exact production invariants and profile validation.

### Equipment and combat

- Create `scripts/equipment/active_weapon_damage_snapshot.gd`: immutable member/item/base/range/revision snapshot.
- Create `scripts/equipment/active_weapon_damage_resolver.gd`: resolves only the active main-hand item.
- Extend `equipment_activation_result.gd`, `equipment_activation_resolver.gd`, `equipment_transition_result.gd`, `equipment_transition_service.gd`, `player_run_context.gd`, and `party_manager.gd`: atomic source-plus-weapon publication.
- Create `scripts/combat/action_damage_component_projection.gd`: selects authored fallback or active weapon components and applies effectiveness.
- Modify `scripts/data/attack_definition.gd`, `damage_resolver.gd`, `combatant_adapter.gd`, `combat_modifiers.gd`, `candidate_action_validation_service.gd`, `action_combat_estimate_service.gd`, and five playable attack resources.

### Presentation, reports, and evidence

- Modify shared item presentation, tooltip, comparison, Armoury, Warehouse, and Developer Sandbox projections.
- Create `scripts/items/item_generation_balance_report.gd` and `tools/export_weighted_loot_balance_report.gd`.
- Generate `docs/validation/evidence/2026-08-10-weighted-loot-production-balance.json` and `.md`.
- Create `tests/integration/weighted_loot_production_runner.gd` and `docs/verification/2026-08-10-weighted-loot-production-content-and-weapon-damage.md`.

---

### Task 1: Add immutable base-damage values and schema-1-to-schema-2 migration

**Files:**
- Create: `scripts/items/item_base_damage_component.gd`
- Modify: `scripts/items/item_instance.gd`
- Modify: `scripts/items/item_instance_codec.gd`
- Modify: `scripts/items/item_instance_issuer.gd`
- Modify: `tests/unit/test_item_instance_codec.gd`
- Modify: `tests/unit/test_profile_item_schema_migration.gd`
- Test: `tests/unit/test_item_base_damage_component.gd`
- Modify: `scripts/dev/developer_item_fixture_issuer.gd`
- Modify: `scripts/items/item_generation_service.gd`
- Modify: `tests/integration/equipment_attribute_application_runner.gd`
- Modify: `tests/integration/item_storage_performance_runner.gd`
- Modify: `tests/unit/test_developer_item_sandbox_state.gd`
- Modify: `tests/unit/test_equipment_assignment_service.gd`
- Modify: `tests/unit/test_equipment_transition_service.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_item_base_and_rarity_selection.gd`
- Modify: `tests/unit/test_item_foundation_manifest.gd`
- Modify: `tests/unit/test_item_generation_service.gd`
- Modify: `tests/unit/test_non_equipment_activation_refresh.gd`
- Modify: `tests/unit/test_player_run_context.gd`
- Modify: `tests/unit/test_run_context_registry.gd`
- Modify: `tests/unit/test_run_item_ownership.gd`
- Modify: `tests/unit/test_stats_ledger_page.gd`
- Modify: `docs/superpowers/plans/2026-08-10-weighted-loot-production-content-and-weapon-damage.md`

User-approved review resolution: keep the issuer's schema-2 exact-field contract strict and expand Task 1 scope to every live direct issuer caller and current-schema fixture builder, each of which must explicitly provide `base_damage_components: []` until generation supplies real values.

**Interfaces:**
- Produces: `ItemBaseDamageComponent.create(type_id: StringName, minimum: float, maximum: float) -> ItemBaseDamageComponent`.
- Produces: `ItemBaseDamageComponent.copy()`, `to_dictionary()`, and `validate(DamageTypeCatalog) -> String`.
- Produces: `ItemInstance.base_damage_components: Array[ItemBaseDamageComponent]` and `ItemInstance.SCHEMA_VERSION == 2`.
- Consumes: existing `ItemInstanceCodec`, `ItemRegistry`, `ProfileCodec`, and `ResumableRunItemCodec` call paths without adding a second migration layer.

- [ ] **Step 1: Write failing schema and value-object tests**

Add assertions that components copy defensively, serialize in sorted damage-type order, reject empty/unknown/duplicate types and nonfinite/negative/inverted values, and produce exact fields:

```gdscript
{
    "damage_type_id": "physical",
    "minimum_damage": 7.0,
    "maximum_damage": 11.0,
}
```

Add one literal schema-1 document with no `base_damage_components`; assert decode succeeds, returns in-memory schema 2 with an empty array, and re-encode includes the empty array. Add literal tier-1, tier-2, and tier-3 documents for each retained fixture ID and prove every historical minimum/maximum boundary remains accepted after production content generation. Add schema-2 round-trip and unsupported-schema-3 rejection. Assert a failed profile migration leaves original primary and backup bytes unchanged.

- [ ] **Step 2: Run the focused tests and verify RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_base_damage_component.gd tests/unit/test_item_instance_codec.gd tests/unit/test_profile_item_schema_migration.gd
```

Expected: non-zero exit because schema 2 and `ItemBaseDamageComponent` do not exist.

- [ ] **Step 3: Implement the value and version-aware codec**

Use this public shape:

```gdscript
class_name ItemBaseDamageComponent
extends RefCounted

var damage_type_id: StringName
var minimum_damage := 0.0
var maximum_damage := 0.0

static func create(type_id: StringName, minimum: float, maximum: float) -> ItemBaseDamageComponent:
    var result := ItemBaseDamageComponent.new()
    result.damage_type_id = type_id
    result.minimum_damage = minimum
    result.maximum_damage = maximum
    return result
```

Set `ItemInstance.SCHEMA_VERSION := 2`, add defensive copy/serialization, and make `ItemInstanceCodec._validate_document()` branch on schema before exact-field validation. Schema 1 expects the old seven fields; schema 2 expects those fields plus `base_damage_components`. Decode schema 1 directly into a schema-2 instance with an empty component array. Extend `ItemInstanceIssuer.ITEM_DATA_FIELDS` and generated issue documents with the array. Pass `GameCatalog.DAMAGE_TYPES` to component validation; never consult a live weapon profile while decoding.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Step 2 command.

Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Commit the schema increment**

```powershell
git add scripts/items/item_base_damage_component.gd scripts/items/item_instance.gd scripts/items/item_instance_codec.gd scripts/items/item_instance_issuer.gd scripts/dev/developer_item_fixture_issuer.gd scripts/items/item_generation_service.gd tests/integration/equipment_attribute_application_runner.gd tests/integration/item_storage_performance_runner.gd tests/unit/test_item_base_damage_component.gd tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_equipment_assignment_service.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_game_catalog.gd tests/unit/test_item_base_and_rarity_selection.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_item_generation_service.gd tests/unit/test_item_instance_codec.gd tests/unit/test_non_equipment_activation_refresh.gd tests/unit/test_player_run_context.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_run_context_registry.gd tests/unit/test_run_item_ownership.gd tests/unit/test_stats_ledger_page.gd docs/superpowers/plans/2026-08-10-weighted-loot-production-content-and-weapon-damage.md
git diff --cached --check
git commit -m "feat: add immutable weapon damage item data"
```

---

### Task 2: Define and validate weapon-damage profiles

**Files:**
- Create: `scripts/items/weapon_damage_component_curve.gd`
- Create: `scripts/items/weapon_damage_profile.gd`
- Modify: `scripts/equipment/equipment_base_definition.gd`
- Modify: `scripts/equipment/equipment_catalog.gd`
- Test: `tests/unit/test_weapon_damage_profile.gd`
- Modify: `tests/unit/test_equipment_contract.gd`

**Interfaces:**
- Produces: `WeaponDamageComponentCurve.range_at(item_level: int) -> Vector2`.
- Produces: `WeaponDamageProfile.rarity_multiplier(rarity_id: StringName) -> float`.
- Produces: `WeaponDamageProfile.validate(DamageTypeCatalog) -> PackedStringArray`.
- Produces: optional `EquipmentBaseDefinition.weapon_damage_profile: WeaponDamageProfile`.

- [ ] **Step 1: Write failing curve/profile/catalog tests**

Cover exact interpolation at item levels 1, 500, 1000; finite monotonic anchors; duplicate damage types; quality bounds `0.85..1.00`; exact rarity map; support bases with null profiles; and explicit rejection when an authored profile is malformed. Use an in-test catalog containing eleven damage bases and seven support bases to prove the validation policy; Task 6 repeats those assertions against production resources.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_weapon_damage_profile.gd tests/unit/test_equipment_contract.gd
```

Expected: non-zero exit because profile types and the base link do not exist.

- [ ] **Step 3: Implement profile contracts**

Use exact exported data:

```gdscript
class_name WeaponDamageComponentCurve
extends Resource

@export var damage_type_id: StringName
@export var minimum_at_level_1 := 0.0
@export var maximum_at_level_1 := 0.0
@export var minimum_at_level_1000 := 0.0
@export var maximum_at_level_1000 := 0.0

func range_at(item_level: int) -> Vector2:
    var progress := clampf(float(item_level - 1) / 999.0, 0.0, 1.0)
    return Vector2(
        lerpf(minimum_at_level_1, minimum_at_level_1000, progress),
        lerpf(maximum_at_level_1, maximum_at_level_1000, progress),
    )
```

```gdscript
class_name WeaponDamageProfile
extends Resource

const RARITY_MULTIPLIERS := {
    &"common": 1.00, &"uncommon": 1.08, &"rare": 1.18,
    &"epic": 1.32, &"legendary": 1.50,
}

@export var id: StringName
@export_range(1, 1000, 1) var minimum_item_level := 1
@export var quality_minimum := 0.85
@export var quality_maximum := 1.00
@export var components: Array[WeaponDamageComponentCurve] = []
```

`EquipmentCatalog.validate()` passes `GameCatalog.DAMAGE_TYPES` into base/profile validation and prefixes failures with base/profile IDs. Do not infer damage-bearing status from `weight_class_id` or `weapon_family_id`; only a non-null explicit profile creates base damage.

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 5: Commit profile definitions**

```powershell
git add scripts/items/weapon_damage_component_curve.gd scripts/items/weapon_damage_profile.gd scripts/equipment/equipment_base_definition.gd scripts/equipment/equipment_catalog.gd tests/unit/test_weapon_damage_profile.gd tests/unit/test_equipment_contract.gd
git diff --cached --check
git commit -m "feat: define typed weapon damage profiles"
```

---

### Task 3: Roll base damage in an independent deterministic generation stage

**Files:**
- Create: `scripts/items/weapon_base_damage_roll_result.gd`
- Create: `scripts/items/weapon_base_damage_roller.gd`
- Modify: `scripts/items/item_generation_trace.gd`
- Modify: `scripts/items/item_generation_service.gd`
- Modify: `scripts/items/item_instance_issuer.gd`
- Test: `tests/unit/test_weapon_base_damage_roller.gd`
- Modify: `tests/unit/test_item_generation_service.gd`

**Interfaces:**
- Produces: `WeaponBaseDamageRollResult.components`, `.quality_by_type`, `.provenance`, `.error`, and `.ok()`.
- Produces: `WeaponBaseDamageRoller.roll(request, base, rarity, trace) -> WeaponBaseDamageRollResult`.
- Changes: `ItemGenerationTrace.record(stage, eligible, rejected, weights, selected, details = {})` with canonical JSON-safe details.
- Changes: `ItemGenerationService.GENERATOR_VERSION` from 1 to 2.

- [ ] **Step 1: Write failing deterministic-stage tests**

Assert fixed seed/sequence output, exact rarity multiplication, non-damage base empty success, hybrid component sorting, base-damage trace details, and stable `PARTY_FORGE_ITEM_GENERATION_ERROR stage=base_damage` failures. Generate the same request before and after inserting a damage profile and prove base/rarity/pattern/affix/tier/roll selections do not shift; only the new named stage and issued components differ.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_weapon_base_damage_roller.gd tests/unit/test_item_generation_service.gd
```

Expected: non-zero exit for missing roller and missing schema-2 issuance data.

- [ ] **Step 3: Implement the pure roller and orchestration order**

For each sorted curve, calculate:

```gdscript
var bounds := curve.range_at(request.item_level)
var unit := ItemDeterministicRandom.unit(
    request.seed,
    request.generation_sequence,
    StringName("base_damage:%s" % curve.damage_type_id),
    0,
)
var quality := lerpf(profile.quality_minimum, profile.quality_maximum, unit)
var rarity_scale := profile.rarity_multiplier(rarity.id)
var minimum := snappedf(bounds.x * quality * rarity_scale, 0.01)
var maximum := snappedf(bounds.y * quality * rarity_scale, 0.01)
```

Record one `base_damage` trace row containing profile ID, item level, rarity multiplier, per-type bounds, unit, quality, and final range. Put the same canonical data in `WeaponBaseDamageRollResult.provenance`, then store it under `origin.source.generation.base_damage` so advanced tooltips can explain issued values without consulting current profile balance. In `ItemGenerationService.generate()`, call the roller after rarity and before pattern. Pass component dictionaries to `ItemInstanceIssuer.issue()`. Return failure before affix assembly or issuance if the profile rejects the request.

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 5: Commit deterministic base-damage generation**

```powershell
git add scripts/items/weapon_base_damage_roll_result.gd scripts/items/weapon_base_damage_roller.gd scripts/items/item_generation_trace.gd scripts/items/item_generation_service.gd scripts/items/item_instance_issuer.gd tests/unit/test_weapon_base_damage_roller.gd tests/unit/test_item_generation_service.gd
git diff --cached --check
git commit -m "feat: roll deterministic weapon base damage"
```

---

### Task 4: Author the exact 96-explicit-affix source manifest

**Files:**
- Create: `tools/weighted_loot_content_rows.gd`
- Test: `tests/unit/test_weighted_loot_content_rows.gd`

**Interfaces:**
- Produces: `WeightedLootContentRows.explicit_rows() -> Array[Dictionary]`.
- Produces: `WeightedLootContentRows.tier_rows(curve_key, component_scale) -> Array[Dictionary]`.
- Produces: exact category, side, family, hard eligibility tag, soft affinity tag, operation, curve, and weight metadata consumed by Task 5.

- [ ] **Step 1: Write failing source-manifest tests**

Assert exact totals `96/64/24/8/48/48`, unique nonempty IDs/names, six retained fixture IDs and kinds, weight bands, two effects per hybrid, 70%/85% scaling, known stats/operations/tags, nonempty conflict families, exact thresholds/weights, and twelve monotonic tiers.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_weighted_loot_content_rows.gd
```

Expected: non-zero exit because the source manifest does not exist.

- [ ] **Step 3: Implement exact focused IDs and legacy exceptions**

Use these exact focused prefix IDs:

```gdscript
const FOCUSED_PREFIX_IDS := [
    &"stout", &"keen", &"wise",
    &"forceful", &"brutal", &"deadeye", &"arcane", &"tempered",
    &"searing", &"glacial", &"stormcharged", &"profane",
    &"vital", &"robust", &"plated", &"reinforced", &"benevolent", &"commanding",
    &"potent_weapon", &"duelist", &"farshot", &"spellwoven", &"martial_edge",
    &"pyromantic", &"cryomantic", &"tempestuous", &"voidtouched",
    &"juggernaut", &"ironclad", &"towerborn", &"merciful", &"inspiring",
]
```

Use these exact focused suffix IDs:

```gdscript
const FOCUSED_SUFFIX_IDS := [
    &"of_embers", &"of_rime", &"of_reach",
    &"of_might", &"of_agility", &"of_endurance", &"of_intellect", &"of_insight", &"of_presence",
    &"of_fire_ward", &"of_cold_ward", &"of_lightning_ward", &"of_chaos_ward",
    &"of_precision", &"of_ferocity", &"of_alacrity", &"of_recovery",
    &"of_velocity", &"of_expansion", &"of_the_wind", &"of_gathering",
    &"of_evasion", &"of_guarding", &"of_deflection", &"of_vigor", &"of_drain",
    &"of_the_duelist", &"of_the_marksman", &"of_the_savant", &"of_the_healer",
    &"of_martial_haste", &"of_arcane_focus",
]
```

The three retained prefixes and three retained suffixes are explicit semantic exceptions. All new attribute affixes are suffixes and all new direct damage-magnitude affixes are prefixes. Reuse the retained IDs' current player-facing names.

- [ ] **Step 4: Implement exact hybrid IDs and curve policy**

```gdscript
const STANDARD_PREFIX_IDS := [
    &"battle_hardened", &"hunter_born", &"spell_forged", &"elemental_fury",
    &"stormfire", &"winter_storm", &"voidflame", &"unyielding_force",
    &"bloodbound", &"sacred_guard", &"fortified_vitality", &"commanding_presence",
]
const STANDARD_SUFFIX_IDS := [
    &"of_swiftness", &"of_deadly_precision", &"of_guarded_resolve", &"of_restoration",
    &"of_exploration", &"of_the_pyromancer", &"of_the_cryomancer", &"of_the_stormcaller",
    &"of_the_occultist", &"of_balanced_form", &"of_martial_mastery", &"of_arcane_mastery",
]
const PREMIUM_PREFIX_IDS := [
    &"apex_force", &"eternal_bulwark", &"primal_convergence", &"sovereign_magic",
]
const PREMIUM_SUFFIX_IDS := [
    &"of_perfect_form", &"of_inexorable_time", &"of_boundless_reach", &"of_royal_command",
]
```

Use this exact focused effect matrix. Each tuple is `[id, stat_id, operation, required_item_tag]`; an empty tag means broad eligibility. Generate the modifier family from `stat_id` plus the operation category, so every specialized duplicate conflicts with its broad equivalent.

```gdscript
const FOCUSED_PREFIX_EFFECTS := [
    [&"stout", &"constitution", StatModifier.Operation.FLAT, &""],
    [&"keen", &"dexterity", StatModifier.Operation.FLAT, &""],
    [&"wise", &"wisdom", StatModifier.Operation.FLAT, &""],
    [&"forceful", &"damage", StatModifier.Operation.INCREASED, &""],
    [&"brutal", &"melee_damage", StatModifier.Operation.INCREASED, &""],
    [&"deadeye", &"ranged_damage", StatModifier.Operation.INCREASED, &""],
    [&"arcane", &"caster_damage", StatModifier.Operation.INCREASED, &""],
    [&"tempered", &"physical_damage", StatModifier.Operation.INCREASED, &""],
    [&"searing", &"fire_damage", StatModifier.Operation.INCREASED, &""],
    [&"glacial", &"cold_damage", StatModifier.Operation.INCREASED, &""],
    [&"stormcharged", &"lightning_damage", StatModifier.Operation.INCREASED, &""],
    [&"profane", &"chaos_damage", StatModifier.Operation.INCREASED, &""],
    [&"vital", &"max_health", StatModifier.Operation.FLAT, &""],
    [&"robust", &"max_health", StatModifier.Operation.INCREASED, &""],
    [&"plated", &"armor", StatModifier.Operation.FLAT, &""],
    [&"reinforced", &"armor", StatModifier.Operation.INCREASED, &""],
    [&"benevolent", &"healing_power", StatModifier.Operation.INCREASED, &""],
    [&"commanding", &"party_influence", StatModifier.Operation.FLAT, &""],
    [&"potent_weapon", &"damage", StatModifier.Operation.INCREASED, &"weapon"],
    [&"duelist", &"melee_damage", StatModifier.Operation.INCREASED, &"one_hand_sword"],
    [&"farshot", &"ranged_damage", StatModifier.Operation.INCREASED, &"bow"],
    [&"spellwoven", &"caster_damage", StatModifier.Operation.INCREASED, &"caster"],
    [&"martial_edge", &"physical_damage", StatModifier.Operation.INCREASED, &"melee"],
    [&"pyromantic", &"fire_damage", StatModifier.Operation.INCREASED, &"caster"],
    [&"cryomantic", &"cold_damage", StatModifier.Operation.INCREASED, &"caster"],
    [&"tempestuous", &"lightning_damage", StatModifier.Operation.INCREASED, &"caster"],
    [&"voidtouched", &"chaos_damage", StatModifier.Operation.INCREASED, &"caster"],
    [&"juggernaut", &"max_health", StatModifier.Operation.FLAT, &"heavy"],
    [&"ironclad", &"armor", StatModifier.Operation.FLAT, &"heavy"],
    [&"towerborn", &"armor", StatModifier.Operation.INCREASED, &"shield"],
    [&"merciful", &"healing_power", StatModifier.Operation.INCREASED, &"tome"],
    [&"inspiring", &"party_influence", StatModifier.Operation.FLAT, &"accessory"],
]

const FOCUSED_SUFFIX_EFFECTS := [
    [&"of_embers", &"fire_damage", StatModifier.Operation.INCREASED, &""],
    [&"of_rime", &"cold_damage", StatModifier.Operation.INCREASED, &""],
    [&"of_reach", &"attack_range", StatModifier.Operation.INCREASED, &""],
    [&"of_might", &"strength", StatModifier.Operation.FLAT, &""],
    [&"of_agility", &"dexterity", StatModifier.Operation.FLAT, &""],
    [&"of_endurance", &"constitution", StatModifier.Operation.FLAT, &""],
    [&"of_intellect", &"intelligence", StatModifier.Operation.FLAT, &""],
    [&"of_insight", &"wisdom", StatModifier.Operation.FLAT, &""],
    [&"of_presence", &"charisma", StatModifier.Operation.FLAT, &""],
    [&"of_fire_ward", &"fire_resistance", StatModifier.Operation.FLAT, &""],
    [&"of_cold_ward", &"cold_resistance", StatModifier.Operation.FLAT, &""],
    [&"of_lightning_ward", &"lightning_resistance", StatModifier.Operation.FLAT, &""],
    [&"of_chaos_ward", &"chaos_resistance", StatModifier.Operation.FLAT, &""],
    [&"of_precision", &"crit_chance", StatModifier.Operation.FLAT, &""],
    [&"of_ferocity", &"crit_multiplier", StatModifier.Operation.FLAT, &""],
    [&"of_alacrity", &"attack_speed", StatModifier.Operation.INCREASED, &""],
    [&"of_recovery", &"cooldown_rate", StatModifier.Operation.INCREASED, &""],
    [&"of_velocity", &"projectile_speed", StatModifier.Operation.INCREASED, &""],
    [&"of_expansion", &"area_size", StatModifier.Operation.INCREASED, &""],
    [&"of_the_wind", &"move_speed", StatModifier.Operation.INCREASED, &""],
    [&"of_gathering", &"pickup_radius", StatModifier.Operation.INCREASED, &""],
    [&"of_evasion", &"dodge_chance", StatModifier.Operation.FLAT, &""],
    [&"of_guarding", &"block_chance", StatModifier.Operation.FLAT, &""],
    [&"of_deflection", &"block_effectiveness", StatModifier.Operation.FLAT, &""],
    [&"of_vigor", &"health_regeneration", StatModifier.Operation.FLAT, &""],
    [&"of_drain", &"life_steal", StatModifier.Operation.FLAT, &""],
    [&"of_the_duelist", &"strength", StatModifier.Operation.FLAT, &"one_hand_sword"],
    [&"of_the_marksman", &"dexterity", StatModifier.Operation.FLAT, &"bow"],
    [&"of_the_savant", &"intelligence", StatModifier.Operation.FLAT, &"caster"],
    [&"of_the_healer", &"wisdom", StatModifier.Operation.FLAT, &"tome"],
    [&"of_martial_haste", &"attack_speed", StatModifier.Operation.INCREASED, &"melee"],
    [&"of_arcane_focus", &"cooldown_rate", StatModifier.Operation.INCREASED, &"caster"],
]
```

Use these exact two-effect hybrid mappings:

```gdscript
const HYBRID_EFFECTS := {
    &"battle_hardened": [&"melee_damage", &"armor"],
    &"hunter_born": [&"ranged_damage", &"attack_range"],
    &"spell_forged": [&"caster_damage", &"area_size"],
    &"elemental_fury": [&"fire_damage", &"cold_damage"],
    &"stormfire": [&"fire_damage", &"lightning_damage"],
    &"winter_storm": [&"cold_damage", &"lightning_damage"],
    &"voidflame": [&"chaos_damage", &"fire_damage"],
    &"unyielding_force": [&"damage", &"max_health"],
    &"bloodbound": [&"damage", &"life_steal"],
    &"sacred_guard": [&"healing_power", &"armor"],
    &"fortified_vitality": [&"max_health", &"armor"],
    &"commanding_presence": [&"damage", &"party_influence"],
    &"of_swiftness": [&"attack_speed", &"move_speed"],
    &"of_deadly_precision": [&"crit_chance", &"crit_multiplier"],
    &"of_guarded_resolve": [&"block_chance", &"block_effectiveness"],
    &"of_restoration": [&"health_regeneration", &"cooldown_rate"],
    &"of_exploration": [&"move_speed", &"pickup_radius"],
    &"of_the_pyromancer": [&"fire_damage", &"fire_resistance"],
    &"of_the_cryomancer": [&"cold_damage", &"cold_resistance"],
    &"of_the_stormcaller": [&"lightning_damage", &"lightning_resistance"],
    &"of_the_occultist": [&"chaos_damage", &"chaos_resistance"],
    &"of_balanced_form": [&"dodge_chance", &"block_chance"],
    &"of_martial_mastery": [&"strength", &"dexterity"],
    &"of_arcane_mastery": [&"intelligence", &"wisdom"],
    &"apex_force": [&"damage", &"crit_multiplier"],
    &"eternal_bulwark": [&"max_health", &"armor"],
    &"primal_convergence": [&"physical_damage", &"attack_speed"],
    &"sovereign_magic": [&"caster_damage", &"healing_power"],
    &"of_perfect_form": [&"dodge_chance", &"move_speed"],
    &"of_inexorable_time": [&"attack_speed", &"cooldown_rate"],
    &"of_boundless_reach": [&"attack_range", &"area_size"],
    &"of_royal_command": [&"charisma", &"party_influence"],
}
```

Infer each hybrid effect's operation from the focused mapping: attributes, health, armor, regeneration, party influence, resistances, critical stats, dodge, block, block effectiveness, and life steal are `FLAT`; the remaining stats are `INCREASED`.

Use exact curve endpoints:

```gdscript
const CURVE_ENDPOINTS := {
    &"flat_attribute": [Vector2(1.0, 3.0), Vector2(70.0, 90.0), 1.0],
    &"flat_health": [Vector2(5.0, 10.0), Vector2(400.0, 550.0), 0.01],
    &"flat_armor": [Vector2(2.0, 4.0), Vector2(200.0, 280.0), 0.01],
    &"flat_party_influence": [Vector2(1.0, 2.0), Vector2(60.0, 80.0), 1.0],
    &"flat_regeneration": [Vector2(0.5, 1.0), Vector2(25.0, 35.0), 0.01],
    &"flat_ratio": [Vector2(0.01, 0.02), Vector2(0.18, 0.25), 0.001],
    &"flat_crit_multiplier": [Vector2(0.05, 0.10), Vector2(0.80, 1.20), 0.001],
    &"increased_multiplier": [Vector2(0.04, 0.08), Vector2(0.75, 1.00), 0.001],
}
```

Select curves by stat/operation: core attributes use `flat_attribute`; flat maximum health uses `flat_health`; flat armor uses `flat_armor`; party influence uses `flat_party_influence`; health regeneration uses `flat_regeneration`; critical multiplier uses `flat_crit_multiplier`; other flat ratios use `flat_ratio`; every increased effect uses `increased_multiplier`. Family IDs are based on semantic stat plus operation category, so pure/hybrid equivalents block each other. Generate tier values by exponent-interpolating each curve's level-1 and level-1000 endpoints with exponent `1.20`, then snap by the third endpoint value. Apply `0.70` or `0.85` before snapping for hybrids.

Override the generated first three ranges for retained IDs with these exact historical bounds; tiers 4-12 continue monotonically from the tier-3 maximum toward the curve's level-1000 endpoint:

```gdscript
const LEGACY_TIER_BOUNDS := {
    &"stout": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
    &"keen": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
    &"wise": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
    &"of_embers": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
    &"of_rime": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
    &"of_reach": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
    &"tempered_edge": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
}
```

Derive new display names deterministically: prefix IDs become underscore-replaced title case; suffix IDs beginning `of_` become `of ` plus title case of the remainder. Retained IDs keep their current exact display names. Output paths are exact functions of category and ID: retained IDs stay under `data/items/affixes/fixtures/<id>.tres`; other rows use `data/items/affixes/production/<category>/<id>.tres`.

Derive soft affinity tags from effect stats using only the three live accessory-family tags. Melee damage, Strength, physical damage, armor, and block add `melee`; ranged damage, Dexterity, attack range, projectile speed, movement, and dodge add `ranged`; caster damage, Intelligence, Wisdom, healing, area, cooldown, and elemental/chaos damage or resistance add `caster`. Global stats, Constitution, Charisma, critical stats, regeneration, life steal, and pickup radius add no affinity. Affinity affects only accessory weighting and never changes eligibility.

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 6: Commit the production source rows**

```powershell
git add tools/weighted_loot_content_rows.gd tests/unit/test_weighted_loot_content_rows.gd
git diff --cached --check
git commit -m "feat: author weighted loot affix source rows"
```

---

### Task 5: Add 99 unique implicit assignments and eleven weapon-profile rows

**Files:**
- Modify: `tools/weighted_loot_content_rows.gd`
- Modify: `tests/unit/test_weighted_loot_content_rows.gd`

**Interfaces:**
- Produces: `implicit_rows(EquipmentCatalog) -> Array[Dictionary]` with one row per live base.
- Produces: `weapon_profile_rows() -> Array[Dictionary]` with exactly eleven damage profiles.
- Produces: `support_base_ids() -> Array[StringName]` with exactly seven weapon-slot support bases.

- [ ] **Step 1: Extend failing manifest tests**

Assert 99 unique implicit IDs/names, exactly one assignment per base, `tempered_edge` only on `forge_vanguard_sword`, twelve shared tiers, and template coverage for every compatible slot. Assert eleven profile rows and seven explicit support IDs with no overlap. Assert every live base is classified as damage-profile, support, or non-weapon equipment.

- [ ] **Step 2: Run tests and verify RED**

Run Task 4 Step 2. Expected: non-zero exit for missing implicit/profile rows.

- [ ] **Step 3: Implement deterministic implicit identity and templates**

For every base except `forge_vanguard_sword`, derive `id = &"%s_implicit" % base.id` and `display_name = "%s Legacy" % base.display_name`; retain `tempered_edge` and `Tempered Edge` for the sword. Select the exact template below by compatible slot. Identity always remains base-specific.

```gdscript
const IMPLICIT_TEMPLATE_EFFECTS := {
    &"helmet": [&"max_health"],
    &"body_armour": [&"armor"],
    &"legs": [&"move_speed"],
    &"gloves": [&"attack_speed"],
    &"boots": [&"dodge_chance"],
    &"amulet": [&"party_influence"],
    &"ring_left": [&"crit_chance"],
    &"ring_right": [&"crit_chance"],
    &"belt": [&"health_regeneration"],
}
```

Main-hand implicit stat follows the explicit profile component: Physical, Fire, Cold, Lightning, or Chaos maps to its matching damage stat. Off-hand support maps shield to `block_chance`, quiver to `ranged_damage`, and focus/grimoire/tome to `caster_damage`. Use the same operation and curve-selection rules as Task 4. If a base has multiple compatible slots, use canonical priority `helmet, body_armour, legs, gloves, boots, amulet, ring_left, ring_right, belt, main_hand, off_hand`.

- [ ] **Step 4: Implement exact damage-profile rows**

```gdscript
const WEAPON_PROFILE_ROWS := [
    {"base": &"forge_vanguard_sword", "type": &"physical", "l1": Vector2(7, 11), "l1000": Vector2(260, 390)},
    {"base": &"forge_vanguard_hammer", "type": &"physical", "l1": Vector2(9, 14), "l1000": Vector2(310, 470)},
    {"base": &"sunforged_warhammer", "type": &"physical", "l1": Vector2(12, 18), "l1000": Vector2(380, 570)},
    {"base": &"greenwood_recurve_bow", "type": &"physical", "l1": Vector2(6, 10), "l1000": Vector2(240, 360)},
    {"base": &"siege_greatbow", "type": &"physical", "l1": Vector2(12, 20), "l1000": Vector2(400, 640)},
    {"base": &"nightstep_dagger_main", "type": &"physical", "l1": Vector2(5, 8), "l1000": Vector2(200, 320)},
    {"base": &"nightstep_dagger_off", "type": &"physical", "l1": Vector2(4, 7), "l1000": Vector2(180, 290)},
    {"base": &"emberweave_wand", "type": &"fire", "l1": Vector2(7, 11), "l1000": Vector2(270, 420)},
    {"base": &"grave_covenant_bone_wand", "type": &"chaos", "l1": Vector2(7, 11), "l1000": Vector2(270, 420)},
    {"base": &"rime_scholar_staff", "type": &"cold", "l1": Vector2(10, 16), "l1000": Vector2(350, 540)},
    {"base": &"storm_chaplain_sceptre", "type": &"lightning", "l1": Vector2(8, 13), "l1000": Vector2(300, 470)},
]
const SUPPORT_BASE_IDS := [
    &"dawn_bulwark_shield", &"forge_vanguard_shield", &"greenwood_light_quiver",
    &"siege_heavy_quiver", &"emberweave_flame_focus", &"grave_covenant_grimoire",
    &"storm_chaplain_holy_tome",
]
```

Every profile uses quality bounds `0.85..1.00` and the shared rarity map. The off-hand dagger gets item data and tooltip ranges but does not enter runtime action selection before the future dual-wield design.

Derive each profile ID as `weapon_profile_<base_id>` and its output path as `data/items/weapon_profiles/<base_id>.tres`.

- [ ] **Step 5: Run tests and verify GREEN**

Run Task 4 Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 6: Commit implicit and weapon rows**

```powershell
git add tools/weighted_loot_content_rows.gd tests/unit/test_weighted_loot_content_rows.gd
git diff --cached --check
git commit -m "feat: author implicit and weapon profile rows"
```

---

### Task 6: Generate production resources and enforce byte-identical parity

**Files:**
- Create: `tools/build_weighted_loot_content.gd`
- Modify: `data/items/affixes/fixtures/stout.tres`
- Modify: `data/items/affixes/fixtures/keen.tres`
- Modify: `data/items/affixes/fixtures/wise.tres`
- Modify: `data/items/affixes/fixtures/of_embers.tres`
- Modify: `data/items/affixes/fixtures/of_rime.tres`
- Modify: `data/items/affixes/fixtures/of_reach.tres`
- Modify: `data/items/affixes/fixtures/tempered_edge.tres`
- Generate: `data/items/affixes/production/focused/*.tres` (58 files; all focused IDs except the six retained explicit fixtures)
- Generate: `data/items/affixes/production/standard_hybrid/*.tres`
- Generate: `data/items/affixes/production/premium_hybrid/*.tres`
- Generate: `data/items/affixes/production/implicits/*.tres`
- Generate: `data/items/weapon_profiles/*.tres`
- Modify: `data/items/core_item_foundation_catalog.tres`
- Modify: `data/equipment/bases/**/*.tres`
- Modify: `scripts/items/item_foundation_catalog.gd`
- Modify: `scripts/items/item_affix_definition.gd`
- Modify: `scripts/items/item_generation_weight_policy.gd`
- Modify: `scripts/items/item_affix_assembler.gd`
- Modify: `scripts/equipment/equipment_catalog.gd`
- Modify: `tests/unit/test_item_foundation_catalog.gd`
- Modify: `tests/unit/test_item_foundation_manifest.gd`
- Modify: `tests/unit/test_item_affix_assembler.gd`
- Test: `tests/unit/test_weighted_loot_builder_parity.gd`

**Interfaces:**
- Produces: `BuildWeightedLootContent.build_document_set(equipment, stats, damage_types) -> Dictionary` keyed by canonical `res://` path.
- Produces: exact production catalog registration and base assignment.
- Produces: `ItemGenerationWeightPolicy.affix_weight(affix, request, base_tags) -> float` with a `1.35` matching-affinity multiplier only when `accessory` is in `base_tags`.
- Consumes: Tasks 2, 4, and 5 typed rows.

- [ ] **Step 1: Write failing resource/count/parity tests**

Assert external resource paths, exact manifest counts, exact category/side counts, twelve tiers, one unique implicit per base, all 99 base references, profile links, rarity ceilings, known tags/families/affinities, reachability, and zero byte difference between generated canonical documents and checked-in resources. Add accessory selection tests showing a `1.35` matching-affinity multiplier, unchanged hard eligibility, and nonzero off-family weight.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_weighted_loot_builder_parity.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_game_catalog.gd
```

Expected: non-zero exit because generated production resources are absent.

- [ ] **Step 3: Implement deterministic builder and strict validation**

Sort every row, tag, family, effect, tier, base assignment, resource path, and catalog reference by stable ID before saving. Build resources in memory first and run all cross-catalog validators before any write. A validation failure prints one stable `PARTY_FORGE_WEIGHTED_CONTENT_BUILD_ERROR stage=<stage> id=<id> reason=<reason>` and saves nothing; an I/O failure reports the exact path and leaves Git diff inspection as the recovery boundary.

```gdscript
static func build_document_set(
    equipment: EquipmentCatalog,
    stats: StatCatalog,
    damage_types: DamageTypeCatalog,
) -> Dictionary:
    var documents: Dictionary = {}
    for row: Dictionary in WeightedLootContentRows.explicit_rows():
        documents[_affix_path(row)] = _affix_from_row(row)
    for row: Dictionary in WeightedLootContentRows.implicit_rows(equipment):
        documents[_affix_path(row)] = _affix_from_row(row)
    for row: Dictionary in WeightedLootContentRows.weapon_profile_rows():
        documents[_weapon_profile_path(row)] = _weapon_profile_from_row(row)
    return _canonical_documents(documents)
```

`ItemFoundationCatalog.validate()` must enforce exact production totals and accept the six documented legacy-side exceptions without weakening other kind checks. Rarity ceilings are encoded through each tier's `allowed_rarity_ids`:

```gdscript
T1..T3  -> common, uncommon, rare, epic, legendary
T4..T5  -> uncommon, rare, epic, legendary
T6..T8  -> rare, epic, legendary
T9..T10 -> epic, legendary
T11..T12 -> legendary
```

Add `@export var affinity_tags: Array[StringName] = []` to `ItemAffixDefinition` with sorted, unique, known-tag validation. `ItemAffixAssembler` passes the selected base's normalized tags to the weight policy. The policy applies the `1.35` multiplier only when the base is an accessory and affinity intersects; combat equipment continues using authored hard required/excluded tags. A nonmatching accessory candidate retains its original positive weight.

- [ ] **Step 4: Run the builder twice and prove byte parity**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git status --porcelain=v1 | Set-Content '.superpowers\sdd\weighted-loot-first-build.status'
& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git diff --check
```

Expected: both exits `0`; the second build changes zero tracked bytes relative to the first build.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 6: Commit generated production content deliberately**

Stage the builder, named test files, four production affix directories, weapon profiles, item definition/weight/assembler changes, foundation catalog, equipment catalog validator, and only the 99 intentionally rewritten base resources. Review `git diff --cached --name-status` before committing.

```powershell
git diff --cached --check
git commit -m "feat: generate production weighted loot content"
```

---

### Task 7: Resolve an immutable active main-hand weapon snapshot

**Files:**
- Create: `scripts/equipment/active_weapon_damage_snapshot.gd`
- Create: `scripts/equipment/active_weapon_damage_resolver.gd`
- Modify: `scripts/equipment/equipment_activation_result.gd`
- Modify: `scripts/equipment/equipment_activation_resolver.gd`
- Test: `tests/unit/test_active_weapon_damage_resolver.gd`
- Modify: `tests/unit/test_equipment_activation_resolver.gd`

**Interfaces:**
- Produces: `ActiveWeaponDamageSnapshot.create(member_id, item_id, base_id, components, revision)` and defensive `copy()`.
- Produces: `ActiveWeaponDamageResolver.resolve(member_id, container, state, active_ids, equipment, revision) -> Dictionary` shaped `{error, snapshot}`.
- Changes: `EquipmentActivationResult.success(active_ids: Array[String], disabled_reasons_by_item: Dictionary, raw: ResolvedStatSnapshot, equipment_source: StatModifierSource, weapon_snapshot: ActiveWeaponDamageSnapshot)` and `weapon_snapshot() -> ActiveWeaponDamageSnapshot`.

- [ ] **Step 1: Write failing active/disabled/main-hand tests**

Cover valid main hand, empty slot, schema-1 empty range, disabled main hand, support off hand, dual daggers selecting only main hand, malformed component data, defensive copies, and revision/member/item/base identity.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_active_weapon_damage_resolver.gd tests/unit/test_equipment_activation_resolver.gd
```

Expected: non-zero exit because active weapon snapshots do not exist.

- [ ] **Step 3: Implement resolver and activation composition**

Resolve `EquipmentSlotIndex.index_for(&"main_hand")`; return null success when the slot is empty, the item is inactive, or its component array is empty. Validate copied components against `GameCatalog.DAMAGE_TYPES`. `EquipmentActivationResolver.resolve()` must create the equipment stat source and weapon snapshot inside the same final pass; a weapon failure turns the complete activation into failure.

```gdscript
static func resolve(
    member_id: int,
    container: ItemSlotContainer,
    state: ItemOwnershipState,
    active_item_ids: Array[String],
    equipment: EquipmentCatalog,
    revision: int,
) -> Dictionary:
    var slot := EquipmentSlotIndex.index_for(&"main_hand")
    var item_id := container.item_id_at(slot) if slot >= 0 else ""
    if item_id.is_empty() or item_id not in active_item_ids:
        return {"error": "", "snapshot": null}
    return _snapshot_for_item(member_id, item_id, state, equipment, revision)
```

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 5: Commit weapon activation**

```powershell
git add scripts/equipment/active_weapon_damage_snapshot.gd scripts/equipment/active_weapon_damage_resolver.gd scripts/equipment/equipment_activation_result.gd scripts/equipment/equipment_activation_resolver.gd tests/unit/test_active_weapon_damage_resolver.gd tests/unit/test_equipment_activation_resolver.gd
git diff --cached --check
git commit -m "feat: resolve active weapon damage snapshots"
```

---

### Task 8: Publish equipment stats and weapon snapshots atomically

**Files:**
- Modify: `scripts/equipment/equipment_transition_result.gd`
- Modify: `scripts/equipment/equipment_transition_service.gd`
- Modify: `scripts/run/player_run_context.gd`
- Modify: `scripts/party/party_manager.gd`
- Modify: `tests/unit/test_equipment_transition_service.gd`
- Modify: `tests/unit/test_player_run_context.gd`
- Modify: `tests/unit/test_party_manager.gd`

**Interfaces:**
- Produces: `PartyManager.active_weapon_snapshot(member_id: int) -> ActiveWeaponDamageSnapshot`.
- Produces: `PartyManager.replace_member_equipment_projection_atomically(member_id, source, weapon, authority) -> bool`.
- Produces: `PartyManager.replace_member_equipment_projections_atomically(projections_by_member: Dictionary, authority) -> int` for resume/reconstruction.
- Changes: `PartyManager.replace_member_source_with_equipment_atomically(member_id, member_source, equipment_source, weapon, authority) -> bool`.
- Produces: atomic validation of equipment-source identity, weapon-snapshot identity, revision, and ownership before live state changes.

- [ ] **Step 1: Write failing transaction tests**

Assert successful equip/remove/replace/disable updates source and weapon with one revision and one `stats_changed` notification. Inject invalid source, weapon, ownership, revision, and authority; assert previous sources, snapshot, caches, health, activation map, state bytes, revision, and signals remain identical. Add 24-member isolation proving only the selected member changes.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_party_manager.gd
```

Expected: non-zero exit because PartyManager does not own weapon snapshots.

- [ ] **Step 3: Extend candidate and commit contracts**

Keep `_active_weapon_by_member` private. Every preview builds equipment activation with `candidate_revision = party.stat_revision() + 1`, which is the revision the one-member or multi-member invalidation will publish. `replace_member_equipment_projection_atomically()` validates canonical source identity and weapon member/revision identity before saving previous source/snapshot, committing both, invalidating member caches once, incrementing revision once, and emitting once. Restore both objects before returning false on any failure. Task 9 extends the already-atomic preflight with weapon-aware action validation after the shared projection exists.

The multi-member method accepts entries shaped `{source: StatModifierSource, weapon: ActiveWeaponDamageSnapshot}` and validates every member before committing any. The non-equipment refresh method receives the recomputed weapon snapshot together with its recomputed equipment source. `PlayerRunContext.assign_equipment()`, non-equipment refresh, and reconstruction commit through these authority methods; never assign the activation or snapshot dictionaries before PartyManager accepts the complete projection.

```gdscript
func replace_member_equipment_projection_atomically(
    member_id: int,
    equipment_source: StatModifierSource,
    weapon: ActiveWeaponDamageSnapshot,
    authority: RefCounted = null,
) -> bool:
    if not _equipment_projection_is_valid(member_id, equipment_source, weapon, authority, _stat_revision + 1):
        return false
    var previous_sources := member_by_id(member_id).modifier_sources
    var previous_weapon := active_weapon_snapshot(member_id)
    if not _commit_equipment_projection_without_invalidation(member_id, equipment_source, weapon):
        _restore_member_sources_without_invalidation(member_id, previous_sources)
        _restore_weapon_without_invalidation(member_id, previous_weapon)
        return false
    _invalidate_member(member_id)
    return true
```

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 5: Commit atomic publication**

```powershell
git add scripts/equipment/equipment_transition_result.gd scripts/equipment/equipment_transition_service.gd scripts/run/player_run_context.gd scripts/party/party_manager.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_party_manager.gd
git diff --cached --check
git commit -m "feat: publish weapon projections atomically"
```

---

### Task 9: Share one weapon-aware action projection across runtime and estimates

**Files:**
- Create: `scripts/combat/action_damage_component_projection.gd`
- Modify: `scripts/data/attack_definition.gd`
- Modify: `scripts/combat/combatant_adapter.gd`
- Modify: `scripts/combat/combat_modifiers.gd`
- Modify: `scripts/combat/attack_executor.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/combat/action_damage_projection.gd`
- Modify: `scripts/combat/combat_rng.gd`
- Modify: `scripts/combat/damage_resolver.gd`
- Modify: `scripts/combat/candidate_action_validation_service.gd`
- Modify: `scripts/ui/ledger/action_combat_estimate_service.gd`
- Modify: `data/attacks/fighter_cleave.tres`
- Modify: `data/attacks/ranger_shot.tres`
- Modify: `data/attacks/marksman_heavy_shot.tres`
- Modify: `data/attacks/rogue_flurry.tres`
- Modify: `data/attacks/paladin_smite.tres`
- Test: `tests/unit/test_action_damage_component_projection.gd`
- Modify: `tests/unit/test_damage_resolver.gd`
- Modify: `tests/unit/test_combat_rng.gd`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_action_combat_estimate_service.gd`
- Modify: `tests/unit/test_equipment_transition_service.gd`
- Modify: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Produces: `AttackDefinition.DamageSource.AUTHORED` and `.ACTIVE_WEAPON`.
- Produces: `AttackDefinition.weapon_damage_effectiveness: float`, default `1.0`.
- Produces: `ActionDamageComponentProjection.resolve(attack, weapon) -> Dictionary` shaped `{error, used_fallback, components}`.
- Changes: `ActionCombatEstimateService.estimate_from_snapshot(attack: AttackDefinition, action_stats: ResolvedStatSnapshot, types: DamageTypeCatalog, weapon: ActiveWeaponDamageSnapshot = null) -> ActionCombatEstimate`.
- Produces: `CombatRng.unit() -> float`; existing `roll(chance)` delegates its consumed draw to this method.
- Changes: `CombatantAdapter` owns a defensive `weapon_snapshot`; `CombatModifiers.Snapshot` captures the same revision-matched snapshot; `AttackExecutor` passes it into the source adapter.
- Changes: `CandidateActionValidationService.validate(class_definition: ClassDefinition, member_id: int, stat_catalog: StatCatalog, damage_types: DamageTypeCatalog, base_values: Dictionary, capabilities: Array[StringName], final_sources: Array[StatModifierSource], revision: int, tuning: AttributeProjectionTuning, weapon: ActiveWeaponDamageSnapshot = null) -> String` validates every owned action against the candidate weapon before the atomic commit from Task 8.

- [ ] **Step 1: Write failing projection/parity tests**

Cover authored actions ignoring equipment, weapon actions multiplying each typed component, missing/empty snapshot using authored fallback, hybrid weapon ordering, invalid effectiveness, unknown types, runtime normal hit equal to estimate normal hit with fixed no-crit RNG, and existing global/archetype/type scaling applied exactly once. Add a transition test proving an invalid candidate weapon action leaves the already-published source/snapshot/state/revision unchanged.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_action_damage_component_projection.gd tests/unit/test_combat_rng.gd tests/unit/test_attack_execution.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_game_catalog.gd
```

Expected: non-zero exit because action damage source/effectiveness do not exist.

- [ ] **Step 3: Implement the shared component projection**

```gdscript
enum DamageSource { AUTHORED, ACTIVE_WEAPON }
@export var damage_source := DamageSource.AUTHORED
@export var weapon_damage_effectiveness := 1.0
```

For `ACTIVE_WEAPON`, copy snapshot components and multiply minimum/maximum by effectiveness. Add `CombatRng.unit()` as the sole raw `[0, 1)` draw primitive and make `roll(chance)` call it only when a chance consumes a draw. Preserve the existing critical roll first; then runtime selects one amount per non-fixed component in sorted damage-type order with `lerpf(minimum, maximum, rng.unit())`. Estimates use the midpoint `(minimum + maximum) * 0.5`. Both paths then call the existing `ActionDamageProjection.normal_component()` for global, archetype, and type scaling. Authored fallback converts each current `AttackDamageComponent.base_amount` into a fixed `minimum == maximum` range and therefore consumes no range draw.

Mark exactly the five listed playable attacks `ACTIVE_WEAPON`. Mage, Frost Mage, Cleric bolt/heal, and Warlock remain authored. Preserve every attack's current authored component as fallback.

`CombatModifiers.resolve_for_action()` reads both the action stat snapshot and `PartyManager.active_weapon_snapshot(member_id)` before returning. `AttackExecutor.execute()` passes that snapshot to `PartyActor.get_combat_adapter()`, and `CombatantAdapter` stores a defensive copy. Reject execution when the weapon snapshot's member or equipment revision does not match the action context; do not re-query PartyManager after the context is captured.

Extend `CandidateActionValidationService.validate()` with the optional candidate weapon. Every equipment preview from Task 8 calls it after source/stat/snapshot validation and before commit. It invokes the same `ActionCombatEstimateService.estimate_from_snapshot()` signature for every owned action, so invalid effectiveness, type, or nonfinite damage aborts the complete transition.

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 5: Commit weapon-aware action projection**

```powershell
git add scripts/combat/action_damage_component_projection.gd scripts/data/attack_definition.gd scripts/combat/combatant_adapter.gd scripts/combat/combat_modifiers.gd scripts/combat/attack_executor.gd scripts/characters/party_actor.gd scripts/combat/action_damage_projection.gd scripts/combat/combat_rng.gd scripts/combat/damage_resolver.gd scripts/combat/candidate_action_validation_service.gd scripts/ui/ledger/action_combat_estimate_service.gd data/attacks/fighter_cleave.tres data/attacks/ranger_shot.tres data/attacks/marksman_heavy_shot.tres data/attacks/rogue_flurry.tres data/attacks/paladin_smite.tres tests/unit/test_action_damage_component_projection.gd tests/unit/test_combat_rng.gd tests/unit/test_attack_execution.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_game_catalog.gd
git diff --cached --check
git commit -m "feat: use weapon damage in playable attacks"
```

---

### Task 10: Present typed base ranges and weapon-aware comparisons

**Files:**
- Modify: `scripts/ui/storage/item_presentation_projector.gd`
- Modify: `scripts/ui/storage/item_tooltip_card.gd`
- Modify: `scripts/ui/storage/item_comparison_resolver.gd`
- Modify: `scripts/ui/storage/equipment_comparison_projection_service.gd`
- Modify: `scripts/ui/storage/profile_storage_projection.gd`
- Modify: `scripts/ui/armoury/armoury_screen.gd`
- Modify: `scripts/ui/warehouse/warehouse_screen.gd`
- Modify: `scripts/ui/developer_item_sandbox.gd`
- Modify: `tests/unit/test_item_presentation_projector.gd`
- Modify: `tests/unit/test_item_tooltip_card.gd`
- Modify: `tests/unit/test_item_comparison_resolver.gd`
- Modify: `tests/unit/test_profile_storage_projection.gd`
- Modify: `tests/integration/item_tooltip_responsive_runner.gd`

**Interfaces:**
- Produces detail field `base_damage_components: Array[Dictionary]` with type ID/name/color/minimum/maximum.
- Produces detail field `base_damage_lines: PackedStringArray` displayed above implicits.
- Extends comparison rows with per-type base range, normal hit, critical hit, average hit, attacks/second, DPS, healing, and activation changes.

- [ ] **Step 1: Write failing projection/tooltip/comparison tests**

Assert normal item order: title/classification, typed base ranges, implicit, explicit, requirements, warning. Assert hybrid ranges remain separate. Advanced mode shows profile ID, rarity multiplier, quality, tiers, exact values, and roll bounds; Player Mode omits technical IDs. Compare mode marks improved rows green and reduced rows red, including damage types that exist on only one side. Verify schema-1 empty components render no blank heading.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_profile_storage_projection.gd
```

Expected: non-zero exit for missing base-damage detail and comparison rows.

- [ ] **Step 3: Extend shared projection and cards**

Project base damage directly from immutable item components and resolve only presentation names/colors through `DamageTypeCatalog`. Add `_base_damage_label` between classification and core values. Feed current/candidate active weapon snapshots into the same action-estimate service used by Task 9. Do not calculate DPS inside tooltip code.

```gdscript
detail["base_damage_components"] = _project_base_damage(item.base_damage_components, damage_types)
detail["base_damage_lines"] = _base_damage_lines(detail["base_damage_components"] as Array)

_base_damage_label = _add_label("BaseDamage", 15)
_set_label(_base_damage_label, _string_lines(_detail.get("base_damage_lines", [])))
```

Armoury, Warehouse, and Developer Sandbox continue passing the shared detail dictionary. Do not expose or enable the Character Ledger Equipment & Inventory tab.

- [ ] **Step 4: Run unit and responsive tests**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_profile_storage_projection.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

Expected: both exits `0`, focused PASS marker, responsive PASS marker, and no 1080p/1440p/4K overflow failures.

- [ ] **Step 5: Commit shared presentation**

```powershell
git add scripts/ui/storage/item_presentation_projector.gd scripts/ui/storage/item_tooltip_card.gd scripts/ui/storage/item_comparison_resolver.gd scripts/ui/storage/equipment_comparison_projection_service.gd scripts/ui/storage/profile_storage_projection.gd scripts/ui/armoury/armoury_screen.gd scripts/ui/warehouse/warehouse_screen.gd scripts/ui/developer_item_sandbox.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_profile_storage_projection.gd tests/integration/item_tooltip_responsive_runner.gd
git diff --cached --check
git commit -m "feat: present weapon ranges and comparisons"
```

---

### Task 11: Produce deterministic machine and human balance reports

**Files:**
- Create: `scripts/items/item_generation_balance_report.gd`
- Create: `tools/export_weighted_loot_balance_report.gd`
- Modify: `scripts/items/item_generation_request.gd`
- Test: `tests/unit/test_item_generation_balance_report.gd`
- Modify: `tests/unit/test_item_generation_request.gd`
- Modify: `tests/unit/test_item_generation_distribution.gd`
- Generate: `docs/validation/evidence/2026-08-10-weighted-loot-production-balance.json`
- Generate: `docs/validation/evidence/2026-08-10-weighted-loot-production-balance.md`

**Interfaces:**
- Produces: `ItemGenerationBalanceReport.build(equipment, foundation, requests) -> Dictionary`.
- Produces: canonical JSON and stable Markdown from the same report dictionary.
- Produces: `ItemGenerationRequest.copy_with_sequence(value: int) -> ItemGenerationRequest`, preserving every other request field by defensive copy.

- [ ] **Step 1: Write failing report and distribution tests**

Use fixed seed ranges and request matrices at item levels `1, 10, 30, 60, 100, 160, 240, 340, 460, 600, 770, 950, 1000`; all five ordinary rarities; melee/ranged/caster/global bases; low/moderate/extreme Charisma; party tags; and Heat values `0, 25, 100`. Assert exact manifest/reachability sections, deterministic repeat output, all four weight bands observed, higher-level tier trend, premium scarcity, party bias without elimination, diminishing Charisma without gate bypass, and weapon minimum/median/high percentiles.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_request.gd tests/unit/test_item_generation_balance_report.gd tests/unit/test_item_generation_distribution.gd
```

Expected: non-zero exit because the report service does not exist.

- [ ] **Step 3: Implement bounded deterministic reporting**

Use exactly 2,000 sequences per orthogonal scenario row rather than a full Cartesian product: 65 level-by-rarity rows, 8 archetype/party-bias rows, and 9 Charisma-by-Heat rows, for 164,000 generated samples. Use stable sorted aggregation keys. Record counts, normalized proportions, expected relative weights, reachability, exclusions, tier/rarity fill rates, and weapon percentiles. Tests use broad direction/tolerance assertions; they never require a particular individual roll. Exporter writes JSON with two-space indentation and Markdown tables in stable key order.

```gdscript
func copy_with_sequence(value: int) -> ItemGenerationRequest:
    var result := ItemGenerationRequest.new()
    for property_name: StringName in [
        &"seed", &"item_level", &"source_id", &"generation_domain", &"difficulty_id",
        &"heat", &"charisma_value", &"forced_base_id", &"forced_rarity_id",
    ]:
        result.set(property_name, get(property_name))
    for property_name: StringName in [
        &"permitted_rarity_ids", &"party_archetype_tags", &"unlock_tags",
        &"required_base_tags", &"excluded_base_tags", &"required_affix_tags", &"excluded_affix_tags",
    ]:
        result.set(property_name, (get(property_name) as Array).duplicate())
    result.generation_sequence = value
    return result

static func build(
    equipment: EquipmentCatalog,
    foundation: ItemFoundationCatalog,
    requests: Array[ItemGenerationRequest],
) -> Dictionary:
    var report := _empty_report()
    for request: ItemGenerationRequest in _sorted_requests(requests):
        for sequence: int in 2000:
            var sample := request.copy_with_sequence(sequence)
            _record(report, ItemGenerationService.generate(sample, "balance-report", sequence, equipment, foundation))
    return _canonical_report(report)
```

- [ ] **Step 4: Generate reports twice and verify byte parity**

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tools/export_weighted_loot_balance_report.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$jsonHash = (Get-FileHash 'docs\validation\evidence\2026-08-10-weighted-loot-production-balance.json').Hash
$mdHash = (Get-FileHash 'docs\validation\evidence\2026-08-10-weighted-loot-production-balance.md').Hash
& $godot --headless --path . --quit-after 1800 --script res://tools/export_weighted_loot_balance_report.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ((Get-FileHash 'docs\validation\evidence\2026-08-10-weighted-loot-production-balance.json').Hash -ne $jsonHash) { throw 'JSON report drifted' }
if ((Get-FileHash 'docs\validation\evidence\2026-08-10-weighted-loot-production-balance.md').Hash -ne $mdHash) { throw 'Markdown report drifted' }
```

Expected: both hashes remain identical.

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 6: Commit reports and generator**

```powershell
git add scripts/items/item_generation_request.gd scripts/items/item_generation_balance_report.gd tools/export_weighted_loot_balance_report.gd tests/unit/test_item_generation_request.gd tests/unit/test_item_generation_balance_report.gd tests/unit/test_item_generation_distribution.gd docs/validation/evidence/2026-08-10-weighted-loot-production-balance.json docs/validation/evidence/2026-08-10-weighted-loot-production-balance.md
git diff --cached --check
git commit -m "test: record weighted loot balance evidence"
```

---

### Task 12: Verify save, ownership, extraction, and 24-member integration

**Files:**
- Create: `tests/integration/weighted_loot_production_runner.gd`
- Modify: `tests/integration/progression_24_member_runner.gd`
- Modify: `tests/unit/test_run_item_ownership.gd`
- Modify: `tests/unit/test_run_extraction_policy.gd`
- Modify: `tests/unit/test_run_resolution_service.gd`
- Modify: `tests/unit/test_profile_item_storage_service.gd`
- Modify: `tests/unit/test_local_run_setup_coordinator.gd`

**Interfaces:**
- Consumes: complete Increment 3 item, activation, combat, UI, and persistence contracts.
- Produces: end-to-end proof without enabling ground drops or ledger inventory.

- [ ] **Step 1: Write failing end-to-end scenarios**

Generate, issue, store, equip, disable, re-enable, extract, save, reload, resume, compare, and attack with fixed schema-2 weapons. Include one literal schema-1 fixture and prove fallback. Include 24 members with distinct main hands and prove one member's transition changes no other member's item bytes, sources, snapshots, estimates, or health. Assert failed transitions and failed generation consume no sequence and mutate no profile/run state.

- [ ] **Step 2: Run integration tests and verify RED if wiring remains incomplete**

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/weighted_loot_production_runner.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/progression_24_member_runner.gd
```

Expected: both runners exit `0` if Tasks 1-11 are complete. A failure is assigned back to the task owning the failed contract before this integration task proceeds.

- [ ] **Step 3: Keep the integration runner explicit and contract-only**

The new runner calls public APIs only and records one stable PASS marker:

```gdscript
extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    _verify_schema_migration_and_resume(failures)
    _verify_generate_store_equip_attack_extract(failures)
    _verify_failure_atomicity(failures)
    _verify_twenty_four_member_isolation(failures)
    if failures.is_empty():
        print("WEIGHTED_LOOT_PRODUCTION_INTEGRATION: PASS")
        quit(0)
        return
    for failure: String in failures:
        push_error("WEIGHTED_LOOT_PRODUCTION_INTEGRATION: %s" % failure)
    quit(1)
```

If a scenario fails, use the stable diagnostic to return to the owning task: codec/profile failures to Task 1, generation failures to Tasks 3-6, activation/ownership failures to Tasks 7-8, runtime damage failures to Task 9, and presentation failures to Task 10. Preserve existing extraction selection rules and leader/follower ownership. Do not add pickup or ground-drop nodes.

- [ ] **Step 4: Run focused regression and integration batches**

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_instance_codec.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_run_item_ownership.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_service.gd tests/unit/test_local_run_setup_coordinator.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_damage_resolver.gd tests/unit/test_item_tooltip_card.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/weighted_loot_production_runner.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/progression_24_member_runner.gd
```

Expected: every exit `0`, focused PASS marker, and both integration PASS markers.

- [ ] **Step 5: Commit integration coverage**

```powershell
git add tests/integration/weighted_loot_production_runner.gd tests/integration/progression_24_member_runner.gd tests/unit/test_run_item_ownership.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_local_run_setup_coordinator.gd
git diff --cached --check
git commit -m "test: verify weighted loot integration"
```

---

### Task 13: Run cold-import, full-suite, startup, and evidence gates

**Files:**
- Create: `docs/verification/2026-08-10-weighted-loot-production-content-and-weapon-damage.md`

**Interfaces:**
- Consumes: the exact final review commit.
- Produces: reproducible verification evidence and a reviewable branch; it does not merge into `main`.

- [ ] **Step 1: Inventory processes, Git state, and generated sidecars**

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Select-Object Id,ProcessName,Path
git status --short
git diff --check
git ls-files '*.gd.uid' | Sort-Object | Set-Content '.superpowers\sdd\weighted-loot-tracked-uids-before.txt'
Get-ChildItem -Recurse -Filter *.gd.uid | ForEach-Object { $_.FullName.Substring($pwd.Path.Length + 1) } | Sort-Object | Set-Content '.superpowers\sdd\weighted-loot-all-uids-before.txt'
```

Expected: only intentional feature paths are tracked; do not stop the user's unrelated editor.

- [ ] **Step 2: Run cold import and focused feature suite**

```powershell
& $godot --headless --path . --editor --quit-after 600 2>&1 | Tee-Object '.superpowers\sdd\weighted-loot-cold-import.log'
& $godot --headless --path . --quit-after 1800 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_base_damage_component.gd tests/unit/test_weapon_damage_profile.gd tests/unit/test_weapon_base_damage_roller.gd tests/unit/test_weighted_loot_content_rows.gd tests/unit/test_weighted_loot_builder_parity.gd tests/unit/test_active_weapon_damage_resolver.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_action_damage_component_projection.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_generation_balance_report.gd
```

Expected: import exit `0` with no unexpected parse/load error; focused exit `0` with one PASS marker.

- [ ] **Step 3: Run complete and integration suites**

```powershell
& $godot --headless --path . --quit-after 2400 --script res://tests/test_runner.gd 2>&1 | Tee-Object '.superpowers\sdd\weighted-loot-full-suite.log'
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/weighted_loot_production_runner.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 1200 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

Expected: every command exits `0`; full suite prints exactly one `TEST_SUMMARY: PASS (<observed> suites)` and no failure marker; every integration runner prints its PASS marker.

- [ ] **Step 4: Run startup and deterministic regeneration gates**

```powershell
& $godot --headless --path . --quit-after 600 2>&1 | Tee-Object '.superpowers\sdd\weighted-loot-startup.log'
$before = git diff --binary
& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd
& $godot --headless --path . --quit-after 1800 --script res://tools/export_weighted_loot_balance_report.gd
$after = git diff --binary
if ($before -ne $after) { throw 'deterministic generators changed tracked bytes' }
```

Expected: startup includes `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY` exactly once; regeneration changes zero tracked bytes.

- [ ] **Step 5: Record exact evidence and deferred physical checks**

The verification document records final commit, Godot version, commands, exit codes, observed suite count, markers, manifest counts, schema migration cases, integration cases, report hashes, cold-import/startup diagnostics, and sidecar disposition. Record physical-controller acceptance and human visual review as deferred unless they were actually performed.

- [ ] **Step 6: Commit the evidence document**

```powershell
git add docs/verification/2026-08-10-weighted-loot-production-content-and-weapon-damage.md
git diff --cached --check
git commit -m "docs: verify weighted loot production content"
git status --short
```

Expected: no tracked changes remain. Report the generated/untracked sidecars explicitly; do not describe the worktree as fully clean if they remain.

---

## Review checkpoints

Request independent review after Tasks 3, 6, 9, 10, and 13. Each review checks spec compliance first and code quality second. Do not continue past a checkpoint with an unresolved critical or important finding.

## Completion boundary

This plan ends with a verified feature branch and an explicit integration choice. It does not merge, delete worktrees, enable production drops, unlock upper rarities, expose the ledger inventory page, or claim physical controller/visual acceptance without direct evidence.
