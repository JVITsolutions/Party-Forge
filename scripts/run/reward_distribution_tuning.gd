class_name RewardDistributionTuning
extends Resource

@export var leader_event_share_radius := 18.0
@export var follower_squad_link_radius := 14.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(leader_event_share_radius) or leader_event_share_radius <= 0.0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=leader_event_share_radius")
	if not is_finite(follower_squad_link_radius) or follower_squad_link_radius <= 0.0:
		errors.append("PARTY_FORGE_REWARD_ERROR field=follower_squad_link_radius")
	return errors
