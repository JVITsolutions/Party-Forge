class_name PassiveTreeLoader
extends RefCounted

const FORMAT := "passive-skill-tree"
const FORMAT_VERSION := 1
const OPERATIONS: Array[StringName] = [&"add_flat", &"add_percent", &"multiply", &"set", &"custom"]
const DIRECTIONS: Array[StringName] = [&"bidirectional", &"forward"]
const ERROR_PREFIX := "PARTY_FORGE_PASSIVE_TREE_ERROR path="
const SIGNED_64_MIN_AS_FLOAT := -9223372036854775808.0
const SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT := 9223372036854775808.0

func load_path(path: String) -> PassiveTreeLoadResult:
	var result := PassiveTreeLoadResult.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_error(result.errors, path, "document", "could not read UTF-8 JSON document")
		return result
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		_add_error(result.errors, path, "document", "must contain valid JSON: %s at line %d" % [parser.get_error_message(), parser.get_error_line()])
		return result
	if not parser.data is Dictionary:
		_add_error(result.errors, path, "document", "JSON root must be a JSON object")
		return result
	return load_dictionary(parser.data as Dictionary, path)

func load_dictionary(document: Dictionary, source_path: String) -> PassiveTreeLoadResult:
	var result := PassiveTreeLoadResult.new()
	var errors := result.errors

	_validate_exact_string(document.get("format"), FORMAT, "format", source_path, errors)
	_validate_exact_integer(document.get("formatVersion"), FORMAT_VERSION, "formatVersion", source_path, errors)
	var tree_id := _string_name(document.get("treeId"), "treeId", source_path, errors)
	var tree_name := _required_string(document.get("name"), "name", source_path, errors)
	var starting_values := _array(document.get("startingNodeIds"), "startingNodeIds", source_path, errors)
	var node_values := _array(document.get("nodes"), "nodes", source_path, errors)
	var connection_values := _array(document.get("connections"), "connections", source_path, errors)
	var metadata := _dictionary(document.get("metadata"), "metadata", source_path, errors)

	var starting_node_ids: Array[StringName] = []
	var starting_seen: Dictionary = {}
	for index: int in starting_values.size():
		var starting_id := _string_name(starting_values[index], "startingNodeIds[%d]" % index, source_path, errors)
		if starting_id == &"":
			continue
		if starting_seen.has(starting_id):
			_add_error(errors, source_path, "startingNodeIds[%d]" % index, "duplicate starting node id '%s'" % starting_id)
		else:
			starting_seen[starting_id] = true
			starting_node_ids.append(starting_id)

	var nodes: Array[PassiveTreeNode] = []
	var node_ids: Dictionary = {}
	var node_types: Dictionary = {}
	for index: int in node_values.size():
		var field := "nodes[%d]" % index
		if not node_values[index] is Dictionary:
			_add_error(errors, source_path, field, "must be a JSON object")
			continue
		var node_document := node_values[index] as Dictionary
		var node_id := _string_name(node_document.get("id"), "%s.id" % field, source_path, errors)
		var node_type := _string_name(node_document.get("type"), "%s.type" % field, source_path, errors)
		var node_name := _required_string(node_document.get("name"), "%s.name" % field, source_path, errors)
		var description := _required_string_value(node_document.get("description"), "%s.description" % field, source_path, errors)
		var position := _position(node_document.get("position"), "%s.position" % field, source_path, errors)
		var cost := _non_negative_integer(node_document.get("cost"), "%s.cost" % field, source_path, errors)
		var tags := _string_name_array(node_document.get("tags"), "%s.tags" % field, source_path, errors)
		var icon: Variant = node_document.get("icon")
		if icon != null and not icon is String:
			_add_error(errors, source_path, "%s.icon" % field, "must be a string or null")
		var effects := _effects(node_document.get("effects"), "%s.effects" % field, source_path, errors)
		var requirements := _requirements(node_document.get("requirements"), "%s.requirements" % field, source_path, errors)
		var node_metadata := _dictionary(node_document.get("metadata"), "%s.metadata" % field, source_path, errors)
		if node_id != &"":
			if node_ids.has(node_id):
				_add_error(errors, source_path, "%s.id" % field, "duplicate node id '%s'" % node_id)
			else:
				node_ids[node_id] = true
				node_types[node_id] = node_type
		nodes.append(PassiveTreeNode.new(node_id, node_type, position, node_name, description, cost, tags, icon, effects, requirements, node_metadata))

	for index: int in starting_node_ids.size():
		var starting_id := starting_node_ids[index]
		if not node_ids.has(starting_id):
			_add_error(errors, source_path, "startingNodeIds[%d]" % index, "references missing node '%s'" % starting_id)
		elif node_types.get(starting_id) != &"start":
			_add_error(errors, source_path, "startingNodeIds[%d]" % index, "node '%s' must have type=start" % starting_id)

	var connections: Array[PassiveTreeConnection] = []
	var connection_ids: Dictionary = {}
	var endpoint_pairs: Dictionary = {}
	for index: int in connection_values.size():
		var field := "connections[%d]" % index
		if not connection_values[index] is Dictionary:
			_add_error(errors, source_path, field, "must be a JSON object")
			continue
		var connection_document := connection_values[index] as Dictionary
		var connection_id := _string_name(connection_document.get("id"), "%s.id" % field, source_path, errors)
		var from_id := _string_name(connection_document.get("from"), "%s.from" % field, source_path, errors)
		var to_id := _string_name(connection_document.get("to"), "%s.to" % field, source_path, errors)
		var direction := _string_name(connection_document.get("direction"), "%s.direction" % field, source_path, errors)
		var connection_cost := _non_negative_integer(connection_document.get("cost"), "%s.cost" % field, source_path, errors)
		var conditions := _requirements(connection_document.get("conditions"), "%s.conditions" % field, source_path, errors)
		var connection_metadata := _dictionary(connection_document.get("metadata"), "%s.metadata" % field, source_path, errors)
		if connection_id != &"":
			if connection_ids.has(connection_id):
				_add_error(errors, source_path, "%s.id" % field, "duplicate connection id '%s'" % connection_id)
			else:
				connection_ids[connection_id] = true
		if from_id != &"" and not node_ids.has(from_id):
			_add_error(errors, source_path, "%s.from" % field, "references missing node '%s'" % from_id)
		if to_id != &"" and not node_ids.has(to_id):
			_add_error(errors, source_path, "%s.to" % field, "references missing node '%s'" % to_id)
		if from_id != &"" and from_id == to_id:
			_add_error(errors, source_path, field, "self-edge '%s' is not allowed" % from_id)
		if direction != &"" and not DIRECTIONS.has(direction):
			_add_error(errors, source_path, "%s.direction" % field, "must be bidirectional or forward")
		if from_id != &"" and to_id != &"" and from_id != to_id:
			var first_endpoint := from_id if String(from_id) < String(to_id) else to_id
			var second_endpoint := to_id if first_endpoint == from_id else from_id
			var paired_endpoints: Dictionary = endpoint_pairs.get(first_endpoint, {})
			if paired_endpoints.has(second_endpoint):
				_add_error(errors, source_path, field, "duplicate endpoint pair '%s' and '%s'" % [from_id, to_id])
			else:
				paired_endpoints[second_endpoint] = true
				endpoint_pairs[first_endpoint] = paired_endpoints
		connections.append(PassiveTreeConnection.new(connection_id, from_id, to_id, direction, connection_cost, conditions, connection_metadata))

	if errors.is_empty():
		result.tree = PassiveTreeDefinition.new(tree_id, tree_name, starting_node_ids, nodes, connections, metadata)
	return result

