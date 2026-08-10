extends RefCounted

const PROJECTION_PATH := "res://scripts/combat/action_damage_component_projection.gd"
const AUTHORED := 0
const ACTIVE_WEAPON := 1

func run() -> Array[String]:
	var failures: Array[String] = []
	var attack := _attack([_authored(&"physical", 10.0)])
	var has_source := _has_property(attack, &"damage_source")
	var has_effectiveness := _has_property(attack, &"weapon_damage_effectiveness")
	TestAssertions.truthy(has_source, "attack definition exposes a damage source", failures)
	TestAssertions.truthy(has_effectiveness, "attack definition exposes weapon damage effectiveness", failures)
	TestAssertions.truthy(ResourceLoader.exists(PROJECTION_PATH), "shared action damage component projection exists", failures)
	if not has_source or not has_effectiveness or not ResourceLoader.exists(PROJECTION_PATH):
		return failures

	var projection := load(PROJECTION_PATH) as Script
	TestAssertions.truthy(projection != null and projection.can_instantiate(), "shared component projection parses", failures)
	if projection == null or not projection.can_instantiate():
		return failures
	var weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-a", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"physical", 5.0, 9.0),
		ItemBaseDamageComponent.create(&"fire", 2.0, 4.0),
	], 4)

	attack.set(&"damage_source", AUTHORED)
	var authored: Dictionary = projection.call("resolve", attack, weapon)
	_assert_projection(authored, false, [&"physical"], [10.0], [10.0], "authored action ignores weapon", failures)

	attack.set(&"damage_source", ACTIVE_WEAPON)
	attack.set(&"weapon_damage_effectiveness", 2.0)
	var active: Dictionary = projection.call("resolve", attack, weapon)
	_assert_projection(active, false, [&"fire", &"physical"], [4.0, 10.0], [8.0, 18.0], "weapon action multiplies and sorts", failures)

	var missing: Dictionary = projection.call("resolve", attack, null)
	_assert_projection(missing, true, [&"physical"], [10.0], [10.0], "missing weapon uses fixed authored fallback", failures)
	var empty_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-empty", &"forge_vanguard_sword", [], 4)
	var empty: Dictionary = projection.call("resolve", attack, empty_weapon)
	_assert_projection(empty, true, [&"physical"], [10.0], [10.0], "empty weapon uses fixed authored fallback", failures)

	attack.set(&"weapon_damage_effectiveness", INF)
	var invalid: Dictionary = projection.call("resolve", attack, weapon)
	TestAssertions.truthy(not String(invalid.get("error", "")).is_empty(), "non-finite weapon effectiveness is rejected", failures)
	var weapon_heal := AttackDefinition.new()
	weapon_heal.id = &"weapon_heal_without_fallback"
	weapon_heal.kind = AttackDefinition.Kind.HEAL
	weapon_heal.power = 10.0
	weapon_heal.cooldown = 1.0
	weapon_heal.range = 4.0
	weapon_heal.damage_source = AttackDefinition.DamageSource.ACTIVE_WEAPON
	TestAssertions.truthy(
		not weapon_heal.validate(GameCatalog.DAMAGE_TYPES).is_empty(),
		"weapon-sourced action without authored fallback is rejected",
		failures,
	)

	attack.set(&"weapon_damage_effectiveness", 1.0)
	var resolver_script := load("res://scripts/combat/damage_resolver.gd") as Script
	var tags: Array[StringName] = resolver_script.call("action_tags_for", attack, weapon)
	TestAssertions.equal(tags, [&"fire", &"melee", &"physical"], "weapon-aware tags merge actual damage types in deterministic order", failures)
	var fallback_tags: Array[StringName] = resolver_script.call("action_tags_for", attack, null)
	TestAssertions.equal(fallback_tags, [&"melee", &"physical"], "fallback tags use authored component types", failures)
	var fire_only_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-fire", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"fire", 5.0, 5.0),
	], 4)
	var fire_tags: Array[StringName] = resolver_script.call("action_tags_for", attack, fire_only_weapon)
	TestAssertions.equal(fire_tags, [&"fire", &"melee", &"physical"], "weapon tags preserve authored fallback types and add actual weapon types", failures)
	var tagged_modifier := StatModifier.create(&"fire_damage", StatModifier.Operation.INCREASED, 0.5, &"weapon_fire_tag", "Weapon Fire Tag", fire_tags)
	tagged_modifier.required_action_tags = [&"fire"]
	var tagged_source := StatModifierSource.create(&"weapon_type_tag_source", &"test", "Weapon Type Tag Source", 1, [tagged_modifier])
	var fighter := GameCatalog.load_defaults().class_by_id(&"fighter")
	var tagged_resolution := MemberStatResolutionService.resolve(
		1,
		GameCatalog.STAT_CATALOG,
		fighter.stat_base_values(),
		fighter.capability_tags,
		[tagged_source] as Array[StatModifierSource],
		fire_tags,
		4,
		PartyManager.DEFAULT_ATTRIBUTE_PROJECTION,
	)
	TestAssertions.truthy(tagged_resolution.ok(), "weapon type-tagged candidate stats resolve", failures)
	if tagged_resolution.ok():
		TestAssertions.truthy(tagged_resolution.final_stats.value(&"fire_damage", 1.0) > 1.0, "actual weapon type activates matching type-gated source", failures)
	_test_runtime_rng_and_estimate_parity(attack, weapon, failures)
	return failures

