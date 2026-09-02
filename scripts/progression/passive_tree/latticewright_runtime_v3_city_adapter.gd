class_name LatticewrightRuntimeV3CityAdapter
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_CITY_RUNTIME_V3_ERROR"
const FORMAT_VERSION := 3
const PROJECT_ID := "party-forge-city"
const GRAPH_ID := "city-passive-tree"
const DOMAIN_TREE_ID := "party-forge-city-v1"

const IMPLEMENTED_IDS: Array[StringName] = [
	&"city-heart", &"equipment-registry", &"field-pack", &"stash-access",
	&"extraction-license", &"secured-loadout", &"leader-loadout-extraction",
]
const PORTAL_GATED_IDS: Array[StringName] = [
	&"hero-district-charter", &"trials-district-charter", &"market-district-charter",
	&"expedition-district-charter", &"forge-district-charter", &"logistics-district-charter",
]
const FUTURE_IDS: Array[StringName] = [
	&"shared-lessons-1", &"shared-lessons-2", &"expanded-barracks", &"hero-registry",
	&"training-yard", &"trial-monument", &"arena-charter", &"endless-gate",
	&"open-market", &"merchant-permits", &"contract-ledger", &"grand-exchange",
	&"surveyors-office", &"expedition-board", &"north-road-charter", &"waystone-network",
	&"pathfinders-charter", &"smiths-guild", &"reclamation-bench", &"artificers-hall",
	&"grand-workshop", &"civic-archive", &"blueprint-library", &"hall-of-heroes",
]

const PLACEMENT_TYPES := {
	"start-node": &"start",
	"small-node": &"small",
	"medium-node": &"medium",
	"large-node": &"large",
}

const EXPECTED_VOCABULARY := {
	"contentPlural": "Passives",
	"contentSingular": "Passive",
	"graphPlural": "Passive Trees",
	"graphSingular": "Passive Tree",
	"placementPlural": "Nodes",
	"placementSingular": "Node",
}

const EXPECTED_EXTENSIONS := {
	"gameplayConsumer": "party-forge",
	"partyForgeDomainTreeId": DOMAIN_TREE_ID,
	"partyForgeStatus": "runtime-integrated",
}

