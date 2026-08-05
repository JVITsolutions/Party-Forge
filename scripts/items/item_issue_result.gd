class_name ItemIssueResult
extends RefCounted

var item: ItemInstance
var error: String

func ok() -> bool:
	return item != null and error.is_empty()
