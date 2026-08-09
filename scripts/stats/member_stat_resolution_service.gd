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
	var projection := AttributeDerivedSourceProjector.project(member_id, raw, tuning)
	if not projection.ok():
		return MemberStatResolution.failure(projection.error)
	var projection_error := AttributeDerivedSourceProjector.validate_source(projection.source)
	if not projection_error.is_empty():
		return MemberStatResolution.failure(projection_error)

	var final_sources := sources.duplicate()
	final_sources.append(projection.source)
	var final := StatResolver.resolve(member_id, catalog, base_values, capabilities, final_sources, action_tags, revision)
	return MemberStatResolution.success(raw, projection.source, final)
