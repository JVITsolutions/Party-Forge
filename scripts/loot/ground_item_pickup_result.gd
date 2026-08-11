class_name GroundItemPickupResult
extends RefCounted

enum Code { OK, MOVE_CLOSER, INVENTORY_FULL, NOT_OWNER, MISSING, TRANSACTION_REJECTED }

var code: Code = Code.MISSING
var message := ""

func _init(code_value: Code = Code.MISSING, message_value: String = "") -> void:
	code = code_value
	message = message_value

func ok() -> bool:
	return code == Code.OK
