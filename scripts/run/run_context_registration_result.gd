class_name RunContextRegistrationResult
extends RefCounted

enum Code {
	OK,
	INVALID_CONTEXT,
	DUPLICATE_RUN_PLAYER,
	DUPLICATE_PROFILE,
	DUPLICATE_SLOT,
	DUPLICATE_DEVICE,
	ARENA_RUN_LOCKED,
}

var code := Code.OK
var message := ""

static func success() -> RunContextRegistrationResult:
	return RunContextRegistrationResult.new()

static func failure(value: Code, detail: String) -> RunContextRegistrationResult:
	var result := RunContextRegistrationResult.new()
	result.code = value
	result.message = "PARTY_FORGE_RUN_CONTEXT_ERROR code=%s reason=%s" % [Code.keys()[value], detail]
	return result

func ok() -> bool:
	return code == Code.OK
