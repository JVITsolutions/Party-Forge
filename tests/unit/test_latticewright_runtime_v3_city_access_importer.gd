extends RefCounted

const Importer = preload("res://scripts/tools/latticewright_runtime_v3_city_access_importer.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_runtime_translation(failures)
	_test_rejections_and_canonicalization(failures)
	_test_whitespace_only_provenance(failures)
	return failures

func _test_exact_runtime_translation(failures: Array[String]) -> void:
	var source_sha := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	var result: Variant = Importer.translate(_runtime(), source_sha)
	TestAssertions.truthy(result.ok(), "exact runtime-v3 City Access document translates", failures)
	if not result.ok(): return
	var candidate: Dictionary = result.candidate
	TestAssertions.equal(candidate["format"], "party-forge-access-snapshot", "output owns Party Forge format", failures)
	TestAssertions.equal(candidate["version"], 1, "output owns Party Forge version", failures)
	TestAssertions.equal(candidate["source"]["adapter"], "latticewright-runtime-v3-city-access", "adapter is traceable", failures)
	TestAssertions.equal(candidate["source"]["sha256"], source_sha, "exact source bytes are traceable", failures)
	TestAssertions.equal(candidate["locations"].size(), 7, "all seven City locations translate", failures)
	var archive := _location(candidate["locations"], "city.scholars_archive")
	TestAssertions.equal(archive["visibleWhen"], [{"kind": "prologue_state", "value": "completed"}], "hidden availability also controls visibility", failures)
	var inn := _location(candidate["locations"], "city.inn")
	TestAssertions.equal(inn["visibleWhen"], [{"kind": "always", "value": ""}], "visible policy uses always visibility", failures)
	TestAssertions.equal(inn["availableWhen"], [{"kind": "permanent_unlock", "value": "service:hero_registry"}], "permanent unlock translates", failures)

func _test_rejections_and_canonicalization(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"label": "wrong format", "path": ["format"], "value": "other"},
		{"label": "wrong version", "path": ["formatVersion"], "value": 2},
		{"label": "wrong project", "path": ["projectId"], "value": "other-project"},
		{"label": "wrong graph", "path": ["graphs", 0, "id"], "value": "other-graph"},
		{"label": "missing semantic field", "path": ["content", 0, "fieldValues", "party-forge-location-id"], "erase": true},
		{"label": "invalid visibility", "path": ["content", 0, "fieldValues", "party-forge-visibility-policy"], "value": "hidden"},
		{"label": "unknown requirement", "path": ["content", 0, "requirements"], "value": [{"definitionId": "other", "values": {"value": "x"}}]},
		{"label": "unknown requirement value", "path": ["content", 2, "requirements", 0, "values", "value"], "value": "started"},
		{"label": "effects", "path": ["content", 0, "effects"], "value": [{"definitionId": "effect", "values": {}}]},
		{"label": "connection conditions", "path": ["graphs", 0, "connections"], "value": [_connection()]},
		{"label": "portals", "path": ["graphPortals"], "value": [_portal()]},
		{"label": "assets", "path": ["assets"], "value": [_asset()]},
		{"label": "missing root extension", "path": ["extensions", "gameplayConsumer"], "erase": true},
		{"label": "mismatched root extension", "path": ["extensions", "gameplayConsumer"], "value": "wired"},
		{"label": "extra root extension", "path": ["extensions", "other"], "value": true},
		{"label": "nested extensions", "path": ["content", 0, "extensions"], "value": {"other": true}},
		{"label": "nonempty extensions", "path": ["extensions"], "value": {"unexpected": true}},
	]:
		var document := _runtime()
		if test_case.has("erase"):
			_erase(document, test_case["path"] as Array)
		else:
			_set_path(document, test_case["path"] as Array, test_case["value"])
		TestAssertions.truthy(not Importer.translate(document, _sha()).ok(), "%s rejects" % test_case["label"], failures)
	var duplicate_content := _runtime()
	duplicate_content["content"].append((duplicate_content["content"][0] as Dictionary).duplicate(true))
	TestAssertions.truthy(not Importer.translate(duplicate_content, _sha()).ok(), "duplicate source content rejects", failures)
	var dangling := _runtime()
	dangling["graphs"][0]["placements"][0]["contentId"] = "missing"
	TestAssertions.truthy(not Importer.translate(dangling, _sha()).ok(), "dangling placement rejects", failures)
	var duplicate_placement := _runtime()
	duplicate_placement["graphs"][0]["placements"].append((duplicate_placement["graphs"][0]["placements"][0] as Dictionary).duplicate(true))
	TestAssertions.truthy(not Importer.translate(duplicate_placement, _sha()).ok(), "duplicate placement rejects", failures)
	var duplicate_destination := _runtime()
	duplicate_destination["content"][1]["fieldValues"]["party-forge-destination-id"] = "city.apothecary.interior"
	TestAssertions.truthy(not Importer.translate(duplicate_destination, _sha()).ok(), "duplicate destination rejects", failures)
	var valid_layout := _runtime()
	valid_layout["graphs"][0]["groups"] = [_group()]
	valid_layout["graphs"][0]["decorations"] = [_decoration()]
	TestAssertions.truthy(Importer.translate(valid_layout, _sha()).ok(), "structurally valid ignored layout records translate", failures)
	var malformed_layout := _runtime()
	malformed_layout["graphs"][0]["decorations"] = [{"id": "broken", "extensions": {}}]
	TestAssertions.truthy(not Importer.translate(malformed_layout, _sha()).ok(), "incomplete decoration rejects", failures)
	var dangling_group := _runtime()
	dangling_group["graphs"][0]["groups"] = [_group("missing-placement")]
	TestAssertions.truthy(not Importer.translate(dangling_group, _sha()).ok(), "dangling group placement rejects", failures)
	var reordered := _runtime()
	reordered["content"].reverse()
	reordered["graphs"][0]["placements"].reverse()
	reordered["schemas"]["fields"].reverse()
	reordered["schemas"]["requirements"].reverse()
	var first: Variant = Importer.translate(_runtime(), _sha())
	var second: Variant = Importer.translate(reordered, _sha())
	TestAssertions.truthy(first.ok() and second.ok(), "reordered runtime fixtures translate", failures)
	if first.ok() and second.ok():
		TestAssertions.equal(CityAccessSnapshotCodec.encode_document(first.candidate), CityAccessSnapshotCodec.encode_document(second.candidate), "runtime reorderings produce byte-identical candidates", failures)
		TestAssertions.truthy(first.candidate["source"]["sha256"] != Importer.translate(_runtime(), "f".repeat(64)).candidate["source"]["sha256"], "source byte hash remains independent provenance", failures)

