extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists("res://scripts/progression/level_up_application_result.gd"):
		failures.append("typed LevelUpApplicationResult script is missing")
		return failures
	if not FileAccess.file_exists("res://scripts/progression/level_up_application_policy.gd"):
		failures.append("LevelUpApplicationPolicy script is missing")
		return failures
	_test_routes_validate_without_mutation(failures)
	_test_targeted_choices_require_current_recipient_authority(failures)
	_test_recruitment_uses_current_catalog_and_capacity(failures)
	_test_stale_authored_choice_is_readable(failures)
	_test_null_and_capped_inputs_are_readable(failures)
	_test_policy_re_resolves_current_catalog_definition(failures)
	return failures


func _test_routes_validate_without_mutation(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var before_members := party.members.size()
	var before_rank := party.party_stat_rank(&"damage")
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Forged visual label")
	var result: RefCounted = _policy().call("evaluate", choice, party, catalog, 0)
	TestAssertions.truthy(result.ok(), "valid direct choice is accepted", failures)
	TestAssertions.equal(result.choice_key, choice.key(), "result retains exact choice identity", failures)
	TestAssertions.equal(result.recipient_member_id, 0, "direct result has no recipient", failures)
	TestAssertions.equal(party.members.size(), before_members, "policy does not recruit while evaluating", failures)
	TestAssertions.equal(party.party_stat_rank(&"damage"), before_rank, "policy does not apply an upgrade while evaluating", failures)
	party.free()


func _test_targeted_choices_require_current_recipient_authority(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye"))
	var policy := _policy()
	var missing: RefCounted = policy.call("evaluate", choice, party, catalog, 0)
	TestAssertions.truthy(not missing.ok(), "targeted choice requires a member", failures)
	TestAssertions.truthy("Choose" in missing.reason, "missing-recipient rejection is player-readable", failures)
	var ineligible: RefCounted = policy.call("evaluate", choice, party, catalog, 1)
	TestAssertions.truthy(not ineligible.ok(), "targeted choice rejects an ineligible member", failures)
	TestAssertions.truthy(not ineligible.reason.is_empty(), "ineligible-recipient rejection is readable", failures)
	var accepted: RefCounted = policy.call("evaluate", choice, party, catalog, 2)
	TestAssertions.truthy(accepted.ok(), "targeted choice accepts a current eligible member", failures)
	TestAssertions.equal(accepted.recipient_member_id, 2, "targeted result keeps the stable recipient id", failures)
	party.free()


func _test_recruitment_uses_current_catalog_and_capacity(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var policy := _policy()
	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Decorative text cannot route")
	var before_members := party.members.size()
	TestAssertions.truthy(policy.evaluate(recruit, party, catalog, 0).ok(), "catalog-backed recruit is accepted with capacity", failures)
	TestAssertions.equal(party.members.size(), before_members, "recruit evaluation is mutation-free", failures)
	var stale: RefCounted = policy.call("evaluate", UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"retired_class", "Recruit Retired"), party, catalog, 0)
	TestAssertions.truthy(not stale.ok() and "no longer" in stale.reason, "missing recruit definition has a readable stale reason", failures)
	party.configure_capacity(PartyCapacityPolicy.new(1))
	var full: RefCounted = policy.call("evaluate", recruit, party, catalog, 0)
	TestAssertions.truthy(not full.ok() and "full" in full.reason.to_lower(), "recruit capacity rejection is readable", failures)
	party.free()


func _test_stale_authored_choice_is_readable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var retired := catalog.upgrade_by_id(&"vitality").duplicate(true) as UpgradeDefinition
	retired.id = &"retired_upgrade"
	var stale: RefCounted = _policy().call("evaluate", UpgradeChoice.authored(retired), party, catalog, 1)
	TestAssertions.truthy(not stale.ok(), "stale authored choice is rejected", failures)
	TestAssertions.truthy("no longer" in stale.reason, "stale authored rejection is player-readable", failures)
	TestAssertions.truthy(stale.reason.ends_with("."), "stale rejection is a complete sentence", failures)
	TestAssertions.truthy("PARTY_FORGE_" not in stale.reason and "retired_upgrade" not in stale.reason, "player rejection hides diagnostics and raw ids", failures)
	TestAssertions.equal(party.members[0].upgrade_rank(retired.id), 0, "stale evaluation does not mutate member ranks", failures)
	party.free()


func _test_null_and_capped_inputs_are_readable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var policy := _policy()
	for result: RefCounted in [
		policy.call("evaluate", null, party, catalog, 0),
		policy.call("evaluate", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"), null, catalog, 0),
		policy.call("evaluate", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"), party, null, 0),
	]:
		TestAssertions.truthy(not bool(result.call("ok")), "missing authority rejects evaluation", failures)
		TestAssertions.truthy(not String(result.get("reason")).is_empty() and String(result.get("reason")).ends_with("."), "missing authority has a complete readable reason", failures)

	var wall := catalog.upgrade_by_id(&"vanguard_wall")
	TestAssertions.truthy(UpgradeApplicationService.apply(wall.id, catalog, party), "capped policy fixture applies its only rank", failures)
	var before_rank := party.upgrade_rank(wall.id)
	var capped: RefCounted = policy.call("evaluate", UpgradeChoice.authored(wall), party, catalog, 0)
	TestAssertions.truthy(not capped.ok() and "maximum rank" in capped.reason.to_lower(), "capped choice has a readable rejection", failures)
	TestAssertions.equal(party.upgrade_rank(wall.id), before_rank, "capped evaluation remains mutation-free", failures)
	party.free()


func _test_policy_re_resolves_current_catalog_definition(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var stale_definition := catalog.upgrade_by_id(&"deadeye").duplicate(true) as UpgradeDefinition
	stale_definition.scope = UpgradeDefinition.Scope.PARTY
	stale_definition.allowed_class_ids = []
	var stale_choice := UpgradeChoice.authored(stale_definition)
	TestAssertions.equal(stale_choice.application_route(), 0, "stale fixture itself looks direct", failures)
	var result: RefCounted = _policy().call("evaluate", stale_choice, party, catalog, 0)
	TestAssertions.truthy(not result.ok(), "policy rejects missing recipient using current catalog definition", failures)
	TestAssertions.truthy("Choose" in result.reason, "current targeted authority supplies the readable route reason", failures)
	party.free()


func _policy() -> RefCounted:
	return (load("res://scripts/progression/level_up_application_policy.gd") as Script).new()
