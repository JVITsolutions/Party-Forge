class_name ResolvedStatComparisonService
extends RefCounted


static func compare(
	current: ResolvedStatSnapshot,
	candidate: ResolvedStatSnapshot,
	catalog: StatCatalog,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current == null or candidate == null or catalog == null:
		return result
	for definition: StatDefinition in catalog.all():
		if definition == null:
			continue
		var before := current.value(definition.id, definition.default_value)
		var after := candidate.value(definition.id, definition.default_value)
		if not is_finite(before) or not is_finite(after):
			continue
		var delta := after - before
		if is_zero_approx(delta):
			continue
		var benefit := 1 if definition.comparison_direction == StatDefinition.ComparisonDirection.HIGHER_IS_BETTER else -1 if definition.comparison_direction == StatDefinition.ComparisonDirection.LOWER_IS_BETTER else 0
		var direction := int(signf(delta)) * benefit
		var symbol := "▲" if direction > 0 else "▼" if direction < 0 else "•"
		var meaning := "improved" if direction > 0 else "reduced" if direction < 0 else "changed"
		var formatted_delta := _format_delta(definition, absf(delta))
		var signed_delta := "%s%s" % ["+" if delta > 0.0 else "-", formatted_delta]
		var text := "%s %s %s — %s" % [symbol, signed_delta, definition.display_name, meaning]
		result.append({
			"row_type": "stat",
			"stat_id": definition.id,
			"delta": delta,
			"direction": direction,
			"text": text,
			"accessible_text": "%s; %s" % [text, meaning],
		})
	return result


static func _format_delta(definition: StatDefinition, value: float) -> String:
	return definition.format_modifier_value(value)
