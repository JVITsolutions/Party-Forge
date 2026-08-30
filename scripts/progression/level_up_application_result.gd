class_name LevelUpApplicationResult
extends RefCounted

var choice_key: String = ""
var recipient_member_id: int = 0
var reason: String = ""
var _accepted: bool = false


static func accepted(choice_key_value: String, recipient_member_id_value: int) -> LevelUpApplicationResult:
	var result := LevelUpApplicationResult.new()
	result.choice_key = choice_key_value
	result.recipient_member_id = recipient_member_id_value
	result._accepted = true
	return result


static func rejected(choice_key_value: String, recipient_member_id_value: int, reason_value: String) -> LevelUpApplicationResult:
	var result := LevelUpApplicationResult.new()
	result.choice_key = choice_key_value
	result.recipient_member_id = recipient_member_id_value
	result.reason = reason_value
	return result


func ok() -> bool:
	return _accepted
