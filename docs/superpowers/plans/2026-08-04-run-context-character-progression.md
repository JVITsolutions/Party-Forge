# Party Forge Run Context and Character Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent profile-owned run contexts, per-character XP and core-attribute growth, leader-only upgrade queues, distance-based XP-orb sharing, and ledger visibility while preserving the current single-player Arena route.

**Architecture:** `RunContextRegistry` owns unique profile/device registrations and each `PlayerRunContext` owns one existing `PartyManager`, character progression states, actor bindings, and its leader-upgrade queue. Progression is previewed as an immutable transaction, validated through the existing stat pipeline, and committed only after its cumulative growth source is accepted. XP orbs submit idempotent spatial reward packets to a distributor that evaluates every registered context at collection time; the current `ExperienceSystem`, HUD, and level-up panel remain temporary adapters over the active single-player context.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources (`.tres`), existing `StatModifierSource`/`StatResolver`, existing profile and ledger foundations, custom unit runners, headless integration runners, and PowerShell verification on Windows.

## Global Constraints

- Execute implementation in an isolated feature worktree created with the `using-git-worktrees` skill; do not implement directly in the authoritative `main` checkout.
- Start from approved design commit `a8f02ea` or a clean descendant containing `docs/superpowers/specs/2026-08-04-plan-4a-run-context-character-progression-design.md`.
- Preserve Godot 4.7.1 and typed GDScript; add no third-party runtime dependency.
- Keep normal Arena gameplay single-player. Multiple contexts are exposed only through tests and a Developer Mode harness in Plan 4A.
- Treat stable run-player ID and profile ID as ownership identities. Controller device IDs are replaceable assignments, not ownership identities.
- Reject duplicate run-player, profile, player-slot, or assigned-device registrations without partial mutation.
- Character level, XP, fractional XP, growth history, and milestone outcomes are run-scoped and must not mutate `ProfileState`.
- Eligible characters receive the full XP packet; XP is never divided by party size.
- A leader must be alive, available, and inside the event-share radius. A follower must additionally be alive, available, and inside the squad-link radius of its own leader.
- Resolve eligibility at collection time and record every packet/context pair exactly once, including ineligible outcomes.
- Every level grants one class-authored guaranteed core attribute; levels divisible by five also grant one deterministic weighted core attribute.
- Only a leader queues upgrade choices. Followers level and gain attributes without creating cards.
- Apply cumulative growth through `StatModifierSource` and `StatResolver`; never write into `ResolvedStatSnapshot`.
- Do not persist active-run progression, implement tutorial scenes, onboarding presentation, playable split-screen, adaptive cameras, Arena wave acceleration, Adventure Mode, inventory, equipment interaction, gold, stash, extraction, or shops.
- Use `apply_patch` for authored source, resource, scene, test, and documentation edits. Do not save scenes through an open editor.
- Every production change follows RED, GREEN, focused regression, `git diff --check`, and a focused commit.
- Run full `--import` before accepting new `.tres` content. Add only the `.gd.uid` files generated for newly tracked scripts; remove verification-generated `.import` and unrelated `.uid` sidecars after validating an exact allowlist.
- The full-suite pass condition is exit code `0` plus `TEST_SUMMARY: PASS`; never hard-code a suite count.
- Existing intentional negative-test diagnostics and known shutdown leak output are not failures when the runner exits `0`, prints its required PASS marker, and emits no unexpected parse, loader, or test failure.

## Standard Verification Commands

