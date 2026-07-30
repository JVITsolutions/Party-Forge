extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_invalid_mitigation_rule_is_rejected(failures)
	_test_default_generator_authors_exact_typed_party_attacks(failures)
	_test_classes_use_active_types_and_supported_kinds(failures)
	_test_non_finite_healing_is_rejected(failures)
	_test_packet_scalar_evidence_is_immutable(failures)
	return failures

func _test_invalid_mitigation_rule_is_rejected(failures: Array[String]) -> void:
	var invalid_type := DamageTypeDefinition.new()
	invalid_type.id = &"unstable"
	invalid_type.display_name = "Unstable"
	invalid_type.keyword_id = &"unstable"
	invalid_type.offense_stat_id = &"physical_damage"
	invalid_type.defense_stat_id = &"armor"
	invalid_type.set("mitigation_rule", 99)
	TestAssertions.truthy("PARTY_FORGE_DAMAGE_ERROR type=unstable rule=99 reason=unsupported mitigation rule" in invalid_type.validate(PartyManager.STAT_CATALOG), "invalid mitigation rule diagnostic", failures)

	var types := DamageTypeCatalog.new()
	types.definitions = [invalid_type]
	var source := CombatantAdapter.new(null, &"party:rule_source", 1)
	var prepared: Array[PreparedDamageComponent] = [PreparedDamageComponent.new(&"unstable", 10.0, 10.0, 10.0, 10.0)]
	var tags: Array[StringName] = [&"unstable"]
	var packet := DamagePacket.create(source, &"invalid_rule_hit", tags, false, false, -1.0, 1.0, 0.0, prepared)
	var health := HealthComponent.new()
	health.configure(100.0, false, 1.0, 1.0, true)
	var target := CombatantAdapter.new(null, &"enemy:rule_target", 2, health, null, true)
	var result := DamageResolver.resolve(packet, target, CombatRng.new(1), types)
	TestAssertions.truthy(not result.valid, "resolver rejects unsupported mitigation rule", failures)
	TestAssertions.equal(result.error_reason, "PARTY_FORGE_DAMAGE_ERROR attack=invalid_rule_hit source=party:rule_source target=enemy:rule_target type=unstable rule=99 reason=unsupported mitigation rule", "resolver mitigation rule diagnostic", failures)
	TestAssertions.near(health.current_health, 100.0, 0.001, "unsupported mitigation rule changes no health", failures)
	health.free()

