# Five-Class Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Party Forge from four to nine playable classes by adding Paladin, Rogue, Frost Mage, Warlock, and the user's existing Marksman, with functional overlapping traits and catalog-driven leader/recruit flows.

**Architecture:** Class identity remains Resource-driven: typed attack Resources define delivery and damage, ClassDefinition Resources define roles/base stats/capabilities, and TraitDefinition Resources contribute shared resolved-stat modifiers. GameCatalog becomes the only source for leader and recruit availability, while a reusable ClassSelectionPanel renders the catalog without class-specific branches.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources/TSCN scenes, the existing `tests/test_runner.gd` harness, and the connected Godot editor session.

## Global Constraints

- Work in the user-authorized live `main` checkout at `F:\Projects(root)\Game dev\Projects\party-forge`; do not create or remove a worktree.
- Save all open Godot scenes before execution and restore `res://scenes/game/main.tscn` as the active saved scene after verification.
- Preserve every unrelated modified/untracked path. The user's `data/classes/marksman.tres` is deliberately in scope; GodotSteam, the handbook ZIP, UI work outside the selector, and unrelated serialized/formatting changes remain out of scope.
- Use typed GDScript and strict RED-GREEN TDD. A task does not advance until its implementation passes both specification and code-quality review.
- Keep the four-member party cap and duplicate-class recruitment.
- The exact playable order is Fighter, Ranger, Mage, Cleric, Paladin, Rogue, Frost Mage, Warlock, Marksman.
- Do not add items, affixes, passive trees, functional ailments, the character stat drawer, or stage-5 character-targeted upgrades.
- Cold and Chaos are ordinary data-driven damage types already supported by the shared resolver; do not add resolver branches for named elements.
- All new balance values are initial testable identity data, not final balance.
- Any generated `.gd.uid` sidecar matching a new script is staged with that script.
- When a dirty file overlaps the task, stage only the authorized feature hunk and verify both cached and residual diffs before committing.

---

## File Structure

### New content

- `data/attacks/paladin_smite.tres` — Paladin Physical melee attack.
- `data/attacks/rogue_flurry.tres` — Rogue fast Physical melee attack.
- `data/attacks/frost_shard.tres` — Frost Mage Cold area projectile.
- `data/attacks/warlock_bolt.tres` — Warlock heavy Chaos projectile.
- `data/attacks/marksman_heavy_shot.tres` — Marksman slow, long-range Physical bow shot.
- `data/classes/paladin.tres`, `rogue.tres`, `frost_mage.tres`, `warlock.tres` — four new class definitions.
- `data/classes/marksman.tres` — complete and adopt the existing in-development Resource.
- `data/traits/fire.tres`, `cold.tres`, `skirmisher.tres`, `occult.tres`, `chaos.tres`, `bow.tres` — overlapping trait identities.
- `tools/class_expansion_rows.gd` — one exact attack/class data table shared by generation and migration.
- `tools/migrate_class_expansion_data.gd` — idempotent live-project migration for the five new classes.
- `scripts/ui/class_selection_panel.gd` — catalog-driven scrollable leader selector.

### Modified foundations

- `scripts/data/trait_definition.gd` and `scripts/party/party_manager.gd` — validate and resolve new trait effects.
- `scripts/data/game_catalog.gd` — load nine classes/thirteen traits and validate class trait references.
- `tools/create_default_data.gd` — make a clean generated project contain the complete nine-class catalog.
- `scripts/game/main.gd` and `scenes/ui/hud.tscn` — replace four hard-coded buttons with the selector component.
- Focused tests plus handbook Chapters 3–6 and 10 document and verify the new content.

---

### Task 1: Functional Expansion Traits

**Files:**

- Modify: `scripts/data/trait_definition.gd`
- Modify: `scripts/party/party_manager.gd`
- Modify: `scripts/data/game_catalog.gd`
- Modify: `data/classes/mage.tres`
- Create: `data/traits/fire.tres`
- Create: `data/traits/cold.tres`
- Create: `data/traits/skirmisher.tres`
- Create: `data/traits/occult.tres`
- Create: `data/traits/chaos.tres`
- Create: `data/traits/bow.tres`
- Create: `tests/unit/test_class_expansion_traits.gd`

**Interfaces:**

- Consumes: `PartyManager.stats_for(member_id: int) -> ResolvedStatSnapshot`.
- Produces: six valid TraitDefinition Resources and deterministic trait-to-stat mappings.

- [ ] **Step 1: Write the failing trait coverage**

Create `tests/unit/test_class_expansion_traits.gd`:

