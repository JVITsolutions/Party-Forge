class_name ItemGenerationService
extends RefCounted

const GENERATOR_VERSION := 1

static func generate(
	request: ItemGenerationRequest,
	issuer_namespace: String,
	item_sequence: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> ItemGenerationResult:
	var trace := ItemGenerationTrace.new()
	if request == null:
		return _fail(trace, null, &"request", &"invalid_request", {"message": "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=request reason=missing"})
	if foundation == null:
		return _fail(trace, request, &"request", &"invalid_request", {"message": "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=foundation reason=manifest missing"})
	var request_error := request.validate(foundation)
	if not request_error.is_empty():
		return _fail(trace, request, &"request", &"invalid_request", {"message": request_error})
	if equipment == null:
		trace.record(&"base", [], {"<catalog>": "equipment_catalog_missing"}, {}, &"")
		return _fail(trace, request, &"base", &"no_eligible_base", _selector_failure_details(trace, &"base"))

	var base := ItemBaseSelector.select(request, equipment, trace)
	if base == null:
		return _fail(trace, request, &"base", &"no_eligible_base", _selector_failure_details(trace, &"base"))
	var rarity := ItemRaritySelector.select(request, foundation, trace)
	if rarity == null:
		return _fail(trace, request, &"rarity", &"no_eligible_rarity", _selector_failure_details(trace, &"rarity"))
	var pattern := ItemPatternSelector.select(request, rarity, trace)
	if pattern == null:
		return _fail(trace, request, &"pattern", &"no_eligible_pattern", _selector_failure_details(trace, &"pattern", {"rarity_id": String(rarity.id)}))

	var assembled := ItemAffixAssembler.assemble(request, base, rarity, pattern, foundation, trace)
	if not assembled.ok():
		return _fail(trace, request, &"affix", assembled.error_code, assembled.details)

	var affix_documents: Array[Dictionary] = []
	for affix: ItemAffixInstance in assembled.affixes:
		affix_documents.append(affix.to_dictionary())
	var generation_provenance := {
		"generator_version": GENERATOR_VERSION,
		"domain": String(request.generation_domain),
		"source_id": String(request.source_id),
		"item_level": request.item_level,
		"request_sequence": request.generation_sequence,
		"selected_base_id": String(base.id),
		"selected_rarity_id": String(rarity.id),
	}
	if not request.forced_base_id.is_empty():
		generation_provenance["forced_base_id"] = String(request.forced_base_id)
	if not request.forced_rarity_id.is_empty():
		generation_provenance["forced_rarity_id"] = String(request.forced_rarity_id)
	var source := {"generation": generation_provenance}
	var issued := ItemInstanceIssuer.issue(
		issuer_namespace,
		item_sequence,
		source,
		request.seed,
		{
			"affixes": affix_documents,
			"base_definition_id": String(base.id),
			"base_damage_components": [],
			"item_level": request.item_level,
			"rarity_id": String(rarity.id),
		},
		equipment,
		foundation
	)
	if not issued.ok():
		return _fail(trace, request, &"issuance", &"issuer_rejected", {"message": issued.error})
	return ItemGenerationResult.success(issued.item, trace)

static func _fail(
	trace: ItemGenerationTrace,
	request: ItemGenerationRequest,
	stage: StringName,
	code: StringName,
	details: Dictionary
) -> ItemGenerationResult:
	var failure := ItemGenerationFailure.new()
	failure.generator_version = GENERATOR_VERSION
	failure.stage = stage
	failure.code = code
	if request != null:
		failure.source_id = request.source_id
		failure.seed = request.seed
		failure.generation_sequence = request.generation_sequence
	failure.details = details.duplicate(true)
	return ItemGenerationResult.failed(failure, trace)

static func _selector_failure_details(
	trace: ItemGenerationTrace,
	stage: StringName,
	initial_details: Dictionary = {}
) -> Dictionary:
	var details := initial_details.duplicate(true)
	var stages := trace.stages
	for index: int in range(stages.size() - 1, -1, -1):
		var stage_record := stages[index]
		if stage_record.get("stage", "") != String(stage):
			continue
		details["rejected"] = (stage_record.get("rejected", {}) as Dictionary).duplicate(true)
		break
	return details
