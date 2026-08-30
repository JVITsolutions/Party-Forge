class_name LevelUpApplicationPolicy
extends RefCounted


func evaluate(
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
	member_id: int,
) -> LevelUpApplicationResult:
	var choice_key := choice.key() if choice != null else ""
	if choice == null:
		return LevelUpApplicationResult.rejected(choice_key, member_id, "This upgrade is no longer available.")
	if party == null:
		return LevelUpApplicationResult.rejected(choice_key, member_id, "The party is no longer available.")
	if catalog == null:
		return LevelUpApplicationResult.rejected(choice_key, member_id, "Upgrade information is no longer available.")

	match choice.kind:
		UpgradeChoice.Kind.RECRUIT:
			return _evaluate_recruit(choice, party, catalog)
		UpgradeChoice.Kind.CLASS_RANK:
			if catalog.class_by_id(choice.target_id) == null:
				return _rejected(choice, member_id, "That class is no longer available.")
			if party.get_class_rank(choice.target_id) <= 0:
				return _rejected(choice, member_id, "That class is no longer represented in the party.")
		UpgradeChoice.Kind.TRAIT:
			if catalog.trait_by_id(choice.target_id) == null:
				return _rejected(choice, member_id, "That trait is no longer available.")
			if party.active_tier(choice.target_id) <= 0:
				return _rejected(choice, member_id, "That trait is no longer active in the party.")
		UpgradeChoice.Kind.PARTY_STAT:
			if choice.target_id not in PartyManager.PARTY_STAT_IDS:
				return _rejected(choice, member_id, "That party upgrade is no longer available.")
			if party.party_stat_rank(choice.target_id) >= party.upgrade_tuning.party_stat_max_rank:
				return _rejected(choice, member_id, "This upgrade has reached its maximum rank.")
		UpgradeChoice.Kind.AUTHORED:
			return _evaluate_authored(choice, party, catalog, member_id)
		_:
			return _rejected(choice, member_id, "This upgrade is no longer available.")
	return LevelUpApplicationResult.accepted(choice_key, 0)


func _evaluate_recruit(
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
) -> LevelUpApplicationResult:
	if catalog.class_by_id(choice.target_id) == null:
		return _rejected(choice, 0, "That recruit is no longer available.")
	if not party.can_recruit():
		return _rejected(choice, 0, "The party is full.")
	return LevelUpApplicationResult.accepted(choice.key(), 0)


func _evaluate_authored(
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
	member_id: int,
) -> LevelUpApplicationResult:
	var definition := catalog.upgrade_by_id(choice.target_id)
	if choice.definition == null or definition == null or not is_same(choice.definition, definition):
		return _rejected(choice, member_id, "This offer is no longer available.")
	var recipient_id := member_id if choice.application_route() == UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION else 0
	if choice.application_route() == UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION and recipient_id <= 0:
		return _rejected(choice, member_id, "Choose an eligible party member.")
	var errors := UpgradeApplicationService.validate_application(definition, party, recipient_id)
	if not errors.is_empty():
		return _rejected(choice, member_id, _readable_application_error(definition, party, recipient_id, errors))
	return LevelUpApplicationResult.accepted(choice.key(), recipient_id)


func _readable_application_error(
	definition: UpgradeDefinition,
	party: PartyManager,
	member_id: int,
	errors: PackedStringArray,
) -> String:
	if definition.is_single_recipient():
		var eligibility := UpgradeApplicationService.eligibility_reason(definition, party, member_id)
		if not eligibility.is_empty():
			return _readable_eligibility_reason(eligibility)
	var joined := " ".join(errors).to_lower()
	if "maximum rank reached" in joined:
		return "This upgrade has reached its maximum rank."
	if "no eligible party member" in joined:
		return "No eligible party member remains."
	return "This upgrade can no longer be applied."


func _readable_eligibility_reason(reason: String) -> String:
	var normalized := reason.strip_edges()
	if normalized == "Member is no longer available.":
		return "That party member is no longer available."
	if normalized == "Class is not eligible.":
		return "Choose a party member from an eligible class."
	if normalized == "Requires one matching eligibility tag.":
		return "Choose a party member who meets at least one listed requirement."
	if normalized.begins_with("Requires "):
		return "Choose a party member who meets every listed requirement."
	if normalized.begins_with("Excluded by "):
		return "Choose a party member without an excluded requirement."
	return "Choose an eligible party member."


func _rejected(choice: UpgradeChoice, member_id: int, reason: String) -> LevelUpApplicationResult:
	return LevelUpApplicationResult.rejected(choice.key(), member_id, reason)
