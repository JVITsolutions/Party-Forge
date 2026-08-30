class_name UpgradeOfferProjectionService
extends RefCounted


func build(
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
	disabled_reason: String = "",
) -> UpgradeOfferProjection:
	var result := UpgradeOfferProjection.new()
	if choice == null:
		result.disabled_reason = disabled_reason if not disabled_reason.is_empty() else "This upgrade is no longer available."
		return result
	result.choice_key = choice.key()
	result.target_id = choice.target_id
	result.disabled_reason = disabled_reason
	if choice.kind == UpgradeChoice.Kind.AUTHORED:
		return _build_authored(result, choice, party, catalog)
	return _build_foundational(result, choice, party, catalog)


func build_all(
	choices: Array[UpgradeChoice],
	party: PartyManager,
	catalog: GameCatalog,
	disabled_reason: String = "",
) -> Array[UpgradeOfferProjection]:
	var result: Array[UpgradeOfferProjection] = []
	for choice: UpgradeChoice in choices:
		result.append(build(choice, party, catalog, disabled_reason))
	return result


func _build_authored(
	result: UpgradeOfferProjection,
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
) -> UpgradeOfferProjection:
	var definition := catalog.upgrade_by_id(choice.target_id) if catalog != null else null
	if definition == null:
		result.display_name = choice.label
		if result.disabled_reason.is_empty():
			result.disabled_reason = "This upgrade is no longer available."
		return result
	var content := UpgradePresentationService.card(definition, party)
	result.category_id = content.get("category_id", &"")
	result.icon_id = content.get("icon_id", &"")
	result.display_name = str(content.get("name", definition.display_name))
	result.rarity_label = str(content.get("rarity_label", ""))
	# Before a recipient is selected, authored prose is the only universal effect truth.
	result.effect_text = definition.summary
	result.scope_text = _scope_text(content)
	result.rank_text = str(content.get("rank_text", ""))
	result.eligibility_text = str(content.get("eligibility_text", ""))
	result.recipient_tags.assign(content.get("recipient_tags", []))
	result.class_tags.assign(content.get("class_tags", []))
	return result


func _build_foundational(
	result: UpgradeOfferProjection,
	choice: UpgradeChoice,
	party: PartyManager,
	catalog: GameCatalog,
) -> UpgradeOfferProjection:
	var content := FoundationalUpgradePresentationService.card(choice, party, catalog)
	result.category_id = content.get("category_id", &"")
	result.icon_id = content.get("icon_id", &"")
	result.display_name = str(content.get("name", choice.label))
	result.rarity_label = str(content.get("rarity_label", ""))
	result.effect_text = str(content.get("summary", ""))
	if choice.kind == UpgradeChoice.Kind.RECRUIT:
		result.effect_text = _recruit_effect(choice, catalog)
	result.scope_text = _scope_text(content)
	if choice.kind == UpgradeChoice.Kind.RECRUIT:
		var recruit_definition := catalog.class_by_id(choice.target_id) if catalog != null else null
		if recruit_definition != null:
			result.scope_text = "Recruit • %s" % UpgradePresentationService.role_name(recruit_definition.role)
	result.rank_text = str(content.get("rank_text", ""))
	result.eligibility_text = str(content.get("eligibility_text", ""))
	result.recipient_tags.assign(content.get("recipient_tags", []))
	result.class_tags.assign(content.get("class_tags", []))
	return result


func _recruit_effect(choice: UpgradeChoice, catalog: GameCatalog) -> String:
	var definition := catalog.class_by_id(choice.target_id) if catalog != null else null
	if definition == null:
		return "Recruitment details are unavailable."
	var trait_names := PackedStringArray()
	for trait_id: StringName in definition.traits:
		var trait_definition := catalog.trait_by_id(trait_id)
		if trait_definition != null:
			trait_names.append(trait_definition.display_name)
	var result := "Recruit a %s %s." % [UpgradePresentationService.role_name(definition.role), definition.display_name]
	if not trait_names.is_empty():
		result += " Traits: %s." % ", ".join(trait_names)
	return result


func _scope_text(content: Dictionary) -> String:
	var lines := PackedStringArray()
	for key: String in ["recipient_text", "inheritance_text"]:
		var line := str(content.get(key, "")).strip_edges()
		if not line.is_empty():
			lines.append(line)
	return " ".join(lines)