const EXPECTED_SCHEMAS := {
	"categories": [
		{"description": "large progression tier.", "id": "large", "name": "Large"},
		{"description": "medium progression tier.", "id": "medium", "name": "Medium"},
		{"description": "small progression tier.", "id": "small", "name": "Small"},
		{"description": "start progression tier.", "id": "start", "name": "Start"},
	],
	"contentTypes": [{
		"description": "A Party Forge progression design node.",
		"fieldIds": ["party-forge-activation-state"],
		"id": "passive",
		"name": "Passive",
	}],
	"currencies": [],
	"effects": [
		{
			"description": "Discovers one permanent Party Forge building.",
			"descriptionTemplate": "Discover building {building-id}.",
			"id": "party-forge-building-discovery",
			"name": "Party Forge Building Discovery",
			"parameterDefinitions": [{"id": "building-id", "name": "Building ID", "required": true, "valueType": "text"}],
		},
		{
			"description": "Adds permanent profile extraction capacity.",
			"descriptionTemplate": "Add {amount} extraction capacity to {scope}.",
			"id": "party-forge-extraction-capacity-add",
			"name": "Party Forge Extraction Capacity Add",
			"parameterDefinitions": [
				{"id": "amount", "name": "Amount", "required": true, "valueType": "number"},
				{"allowedValues": ["profile"], "id": "scope", "name": "Scope", "required": true, "valueType": "enum"},
			],
		},
		{
			"description": "Unlocks one permanent Party Forge feature.",
			"descriptionTemplate": "Unlock feature {feature-id}.",
			"id": "party-forge-feature-unlock",
			"name": "Party Forge Feature Unlock",
			"parameterDefinitions": [{"id": "feature-id", "name": "Feature ID", "required": true, "valueType": "text"}],
		},
		{
			"description": "Adds permanent profile inventory columns.",
			"descriptionTemplate": "Add {amount} inventory columns to {scope}.",
			"id": "party-forge-inventory-columns-add",
			"name": "Party Forge Inventory Columns Add",
			"parameterDefinitions": [
				{"id": "amount", "name": "Amount", "required": true, "valueType": "number"},
				{"allowedValues": ["profile"], "id": "scope", "name": "Scope", "required": true, "valueType": "enum"},
			],
		},
		{
			"description": "Adds permanent profile stash tabs.",
			"descriptionTemplate": "Add {amount} stash tabs with {slots-per-tab} slots each to {scope}.",
			"id": "party-forge-stash-tabs-add",
			"name": "Party Forge Stash Tabs Add",
			"parameterDefinitions": [
				{"id": "amount", "name": "Amount", "required": true, "valueType": "number"},
				{"allowedValues": ["profile"], "id": "scope", "name": "Scope", "required": true, "valueType": "enum"},
				{"id": "slots-per-tab", "name": "Slots Per Tab", "required": true, "valueType": "number"},
			],
		},
		{
			"description": "Discovers one permanent Party Forge passive tree.",
			"descriptionTemplate": "Discover passive tree {tree-id}.",
			"id": "party-forge-tree-discovery",
			"name": "Party Forge Tree Discovery",
			"parameterDefinitions": [{"id": "tree-id", "name": "Tree ID", "required": true, "valueType": "text"}],
		},
	],
	"fields": [
		{"id": "node-cost", "minimum": 0, "name": "Point Cost", "owner": "placement", "required": true, "valueType": "number"},
		{
			"allowedValues": ["future", "implemented", "portal-gated"],
			"id": "party-forge-activation-state",
			"name": "Party Forge Activation State",
			"owner": "content",
			"required": true,
			"valueType": "enum",
		},
	],
	"placementTypes": [
		{"description": "large progression placement.", "fieldIds": ["node-cost"], "id": "large-node", "name": "Large Node", "shape": "large"},
		{"description": "medium progression placement.", "fieldIds": ["node-cost"], "id": "medium-node", "name": "Medium Node", "shape": "medium"},
		{"description": "small progression placement.", "fieldIds": ["node-cost"], "id": "small-node", "name": "Small Node", "shape": "small"},
		{"description": "start progression placement.", "fieldIds": ["node-cost"], "id": "start-node", "name": "Start Node", "shape": "start"},
	],
	"ranks": [],
	"requirements": [{
		"description": "Requires one allocated Party Forge passive-tree node.",
		"id": "party-forge-allocated-node",
		"name": "Party Forge Allocated Node",
		"parameterDefinitions": [
			{"id": "tree-id", "name": "Tree ID", "required": true, "valueType": "text"},
			{"id": "node-id", "name": "Node ID", "required": true, "valueType": "text"},
		],
	}],
	"tags": [
		{"description": "Party Forge city design tag.", "id": "city", "name": "City"},
		{"description": "Party Forge party-forge design tag.", "id": "party-forge", "name": "Party Forge"},
		{"description": "Party Forge small design tag.", "id": "small", "name": "Small"},
		{"description": "Party Forge start design tag.", "id": "start", "name": "Start"},
	],
}

const PORTAL_CONTRACTS := {
	"city-to-expedition-district": ["expedition-district-charter", "Open Expedition District", "party-forge-expedition-district", "expedition-district-passive-tree", "party-forge-expedition-district-v1"],
	"city-to-forge-district": ["forge-district-charter", "Open Forge District", "party-forge-forge-district", "forge-district-passive-tree", "party-forge-forge-district-v1"],
	"city-to-hero-district": ["hero-district-charter", "Open Hero District", "party-forge-hero-district", "hero-district-passive-tree", "party-forge-hero-district-v1"],
	"city-to-logistics-district": ["logistics-district-charter", "Open Logistics District", "party-forge-building-warehouse", "warehouse-passive-tree", "party-forge-warehouse-v1"],
	"city-to-market-district": ["market-district-charter", "Open Market District", "party-forge-market-district", "market-district-passive-tree", "party-forge-market-district-v1"],
	"city-to-trials-district": ["trials-district-charter", "Open Trials District", "party-forge-trials-district", "trials-district-passive-tree", "party-forge-trials-district-v1"],
}

