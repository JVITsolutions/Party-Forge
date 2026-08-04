extends RefCounted

class TypedAttackErrorClass:
    extends ClassDefinition

    func validate(_types: DamageTypeCatalog = null) -> PackedStringArray:
        return PackedStringArray([
            "class %s primary PARTY_FORGE_DAMAGE_ERROR attack=%s type=void reason=unknown component type" % [id, primary_attack.id],
        ])

const EXPECTED_CAPABILITIES := {
    &"fighter": [&"area", &"melee", &"physical", &"armour_heavy", &"one_hand_sword", &"shield"],
    &"ranger": [&"physical", &"projectile", &"ranged", &"armour_light", &"armour_medium", &"bow_light_medium"],
    &"mage": [&"area", &"fire", &"projectile", &"armour_light", &"caster_wand", &"caster_focus"],
    &"cleric": [&"healing", &"lightning", &"projectile", &"armour_light", &"armour_medium", &"divine_sceptre", &"divine_tome"],
    &"paladin": [&"area", &"block", &"melee", &"physical", &"regeneration", &"armour_heavy", &"one_hand_hammer", &"shield"],
    &"rogue": [&"area", &"crit", &"dodge", &"life_steal", &"melee", &"physical", &"armour_light", &"dagger", &"dual_wield"],
    &"frost_mage": [&"area", &"cold", &"projectile", &"armour_light", &"caster_staff"],
    &"warlock": [&"chaos", &"life_steal", &"projectile", &"ranged", &"armour_light", &"occult_wand", &"occult_grimoire"],
    &"marksman": [&"bow", &"crit", &"physical", &"projectile", &"ranged", &"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"],
}

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog: GameCatalog = GameCatalog.load_defaults()
    TestAssertions.equal(catalog.classes.size(), 9, "nine classes", failures)
    TestAssertions.equal(catalog.traits.size(), 13, "thirteen traits", failures)
    TestAssertions.equal(catalog.enemies.size(), 4, "three enemies plus boss", failures)
    TestAssertions.equal(catalog.validate().size(), 0, "catalog validates", failures)
    TestAssertions.equal(catalog.class_by_id(&"fighter").traits, [&"martial", &"vanguard"], "fighter traits", failures)
    TestAssertions.equal(catalog.class_by_id(&"cleric").support_action.id, &"cleric_heal", "cleric heal", failures)
    _assert_class_names_and_eligibility(catalog, failures)
    var fighter := catalog.class_by_id(&"fighter")
    fighter.growth_definition = null
    TestAssertions.truthy(
        catalog.validate().has("PARTY_FORGE_RESOURCE_ERROR id=fighter reason=class fighter growth definition is missing"),
        "missing fighter growth definition fails catalog validation",
        failures,
    )
    fighter.growth_definition = load("res://data/progression/class_growth/fighter.tres") as ClassGrowthDefinition
    var attack_links: Array[Array] = [
        [&"fighter", &"primary_attack", "res://data/attacks/fighter_cleave.tres"],
        [&"ranger", &"primary_attack", "res://data/attacks/ranger_shot.tres"],
        [&"mage", &"primary_attack", "res://data/attacks/mage_burst.tres"],
        [&"cleric", &"primary_attack", "res://data/attacks/cleric_bolt.tres"],
        [&"cleric", &"support_action", "res://data/attacks/cleric_heal.tres"],
        [&"paladin", &"primary_attack", "res://data/attacks/paladin_smite.tres"],
        [&"rogue", &"primary_attack", "res://data/attacks/rogue_flurry.tres"],
        [&"frost_mage", &"primary_attack", "res://data/attacks/frost_shard.tres"],
        [&"warlock", &"primary_attack", "res://data/attacks/warlock_bolt.tres"],
        [&"marksman", &"primary_attack", "res://data/attacks/marksman_heavy_shot.tres"],
    ]
    for link: Array in attack_links:
        var definition: ClassDefinition = catalog.class_by_id(link[0])
        var attack: AttackDefinition = definition.get(link[1]) as AttackDefinition
        TestAssertions.equal(attack.resource_path, link[2], "%s %s uses external attack" % [link[0], link[1]], failures)
    _assert_generated_values(failures)
    _assert_persisted_attack_damage_path(failures)
    return failures

