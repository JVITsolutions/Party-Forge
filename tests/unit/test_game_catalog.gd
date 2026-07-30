extends RefCounted

class TypedAttackErrorClass:
    extends ClassDefinition

    func validate(_types: DamageTypeCatalog = null) -> PackedStringArray:
        return PackedStringArray([
            "class %s primary PARTY_FORGE_DAMAGE_ERROR attack=%s type=void reason=unknown component type" % [id, primary_attack.id],
        ])

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog: GameCatalog = GameCatalog.load_defaults()
    TestAssertions.equal(catalog.classes.size(), 4, "four classes", failures)
    TestAssertions.equal(catalog.traits.size(), 13, "thirteen traits", failures)
    TestAssertions.equal(catalog.enemies.size(), 3, "two enemies plus boss", failures)
    TestAssertions.equal(catalog.validate().size(), 0, "catalog validates", failures)
    TestAssertions.equal(catalog.class_by_id(&"fighter").traits, [&"martial", &"vanguard"], "fighter traits", failures)
    TestAssertions.equal(catalog.class_by_id(&"cleric").support_action.id, &"cleric_heal", "cleric heal", failures)
    var attack_links: Array[Array] = [
        [&"fighter", &"primary_attack", "res://data/attacks/fighter_cleave.tres"],
        [&"ranger", &"primary_attack", "res://data/attacks/ranger_shot.tres"],
        [&"mage", &"primary_attack", "res://data/attacks/mage_burst.tres"],
        [&"cleric", &"primary_attack", "res://data/attacks/cleric_bolt.tres"],
        [&"cleric", &"support_action", "res://data/attacks/cleric_heal.tres"],
    ]
    for link: Array in attack_links:
        var definition: ClassDefinition = catalog.class_by_id(link[0])
        var attack: AttackDefinition = definition.get(link[1]) as AttackDefinition
        TestAssertions.equal(attack.resource_path, link[2], "%s %s uses external attack" % [link[0], link[1]], failures)
    _assert_generated_values(failures)
    _assert_persisted_attack_damage_path(failures)
    return failures

