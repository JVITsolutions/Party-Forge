extends SceneTree

func _initialize() -> void:
    for path: String in ["res://data/attacks", "res://data/classes", "res://data/traits", "res://data/enemies"]:
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
    var attacks: Dictionary = {}
    attacks[&"fighter_cleave"] = _attack(&"fighter_cleave", AttackDefinition.Kind.MELEE_CLEAVE, 18.0, 0.8, 2.2, 0.0, 1.6)
    attacks[&"ranger_shot"] = _attack(&"ranger_shot", AttackDefinition.Kind.PROJECTILE, 11.0, 0.55, 11.0, 16.0, 0.0)
    attacks[&"mage_burst"] = _attack(&"mage_burst", AttackDefinition.Kind.AREA_PROJECTILE, 24.0, 1.5, 12.0, 11.0, 2.5)
    attacks[&"cleric_bolt"] = _attack(&"cleric_bolt", AttackDefinition.Kind.PROJECTILE, 8.0, 1.0, 10.0, 13.0, 0.0)
    attacks[&"cleric_heal"] = _attack(&"cleric_heal", AttackDefinition.Kind.HEAL, 18.0, 3.0, 9.0, 0.0, 0.0)
    for id: StringName in attacks:
        ResourceSaver.save(attacks[id], "res://data/attacks/%s.tres" % id)

    _save_class(&"fighter", "Fighter", ClassDefinition.Role.FRONTLINE, Color("d94f4f"), [&"martial", &"vanguard"], 140.0, 6.0, 6.2, 2.0, 5.0, 9.0, attacks[&"fighter_cleave"], null)
    _save_class(&"ranger", "Ranger", ClassDefinition.Role.MIDLINE, Color("5fbd72"), [&"martial", &"ranged"], 90.0, 1.0, 6.6, 5.0, 11.0, 11.0, attacks[&"ranger_shot"], null)
    _save_class(&"mage", "Mage", ClassDefinition.Role.BACKLINE, Color("9567e8"), [&"arcane", &"ranged", &"caster"], 75.0, 0.0, 6.0, 6.5, 12.0, 12.0, attacks[&"mage_burst"], null)
    _save_class(&"cleric", "Cleric", ClassDefinition.Role.SUPPORT, Color("f0d15b"), [&"divine", &"support", &"caster"], 95.0, 2.0, 6.0, 4.0, 10.0, 10.0, attacks[&"cleric_bolt"], attacks[&"cleric_heal"])

    _save_trait(&"martial", "Martial", &"attack_speed", {2: 0.15, 4: 0.35})
    _save_trait(&"vanguard", "Vanguard", &"nearby_damage_reduction", {2: 0.12, 4: 0.28})
    _save_trait(&"ranged", "Ranged", &"projectile_speed_and_range", {2: 0.15, 4: 0.35})
    _save_trait(&"arcane", "Arcane", &"area_size", {2: 0.18, 4: 0.40})
    _save_trait(&"caster", "Caster", &"cooldown_reduction", {2: 0.12, 4: 0.28})
    _save_trait(&"divine", "Divine", &"healing_and_revive", {2: 0.18, 4: 0.40})
    _save_trait(&"support", "Support", &"support_power", {2: 0.15, 4: 0.35})

    _save_enemy(&"swarmer", EnemyDefinition.Behavior.SWARMER, 24.0, 4.8, 8.0, 2)
    _save_enemy(&"spitter", EnemyDefinition.Behavior.SPITTER, 42.0, 2.8, 10.0, 4)
    _save_enemy(&"forge_guardian", EnemyDefinition.Behavior.FORGE_GUARDIAN, 1500.0, 3.3, 22.0, 100)
    print("DATA_GENERATION_OK")
    quit(0)

func _attack(id: StringName, kind: AttackDefinition.Kind, power: float, cooldown: float, range_value: float, speed: float, radius: float) -> AttackDefinition:
    var value := AttackDefinition.new()
    value.id = id; value.kind = kind; value.power = power; value.cooldown = cooldown
    value.range = range_value; value.projectile_speed = speed; value.area_radius = radius
    return value

func _save_class(id: StringName, name_value: String, role: ClassDefinition.Role, color: Color, traits: Array[StringName], health: float, armor: float, speed: float, preferred: float, engagement: float, tether: float, primary: AttackDefinition, support: AttackDefinition) -> void:
    var value := ClassDefinition.new()
    value.id = id; value.display_name = name_value; value.role = role; value.color = color; value.traits = traits
    value.max_health = health; value.armor = armor; value.move_speed = speed
    value.preferred_distance = preferred; value.engagement_distance = engagement; value.tether_distance = tether
    value.primary_attack = primary; value.support_action = support
    ResourceSaver.save(value, "res://data/classes/%s.tres" % id)

func _save_trait(id: StringName, name_value: String, stat: StringName, tiers: Dictionary) -> void:
    var value := TraitDefinition.new()
    value.id = id; value.display_name = name_value; value.stat_id = stat; value.tiers = tiers
    ResourceSaver.save(value, "res://data/traits/%s.tres" % id)

func _save_enemy(id: StringName, behavior: EnemyDefinition.Behavior, health: float, speed: float, damage: float, experience: int) -> void:
    var value := EnemyDefinition.new()
    value.id = id; value.behavior = behavior; value.max_health = health; value.move_speed = speed
    value.contact_damage = damage; value.experience = experience
    ResourceSaver.save(value, "res://data/enemies/%s.tres" % id)