func _assert_class_names_and_eligibility(catalog: GameCatalog, failures: Array[String]) -> void:
    var expected_names := {
        &"fighter": PackedStringArray(["Aldric", "Branna", "Cedric", "Dagna", "Garrick", "Hilda", "Rowan", "Thane"]),
        &"ranger": PackedStringArray(["Ash", "Briar", "Elowen", "Fen", "Linden", "Robin", "Sylvi", "Wren"]),
        &"mage": PackedStringArray(["Alaric", "Circe", "Elara", "Isolde", "Lucan", "Mira", "Orin", "Selene"]),
        &"cleric": PackedStringArray(["Ansel", "Beatrix", "Clement", "Faith", "Mercy", "Sabine", "Tobias", "Verity"]),
        &"paladin": PackedStringArray(["Aegis", "Armand", "Galahad", "Helena", "Roland", "Seraphine", "Tristan", "Valora"]),
        &"rogue": PackedStringArray(["Corvin", "Flick", "Jax", "Nyx", "Rook", "Shade", "Talia", "Vesper"]),
        &"frost_mage": PackedStringArray(["Boreas", "Eira", "Iskra", "Lumi", "Neve", "Rime", "Skadi", "Ylva"]),
        &"warlock": PackedStringArray(["Azrael", "Belladonna", "Dorian", "Hex", "Lilith", "Malachar", "Morwen", "Sable"]),
        &"marksman": PackedStringArray(["Arlen", "Blythe", "Cora", "Fletcher", "Hawke", "Ivo", "Petra", "Quinn"]),
    }
    for definition: ClassDefinition in catalog.classes:
        TestAssertions.truthy(definition.name_pool != null, "%s has name pool" % definition.id, failures)
        if definition.name_pool != null:
            TestAssertions.equal(definition.name_pool.id, definition.id, "%s name pool id" % definition.id, failures)
            TestAssertions.equal(definition.name_pool.names, expected_names[definition.id], "%s exact names" % definition.id, failures)
            TestAssertions.equal(definition.name_pool.resource_path, "res://data/names/%s.tres" % definition.id, "%s external name pool" % definition.id, failures)
        TestAssertions.equal(definition.name_pool.validate(8), PackedStringArray(), "%s name pool validates" % definition.id, failures)
        if EXPECTED_CAPABILITIES.has(definition.id):
            TestAssertions.equal(definition.capability_tags, EXPECTED_CAPABILITIES[definition.id], "%s explicit capabilities" % definition.id, failures)
        var expected_union: Array[StringName] = []
        expected_union.append_array(definition.traits)
        expected_union.append_array(definition.capability_tags)
        expected_union.sort()
        var deduped: Array[StringName] = []
        for tag: StringName in expected_union:
            if tag not in deduped:
                deduped.append(tag)
        TestAssertions.equal(definition.normalized_eligibility_tags(), deduped, "%s eligibility tags are deduped and sorted" % definition.id, failures)

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
        {"path": "res://data/attacks/paladin_smite.tres", "values": {"id": &"paladin_smite", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "power": 0.0, "cooldown": 1.05, "range": 2.1, "projectile_speed": 0.0, "area_radius": 1.4, "action_tags": [&"area", &"melee", &"physical"], "can_crit": true}, "damage_type": &"physical", "damage_amount": 16.0},
        {"path": "res://data/attacks/rogue_flurry.tres", "values": {"id": &"rogue_flurry", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "power": 0.0, "cooldown": 0.32, "range": 2.0, "projectile_speed": 0.0, "area_radius": 0.9, "action_tags": [&"area", &"melee", &"physical", &"skirmisher"], "can_crit": true}, "damage_type": &"physical", "damage_amount": 8.0},
        {"path": "res://data/attacks/frost_shard.tres", "values": {"id": &"frost_shard", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "power": 0.0, "cooldown": 1.35, "range": 12.5, "projectile_speed": 10.0, "area_radius": 3.0, "action_tags": [&"area", &"cold", &"projectile"], "can_crit": true}, "damage_type": &"cold", "damage_amount": 20.0},
        {"path": "res://data/attacks/warlock_bolt.tres", "values": {"id": &"warlock_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "power": 0.0, "cooldown": 1.75, "range": 12.5, "projectile_speed": 9.0, "area_radius": 0.0, "action_tags": [&"chaos", &"projectile", &"ranged"], "can_crit": true}, "damage_type": &"chaos", "damage_amount": 30.0},
        {"path": "res://data/attacks/marksman_heavy_shot.tres", "values": {"id": &"marksman_heavy_shot", "kind": AttackDefinition.Kind.PROJECTILE, "power": 0.0, "cooldown": 2.2, "range": 16.0, "projectile_speed": 22.0, "area_radius": 0.0, "action_tags": [&"bow", &"physical", &"projectile", &"ranged"], "can_crit": true}, "damage_type": &"physical", "damage_amount": 42.0},
        {"path": "res://data/attacks/boltcaster_bolt.tres", "values": {"id": &"boltcaster_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 2.4, "range": 16.0, "projectile_speed": 8.0, "area_radius": 0.0, "action_tags": [&"projectile", &"ranged"]}, "damage_type": &"physical", "damage_amount": 9.0},
    ]
    var class_rows: Array[Dictionary] = [
        {"path": "res://data/classes/fighter.tres", "values": {"id": &"fighter", "display_name": "Fighter", "role": ClassDefinition.Role.FRONTLINE, "color": Color("d94f4f"), "traits": [&"martial", &"vanguard"], "max_health": 260.0, "armor": 10.0, "move_speed": 6.2, "preferred_distance": 2.0, "engagement_distance": 5.0, "tether_distance": 9.0, "support_action": null}},
        {"path": "res://data/classes/ranger.tres", "values": {"id": &"ranger", "display_name": "Ranger", "role": ClassDefinition.Role.MIDLINE, "color": Color("5fbd72"), "traits": [&"martial", &"ranged"], "max_health": 90.0, "armor": 1.0, "move_speed": 6.6, "preferred_distance": 5.0, "engagement_distance": 11.0, "tether_distance": 11.0, "support_action": null}},
        {"path": "res://data/classes/mage.tres", "values": {"id": &"mage", "display_name": "Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("9567e8"), "traits": [&"arcane", &"caster", &"fire"], "max_health": 75.0, "armor": 0.0, "move_speed": 6.0, "preferred_distance": 6.5, "engagement_distance": 12.0, "tether_distance": 12.0, "support_action": null}},
        {"path": "res://data/classes/cleric.tres", "values": {"id": &"cleric", "display_name": "Cleric", "role": ClassDefinition.Role.SUPPORT, "color": Color("f0d15b"), "traits": [&"divine", &"support", &"caster"], "max_health": 95.0, "armor": 2.0, "move_speed": 6.0, "preferred_distance": 4.0, "engagement_distance": 10.0, "tether_distance": 10.0}},
        {"path": "res://data/classes/paladin.tres", "values": {"id": &"paladin", "display_name": "Paladin", "role": ClassDefinition.Role.FRONTLINE, "color": Color("e6c85f"), "traits": [&"divine", &"vanguard", &"martial"], "capability_tags": EXPECTED_CAPABILITIES[&"paladin"], "base_stat_overrides": {&"block_chance": 0.18, &"block_effectiveness": 0.55, &"health_regeneration": 1.5}, "max_health": 220.0, "armor": 18.0, "move_speed": 5.6, "preferred_distance": 2.0, "engagement_distance": 4.5, "tether_distance": 8.5, "support_action": null}},
        {"path": "res://data/classes/rogue.tres", "values": {"id": &"rogue", "display_name": "Rogue", "role": ClassDefinition.Role.MIDLINE, "color": Color("a95be8"), "traits": [&"martial", &"skirmisher"], "capability_tags": EXPECTED_CAPABILITIES[&"rogue"], "base_stat_overrides": {&"crit_chance": 0.20, &"crit_multiplier": 1.75, &"dodge_chance": 0.18, &"life_steal": 0.05}, "max_health": 72.0, "armor": 0.0, "move_speed": 7.4, "preferred_distance": 1.4, "engagement_distance": 3.0, "tether_distance": 8.0, "support_action": null}},
        {"path": "res://data/classes/frost_mage.tres", "values": {"id": &"frost_mage", "display_name": "Frost Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("70c8ff"), "traits": [&"arcane", &"caster", &"cold"], "capability_tags": EXPECTED_CAPABILITIES[&"frost_mage"], "base_stat_overrides": {}, "max_health": 78.0, "armor": 0.0, "move_speed": 6.0, "preferred_distance": 6.5, "engagement_distance": 12.5, "tether_distance": 12.5, "support_action": null}},
        {"path": "res://data/classes/warlock.tres", "values": {"id": &"warlock", "display_name": "Warlock", "role": ClassDefinition.Role.BACKLINE, "color": Color("7e4bc4"), "traits": [&"occult", &"caster", &"chaos"], "capability_tags": EXPECTED_CAPABILITIES[&"warlock"], "base_stat_overrides": {&"chaos_damage": 1.10, &"life_steal": 0.12}, "max_health": 82.0, "armor": 1.0, "move_speed": 5.8, "preferred_distance": 6.0, "engagement_distance": 12.5, "tether_distance": 12.5, "support_action": null}},
        {"path": "res://data/classes/marksman.tres", "values": {"id": &"marksman", "display_name": "Marksman", "role": ClassDefinition.Role.MIDLINE, "color": Color(0.27579924, 0.36415747, 0.056183092, 1.0), "traits": [&"martial", &"ranged", &"bow"], "capability_tags": EXPECTED_CAPABILITIES[&"marksman"], "base_stat_overrides": {&"crit_chance": 0.10, &"crit_multiplier": 2.0}, "max_health": 80.0, "armor": 2.0, "move_speed": 5.8, "preferred_distance": 8.0, "engagement_distance": 16.0, "tether_distance": 16.0, "support_action": null}},
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
        {"path": "res://data/enemies/boltcaster.tres", "values": {"id": &"boltcaster", "behavior": EnemyDefinition.Behavior.BOLTCASTER, "max_health": 15.0, "move_speed": 3.1, "stat_overrides": {}, "experience": 3}, "attacks": [&"boltcaster_bolt"]},
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
