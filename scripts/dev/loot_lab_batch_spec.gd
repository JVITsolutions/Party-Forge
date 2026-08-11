class_name LootLabBatchSpec
extends RefCounted

const MAX_ATTEMPTS := 100000
const SAMPLE_LIMIT := 100
const PREVIEW_NAMESPACE_PREFIX := "loot-lab-preview:"

var target_count := 0
var error := ""
var _request_template: ItemGenerationRequest
var _request_document: Dictionary = {}
var _identity := ""

static func create(
	request: ItemGenerationRequest,
	attempts: int,
	foundation: ItemFoundationCatalog
) -> LootLabBatchSpec:
	var result := LootLabBatchSpec.new()
	result._initialize(request, attempts, foundation)
	return result

func ok() -> bool:
	return error.is_empty()

func request_document() -> Dictionary:
	return _request_document.duplicate(true)

func request_for_attempt(attempt_index: int) -> ItemGenerationRequest:
	if not ok() or attempt_index < 0 or attempt_index >= target_count:
		return null
	return _request_template.copy_with_sequence(_request_template.generation_sequence + attempt_index)

func sample_attempt_indexes() -> Array[int]:
	var result: Array[int] = []
	if not ok():
		return result
	if target_count <= SAMPLE_LIMIT:
		for attempt_index: int in target_count:
			result.append(attempt_index)
		return result
	for sample_index: int in SAMPLE_LIMIT:
		result.append(sample_index * (target_count - 1) / (SAMPLE_LIMIT - 1))
	return result

func scenario_identity() -> String:
	return _identity

func preview_issuer_namespace() -> String:
	if not ok():
		return ""
	return "%s%s" % [PREVIEW_NAMESPACE_PREFIX, _identity.sha256_text()]

func _initialize(
	request: ItemGenerationRequest,
	attempts: int,
	foundation: ItemFoundationCatalog
) -> void:
	if request == null:
		error = _error("request", "must not be null")
		return
	if foundation == null:
		error = _error("foundation", "must not be null")
		return
	if attempts < 1 or attempts > MAX_ATTEMPTS:
		error = _error("target_count", "must be between 1 and %d" % MAX_ATTEMPTS)
		return
	var request_error := request.validate(foundation)
	if not request_error.is_empty():
		error = request_error
		return
	var final_sequence := request.generation_sequence + attempts - 1
	if final_sequence > ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
		error = _error("generation_sequence", "final sequence exceeds JSON-safe integer maximum")
		return

	var frozen_request := request.copy_with_sequence(request.generation_sequence)
	var canonical := frozen_request.canonical_document()
	if canonical.is_empty():
		error = _error("request", "canonical document is invalid")
		return
	var identity := ItemGenerationBalanceReport.scenario_identity(frozen_request)
	if identity.is_empty():
		error = _error("request", "scenario identity is invalid")
		return

	target_count = attempts
	_request_template = frozen_request
	_request_document = canonical.duplicate(true)
	_identity = identity

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_LOOT_LAB_BATCH_ERROR field=%s reason=%s" % [field, reason]
