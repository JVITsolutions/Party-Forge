class_name GameCatalog
extends RefCounted

const CLASS_PATHS: PackedStringArray = [
    "res://data/classes/fighter.tres", "res://data/classes/ranger.tres",
    "res://data/classes/mage.tres", "res://data/classes/cleric.tres"
]
const TRAIT_PATHS: PackedStringArray = [
    "res://data/traits/martial.tres", "res://data/traits/vanguard.tres",
    "res://data/traits/ranged.tres", "res://data/traits/arcane.tres",
    "res://data/traits/caster.tres", "res://data/traits/divine.tres",
    "res://data/traits/support.tres"
]
const ENEMY_PATHS: PackedStringArray = [
    "res://data/enemies/swarmer.tres", "res://data/enemies/spitter.tres",
    "res://data/enemies/forge_guardian.tres"
]

var classes: Array[ClassDefinition] = []
var traits: Array[TraitDefinition] = []
var enemies: Array[EnemyDefinition] = []

static func load_defaults() -> GameCatalog:
    var catalog := GameCatalog.new()
    for path: String in CLASS_PATHS:
        catalog.classes.append(load(path) as ClassDefinition)
    for path: String in TRAIT_PATHS:
        catalog.traits.append(load(path) as TraitDefinition)
    for path: String in ENEMY_PATHS:
        catalog.enemies.append(load(path) as EnemyDefinition)
    return catalog

func class_by_id(id: StringName) -> ClassDefinition:
    for definition: ClassDefinition in classes:
        if definition != null and definition.id == id: return definition
    return null

func trait_by_id(id: StringName) -> TraitDefinition:
    for definition: TraitDefinition in traits:
        if definition != null and definition.id == id: return definition
    return null

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    var seen: Dictionary = {}
    var resources: Array[Resource] = []
    for definition: ClassDefinition in classes: resources.append(definition)
    for definition: TraitDefinition in traits: resources.append(definition)
    for definition: EnemyDefinition in enemies: resources.append(definition)
    for definition: Resource in resources:
        if definition == null:
            errors.append("PARTY_FORGE_RESOURCE_ERROR reason=resource failed to load")
            continue
        var id: StringName = definition.get("id")
        if seen.has(id): errors.append("PARTY_FORGE_RESOURCE_ERROR reason=duplicate id %s" % id)
        seen[id] = true
        var validation: PackedStringArray = definition.call("validate")
        for reason: String in validation:
            errors.append("PARTY_FORGE_RESOURCE_ERROR id=%s reason=%s" % [id, reason])
    return errors
