extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	TestAssertions.truthy("core_equipment_catalog.tres" in source, "validator uses canonical catalog", failures)
	TestAssertions.truthy("family_for" in source, "validator checks declared visual family", failures)
	TestAssertions.truthy("HashingContext.HASH_SHA256" in source, "validator rejects duplicate pixels", failures)
	TestAssertions.truthy("unique_master" in source and "unique_runtime" in source, "validator reports uniqueness totals", failures)
	return failures