static func translate(document: Dictionary, source_path: String, source_sha256: String) -> PassiveTreeLoadResult:
	var header := LatticewrightRuntimeHeader.validate(document)
	if not header.ok():
		return PassiveTreeLoadResult.failure(header.error)
	var root_error := _validate_root(document, header)
	if not root_error.is_empty():
		return PassiveTreeLoadResult.failure(root_error)

	var graph := (document["graphs"] as Array)[0] as Dictionary
	var content_by_id: Dictionary = {}
	var content_error := _validate_content(document["content"] as Array, content_by_id)
	if not content_error.is_empty():
		return PassiveTreeLoadResult.failure(content_error)

	var nodes: Array[PassiveTreeNode] = []
	var node_error := _project_nodes(graph, content_by_id, nodes)
	if not node_error.is_empty():
		return PassiveTreeLoadResult.failure(node_error)
	var connections: Array[PassiveTreeConnection] = []
	var connection_error := _project_connections(graph, content_by_id, connections)
	if not connection_error.is_empty():
		return PassiveTreeLoadResult.failure(connection_error)

	var geometry_errors := CityTreeGeometryValidator.validate(nodes, connections)
	if not geometry_errors.is_empty():
		var geometry_failure := PassiveTreeLoadResult.new()
		geometry_failure.errors.assign(geometry_errors)
		return geometry_failure

	var portals: Array[PassiveTreePortal] = []
	var portal_error := _project_portals(document["graphPortals"] as Array, content_by_id, nodes, portals)
	if not portal_error.is_empty():
		return PassiveTreeLoadResult.failure(portal_error)
	var requirement_error := _validate_extraction_requirements(nodes)
	if not requirement_error.is_empty():
		return PassiveTreeLoadResult.failure(requirement_error)

	var metadata := {
		"sourceFormat": LatticewrightRuntimeHeader.FORMAT,
		"sourceFormatVersion": FORMAT_VERSION,
		"sourceGraphId": GRAPH_ID,
		"sourcePath": source_path,
		"sourceProjectId": PROJECT_ID,
		"sourceSha256": source_sha256,
	}
	var result := PassiveTreeLoadResult.new()
	result.tree = PassiveTreeDefinition.new(
		StringName(DOMAIN_TREE_ID),
		document["name"] as String,
		[&"city-heart"],
		nodes,
		connections,
		metadata,
		portals,
	)
	return result

static func _validate_root(document: Dictionary, header: LatticewrightRuntimeHeader) -> String:
	if header.format_version != FORMAT_VERSION:
		return _error("formatVersion", "must equal %d" % FORMAT_VERSION)
	if String(header.project_id) != PROJECT_ID:
		return _error("projectId", "must equal %s" % PROJECT_ID)
	if document.get("name") != "Party Forge City":
		return _error("name", "must equal Party Forge City")
	if document.get("archetype") != "passive-tree":
		return _error("archetype", "must equal passive-tree")
	if document.get("vocabulary") != EXPECTED_VOCABULARY:
		return _error("vocabulary", "must match the exact City vocabulary")
	if document.get("extensions") != EXPECTED_EXTENSIONS:
		return _error("extensions", "must match the exact runtime-integrated City extensions")
	if not _json_equal(document.get("schemas"), EXPECTED_SCHEMAS):
		return _error("schemas", "must match the exact approved City schema definitions")
	if not (document.get("assets") as Array).is_empty():
		return _error("assets", "must be empty")
	var graphs := document.get("graphs") as Array
	if graphs.size() != 1 or not graphs[0] is Dictionary:
		return _error("graphs", "must contain exactly one City graph object")
	var graph := graphs[0] as Dictionary
	if not _has_exact_keys(graph, ["connections", "decorations", "extensions", "groups", "id", "name", "placements", "startingPlacementIds"]):
		return _error("graph", "must contain the exact runtime-v3 graph fields")
	if graph.get("id") != GRAPH_ID:
		return _error("graph.id", "must equal %s" % GRAPH_ID)
	if graph.get("name") != "City Passive Tree":
		return _error("graph.name", "must equal City Passive Tree")
	if graph.get("startingPlacementIds") != ["city-heart"]:
		return _error("startingPlacementIds", "must equal [city-heart]")
	if not graph.get("groups") is Array or not (graph.get("groups") as Array).is_empty():
		return _error("graph.groups", "must be an empty array")
	if not graph.get("decorations") is Array or not (graph.get("decorations") as Array).is_empty():
		return _error("graph.decorations", "must be an empty array")
	if graph.get("extensions") != {}:
		return _error("graph.extensions", "must be empty")
	if not graph.get("placements") is Array or (graph.get("placements") as Array).size() != 37:
		return _error("graph.placements", "must contain exactly 37 placements")
	if not graph.get("connections") is Array or (graph.get("connections") as Array).size() != 37:
		return _error("graph.connections", "must contain exactly 37 connections")
	if not document.get("content") is Array or (document.get("content") as Array).size() != 37:
		return _error("content", "must contain exactly 37 content records")
	if not document.get("graphPortals") is Array or (document.get("graphPortals") as Array).size() != 6:
		return _error("graphPortals", "must contain exactly 6 portals")
	return ""