func _test_runtime_rng_and_estimate_parity(attack: AttackDefinition, _weapon: ActiveWeaponDamageSnapshot, failures: Array[String]) -> void:
	var adapter_script := load("res://scripts/combat/combatant_adapter.gd") as Script
	var probe := CombatantAdapter.new()
	if not _has_property(probe, &"weapon_snapshot"):
		TestAssertions.truthy(false, "combat adapter owns a defensive weapon snapshot", failures)
		return
	attack.set(&"damage_source", ACTIVE_WEAPON)
	attack.set(&"weapon_damage_effectiveness", 1.0)
	attack.can_crit = true
	var stats := _stats({&"crit_chance": 0.5, &"crit_multiplier": 2.0})
	stats.revision = 4
	var ranged_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-ranges", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"physical", 4.0, 8.0),
		ItemBaseDamageComponent.create(&"fire", 10.0, 20.0),
	], 4)
	var adapter := adapter_script.new(null, &"party:1", 1, null, stats, true, Callable(), ranged_weapon) as CombatantAdapter
	var exposed: ActiveWeaponDamageSnapshot = adapter.get("weapon_snapshot") as ActiveWeaponDamageSnapshot
	if exposed != null:
		exposed._components.clear()
	TestAssertions.equal((adapter.get("weapon_snapshot") as ActiveWeaponDamageSnapshot).components.size(), 2, "adapter weapon snapshot getter is defensive", failures)
	var rng := CombatRng.new(101, [0.20, 0.25, 0.75])
	var packet := DamageResolver.prepare(attack, adapter, rng, GameCatalog.DAMAGE_TYPES)
	TestAssertions.truthy(packet.valid and packet.critical, "weapon range runtime packet is valid and critical", failures)
	if packet.valid:
		TestAssertions.equal(packet.components.map(func(component: PreparedDamageComponent) -> StringName: return component.damage_type_id), [&"fire", &"physical"], "runtime samples components in sorted type order", failures)
		TestAssertions.near(packet.components[0].authored_amount, 12.5, 0.0001, "first post-crit draw samples fire range", failures)
		TestAssertions.near(packet.components[1].authored_amount, 7.0, 0.0001, "second post-crit draw samples physical range", failures)
		TestAssertions.near(packet.components[0].post_crit, 25.0, 0.0001, "shared critical multiplier applies after fire range roll", failures)
		TestAssertions.near(packet.components[1].post_crit, 14.0, 0.0001, "shared critical multiplier applies after physical range roll", failures)
	TestAssertions.equal(rng.draw_count, 3, "critical draw occurs first then one draw per sorted non-fixed component", failures)

	var fixed_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-fixed", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"physical", 7.0, 7.0),
	], 4)
	var fixed_stats := _stats({&"damage": 1.2, &"melee_damage": 1.25, &"physical_damage": 1.4})
	fixed_stats.revision = 4
	var fixed_adapter := adapter_script.new(null, &"party:1", 1, null, fixed_stats, true, Callable(), fixed_weapon) as CombatantAdapter
	attack.can_crit = false
	var fixed_rng := CombatRng.new(102, [0.9])
	var fixed_packet := DamageResolver.prepare(attack, fixed_adapter, fixed_rng, GameCatalog.DAMAGE_TYPES)
	var estimate_script := load("res://scripts/ui/ledger/action_combat_estimate_service.gd") as Script
	var estimate := estimate_script.call("estimate_from_snapshot", attack, fixed_stats, GameCatalog.DAMAGE_TYPES, fixed_weapon) as ActionCombatEstimate
	TestAssertions.truthy(fixed_packet.valid and estimate != null and estimate.available, "fixed weapon runtime and estimate are available", failures)
	if fixed_packet.valid and estimate != null:
		TestAssertions.near(fixed_packet.components[0].typed_scaled, estimate.normal_hit, 0.0001, "fixed runtime normal hit equals midpoint estimate", failures)
		TestAssertions.near(estimate.normal_hit, 14.7, 0.0001, "global archetype and type scaling apply once", failures)
	TestAssertions.equal(fixed_rng.draw_count, 0, "fixed weapon component consumes no range draw", failures)
	var tiny_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-tiny-range", &"forge_vanguard_sword", [
		ItemBaseDamageComponent.create(&"physical", 1.0, 1.0000001),
	], 4)
	var tiny_adapter := adapter_script.new(null, &"party:1", 1, null, fixed_stats, true, Callable(), tiny_weapon) as CombatantAdapter
	var tiny_rng := CombatRng.new(1021, [0.5])
	var tiny_packet := DamageResolver.prepare(attack, tiny_adapter, tiny_rng, GameCatalog.DAMAGE_TYPES)
	TestAssertions.truthy(tiny_packet.valid, "tiny non-fixed weapon range prepares", failures)
	TestAssertions.equal(tiny_rng.draw_count, 1, "every exact non-fixed range consumes one unit draw", failures)

	var fallback_adapter := adapter_script.new(null, &"party:1", 1, null, fixed_stats, true, Callable(), null) as CombatantAdapter
	var fallback_rng := CombatRng.new(103, [0.9])
	var fallback_packet := DamageResolver.prepare(attack, fallback_adapter, fallback_rng, GameCatalog.DAMAGE_TYPES)
	TestAssertions.truthy(fallback_packet.valid, "missing weapon runtime uses authored fallback", failures)
	TestAssertions.equal(fallback_rng.draw_count, 0, "fixed authored fallback consumes no range draw", failures)
	attack.set(&"damage_source", AUTHORED)
	var authored_stale_rng := CombatRng.new(1031, [0.2])
	var authored_stale_adapter := adapter_script.new(null, &"party:1", 1, null, fixed_stats, true, Callable(), ActiveWeaponDamageSnapshot.create(999, "ignored", &"forge_vanguard_sword", [ItemBaseDamageComponent.create(&"fire", 50.0, 60.0)], 99)) as CombatantAdapter
	var authored_packet := DamageResolver.prepare(attack, authored_stale_adapter, authored_stale_rng, GameCatalog.DAMAGE_TYPES)
	TestAssertions.truthy(authored_packet.valid, "authored runtime ignores mismatched weapon context", failures)
	if authored_packet.valid:
		TestAssertions.equal(authored_packet.components[0].damage_type_id, &"physical", "authored runtime keeps authored type", failures)
		TestAssertions.near(authored_packet.components[0].authored_amount, 10.0, 0.0001, "authored runtime keeps fixed authored amount", failures)
	TestAssertions.equal(authored_stale_rng.draw_count, 0, "authored runtime ignores weapon ranges and consumes no range draw", failures)

	attack.set(&"damage_source", ACTIVE_WEAPON)
	var stale_weapon := ActiveWeaponDamageSnapshot.create(1, "weapon-stale", &"forge_vanguard_sword", [ItemBaseDamageComponent.create(&"physical", 7.0, 7.0)], 5)
	var stale_adapter := adapter_script.new(null, &"party:1", 1, null, fixed_stats, true, Callable(), stale_weapon) as CombatantAdapter
	var stale_rng := CombatRng.new(104, [0.2])
	var stale_packet := DamageResolver.prepare(attack, stale_adapter, stale_rng, GameCatalog.DAMAGE_TYPES)
	TestAssertions.truthy(not stale_packet.valid and stale_packet.error_reason.contains("revision"), "runtime rejects stale weapon revision", failures)
	TestAssertions.equal(stale_rng.draw_count, 0, "stale weapon rejection consumes no RNG", failures)

