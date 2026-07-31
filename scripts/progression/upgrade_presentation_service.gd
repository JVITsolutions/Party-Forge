class_name UpgradePresentationService
extends RefCounted

const MATCHING_INHERITANCE_TEXT := "Affects every matching current and future party member, including later recruits."


static func card(definition: UpgradeDefinition, party: PartyManager) -> Dictionary:
	return {
		"id": definition.id,
		"name": definition.display_name,
		"scope_badge": _scope_badge(definition),
		"rank_text": _rank_text(definition, party),
		"summary": definition.summary,
		"eligibility_text": _eligibility_text(definition),
		"recipient_text": _recipient_text(definition),
		"inheritance_text": _inheritance_text(definition),
	}


static func tooltip(
	definition: UpgradeDefinition,
	rank: int,
	stats: StatCatalog,
	keywords: KeywordCatalog
) -> Dictionary:
	var effect_lines: Array[String] = []
	for effect_definition: UpgradeEffectDefinition in definition.effects:
		var effect := effect_definition as StatUpgradeEffect
		if effect == null:
			continue
		var stat_definition: StatDefinition = stats.definition(effect.stat_id)
		var stat_name := effect.stat_id
		if stat_definition != null:
			stat_name = stat_definition.display_name
		effect_lines.append(_effect_line(effect, rank, stat_definition, stat_name))

	var keyword_lines: Array[String] = []
	for keyword_id: StringName in definition.tooltip_keyword_ids:
		var keyword: KeywordDefinition = keywords.definition(keyword_id)
		if keyword == null:
			keyword_lines.append("Missing definition: %s" % keyword_id)
		else:
			keyword_lines.append("%s: %s" % [keyword.display_name, keyword.explanation])

	return {
		"title": definition.display_name,
		"rank_text": "Offered rank %d / %d" % [rank, definition.max_rank],
		"description": definition.description,
		"effect_lines": effect_lines,
		"eligibility_text": _eligibility_text(definition),
		"inheritance_text": _inheritance_text(definition),
		"keyword_lines": keyword_lines,
	}


static func owned_tooltip(
	definition: UpgradeDefinition,
	rank: int,
	stats: StatCatalog,
	keywords: KeywordCatalog
) -> Dictionary:
	var content := tooltip(definition, rank, stats, keywords)
	content["rank_text"] = "Rank %d / %d" % [rank, definition.max_rank]
	return content


