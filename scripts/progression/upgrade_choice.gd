class_name UpgradeChoice
extends RefCounted

enum Kind { RECRUIT, CLASS_RANK, TRAIT, PARTY_STAT }
var kind: Kind
var target_id: StringName
var label: String

func _init(kind_value: Kind, target: StringName, label_value: String) -> void:
    kind = kind_value; target_id = target; label = label_value

func key() -> String:
    return "%d:%s" % [kind, target_id]

func is_valid_for(party: PartyManager) -> bool:
    match kind:
        Kind.RECRUIT: return party.members.size() < PartyManager.MAX_PARTY_SIZE
        Kind.CLASS_RANK: return party.get_class_rank(target_id) > 0
        Kind.TRAIT: return party.active_tier(target_id) > 0
        Kind.PARTY_STAT: return true
    return false
