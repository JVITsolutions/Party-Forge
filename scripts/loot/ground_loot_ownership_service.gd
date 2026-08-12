class_name GroundLootOwnershipService
extends RefCounted

func create_drop(
	context: PlayerRunContext,
	request: ItemGenerationRequest,
	record_identity: Dictionary,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	registry: GroundItemRegistry,
) -> GroundLootOwnershipResult:
	var prepared := _preflight(context, request, record_identity, equipment, foundation, registry)
	var error := String(prepared.get("error", ""))
	if not error.is_empty():
		return GroundLootOwnershipResult.failure(error, null, StringName(prepared.get("stage", &"configuration")), StringName(prepared.get("code", &"invalid_configuration")))

	var generated := context.issue_ground_item(request, equipment, foundation)
	if generated == null or not generated.ok():
		var generation_code := generated.failure.code if generated != null and generated.failure != null else &"generation_unavailable"
		return GroundLootOwnershipResult.failure(_generation_error(generated), generated, &"generation", generation_code)

	var record := GroundItemRecord.new()
	record.drop_id = StringName(record_identity["drop_id"])
	record.item_id = generated.item.instance_id
	record.run_player_id = context.run_player_id
	record.profile_id = context.profile_id
	record.player_number = int(record_identity["player_number"])
	record.color_id = StringName(record_identity["color_id"])
	record.world_position = record_identity["world_position"] as Vector3
	record.rarity_id = generated.item.rarity_id
	record.source_id = request.source_id
	record.ground_slot = int(prepared["ground_slot"])
	registry._commit_prevalidated(record)
	return GroundLootOwnershipResult.success(record, generated)

func _preflight(
	context: PlayerRunContext,
	request: ItemGenerationRequest,
	record_identity: Dictionary,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	registry: GroundItemRegistry,
) -> Dictionary:
	if context == null or not context.is_configured():
		return _failed("context", "configured owner context is required", &"ownership", &"context_invalid")
	if request == null:
		return _failed("request", "must not be null", &"configuration", &"request_missing")
	if equipment == null:
		return _failed("equipment", "catalog is required", &"configuration", &"equipment_catalog_missing")
	if foundation == null:
		return _failed("foundation", "catalog is required", &"configuration", &"foundation_catalog_missing")
	if registry == null:
		return _failed("registry", "must not be null", &"configuration", &"registry_missing")
	var request_error := request.validate(foundation)
	if not request_error.is_empty():
		return _failed("request", request_error, &"configuration", &"request_invalid")
	var identity_error := _identity_error(context, request, record_identity)
	if not identity_error.is_empty():
		return {"error": identity_error, "stage": &"ownership", "code": &"identity_mismatch"}

	var state := context.item_state()
	if state == null or state.owner_id != String(context.run_player_id):
		return _failed("owner", "item state owner does not match run player", &"ownership", &"item_state_mismatch")
	var ground := context.ground_items()
	if (
		ground == null
		or ground.container_id != ItemSlotContainer.RUN_GROUND_ITEMS_ID
		or ground.container_kind != ItemSlotContainer.RUN_GROUND_ITEMS
		or ground.owner_id != String(context.run_player_id)
	):
		return _failed("ground", "owner ground container is invalid", &"ownership", &"ground_owner_mismatch")
	var ground_slot := ground.first_empty_slot()
	if ground_slot < 0:
		return _failed("ground", "owner ground container is full", &"storage", &"ground_full")

	var issuer_namespace := _issuer_namespace(context)
	var sequence_result := _next_sequence(state.registry(), issuer_namespace)
	var sequence_error := String(sequence_result.get("error", ""))
	if not sequence_error.is_empty():
		return _failed("issuer", sequence_error, &"storage", &"issuer_sequence_invalid")
	var item_id := "item-%s-%016d" % [issuer_namespace.sha256_text(), int(sequence_result["sequence"])]
	if state.registry().has(item_id):
		return _failed("issuer", "predicted item ID already belongs to the owner", &"storage", &"ground_record_conflict")
	var registry_error := registry._preflight_identity(StringName(record_identity["drop_id"]), item_id)
	if not registry_error.is_empty():
		return {"error": registry_error, "stage": &"storage", "code": &"ground_record_conflict"}
	return {"error": "", "ground_slot": ground_slot, "item_id": item_id}

func _identity_error(context: PlayerRunContext, request: ItemGenerationRequest, identity: Dictionary) -> String:
	for field: String in ["drop_id", "run_player_id", "profile_id", "player_number", "color_id", "world_position", "source_id"]:
		if not identity.has(field):
			return _error("record_identity.%s" % field, "is required")
	var drop_id := StringName(identity["drop_id"])
	var run_player_id := StringName(identity["run_player_id"])
	var profile_id := String(identity["profile_id"])
	var player_number := int(identity["player_number"])
	var color_id := StringName(identity["color_id"])
	var position: Variant = identity["world_position"]
	var source_id := StringName(identity["source_id"])
	if drop_id.is_empty():
		return _error("record_identity.drop_id", "must not be empty")
	if run_player_id != context.run_player_id:
		return _error("record_identity.run_player_id", "must match context owner")
	if profile_id != context.profile_id:
		return _error("record_identity.profile_id", "must match context profile")
	if player_number != context.player_slot_index + 1:
		return _error("record_identity.player_number", "must match the session slot")
	if not PlayerColorPalette.is_valid(color_id):
		return _error("record_identity.color_id", "must be a supported player color")
	if not position is Vector3 or not _finite_position(position as Vector3):
		return _error("record_identity.world_position", "must be a finite Vector3")
	if source_id != request.source_id:
		return _error("record_identity.source_id", "must match request source")
	return ""

func _next_sequence(items: ItemRegistry, issuer_namespace: String) -> Dictionary:
	if items == null:
		return {"error": "item registry is missing", "sequence": 0}
	var maximum_sequence := -1
	var seen: Dictionary = {}
	for item_id: String in items.ids():
		var item := items.item(item_id)
		if item == null or String(item.origin.get("issuer_namespace", "")) != issuer_namespace:
			continue
		var value: Variant = item.origin.get("sequence")
		if not _nonnegative_json_int(value):
			return {"error": "existing issuer sequence is invalid", "sequence": 0}
		var sequence := int(value)
		if seen.has(sequence):
			return {"error": "existing issuer sequence is duplicated", "sequence": 0}
		seen[sequence] = true
		maximum_sequence = maxi(maximum_sequence, sequence)
	if maximum_sequence == ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
		return {"error": "issuer sequence is exhausted", "sequence": 0}
	return {"error": "", "sequence": maximum_sequence + 1}

func _issuer_namespace(context: PlayerRunContext) -> String:
	return "run:%s:%s:%s" % [context.profile_id, context.run_seed, context.run_player_id]

func _generation_error(generated: ItemGenerationResult) -> String:
	if generated == null or generated.failure == null:
		return _error("generation", "production generation returned no result")
	var message := String(generated.failure.details.get("message", ""))
	var detail := "stage=%s code=%s" % [generated.failure.stage, generated.failure.code]
	if not message.is_empty():
		detail += " message=%s" % message
	return _error("generation", detail)

func _failed(field: String, reason: String, stage: StringName, code: StringName) -> Dictionary:
	return {"error": _error(field, reason), "stage": stage, "code": code}

func _finite_position(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _nonnegative_json_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= ItemInstanceCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= 0.0 and number <= float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX)

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_GROUND_LOOT_OWNERSHIP_ERROR field=%s reason=%s" % [field, reason]