Run from the isolated worktree:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --import
& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd
& $godot --headless --path $project --editor --quit-after 2
git diff --check
```

Expected GREEN result: all commands exit `0`; the suite prints `TEST_SUMMARY: PASS`; no unexpected `SCRIPT ERROR`, `Parse Error`, `TEST_FAILURE`, `No loader found`, or resource-load error appears; and `git diff --check` has no output.

For a focused unit suite:

```powershell
& $godot --headless --path $project --script res://tests/focused_test_runner.gd -- res://tests/unit/test_name.gd
```

## File and Responsibility Map

### Growth content and progression domain

- `scripts/progression/class_growth_definition.gd` - validates guaranteed cycles and milestone weights against the six core attributes.
- `scripts/progression/character_progression_state.gd` - copy-owned run-scoped level, XP, fractional XP, and growth history.
- `scripts/progression/character_progression_award.gd` - typed preview/commit result.
- `scripts/progression/character_progression_service.gd` - XP scaling, increasing thresholds, deterministic growth preview, and cumulative stat-source construction.
- `scripts/data/class_definition.gd` - requires one class growth resource.
- `data/progression/class_growth/*.tres` - provisional authored growth for all nine current classes.
- `data/stats/core_stats.tres` and `data/keywords/core_keywords.tres` - six visible core attributes and tooltip definitions.
- `data/classes/*.tres` - link each class to exactly one growth resource.

### Run ownership

- `scripts/run/run_context_registration_result.gd` - stable registration result codes and diagnostics.
- `scripts/run/run_join_policy.gd` - pure Arena pre-run and future Adventure safe-checkpoint admission policy.
- `scripts/run/run_context_registry.gd` - unique run-player/profile/slot/device registration and ordered context lookup.
- `scripts/run/player_run_context.gd` - profile snapshot, party, progression states, actor bindings, atomic XP commit, and leader queue.
- `scripts/party/party_manager.gd` - validated replace-by-ID member stat-source seam.

### Reward routing

- `scripts/run/reward_packet.gd` - stable packet identity, XP amount, and event position.
- `scripts/run/reward_distribution_tuning.gd` and `data/progression/reward_distribution.tres` - provisional event-share and squad-link radii.
- `scripts/run/reward_distribution_service.gd` - collection-time eligibility and idempotent multi-context resolution.
- `scripts/progression/experience_orb.gd` - pickup movement plus one distributor submission.
- `scripts/game/spawn_director.gd` - unique reward packet IDs and orb configuration.

### Compatibility and presentation

- `scripts/progression/experience_system.gd` - temporary single-player facade over the active leader state and queue.
- `scripts/party/party_actor_spawner.gd` - binds spawned follower actors to their owning context.
- `scripts/game/main.gd` - constructs the registry, active context, distributor, and compatibility adapters.
- `scripts/ui/hud.gd` - reads the facade without regaining progression ownership.
- `scripts/ui/ledger/ledger_data_provider.gd`, `scripts/ui/ledger/character_ledger.gd`, and `scripts/ui/ledger/stats_ledger_page.gd` - project level, XP, and source-backed attributes for all members.

### Verification

- `tests/unit/test_class_growth_definition.gd`
- `tests/unit/test_run_context_registry.gd`
- `tests/unit/test_character_progression.gd`
- `tests/unit/test_player_run_context.gd`
- `tests/unit/test_reward_distribution.gd`
- `tests/unit/test_experience_orb.gd`
- Existing focused suites modified where their contracts change.
- `tests/integration/run_context_harness_runner.gd` - two-profile isolation and reward-routing proof.
- `tests/integration/progression_arena_smoke_runner.gd` - production single-player launch, orb XP, leader queue, HUD, and ledger proof.
- `tests/integration/progression_24_member_runner.gd` - progressive 1/6/12/24 character timing, physics, memory, and ledger evidence.
- `docs/verification/2026-08-04-run-context-character-progression.md` - exact-head evidence and deferred hardware boundary.

---

### Task 1: Core attributes and validated class-growth content

**Files:**
- Create: `scripts/progression/class_growth_definition.gd`
- Create: `data/progression/class_growth/fighter.tres`
- Create: `data/progression/class_growth/ranger.tres`
- Create: `data/progression/class_growth/mage.tres`
- Create: `data/progression/class_growth/cleric.tres`
- Create: `data/progression/class_growth/paladin.tres`
- Create: `data/progression/class_growth/rogue.tres`
- Create: `data/progression/class_growth/frost_mage.tres`
- Create: `data/progression/class_growth/warlock.tres`
- Create: `data/progression/class_growth/marksman.tres`
- Modify: `scripts/data/class_definition.gd`
- Modify: `data/classes/fighter.tres`
- Modify: `data/classes/ranger.tres`
- Modify: `data/classes/mage.tres`
- Modify: `data/classes/cleric.tres`
- Modify: `data/classes/paladin.tres`
- Modify: `data/classes/rogue.tres`
- Modify: `data/classes/frost_mage.tres`
- Modify: `data/classes/warlock.tres`
- Modify: `data/classes/marksman.tres`
- Modify: `data/stats/core_stats.tres`
- Modify: `data/keywords/core_keywords.tres`
- Modify: `scripts/ui/ledger/ledger_data_provider.gd`
- Create test: `tests/unit/test_class_growth_definition.gd`
- Modify test: `tests/unit/test_stat_catalog.gd`
- Modify test: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Produces: `ClassGrowthDefinition.CORE_ATTRIBUTE_IDS: Array[StringName]`.
- Produces: `ClassGrowthDefinition.guaranteed_attribute_for_level(level: int) -> StringName`; level 2 is the first growth step.
- Produces: `ClassGrowthDefinition.milestone_attribute_for_roll(unit_roll: float) -> StringName`.
- Produces: `ClassGrowthDefinition.validate() -> PackedStringArray`; empty means valid.
- Produces: `ClassDefinition.growth_definition: ClassGrowthDefinition`.

- [ ] **Step 1: Write the failing growth-content suite**

Create `tests/unit/test_class_growth_definition.gd`:

```gdscript
extends RefCounted

const EXPECTED_CLASS_IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	for class_id: StringName in EXPECTED_CLASS_IDS:
		var definition := catalog.class_by_id(class_id)
		TestAssertions.truthy(definition != null, "%s class loads" % class_id, failures)
		if definition == null:
			continue
		TestAssertions.truthy(definition.growth_definition != null, "%s growth loads" % class_id, failures)
		if definition.growth_definition == null:
			continue
		TestAssertions.equal(definition.growth_definition.validate(), PackedStringArray(), "%s growth validates" % class_id, failures)
		for level: int in range(2, 14):
			TestAssertions.truthy(
				definition.growth_definition.guaranteed_attribute_for_level(level) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
				"%s level %d guaranteed attribute is core" % [class_id, level], failures,
			)
		TestAssertions.truthy(
			definition.growth_definition.milestone_attribute_for_roll(0.0) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
			"%s first weighted result is core" % class_id, failures,
		)
		TestAssertions.truthy(
			definition.growth_definition.milestone_attribute_for_roll(0.999999) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
			"%s last weighted result is core" % class_id, failures,
		)
	var invalid := ClassGrowthDefinition.new()
	invalid.guaranteed_cycle = [&"damage"]
	invalid.milestone_weights = {&"strength": 0.0}
	TestAssertions.equal(invalid.validate(), PackedStringArray([
		"PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=damage reason=unknown core attribute",
		"PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights",
	]), "invalid growth fails closed", failures)
	return failures
```

Extend `tests/unit/test_stat_catalog.gd` so every ID in `ClassGrowthDefinition.CORE_ATTRIBUTE_IDS` exists, is universal, defaults to `0.0`, uses integer formatting, and has a keyword. Extend `tests/unit/test_game_catalog.gd` so `GameCatalog.load_defaults().validate()` remains empty and removing Fighter's growth definition produces `class fighter growth definition is missing`.

- [ ] **Step 2: Run the focused suites to verify RED**

Run:

```powershell
& $godot --headless --path $project --script res://tests/focused_test_runner.gd -- res://tests/unit/test_class_growth_definition.gd res://tests/unit/test_stat_catalog.gd res://tests/unit/test_game_catalog.gd
```

Expected: nonzero exit with missing `ClassGrowthDefinition`, missing `growth_definition`, and missing core-attribute definitions.

- [ ] **Step 3: Implement the growth resource contract**

Create `scripts/progression/class_growth_definition.gd`:

```gdscript
class_name ClassGrowthDefinition
extends Resource

const CORE_ATTRIBUTE_IDS: Array[StringName] = [
	&"strength", &"dexterity", &"constitution",
	&"intelligence", &"wisdom", &"charisma",
]

@export var guaranteed_cycle: Array[StringName] = []
@export var milestone_weights: Dictionary = {}

func guaranteed_attribute_for_level(level: int) -> StringName:
	if guaranteed_cycle.is_empty() or level < 2:
		return &""
	return guaranteed_cycle[(level - 2) % guaranteed_cycle.size()]

func milestone_attribute_for_roll(unit_roll: float) -> StringName:
	var ids: Array[StringName] = []
	var total := 0.0
	for attribute_id: StringName in CORE_ATTRIBUTE_IDS:
		var weight := maxf(float(milestone_weights.get(attribute_id, 0.0)), 0.0)
		if weight <= 0.0:
			continue
		ids.append(attribute_id)
		total += weight
	if total <= 0.0:
		return &""
	var cursor := clampf(unit_roll, 0.0, 0.999999999) * total
	for attribute_id: StringName in ids:
		cursor -= float(milestone_weights[attribute_id])
		if cursor < 0.0:
			return attribute_id
	return ids.back()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if guaranteed_cycle.is_empty():
		errors.append("PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle reason=empty")
	for attribute_id: StringName in guaranteed_cycle:
		if attribute_id not in CORE_ATTRIBUTE_IDS:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=%s reason=unknown core attribute" % attribute_id)
	var positive_weight_count := 0
	for key: Variant in milestone_weights:
		var attribute_id := StringName(key)
		var weight := float(milestone_weights[key])
		if attribute_id not in CORE_ATTRIBUTE_IDS:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights value=%s reason=unknown core attribute" % attribute_id)
		elif not is_finite(weight) or weight < 0.0:
			errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights value=%s reason=invalid weight" % attribute_id)
		elif weight > 0.0:
			positive_weight_count += 1
	if positive_weight_count == 0:
		errors.append("PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights")
	return errors
```

Add `@export var growth_definition: ClassGrowthDefinition` to `ClassDefinition`; append `class %s growth definition is missing` when null and prefix nonempty growth validation errors with `class <id> `.

- [ ] **Step 4: Author all nine provisional growth resources and links**

Each `.tres` uses `res://scripts/progression/class_growth_definition.gd`. Author these exact cycles and weights, then add the corresponding growth file as an `ext_resource` and `growth_definition = ExtResource(...)` in each class resource:

| Class | Guaranteed cycle | Milestone weights |
| --- | --- | --- |
| Fighter | Strength, Constitution, Strength, Dexterity | Strength 50, Constitution 30, Dexterity 15, Wisdom 5 |
| Ranger | Dexterity, Wisdom, Dexterity, Constitution | Dexterity 50, Wisdom 25, Constitution 15, Strength 10 |
| Mage | Intelligence, Wisdom, Intelligence, Charisma | Intelligence 50, Wisdom 25, Charisma 15, Constitution 10 |
| Cleric | Wisdom, Charisma, Wisdom, Constitution | Wisdom 50, Charisma 25, Constitution 20, Strength 5 |
| Paladin | Strength, Charisma, Constitution, Wisdom | Strength 30, Charisma 25, Constitution 25, Wisdom 20 |
| Rogue | Dexterity, Charisma, Dexterity, Strength | Dexterity 50, Charisma 25, Strength 15, Constitution 10 |
| Frost Mage | Intelligence, Wisdom, Intelligence, Constitution | Intelligence 50, Wisdom 25, Constitution 20, Dexterity 5 |
| Warlock | Charisma, Intelligence, Charisma, Constitution | Charisma 45, Intelligence 30, Constitution 20, Wisdom 5 |
| Marksman | Dexterity, Strength, Dexterity, Wisdom | Dexterity 50, Strength 25, Wisdom 15, Constitution 10 |

Use these complete resource bodies; each label is the destination file name and is not part of the file:

```text
fighter.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"strength", &"constitution", &"strength", &"dexterity"])
milestone_weights = {&"strength": 50.0, &"constitution": 30.0, &"dexterity": 15.0, &"wisdom": 5.0}

ranger.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"dexterity", &"wisdom", &"dexterity", &"constitution"])
milestone_weights = {&"dexterity": 50.0, &"wisdom": 25.0, &"constitution": 15.0, &"strength": 10.0}

mage.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"intelligence", &"wisdom", &"intelligence", &"charisma"])
milestone_weights = {&"intelligence": 50.0, &"wisdom": 25.0, &"charisma": 15.0, &"constitution": 10.0}

cleric.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"wisdom", &"charisma", &"wisdom", &"constitution"])
milestone_weights = {&"wisdom": 50.0, &"charisma": 25.0, &"constitution": 20.0, &"strength": 5.0}

paladin.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"strength", &"charisma", &"constitution", &"wisdom"])
milestone_weights = {&"strength": 30.0, &"charisma": 25.0, &"constitution": 25.0, &"wisdom": 20.0}

rogue.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"dexterity", &"charisma", &"dexterity", &"strength"])
milestone_weights = {&"dexterity": 50.0, &"charisma": 25.0, &"strength": 15.0, &"constitution": 10.0}

frost_mage.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"intelligence", &"wisdom", &"intelligence", &"constitution"])
milestone_weights = {&"intelligence": 50.0, &"wisdom": 25.0, &"constitution": 20.0, &"dexterity": 5.0}

warlock.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"charisma", &"intelligence", &"charisma", &"constitution"])
milestone_weights = {&"charisma": 45.0, &"intelligence": 30.0, &"constitution": 20.0, &"wisdom": 5.0}

marksman.tres
[gd_resource type="Resource" script_class="ClassGrowthDefinition" format=3]
[ext_resource type="Script" path="res://scripts/progression/class_growth_definition.gd" id="1_growth"]
[resource]
script = ExtResource("1_growth")
guaranteed_cycle = Array[StringName]([&"dexterity", &"strength", &"dexterity", &"wisdom"])
milestone_weights = {&"dexterity": 50.0, &"strength": 25.0, &"wisdom": 15.0, &"constitution": 10.0}
```

- [ ] **Step 5: Add the six stats and keyword tooltips**

Add universal, integer-formatted, default-zero stat definitions for `strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, and `charisma`, all in UI group `attributes`. Add matching keywords with these exact explanations:

```text
Strength: A core attribute associated with physical power and forceful actions.
Dexterity: A core attribute associated with precision, agility, and quick actions.
Constitution: A core attribute associated with toughness, endurance, and survival.
Intelligence: A core attribute associated with learned magic, analysis, and complex effects.
Wisdom: A core attribute associated with awareness, discipline, and restorative power.
Charisma: A core attribute associated with presence, conviction, and influence.
```

Insert `&"attributes"` immediately after `&"overview"` in `LedgerDataProvider.GROUP_ORDER`. Do not make attributes directly alter combat formulas in Plan 4A; they are linked, source-backed character stats prepared for later abilities, items, affixes, and passive trees.

- [ ] **Step 6: Import resources and verify GREEN**

Run full import, then the three focused suites. Expected: import exit `0`, no loader error, and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 7: Commit**

```powershell
git add scripts/progression/class_growth_definition.gd data/progression/class_growth data/classes data/stats/core_stats.tres data/keywords/core_keywords.tres scripts/data/class_definition.gd scripts/ui/ledger/ledger_data_provider.gd tests/unit/test_class_growth_definition.gd tests/unit/test_stat_catalog.gd tests/unit/test_game_catalog.gd
git commit -m "feat: author class attribute growth"
```

---

### Task 2: Unique run-context registry and assignment contracts

**Files:**
- Create: `scripts/run/run_context_registration_result.gd`
- Create: `scripts/run/run_join_policy.gd`
- Create: `scripts/run/run_context_registry.gd`
- Create test: `tests/unit/test_run_context_registry.gd`

**Interfaces:**
- Consumes in this task: a structural `RefCounted` fixture exposing `run_player_id`, `player_slot_index`, and `profile_id`; Task 4 tightens these signatures to `PlayerRunContext` after that concrete type exists.
- Produces: `RunContextRegistrationResult.Code { OK, INVALID_CONTEXT, DUPLICATE_RUN_PLAYER, DUPLICATE_PROFILE, DUPLICATE_SLOT, DUPLICATE_DEVICE, ARENA_RUN_LOCKED }`.
- Produces: `RunJoinPolicy.can_accept(mode_id: StringName, roster_locked: bool, at_safe_checkpoint: bool) -> bool` for `&"arena"` and `&"adventure"`.
- Produces temporarily: `RunContextRegistry.register_context(context: RefCounted, device_id: int = -1) -> RunContextRegistrationResult`.
- Produces temporarily: `RunContextRegistry.context_for(run_player_id: StringName) -> RefCounted`.
- Produces temporarily: `RunContextRegistry.all_contexts() -> Array[RefCounted]`, sorted by `player_slot_index`.
- Produces: `RunContextRegistry.reassign_device(run_player_id: StringName, device_id: int) -> RunContextRegistrationResult` and `device_for(run_player_id: StringName) -> int`.
- Produces: `RunContextRegistry.lock_arena_roster() -> void` and `clear() -> void`.

- [ ] **Step 1: Write the failing registry suite**

Create `tests/unit/test_run_context_registry.gd` with this task-local structural fixture; it prevents Task 2 from depending on a future production class:

```gdscript
class StubRunContext extends RefCounted:
	var run_player_id: StringName
	var player_slot_index: int
	var profile_id: String

	func _init(run_id: StringName, slot: int, owned_profile_id: String) -> void:
		run_player_id = run_id
		player_slot_index = slot
		profile_id = owned_profile_id

func _context(run_id: StringName, slot: int, profile_id: String) -> RefCounted:
	return StubRunContext.new(run_id, slot, profile_id)
```

Assert:

```gdscript
var registry := RunContextRegistry.new()
var alpha := _context(&"player_alpha", 0, "profile-alpha")
TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.OK, "first context registers", failures)
TestAssertions.equal(registry.register_context(alpha, 0).code, RunContextRegistrationResult.Code.DUPLICATE_RUN_PLAYER, "run player is unique", failures)
TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-alpha"), 1).code, RunContextRegistrationResult.Code.DUPLICATE_PROFILE, "profile is unique", failures)
TestAssertions.equal(registry.register_context(_context(&"player_beta", 0, "profile-beta"), 1).code, RunContextRegistrationResult.Code.DUPLICATE_SLOT, "slot is unique", failures)
TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-beta"), 0).code, RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "assigned device is unique", failures)
TestAssertions.equal(registry.all_contexts().size(), 1, "rejections do not partially register", failures)
registry.lock_arena_roster()
TestAssertions.equal(registry.register_context(_context(&"player_beta", 1, "profile-beta"), 1).code, RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena roster rejects late joins", failures)
registry.clear()
TestAssertions.equal(registry.all_contexts().size(), 0, "clear releases registrations", failures)
```

Also assert that device `-1` is an unassigned sentinel and may appear on more than one registration, and that `all_contexts()` remains slot-sorted regardless of registration order.

After registering Alpha on device 0, reassign it to device 2 and assert `context_for(&"player_alpha")` is the identical object, device 0 becomes free, and device 2 reports Alpha. Attempt to reassign Alpha onto Beta's device and assert the duplicate-device result leaves both prior assignments unchanged.

Add pure join-policy assertions: Arena accepts only while the roster is unlocked; Adventure accepts only at an authored safe checkpoint; unknown modes always reject.

- [ ] **Step 2: Run the focused suite to verify RED**

Expected: nonzero exit because the registry/result classes do not exist.

- [ ] **Step 3: Implement stable result codes**

Create `scripts/run/run_context_registration_result.gd`:

```gdscript
class_name RunContextRegistrationResult
extends RefCounted

enum Code {
	OK,
	INVALID_CONTEXT,
	DUPLICATE_RUN_PLAYER,
	DUPLICATE_PROFILE,
	DUPLICATE_SLOT,
	DUPLICATE_DEVICE,
	ARENA_RUN_LOCKED,
}

var code := Code.OK
var message := ""

static func success() -> RunContextRegistrationResult:
	return RunContextRegistrationResult.new()

static func failure(value: Code, detail: String) -> RunContextRegistrationResult:
	var result := RunContextRegistrationResult.new()
	result.code = value
	result.message = "PARTY_FORGE_RUN_CONTEXT_ERROR code=%s reason=%s" % [Code.keys()[value], detail]
	return result

func ok() -> bool:
	return code == Code.OK
```

Create `scripts/run/run_join_policy.gd`:

```gdscript
class_name RunJoinPolicy
extends RefCounted

const ARENA: StringName = &"arena"
const ADVENTURE: StringName = &"adventure"

static func can_accept(mode_id: StringName, roster_locked: bool, at_safe_checkpoint: bool) -> bool:
	match mode_id:
		ARENA:
			return not roster_locked
		ADVENTURE:
			return at_safe_checkpoint
		_:
			return false
```

- [ ] **Step 4: Implement the registry without partial mutation**

Create `scripts/run/run_context_registry.gd` with dictionaries indexed by run-player ID, profile ID, slot, and assigned device. `register_context()` reads the three structural fields through `context.get(...)`, performs every validation before writing any dictionary, and never calls a method on the fixture. `clear()` empties all dictionaries and resets the Arena lock. `all_contexts()` duplicates values into `Array[RefCounted]` and sorts by `int(context.get("player_slot_index"))`; callers never receive an owned dictionary.

Use these exact rejection priorities after null/empty validation: Arena lock, run-player ID, profile ID, slot, assigned device. A negative device is unassigned and is never indexed.

```gdscript
class_name RunContextRegistry
extends RefCounted

var _by_run_player: Dictionary = {}
var _by_profile: Dictionary = {}
var _by_slot: Dictionary = {}
var _by_device: Dictionary = {}
var _device_by_run_player: Dictionary = {}
var _arena_roster_locked := false

func register_context(context: RefCounted, device_id: int = -1) -> RunContextRegistrationResult:
	if context == null:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "context is null")
	var run_player_id := StringName(context.get("run_player_id"))
	var profile_id := String(context.get("profile_id"))
	var slot := int(context.get("player_slot_index"))
	if run_player_id.is_empty() or profile_id.is_empty() or slot < 0:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "identity fields are invalid")
	if _arena_roster_locked:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.ARENA_RUN_LOCKED, "Arena roster is locked")
	if _by_run_player.has(run_player_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_RUN_PLAYER, "run player %s already registered" % run_player_id)
	if _by_profile.has(profile_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_PROFILE, "profile %s already registered" % profile_id)
	if _by_slot.has(slot):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_SLOT, "slot %d already registered" % slot)
	if device_id >= 0 and _by_device.has(device_id):
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "device %d already assigned" % device_id)
	_by_run_player[run_player_id] = context
	_by_profile[profile_id] = context
	_by_slot[slot] = context
	if device_id >= 0:
		_by_device[device_id] = context
		_device_by_run_player[run_player_id] = device_id
	return RunContextRegistrationResult.success()

func context_for(run_player_id: StringName) -> RefCounted:
	return _by_run_player.get(run_player_id) as RefCounted

func all_contexts() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for value: Variant in _by_run_player.values():
		result.append(value as RefCounted)
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		return int(left.get("player_slot_index")) < int(right.get("player_slot_index")))
	return result

func lock_arena_roster() -> void:
	_arena_roster_locked = true

func is_arena_roster_locked() -> bool:
	return _arena_roster_locked

func reassign_device(run_player_id: StringName, device_id: int) -> RunContextRegistrationResult:
	if not _by_run_player.has(run_player_id) or device_id < 0:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.INVALID_CONTEXT, "device reassignment is invalid")
	if _by_device.has(device_id) and _by_device[device_id] != _by_run_player[run_player_id]:
		return RunContextRegistrationResult.failure(RunContextRegistrationResult.Code.DUPLICATE_DEVICE, "device %d already assigned" % device_id)
	var previous_device := int(_device_by_run_player.get(run_player_id, -1))
	if previous_device >= 0:
		_by_device.erase(previous_device)
	_by_device[device_id] = _by_run_player[run_player_id]
	_device_by_run_player[run_player_id] = device_id
	return RunContextRegistrationResult.success()

func device_for(run_player_id: StringName) -> int:
	return int(_device_by_run_player.get(run_player_id, -1))

func clear() -> void:
	_by_run_player.clear()
	_by_profile.clear()
	_by_slot.clear()
	_by_device.clear()
	_device_by_run_player.clear()
	_arena_roster_locked = false
```

- [ ] **Step 5: Verify GREEN and commit**

Run the focused suite, then:

```powershell
git add scripts/run/run_context_registration_result.gd scripts/run/run_join_policy.gd scripts/run/run_context_registry.gd tests/unit/test_run_context_registry.gd
git commit -m "feat: add unique run context registry"
```

---

### Task 3: Transactional per-character progression

**Files:**
- Create: `scripts/progression/character_progression_state.gd`
- Create: `scripts/progression/character_progression_award.gd`
- Create: `scripts/progression/character_progression_service.gd`
- Modify: `scripts/party/party_manager.gd`
- Create test: `tests/unit/test_character_progression.gd`
- Modify test: `tests/unit/test_party_manager.gd`
- Modify test: `tests/unit/test_progression.gd`

**Interfaces:**
- Consumes: `ExperienceTuning.requirement_for_level(level: int) -> int` and Task 1 growth resources.
- Produces: `CharacterProgressionState.fresh(member_id: int, tuning: ExperienceTuning) -> CharacterProgressionState`, `copy() -> CharacterProgressionState`, `to_snapshot() -> Dictionary`, and `from_snapshot(snapshot: Dictionary, tuning: ExperienceTuning) -> CharacterProgressionState`.
- Produces: `CharacterProgressionService.preview_award(current: CharacterProgressionState, growth: ClassGrowthDefinition, tuning: ExperienceTuning, base_amount: int, multiplier_percent: int, run_seed: int, run_player_id: StringName, member_id: int) -> CharacterProgressionAward` without mutating its input.
- Produces: `CharacterProgressionService.source_for(member_id: int, state: CharacterProgressionState) -> StatModifierSource`.
- Produces: `PartyManager.replace_member_source(member_id: int, source: StatModifierSource) -> bool`.

- [ ] **Step 1: Write failing state, threshold, overflow, growth, and determinism tests**

Create `tests/unit/test_character_progression.gd`. Cover these exact cases:

```gdscript
var fighter := load("res://data/progression/class_growth/fighter.tres") as ClassGrowthDefinition
var tuning := load("res://data/progression/default_experience.tres") as ExperienceTuning
var initial := CharacterProgressionState.fresh(1, tuning)
var award := CharacterProgressionService.preview_award(initial, fighter, tuning, 94, 100, 1337, &"player_one", 1)
TestAssertions.equal(initial.level, 1, "preview does not mutate input", failures)
TestAssertions.equal(award.next_state.level, 4, "94 XP reaches level four", failures)
TestAssertions.equal(award.next_state.experience, 0, "exact multi-level thresholds preserve zero overflow", failures)
TestAssertions.equal(award.gained_levels, [2, 3, 4], "all earned levels are ordered", failures)
TestAssertions.equal(award.next_state.experience_required, 62, "next requirement is stored for level four", failures)
TestAssertions.equal(award.next_state.core_attribute_gains[&"strength"], 2, "fighter gains strength at levels two and four", failures)
TestAssertions.equal(award.next_state.core_attribute_gains[&"constitution"], 1, "fighter gains constitution at level three", failures)
```

Also test 150% fractional carry, one milestone at level 5, identical milestone outcomes for identical seed/context/member/level, isolation when another context or member is evaluated first, changed outcome stream when stable identity changes, invalid growth failure without a next state, nonpositive XP as a successful no-op, cumulative source IDs/owner IDs, and source modifiers for all six attributes. Round-trip a state through `to_snapshot()`/`from_snapshot()` and require exact equality; reject a snapshot with a mismatched member ID, nonpositive level, XP outside `[0, experience_required)`, an unknown attribute, or a milestone level not divisible by five.

Extend `test_party_manager.gd` to prove `replace_member_source()` replaces rather than appends a stable source ID, rejects an unknown stat without changing the previous resolved values, and emits exactly one `stats_changed(member_id)` on success.

- [ ] **Step 2: Run focused tests to verify RED**

Run `test_character_progression.gd`, `test_party_manager.gd`, and `test_progression.gd`. Expected: missing progression types and replace seam.

- [ ] **Step 3: Implement copy-owned progression state and award result**

`CharacterProgressionState` contains exactly: `member_id`, `level = 1`, `experience = 0`, `experience_required`, `fractional_experience = 0.0`, `core_attribute_gains`, `guaranteed_growth_history`, and `milestone_outcomes`. `fresh()` seeds every core attribute to zero and stores `tuning.requirement_for_level(1)`. `copy()` deep-copies both arrays and dictionaries. `to_snapshot()` emits only JSON-safe primitives; `from_snapshot()` validates every field, recomputes the required XP from the supplied tuning, requires the stored value to match, and returns null on any invalid field. These seams are deterministic run-save preparation only; no Plan 4A caller writes them to ProfileState or disk.

`CharacterProgressionAward` contains `next_state`, `gained_levels: Array[int]`, `attribute_delta: Dictionary`, `milestone_outcomes: Dictionary`, and `error`. `ok()` returns true only when `next_state != null` and `error.is_empty()`.

Use these exact declarations and copy contract:

```gdscript
# scripts/progression/character_progression_state.gd
class_name CharacterProgressionState
extends RefCounted

const SNAPSHOT_VERSION := 1

var member_id := 0
var level := 1
var experience := 0
var experience_required := 1
var fractional_experience := 0.0
var core_attribute_gains: Dictionary = {}
var guaranteed_growth_history: Array[StringName] = []
var milestone_outcomes: Dictionary = {}

static func fresh(id: int, tuning: ExperienceTuning) -> CharacterProgressionState:
	if id <= 0 or tuning == null or not tuning.validate().is_empty():
		return null
	var state := CharacterProgressionState.new()
	state.member_id = id
	state.experience_required = tuning.requirement_for_level(1)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		state.core_attribute_gains[attribute_id] = 0
	return state

func copy() -> CharacterProgressionState:
	var result := CharacterProgressionState.new()
	result.member_id = member_id
	result.level = level
	result.experience = experience
	result.experience_required = experience_required
	result.fractional_experience = fractional_experience
	result.core_attribute_gains = core_attribute_gains.duplicate(true)
	result.guaranteed_growth_history = guaranteed_growth_history.duplicate()
	result.milestone_outcomes = milestone_outcomes.duplicate(true)
	return result

func to_snapshot() -> Dictionary:
	var history: Array[String] = []
	for attribute_id: StringName in guaranteed_growth_history:
		history.append(String(attribute_id))
	var milestones: Dictionary = {}
	for milestone_level: Variant in milestone_outcomes:
		milestones[str(int(milestone_level))] = String(milestone_outcomes[milestone_level])
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[String(attribute_id)] = int(core_attribute_gains.get(attribute_id, 0))
	return {
		"version": SNAPSHOT_VERSION,
		"member_id": member_id,
		"level": level,
		"experience": experience,
		"experience_required": experience_required,
		"fractional_experience": fractional_experience,
		"core_attribute_gains": attributes,
		"guaranteed_growth_history": history,
		"milestone_outcomes": milestones,
	}
```

`from_snapshot()` accepts only `SNAPSHOT_VERSION`, requires exact dictionary/array field types, converts attribute strings back to `StringName`, rejects unknown/missing core IDs and negative counts, requires `level >= 1`, finite fractional XP in `[0, 1)`, `experience >= 0`, `experience < tuning.requirement_for_level(level)`, and exact stored `experience_required`. It converts milestone keys to integers, requires every key to be positive and divisible by five, and requires every history/milestone value to be a core attribute. It returns a newly populated state or null; it never normalizes corrupt data.

```gdscript
# scripts/progression/character_progression_award.gd
class_name CharacterProgressionAward
extends RefCounted

var next_state: CharacterProgressionState
var gained_levels: Array[int] = []
var attribute_delta: Dictionary = {}
var milestone_outcomes: Dictionary = {}
var error := ""

func ok() -> bool:
	return next_state != null and error.is_empty()

static func failure(detail: String) -> CharacterProgressionAward:
	var result := CharacterProgressionAward.new()
	result.error = "PARTY_FORGE_PROGRESSION_ERROR reason=%s" % detail
	return result
```

- [ ] **Step 4: Implement deterministic preview logic**

Implement `preview_award()` with this transaction order:

```gdscript
var next := current.copy()
var scaled := float(maxi(base_amount, 0)) * float(clampi(multiplier_percent, 100, 1000)) / 100.0 + next.fractional_experience
var whole := floori(scaled)
next.fractional_experience = scaled - float(whole)
next.experience += whole
while next.experience >= tuning.requirement_for_level(next.level):
	next.experience -= tuning.requirement_for_level(next.level)
	next.level += 1
	next.experience_required = tuning.requirement_for_level(next.level)
	award.gained_levels.append(next.level)
	var guaranteed := growth.guaranteed_attribute_for_level(next.level)
	_increment_attribute(next, award, guaranteed)
	next.guaranteed_growth_history.append(guaranteed)
	if next.level % 5 == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|%s|%d|%d" % [run_seed, run_player_id, member_id, next.level])
		var milestone := growth.milestone_attribute_for_roll(rng.randf())
		_increment_attribute(next, award, milestone)
		next.milestone_outcomes[next.level] = milestone
		award.milestone_outcomes[next.level] = milestone
award.next_state = next
```

Validate null/current-member mismatch, tuning, and growth before copying. `source_for()` returns one stable `character_growth_<member_id>` source with six FLAT modifiers containing cumulative totals and label `Class Growth`.

Use this exact source construction and increment helper:

```gdscript
static func source_for(member_id: int, state: CharacterProgressionState) -> StatModifierSource:
	if state == null or member_id <= 0 or state.member_id != member_id:
		return null
	var source_id := StringName("character_growth_%d" % member_id)
	var modifiers: Array[StatModifier] = []
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		modifiers.append(StatModifier.create(
			attribute_id,
			StatModifier.Operation.FLAT,
			float(state.core_attribute_gains.get(attribute_id, 0)),
			source_id,
			"Class Growth",
		))
	return StatModifierSource.create(source_id, &"character_growth", "Class Growth", member_id, modifiers)

static func _increment_attribute(state: CharacterProgressionState, award: CharacterProgressionAward, attribute_id: StringName) -> void:
	state.core_attribute_gains[attribute_id] = int(state.core_attribute_gains.get(attribute_id, 0)) + 1
	award.attribute_delta[attribute_id] = int(award.attribute_delta.get(attribute_id, 0)) + 1
```

- [ ] **Step 5: Add atomic replace-by-ID to PartyManager**

`replace_member_source()` first resolves the member and validates the entire proposed source through `StatResolver.validate_sources`. Only after validation succeeds does it call the existing member replacement seam and invalidate that member. It must not emit or mutate on failure.

- [ ] **Step 6: Migrate the old progression unit suite to the new domain API**

Keep its existing XP threshold, overflow, multiplier, and ordered-level assertions, but perform them through `CharacterProgressionService.preview_award()` instead of an unconfigured standalone `ExperienceSystem`. Leave the upgrade-choice generation assertions unchanged.

- [ ] **Step 7: Verify GREEN and commit**

```powershell
git add scripts/progression/character_progression_state.gd scripts/progression/character_progression_award.gd scripts/progression/character_progression_service.gd scripts/party/party_manager.gd tests/unit/test_character_progression.gd tests/unit/test_party_manager.gd tests/unit/test_progression.gd
git commit -m "feat: add transactional character progression"
```

---

### Task 4: Profile-owned player context and leader upgrade queue

**Files:**
- Create: `scripts/run/player_run_context.gd`
- Create test: `tests/unit/test_player_run_context.gd`
- Modify test: `tests/unit/test_run_context_registry.gd`

**Interfaces:**
- Consumes: Tasks 1-3, an initialized `PartyManager`, and a valid `ProfileState` snapshot.
- Produces: `PlayerRunContext.configure(run_player_id_value: StringName, slot: int, profile: ProfileState, run_seed_value: int, manager: PartyManager, experience_multiplier: int) -> PackedStringArray`.
- Produces: `progression_for(member_id: int) -> CharacterProgressionState` as a defensive copy.
- Produces: `award_experience(member_id: int, amount: int) -> CharacterProgressionAward`.
- Produces: `pending_leader_levels() -> Array[int]`, `current_pending_level() -> int`, and `consume_pending_leader_level() -> bool`.
- Produces: `bind_actor(member_id: int, actor: Node3D) -> bool`, `actor_for(member_id: int) -> Node3D`, and `member_is_available(member_id: int) -> bool`.
- Tightens Task 2: registry arguments/returns become `PlayerRunContext` and `Array[PlayerRunContext]` with no behavioral change.

- [ ] **Step 1: Write the failing context suite**

Build a Fighter-led party with a Ranger follower. Assert that configuration creates level-one states for both, returned profile/progression values are copy-isolated, actor bindings reject unknown members, and one 20-XP leader award:

- advances only the leader to level 2;
- adds its Fighter growth source through `PartyManager`;
- queues exactly `[2]`;
- emits ordered `member_level_ready(1, 2)` and one `progression_changed(1)`;
- leaves the follower at level 1.

Award the follower 20 XP and assert it grows as Ranger, queues no level, and cannot change the leader queue. Replace the Fighter growth resource temporarily with one whose guaranteed cycle contains an unknown stat, assert the award fails, then assert level, XP, attributes, queue, stat source, and signal counts are unchanged.

- [ ] **Step 2: Run the focused suite to verify RED**

Expected: nonzero exit because `PlayerRunContext` is missing.

- [ ] **Step 3: Implement context configuration and member synchronization**

`PlayerRunContext` is a `RefCounted` with signals `progression_changed(member_id: int)` and `member_level_ready(member_id: int, level: int)`. It stores private copies of profile and progression state, exposes `profile_snapshot` and `progression_for()` through defensive copies, and keeps the live `PartyManager` reference as its owned run squad.

During `configure()`, validate nonempty IDs, nonnegative slot, valid profile, nonnull initialized party, positive run seed, and experience multiplier 100-1000. Create a fresh state for every existing member and connect `party.member_added` so recruits receive state exactly once. Configuration returns stable `PARTY_FORGE_RUN_CONTEXT_ERROR field=<field>` strings and changes no fields when validation fails.

- [ ] **Step 4: Implement atomic XP commit and leader queues**

`award_experience()` previews against the member's current state and class growth. If level gains exist, build the cumulative source and call `party.replace_member_source()` before replacing the stored state. On source failure return `PARTY_FORGE_PROGRESSION_ERROR member=<id> reason=stat source rejected` and change nothing. On success, store the copied next state, append earned levels only when `member.is_leader`, emit each earned level in ascending order, then emit one progression change.

The queue getter returns a duplicate. Consumption removes only the first leader level and returns false for an empty queue.

The core commit methods are:

```gdscript
func progression_for(member_id: int) -> CharacterProgressionState:
	var state := _progression_by_member.get(member_id) as CharacterProgressionState
	return state.copy() if state != null else null

func award_experience(member_id: int, amount: int) -> CharacterProgressionAward:
	var member := party.member_by_id(member_id) if party != null else null
	var current := _progression_by_member.get(member_id) as CharacterProgressionState
	if member == null or current == null or member.class_definition == null:
		return CharacterProgressionAward.failure("member=%d unavailable" % member_id)
	var award := CharacterProgressionService.preview_award(
		current, member.class_definition.growth_definition, experience_tuning,
		amount, experience_multiplier_percent, run_seed, run_player_id, member_id,
	)
	if not award.ok():
		return award
	if not award.gained_levels.is_empty():
		var source := CharacterProgressionService.source_for(member_id, award.next_state)
		if source == null or not party.replace_member_source(member_id, source):
			return CharacterProgressionAward.failure("member=%d stat source rejected" % member_id)
	_progression_by_member[member_id] = award.next_state.copy()
	if member.is_leader:
		_pending_leader_levels.append_array(award.gained_levels)
	for earned_level: int in award.gained_levels:
		member_level_ready.emit(member_id, earned_level)
	progression_changed.emit(member_id)
	return award

func pending_leader_levels() -> Array[int]:
	return _pending_leader_levels.duplicate()

func current_pending_level() -> int:
	return _pending_leader_levels[0] if not _pending_leader_levels.is_empty() else 0

func consume_pending_leader_level() -> bool:
	if _pending_leader_levels.is_empty():
		return false
	_pending_leader_levels.pop_front()
	return true
```

- [ ] **Step 5: Implement actor binding and availability**

Store actor bindings as `WeakRef` values. `bind_actor()` also sets `party_forge_run_player_id` and `party_forge_member_id` metadata so later combat/reward records can resolve stable ownership without using proximity or controller state. `actor_for()` removes and returns null for freed actors. `member_is_available()` requires a bound actor, a `HealthComponent` child, and both `is_dead == false` and `is_downed == false`. `member_position()` returns `{ "valid": true, "position": Vector3 }` using `global_position` in-tree and `position` outside-tree; otherwise `{ "valid": false }`.

```gdscript
func bind_actor(member_id: int, actor: Node3D) -> bool:
	if party == null or party.member_by_id(member_id) == null or actor == null:
		return false
	actor.set_meta("party_forge_run_player_id", run_player_id)
	actor.set_meta("party_forge_member_id", member_id)
	_actor_by_member[member_id] = weakref(actor)
	return true

func actor_for(member_id: int) -> Node3D:
	var reference := _actor_by_member.get(member_id) as WeakRef
	var actor := reference.get_ref() as Node3D if reference != null else null
	if actor == null:
		_actor_by_member.erase(member_id)
	return actor

func member_is_available(member_id: int) -> bool:
	var actor := actor_for(member_id)
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent if actor != null else null
	return health != null and not health.is_dead and not health.is_downed

func member_position(member_id: int) -> Dictionary:
	var actor := actor_for(member_id)
	if actor == null:
		return {"valid": false}
	return {"valid": true, "position": actor.global_position if actor.is_inside_tree() else actor.position}
```

- [ ] **Step 6: Replace the registry test stub with real configured contexts**

Change the three registry signatures from `RefCounted` to `PlayerRunContext`, replace structural `get(...)` calls with typed properties, and replace the Task 2 stub fixtures with valid ProfileState/PartyManager/PlayerRunContext fixtures. Preserve every uniqueness and atomicity assertion.

- [ ] **Step 7: Verify GREEN and commit**

```powershell
git add scripts/run/player_run_context.gd tests/unit/test_player_run_context.gd tests/unit/test_run_context_registry.gd
git commit -m "feat: own progression by player run context"
```

---

### Task 5: Idempotent distance-based reward distribution

**Files:**
- Create: `scripts/run/reward_packet.gd`
- Create: `scripts/run/reward_distribution_tuning.gd`
- Create: `scripts/run/reward_distribution_service.gd`
- Create: `data/progression/reward_distribution.tres`
- Create test: `tests/unit/test_reward_distribution.gd`

**Interfaces:**
- Consumes: `RunContextRegistry.all_contexts()` and Task 4 actor/progression methods.
- Produces: `RewardPacket.create(packet_id: StringName, experience: int, position: Vector3) -> RewardPacket`.
- Produces: `RewardDistributionService.configure(registry, tuning) -> PackedStringArray`.
- Produces: `RewardDistributionService.distribute(packet: RewardPacket) -> Dictionary` with `awarded_members`, `skipped_contexts`, and `errors`.
- Produces: `RewardDistributionService.has_resolved(packet_id: StringName, run_player_id: StringName) -> bool`.

- [ ] **Step 1: Write the failing reward matrix**

Create two contexts with bound leader/follower `Node3D` fixtures, each containing a configured `HealthComponent`. Use tuning `leader_event_share_radius = 18.0` and `follower_squad_link_radius = 14.0`. Test:

- leader at 17.99 gets full XP;
- leader at exactly 18.0 gets full XP;
- leader at 18.01 and all followers in that context get none;
- follower at exactly 14.0 from its own qualified leader gets full XP;
- follower at 14.01 gets none;
- dead/downed follower gets none;
- follower revived before distribution qualifies;
- every eligible member gets the full packet value rather than a split;
- retrying the same packet awards nothing;
- an ineligible packet/context pair remains resolved after actors move;
- one context's invalid member does not block another context;
- null/empty packet fails without marking any pair.

- [ ] **Step 2: Run the focused suite to verify RED**

Expected: missing reward types.

- [ ] **Step 3: Implement packet and tuning validation**

`RewardPacket` owns immutable-by-convention fields `packet_id`, `experience`, and `world_position`; `validate()` rejects empty ID and negative XP. `RewardDistributionTuning` exports positive finite radii. Create `data/progression/reward_distribution.tres` with `18.0` leader-event radius and `14.0` follower-link radius.

```gdscript
# scripts/run/reward_packet.gd
class_name RewardPacket
extends RefCounted

var packet_id: StringName
var experience := 0
var world_position := Vector3.ZERO

static func create(id: StringName, experience_value: int, position: Vector3) -> RewardPacket:
	var packet := RewardPacket.new()
	packet.packet_id = id
	packet.experience = experience_value
	packet.world_position = position
	return packet

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if packet_id.is_empty():
		errors.append("PARTY_FORGE_REWARD_ERROR field=packet_id")
	if experience < 0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=experience")
	return errors

# scripts/run/reward_distribution_tuning.gd
class_name RewardDistributionTuning
extends Resource

@export var leader_event_share_radius := 18.0
@export var follower_squad_link_radius := 14.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(leader_event_share_radius) or leader_event_share_radius <= 0.0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=leader_event_share_radius")
	if not is_finite(follower_squad_link_radius) or follower_squad_link_radius <= 0.0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=follower_squad_link_radius")
	return errors
```

- [ ] **Step 4: Implement collection-time distribution**

For each slot-sorted context, compute key `<packet_id>|<run_player_id>`. Skip an already resolved key. Mark the key resolved before evaluating actors so retries cannot turn an ineligible collection-time result into a later award. Require the leader actor to be available and at `distance_to(packet.world_position) <= leader_event_share_radius`. Award the full XP to the leader, then independently award each available follower whose position is at `distance_to(leader_position) <= follower_squad_link_radius`.

Return member keys as `<run_player_id>:<member_id>` in `awarded_members`. Append stable context IDs to `skipped_contexts`; append award failures to `errors`. Do not stop iterating when one context/member fails.

Use this resolution structure; `_award()` calls `context.award_experience(member_id, packet.experience)`, appends the stable member key on success, and appends the award error on failure:

```gdscript
class_name RewardDistributionService
extends RefCounted

var registry: RunContextRegistry
var tuning: RewardDistributionTuning
var _resolved_pairs: Dictionary = {}

func configure(context_registry: RunContextRegistry, distribution_tuning: RewardDistributionTuning) -> PackedStringArray:
	var errors := PackedStringArray()
	if context_registry == null:
		errors.append("PARTY_FORGE_REWARD_ERROR field=registry")
	if distribution_tuning == null:
		errors.append("PARTY_FORGE_REWARD_ERROR field=tuning")
	elif not distribution_tuning.validate().is_empty():
		errors.append_array(distribution_tuning.validate())
	if errors.is_empty():
		registry = context_registry
		tuning = distribution_tuning
		_resolved_pairs.clear()
	return errors

func distribute(packet: RewardPacket) -> Dictionary:
	var report := {"awarded_members": PackedStringArray(), "skipped_contexts": PackedStringArray(), "errors": PackedStringArray()}
	if registry == null or tuning == null or packet == null or not packet.validate().is_empty():
		(report.errors as PackedStringArray).append("PARTY_FORGE_REWARD_ERROR reason=invalid distribution request")
		return report
	for context: PlayerRunContext in registry.all_contexts():
		var pair_key := "%s|%s" % [packet.packet_id, context.run_player_id]
		if _resolved_pairs.has(pair_key):
			continue
		_resolved_pairs[pair_key] = true
		var leader_id := context.party.members[0].member_id if context.party != null and not context.party.members.is_empty() else 0
		var leader_position := context.member_position(leader_id)
		if not context.member_is_available(leader_id) or not bool(leader_position.get("valid", false)):
			(report.skipped_contexts as PackedStringArray).append(String(context.run_player_id))
			continue
		var leader_world_position := leader_position.position as Vector3
		if leader_world_position.distance_to(packet.world_position) > tuning.leader_event_share_radius:
			(report.skipped_contexts as PackedStringArray).append(String(context.run_player_id))
			continue
		_award(context, leader_id, packet, report)
		for member: PartyMemberState in context.party.members:
			if member.is_leader or not context.member_is_available(member.member_id):
				continue
			var follower_position := context.member_position(member.member_id)
			if bool(follower_position.get("valid", false)) and (follower_position.position as Vector3).distance_to(leader_world_position) <= tuning.follower_squad_link_radius:
				_award(context, member.member_id, packet, report)
	return report

func has_resolved(packet_id: StringName, run_player_id: StringName) -> bool:
	return _resolved_pairs.has("%s|%s" % [packet_id, run_player_id])

func _award(context: PlayerRunContext, member_id: int, packet: RewardPacket, report: Dictionary) -> void:
	var award := context.award_experience(member_id, packet.experience)
	if award.ok():
		(report.awarded_members as PackedStringArray).append("%s:%d" % [context.run_player_id, member_id])
	else:
		(report.errors as PackedStringArray).append(award.error)
```

- [ ] **Step 5: Verify GREEN and commit**

```powershell
git add scripts/run/reward_packet.gd scripts/run/reward_distribution_tuning.gd scripts/run/reward_distribution_service.gd data/progression/reward_distribution.tres tests/unit/test_reward_distribution.gd
git commit -m "feat: distribute spatial experience rewards"
```

---

### Task 6: Route XP-orb collection through reward packets

**Files:**
- Modify: `scripts/progression/experience_orb.gd`
- Modify: `scripts/game/spawn_director.gd`
- Create test: `tests/unit/test_experience_orb.gd`
- Modify test: `tests/unit/test_spawn_schedule.gd`
- Modify test: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: `RewardDistributionService.distribute()` from Task 5.
- Produces: `ExperienceOrb.configure(experience_value, packet_id, target_leader, distributor, radius_multiplier)`.
- Produces: SpawnDirector packet IDs `xp_<run_seed>_<reward_sequence>`.

- [ ] **Step 1: Write failing orb-routing regressions**

Update the orb suite to configure a real distributor/context. Preserve tests for attraction radius, no movement outside radius, acceleration, collection radius, pickup multiplier, and one-time collection. Replace the old direct-system assertion with:

```gdscript
orb.configure(20, &"xp_1337_1", leader, distributor, 1.0)
orb.position = leader.position
orb.advance_collection(0.016)
TestAssertions.equal(context.progression_for(1).level, 2, "collected orb routes through context", failures)
TestAssertions.truthy(distributor.has_resolved(&"xp_1337_1", &"player_one"), "packet/context is recorded", failures)
orb.advance_collection(0.016)
TestAssertions.equal(context.progression_for(1).level, 2, "collected orb cannot award twice", failures)
```

Extend SpawnDirector tests to prove sequential drops use distinct IDs, the same run seed produces the same sequence after fresh configuration, and pickup-radius resync still reaches live orbs.

- [ ] **Step 2: Run focused suites to verify RED**

Expected: configure signature mismatch and missing packet IDs.

- [ ] **Step 3: Replace the orb's global ExperienceSystem dependency**

Remove `experience_system`. Store `packet_id` and `reward_distributor`. `_collect()` sets `collected` first, creates `RewardPacket.create(packet_id, value, current orb position)`, calls the distributor once, and queues free. Invalid distributors still consume the physical orb and emit one stable `PARTY_FORGE_REWARD_ERROR packet=<id> reason=distributor unavailable` diagnostic; they never fall back to global XP.

- [ ] **Step 4: Make SpawnDirector create deterministic unique packet IDs**

Replace its ExperienceSystem parameter/property with `RewardDistributionService`, reset `_reward_sequence = 0` in `configure()`, increment per reward drop, and call:

```gdscript
var packet_id := StringName("xp_%d_%d" % [run_seed, _reward_sequence])
orb.call("configure", experience, packet_id, leader, reward_distributor, pickup_radius_multiplier)
```

Keep the orb attracted to the current active leader; reward sharing is evaluated by the distributor and does not change movement targeting.

- [ ] **Step 5: Verify GREEN and commit**

```powershell
git add scripts/progression/experience_orb.gd scripts/game/spawn_director.gd tests/unit/test_experience_orb.gd tests/unit/test_spawn_schedule.gd tests/unit/test_main_wiring.gd
git commit -m "refactor: route experience orbs by run context"
```

---

### Task 7: Preserve the single-player Arena through context adapters

**Files:**
- Modify: `scripts/progression/experience_system.gd`
- Modify: `scripts/party/party_actor_spawner.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scripts/ui/hud.gd`
- Modify: `scripts/ui/developer_mode_badge.gd`
- Modify: `tests/unit/test_progression.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Create test: `tests/unit/test_party_actor_spawner.gd`
- Create test: `tests/unit/test_developer_mode_badge.gd`

**Interfaces:**
- Consumes: Tasks 2-6.
- Produces: `ExperienceSystem.configure_context(context: PlayerRunContext, leader_member_id: int) -> void`.
- Produces: legacy getters `level`, `experience`, `pending_levels`, `pending_level_numbers`, `experience_for_next_level()`, `current_pending_level()`, and `consume_pending_level()` backed by the active context.
- Produces: `PartyActorSpawner.initialize(..., owner_context: PlayerRunContext = null)`.
- Produces: `PartyForgeMain.run_context_registry`, `active_run_context`, and `reward_distribution_service`.

- [ ] **Step 1: Write failing adapter and wiring assertions**

Update `test_progression.gd` to configure an ExperienceSystem with a real context and assert its properties mirror the leader state/queue after `add_experience(20)`. Extend main wiring assertions to require registry/context/distributor variables, profile-derived context setup, leader binding, SpawnDirector distributor configuration, and no direct orb/global ExperienceSystem route. Extend spawner tests to assert a spawned follower is bound to its owning context.

Extend DeveloperModeBadge tests so player mode hides reward tuning, while Developer Mode includes exact `XP SHARE 18.0m` and `SQUAD LINK 14.0m` diagnostics.

- [ ] **Step 2: Run focused suites to verify RED**

Expected: missing adapter configuration and main/spawner context wiring.

- [ ] **Step 3: Convert ExperienceSystem into a compatibility facade**

Keep it as a Node because the scene already owns one. Remove stored mutable progression values. Bind/unbind `PlayerRunContext.member_level_ready`; proxy `level_ready` only for the configured leader member. `add_experience()` calls `context.award_experience(leader_member_id, amount)`. Every public getter returns safe defaults when unconfigured. `configure_multiplier()` stores the clamped percent only until the next `PlayerRunContext.configure()`; PartyForgeMain passes the same multiplier to both, avoiding a second scaling pass.

- [ ] **Step 4: Bind actors during production spawning**

After the leader is configured and added, call `active_run_context.bind_actor(leader_member_id, leader)`. Give PartyActorSpawner the context and call `bind_actor(member.member_id, companion)` only after the companion enters its actor container. A binding failure frees the just-created companion and reports `PARTY_FORGE_RUN_CONTEXT_ERROR member=<id> reason=actor bind failed`.

- [ ] **Step 5: Construct the active single-player ownership graph in PartyForgeMain**

At run start:

1. clear/create `RunContextRegistry`;
2. initialize the existing PartyManager;
3. configure one `PlayerRunContext` with run-player ID `player_1`, slot `0`, a defensive copy of `active_profile()`, run seed, party, and run-rules XP multiplier;
4. register it with device `-1` until the later lobby owns device claims;
5. lock the Arena roster;
6. configure the ExperienceSystem facade;
7. bind the leader and initialize the spawner;
8. configure `RewardDistributionService` from `res://data/progression/reward_distribution.tres` and give it to SpawnDirector;
9. leave `PartyForgeMain.party_manager` pointing at `active_run_context.party` for compatibility.

If context setup or registration fails, free the newly spawned leader if present, leave `run_started == false`, show the front end, and emit the stable registration/configuration diagnostic. Do not partially start GameRun.

Pass the loaded reward tuning to `DeveloperModeBadge.configure(snapshot, reward_tuning)`. The badge appends the two distance diagnostics only when Developer Mode is active; normal player mode remains hidden.

- [ ] **Step 6: Keep level-up presentation leader-only**

Retain `_on_level_ready`, `_present_pending_level`, and the existing panel flow through the ExperienceSystem facade. Because only the active context leader queue is exposed, follower progression cannot open the panel. Consuming a choice removes exactly one leader queue entry; multiple earned levels remain FIFO.

- [ ] **Step 7: Verify focused GREEN and commit**

```powershell
git add scripts/progression/experience_system.gd scripts/party/party_actor_spawner.gd scripts/game/main.gd scripts/ui/hud.gd scripts/ui/developer_mode_badge.gd tests/unit/test_progression.gd tests/unit/test_main_wiring.gd tests/unit/test_party_actor_spawner.gd tests/unit/test_developer_mode_badge.gd
git commit -m "feat: integrate active player run context"
```

---

### Task 8: Project independent progression into the ledger

**Files:**
- Modify: `scripts/ui/ledger/ledger_data_provider.gd`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `scripts/game/main.gd`
- Modify test: `tests/unit/test_ledger_data_provider.gd`
- Modify test: `tests/unit/test_stats_ledger_page.gd`
- Modify test: `tests/unit/test_character_ledger_foundation.gd`
- Modify integration: `tests/integration/ledger_24_member_runner.gd`

**Interfaces:**
- Consumes: `Callable(member_id) -> CharacterProgressionState` supplied by the owning context.
- Produces: member-row fields `character_level`, `experience`, `experience_required`, `experience_fraction`, `guaranteed_growth_count`, and `milestone_count`.
- Produces: visible Level/XP header plus existing source-backed attribute rows and detail breakdown.

- [ ] **Step 1: Write failing provider/UI assertions**

Extend provider tests with two independently leveled members and assert their row values do not mirror each other. Assert each core attribute appears in `stat_rows()` without Show All, has a `Class Growth` detail source after leveling, and retains its keyword explanation.

Extend Stats page tests so the selected header contains `Level 3`, `XP 7 / 44`, and the health/downed/dead text still works. Extend the 24-member runner so member 1 and member 24 show distinct level/XP projections and selection/focus/scroll behavior remains valid at 1080p, 1440p, and 4K.

- [ ] **Step 2: Run focused suites and the ledger runner to verify RED**

Expected: progression fields are missing from rows/header.

- [ ] **Step 3: Add an optional progression provider without breaking neutral/front-end configuration**

Add these exact trailing arguments:

```gdscript
# LedgerDataProvider.configure(...)
progression_provider: Callable = Callable(),
progression_context: PlayerRunContext = null

# CharacterLedger.configure(...) after feature_policy
progression_provider: Callable = Callable(),
progression_context: PlayerRunContext = null
```

Empty callables return level 1, XP 0, and `ExperienceSystem.DEFAULT_TUNING.requirement_for_level(1)`. PartyForgeMain passes `Callable(active_run_context, "progression_for")` and the active context only after a run context exists; its neutral front-end ledger keeps both defaults.

Provider signal wiring also observes `active_run_context.progression_changed` through a new optional context argument, emitting `data_changed(member_id)` and disconnecting safely during reconfiguration/deletion.

Add these exact fields to every member row:

```gdscript
var progression := progression_provider.call(member.member_id) as CharacterProgressionState if progression_provider.is_valid() else null
var required := ExperienceSystem.DEFAULT_TUNING.requirement_for_level(1)
if progression != null:
	required = progression.experience_required
row["character_level"] = progression.level if progression != null else 1
row["experience"] = progression.experience if progression != null else 0
row["experience_required"] = required
row["experience_fraction"] = float(row.experience) / float(maxi(required, 1))
row["guaranteed_growth_count"] = progression.guaranteed_growth_history.size() if progression != null else 0
row["milestone_count"] = progression.milestone_outcomes.size() if progression != null else 0
```

- [ ] **Step 4: Render progression without duplicating stat arithmetic**

Append this information to the Stats header:

```text
<Name> | <Class> Rank <N> | Level <N> | XP <current> / <required> | <Role> | Health <current> / <maximum> [| Downed| Dead]
```

Use `state.experience_required` for required XP and assert it matches the tuning during context construction/restore. Core-attribute values and breakdowns continue through `party.stats_for()` and `stat_detail()`; the UI never reads `core_attribute_gains` to calculate totals.

- [ ] **Step 5: Verify GREEN and commit**

```powershell
git add scripts/ui/ledger/ledger_data_provider.gd scripts/ui/ledger/character_ledger.gd scripts/ui/ledger/stats_ledger_page.gd scripts/game/main.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_character_ledger_foundation.gd tests/integration/ledger_24_member_runner.gd
git commit -m "feat: show character progression in ledger"
```

---

### Task 9: Multi-context harness, production smoke, and 24-character baseline

**Files:**
- Create: `tests/integration/run_context_harness_runner.gd`
- Create: `tests/integration/progression_arena_smoke_runner.gd`
- Create: `tests/integration/progression_24_member_runner.gd`
- Create: `docs/verification/2026-08-04-run-context-character-progression.md`

**Interfaces:**
- Consumes: complete Plan 4A production interfaces.
- Produces marker: `RUN_CONTEXT_HARNESS_SUMMARY: PASS contexts=2`.
- Produces marker: `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`.
- Produces markers: `PROGRESSION_LOAD_SIZE_PASS members=<1|6|12|24> ...` and `PROGRESSION_24_MEMBER_SUMMARY: PASS`.

- [ ] **Step 1: Write the two-profile harness**

Construct two valid profiles, two PartyManagers, two contexts, and two leaders/followers at controlled positions. Register in reverse slot order. Distribute packets and assert:

- sorted context order is slot 0 then slot 1;
- each context owns a distinct PartyManager and progression dictionary;
- a packet near only player one changes only player one;
- a packet in both event radii changes both eligible squads by the full amount;
- RNG/milestone results for player one match a single-context control run;
- player one queue consumption cannot mutate player two's queue;
- a forced stat-source rejection in player two cannot mutate player one;
- one packet retry changes neither context.

Exit nonzero on any failure; otherwise print the exact harness PASS marker.

- [ ] **Step 2: Write the production Arena smoke runner**

Use isolated `APPDATA` and `LOCALAPPDATA` supplied by the caller. Create/select one test profile through `ProfileManager`, instantiate `res://scenes/game/main.tscn`, start Fighter through `select_leader_class()`, and assert:

- one registered/locked context exists;
- PartyForgeMain compatibility party is the active context party;
- leader actor is bound and available;
- collecting a production-configured orb advances the leader;
- exactly one leader upgrade is pending and the level-up presentation enters its expected state;
- HUD XP values match the active leader state;
- opening the ledger shows the leader's new level and Class Growth source;
- the profile reloaded from disk is byte/value unchanged by run progression.

Print `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS` and remove only the isolated test profile/settings roots it created.

- [ ] **Step 3: Write progressive 1/6/12/24 load evidence**

For each target size, construct contexts/parties whose total character count equals the target, bind live leader/follower actors, allow at least 120 physics frames, award enough XP for multiple levels, open/refresh the production ledger, and record:

- elapsed microseconds for progression awards;
- elapsed microseconds for ledger refresh;
- average and maximum process/physics frame time from Godot Performance monitors;
- static and static-maximum memory;
- actor count, context count, and party-member count;
- correctness checks for every member's state/source/ledger row.

Use one context for 1 and 6, two contexts for 12, and four contexts of six for 24. Do not add an arbitrary pass/fail FPS threshold in Plan 4A; fail on errors, missing rows, ownership contamination, nonfinite metrics, or a runner timeout. Print the exact size and summary markers so later performance work can compare a stable baseline.

- [ ] **Step 4: Run focused and integration gates**

```powershell
$env:APPDATA = Join-Path $project '.superpowers/plan-4a-appdata'
$env:LOCALAPPDATA = Join-Path $project '.superpowers/plan-4a-localappdata'
& $godot --headless --path $project --import
& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd
& $godot --headless --path $project --quit-after 120 --script res://tests/integration/run_context_harness_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/progression_arena_smoke_runner.gd
& $godot --headless --path $project --quit-after 300 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path $project --editor --quit-after 2
git diff --check
```

Expected: every command exits `0`; each runner prints its exact PASS marker; the full suite prints `TEST_SUMMARY: PASS`; import/startup contain no unexpected parse/loader error; and whitespace check is clean.

- [ ] **Step 5: Record exact-head evidence and explicit deferrals**

Create the verification document with the tested commit, commands, exit codes, required markers, suite count observed rather than assumed, timing/memory table for all four sizes, generated-sidecar cleanup inventory, known baseline diagnostics, and changed-file review. State explicitly:

- normal Arena is still single-player;
- the two-profile harness is domain/integration evidence, not playable split-screen;
- controller assignment interfaces are automated contracts only;
- physical-controller, reconnect, Remote Play, and adaptive-camera validation remain deferred;
- tutorial, onboarding presentation, Arena wave rework, and Adventure remain deferred;
- progression is run-scoped and no ProfileState value changed.

- [ ] **Step 6: Request independent code review and fix only confirmed findings**

Use the `requesting-code-review` skill against the complete Plan 4A range. Classify findings as Critical, Important, or Minor. Add a failing regression before fixing confirmed production defects; rerun the affected focused gate and the complete final gate. Record accepted deferred Minor findings honestly.

- [ ] **Step 7: Commit verification**

```powershell
git add tests/integration/run_context_harness_runner.gd tests/integration/progression_arena_smoke_runner.gd tests/integration/progression_24_member_runner.gd docs/verification/2026-08-04-run-context-character-progression.md
git commit -m "test: verify run context progression slice"
```

## Final Acceptance Checklist

- [ ] At least two profile-owned contexts coexist with no shared mutable party, progression, RNG, or upgrade-queue state.
- [ ] The current single-player Arena starts through the active-profile gate and retains combat, orb attraction, HUD, level-up, pause, and ledger behavior.
- [ ] Every current class has valid, visible, tooltip-backed core attributes and complete provisional growth content.
- [ ] Every character tracks independent increasing-threshold XP and levels; exact overflow and fractional XP are preserved.
- [ ] Every level grants guaranteed class growth; every fifth level grants deterministic isolated weighted growth.
- [ ] Only leaders queue upgrade cards; followers never create a card.
- [ ] XP reward eligibility uses the approved event/leader/follower distances at inside, exact boundary, and outside positions.
- [ ] Dead, downed, or separated members receive no XP; revived-before-collection members can qualify.
- [ ] Every packet/context pair is idempotent, including ineligible collection-time outcomes.
- [ ] Ledger projection works for all members through 24 and never calculates attribute totals outside StatResolver.
- [ ] Two-context, production Arena, and progressive 24-character runners pass with recorded evidence.
- [ ] Full import, full unit suite, startup smoke, focused integrations, and `git diff --check` pass at exact head.
- [ ] No active-run progression is persisted to ProfileState and no deferred player-facing system is exposed as complete.
