class_name ForgePartyMemberMarker
extends ForgePartyMemberCard


func _format_name(member: PartyMemberHudProjection) -> String:
	return member.display_name.to_upper()


func _format_class(member: PartyMemberHudProjection) -> String:
	return "%s  ·  L%d" % [member.class_label.to_upper(), member.level]
