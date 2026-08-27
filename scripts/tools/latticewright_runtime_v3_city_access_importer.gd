class_name LatticewrightRuntimeV3CityAccessImporter
extends RefCounted

const ADAPTER := "latticewright-runtime-v3-city-access"
const EXPECTED_LOCATIONS := {
	"city.apothecary": {"destination": "city.apothecary.interior", "visibility": "visible", "requirement": "", "value": ""},
	"city.coliseum_road": {"destination": "city.coliseum_road.route", "visibility": "visible", "requirement": "", "value": ""},
	"city.scholars_archive": {"destination": "city.scholars_archive.interior", "visibility": "hidden_until_available", "requirement": "party-forge-prologue-state", "value": "completed"},
	"city.inn": {"destination": "city.inn.interior", "visibility": "visible", "requirement": "party-forge-permanent-unlock", "value": "service:hero_registry"},
	"city.merchant": {"destination": "city.merchant.interior", "visibility": "visible", "requirement": "party-forge-permanent-unlock", "value": "service:city_vendors"},
	"city.warehouse": {"destination": "city.warehouse.interior", "visibility": "visible", "requirement": "party-forge-permanent-unlock", "value": "stash"},
	"city.smithy": {"destination": "city.smithy.interior", "visibility": "visible", "requirement": "party-forge-permanent-unlock", "value": "service:equipment_upgrading"},
}
const ROOT_KEYS := ["format", "formatVersion", "projectId", "name", "archetype", "vocabulary", "schemas", "content", "graphs", "graphPortals", "assets", "extensions"]
const SCHEMA_KEYS := ["fields", "contentTypes", "placementTypes", "effects", "requirements", "currencies", "ranks", "categories", "tags"]
const CONTENT_KEYS := ["id", "typeId", "name", "description", "fieldValues", "effects", "requirements", "categoryIds", "tagIds", "iconAssetId", "extensions"]
const GRAPH_KEYS := ["id", "name", "startingPlacementIds", "placements", "connections", "groups", "decorations", "extensions"]
const PLACEMENT_KEYS := ["id", "contentId", "typeId", "position", "fieldValues", "extensions"]
const CONNECTION_KEYS := ["id", "from", "to", "direction", "cost", "conditions", "extensions"]

static func translate(document: Dictionary, source_sha256: String) -> CityAccessImportResult:
	if not _sha(source_sha256): return _failure("source hash is invalid")
	var root_error := _root(document)
	if not root_error.is_empty(): return _failure(root_error)
	var schemas := document["schemas"] as Dictionary
	var schema_error := _schemas(schemas)
	if not schema_error.is_empty(): return _failure(schema_error)
	var content_error := _content(document["content"] as Array)
	if not content_error.is_empty(): return _failure(content_error)
	var graph_error := _graph(document["graphs"] as Array, document["content"] as Array)
	if not graph_error.is_empty(): return _failure(graph_error)
	return CityAccessImportResult.success(_candidate(document["content"] as Array, source_sha256))

static func _root(document: Dictionary) -> String:
	if not _keys(document, ROOT_KEYS): return "root keys are invalid"
	if document["format"] != "latticewright-progression" or not _integer(document["formatVersion"]) or int(document["formatVersion"]) != 3: return "runtime format is invalid"
	if document["projectId"] != "party-forge-city-access" or document["archetype"] != "custom": return "runtime identity is invalid"
	if not _text(document["name"]) or not document["vocabulary"] is Dictionary or not document["schemas"] is Dictionary: return "runtime display records are invalid"
	var vocabulary := document["vocabulary"] as Dictionary
	if not _keys(vocabulary, ["graphSingular", "graphPlural", "contentSingular", "contentPlural", "placementSingular", "placementPlural"]): return "vocabulary keys are invalid"
	for value: Variant in vocabulary.values():
		if not _text(value): return "vocabulary values are invalid"
	for array_key: String in ["content", "graphs", "graphPortals", "assets"]:
		if not document[array_key] is Array: return "runtime arrays are invalid"
	if document["extensions"] != {"gameplayConsumer": "not-yet-wired", "partyForgeStatus": "authoring-design-data"}: return "runtime extensions are invalid"
	if not (document["graphPortals"] as Array).is_empty() or not (document["assets"] as Array).is_empty(): return "runtime portals or assets are unsupported"
	return ""

