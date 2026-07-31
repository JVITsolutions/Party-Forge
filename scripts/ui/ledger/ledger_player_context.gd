class_name LedgerPlayerContext
extends RefCounted

var local_player_id := 0
var selected_member_id := 0
var active_page_id: StringName = &"stats"
var last_focus_path := NodePath()
var opened_by_player_id := 0

func _init(player_id := 0) -> void:
	local_player_id = player_id
	opened_by_player_id = player_id

func ensure_valid_member(party: PartyManager, preferred_member_id: int = 0) -> int:
	if party == null or party.members.is_empty():
		selected_member_id = 0
		return 0
	if party.member_by_id(selected_member_id) != null:
		return selected_member_id
	if preferred_member_id > 0 and party.member_by_id(preferred_member_id) != null:
		selected_member_id = preferred_member_id
	else:
		selected_member_id = party.members[0].member_id
	return selected_member_id
