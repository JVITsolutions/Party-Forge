class_name WarehouseAccessPolicy
extends RefCounted

enum State { BLOCKED, AVAILABLE }

static func resolve(profile: Variant) -> State:
	if not profile is ProfileState:
		return State.BLOCKED
	var typed_profile := profile as ProfileState
	return State.AVAILABLE if "stash" in typed_profile.permanent_feature_unlocks else State.BLOCKED
