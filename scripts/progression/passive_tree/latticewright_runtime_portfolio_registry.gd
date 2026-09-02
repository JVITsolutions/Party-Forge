class_name LatticewrightRuntimePortfolioRegistry
extends RefCounted

var _runtimes: Dictionary = {}

func register_runtime(runtime: Dictionary) -> String:
	var header := LatticewrightRuntimeHeader.validate(runtime)
	if not header.ok():
		return header.error
	if _runtimes.has(header.project_id):
		return _error("projectId", "duplicate project '%s'" % header.project_id)
	var graph_ids: Dictionary = {}
	var graphs := runtime.get("graphs") as Array
	for index: int in graphs.size():
		if not graphs[index] is Dictionary:
			return _error("graphs[%d]" % index, "must be a JSON object")
		var graph := graphs[index] as Dictionary
		var graph_id_value: Variant = graph.get("id")
		if not graph_id_value is String or String(graph_id_value).strip_edges().is_empty():
			return _error("graphs[%d].id" % index, "must be a non-empty string")
		var graph_id := StringName(graph_id_value as String)
		if graph_ids.has(graph_id):
			return _error("graphs[%d].id" % index, "duplicate graph '%s'" % graph_id)
		graph_ids[graph_id] = true
	_runtimes[header.project_id] = {
		"runtime": runtime.duplicate(true),
		"graph_ids": graph_ids.duplicate(true),
	}
	return ""

func has_graph(project_id: StringName, graph_id: StringName) -> bool:
	if not _runtimes.has(project_id):
		return false
	var record := _runtimes[project_id] as Dictionary
	return (record.get("graph_ids") as Dictionary).has(graph_id)

func unregister_runtime(project_id: StringName) -> void:
	_runtimes.erase(project_id)

func copy() -> LatticewrightRuntimePortfolioRegistry:
	var result := LatticewrightRuntimePortfolioRegistry.new()
	result._runtimes = _runtimes.duplicate(true)
	return result

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_PASSIVE_TREE_PORTFOLIO_ERROR field=%s reason=%s" % [field, reason]