static func _validate_content(values: Array, content_by_id: Dictionary) -> String:
	for index: int in values.size():
		if not values[index] is Dictionary:
			return _error("content[%d]" % index, "must be an object")
		var content := values[index] as Dictionary
		if not _has_exact_keys(content, ["categoryIds", "description", "effects", "extensions", "fieldValues", "iconAssetId", "id", "name", "requirements", "tagIds", "typeId"]):
			return _error("content[%d]" % index, "must contain the exact runtime-v3 content fields")
		var id_value: Variant = content.get("id")
		if not _is_stable_identifier(id_value):
			return _error("content[%d].id" % index, "must be a stable lowercase ID")
		var content_id := StringName(id_value as String)
		if content_by_id.has(content_id):
			return _error("content[%d].id" % index, "duplicate content ID %s" % content_id)
		var expected_state := _expected_activation_state(content_id)
		if expected_state.is_empty():
			return _error("content[%d].id" % index, "unexpected City content ID %s" % content_id)
		if content.get("typeId") != "passive":
			return _error("content[%d].typeId" % index, "must equal passive")
		if not content.get("name") is String or String(content.get("name")).strip_edges().is_empty():
			return _error("content[%d].name" % index, "must be a non-empty string")
		if not content.get("description") is String:
			return _error("content[%d].description" % index, "must be a string")
		if content.get("iconAssetId") != null:
			return _error("content[%d].iconAssetId" % index, "must be null when assets are empty")
		if content.get("extensions") != {"evidence": "party-forge-repository-and-approved-design"}:
			return _error("content[%d].extensions" % index, "must contain exact evidence provenance")
		var field_values: Variant = content.get("fieldValues")
		if not field_values is Dictionary or not _has_exact_keys(field_values as Dictionary, ["party-forge-activation-state"]):
			return _error("content[%d].fieldValues" % index, "must contain exactly party-forge-activation-state")
		var actual_state: Variant = (field_values as Dictionary).get("party-forge-activation-state")
		if actual_state not in ["implemented", "portal-gated", "future"]:
			return _error("content[%d].activationState" % index, "must be implemented, portal-gated, or future")
		if actual_state != expected_state:
			return _error("content[%d].activationState" % index, "%s must equal %s" % [content_id, expected_state])
		var expected_tier := "start" if content_id == &"city-heart" else "small"
		if content.get("categoryIds") != [expected_tier]:
			return _error("content[%d].categoryIds" % index, "must equal [%s]" % expected_tier)
		if content.get("tagIds") != ["city", "party-forge", expected_tier]:
			return _error("content[%d].tagIds" % index, "must equal the exact City tag set")
		if not content.get("effects") is Array or not content.get("requirements") is Array:
			return _error("content[%d]" % index, "effects and requirements must be arrays")
		content_by_id[content_id] = content
	return ""

