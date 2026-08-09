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
	var request_error := request.validate(foundation) if request != null else "PARTY_FORGE_ITEM_GENERATION_ERROR stage=request field=request reason=missing"
	if not request_error.is_empty():
		return _fail(trace, request, &"request", &"invalid_request", {"message": request_error})

	var base := ItemBaseSelector.select(request, equipment, trace)
	if base == null:
		return _fail(trace, request, &"base", &"no_eligible_base", {})
	var rarity := ItemRaritySelector.select(request, foundation, trace)
	if rarity == null:
		return _fail(trace, request, &"rarity", &"no_eligible_rarity", {})
	var pattern := ItemPatternSelector.select(request, rarity, trace)
	if pattern == null:
		return _fail(trace, request, &"pattern", &"no_eligible_pattern", {"rarity_id": String(rarity.id)})

	var assembled := ItemAffixAssembler.assemble(request, base, rarity, pattern, foundation, trace)
	if not assembled.ok():
		return _fail(trace, request, &"affix", assembled.error_code, assembled.details)

	var affix_documents: Array[Dictionary] = []
	for affix: ItemAffixInstance in assembled.affixes:
		affix_documents.append(affix.to_dictionary())
	var source := {
		"generation": {
			"generator_version": GENERATOR_VERSION,
			"domain": String(request.generation_domain),
			"source_id": String(request.source_id),
			"item_level": request.item_level,
			"request_sequence": request.generation_sequence,
		}
	}
	var issued := ItemInstanceIssuer.issue(
		issuer_namespace,
		item_sequence,
		source,
		request.seed,
		{
			"affixes": affix_documents,
			"base_definition_id": String(base.id),
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
	failure.stage = stage
	failure.code = code
	if request != null:
		failure.source_id = request.source_id
		failure.seed = request.seed
		failure.generation_sequence = request.generation_sequence
	failure.details = details.duplicate(true)
	return ItemGenerationResult.failed(failure, trace)
