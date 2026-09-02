class_name PlayerItemDropAccessPolicy
extends RefCounted

const REQUIRED_FEATURES: Array[StringName] = [&"equipment_inventory", &"inventory"]

static func allows(
	profile: ProfileState,
	run_inventory: ItemSlotContainer,
	feature_policy: FeatureAccessPolicy,
) -> bool:
	if profile == null or run_inventory == null or feature_policy == null or run_inventory.capacity <= 0:
		return false
	for feature_id: StringName in REQUIRED_FEATURES:
		if feature_policy.resolve(feature_id, FeatureAccessPolicy.State.AVAILABLE, feature_id) != FeatureAccessPolicy.State.AVAILABLE:
			return false
	return true