static func _project_nodes(graph: Dictionary, content_by_id: Dictionary, nodes: Array[PassiveTreeNode]) -> String:
	var placement_ids: Dictionary = {}
	var used_content_ids: Dictionary = {}
	for index: int in (graph["placements"] as Array).size():
		var value: Variant = (graph["placements"] as Array)[index]
		if not value is Dictionary:
			return _error("placements[%d]" % index, "must be an object")
		var placement := value as Dictionary
		if not _has_exact_keys(placement, ["contentId", "extensions", "fieldValues", "id", "position", "typeId"]):
			return _error("placements[%d]" % index, "must contain exact runtime-v3 placement fields")
		var id_value: Variant = placement.get("id")
		var content_id_value: Variant = placement.get("contentId")
		if not _is_stable_identifier(id_value) or not _is_stable_identifier(content_id_value):
			return _error("placements[%d].id" % index, "placement and content IDs must be stable lowercase IDs")
		var placement_id := StringName(id_value as String)
		var content_id := StringName(content_id_value as String)
		if placement_ids.has(placement_id):
			return _error("placements[%d].id" % index, "duplicate placement ID %s" % placement_id)
		if used_content_ids.has(content_id):
			return _error("placements[%d].contentId" % index, "content %s is placed more than once" % content_id)
		if placement_id != content_id or not content_by_id.has(content_id):
			return _error("placements[%d].contentId" % index, "must map one-to-one to the same City content ID")
		var type_id: Variant = placement.get("typeId")
		if not PLACEMENT_TYPES.has(type_id):
			return _error("placements[%d].typeId" % index, "unsupported placement type %s" % [type_id])
		var node_type: StringName = PLACEMENT_TYPES[type_id]
		if (content_id == &"city-heart") != (node_type == &"start"):
			return _error("placements[%d].typeId" % index, "only city-heart may use start-node")
		if placement.get("extensions") != {}:
			return _error("placements[%d].extensions" % index, "must be empty")
		var field_values: Variant = placement.get("fieldValues")
		if not field_values is Dictionary or not _has_exact_keys(field_values as Dictionary, ["node-cost"]):
			return _error("placements[%d].fieldValues" % index, "must contain exactly node-cost")
		var cost_value: Variant = _exact_integer((field_values as Dictionary).get("node-cost"))
		if cost_value == null or int(cost_value) < 0:
			return _error("placements[%d].node-cost" % index, "must be a nonnegative exact integer")
		var position_value: Variant = placement.get("position")
		if not position_value is Dictionary or not _has_exact_keys(position_value as Dictionary, ["x", "y"]):
			return _error("placements[%d].position" % index, "must contain exactly finite x and y")
		var x: Variant = (position_value as Dictionary).get("x")
		var y: Variant = (position_value as Dictionary).get("y")
		if not _is_finite_number(x):
			return _error("placements[%d].position.x" % index, "must be finite")
		if not _is_finite_number(y):
			return _error("placements[%d].position.y" % index, "must be finite")
		var position := Vector2(float(x), float(y))
		if not position.is_finite():
			return _error("placements[%d].position" % index, "must remain a finite Vector2")
		var content := content_by_id[content_id] as Dictionary
		var effects: Array[PassiveTreeEffect] = []
		var effect_error := _translate_effects(content_id, content["effects"] as Array, effects)
		if not effect_error.is_empty():
			return effect_error
		var requirements: Array[PassiveTreeRequirement] = []
		var requirement_error := _translate_requirements(content_id, content["requirements"] as Array, requirements)
		if not requirement_error.is_empty():
			return requirement_error
		var tags: Array[StringName] = []
		for tag: Variant in content["tagIds"] as Array:
			tags.append(StringName(tag as String))
		var metadata := {
			"activationState": (content["fieldValues"] as Dictionary)["party-forge-activation-state"],
			"sourceContentId": String(content_id),
			"sourceGraphId": GRAPH_ID,
			"sourcePlacementId": String(placement_id),
			"sourceProjectId": PROJECT_ID,
		}
		nodes.append(PassiveTreeNode.new(
			content_id,
			node_type,
			position,
			content["name"] as String,
			content["description"] as String,
			int(cost_value),
			tags,
			null,
			effects,
			requirements,
			metadata,
		))
		placement_ids[placement_id] = true
		used_content_ids[content_id] = true
	if used_content_ids.size() != content_by_id.size():
		return _error("placements", "must place every content record exactly once")
	return ""