```gdscript
extends RefCounted

const EXPECTED: Array[Dictionary] = [
	{"id": &"fire", "name": "Fire", "stat": &"fire_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"cold", "name": "Cold", "stat": &"cold_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"skirmisher", "name": "Skirmisher", "stat": &"dodge_chance", "tiers": {2: 0.08, 4: 0.18}, "resolved": 0.08},
	{"id": &"occult", "name": "Occult", "stat": &"life_steal", "tiers": {2: 0.04, 4: 0.10}, "resolved": 0.04},
	{"id": &"chaos", "name": "Chaos", "stat": &"chaos_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"bow", "name": "Bow", "stat": &"attack_range", "tiers": {2: 0.12, 4: 0.28}, "resolved": 1.12},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	for row: Dictionary in EXPECTED:
		var trait := load("res://data/traits/%s.tres" % row["id"]) as TraitDefinition
		TestAssertions.truthy(trait != null, "%s trait loads" % row["id"], failures)
		if trait == null:
			continue
		TestAssertions.equal(trait.id, row["id"], "%s id" % row["id"], failures)
		TestAssertions.equal(trait.display_name, row["name"], "%s name" % row["id"], failures)
		TestAssertions.equal(trait.stat_id, row["stat"], "%s stat" % row["id"], failures)
		TestAssertions.equal(trait.tiers, row["tiers"], "%s tiers" % row["id"], failures)
		TestAssertions.equal(trait.validate(), PackedStringArray(), "%s validates" % row["id"], failures)
		var definition := ClassDefinition.new()
		definition.id = StringName("trait_test_%s" % row["id"])
		definition.display_name = "Trait Test"
		definition.traits = [row["id"]]
		definition.primary_attack = catalog.class_by_id(&"fighter").primary_attack
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		party.recruit(definition)
		TestAssertions.near(
			party.stats_for(party.members[0].member_id).value(row["stat"]),
			row["resolved"],
			0.001,
			"%s tier two changes resolved stat" % row["id"],
			failures,
		)
		party.free()
	TestAssertions.equal(
		catalog.class_by_id(&"mage").traits,
		[&"arcane", &"caster", &"fire"],
		"Mage matches approved Arcane Caster Fire identity",
		failures,
	)
	return failures
```

- [ ] **Step 2: Run RED**

Run the full test command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: FAIL because the six trait Resources are missing and Mage still uses `ranged`.

- [ ] **Step 3: Extend trait validation and resolution**

Append these IDs to `TraitDefinition.SUPPORTED_STAT_IDS`:

```gdscript
&"fire_damage", &"cold_damage", &"chaos_damage",
&"dodge_chance", &"life_steal", &"attack_range",
```

Add these branches to `PartyManager._sources_for()`'s trait `match`:

```gdscript
&"fire_damage", &"cold_damage", &"chaos_damage", &"attack_range":
	trait_modifiers.append(StatModifier.create(
		trait_data.stat_id,
		StatModifier.Operation.INCREASED,
		active_value,
		trait_id,
		label,
	))
&"dodge_chance", &"life_steal":
	trait_modifiers.append(StatModifier.create(
		trait_data.stat_id,
		StatModifier.Operation.FLAT,
		active_value,
		trait_id,
		label,
	))
```

Create the six Resources with the exact rows from `EXPECTED`. Each uses `scripts/data/trait_definition.gd`, its exact `id`, `display_name`, `stat_id`, and `tiers`.

Change Mage traits to:

```gdscript
traits = Array[StringName]([&"arcane", &"caster", &"fire"])
```

Add the six exact paths after the seven existing paths in `GameCatalog.TRAIT_PATHS`.

- [ ] **Step 4: Run GREEN and parser/import checks**

Run the full suite and:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --import
```

Expected: `TEST_SUMMARY: PASS (28 suites)`, import exit 0, and only intentional diagnostic cases.

- [ ] **Step 5: Commit**

Stage only Task 1 files plus matching UID sidecars, run `git diff --cached --check`, and commit:

```powershell
git commit -m "feat: add expansion traits"
```

---

### Task 2: Exact Five-Class Attack and Class Resources

**Files:**

- Create: `tools/class_expansion_rows.gd`
- Create: `tools/migrate_class_expansion_data.gd`
- Modify: `tools/create_default_data.gd`
- Create: five attack Resources listed in File Structure
- Create: four new class Resources listed in File Structure
- Modify/adopt: `data/classes/marksman.tres`
- Create: `tests/unit/test_expanded_class_content.gd`

**Interfaces:**

- Consumes: `AttackDefinition`, `AttackDamageComponent`, `ClassDefinition`, and the Task 1 traits.
- Produces: five complete class Resources and five typed party attacks.

- [ ] **Step 1: Write the failing exact-content test**

Create `tests/unit/test_expanded_class_content.gd`. The test must load these exact independent tables:

```gdscript
extends RefCounted

