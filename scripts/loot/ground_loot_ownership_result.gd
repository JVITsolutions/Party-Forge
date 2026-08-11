class_name GroundLootOwnershipResult
extends RefCounted

var record: GroundItemRecord
var generated: ItemGenerationResult
var error := ""
var diagnostic_stage: StringName
var diagnostic_code: StringName

static func success(record_value: GroundItemRecord, generated_value: ItemGenerationResult) -> GroundLootOwnershipResult:
	var result := GroundLootOwnershipResult.new()
	result.record = record_value.copy() if record_value != null else null
	result.generated = generated_value
	return result

static func failure(
	message: String,
	generated_value: ItemGenerationResult = null,
	stage: StringName = &"configuration",
	code: StringName = &"unknown",
) -> GroundLootOwnershipResult:
	var result := GroundLootOwnershipResult.new()
	result.error = message
	result.generated = generated_value
	result.diagnostic_stage = stage
	result.diagnostic_code = code
	return result

func ok() -> bool:
	return error.is_empty() and record != null and generated != null and generated.ok()