static func _project_connections(graph: Dictionary, content_by_id: Dictionary, connections: Array[PassiveTreeConnection]) -> String:
	var connection_ids: Dictionary = {}
	var endpoint_pairs: Dictionary = {}
	for index: int in (graph["connections"] as Array).size():
		var value: Variant = (graph["connections"] as Array)[index]
		if not value is Dictionary:
			return _error("connections[%d]" % index, "must be an object")
		var connection := value as Dictionary
		if not _has_exact_keys(connection, ["conditions", "cost", "direction", "extensions", "from", "id", "to"]):
			return _error("connections[%d]" % index, "must contain exact runtime-v3 connection fields")
		for key: String in ["id", "from", "to"]:
			if not _is_stable_identifier(connection.get(key)):
				return _error("connections[%d].%s" % [index, key], "must be a stable lowercase ID")
		var connection_id := StringName(connection["id"] as String)
		var from_id := StringName(connection["from"] as String)
		var to_id := StringName(connection["to"] as String)
		if connection_ids.has(connection_id):
			return _error("connections[%d].id" % index, "duplicate connection ID %s" % connection_id)
		if not content_by_id.has(from_id) or not content_by_id.has(to_id):
			return _error("connections[%d]" % index, "endpoints must reference placed City content")
		if from_id == to_id:
			return _error("connections[%d]" % index, "self-edges are not allowed")
		var first := String(from_id) if String(from_id) < String(to_id) else String(to_id)
		var second := String(to_id) if first == String(from_id) else String(from_id)
		var pair := "%s\u001f%s" % [first, second]
		if endpoint_pairs.has(pair):
			return _error("connections[%d]" % index, "duplicate endpoint pair %s/%s" % [first, second])
		if connection.get("direction") != "bidirectional":
			return _error("connections[%d].direction" % index, "must equal bidirectional")
		var cost_value: Variant = _exact_integer(connection.get("cost"))
		if cost_value == null or int(cost_value) < 0:
			return _error("connections[%d].cost" % index, "must be a nonnegative exact integer")
		if connection.get("extensions") != {}:
			return _error("connections[%d].extensions" % index, "must be empty")
		if not connection.get("conditions") is Array:
			return _error("connections[%d].conditions" % index, "must be an array")
		var conditions: Array[PassiveTreeRequirement] = []
		var condition_error := _translate_requirements(connection_id, connection["conditions"] as Array, conditions)
		if not condition_error.is_empty():
			return condition_error
		connections.append(PassiveTreeConnection.new(connection_id, from_id, to_id, &"bidirectional", int(cost_value), conditions, {}))
		connection_ids[connection_id] = true
		endpoint_pairs[pair] = true
	return ""

static func _translate_effects(owner_id: StringName, values: Array, effects: Array[PassiveTreeEffect]) -> String:
	for index: int in values.size():
		if not values[index] is Dictionary:
			return _error("content.%s.effects[%d]" % [owner_id, index], "must be an object")
		var instance := values[index] as Dictionary
		if not _has_exact_keys(instance, ["definitionId", "values"]) or not instance.get("values") is Dictionary:
			return _error("content.%s.effects[%d]" % [owner_id, index], "must contain exactly definitionId and object values")
		var definition: Variant = instance.get("definitionId")
		var parameters := instance["values"] as Dictionary
		match definition:
			"party-forge-feature-unlock":
				var error := _validate_identifier_values(parameters, ["feature-id"], "feature-id")
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"feature_unlock", &"set", true, {"featureId": parameters["feature-id"]}))
			"party-forge-inventory-columns-add":
				var error := _validate_integer_scope_values(parameters, ["amount", "scope"])
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"inventory_columns", &"add_flat", int(_exact_integer(parameters["amount"])), {"scope": "profile"}))
			"party-forge-stash-tabs-add":
				var error := _validate_integer_scope_values(parameters, ["amount", "scope", "slots-per-tab"], ["amount", "slots-per-tab"])
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"stash_tabs", &"add_flat", int(_exact_integer(parameters["amount"])), {"scope": "profile", "slotsPerTab": int(_exact_integer(parameters["slots-per-tab"]))}))
			"party-forge-building-discovery":
				var error := _validate_identifier_values(parameters, ["building-id"], "building-id")
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"building_discovery", &"set", true, {"buildingId": parameters["building-id"]}))
			"party-forge-extraction-capacity-add":
				var error := _validate_integer_scope_values(parameters, ["amount", "scope"])
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"extraction_capacity", &"add_flat", int(_exact_integer(parameters["amount"])), {"scope": "profile"}))
			"party-forge-tree-discovery":
				var error := _validate_identifier_values(parameters, ["tree-id"], "tree-id")
				if not error.is_empty(): return _error("content.%s.effects[%d].values" % [owner_id, index], error)
				effects.append(PassiveTreeEffect.new(&"tree_discovery", &"set", true, {"treeId": parameters["tree-id"]}))
			_:
				return _error("content.%s.effects[%d].definitionId" % [owner_id, index], "unknown effect definition %s" % [definition])
	return ""

