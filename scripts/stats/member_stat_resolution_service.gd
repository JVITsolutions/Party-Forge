class_name MemberStatResolutionService
extends RefCounted

static func resolve(
	member_id: int,
	catalog: StatCatalog,
	base_values: Dictionary,
	capabilities: Array[StringName],
	sources: Array[StatModifierSource],
	action_tags: Array[StringName],
	revision: int,
	tuning: AttributeProjectionTuning,
) -> MemberStatResolution:
	var source_errors := StatResolver.validate_sources(catalog, sources)
	if not source_errors.is_empty():
		return MemberStatResolution.failure(source_errors[0])

	var raw := StatResolver.resolve(member_id, catalog, base_values, capabilities, sources, [], revision)
	var raw_error := _snapshot_error(member_id, catalog, raw, "raw")
	if not raw_error.is_empty():
		return MemberStatResolution.failure(raw_error)
	var projection := AttributeDerivedSourceProjector.project(member_id, raw, tuning)
	if not projection.ok():
		return MemberStatResolution.failure(projection.error)
	var projection_error := AttributeDerivedSourceProjector.validate_source(projection.source)
	if not projection_error.is_empty():
		return MemberStatResolution.failure(projection_error)

	var final_sources := sources.duplicate()
	final_sources.append(projection.source)
	var final_source_errors := StatResolver.validate_sources(catalog, final_sources)
	if not final_source_errors.is_empty():
		return MemberStatResolution.failure(final_source_errors[0])
	var final := StatResolver.resolve(member_id, catalog, base_values, capabilities, final_sources, action_tags, revision)
	var final_error := _snapshot_error(member_id, catalog, final, "final")
	if not final_error.is_empty():
		return MemberStatResolution.failure(final_error)
	return MemberStatResolution.success(raw, projection.source, final)


static func _snapshot_error(
	member_id: int,
	catalog: StatCatalog,
	snapshot: ResolvedStatSnapshot,
	stage: String,
) -> String:
	for definition: StatDefinition in catalog.all():
		if definition == null:
			continue
		var value := snapshot.value(definition.id, NAN)
		if not is_finite(value):
			return "PARTY_FORGE_STAT_RESOLUTION_ERROR member=%d stat=%s stage=%s value=%s reason=resolved value is non-finite" % [
				member_id, definition.id, stage, str(value),
			]
	return ""
