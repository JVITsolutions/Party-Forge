extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.0, 0), 0, "roll starts zero-recruit band", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.449999, 0), 0, "zero-recruit band ends below 45 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.45, 0), 1, "one-recruit band begins at 45 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.849999, 0), 1, "one-recruit band ends below 85 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.85, 0), 2, "two-recruit band begins at 85 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.969999, 0), 2, "two-recruit band ends below 97 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.97, 0), 3, "three-recruit band begins at 97 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(-1.0, 0), 0, "negative roll clamps to zero", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(1.0, 0), 3, "unit roll clamps below one", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(INF, 0), 0, "positive infinity uses safe zero roll", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(-INF, 0), 0, "negative infinity uses safe zero roll", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(NAN, 0), 0, "not-a-number uses safe zero roll", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.1, 3), 1, "three misses force one recruit", failures)
	var state := LevelUpOfferState.new()
	for _index: int in 3:
		state.record_recruit_result(true, 0)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 3, "eligible misses accumulate drought", failures)
	state.record_recruit_result(false, 0)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 3, "ineligible offer preserves drought", failures)
	state.record_recruit_result(true, 1)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 0, "recruit clears drought", failures)
	var first_seed := state.seed_for(1337, 2, 1)
	state.offer_sequence += 1
	TestAssertions.truthy(first_seed != state.seed_for(1337, 2, 1), "offer sequence changes seed", failures)
	TestAssertions.truthy(first_seed != LevelUpOfferState.new().seed_for(7331, 2, 1), "run seed changes offer seed", failures)
	TestAssertions.truthy(first_seed != LevelUpOfferState.new().seed_for(1337, 3, 1), "pending level changes offer seed", failures)
	TestAssertions.truthy(first_seed != LevelUpOfferState.new().seed_for(1337, 2, 2), "party size changes offer seed", failures)
	return failures
