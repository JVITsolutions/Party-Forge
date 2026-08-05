class_name ItemTransactionResult
extends RefCounted

enum Code {
	OK,
	INVALID_REQUEST,
	UNKNOWN_OWNER,
	UNKNOWN_CONTAINER,
	SLOT_OUT_OF_BOUNDS,
	SOURCE_MISMATCH,
	DESTINATION_OCCUPIED,
	DUPLICATE_INSTANCE,
	DUPLICATE_REFERENCE,
	INVALID_ITEM,
	TRANSACTION_REPLAY,
	TRANSACTION_COLLISION,
}

var code: Code = Code.INVALID_REQUEST
var _next_state: ItemOwnershipState
var next_state: ItemOwnershipState:
	get:
		return _next_state.copy() if _next_state != null else null
	set(value):
		_next_state = value.copy() if value != null else null
var duplicate := false

static func create(code_value: Code, state: ItemOwnershipState = null, duplicate_value: bool = false) -> ItemTransactionResult:
	var result := ItemTransactionResult.new()
	result.code = code_value
	result.next_state = state
	result.duplicate = duplicate_value
	return result

func ok() -> bool:
	return code == Code.OK