static func recipient_rows(
	definition: UpgradeDefinition,
	party: PartyManager,
	health_provider: Callable
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for member: PartyMemberState in party.members:
		var rank_owner_id := member.member_id if definition.is_single_recipient() else 0
		var current_rank := party.upgrade_rank(definition.id, rank_owner_id)
		var disabled_reason := UpgradeApplicationService.eligibility_reason(
			definition,
			party,
			member.member_id
		)
		if disabled_reason.is_empty() and current_rank >= definition.max_rank:
			disabled_reason = "Maximum rank reached."
		var eligible := disabled_reason.is_empty()
		var health := Vector2.ZERO
		if health_provider.is_valid():
			health = health_provider.call(member.member_id)

		var preview_lines: Array[String] = []
		if eligible:
			for preview: Dictionary in UpgradeApplicationService.preview_values(
				definition,
				party,
				member.member_id
			):
				var stat_definition: StatDefinition = PartyManager.STAT_CATALOG.definition(preview.stat_id)
				var stat_name := String(preview.stat_id)
				var before_text := _number_text(float(preview.before))
				var after_text := _number_text(float(preview.after))
				if stat_definition != null:
					stat_name = stat_definition.display_name
					before_text = stat_definition.format_value(float(preview.before))
					after_text = stat_definition.format_value(float(preview.after))
				preview_lines.append("%s: %s -> %s" % [stat_name, before_text, after_text])

		rows.append({
			"member_id": member.member_id,
			"character_name": member.character_name,
			"class_name": member.class_definition.display_name,
			"role_name": role_name(member.class_definition.role),
			"health_current": health.x,
			"health_maximum": health.y,
			"class_rank": party.get_class_rank(member.class_definition.id),
			"eligible": eligible,
			"disabled_reason": disabled_reason,
			"current_rank": current_rank,
			"next_rank": mini(current_rank + 1, definition.max_rank),
			"preview_lines": preview_lines,
		})
	return rows


static func role_name(role: ClassDefinition.Role) -> String:
	match role:
		ClassDefinition.Role.FRONTLINE:
			return "Frontline"
		ClassDefinition.Role.MIDLINE:
			return "Midline"
		ClassDefinition.Role.BACKLINE:
			return "Backline"
		ClassDefinition.Role.SUPPORT:
			return "Support"
		_:
			return "Unknown"


static func _rank_text(definition: UpgradeDefinition, party: PartyManager) -> String:
	if not definition.is_single_recipient():
		return "Rank %d / %d" % [party.upgrade_rank(definition.id), definition.max_rank]

	var ranks: Array[int] = []
	for member: PartyMemberState in party.members:
		if definition.is_member_eligible(member):
			ranks.append(party.upgrade_rank(definition.id, member.member_id))
	if ranks.is_empty():
		return "Rank 0 / %d" % definition.max_rank
	var first_rank := ranks[0]
	for rank: int in ranks:
		if rank != first_rank:
			return "Rank varies / %d" % definition.max_rank
	return "Rank %d / %d" % [first_rank, definition.max_rank]


static func _scope_badge(definition: UpgradeDefinition) -> String:
	match definition.scope:
		UpgradeDefinition.Scope.CHARACTER:
			return "Character"
		UpgradeDefinition.Scope.CLASS_SPECIFIC:
			if definition.allowed_class_ids.size() == 1:
				return "%s Signature" % String(definition.allowed_class_ids[0]).replace("_", " ").capitalize()
			return "Class Signature"
		UpgradeDefinition.Scope.PARTY:
			return "Party"
		UpgradeDefinition.Scope.TRAIT:
			return "Matching Party"
		_:
			return "Upgrade"


static func _eligibility_text(definition: UpgradeDefinition) -> String:
	var requirements: Array[String] = []
	if not definition.allowed_class_ids.is_empty():
		requirements.append("Eligible classes: %s" % _joined_ids(definition.allowed_class_ids))
	if not definition.required_all_tags.is_empty():
		requirements.append("Requires all traits or capabilities: %s" % _joined_ids(definition.required_all_tags))
	if not definition.required_any_tags.is_empty():
		requirements.append("Requires any trait or capability: %s" % _joined_ids(definition.required_any_tags))
	if not definition.excluded_tags.is_empty():
		requirements.append("Excludes traits or capabilities: %s" % _joined_ids(definition.excluded_tags))
	if requirements.is_empty():
		return "All party members are eligible."
	return " ".join(requirements)


static func _recipient_text(definition: UpgradeDefinition) -> String:
	if definition.is_single_recipient():
		return "Choose one eligible party member."
	if _has_matching_criteria(definition):
		return "Applies to every matching party member."
	if definition.scope == UpgradeDefinition.Scope.PARTY:
		return "Applies to the whole party."
	return "Applies to every matching party member."


static func _inheritance_text(definition: UpgradeDefinition) -> String:
	if definition.is_single_recipient():
		return ""
	if _has_matching_criteria(definition):
		return MATCHING_INHERITANCE_TEXT
	return ""


static func _has_matching_criteria(definition: UpgradeDefinition) -> bool:
	return (
		definition.scope == UpgradeDefinition.Scope.TRAIT
		or not definition.allowed_class_ids.is_empty()
		or not definition.required_all_tags.is_empty()
		or not definition.required_any_tags.is_empty()
		or not definition.excluded_tags.is_empty()
	)


static func _effect_line(
	effect: StatUpgradeEffect,
	rank: int,
	stat_definition: StatDefinition,
	stat_name: String
) -> String:
	var value := effect.value_for_rank(rank)
	match effect.operation:
		StatModifier.Operation.INCREASED:
			return "%s increased %s." % [_percent_text(value), stat_name]
		StatModifier.Operation.REDUCED:
			return "%s reduced %s." % [_percent_text(value), stat_name]
		StatModifier.Operation.MORE:
			return "%s more %s." % [_percent_text(value), stat_name]
		StatModifier.Operation.LESS:
			return "%s less %s." % [_percent_text(value), stat_name]
		StatModifier.Operation.FLAT:
			if (
				stat_definition != null
				and stat_definition.value_format == StatDefinition.ValueFormat.RATIO_PERCENT
				and stat_definition.default_value <= 1.0
			):
				return "+%s percentage points %s." % [_number_text(value * 100.0), stat_name]
			return "+%s %s." % [_number_text(value), stat_name]
		_:
			return "%s: %s." % [stat_name, _number_text(value)]


static func _percent_text(value: float) -> String:
	return "%s%%" % _number_text(value * 100.0)


static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.4f" % value).rstrip("0").rstrip(".")


static func _joined_ids(ids: Array[StringName]) -> String:
	var labels: PackedStringArray = []
	for id: StringName in ids:
		labels.append(String(id).replace("_", " ").capitalize())
	return ", ".join(labels)
