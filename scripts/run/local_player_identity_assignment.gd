class_name LocalPlayerIdentityAssignment
extends RefCounted

var error := ""
var _identities: Dictionary = {}


func _init(message: String = "", identities: Dictionary = {}) -> void:
	error = message
	_identities = identities.duplicate(true)


func ok() -> bool:
	return error.is_empty()


func identities() -> Dictionary:
	return _identities.duplicate(true)