func _test_default_generator_authors_exact_typed_party_attacks(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string("res://tools/create_default_data.gd")
	var required_fragments: PackedStringArray = [
		"const ATTACK_ROWS",
		"{\"id\":&\"fighter_cleave\", \"kind\":AttackDefinition.Kind.MELEE_CLEAVE, \"type\":&\"physical\", \"amount\":18.0",
		"{\"id\":&\"ranger_shot\", \"kind\":AttackDefinition.Kind.PROJECTILE, \"type\":&\"physical\", \"amount\":11.0",
		"{\"id\":&\"mage_burst\", \"kind\":AttackDefinition.Kind.AREA_PROJECTILE, \"type\":&\"fire\", \"amount\":24.0",
		"{\"id\":&\"cleric_bolt\", \"kind\":AttackDefinition.Kind.PROJECTILE, \"type\":&\"lightning\", \"amount\":8.0",
		"{\"id\":&\"cleric_heal\", \"kind\":AttackDefinition.Kind.HEAL, \"type\":&\"\", \"amount\":0.0, \"power\":18.0",
		"AttackDamageComponent.new()",
		"value.action_tags.assign(row[\"tags\"])",
		"value.can_crit = row[\"crit\"]",
	]
	for fragment: String in required_fragments:
		TestAssertions.truthy(fragment in source, "default generator typed fragment: %s" % fragment, failures)

func _test_classes_use_active_types_and_supported_kinds(failures: Array[String]) -> void:
	var invalid_kind := _valid_attack(&"invalid_kind", AttackDefinition.Kind.PROJECTILE, &"physical")
	invalid_kind.set("kind", 99)
	TestAssertions.truthy("PARTY_FORGE_DAMAGE_ERROR attack=invalid_kind kind=99 reason=invalid attack kind" in invalid_kind.validate(GameCatalog.load_defaults().damage_types), "out-of-range attack kind diagnostic", failures)

	var definition := _valid_class()
	if not _method_accepts(definition, &"validate", 1):
		TestAssertions.truthy(false, "class validation accepts active damage catalog", failures)
		return
	var radiant := DamageTypeDefinition.new()
	radiant.id = &"radiant"
	radiant.display_name = "Radiant"
	radiant.keyword_id = &"radiant"
	radiant.offense_stat_id = &"fire_damage"
	radiant.defense_stat_id = &"fire_resistance"
	radiant.mitigation_rule = DamageTypeDefinition.MitigationRule.RESISTANCE
	var active_types := DamageTypeCatalog.new()
	active_types.definitions = GameCatalog.load_defaults().damage_types.all()
	active_types.definitions.append(radiant)
	definition.primary_attack = _valid_attack(&"radiant_bolt", AttackDefinition.Kind.PROJECTILE, &"radiant")
	TestAssertions.equal(definition.call("validate", active_types), PackedStringArray(), "class accepts type from active catalog", failures)
	TestAssertions.truthy(_contains_reason(definition.call("validate", GameCatalog.load_defaults().damage_types), "unknown component type"), "class rejects type missing from active catalog", failures)
	var game := GameCatalog.new()
	game.damage_types = active_types
	game.classes.append(definition)
	var review_trait := TraitDefinition.new()
	review_trait.id = &"review"
	review_trait.display_name = "Review"
	review_trait.stat_id = &"attack_speed"
	review_trait.tiers = {2: 0.15, 4: 0.35}
	game.traits.append(review_trait)
	TestAssertions.equal(game.validate(), PackedStringArray(), "game catalog passes active types into class validation", failures)

	for unsupported_kind: int in [AttackDefinition.Kind.DIRECT, AttackDefinition.Kind.AREA]:
		var unsupported := _valid_class()
		unsupported.primary_attack = _valid_attack(&"unsupported_party", unsupported_kind as AttackDefinition.Kind, &"physical")
		var errors: PackedStringArray = unsupported.call("validate", active_types)
		TestAssertions.truthy(_contains_reason(errors, "unsupported party attack kind"), "class rejects enemy-only attack kind %d" % unsupported_kind, failures)

func _test_non_finite_healing_is_rejected(failures: Array[String]) -> void:
	var heal := _valid_attack(&"poisoned_heal", AttackDefinition.Kind.HEAL, &"")
	heal.power = NAN
	TestAssertions.truthy("PARTY_FORGE_DAMAGE_ERROR attack=poisoned_heal reason=heal power must be finite and positive" in heal.validate(GameCatalog.load_defaults().damage_types), "non-finite heal definition diagnostic", failures)
	var health := HealthComponent.new()
	health.configure(100.0, false, 1.0, 1.0, true)
	health.apply_damage(25.0)
	var restored := health.heal(NAN)
	TestAssertions.truthy(is_finite(restored), "NaN healing reports a finite result", failures)
	TestAssertions.near(restored, 0.0, 0.001, "NaN healing restores nothing", failures)
	TestAssertions.truthy(is_finite(health.current_health), "NaN healing cannot poison health state", failures)
	TestAssertions.near(health.current_health, 75.0, 0.001, "NaN healing preserves current health", failures)
	health.free()

func _test_packet_scalar_evidence_is_immutable(failures: Array[String]) -> void:
	var source := CombatantAdapter.new(null, &"party:immutable", 1)
	var tags: Array[StringName] = [&"physical"]
	var prepared: Array[PreparedDamageComponent] = [PreparedDamageComponent.new(&"physical", 18.0, 18.0, 18.0, 27.0)]
	var packet := DamagePacket.create(source, &"sealed_hit", tags, true, true, 0.25, 1.5, 0.2, prepared)
	packet.valid = false
	packet.error_reason = "mutated"
	packet.source = null
	packet.source_id = &"enemy:mutated"
	packet.source_team_id = 9
	packet.attack_id = &"mutated"
	packet.can_crit = false
	packet.critical = false
	packet.crit_draw = 0.99
	packet.crit_multiplier = 9.0
	packet.life_steal_rate = 9.0
	TestAssertions.truthy(packet.valid, "packet validity is immutable", failures)
	TestAssertions.equal(packet.error_reason, "", "packet error evidence is immutable", failures)
	TestAssertions.equal(packet.source, source, "packet source reference is immutable", failures)
	TestAssertions.equal(packet.source_id, &"party:immutable", "packet source identity is immutable", failures)
	TestAssertions.equal(packet.source_team_id, 1, "packet source team is immutable", failures)
	TestAssertions.equal(packet.attack_id, &"sealed_hit", "packet attack identity is immutable", failures)
	TestAssertions.truthy(packet.can_crit and packet.critical, "packet crit outcome is immutable", failures)
	TestAssertions.near(packet.crit_draw, 0.25, 0.001, "packet crit draw is immutable", failures)
	TestAssertions.near(packet.crit_multiplier, 1.5, 0.001, "packet crit multiplier is immutable", failures)
	TestAssertions.near(packet.life_steal_rate, 0.2, 0.001, "packet life steal evidence is immutable", failures)

func _valid_attack(attack_id: StringName, attack_kind: AttackDefinition.Kind, type_id: StringName) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = attack_id
	attack.kind = attack_kind
	attack.cooldown = 1.0
	attack.range = 5.0
	attack.projectile_speed = 10.0 if attack_kind in [AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE] else 0.0
	attack.area_radius = 1.0 if attack_kind in [AttackDefinition.Kind.MELEE_CLEAVE, AttackDefinition.Kind.AREA_PROJECTILE, AttackDefinition.Kind.AREA] else 0.0
	if attack_kind == AttackDefinition.Kind.HEAL:
		attack.power = 10.0
		attack.action_tags.assign([&"healing"])
	else:
		var component := AttackDamageComponent.new()
		component.damage_type_id = type_id
		component.base_amount = 10.0
		attack.damage_components.append(component)
		attack.action_tags.assign([&"projectile"] if attack_kind == AttackDefinition.Kind.PROJECTILE else [&"area"])
	return attack

func _valid_class() -> ClassDefinition:
	var definition := ClassDefinition.new()
	definition.id = &"review_class"
	definition.display_name = "Review Class"
	definition.traits = [&"review"]
	definition.primary_attack = _valid_attack(&"review_primary", AttackDefinition.Kind.PROJECTILE, &"physical")
	return definition

func _contains_reason(errors: PackedStringArray, fragment: String) -> bool:
	for reason: String in errors:
		if fragment in reason:
			return true
	return false

func _method_accepts(object: Object, method_name: StringName, argument_count: int) -> bool:
	for row: Dictionary in object.get_method_list():
		if StringName(row.get("name", "")) == method_name:
			return (row.get("args", []) as Array).size() == argument_count
	return false