static func _translate_requirements(owner_id: StringName, values: Array, requirements: Array[PassiveTreeRequirement]) -> String:
	for index: int in values.size():
		if not values[index] is Dictionary:
			return _error("content.%s.requirements[%d]" % [owner_id, index], "must be an object")
		var instance := values[index] as Dictionary
		if not _has_exact_keys(instance, ["definitionId", "values"]) or not instance.get("values") is Dictionary:
			return _error("content.%s.requirements[%d]" % [owner_id, index], "must contain exactly definitionId and object values")
		if instance.get("definitionId") != "party-forge-allocated-node":
			return _error("content.%s.requirements[%d].definitionId" % [owner_id, index], "unknown requirement definition %s" % [instance.get("definitionId")])
		var parameters := instance["values"] as Dictionary
		if not _has_exact_keys(parameters, ["node-id", "tree-id"]):
			return _error("content.%s.requirements[%d].values" % [owner_id, index], "values must contain exactly node-id and tree-id")
		if not _is_stable_identifier(parameters.get("node-id")) or not _is_stable_identifier(parameters.get("tree-id")):
			return _error("content.%s.requirements[%d].values" % [owner_id, index], "node-id and tree-id must be stable lowercase IDs")
		requirements.append(PassiveTreeRequirement.new(
			&"allocated_node",
			&"contains",
			parameters["node-id"],
			{"treeId": parameters["tree-id"]},
		))
	return ""

static func _project_portals(
	values: Array,
	content_by_id: Dictionary,
	nodes: Array[PassiveTreeNode],
	portals: Array[PassiveTreePortal],
) -> String:
	var nodes_by_id: Dictionary = {}
	for tree_node: PassiveTreeNode in nodes:
		nodes_by_id[tree_node.id] = tree_node
	var seen: Dictionary = {}
	for index: int in values.size():
		if not values[index] is Dictionary:
			return _error("graphPortals[%d]" % index, "must be an object")
		var portal := values[index] as Dictionary
		if not _has_exact_keys(portal, ["extensions", "id", "label", "role", "sourceGraphId", "sourcePlacementId", "targetGraphId", "targetProjectId"]):
			return _error("graphPortals[%d]" % index, "must contain exact runtime-v3 portal fields")
		var portal_id: Variant = portal.get("id")
		if not portal_id is String or not PORTAL_CONTRACTS.has(portal_id):
			return _error("graphPortals[%d].id" % index, "unexpected portal %s" % [portal_id])
		if seen.has(portal_id):
			return _error("graphPortals[%d].id" % index, "duplicate portal %s" % portal_id)
		var contract := PORTAL_CONTRACTS[portal_id] as Array
		if portal.get("sourceGraphId") != GRAPH_ID \
		or portal.get("sourcePlacementId") != contract[0] \
		or portal.get("label") != contract[1] \
		or portal.get("role") != "drill-down" \
		or portal.get("targetProjectId") != contract[2] \
		or portal.get("targetGraphId") != contract[3] \
		or portal.get("extensions") != {}:
			return _error("graphPortals[%d].portal" % index, "portal %s must match its exact approved contract" % portal_id)
		var source_id := StringName(contract[0] as String)
		if not content_by_id.has(source_id) or not nodes_by_id.has(source_id):
			return _error("graphPortals[%d].sourcePlacementId" % index, "must reference an existing charter node")
		var source_node := nodes_by_id[source_id] as PassiveTreeNode
		if source_node.metadata.get("activationState") != "portal-gated" or source_node.effects.size() != 1:
			return _error("graphPortals[%d].portal/effect" % index, "charter must be portal-gated with exactly one discovery effect")
		var effect := source_node.effects[0]
		if effect.effect_id != &"tree_discovery" or effect.parameters.get("treeId") != contract[4]:
			return _error("graphPortals[%d].portal/effect" % index, "charter discovery must match the portal target")
		portals.append(PassiveTreePortal.new(
			StringName(portal_id as String),
			source_id,
			portal["label"] as String,
			&"drill-down",
			StringName(portal["targetProjectId"] as String),
			StringName(portal["targetGraphId"] as String),
			StringName(contract[4] as String),
		))
		seen[portal_id] = true
	if seen.size() != PORTAL_CONTRACTS.size():
		return _error("graphPortals", "must contain every approved City portal exactly once")
	return ""

