class_name PartyMemberState
extends RefCounted

var member_id: int
var character_name: String
var class_definition: ClassDefinition
var is_leader: bool
var capability_tags: Array[StringName] = []
var _modifier_sources: Array[StatModifierSource] = []
var modifier_sources: Array[StatModifierSource]:
    get:
        return _copy_sources(_modifier_sources)

func _init(id_value: int, definition: ClassDefinition, leader: bool, generated_name: String = "") -> void:
    member_id = id_value
    character_name = generated_name
    class_definition = definition
    is_leader = leader
    capability_tags = definition.capability_tags.duplicate()
    for trait_id: StringName in definition.traits:
        if trait_id not in capability_tags:
            capability_tags.append(trait_id)

func _add_modifier_source(source: StatModifierSource) -> void:
    var owned := _copy_source(source)
    owned.owner_member_id = member_id
    _modifier_sources.append(owned)

func _owned_modifier_sources() -> Array[StatModifierSource]:
    return _modifier_sources

func _copy_sources(sources: Array[StatModifierSource]) -> Array[StatModifierSource]:
    var copies: Array[StatModifierSource] = []
    for source: StatModifierSource in sources:
        copies.append(_copy_source(source))
    return copies

func _copy_source(source: StatModifierSource) -> StatModifierSource:
    if source == null:
        return null
    var modifiers: Array[StatModifier] = []
    for modifier: StatModifier in source.modifiers:
        if modifier == null:
            modifiers.append(null)
            continue
        var copied_modifier := StatModifier.create(
            modifier.stat_id,
            modifier.operation,
            modifier.value,
            modifier.source_id,
            modifier.source_label,
            modifier.required_tags,
            modifier.excluded_tags,
        )
        copied_modifier.required_capability_tags = modifier.required_capability_tags.duplicate()
        copied_modifier.excluded_capability_tags = modifier.excluded_capability_tags.duplicate()
        copied_modifier.required_action_tags = modifier.required_action_tags.duplicate()
        copied_modifier.excluded_action_tags = modifier.excluded_action_tags.duplicate()
        modifiers.append(copied_modifier)
    return StatModifierSource.create(source.id, source.source_type, source.label, source.owner_member_id, modifiers)