func _effects(value: Variant, field: String, source_path: String, errors: Array[String]) -> Array[PassiveTreeEffect]:
	var effects: Array[PassiveTreeEffect] = []
	var values := _array(value, field, source_path, errors)
	for index: int in values.size():
		var item_field := "%s[%d]" % [field, index]
		if not values[index] is Dictionary:
			_add_error(errors, source_path, item_field, "must be a JSON object")
			continue
		var document := values[index] as Dictionary
		var effect_id := _string_name(document.get("effectId"), "%s.effectId" % item_field, source_path, errors)
		var operation := _string_name(document.get("operation"), "%s.operation" % item_field, source_path, errors)
		if operation != &"" and not OPERATIONS.has(operation):
			_add_error(errors, source_path, "%s.operation" % item_field, "unsupported operation '%s'" % operation)
		var parameters := _dictionary(document.get("parameters"), "%s.parameters" % item_field, source_path, errors)
		effects.append(PassiveTreeEffect.new(effect_id, operation, document.get("value"), parameters))
	return effects

func _requirements(value: Variant, field: String, source_path: String, errors: Array[String]) -> Array[PassiveTreeRequirement]:
	var requirements: Array[PassiveTreeRequirement] = []
	var values := _array(value, field, source_path, errors)
	for index: int in values.size():
		var item_field := "%s[%d]" % [field, index]
		if not values[index] is Dictionary:
			_add_error(errors, source_path, item_field, "must be a JSON object")
			continue
		var document := values[index] as Dictionary
		var requirement_id := _string_name(document.get("requirementId"), "%s.requirementId" % item_field, source_path, errors)
		var operator := _string_name(document.get("operator"), "%s.operator" % item_field, source_path, errors)
		var parameters := _dictionary(document.get("parameters"), "%s.parameters" % item_field, source_path, errors)
		requirements.append(PassiveTreeRequirement.new(requirement_id, operator, document.get("value"), parameters))
	return requirements

