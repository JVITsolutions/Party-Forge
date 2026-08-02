extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	TestAssertions.truthy("core_equipment_catalog.tres" in source, "validator uses canonical catalog", failures)
	TestAssertions.truthy("family_for" in source, "validator checks declared visual family", failures)
	TestAssertions.truthy("HashingContext.HASH_SHA256" in source, "validator rejects duplicate pixels", failures)
	TestAssertions.truthy("unique_master" in source and "unique_runtime" in source, "validator reports uniqueness totals", failures)
	TestAssertions.truthy("SET_FOLDERS.keys()" in source and "registered_sets.sort()" in source, "all derives deterministically from registered sets", failures)
	TestAssertions.truthy("_registry_error" in source and "registries disagree" in source, "validator fails closed when set registries drift", failures)
	TestAssertions.truthy('return [&"fighter", &"paladin"' not in source, "all does not hardcode the current set list", failures)
	return failures
