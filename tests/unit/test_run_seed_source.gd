extends RefCounted

const RUN_SEED_SOURCE_PATH := "res://scripts/run/run_seed_source.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_injectable_new_run_source(failures)
	_test_same_seed_reproduces_names_classes_and_upgrades(failures)
	_test_bounded_multi_run_variability(failures)
	return failures


func _test_injectable_new_run_source(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(RUN_SEED_SOURCE_PATH), "fresh run seed source exists", failures)
	if not ResourceLoader.exists(RUN_SEED_SOURCE_PATH):
		return
	var seed_values: Array[int] = [44001, 44002]
	var source: Variant = (load(RUN_SEED_SOURCE_PATH) as Script).new(func() -> int: return seed_values.pop_front())
	TestAssertions.equal([source.call(&"next_seed"), source.call(&"next_seed")], [44001, 44002], "each brand-new normal run consumes one fresh injected seed", failures)
	var source_text := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	TestAssertions.truthy(source_text.contains("func configure_new_run_seed_source(source: RefCounted)"), "Main exposes an injectable new-run seed seam", failures)
	TestAssertions.truthy("const RUN_SEED := 1337" not in source_text, "Main no longer owns a fixed normal-run seed", failures)
	TestAssertions.truthy("run_seed: int =" not in source_text, "run preparation requires an explicit seed", failures)
	TestAssertions.truthy(source_text.contains("_prepare_run_start(definition, bootstrap.run_seed)"), "committed recovery keeps its explicit deterministic seed", failures)


func _test_same_seed_reproduces_names_classes_and_upgrades(failures: Array[String]) -> void:
	var first := _run_signature(77119)
	var repeat := _run_signature(77119)
	TestAssertions.equal(repeat, first, "the same explicit seed reproduces names, recruit classes, and authored upgrades", failures)


func _test_bounded_multi_run_variability(failures: Array[String]) -> void:
	var names: Dictionary = {}
	var recruit_classes: Dictionary = {}
	var authored_upgrades: Dictionary = {}
	var signatures: Dictionary = {}
	for run_offset: int in range(64):
		var signature := _run_signature(88000 + run_offset)
		names[String(signature.get("leader_name", ""))] = true
		for class_id: String in signature.get("recruit_classes", []) as Array:
			recruit_classes[class_id] = true
		for upgrade_id: String in signature.get("authored_upgrades", []) as Array:
			authored_upgrades[upgrade_id] = true
		signatures[JSON.stringify(signature)] = true
	var catalog := GameCatalog.load_defaults()
	var possible_fighter_names: Dictionary = {}
	for name: String in catalog.class_by_id(&"fighter").name_pool.names:
		possible_fighter_names[name] = true
	for name: String in catalog.generic_name_pool.names:
		possible_fighter_names[name] = true
	TestAssertions.truthy(names.size() >= 4 and names.size() <= possible_fighter_names.size(), "64 deterministic new-run seeds produce a bounded spread of valid leader names", failures)
	TestAssertions.truthy(recruit_classes.size() >= 4 and recruit_classes.size() <= catalog.classes.size(), "64 deterministic new-run seeds produce a bounded spread of recruit classes", failures)
	TestAssertions.truthy(authored_upgrades.size() >= 6 and authored_upgrades.size() <= catalog.upgrades.size(), "64 deterministic new-run seeds produce a bounded spread of authored upgrades", failures)
	TestAssertions.truthy(signatures.size() >= 8 and signatures.size() <= 64, "different new-run seeds produce varied bounded outcome signatures", failures)
	for class_id: String in recruit_classes:
		TestAssertions.truthy(catalog.class_by_id(StringName(class_id)) != null, "distribution contains only catalogued recruit class %s" % class_id, failures)
	for upgrade_id: String in authored_upgrades:
		TestAssertions.truthy(catalog.upgrade_by_id(StringName(upgrade_id)) != null, "distribution contains only catalogued authored upgrade %s" % upgrade_id, failures)


func _run_signature(run_seed: int) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.configure_identity(run_seed, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var state := LevelUpOfferState.new()
	state.consecutive_eligible_without_recruit = RecruitOfferPolicy.DROUGHT_LIMIT
	var choices := LevelUpChoiceService.generate(
		party,
		catalog,
		state.seed_for(run_seed, 2, party.members.size()),
		8,
		state,
	)
	var recruit_classes: Array[String] = []
	var authored_upgrades: Array[String] = []
	for choice: UpgradeChoice in choices:
		if choice.kind == UpgradeChoice.Kind.RECRUIT:
			recruit_classes.append(String(choice.target_id))
		elif choice.kind == UpgradeChoice.Kind.AUTHORED:
			authored_upgrades.append(String(choice.target_id))
	var result := {
		"leader_name": party.members[0].character_name,
		"recruit_classes": recruit_classes,
		"authored_upgrades": authored_upgrades,
	}
	party.free()
	return result
