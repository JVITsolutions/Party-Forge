class_name ItemGenerationResult
extends RefCounted

var item: ItemInstance
var failure: ItemGenerationFailure
var trace: ItemGenerationTrace

func ok() -> bool:
	return item != null and failure == null