static func _schemas(schemas: Dictionary) -> String:
	if not _keys(schemas, SCHEMA_KEYS): return "schema keys are invalid"
	for key: String in SCHEMA_KEYS:
		if not schemas[key] is Array: return "schema arrays are invalid"
	for empty_key: String in ["effects", "currencies", "ranks", "categories", "tags"]:
		if not (schemas[empty_key] as Array).is_empty(): return "unsupported schema records are present"
	if not _definitions(schemas["fields"] as Array, ["party-forge-location-id", "party-forge-destination-id", "party-forge-visibility-policy"], "field"): return "field definitions are invalid"
	if not _definitions(schemas["contentTypes"] as Array, ["party-forge-access-location"], "content"): return "content type definitions are invalid"
	if not _definitions(schemas["placementTypes"] as Array, ["party-forge-access-location-placement"], "placement"): return "placement type definitions are invalid"
	if not _definitions(schemas["requirements"] as Array, ["party-forge-prologue-state", "party-forge-permanent-unlock"], "requirement"): return "requirement definitions are invalid"
	return ""

static func _definitions(values: Array, expected: Array[String], kind: String) -> bool:
	if values.size() != expected.size(): return false
	var seen := {}
	for value: Variant in values:
		if not value is Dictionary: return false
		var definition := value as Dictionary
		if not _text(definition.get("id")) or seen.has(definition["id"]) or definition["id"] not in expected: return false
		seen[definition["id"]] = true
		match kind:
			"field":
				if not _field_definition(definition): return false
			"content":
				if not _keys(definition, ["id", "name", "description", "fieldIds"]) or not _text(definition["name"]) or not _text(definition["description"]): return false
				if definition["id"] != "party-forge-access-location" or not _string_set(definition["fieldIds"], ["party-forge-location-id", "party-forge-destination-id", "party-forge-visibility-policy"]): return false
			"placement":
				if not _keys(definition, ["id", "name", "description", "fieldIds", "shape"]) or not _text(definition["name"]) or not _text(definition["description"]): return false
				if definition["shape"] != "custom" or not _string_set(definition["fieldIds"], []): return false
			"requirement":
				if not _requirement_definition(definition): return false
	return seen.size() == expected.size()

static func _field_definition(value: Dictionary) -> bool:
	var id := String(value.get("id", ""))
	var expected_keys := ["id", "name", "valueType", "required", "owner"]
	if id == "party-forge-visibility-policy": expected_keys.append("allowedValues")
	if not _keys(value, expected_keys) or not _text(value["name"]) or value["required"] != true or value["owner"] != "content": return false
	if id == "party-forge-location-id" or id == "party-forge-destination-id": return value["valueType"] == "text"
	return value["valueType"] == "enum" and _string_set(value["allowedValues"], ["hidden_until_available", "visible"])

static func _requirement_definition(value: Dictionary) -> bool:
	if not _keys(value, ["id", "name", "description", "parameterDefinitions"]) or not _text(value["name"]) or not _text(value["description"]) or not value["parameterDefinitions"] is Array: return false
	var parameters := value["parameterDefinitions"] as Array
	if parameters.size() != 1 or not parameters[0] is Dictionary: return false
	var parameter := parameters[0] as Dictionary
	var expected_keys := ["id", "name", "valueType", "required"]
	if value["id"] == "party-forge-prologue-state": expected_keys.append("allowedValues")
	if not _keys(parameter, expected_keys) or parameter["id"] != "value" or not _text(parameter["name"]) or parameter["required"] != true: return false
	if value["id"] == "party-forge-prologue-state": return parameter["valueType"] == "enum" and _string_set(parameter["allowedValues"], ["completed", "in_progress", "not_started"])
	return parameter["valueType"] == "text"

static func _content(values: Array) -> String:
	if values.size() != EXPECTED_LOCATIONS.size(): return "content record count is invalid"
	var source_ids := {}; var locations := {}; var destinations := {}
	for value: Variant in values:
		if not value is Dictionary: return "content record is invalid"
		var record := value as Dictionary
		if not _keys(record, CONTENT_KEYS) or not _source_id(record.get("id")) or source_ids.has(record["id"]): return "content source IDs are invalid"
		source_ids[record["id"]] = true
		if record["typeId"] != "party-forge-access-location" or not _text(record["name"]) or not _text(record["description"]) or not record["fieldValues"] is Dictionary: return "content record fields are invalid"
		if not (record["effects"] is Array and (record["effects"] as Array).is_empty()) or not _string_set(record["categoryIds"], []) or not _string_set(record["tagIds"], []) or record["iconAssetId"] != null or not _empty_extensions(record["extensions"]): return "content record semantic extras are invalid"
		var fields := record["fieldValues"] as Dictionary
		if not _keys(fields, ["party-forge-location-id", "party-forge-destination-id", "party-forge-visibility-policy"]): return "content field keys are invalid"
		var location: Variant = fields["party-forge-location-id"]
		var destination: Variant = fields["party-forge-destination-id"]
		var policy: Variant = fields["party-forge-visibility-policy"]
		if not _text(location) or not _text(destination) or not _text(policy) or locations.has(location) or destinations.has(destination) or not EXPECTED_LOCATIONS.has(location): return "content semantics are invalid"
		var expected: Dictionary = EXPECTED_LOCATIONS[location]
		if destination != expected["destination"] or policy != expected["visibility"] or record["id"] != "location-%s" % String(location).replace(".", "-").replace("_", "-"): return "content semantics are invalid"
		if not _requirements(record["requirements"], expected): return "content requirements are invalid"
		locations[location] = true; destinations[destination] = true
	return "" if locations.size() == EXPECTED_LOCATIONS.size() else "content records are incomplete"

