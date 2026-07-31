class_name UpgradeChoice
extends RefCounted

enum Kind { RECRUIT, CLASS_RANK, TRAIT, PARTY_STAT, AUTHORED }
var kind: Kind
var target_id: StringName
var label: String
var definition: UpgradeDefinition

func _init(kind_value: Kind, target: StringName, label_value: String) -> void:
    kind = kind_value; target_id = target; label = label_value

func key() -> String:
    return "%d:%s" % [kind, target_id]

static func authored(card: UpgradeDefinition) -> UpgradeChoice:
    var choice := UpgradeChoice.new(Kind.AUTHORED, card.id, card.display_name)
    choice.definition = card
    return choice

func requires_recipient() -> bool:
    return kind == Kind.AUTHORED and definition != null and definition.is_single_recipient()

func is_valid_for(party: PartyManager) -> bool:
    if party == null:
        return false
    match kind:
        Kind.RECRUIT: return party.can_recruit()
        Kind.CLASS_RANK: return party.get_class_rank(target_id) > 0
        Kind.TRAIT: return party.active_tier(target_id) > 0
        Kind.PARTY_STAT: return target_id in PartyManager.PARTY_STAT_IDS and party.party_stat_rank(target_id) < party.upgrade_tuning.party_stat_max_rank
        Kind.AUTHORED:
            if definition == null:
                return false
            if requires_recipient():
                for member_id: int in UpgradeApplicationService.eligible_member_ids(definition, party):
                    if UpgradeApplicationService.validate_application(definition, party, member_id).is_empty():
                        return true
                return false
            return UpgradeApplicationService.validate_application(definition, party).is_empty()
    return false
