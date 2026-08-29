extends RefCounted

const POLICY_PATH := "res://scripts/world/access/warehouse_access_policy.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(FileAccess.file_exists(POLICY_PATH), "Warehouse access policy exists", failures)
	if not FileAccess.file_exists(POLICY_PATH):
		return failures
	var policy := load(POLICY_PATH)
	TestAssertions.truthy(policy != null, "Warehouse access policy loads", failures)
	if policy == null:
		return failures
	TestAssertions.equal(policy.resolve(null), 0, "null profile is blocked", failures)
	TestAssertions.equal(policy.resolve(RefCounted.new()), 0, "wrong profile type is blocked", failures)
	var profile := ProfileState.new_profile("warehouse-policy", "Warehouse Policy", 1)
	var before_locked := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 0, "profile without stash is blocked", failures)
	TestAssertions.equal(profile.to_dictionary(), before_locked, "locked policy evaluation does not mutate profile", failures)
	profile.permanent_feature_unlocks = ["equipment_inventory", "stash", "stash"]
	var before_unlocked := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 1, "profile with stash is available", failures)
	TestAssertions.equal(profile.to_dictionary(), before_unlocked, "unlocked policy evaluation does not mutate profile", failures)
	profile.permanent_feature_unlocks.clear()
	var before_cleared := profile.to_dictionary()
	TestAssertions.equal(policy.resolve(profile), 0, "later input mutation does not leave cached access", failures)
	TestAssertions.equal(profile.to_dictionary(), before_cleared, "re-evaluation after input mutation remains read-only", failures)
	return failures
