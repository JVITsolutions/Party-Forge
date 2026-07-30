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
    var failures: int = 0
    for id: StringName in attacks:
        if not _save_resource(attacks[id], "res://data/attacks/%s.tres" % id):
            failures += 1
    if failures > 0:
        _finish_failed(failures)
        return

    var saved_attacks: Dictionary = {}
    for id: StringName in attacks:
        var path: String = "res://data/attacks/%s.tres" % id
        var loaded: AttackDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as AttackDefinition
        if loaded == null:
            push_error("PARTY_FORGE_DATA_LOAD_ERROR path=%s" % path)
            failures += 1
        else:
            saved_attacks[id] = loaded
    if failures > 0:
        _finish_failed(failures)
        return

    if not _save_class(&"fighter", "Fighter", ClassDefinition.Role.FRONTLINE, Color("d94f4f"), [&"martial", &"vanguard"], 260.0, 10.0, 6.2, 2.0, 5.0, 9.0, saved_attacks[&"fighter_cleave"], null): failures += 1
    if not _save_class(&"ranger", "Ranger", ClassDefinition.Role.MIDLINE, Color("5fbd72"), [&"martial", &"ranged"], 90.0, 1.0, 6.6, 5.0, 11.0, 11.0, saved_attacks[&"ranger_shot"], null): failures += 1
    if not _save_class(&"mage", "Mage", ClassDefinition.Role.BACKLINE, Color("9567e8"), [&"arcane", &"ranged", &"caster"], 75.0, 0.0, 6.0, 6.5, 12.0, 12.0, saved_attacks[&"mage_burst"], null): failures += 1
    if not _save_class(&"cleric", "Cleric", ClassDefinition.Role.SUPPORT, Color("f0d15b"), [&"divine", &"support", &"caster"], 95.0, 2.0, 6.0, 4.0, 10.0, 10.0, saved_attacks[&"cleric_bolt"], saved_attacks[&"cleric_heal"]): failures += 1

    if not _save_trait(&"martial", "Martial", &"attack_speed", {2: 0.15, 4: 0.35}): failures += 1
    if not _save_trait(&"vanguard", "Vanguard", &"nearby_damage_reduction", {2: 0.12, 4: 0.28}, 6.0): failures += 1
    if not _save_trait(&"ranged", "Ranged", &"projectile_speed_and_range", {2: 0.15, 4: 0.35}): failures += 1
    if not _save_trait(&"arcane", "Arcane", &"area_size", {2: 0.18, 4: 0.40}): failures += 1
    if not _save_trait(&"caster", "Caster", &"cooldown_reduction", {2: 0.12, 4: 0.28}): failures += 1
    if not _save_trait(&"divine", "Divine", &"healing_and_revive", {2: 0.18, 4: 0.40}): failures += 1
    if not _save_trait(&"support", "Support", &"support_power", {2: 0.15, 4: 0.35}): failures += 1

    if not _save_enemy(&"swarmer", EnemyDefinition.Behavior.SWARMER, 12.0, 4.8, 2, ["res://data/attacks/swarmer_contact.tres"]): failures += 1
    if not _save_enemy(&"spitter", EnemyDefinition.Behavior.SPITTER, 18.0, 2.8, 4, ["res://data/attacks/spitter_projectile.tres"]): failures += 1
    if not _save_enemy(&"forge_guardian", EnemyDefinition.Behavior.FORGE_GUARDIAN, 3000.0, 3.3, 100, ["res://data/attacks/guardian_charge.tres", "res://data/attacks/guardian_shockwave.tres"]): failures += 1
    if failures > 0:
        _finish_failed(failures)
        return
    print("DATA_GENERATION_OK")
    quit(0)

func _attack(id: StringName, kind: AttackDefinition.Kind, power: float, cooldown: float, range_value: float, speed: float, radius: float) -> AttackDefinition:
    var value := AttackDefinition.new()
    value.id = id; value.kind = kind; value.power = power; value.cooldown = cooldown
    value.range = range_value; value.projectile_speed = speed; value.area_radius = radius
    return value

func _save_class(id: StringName, name_value: String, role: ClassDefinition.Role, color: Color, traits: Array[StringName], health: float, armor: float, speed: float, preferred: float, engagement: float, tether: float, primary: AttackDefinition, support: AttackDefinition) -> bool:
    var value := ClassDefinition.new()
    value.id = id; value.display_name = name_value; value.role = role; value.color = color; value.traits = traits
    value.max_health = health; value.armor = armor; value.move_speed = speed
    value.class_rank_power_step = 0.2; value.revive_delay = 8.0; value.revive_health_fraction = 0.5
    value.preferred_distance = preferred; value.engagement_distance = engagement; value.tether_distance = tether
    value.primary_attack = primary; value.support_action = support
    return _save_resource(value, "res://data/classes/%s.tres" % id)

func _save_trait(id: StringName, name_value: String, stat: StringName, tiers: Dictionary, effect_radius: float = 0.0) -> bool:
    var value := TraitDefinition.new()
    value.id = id; value.display_name = name_value; value.stat_id = stat; value.tiers = tiers
    value.effect_radius = effect_radius
    return _save_resource(value, "res://data/traits/%s.tres" % id)

func _save_enemy(id: StringName, behavior: EnemyDefinition.Behavior, health: float, speed: float, experience: int, attack_paths: Array[String]) -> bool:
    var value := EnemyDefinition.new()
    value.id = id; value.behavior = behavior; value.max_health = health; value.move_speed = speed
    value.experience = experience
    for attack_path: String in attack_paths:
        value.attacks.append(load(attack_path) as AttackDefinition)
    return _save_resource(value, "res://data/enemies/%s.tres" % id)

func _save_resource(value: Resource, path: String) -> bool:
    var save_error: Error = ResourceSaver.save(value, path)
    if save_error != OK:
        push_error("PARTY_FORGE_DATA_SAVE_ERROR path=%s error=%d" % [path, save_error])
        return false
    return true

func _finish_failed(failures: int) -> void:
    push_error("PARTY_FORGE_DATA_GENERATION_FAILED failures=%d" % failures)
    quit(1)