const ATTACKS: Array[Dictionary] = [
	{"id": &"paladin_smite", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "type": &"physical", "amount": 16.0, "cooldown": 1.05, "range": 2.1, "speed": 0.0, "area": 1.4, "tags": [&"area", &"melee", &"physical"], "crit": true},
	{"id": &"rogue_flurry", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "type": &"physical", "amount": 8.0, "cooldown": 0.32, "range": 1.6, "speed": 0.0, "area": 0.9, "tags": [&"area", &"melee", &"physical", &"skirmisher"], "crit": true},
	{"id": &"frost_shard", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "type": &"cold", "amount": 20.0, "cooldown": 1.35, "range": 12.5, "speed": 10.0, "area": 3.0, "tags": [&"area", &"cold", &"projectile"], "crit": true},
	{"id": &"warlock_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "type": &"chaos", "amount": 30.0, "cooldown": 1.75, "range": 12.5, "speed": 9.0, "area": 0.0, "tags": [&"chaos", &"projectile", &"ranged"], "crit": true},
	{"id": &"marksman_heavy_shot", "kind": AttackDefinition.Kind.PROJECTILE, "type": &"physical", "amount": 42.0, "cooldown": 2.2, "range": 16.0, "speed": 22.0, "area": 0.0, "tags": [&"bow", &"physical", &"projectile", &"ranged"], "crit": true},
]

const CLASSES: Array[Dictionary] = [
	{"id": &"paladin", "name": "Paladin", "role": ClassDefinition.Role.FRONTLINE, "color": Color("e6c85f"), "traits": [&"divine", &"vanguard", &"martial"], "tags": [&"area", &"block", &"melee", &"physical", &"regeneration"], "health": 220.0, "armor": 18.0, "speed": 5.6, "preferred": 2.0, "engagement": 4.5, "tether": 8.5, "attack": &"paladin_smite", "overrides": {&"block_chance": 0.18, &"block_effectiveness": 0.55, &"health_regeneration": 1.5}},
	{"id": &"rogue", "name": "Rogue", "role": ClassDefinition.Role.MIDLINE, "color": Color("a95be8"), "traits": [&"martial", &"skirmisher"], "tags": [&"area", &"crit", &"dodge", &"life_steal", &"melee", &"physical"], "health": 72.0, "armor": 0.0, "speed": 7.4, "preferred": 1.4, "engagement": 3.0, "tether": 8.0, "attack": &"rogue_flurry", "overrides": {&"crit_chance": 0.20, &"crit_multiplier": 1.75, &"dodge_chance": 0.18, &"life_steal": 0.05}},
	{"id": &"frost_mage", "name": "Frost Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("70c8ff"), "traits": [&"arcane", &"caster", &"cold"], "tags": [&"area", &"cold", &"projectile"], "health": 78.0, "armor": 0.0, "speed": 6.0, "preferred": 6.5, "engagement": 12.5, "tether": 12.5, "attack": &"frost_shard", "overrides": {}},
	{"id": &"warlock", "name": "Warlock", "role": ClassDefinition.Role.BACKLINE, "color": Color("7e4bc4"), "traits": [&"occult", &"caster", &"chaos"], "tags": [&"chaos", &"life_steal", &"projectile", &"ranged"], "health": 82.0, "armor": 1.0, "speed": 5.8, "preferred": 6.0, "engagement": 12.5, "tether": 12.5, "attack": &"warlock_bolt", "overrides": {&"chaos_damage": 1.10, &"life_steal": 0.12}},
	{"id": &"marksman", "name": "Marksman", "role": ClassDefinition.Role.MIDLINE, "color": Color(0.27579924, 0.36415747, 0.056183092, 1.0), "traits": [&"martial", &"ranged", &"bow"], "tags": [&"bow", &"crit", &"physical", &"projectile", &"ranged"], "health": 80.0, "armor": 2.0, "speed": 5.8, "preferred": 8.0, "engagement": 16.0, "tether": 16.0, "attack": &"marksman_heavy_shot", "overrides": {&"crit_chance": 0.10, &"crit_multiplier": 2.0}},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	for row: Dictionary in ATTACKS:
		var attack := load("res://data/attacks/%s.tres" % row["id"]) as AttackDefinition
		TestAssertions.truthy(attack != null, "%s attack loads" % row["id"], failures)
		if attack == null:
			continue
		TestAssertions.equal(attack.validate(types), PackedStringArray(), "%s validates" % row["id"], failures)
		TestAssertions.equal(attack.kind, row["kind"], "%s kind" % row["id"], failures)
		TestAssertions.near(attack.power, 0.0, 0.001, "%s legacy power is zero" % row["id"], failures)
		TestAssertions.near(attack.cooldown, row["cooldown"], 0.001, "%s cooldown" % row["id"], failures)
		TestAssertions.near(attack.range, row["range"], 0.001, "%s range" % row["id"], failures)
		TestAssertions.near(attack.projectile_speed, row["speed"], 0.001, "%s speed" % row["id"], failures)
		TestAssertions.near(attack.area_radius, row["area"], 0.001, "%s area" % row["id"], failures)
		TestAssertions.equal(attack.normalized_action_tags(), row["tags"], "%s tags" % row["id"], failures)
		TestAssertions.equal(attack.can_crit, row["crit"], "%s crit" % row["id"], failures)
		TestAssertions.equal(attack.damage_components.size(), 1, "%s one component" % row["id"], failures)
		if attack.damage_components.size() == 1:
			TestAssertions.equal(attack.damage_components[0].damage_type_id, row["type"], "%s type" % row["id"], failures)
			TestAssertions.near(attack.damage_components[0].base_amount, row["amount"], 0.001, "%s amount" % row["id"], failures)
	for row: Dictionary in CLASSES:
		var definition := load("res://data/classes/%s.tres" % row["id"]) as ClassDefinition
		TestAssertions.truthy(definition != null, "%s class loads" % row["id"], failures)
		if definition == null:
			continue
		TestAssertions.equal(definition.validate(types), PackedStringArray(), "%s validates" % row["id"], failures)
		TestAssertions.equal(definition.display_name, row["name"], "%s name" % row["id"], failures)
		TestAssertions.equal(definition.role, row["role"], "%s role" % row["id"], failures)
		TestAssertions.equal(definition.color, row["color"], "%s color" % row["id"], failures)
		TestAssertions.equal(definition.traits, row["traits"], "%s traits" % row["id"], failures)
		TestAssertions.equal(definition.capability_tags, row["tags"], "%s tags" % row["id"], failures)
		TestAssertions.near(definition.max_health, row["health"], 0.001, "%s health" % row["id"], failures)
		TestAssertions.near(definition.armor, row["armor"], 0.001, "%s armor" % row["id"], failures)
		TestAssertions.near(definition.move_speed, row["speed"], 0.001, "%s move speed" % row["id"], failures)
		TestAssertions.near(definition.preferred_distance, row["preferred"], 0.001, "%s preferred" % row["id"], failures)
		TestAssertions.near(definition.engagement_distance, row["engagement"], 0.001, "%s engagement" % row["id"], failures)
		TestAssertions.near(definition.tether_distance, row["tether"], 0.001, "%s tether" % row["id"], failures)
		TestAssertions.equal(definition.primary_attack.id, row["attack"], "%s attack link" % row["id"], failures)
		TestAssertions.equal(definition.base_stat_overrides, row["overrides"], "%s overrides" % row["id"], failures)
	return failures
```

- [ ] **Step 2: Run RED**

Expected: FAIL because all five attack paths and four class paths are missing and Marksman is incomplete.

- [ ] **Step 3: Create the shared exact rows**

Create `tools/class_expansion_rows.gd` with `const ATTACK_ROWS` and `const CLASS_ROWS` containing exactly the independent test tables above. Attack rows additionally contain `"power": 0.0`; class rows use property keys matching ClassDefinition.

- [ ] **Step 4: Implement the idempotent migration**

Create `tools/migrate_class_expansion_data.gd` as a SceneTree script. It must:

1. Create `data/attacks` and `data/classes` if missing.
2. For each attack row, load-or-create AttackDefinition, assign every delivery/tag/crit field, clear components, append one exact AttackDamageComponent, and save.
3. Reload each saved attack with `CACHE_MODE_REPLACE`.
4. For each class row, load-or-create ClassDefinition. This deliberately loads the user's existing Marksman before completing it.
5. Assign every display/role/color/trait/capability/base-stat/formation/combat field, link the reloaded attack, set `support_action = null`, and save.
6. Validate every saved attack/class against the active damage catalog.
7. Print `PARTY_FORGE_CLASS_EXPANSION_SAVED attacks=5 classes=5` and exit 0, or emit `PARTY_FORGE_CLASS_EXPANSION_ERROR path=<path> reason=<reason>` and exit 1.

The assignment loops are exact:

```gdscript
for row: Dictionary in ExpansionRows.ATTACK_ROWS:
	var attack := load(row["path"]) as AttackDefinition if ResourceLoader.exists(row["path"]) else AttackDefinition.new()
	attack.id = row["id"]
	attack.kind = row["kind"]
	attack.power = 0.0
	attack.cooldown = row["cooldown"]
	attack.range = row["range"]
	attack.projectile_speed = row["speed"]
	attack.area_radius = row["area"]
	attack.action_tags.assign(row["tags"])
	attack.can_crit = row["crit"]
	attack.damage_components.clear()
	var component := AttackDamageComponent.new()
	component.damage_type_id = row["type"]
	component.base_amount = row["amount"]
	attack.damage_components.append(component)
	_save_checked(attack, row["path"])
```

```gdscript
for row: Dictionary in ExpansionRows.CLASS_ROWS:
	var definition := load(row["path"]) as ClassDefinition if ResourceLoader.exists(row["path"]) else ClassDefinition.new()
	definition.id = row["id"]
	definition.display_name = row["name"]
	definition.role = row["role"]
	definition.color = row["color"]
	definition.traits.assign(row["traits"])
	definition.capability_tags.assign(row["tags"])
	definition.base_stat_overrides = row["overrides"].duplicate(true)
	definition.max_health = row["health"]
	definition.armor = row["armor"]
	definition.move_speed = row["speed"]
	definition.class_rank_power_step = 0.2
	definition.revive_delay = 8.0
	definition.revive_health_fraction = 0.5
	definition.preferred_distance = row["preferred"]
	definition.engagement_distance = row["engagement"]
	definition.tether_distance = row["tether"]
	definition.primary_attack = saved_attacks[row["attack"]]
	definition.support_action = null
	_save_checked(definition, row["path"])
```

- [ ] **Step 5: Extend the retained default generator**

Preload `class_expansion_rows.gd`. Add its five attack rows to `ATTACK_ROWS`, save its five class rows after the four existing classes, and extend `_save_class` to accept capability tags and base overrides. Update Mage's traits to `[&"arcane", &"caster", &"fire"]`. Save all six Task 1 traits with their exact values.

A clean `create_default_data.gd` run must produce the same 5 expanded attacks/classes as the migration and leave `GameCatalog.load_defaults().validate()` empty once Task 3 registers them.

- [ ] **Step 6: Run the migration twice and verify byte idempotence**

Run the migration, hash the ten expanded Resources, run it again, and compare hashes:

```powershell
& $godot --headless --path $project --script res://tools/migrate_class_expansion_data.gd
$before = Get-FileHash data/attacks/paladin_smite.tres,data/attacks/rogue_flurry.tres,data/attacks/frost_shard.tres,data/attacks/warlock_bolt.tres,data/attacks/marksman_heavy_shot.tres,data/classes/paladin.tres,data/classes/rogue.tres,data/classes/frost_mage.tres,data/classes/warlock.tres,data/classes/marksman.tres
& $godot --headless --path $project --script res://tools/migrate_class_expansion_data.gd
$after = Get-FileHash data/attacks/paladin_smite.tres,data/attacks/rogue_flurry.tres,data/attacks/frost_shard.tres,data/attacks/warlock_bolt.tres,data/attacks/marksman_heavy_shot.tres,data/classes/paladin.tres,data/classes/rogue.tres,data/classes/frost_mage.tres,data/classes/warlock.tres,data/classes/marksman.tres
Compare-Object $before.Hash $after.Hash
```

Expected: migration success twice and no Compare-Object output.

- [ ] **Step 7: Run GREEN and commit**

Expected after Task 2: `TEST_SUMMARY: PASS (29 suites)`. Stage exact Task 2 files, including the formerly untracked Marksman and matching UID sidecars, then commit:

```powershell
git commit -m "feat: author five class expansion"
```

---

### Task 3: Nine-Class Catalog and Recruitment

**Files:**

- Modify: `scripts/data/game_catalog.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_progression.gd`
- Modify: `tests/unit/test_typed_combat_integration.gd`
- Create: `tests/unit/test_expanded_catalog.gd`

**Interfaces:**

- Consumes: the five class Resources and thirteen trait Resources.
- Produces: `GameCatalog.load_defaults()` with nine playable classes, thirteen traits, and active-catalog trait-reference validation.

- [ ] **Step 1: Write the failing catalog/recruitment test**

Create `tests/unit/test_expanded_catalog.gd`:

```gdscript
extends RefCounted

const CLASS_IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	TestAssertions.equal(catalog.classes.size(), 9, "nine playable classes", failures)
	TestAssertions.equal(catalog.traits.size(), 13, "thirteen overlapping traits", failures)
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "expanded catalog validates", failures)
	var actual_ids: Array[StringName] = []
	for definition: ClassDefinition in catalog.classes:
		actual_ids.append(definition.id)
		for trait_id: StringName in definition.traits:
			TestAssertions.truthy(catalog.trait_by_id(trait_id) != null, "%s trait %s resolves" % [definition.id, trait_id], failures)
	TestAssertions.equal(actual_ids, CLASS_IDS, "class order is stable", failures)
	for leader_id: StringName in CLASS_IDS:
		var party := PartyManager.new()
		party.initialize(catalog.class_by_id(leader_id), catalog.traits)
		TestAssertions.equal(party.members[0].class_definition.id, leader_id, "%s can lead" % leader_id, failures)
		for recruit_id: StringName in CLASS_IDS:
			var choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, recruit_id, "Recruit")
			TestAssertions.truthy(choice.is_valid_for(party), "%s recruit choice valid" % recruit_id, failures)
		party.free()
	var ranger := catalog.class_by_id(&"ranger").primary_attack
	var marksman := catalog.class_by_id(&"marksman").primary_attack
	TestAssertions.truthy(marksman.cooldown > ranger.cooldown, "Marksman attacks slower than Ranger", failures)
	TestAssertions.truthy(marksman.damage_components[0].base_amount > ranger.damage_components[0].base_amount, "Marksman hits harder than Ranger", failures)
	TestAssertions.truthy(marksman.range > ranger.range, "Marksman reaches farther than Ranger", failures)
	_test_missing_trait_reference(catalog, failures)
	return failures

func _test_missing_trait_reference(catalog: GameCatalog, failures: Array[String]) -> void:
	var broken := ClassDefinition.new()
	broken.id = &"broken_trait_class"
	broken.display_name = "Broken Trait Class"
	broken.traits = [&"missing_trait"]
	broken.primary_attack = catalog.class_by_id(&"fighter").primary_attack
	var invalid := GameCatalog.new()
	invalid.damage_types = catalog.damage_types
	invalid.classes = [broken]
	invalid.traits = catalog.traits
	var errors := invalid.validate()
	var found := false
	for error: String in errors:
		if error.contains("class=broken_trait_class trait=missing_trait"):
			found = true
			break
	TestAssertions.truthy(found, "missing class trait has grep-friendly validation", failures)
```

- [ ] **Step 2: Run RED**

Expected: FAIL because GameCatalog still loads four classes and does not validate class trait references.

- [ ] **Step 3: Register exact Resource paths**

Replace `GameCatalog.CLASS_PATHS` with:

```gdscript
const CLASS_PATHS: PackedStringArray = [
	"res://data/classes/fighter.tres",
	"res://data/classes/ranger.tres",
	"res://data/classes/mage.tres",
	"res://data/classes/cleric.tres",
	"res://data/classes/paladin.tres",
	"res://data/classes/rogue.tres",
	"res://data/classes/frost_mage.tres",
	"res://data/classes/warlock.tres",
	"res://data/classes/marksman.tres",
]
```

Keep the Task 1 `TRAIT_PATHS` order: seven existing traits, then Fire, Cold, Skirmisher, Occult, Chaos, Bow.

- [ ] **Step 4: Validate class trait references**

After per-Resource validation in `GameCatalog.validate()`, add:

```gdscript
for class_definition: ClassDefinition in classes:
	if class_definition == null:
		continue
	for trait_id: StringName in class_definition.traits:
		if trait_by_id(trait_id) == null:
			errors.append(
				"PARTY_FORGE_RESOURCE_ERROR path=%s class=%s trait=%s reason=unknown trait reference"
				% [class_definition.resource_path, class_definition.id, trait_id]
			)
```

- [ ] **Step 5: Update existing exact-count tests**

In `test_game_catalog.gd`, require 9 classes and 13 traits; extend attack links and exact class rows for all five new classes. In `test_progression.gd`, retain deterministic exact-three choices and add a loop proving a RECRUIT UpgradeChoice for every `CLASS_IDS` is valid while party space remains. In `test_typed_combat_integration.gd`, replace the four-class baseline assertion with nine classes; keep its existing loop over `catalog.classes` so every new primary attack must prepare a valid typed packet.

- [ ] **Step 6: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (30 suites)`, import exit 0, catalog validation empty. Commit exact Task 3 scope:

```powershell
git commit -m "feat: register nine playable classes"
```

---

### Task 4: Catalog-Driven Scrollable Leader Selector

**Files:**

- Create: `scripts/ui/class_selection_panel.gd`
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_responsive_ui.gd`
- Modify: `tools/validation/task_13_victory_acceptance.gd`
- Modify: `tools/validation/task_13_defeat_acceptance.gd`
- Create: `tests/unit/test_class_selection_panel.gd`

**Interfaces:**

- Consumes: ordered `Array[ClassDefinition]` from GameCatalog.
- Produces: `ClassSelectionPanel.class_selected(class_id: StringName)` and `configure(definitions: Array[ClassDefinition])`.

- [ ] **Step 1: Write the failing selector test**

Create `tests/unit/test_class_selection_panel.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var panel := hud.get_node("ClassSelection")
	TestAssertions.truthy(panel is ClassSelectionPanel, "selector uses reusable script", failures)
	if panel is ClassSelectionPanel:
		var catalog := GameCatalog.load_defaults()
		(panel as ClassSelectionPanel).configure(catalog.classes)
		var grid := panel.get_node("Content/Scroll/Grid") as GridContainer
		TestAssertions.equal(grid.columns, 3, "selector uses three-column grid", failures)
		TestAssertions.equal(grid.get_child_count(), 9, "selector renders all nine classes", failures)
		var selected: Array[StringName] = []
		panel.connect("class_selected", func(class_id: StringName) -> void: selected.append(class_id))
		for index: int in range(catalog.classes.size()):
			var definition := catalog.classes[index]
			var button := grid.get_child(index) as Button
			TestAssertions.equal(button.name, "Class_%s" % definition.id, "%s stable button name" % definition.id, failures)
			TestAssertions.truthy(definition.display_name in button.text, "%s display name shown" % definition.id, failures)
			button.pressed.emit()
			TestAssertions.equal(selected[-1], definition.id, "%s emits exact id" % definition.id, failures)
		TestAssertions.equal(selected.size(), 9, "each button emits once", failures)
	hud.free()
	return failures
```

- [ ] **Step 2: Run RED**

Expected: FAIL because ClassSelectionPanel and the Scroll/Grid nodes do not exist.

- [ ] **Step 3: Implement ClassSelectionPanel**

Create `scripts/ui/class_selection_panel.gd`:

```gdscript
class_name ClassSelectionPanel
extends PanelContainer

signal class_selected(class_id: StringName)

var grid: GridContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grid()

func configure(definitions: Array[ClassDefinition]) -> void:
	var target_grid := _grid()
	for child: Node in target_grid.get_children():
		target_grid.remove_child(child)
		child.free()
	for definition: ClassDefinition in definitions:
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Class_%s" % definition.id
		button.text = "%s\n%s" % [definition.display_name, _role_label(definition.role)]
		button.custom_minimum_size = Vector2(220.0, 72.0)
		button.add_theme_color_override("font_color", definition.color)
		button.add_theme_color_override("font_hover_color", definition.color.lightened(0.2))
		button.pressed.connect(_emit_selection.bind(definition.id))
		target_grid.add_child(button)

func _grid() -> GridContainer:
	if grid == null:
		grid = get_node("Content/Scroll/Grid") as GridContainer
	return grid

func _emit_selection(class_id: StringName) -> void:
	class_selected.emit(class_id)

func _role_label(role: ClassDefinition.Role) -> String:
	match role:
		ClassDefinition.Role.FRONTLINE:
			return "Frontline"
		ClassDefinition.Role.MIDLINE:
			return "Midline"
		ClassDefinition.Role.BACKLINE:
			return "Backline"
		ClassDefinition.Role.SUPPORT:
			return "Support"
		_:
			return "Unknown"
```

- [ ] **Step 4: Replace the hard-coded scene buttons**

Attach the new script to `ClassSelection`. Change its logical size to 760×440 using offsets `-380, -220, 380, 220`. Replace Fighter/Ranger/Mage/Cleric nodes with:

```text
ClassSelection
└── Content (VBoxContainer)
    ├── Title (Label)
    └── Scroll (ScrollContainer)
        └── Grid (GridContainer, columns = 3)
```

Set Scroll horizontal and vertical size flags to fill/expand, and Grid horizontal sizing to fill/expand. Runtime owns all buttons.

- [ ] **Step 5: Wire Main to the panel signal**

Replace the hard-coded class ID/button loop in `PartyForgeMain._wire_static_ui()` with:

```gdscript
var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
selector.configure(catalog.classes)
if not selector.class_selected.is_connected(select_leader_class):
	selector.class_selected.connect(select_leader_class)
```

Do not derive node paths from display names.

- [ ] **Step 6: Update integration and responsive tests**

In `test_main_wiring.gd`, configure the selector and press `Class_marksman`; assert the run starts with Marksman as leader. Loop all nine IDs on separate Main instances and assert `select_leader_class(id)` succeeds.

In `test_responsive_ui.gd`, update selector expected size to `Vector2(760.0, 440.0)`, require `Content/Scroll/Grid`, and keep center checks at 1280×720, 1920×1080, and 3840×2160.

Update the two Task 13 acceptance drivers from the deleted `Content/Fighter` and `Content/Mage` paths to `Content/Scroll/Grid/Class_fighter` and `Content/Scroll/Grid/Class_mage`. Their acceptance logic remains unchanged.

- [ ] **Step 7: Run GREEN and live rendered checks**

Expected: `TEST_SUMMARY: PASS (31 suites)`. Through the connected editor, run `main.tscn` at the 1920×1080 logical viewport, confirm nine buttons are reachable within the scroll panel, then resize to 3840×2160 and confirm the panel remains centered. Read game/editor logs from the run cursor and require no new errors.

- [ ] **Step 8: Commit**

Stage only the selector script/UID, HUD scene feature hunk, Main feature hunk, and focused tests:

```powershell
git commit -m "feat: build catalog driven class selector"
```

Immediately record this commit with `git rev-parse HEAD` as the immutable Stage 4 runtime commit. Task 5 tests and documentation may follow, but handbook snapshot banners must point to this runtime boundary.

---

### Task 5: Complete Integration, Generator Proof, and Tutorials

**Files:**

- Modify: `docs/handbook/04-resources-and-content-data.md`
- Modify: `docs/handbook/05-modifying-existing-content.md`
- Modify: `docs/handbook/06-adding-a-class-attack-and-trait.md`
- Modify: `docs/handbook/03-typed-gdscript-signals-and-data-flow.md`
- Modify: `docs/handbook/10-party-forge-architecture-reference.md`
- Modify: `docs/handbook/README.md`
- Create: `tests/unit/test_five_class_integration.gd`

**Interfaces:**

- Consumes: the complete nine-class catalog and selector.
- Produces: final static/integration evidence and source-faithful tutorials.

- [ ] **Step 1: Write the final integration audit**

Create `tests/unit/test_five_class_integration.gd`:

```gdscript
extends RefCounted

const IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "final catalog validates", failures)
	for class_id: StringName in IDS:
		var definition := catalog.class_by_id(class_id)
		TestAssertions.truthy(definition != null, "%s registered" % class_id, failures)
		if definition == null:
			continue
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		party.configure_combat(CombatRng.new(1337), catalog.damage_types)
		var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
		actor.configure(party.members[0])
		actor.configure_combat(party)
		TestAssertions.equal(actor.member_state.class_definition.id, class_id, "%s actor configures" % class_id, failures)
		var attack := definition.primary_attack
		var source := actor.get_combat_adapter(DamageResolver.action_tags_for(attack))
		var prepared := DamageResolver.prepare(
			attack,
			source,
			party.combat_rng,
			catalog.damage_types,
		)
		TestAssertions.truthy(prepared.valid, "%s attack prepares" % class_id, failures)
		actor.free()
		party.free()
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.call("_ready")
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	TestAssertions.equal(selector.grid.get_child_count(), 9, "main selector owns nine buttons", failures)
	main.free()
	return failures