static func _requirements(values: Variant, expected: Dictionary) -> bool:
	if not values is Array: return false
	var requirements := values as Array
	if String(expected["requirement"]).is_empty(): return requirements.is_empty()
	if requirements.size() != 1 or not requirements[0] is Dictionary: return false
	var requirement := requirements[0] as Dictionary
	return _keys(requirement, ["definitionId", "values"]) and requirement["definitionId"] == expected["requirement"] and requirement["values"] is Dictionary and _keys(requirement["values"] as Dictionary, ["value"]) and requirement["values"]["value"] == expected["value"]

static func _graph(values: Array, content: Array) -> String:
	if values.size() != 1 or not values[0] is Dictionary: return "graph count is invalid"
	var graph := values[0] as Dictionary
	if not _keys(graph, GRAPH_KEYS) or graph["id"] != "city-access" or not _text(graph["name"]) or not graph["startingPlacementIds"] is Array or not graph["placements"] is Array or not graph["connections"] is Array or not graph["groups"] is Array or not graph["decorations"] is Array or not _empty_extensions(graph["extensions"]): return "graph record is invalid"
	var content_ids := {}; for record: Dictionary in content: content_ids[record["id"]] = true
	var placement_ids := {}; var content_references := {}
	for value: Variant in graph["placements"] as Array:
		if not value is Dictionary: return "placement record is invalid"
		var placement := value as Dictionary
		if not _keys(placement, PLACEMENT_KEYS) or not _source_id(placement.get("id")) or placement_ids.has(placement["id"]) or not content_ids.has(placement.get("contentId")) or placement["typeId"] != "party-forge-access-location-placement" or not _point(placement.get("position")) or not _empty_dictionary(placement.get("fieldValues")) or not _empty_extensions(placement.get("extensions")): return "placement record is invalid"
		placement_ids[placement["id"]] = true
		content_references[placement["contentId"]] = int(content_references.get(placement["contentId"], 0)) + 1
	if placement_ids.size() != content_ids.size(): return "placement count is invalid"
	for content_id: Variant in content_ids:
		if int(content_references.get(content_id, 0)) != 1: return "content placement references are invalid"
	for starting: Variant in graph["startingPlacementIds"] as Array:
		if not _source_id(starting) or not placement_ids.has(starting): return "starting placement is invalid"
	for connection: Variant in graph["connections"] as Array:
		if not _connection(connection, placement_ids): return "connection record is invalid"
	if not _layout_records(graph["groups"] as Array, graph["decorations"] as Array, placement_ids): return "layout records are invalid"
	return ""

static func _connection(value: Variant, placement_ids: Dictionary) -> bool:
	if not value is Dictionary: return false
	var record := value as Dictionary
	return _keys(record, CONNECTION_KEYS) and _source_id(record.get("id")) and placement_ids.has(record.get("from")) and placement_ids.has(record.get("to")) and record["direction"] in ["bidirectional", "forward"] and _finite(record.get("cost")) and record["conditions"] is Array and (record["conditions"] as Array).is_empty() and _empty_extensions(record.get("extensions"))

static func _layout_records(groups: Array, decorations: Array, placement_ids: Dictionary) -> bool:
	var group_ids := {}
	for group: Variant in groups:
		if not group is Dictionary: return false
		var record := group as Dictionary
		if not _keys(record, ["id", "name", "placementIds", "color", "extensions"]) or not _source_id(record.get("id")) or group_ids.has(record["id"]) or not _text(record.get("name")) or not record["placementIds"] is Array or not _color(record.get("color")) or not _empty_extensions(record.get("extensions")): return false
		var members := {}
		for member: Variant in record["placementIds"] as Array:
			if not _source_id(member) or not placement_ids.has(member) or members.has(member): return false
			members[member] = true
		group_ids[record["id"]] = true
	var decoration_ids := {}
	for decoration: Variant in decorations:
		if not decoration is Dictionary: return false
		var record := decoration as Dictionary
		if not _source_id(record.get("id")) or decoration_ids.has(record["id"]) or not _decoration(record, group_ids): return false
		decoration_ids[record["id"]] = true
	return true

