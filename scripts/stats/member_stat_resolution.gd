class_name MemberStatResolution
extends RefCounted

var error := ""
var raw_attributes: ResolvedStatSnapshot
var derived_source: StatModifierSource
var final_stats: ResolvedStatSnapshot

static func success(
	raw: ResolvedStatSnapshot,
	projected_source: StatModifierSource,
	resolved: ResolvedStatSnapshot,
) -> MemberStatResolution:
	var result := MemberStatResolution.new()
	result.raw_attributes = raw
	result.derived_source = projected_source
	result.final_stats = resolved
	return result

static func failure(message: String) -> MemberStatResolution:
	var result := MemberStatResolution.new()
	result.error = message
	return result

func ok() -> bool:
	return error.is_empty() and raw_attributes != null and derived_source != null and final_stats != null