static func _validate_extraction_requirements(nodes: Array[PassiveTreeNode]) -> String:
	var extraction: PassiveTreeNode
	for tree_node: PassiveTreeNode in nodes:
		if tree_node.id == &"extraction-license":
			extraction = tree_node
			break
	if extraction == null or extraction.requirements.size() != 2:
		return _error("extraction-license.requirements", "extraction-license must have exactly two requirements")
	var found: Dictionary = {"field-pack": false, "stash-access": false}
	for requirement: PassiveTreeRequirement in extraction.requirements:
		if requirement.requirement_id != &"allocated_node" or requirement.operator != &"contains" \
		or requirement.parameters != {"treeId": DOMAIN_TREE_ID} or not found.has(requirement.value):
			return _error("extraction-license.requirements", "requirements must be exact field-pack and stash-access prerequisites")
		found[requirement.value] = true
	if not found["field-pack"] or not found["stash-access"]:
		return _error("extraction-license.requirements", "requirements must include field-pack and stash-access")
	return ""

static func _expected_activation_state(content_id: StringName) -> String:
	if content_id in IMPLEMENTED_IDS:
		return "implemented"
	if content_id in PORTAL_GATED_IDS:
		return "portal-gated"
	if content_id in FUTURE_IDS:
		return "future"
	return ""

static func _validate_identifier_values(values: Dictionary, expected_keys: Array[String], identifier_key: String) -> String:
	if not _has_exact_keys(values, expected_keys):
		return "values must contain exactly %s" % [expected_keys]
	if not _is_stable_identifier(values.get(identifier_key)):
		return "%s must be a stable lowercase ID" % identifier_key
	return ""

static func _validate_integer_scope_values(
	values: Dictionary,
	expected_keys: Array[String],
	integer_keys: Array[String] = ["amount"],
) -> String:
	if not _has_exact_keys(values, expected_keys):
		return "values must contain exactly %s" % [expected_keys]
	if values.get("scope") != "profile":
		return "scope must equal profile"
	for key: String in integer_keys:
		if _exact_integer(values.get(key)) == null:
			return "%s must be an exact integer" % key
	return ""

static func _has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key: Variant in value.keys():
		if not key is String:
			return false
		actual.append(key as String)
	actual.sort()
	var ordered_expected := expected.duplicate()
	ordered_expected.sort()
	return actual == ordered_expected

static func _json_equal(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return (actual is int or actual is float) and (expected is int or expected is float) \
			and is_finite(float(actual)) and is_finite(float(expected)) and float(actual) == float(expected)
	if actual is Dictionary:
		var actual_dictionary := actual as Dictionary
		var expected_dictionary := expected as Dictionary
		if actual_dictionary.size() != expected_dictionary.size():
			return false
		for key: Variant in actual_dictionary:
			if not expected_dictionary.has(key) or not _json_equal(actual_dictionary[key], expected_dictionary[key]):
				return false
		return true
	if actual is Array:
		var actual_array := actual as Array
		var expected_array := expected as Array
		if actual_array.size() != expected_array.size():
			return false
		for index: int in actual_array.size():
			if not _json_equal(actual_array[index], expected_array[index]):
				return false
		return true
	return actual == expected

static func _exact_integer(value: Variant) -> Variant:
	if value is int:
		return value
	if not value is float:
		return null
	var number := value as float
	if not is_finite(number) or number != floor(number) \
		or number < LatticewrightRuntimeHeader.SIGNED_64_MIN_AS_FLOAT \
		or number >= LatticewrightRuntimeHeader.SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT:
		return null
	return int(number)

static func _is_finite_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value as float))

static func _is_stable_identifier(value: Variant) -> bool:
	if not value is String:
		return false
	var text := value as String
	if text.is_empty() or text != text.strip_edges():
		return false
	for index: int in text.length():
		var code := text.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 45 or code == 95):
			return false
	return text.unicode_at(0) != 45 and text.unicode_at(0) != 95 \
		and text.unicode_at(text.length() - 1) != 45 and text.unicode_at(text.length() - 1) != 95

static func _error(field: String, reason: String) -> String:
	return "%s field=%s reason=%s" % [ERROR_PREFIX, field, reason]