func _assert_projection(
	result: Dictionary,
	expected_fallback: bool,
	expected_types: Array[StringName],
	expected_minimums: Array[float],
	expected_maximums: Array[float],
	label: String,
	failures: Array[String],
) -> void:
	TestAssertions.equal(String(result.get("error", "")), "", "%s succeeds" % label, failures)
	TestAssertions.equal(bool(result.get("used_fallback", false)), expected_fallback, "%s fallback flag" % label, failures)
	var components: Array = result.get("components", []) as Array
	TestAssertions.equal(components.size(), expected_types.size(), "%s component count" % label, failures)
	for index: int in mini(components.size(), expected_types.size()):
		var component: Variant = components[index]
		TestAssertions.equal(component.get("damage_type_id"), expected_types[index], "%s type %d" % [label, index], failures)
		TestAssertions.near(float(component.get("minimum_damage")), expected_minimums[index], 0.0001, "%s minimum %d" % [label, index], failures)
		TestAssertions.near(float(component.get("maximum_damage")), expected_maximums[index], 0.0001, "%s maximum %d" % [label, index], failures)

func _attack(components: Array[AttackDamageComponent]) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"projection_test"
	attack.kind = AttackDefinition.Kind.DIRECT
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.action_tags = [&"melee"]
	attack.damage_components = components
	return attack

func _authored(type_id: StringName, amount: float) -> AttackDamageComponent:
	var component := AttackDamageComponent.new()
	component.damage_type_id = type_id
	component.base_amount = amount
	return component

func _stats(overrides: Dictionary) -> ResolvedStatSnapshot:
	var snapshot := ResolvedStatSnapshot.new()
	for definition: StatDefinition in GameCatalog.STAT_CATALOG.definitions:
		snapshot.set_resolved(definition.id, float(overrides.get(definition.id, definition.default_value)), [])
	return snapshot

func _has_property(object: Object, property_name: StringName) -> bool:
	return object.get_property_list().any(func(property: Dictionary) -> bool:
		return property.get("name") == property_name
	)