static func _decoration(record: Dictionary, group_ids: Dictionary) -> bool:
	if not record.has("kind") or not record.has("groupId") or not record.has("opacity") or not record.has("extensions") or not _group_reference(record["groupId"], group_ids) or not _finite(record["opacity"]) or float(record["opacity"]) < 0.0 or float(record["opacity"]) > 1.0 or not _empty_extensions(record["extensions"]): return false
	match record["kind"]:
		"ring":
			return _keys(record, ["id", "kind", "groupId", "center", "radius", "strokeColor", "strokeWidth", "fillColor", "opacity", "extensions"]) and _point(record["center"]) and _nonnegative(record["radius"]) and _color(record["strokeColor"]) and _nonnegative(record["strokeWidth"]) and (record["fillColor"] == null or _color(record["fillColor"]))
		"label":
			return _keys(record, ["id", "kind", "groupId", "position", "text", "color", "fontSize", "opacity", "extensions"]) and _point(record["position"]) and typeof(record["text"]) == TYPE_STRING and _color(record["color"]) and _nonnegative(record["fontSize"])
		"region":
			return _keys(record, ["id", "kind", "groupId", "center", "width", "height", "cornerRadius", "fillColor", "strokeColor", "strokeWidth", "opacity", "extensions"]) and _point(record["center"]) and _nonnegative(record["width"]) and _nonnegative(record["height"]) and _nonnegative(record["cornerRadius"]) and _color(record["fillColor"]) and _color(record["strokeColor"]) and _nonnegative(record["strokeWidth"])
	return false

static func _group_reference(value: Variant, group_ids: Dictionary) -> bool:
	return value == null or (_source_id(value) and group_ids.has(value))

static func _nonnegative(value: Variant) -> bool:
	return _finite(value) and float(value) >= 0.0

static func _color(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 7 or not (value as String).begins_with("#"): return false
	for character: String in (value as String).substr(1):
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f") and not (character >= "A" and character <= "F"): return false
	return true

static func _candidate(content: Array, source_sha256: String) -> Dictionary:
	var locations: Array = []
	for record: Dictionary in content:
		var fields := record["fieldValues"] as Dictionary
		var expected: Dictionary = EXPECTED_LOCATIONS[fields["party-forge-location-id"]]
		var available := _translated_conditions(String(expected["requirement"]), String(expected["value"]))
		locations.append({"id": fields["party-forge-location-id"], "destinationId": fields["party-forge-destination-id"], "visibleWhen": available if fields["party-forge-visibility-policy"] == "hidden_until_available" else [{"kind": "always", "value": ""}], "availableWhen": available})
	locations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	return {"format": "party-forge-access-snapshot", "version": 1, "source": {"adapter": ADAPTER, "format": "latticewright-progression", "formatVersion": 3, "sha256": source_sha256}, "locations": locations}

static func _translated_conditions(definition_id: String, value: String) -> Array:
	if definition_id.is_empty(): return [{"kind": "always", "value": ""}]
	return [{"kind": "prologue_state" if definition_id == "party-forge-prologue-state" else "permanent_unlock", "value": value}]

static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	return true

static func _string_set(value: Variant, expected: Array[String]) -> bool:
	if not value is Array or (value as Array).size() != expected.size(): return false
	var seen := {}
	for item: Variant in value as Array:
		if not _text(item) or seen.has(item) or item not in expected: return false
		seen[item] = true
	return true

static func _empty_extensions(value: Variant) -> bool:
	return value is Dictionary and (value as Dictionary).is_empty()

static func _empty_dictionary(value: Variant) -> bool:
	return value is Dictionary and (value as Dictionary).is_empty()

static func _point(value: Variant) -> bool:
	return value is Dictionary and _keys(value as Dictionary, ["x", "y"]) and _finite((value as Dictionary)["x"]) and _finite((value as Dictionary)["y"])

static func _finite(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _finite(value) and floorf(float(value)) == float(value)

static func _text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty()

static func _source_id(value: Variant) -> bool:
	if not _text(value): return false
	var text := value as String
	if text.begins_with("-") or text.ends_with("-") or text.contains("--"): return false
	for character: String in text:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "-": return false
	return true

static func _sha(value: String) -> bool:
	if value.length() != 64: return false
	for character: String in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"): return false
	return true

static func _failure(reason: String) -> CityAccessImportResult:
	return CityAccessImportResult.failure("translate", reason)
