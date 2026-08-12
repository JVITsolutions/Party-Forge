class_name GroundItemPickupResult
extends RefCounted

enum Code { OK, MOVE_CLOSER, INVENTORY_FULL, NOT_OWNER, MISSING, TRANSACTION_REJECTED }

var code: Code = Code.MISSING
var message := ""
var item_name := ""
var rarity_name := ""

func _init(code_value: Code = Code.MISSING, message_value: String = "", item_name_value: String = "", rarity_name_value: String = "") -> void:
	code = code_value
	message = message_value
	item_name = item_name_value
	rarity_name = rarity_name_value

func ok() -> bool:
	return code == Code.OK

func copy() -> GroundItemPickupResult:
	return GroundItemPickupResult.new(code, message, item_name, rarity_name)

func to_dictionary() -> Dictionary:
	return {"code": code, "message": message, "item_name": item_name, "rarity_name": rarity_name}