```

- [ ] **Step 2: Run and commit the integration audit**

If the new suite passes immediately, record a characterization pass; do not create an artificial production change. If it fails, fix only the missing contract, capture RED/GREEN evidence, and re-review that scope. Require `TEST_SUMMARY: PASS (32 suites)`, then stage only the new integration test and its UID sidecar and commit:

```powershell
git commit -m "test: audit nine class integration"
```

- [ ] **Step 3: Verify both generators in a disposable exact-commit archive**

Create a `git archive` of HEAD in a temporary directory. Run `create_default_data.gd` twice and `migrate_class_expansion_data.gd` twice. After every run:

- all 9 classes, 9 damaging party attacks plus Cleric heal, 13 traits, and 3 enemies load;
- GameCatalog validation is empty;
- all 32 suites pass;
- hashes of generated `data/attacks`, `data/classes`, `data/traits`, and `data/enemies` are unchanged on the second run.

Never run the full default generator against the dirty live project.

- [ ] **Step 4: Update the handbook**

Document exact current behavior:

- Chapter 3: replace the hard-coded four-class signal example with `ClassSelectionPanel.class_selected` and catalog-driven configuration.
- Chapter 4: class, attack, trait, capability, and base-stat Resource ownership.
- Chapter 5: exact nine-class catalog and initial identity numbers, explicitly labeled balance data.
- Chapter 6: catalog-driven steps for adding a party-supported class and why a valid registered Resource enters leader and recruit flows.
- Chapter 10: ClassSelectionPanel ownership and nine-class data flow.
- README: map updated chapters to the immutable Stage 4 runtime commit recorded at the end of Task 4; dates are maintenance context, not snapshot proof.

Do not claim ailments, items, a stat drawer, or passive trees exist.

- [ ] **Step 5: Run fresh automated verification**

Run:

```powershell
& $godot --headless --path $project --script res://tests/test_runner.gd
& $godot --headless --path $project --import
rg -n 'HUD/ClassSelection/Content/(Fighter|Ranger|Mage|Cleric)|var class_ids: Array\[StringName\]' scripts scenes
git diff --check
```

Expected: `TEST_SUMMARY: PASS (32 suites)`; import exit 0; no hard-coded four-class selector match; diff check exit 0. Intentional invalid-input diagnostics and the established Godot AI exit-warning baseline may remain.

- [ ] **Step 6: Verify live through Godot**

Save all three open scenes first. For every generated class button:

1. Start a fresh run.
2. Select the class.
3. Confirm one leader spawns with the selected class ID.
4. Wait for enemies and confirm the class executes its authored attack.
5. Read game/editor logs from the current run cursor and require no new errors.
6. Stop before testing the next class.

Then use isolated PartyManager fixtures to recruit every new class, recruit duplicate Marksmen with distinct member IDs, and prove the fifth member is rejected by the four-member cap.

Restore `main.tscn` as active, save all open scenes, and leave Godot stopped/ready.

- [ ] **Step 7: Commit documentation and final evidence**

Resolve the recorded Task 4 runtime commit into handbook banners. Stage only Task 5 docs and the progress ledger, verify the cached scope, and commit:

```powershell
git commit -m "docs: document nine class catalog"
```

Record final evidence in `.superpowers/sdd/progress.md` and leave all unrelated dirty/untracked paths unstaged.

---

## Completion Criteria

- GameCatalog contains exactly nine ordered playable classes and thirteen valid traits.
- Paladin, Rogue, Frost Mage, Warlock, and Marksman each load, validate, prepare typed damage, lead, and recruit.
- Marksman is demonstrably slower, harder-hitting, and longer-range than Ranger.
- Mage uses the approved Arcane/Caster/Fire identity.
- New trait tier-two effects change intended resolved stats and duplicate classes independently contribute trait counts.
- Selector buttons are generated from catalog data, scrollable, centered at supported resolutions, and contain no class-specific path branch.
- Four-member cap and duplicate-class behavior remain unchanged.
- Full suite, import, generator/migration idempotence, source audits, broad review, and nine-class live smoke are clean.
- The user's Marksman is incorporated; every other unrelated live-project change remains preserved and unstaged.