func _assert_persisted_attack_damage_path(failures: Array[String]) -> void:
    var path := "user://typed_combat_malformed_attack.tres"
    var attack := AttackDefinition.new()
    attack.id = &"malformed_persisted"
    TestAssertions.equal(ResourceSaver.save(attack, path), OK, "malformed attack fixture saves", failures)
    var persisted_attack := load(path) as AttackDefinition
    TestAssertions.truthy(persisted_attack != null, "malformed attack fixture loads", failures)
    if persisted_attack == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        return
    var definition := TypedAttackErrorClass.new()
    definition.id = &"typed_error_fixture"
    definition.primary_attack = persisted_attack
    var catalog := GameCatalog.new()
    catalog.classes.append(definition)
    TestAssertions.equal(catalog.validate(), PackedStringArray([
        "PARTY_FORGE_DAMAGE_ERROR path=%s attack=malformed_persisted type=void reason=unknown component type" % path,
    ]), "persisted attack retains damage prefix and attack path", failures)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _assert_generated_values(failures: Array[String]) -> void:
    var attack_rows: Array[Dictionary] = [
        {"path": "res://data/attacks/fighter_cleave.tres", "values": {"id": &"fighter_cleave", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "cooldown": 0.8, "range": 2.2, "projectile_speed": 0.0, "area_radius": 1.6}, "damage_type": &"physical", "damage_amount": 18.0},
        {"path": "res://data/attacks/ranger_shot.tres", "values": {"id": &"ranger_shot", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 0.55, "range": 11.0, "projectile_speed": 16.0, "area_radius": 0.0}, "damage_type": &"physical", "damage_amount": 11.0},
        {"path": "res://data/attacks/mage_burst.tres", "values": {"id": &"mage_burst", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "cooldown": 1.5, "range": 12.0, "projectile_speed": 11.0, "area_radius": 2.5}, "damage_type": &"fire", "damage_amount": 24.0},
        {"path": "res://data/attacks/cleric_bolt.tres", "values": {"id": &"cleric_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 1.0, "range": 10.0, "projectile_speed": 13.0, "area_radius": 0.0}, "damage_type": &"lightning", "damage_amount": 8.0},
        {"path": "res://data/attacks/cleric_heal.tres", "values": {"id": &"cleric_heal", "kind": AttackDefinition.Kind.HEAL, "power": 18.0, "cooldown": 3.0, "range": 9.0, "projectile_speed": 0.0, "area_radius": 0.0}},
    ]
    var class_rows: Array[Dictionary] = [
        {"path": "res://data/classes/fighter.tres", "values": {"id": &"fighter", "display_name": "Fighter", "role": ClassDefinition.Role.FRONTLINE, "color": Color("d94f4f"), "traits": [&"martial", &"vanguard"], "max_health": 260.0, "armor": 10.0, "move_speed": 6.2, "preferred_distance": 2.0, "engagement_distance": 5.0, "tether_distance": 9.0, "support_action": null}},
        {"path": "res://data/classes/ranger.tres", "values": {"id": &"ranger", "display_name": "Ranger", "role": ClassDefinition.Role.MIDLINE, "color": Color("5fbd72"), "traits": [&"martial", &"ranged"], "max_health": 90.0, "armor": 1.0, "move_speed": 6.6, "preferred_distance": 5.0, "engagement_distance": 11.0, "tether_distance": 11.0, "support_action": null}},
        {"path": "res://data/classes/mage.tres", "values": {"id": &"mage", "display_name": "Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("9567e8"), "traits": [&"arcane", &"caster", &"fire"], "max_health": 75.0, "armor": 0.0, "move_speed": 6.0, "preferred_distance": 6.5, "engagement_distance": 12.0, "tether_distance": 12.0, "support_action": null}},
        {"path": "res://data/classes/cleric.tres", "values": {"id": &"cleric", "display_name": "Cleric", "role": ClassDefinition.Role.SUPPORT, "color": Color("f0d15b"), "traits": [&"divine", &"support", &"caster"], "max_health": 95.0, "armor": 2.0, "move_speed": 6.0, "preferred_distance": 4.0, "engagement_distance": 10.0, "tether_distance": 10.0}},
    ]
    var trait_rows: Array[Dictionary] = [
        {"path": "res://data/traits/martial.tres", "values": {"id": &"martial", "display_name": "Martial", "stat_id": &"attack_speed", "tiers": {2: 0.15, 4: 0.35}}},
        {"path": "res://data/traits/vanguard.tres", "values": {"id": &"vanguard", "display_name": "Vanguard", "stat_id": &"nearby_damage_reduction", "tiers": {2: 0.12, 4: 0.28}}},
        {"path": "res://data/traits/ranged.tres", "values": {"id": &"ranged", "display_name": "Ranged", "stat_id": &"projectile_speed_and_range", "tiers": {2: 0.15, 4: 0.35}}},
        {"path": "res://data/traits/arcane.tres", "values": {"id": &"arcane", "display_name": "Arcane", "stat_id": &"area_size", "tiers": {2: 0.18, 4: 0.40}}},
        {"path": "res://data/traits/caster.tres", "values": {"id": &"caster", "display_name": "Caster", "stat_id": &"cooldown_reduction", "tiers": {2: 0.12, 4: 0.28}}},
        {"path": "res://data/traits/divine.tres", "values": {"id": &"divine", "display_name": "Divine", "stat_id": &"healing_and_revive", "tiers": {2: 0.18, 4: 0.40}}},
        {"path": "res://data/traits/support.tres", "values": {"id": &"support", "display_name": "Support", "stat_id": &"support_power", "tiers": {2: 0.15, 4: 0.35}}},
    ]
    var enemy_rows: Array[Dictionary] = [
        {"path": "res://data/enemies/swarmer.tres", "values": {"id": &"swarmer", "behavior": EnemyDefinition.Behavior.SWARMER, "max_health": 12.0, "move_speed": 4.8, "stat_overrides": {}, "experience": 2}, "attacks": [&"swarmer_contact"]},
        {"path": "res://data/enemies/spitter.tres", "values": {"id": &"spitter", "behavior": EnemyDefinition.Behavior.SPITTER, "max_health": 18.0, "move_speed": 2.8, "stat_overrides": {}, "experience": 4}, "attacks": [&"spitter_projectile"]},
        {"path": "res://data/enemies/forge_guardian.tres", "values": {"id": &"forge_guardian", "behavior": EnemyDefinition.Behavior.FORGE_GUARDIAN, "max_health": 3000.0, "move_speed": 3.3, "stat_overrides": {}, "experience": 100}, "attacks": [&"guardian_charge", &"guardian_shockwave"]},
    ]
    _assert_resource_table("attack", attack_rows, failures)
    _assert_resource_table("class", class_rows, failures)
    _assert_resource_table("trait", trait_rows, failures)
    _assert_resource_table("enemy", enemy_rows, failures)

func _assert_resource_table(kind: String, rows: Array[Dictionary], failures: Array[String]) -> void:
    for row: Dictionary in rows:
        var path: String = row["path"]
        var resource: Resource = load(path)
        TestAssertions.truthy(resource != null, "%s resource loads: %s" % [kind, path], failures)
        if resource == null:
            continue
        var values: Dictionary = row["values"]
        for property: Variant in values:
            var expected: Variant = values[property]
            var label: String = "%s %s %s" % [kind, resource.get("id"), property]
            if typeof(expected) == TYPE_FLOAT:
                TestAssertions.near(float(resource.get(property)), float(expected), 0.001, label, failures)
            else:
                TestAssertions.equal(resource.get(property), expected, label, failures)
        if kind == "attack" and row.has("damage_type"):
            var attack := resource as AttackDefinition
            TestAssertions.equal(attack.damage_components.size(), 1, "attack %s one damage component" % attack.id, failures)
            if attack.damage_components.size() == 1:
                TestAssertions.equal(attack.damage_components[0].damage_type_id, row["damage_type"], "attack %s damage type" % attack.id, failures)
                TestAssertions.near(attack.damage_components[0].base_amount, row["damage_amount"], 0.001, "attack %s damage amount" % attack.id, failures)
        if kind == "enemy" and row.has("attacks"):
            var enemy := resource as EnemyDefinition
            var ids: Array[StringName] = []
            for attack: AttackDefinition in enemy.attacks:
                ids.append(attack.id)
            TestAssertions.equal(ids, row["attacks"], "enemy %s exact attack links" % enemy.id, failures)
