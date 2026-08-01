class_name LevelUpOfferState
extends RefCounted

var offer_sequence := 0
var consecutive_eligible_without_recruit := 0

func seed_for(run_seed: int, pending_level: int, party_size: int) -> int:
	return hash("%d:%d:%d:%d" % [run_seed, offer_sequence, pending_level, party_size])

func record_recruit_result(eligible: bool, recruit_count: int) -> void:
	if not eligible:
		return
	if recruit_count > 0:
		consecutive_eligible_without_recruit = 0
	else:
		consecutive_eligible_without_recruit += 1
