class_name PartyManager
extends Node

signal member_added(member: PartyMemberState)
signal class_rank_changed(class_id: StringName, rank: int)
signal active_traits_changed(tiers: Dictionary)

const MAX_PARTY_SIZE := 4
var members: Array[PartyMemberState] = []
var class_ranks: Dictionary = {}
var trait_definitions: Array[TraitDefinition] = []
var active_tiers: Dictionary = {}

func initialize(leader_class: ClassDefinition, traits: Array[TraitDefinition]) -> void:
    members.clear(); class_ranks.clear(); active_tiers.clear(); trait_definitions = traits
    _append_member(leader_class, true)

func recruit(definition: ClassDefinition) -> bool:
    if definition == null or members.size() >= MAX_PARTY_SIZE:
        return false
    _append_member(definition, false)
    return true

func rank_up(class_id: StringName) -> bool:
    if not class_ranks.has(class_id):
        return false
    class_ranks[class_id] = int(class_ranks[class_id]) + 1
    class_rank_changed.emit(class_id, int(class_ranks[class_id]))
    return true

func get_class_rank(class_id: StringName) -> int:
    return int(class_ranks.get(class_id, 0))

func trait_count(trait_id: StringName) -> int:
    var count := 0
    for member: PartyMemberState in members:
        if trait_id in member.class_definition.traits:
            count += 1
    return count

func active_tier(trait_id: StringName) -> int:
    return int(active_tiers.get(trait_id, 0))

func _append_member(definition: ClassDefinition, leader: bool) -> void:
    var member := PartyMemberState.new(members.size() + 1, definition, leader)
    members.append(member)
    if not class_ranks.has(definition.id): class_ranks[definition.id] = 1
    _recalculate_traits()
    member_added.emit(member)

func _recalculate_traits() -> void:
    var next: Dictionary = {}
    for definition: TraitDefinition in trait_definitions:
        var count: int = trait_count(definition.id)
        var achieved := 0
        for threshold: Variant in definition.tiers.keys():
            if count >= int(threshold): achieved = maxi(achieved, int(threshold))
        if achieved > 0: next[definition.id] = achieved
    if next != active_tiers:
        active_tiers = next
        active_traits_changed.emit(active_tiers.duplicate())