func _test_whitespace_only_provenance(failures: Array[String]) -> void:
	var root := "user://tests/city-access-provenance-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var compact_path := root.path_join("compact.json")
	var spaced_path := root.path_join("spaced.json")
	_write_bytes(compact_path, JSON.stringify(_runtime()).to_utf8_buffer())
	_write_bytes(spaced_path, (JSON.stringify(_runtime(), "  ", false) + "\n").to_utf8_buffer())
	var compact := StrictJsonDocumentReader.read(compact_path, 64 * 1024 * 1024)
	var spaced := StrictJsonDocumentReader.read(spaced_path, 64 * 1024 * 1024)
	var compact_candidate: Variant = Importer.translate(compact.document, compact.sha256)
	var spaced_candidate: Variant = Importer.translate(spaced.document, spaced.sha256)
	TestAssertions.truthy(compact.ok() and spaced.ok() and compact_candidate.ok() and spaced_candidate.ok(), "whitespace provenance fixtures read and translate", failures)
	if compact.ok() and spaced.ok() and compact_candidate.ok() and spaced_candidate.ok():
		TestAssertions.truthy(compact.sha256 != spaced.sha256, "source whitespace changes exact reader SHA-256", failures)
		var normalized_compact: Dictionary = compact_candidate.candidate.duplicate(true)
		var normalized_spaced: Dictionary = spaced_candidate.candidate.duplicate(true)
		normalized_spaced["source"]["sha256"] = normalized_compact["source"]["sha256"]
		TestAssertions.equal(normalized_spaced, normalized_compact, "source whitespace changes only candidate provenance SHA-256", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(compact_path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(spaced_path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(root))

func _runtime() -> Dictionary:
	var locations := [
		["city.apothecary", "city.apothecary.interior", "visible", "", ""],
		["city.coliseum_road", "city.coliseum_road.route", "visible", "", ""],
		["city.scholars_archive", "city.scholars_archive.interior", "hidden_until_available", "party-forge-prologue-state", "completed"],
		["city.inn", "city.inn.interior", "visible", "party-forge-permanent-unlock", "service:hero_registry"],
		["city.merchant", "city.merchant.interior", "visible", "party-forge-permanent-unlock", "service:city_vendors"],
		["city.warehouse", "city.warehouse.interior", "visible", "party-forge-permanent-unlock", "stash"],
		["city.smithy", "city.smithy.interior", "visible", "party-forge-permanent-unlock", "service:equipment_upgrading"],
	]
	var content: Array = []; var placements: Array = []
	for row: Array in locations:
		var ordinal := String(row[0]).replace(".", "-").replace("_", "-")
		content.append({"id": "location-%s" % ordinal, "typeId": "party-forge-access-location", "name": row[0], "description": "fixture", "fieldValues": {"party-forge-location-id": row[0], "party-forge-destination-id": row[1], "party-forge-visibility-policy": row[2]}, "effects": [], "requirements": [] if String(row[3]).is_empty() else [{"definitionId": row[3], "values": {"value": row[4]}}], "categoryIds": [], "tagIds": [], "iconAssetId": null, "extensions": {}})
		placements.append({"id": "placement-%s" % ordinal, "contentId": "location-%s" % ordinal, "typeId": "party-forge-access-location-placement", "position": {"x": 0, "y": 0}, "fieldValues": {}, "extensions": {}})
	return {"format": "latticewright-progression", "formatVersion": 3, "projectId": "party-forge-city-access", "name": "City Access", "archetype": "custom", "vocabulary": {"graphSingular": "Access", "graphPlural": "Access", "contentSingular": "Location", "contentPlural": "Locations", "placementSingular": "Location", "placementPlural": "Locations"}, "schemas": {"fields": [_field("party-forge-location-id", "text"), _field("party-forge-destination-id", "text"), _field("party-forge-visibility-policy", "enum", ["hidden_until_available", "visible"])], "contentTypes": [{"id": "party-forge-access-location", "name": "Location", "description": "fixture", "fieldIds": ["party-forge-location-id", "party-forge-destination-id", "party-forge-visibility-policy"]}], "placementTypes": [{"id": "party-forge-access-location-placement", "name": "Placement", "description": "fixture", "fieldIds": [], "shape": "custom"}], "effects": [], "requirements": [_requirement("party-forge-prologue-state", "enum", ["completed", "in_progress", "not_started"]), _requirement("party-forge-permanent-unlock", "text")], "currencies": [], "ranks": [], "categories": [], "tags": []}, "content": content, "graphs": [{"id": "city-access", "name": "City Access", "startingPlacementIds": ["placement-city-apothecary"], "placements": placements, "connections": [], "groups": [], "decorations": [], "extensions": {}}], "graphPortals": [], "assets": [], "extensions": {"gameplayConsumer": "not-yet-wired", "partyForgeStatus": "authoring-design-data"}}

func _field(id: String, value_type: String, allowed: Array = []) -> Dictionary:
	var result := {"id": id, "name": id, "valueType": value_type, "required": true, "owner": "content"}
	if not allowed.is_empty(): result["allowedValues"] = allowed
	return result

func _requirement(id: String, value_type: String, allowed: Array = []) -> Dictionary:
	var parameter := {"id": "value", "name": "Value", "valueType": value_type, "required": true}
	if not allowed.is_empty(): parameter["allowedValues"] = allowed
	return {"id": id, "name": id, "description": "fixture", "parameterDefinitions": [parameter]}

func _connection() -> Dictionary:
	return {"id": "layout-link", "from": "placement-city-apothecary", "to": "placement-city-inn", "direction": "bidirectional", "cost": 0, "conditions": [{"definitionId": "party-forge-prologue-state", "values": {"value": "completed"}}], "extensions": {}}

func _portal() -> Dictionary:
	return {"id": "portal", "sourceGraphId": "city-access", "sourcePlacementId": "placement-city-apothecary", "label": "x", "role": "travel", "targetProjectId": "other", "targetGraphId": "other", "extensions": {}}

func _asset() -> Dictionary:
	return {"id": "asset", "relativePath": "asset.png", "mediaType": "image", "sha256": _sha(), "extensions": {}}

func _group(member: String = "placement-city-apothecary") -> Dictionary:
	return {"id": "city-layout", "name": "Layout", "placementIds": [member], "color": "#aabbcc", "extensions": {}}

func _decoration() -> Dictionary:
	return {"id": "city-label", "kind": "label", "groupId": "city-layout", "position": {"x": 0, "y": 0}, "text": "City", "color": "#aabbcc", "fontSize": 16, "opacity": 1, "extensions": {}}

func _location(locations: Array, id: String) -> Dictionary:
	for location: Dictionary in locations:
		if location["id"] == id: return location
	return {}

func _set_path(document: Dictionary, path: Array, value: Variant) -> void:
	var current: Variant = document
	for index: int in range(path.size() - 1): current = current[path[index]]
	current[path[-1]] = value

func _erase(document: Dictionary, path: Array) -> void:
	var current: Variant = document
	for index: int in range(path.size() - 1): current = current[path[index]]
	(current as Dictionary).erase(path[-1])

func _sha() -> String:
	return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()
