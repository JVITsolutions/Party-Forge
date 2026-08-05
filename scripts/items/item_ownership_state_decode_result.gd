class_name ItemOwnershipStateDecodeResult
extends RefCounted

var state: ItemOwnershipState
var error: String

func ok() -> bool:
	return state != null and error.is_empty()
