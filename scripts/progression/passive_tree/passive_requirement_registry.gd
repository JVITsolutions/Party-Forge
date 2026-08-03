class_name PassiveRequirementRegistry
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PASSIVE_REQUIREMENT_ERROR"

func validate(requirement: PassiveTreeRequirement) -> String:
	if requirement == null:
		return "%s requirement=null reason=requirement must not be null" % ERROR_PREFIX
	if requirement.requirement_id != &"allocated_node":
		return "%s requirement=%s reason=unknown requirement ID" % [ERROR_PREFIX, requirement.requirement_id]
	if requirement.operator != &"contains":
		return "%s requirement=%s reason=operator must equal contains" % [ERROR_PREFIX, requirement.requirement_id]
	if not _is_kebab_case(requirement.value):
		return "%s requirement=%s field=value reason=value must be a non-empty kebab-case node ID string" % [ERROR_PREFIX, requirement.requirement_id]
	if requirement.parameters.size() != 1 or not requirement.parameters.has("treeId"):
		return "%s requirement=%s field=parameters reason=parameters must contain exactly {treeId}" % [ERROR_PREFIX, requirement.requirement_id]
	if not _is_kebab_case(requirement.parameters["treeId"]):
		return "%s requirement=%s field=treeId reason=treeId must be a non-empty kebab-case string" % [ERROR_PREFIX, requirement.requirement_id]
	return ""

func display_name(requirement_id: StringName) -> String:
	return "Allocated Node" if requirement_id == &"allocated_node" else ""

func describe(requirement: PassiveTreeRequirement) -> String:
	if requirement == null or not validate(requirement).is_empty():
		return ""
	return "Requires allocated node: %s (%s)." % [requirement.value, requirement.parameters["treeId"]]

func keyword_explanation(requirement_id: StringName) -> String:
	if requirement_id != &"allocated_node":
		return ""
	return "Allocated Node: Requires the named node to be allocated in the named passive tree."

func _is_kebab_case(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := value as String
	if text.is_empty() or text.begins_with("-") or text.ends_with("-") or "--" in text:
		return false
	for index: int in text.length():
		var code := text.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 45):
			return false
	return true
