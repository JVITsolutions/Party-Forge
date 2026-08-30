class_name FoundationalUpgradePresentationService
extends RefCounted

const TRAIT_STAT_KEYWORD_IDS := {
	&"cooldown_reduction": [&"cooldown_rate"],
	&"healing_and_revive": [&"healing_power", &"healing"],
	&"nearby_damage_reduction": [&"less"],
	&"projectile_speed_and_range": [&"projectile_speed", &"attack_range"],
	&"support_power": [&"healing_power"],
}


static func card(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary:
	if choice == null or party == null or catalog == null:
		return _with_projection_metadata(_fallback_card(choice), choice, catalog)
	var content: Dictionary
	match choice.kind:
		UpgradeChoice.Kind.CLASS_RANK:
			content = _class_rank_card(choice, party, catalog)
		UpgradeChoice.Kind.RECRUIT:
			content = _recruit_card(choice, catalog)
		UpgradeChoice.Kind.TRAIT:
			content = _trait_card(choice, party, catalog)
		UpgradeChoice.Kind.PARTY_STAT:
			content = _party_stat_card(choice, party)
		_:
			content = _fallback_card(choice)
	return _with_projection_metadata(content, choice, catalog)


static func tooltip(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary:
	var card_content := card(choice, party, catalog)
	if choice == null or party == null or catalog == null:
		return _tooltip_from_card(card_content, card_content.get("summary", ""), [], [])
	match choice.kind:
		UpgradeChoice.Kind.CLASS_RANK:
			var definition := catalog.class_by_id(choice.target_id)
			var description: String = str(card_content.get("summary", ""))
			if definition != null:
				description = "Train the %s class to increase Damage for every current and future %s." % [definition.display_name, "%ss" % definition.display_name]
			return _tooltip_from_card(card_content, description, [card_content.get("summary", "")], _keyword_lines([&"damage", &"increased"], catalog))
		UpgradeChoice.Kind.RECRUIT:
			return _recruit_tooltip(choice, card_content, catalog)
		UpgradeChoice.Kind.TRAIT:
			var trait_definition := catalog.trait_by_id(choice.target_id)
			var description: String = str(card_content.get("summary", ""))
			if trait_definition != null:
				description = "Strengthen the active %s party-composition synergy." % trait_definition.display_name
			var trait_keywords: Array[StringName] = [choice.target_id]
			if trait_definition != null:
				trait_keywords.append_array(_trait_stat_keyword_ids(trait_definition, catalog))
			return _tooltip_from_card(card_content, description, [card_content.get("summary", "")], _keyword_lines(trait_keywords, catalog))
		UpgradeChoice.Kind.PARTY_STAT:
			var stat_definition := PartyManager.STAT_CATALOG.definition(choice.target_id)
			var stat_name := stat_definition.display_name if stat_definition != null else _display_id(choice.target_id)
			var stat_keywords: Array[StringName] = [&"increased"]
			if stat_definition != null:
				stat_keywords.push_front(stat_definition.keyword_id)
			return _tooltip_from_card(card_content, "Improve %s for the whole party." % stat_name, [card_content.get("summary", "")], _keyword_lines(stat_keywords, catalog))
		_:
			return _tooltip_from_card(card_content, card_content.get("summary", ""), [], [])


static func _class_rank_card(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary:
	var definition := catalog.class_by_id(choice.target_id)
	if definition == null:
		return _fallback_card(choice)
	var current_rank := party.get_class_rank(choice.target_id)
	var next_rank := current_rank + 1
	var step := definition.class_rank_power_step
	var current_percent := roundi(float(maxi(current_rank - 1, 0)) * step * 100.0)
	var next_percent := roundi(float(maxi(next_rank - 1, 0)) * step * 100.0)
	var plural := "%ss" % definition.display_name
	return {
		"name": "Train %s" % definition.display_name,
		"scope_badge": "Class Rank",
		"rank_text": "Rank %d -> %d" % [current_rank, next_rank],
		"summary": "%d%% -> %d%% increased Damage." % [current_percent, next_percent],
		"eligibility_text": "Requires the class to be represented in the party.",
		"recipient_text": "Applies to all current %s." % plural,
		"inheritance_text": "All current and future %s inherit this class rank." % plural,
	}


static func _recruit_card(choice: UpgradeChoice, catalog: GameCatalog) -> Dictionary:
	var definition := catalog.class_by_id(choice.target_id)
	if definition == null:
		return _fallback_card(choice)
	return {
		"name": "Recruit %s" % definition.display_name,
		"scope_badge": "Recruit",
		"rank_text": "",
		"summary": "Add a %s to the party." % definition.display_name,
		"eligibility_text": "Requires an open party slot.",
		"recipient_text": "Adds one new %s." % definition.display_name,
		"inheritance_text": "The recruit inherits current class, trait, and party-wide bonuses.",
	}


static func _recruit_tooltip(choice: UpgradeChoice, card_content: Dictionary, catalog: GameCatalog) -> Dictionary:
	var definition := catalog.class_by_id(choice.target_id)
	if definition == null:
		return _tooltip_from_card(card_content, card_content.get("summary", ""), [], [])
	var trait_names := PackedStringArray()
	for trait_id: StringName in definition.traits:
		var trait_definition := catalog.trait_by_id(trait_id)
		trait_names.append(trait_definition.display_name if trait_definition != null else _display_id(trait_id))
	var effect_lines: Array[String] = []
	if not trait_names.is_empty():
		effect_lines.append("Traits: %s." % ", ".join(trait_names))
	var description := "Recruit a %s %s." % [UpgradePresentationService.role_name(definition.role), definition.display_name]
	return _tooltip_from_card(card_content, description, effect_lines, _keyword_lines(definition.normalized_eligibility_tags(), catalog))


static func _trait_card(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary:
	var definition := catalog.trait_by_id(choice.target_id)
	if definition == null:
		return _fallback_card(choice)
	var tier := party.active_tier(choice.target_id)
	var current_rank := party.trait_upgrade_rank(choice.target_id)
	var next_rank := current_rank + 1
	var base_value := float(definition.tiers.get(tier, 0.0))
	var step := party.upgrade_tuning.trait_upgrade_value_step
	var current_percent := base_value * (1.0 + float(current_rank) * step) * 100.0
	var next_percent := base_value * (1.0 + float(next_rank) * step) * 100.0
	var effect_name := _keyword_display_name(definition.stat_id, catalog)
	return {
		"name": "Strengthen %s" % definition.display_name,
		"scope_badge": "Trait Rank",
		"rank_text": "Mastery %d -> %d" % [current_rank, next_rank],
		"summary": "%s: %s -> %s %s." % [definition.display_name, _percent_text(current_percent), _percent_text(next_percent), effect_name],
		"eligibility_text": "Requires the %s trait to be active." % definition.display_name,
		"recipient_text": "Applies to all current members with the %s trait." % definition.display_name,
		"inheritance_text": "All current and future members with the %s trait inherit this mastery." % definition.display_name,
	}


static func _party_stat_card(choice: UpgradeChoice, party: PartyManager) -> Dictionary:
	var definition := PartyManager.STAT_CATALOG.definition(choice.target_id)
	if definition == null:
		return _fallback_card(choice)
	var current_rank := party.party_stat_rank(choice.target_id)
	var next_rank := mini(current_rank + 1, party.upgrade_tuning.party_stat_max_rank)
	var step := _party_stat_step(choice.target_id, party.upgrade_tuning)
	var current_percent := roundi(float(current_rank) * step * 100.0)
	var next_percent := roundi(float(next_rank) * step * 100.0)
	return {
		"name": "Party %s" % definition.display_name,
		"scope_badge": "Party",
		"rank_text": "Rank %d -> %d" % [current_rank, next_rank],
		"summary": "%d%% -> %d%% increased %s." % [current_percent, next_percent, definition.display_name],
		"eligibility_text": "Available until Rank %d." % party.upgrade_tuning.party_stat_max_rank,
		"recipient_text": "Applies to all current party members.",
		"inheritance_text": "All current and future party members inherit this upgrade.",
	}


static func _party_stat_step(stat_id: StringName, tuning: UpgradeTuning) -> float:
	match stat_id:
		&"max_health":
			return tuning.max_health_per_rank
		&"damage":
			return tuning.damage_per_rank
		&"move_speed":
			return tuning.move_speed_per_rank
		&"attack_speed":
			return tuning.attack_speed_per_rank
		&"pickup_radius":
			return tuning.pickup_radius_per_rank
		_:
			return 0.0


static func _trait_stat_keyword_ids(definition: TraitDefinition, catalog: GameCatalog) -> Array[StringName]:
	var keyword_ids: Array[StringName] = []
	if TRAIT_STAT_KEYWORD_IDS.has(definition.stat_id):
		keyword_ids.assign(TRAIT_STAT_KEYWORD_IDS[definition.stat_id])
	elif catalog.keywords != null and catalog.keywords.has_definition(definition.stat_id):
		keyword_ids.append(definition.stat_id)
	return keyword_ids


static func _percent_text(value: float) -> String:
	return "%s%%" % ("%.4f" % value).rstrip("0").rstrip(".")


static func _tooltip_from_card(card_content: Dictionary, description: String, effect_lines: Array, keyword_lines: Array) -> Dictionary:
	return {
		"title": card_content.get("name", "Unavailable"),
		"rank_text": card_content.get("rank_text", ""),
		"description": description,
		"effect_lines": effect_lines,
		"eligibility_text": card_content.get("eligibility_text", ""),
		"inheritance_text": card_content.get("inheritance_text", ""),
		"keyword_lines": keyword_lines,
	}


static func _keyword_lines(keyword_ids: Array[StringName], catalog: GameCatalog) -> Array[String]:
	var lines: Array[String] = []
	for keyword_id: StringName in keyword_ids:
		if keyword_id.is_empty():
			continue
		var keyword := catalog.keywords.definition(keyword_id) if catalog.keywords != null else null
		var line := "Missing definition: %s" % keyword_id
		if keyword != null:
			line = "%s: %s" % [keyword.display_name, keyword.explanation]
		if line not in lines:
			lines.append(line)
	return lines


static func _keyword_display_name(keyword_id: StringName, catalog: GameCatalog) -> String:
	var keyword := catalog.keywords.definition(keyword_id) if catalog.keywords != null else null
	return keyword.display_name if keyword != null else _display_id(keyword_id)


static func _display_id(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()


static func _fallback_card(choice: UpgradeChoice) -> Dictionary:
	return {
		"name": choice.label if choice != null else "Unavailable",
		"scope_badge": "Upgrade",
		"rank_text": "",
		"summary": "Upgrade details are unavailable.",
		"eligibility_text": "",
		"recipient_text": "",
		"inheritance_text": "",
	}


static func _with_projection_metadata(
	content: Dictionary,
	choice: UpgradeChoice,
	catalog: GameCatalog,
) -> Dictionary:
	var result := content.duplicate(true)
	result["category_id"] = _category_id(choice)
	result["icon_id"] = &""
	result["rarity_label"] = ""
	result["recipient_tags"] = _recipient_tags(choice, catalog)
	result["class_tags"] = _class_tags(choice, catalog)
	return result


static func _category_id(choice: UpgradeChoice) -> StringName:
	if choice == null:
		return &""
	match choice.kind:
		UpgradeChoice.Kind.RECRUIT:
			return &"recruit"
		UpgradeChoice.Kind.CLASS_RANK:
			return &"class_rank"
		UpgradeChoice.Kind.TRAIT:
			return &"trait"
		UpgradeChoice.Kind.PARTY_STAT:
			return &"party_stat"
	return &""


static func _recipient_tags(choice: UpgradeChoice, catalog: GameCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	if choice == null:
		return result
	if choice.kind == UpgradeChoice.Kind.TRAIT and catalog != null and catalog.trait_by_id(choice.target_id) != null:
		result.append(choice.target_id)
	elif choice.kind == UpgradeChoice.Kind.RECRUIT and catalog != null:
		var definition := catalog.class_by_id(choice.target_id)
		if definition != null:
			for trait_id: StringName in definition.traits:
				if catalog.trait_by_id(trait_id) != null:
					result.append(trait_id)
	return result


static func _class_tags(choice: UpgradeChoice, catalog: GameCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	if choice == null or catalog == null:
		return result
	if choice.kind in [UpgradeChoice.Kind.RECRUIT, UpgradeChoice.Kind.CLASS_RANK] and catalog.class_by_id(choice.target_id) != null:
		result.append(choice.target_id)
	return result