func _string_name_array(value: Variant, field: String, source_path: String, errors: Array[String]) -> Array[StringName]:
	var result: Array[StringName] = []
	var values := _array(value, field, source_path, errors)
	for index: int in values.size():
		var item := _string_name(values[index], "%s[%d]" % [field, index], source_path, errors)
		if item != &"":
			result.append(item)
	return result

func _position(value: Variant, field: String, source_path: String, errors: Array[String]) -> Vector2:
	var document := _dictionary(value, field, source_path, errors)
	if document.is_empty() and not value is Dictionary:
		return Vector2.ZERO
	var x := _finite_number(document.get("x"), "%s.x" % field, source_path, errors)
	var y := _finite_number(document.get("y"), "%s.y" % field, source_path, errors)
	var position := Vector2(x, y)
	if not position.is_finite():
		_add_error(errors, source_path, field, "components must remain a finite Vector2 after conversion")
		return Vector2.ZERO
	return position

func _array(value: Variant, field: String, source_path: String, errors: Array[String]) -> Array:
	if not value is Array:
		_add_error(errors, source_path, field, "must be a JSON array")
		return []
	return (value as Array).duplicate(true)

func _dictionary(value: Variant, field: String, source_path: String, errors: Array[String]) -> Dictionary:
	if not value is Dictionary:
		_add_error(errors, source_path, field, "must be a JSON object")
		return {}
	return (value as Dictionary).duplicate(true)

func _required_string(value: Variant, field: String, source_path: String, errors: Array[String]) -> String:
	if not value is String or (value as String).strip_edges().is_empty():
		_add_error(errors, source_path, field, "must be a non-empty string")
		return ""
	return value as String

func _required_string_value(value: Variant, field: String, source_path: String, errors: Array[String]) -> String:
	if not value is String:
		_add_error(errors, source_path, field, "must be a string")
		return ""
	return value as String

func _string_name(value: Variant, field: String, source_path: String, errors: Array[String]) -> StringName:
	return StringName(_required_string(value, field, source_path, errors))

func _non_negative_integer(value: Variant, field: String, source_path: String, errors: Array[String]) -> int:
	if not _is_json_integer(value):
		_add_error(errors, source_path, field, "must be a representable signed 64-bit non-negative integer")
		return 0
	var integer := int(value)
	if integer < 0:
		_add_error(errors, source_path, field, "must be a non-negative integer")
		return 0
	return integer

func _finite_number(value: Variant, field: String, source_path: String, errors: Array[String]) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		_add_error(errors, source_path, field, "must be a finite number")
		return 0.0
	var number := float(value)
	if is_nan(number) or is_inf(number):
		_add_error(errors, source_path, field, "must be a finite number")
		return 0.0
	return number

func _validate_exact_string(value: Variant, expected: String, field: String, source_path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_STRING or value != expected:
		_add_error(errors, source_path, field, "must equal '%s'" % expected)

func _validate_exact_integer(value: Variant, expected: int, field: String, source_path: String, errors: Array[String]) -> void:
	if not _is_json_integer(value):
		_add_error(errors, source_path, field, "must be a representable signed 64-bit integer equal to %d" % expected)
	elif int(value) != expected:
		_add_error(errors, source_path, field, "must equal integer %d" % expected)

func _is_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := value as float
	return not is_nan(number) \
		and not is_inf(number) \
		and number == floorf(number) \
		and number >= SIGNED_64_MIN_AS_FLOAT \
		and number < SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT

func _add_error(errors: Array[String], source_path: String, field: String, message: String) -> void:
	errors.append("%s%s field=%s message=%s" % [ERROR_PREFIX, source_path, field, message])
