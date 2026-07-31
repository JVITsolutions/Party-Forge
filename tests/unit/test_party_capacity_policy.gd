extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var minimum := PartyCapacityPolicy.new(1)
	TestAssertions.equal(minimum.capacity(), 1, "minimum policy keeps one party slot", failures)
	TestAssertions.truthy(not minimum.can_add(1), "minimum policy rejects member two", failures)
	var maximum := PartyCapacityPolicy.new(24)
	TestAssertions.equal(maximum.capacity(), 24, "developer policy keeps twenty-four party slots", failures)
	TestAssertions.truthy(maximum.can_add(1, 23), "developer policy accepts members through slot twenty-four", failures)
	TestAssertions.truthy(not maximum.can_add(24), "developer policy rejects member twenty-five", failures)
	return failures
