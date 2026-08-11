extends RefCounted

const FORM_PATH := "res://scripts/ui/loot_lab/loot_lab_request_form.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(FORM_PATH), "Loot Lab request form script exists", failures)
	if not ResourceLoader.exists(FORM_PATH):
		return failures
	var form_script := load(FORM_PATH) as Script
	var form: Variant = form_script.new()
	var preferences_path := "user://developer_item_sandbox/test-request-form-%d.json" % OS.get_process_id()
	_cleanup(preferences_path)
	var store := DeveloperLootLabPreferencesStore.new(AtomicJsonStore.new(), preferences_path)
	form.call(&"configure", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, store)
	var fields := form.get_node("Fields") as GridContainer
	for field: String in ["permitted_rarity_ids", "party_archetype_tags", "unlock_tags", "required_base_tags", "excluded_base_tags", "required_affix_tags", "excluded_affix_tags"]:
		var control := fields.get_node(field.to_pascal_case())
		TestAssertions.truthy(control is MenuButton, "%s uses a controller-operable catalog multi-select" % field, failures)
		if control is MenuButton:
			TestAssertions.truthy((control as MenuButton).get_popup().item_count > 0, "%s exposes catalog-backed choices" % field, failures)
	var difficulty := fields.get_node("DifficultyId") as OptionButton
	var vocabulary_constants := (load("res://scripts/items/item_generation_vocabulary.gd") as Script).get_script_constant_map()
	var difficulties := vocabulary_constants.get("DIFFICULTIES", []) as Array
	TestAssertions.truthy(not difficulties.is_empty(), "shared generation vocabulary declares difficulties", failures)
	TestAssertions.equal(difficulty.item_count, difficulties.size(), "difficulty options come from shared generation vocabulary", failures)
	var document := store.defaults()
	document["seed"] = 90210
	document["generation_sequence"] = 700
	document["item_level"] = 800
	document["source_id"] = "ordinary_enemy"
	document["generation_domain"] = "ordinary_drop"
	document["difficulty_id"] = "normal"
	document["heat"] = 12.5
	document["charisma_value"] = 44.0
	document["permitted_rarity_ids"] = ["rare"]
	document["party_archetype_tags"] = ["melee", "ranged"]
	document["unlock_tags"] = ["rarity_rare_unlocked"]
	document["required_base_tags"] = ["weapon"]
	document["excluded_base_tags"] = ["accessory"]
	document["required_affix_tags"] = []
	document["excluded_affix_tags"] = []
	document["forced_base_id"] = "forge_vanguard_sword"
	document["forced_rarity_id"] = "rare"
	document["batch_preset"] = 10000
	document["custom_batch_count"] = 321
	TestAssertions.equal(form.call(&"apply_preferences", document), "", "form accepts every supported request field", failures)
	TestAssertions.equal(form.call(&"preferences_document"), document, "form round-trips the complete preference document", failures)
	var built := form.call(&"build_batch_spec") as LootLabBatchSpec
	TestAssertions.truthy(built != null and built.ok(), "form builds a validated production batch", failures)
	if built != null and built.ok():
		TestAssertions.equal(built.target_count, 10000, "selected preset reaches the batch boundary", failures)
		var request_document := built.request_document()
		for field: String in ["seed", "generation_sequence", "item_level", "source_id", "generation_domain", "difficulty_id", "heat", "charisma_value", "permitted_rarity_ids", "party_archetype_tags", "unlock_tags", "required_base_tags", "excluded_base_tags", "required_affix_tags", "excluded_affix_tags", "forced_base_id", "forced_rarity_id"]:
			TestAssertions.equal(request_document[field], document[field], "batch request preserves %s" % field, failures)

	document["batch_preset"] = 0
	document["custom_batch_count"] = 100000
	TestAssertions.equal(form.call(&"apply_preferences", document), "", "custom maximum applies", failures)
	built = form.call(&"build_batch_spec") as LootLabBatchSpec
	TestAssertions.equal(built.target_count if built != null else -1, 100000, "custom maximum reaches hard boundary", failures)
	var contradictory := document.duplicate(true)
	contradictory["required_base_tags"] = ["weapon"]
	contradictory["excluded_base_tags"] = ["weapon"]
	TestAssertions.truthy(not String(form.call(&"apply_preferences", contradictory)).is_empty(), "contradictory request fields are rejected locally", failures)
	TestAssertions.equal(form.call(&"preferences_document"), document, "rejected preferences do not mutate the last valid controls", failures)
	form.free()
	_cleanup(preferences_path)
	return failures

func _cleanup(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.previous"]:
		var candidate := "%s%s" % [path, suffix]
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
