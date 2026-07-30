class_name StatResolver
extends RefCounted

static func resolve(member_id: int, catalog: StatCatalog, base_values: Dictionary, capabilities: Array[StringName], sources: Array[StatModifierSource], action_tags: Array[StringName], revision: int) -> ResolvedStatSnapshot:
	var snapshot := ResolvedStatSnapshot.new()
	snapshot.revision = revision
	snapshot.capabilities = capabilities.duplicate()
	var tags := capabilities.duplicate()
	for tag: StringName in action_tags:
		if tag not in tags:
			tags.append(tag)
	for definition: StatDefinition in catalog.all():
		var base := float(base_values.get(definition.id, definition.default_value))
		var flat := 0.0
		var increased := 0.0
		var reduced := 0.0
		var more_factors: Array[float] = []
		var less_factors: Array[float] = []
		var rows: Array[Dictionary] = [{"source_id": &"base", "source_label": "Base", "operation": -1, "value": base}]
		for source: StatModifierSource in sources:
			if source == null or (source.owner_member_id != 0 and source.owner_member_id != member_id):
				continue
			for modifier: StatModifier in source.modifiers:
				if modifier == null or modifier.stat_id != definition.id or not modifier.applies_to(tags):
					continue
				match modifier.operation:
					StatModifier.Operation.FLAT:
						flat += modifier.value
					StatModifier.Operation.INCREASED:
						increased += modifier.value
					StatModifier.Operation.REDUCED:
						reduced += modifier.value
					StatModifier.Operation.MORE:
						more_factors.append(1.0 + modifier.value)
					StatModifier.Operation.LESS:
						less_factors.append(1.0 - modifier.value)
				rows.append({"source_id": modifier.source_id, "source_label": modifier.source_label, "operation": modifier.operation, "value": modifier.value})
		var effective := (base + flat) * (1.0 + increased - reduced)
		for factor: float in more_factors:
			effective *= factor
		for factor: float in less_factors:
			effective *= factor
		snapshot.set_resolved(definition.id, definition.finalize_value(effective), rows)
	return snapshot
