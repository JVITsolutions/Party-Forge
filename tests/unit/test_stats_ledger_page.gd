extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_member_24_identity(failures)
	var tree := Engine.get_main_loop() as SceneTree
	var page_scene := load("res://scenes/ui/ledger/stats_ledger_page.tscn") as PackedScene
	TestAssertions.truthy(page_scene != null, "stats page scene loads", failures)
	if page_scene == null:
		return failures
	var page := page_scene.instantiate() as StatsLedgerPage
	tree.root.add_child(page)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var fighter := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	party.initialize(fighter, catalog.traits)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, func(_member_id: int) -> Dictionary:
		return {"current": 200.0, "maximum": 260.0, "is_downed": false, "is_dead": false}
	)
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	page.configure(provider, context)

	for method_name: StringName in [&"set_show_all", &"select_stat", &"has_stat"]:
		TestAssertions.truthy(page.has_method(method_name), "stats page exposes %s" % method_name, failures)
	for node_path: NodePath in [
		^"Layout/Header/Identity",
		^"Layout/Header/TraitsAndCapabilities",
		^"Layout/Content/StatSide/ShowAll",
		^"Layout/Content/StatSide/StatScroll/Groups",
		^"Layout/Content/DetailPanel/Detail/Title",
		^"Layout/Content/DetailPanel/Detail/Value",
		^"Layout/Content/DetailPanel/Detail/Description",
		^"Layout/Content/DetailPanel/Detail/Cap",
		^"Layout/Content/DetailPanel/Detail/Sources",
	]:
		TestAssertions.truthy(page.get_node_or_null(node_path) != null, "stats page owns %s" % node_path, failures)
	if not failures.is_empty():
		provider.configure(null, null, Callable())
		page.free()
		party.free()
		return failures

	page.refresh()
	var identity := (page.get_node("Layout/Header/Identity") as Label).text
	TestAssertions.truthy("Fighter" in identity and "Rank 1" in identity and "Frontline" in identity, "header identifies selected class rank and role", failures)
	TestAssertions.truthy("200" in identity and "260" in identity, "header includes runtime health", failures)
	var traits_and_capabilities := (page.get_node("Layout/Header/TraitsAndCapabilities") as Label).text
	TestAssertions.truthy("Martial" in traits_and_capabilities and "Vanguard" in traits_and_capabilities, "header lists selected traits", failures)
	TestAssertions.truthy("Physical" in traits_and_capabilities and "Melee" in traits_and_capabilities, "header lists selected capabilities", failures)
	TestAssertions.truthy(page.has_stat(&"physical_damage"), "fighter shows relevant physical stat", failures)
	TestAssertions.truthy(not page.has_stat(&"fire_damage"), "fighter hides irrelevant fire stat", failures)
	var estimates := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates") as VBoxContainer
	TestAssertions.truthy(estimates != null, "Stats page renders Combat Estimates before stat groups", failures)
	var fighter_card := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_fighter_cleave") as PanelContainer
	TestAssertions.truthy(fighter_card != null, "selected Fighter primary action has an estimate card", failures)
	if fighter_card != null:
		var metrics := (fighter_card.get_node("Content/Metrics") as Label).text
		TestAssertions.truthy("Normal Hit" in metrics and "Critical Hit" in metrics and "Average Hit" in metrics, "card exposes all hit values", failures)
		TestAssertions.truthy("Attacks / Second" in metrics and "Estimated DPS" in metrics, "card exposes rate and DPS", failures)
		TestAssertions.truthy("pre-mitigation" in fighter_card.tooltip_text and "per target" in fighter_card.tooltip_text, "card explains estimate boundary", failures)
	TestAssertions.truthy(page.initial_focus() is Button and (page.initial_focus() as Button).name.begins_with("Stat_"), "combat estimates do not steal first-stat focus", failures)

	var mixed_attack := fighter.primary_attack.duplicate(true) as AttackDefinition
	mixed_attack.id = &"mixed_preview"
	mixed_attack.damage_components = [_damage_component(&"physical", 10.0), _damage_component(&"fire", 5.0)]
	fighter.primary_attack = mixed_attack
	page.refresh()
	var mixed_components_label := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_mixed_preview/Content/Components") as Label
	TestAssertions.truthy(mixed_components_label != null, "mixed estimate exposes a damage-type component breakdown", failures)
	if mixed_components_label != null:
		var mixed_components := mixed_components_label.text
		TestAssertions.truthy("Physical" in mixed_components and "Fire" in mixed_components, "mixed estimate exposes each damage-type component", failures)
	mixed_attack.can_crit = false
	page.refresh()
	var noncritical_metrics := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_mixed_preview/Content/Metrics") as Label
	TestAssertions.truthy(noncritical_metrics != null, "noncritical estimate exposes metrics", failures)
	if noncritical_metrics != null:
		TestAssertions.truthy("Critical Hit: Cannot Crit" in noncritical_metrics.text, "noncritical estimate says Cannot Crit", failures)
	mixed_attack.damage_components = [_damage_component(&"unknown", 10.0)]
	page.refresh()
	var unavailable_metrics := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_mixed_preview/Content/Metrics") as Label
	TestAssertions.truthy(unavailable_metrics != null, "unavailable estimate exposes its reason", failures)
	if unavailable_metrics != null:
		TestAssertions.truthy("Estimate unavailable:" in unavailable_metrics.text and "Unknown damage type" in unavailable_metrics.text, "unavailable estimate explains its reason", failures)
	fighter.primary_attack = null
	page.refresh()
	var empty_estimates := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Empty") as Label
	TestAssertions.truthy(empty_estimates != null and empty_estimates.text == "No damaging actions available.", "empty estimate group explains that no damaging actions are available", failures)

	page.set_show_all(true)
	TestAssertions.truthy(page.has_stat(&"fire_damage"), "Show All reveals fire stat", failures)
	var group_names := (page.get_node("Layout/Content/StatSide/StatScroll/Groups") as VBoxContainer).get_children().map(
		func(group: Node) -> StringName: return group.name
	)
	TestAssertions.equal(group_names, [&"Group_combat_estimates", &"Group_overview", &"Group_offense", &"Group_defense", &"Group_resistances", &"Group_utility"], "Show All follows canonical group order", failures)
	var resistance_group := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_resistances")
	TestAssertions.truthy(resistance_group != null, "Show All creates a Resistances group", failures)
	if resistance_group != null:
		TestAssertions.equal((resistance_group.get_node("Heading") as Label).text, "Resistances", "resistance heading uses registry group", failures)
		for resistance_id: StringName in [&"fire_resistance", &"cold_resistance", &"lightning_resistance", &"chaos_resistance"]:
			TestAssertions.truthy(resistance_group.get_node_or_null("Stat_%s" % resistance_id) != null, "%s is grouped under Resistances" % resistance_id, failures)
	page.set_show_all(false)

	var fire_source := StatModifierSource.create(
		&"test_fire",
		&"test",
		"Test Fire",
		1,
		[StatModifier.create(&"fire_damage", StatModifier.Operation.INCREASED, 0.25, &"test_fire", "Test Fire")],
	)
	party.add_member_source(1, fire_source)
	page.refresh()
	TestAssertions.truthy(page.has_stat(&"fire_damage"), "modifier-caused fire stat remains visible", failures)
	TestAssertions.truthy(page.select_stat(&"armor"), "armor detail opens", failures)
	TestAssertions.truthy("Armor" in (page.get_node("Layout/Content/DetailPanel/Detail/Title") as Label).text, "detail shows canonical stat title", failures)
	TestAssertions.truthy("Base" in (page.get_node("Layout/Content/DetailPanel/Detail/Sources") as Label).text, "detail lists resolver base source", failures)
	TestAssertions.equal((page.get_node("Layout/Content/DetailPanel/Detail/Cap") as Label).text, "Minimum 0.0", "detail shows canonical cap text", failures)
	TestAssertions.truthy("estimate" not in (page.get_node("Layout/Content/DetailPanel/Detail/Sources") as Label).text.to_lower(), "armor detail omits UI-only estimates", failures)
	page.refresh()
	TestAssertions.equal(page.get("selected_stat_id"), &"armor", "refresh preserves a visible stat selection", failures)

	TestAssertions.truthy(page.select_stat(&"fire_damage"), "modified fire detail opens", failures)
	var fire_sources := (page.get_node("Layout/Content/DetailPanel/Detail/Sources") as Label).text
	TestAssertions.truthy("Base: 1" in fire_sources, "source detail includes deterministic base value", failures)
	TestAssertions.truthy("Test Fire: +25% increased" in fire_sources, "source detail includes every named modifier", failures)
	var fire_button := page.get_node("Layout/Content/StatSide/StatScroll/Groups/Group_offense/Stat_fire_damage") as Button
	var canonical_description := String(provider.stat_detail(1, &"fire_damage").description)
	TestAssertions.equal(fire_button.tooltip_text, canonical_description, "hover tooltip uses canonical keyword explanation", failures)
	TestAssertions.truthy(fire_button.focus_mode != Control.FOCUS_NONE, "stat rows remain keyboard focusable", failures)
	fire_button.focus_entered.emit()
	TestAssertions.equal((page.get_node("Layout/Content/DetailPanel/Detail/Description") as Label).text, canonical_description, "focus uses the same canonical keyword detail", failures)
	TestAssertions.truthy(page.initial_focus() is Button, "initial focus returns the first stat row", failures)

	provider.configure(null, null, Callable())
	page.free()
	party.free()
	return failures


func _damage_component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result


func _test_member_24_identity(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var page_scene := load("res://scenes/ui/ledger/stats_ledger_page.tscn") as PackedScene
	if page_scene == null:
		TestAssertions.truthy(false, "stats page scene loads for member 24", failures)
		return
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in 23:
		TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "24-member Stats fixture recruits every Fighter", failures)
	var member_24 := party.member_by_id(24)
	TestAssertions.truthy(member_24 != null, "24-member Stats fixture includes member 24", failures)
	if member_24 == null:
		party.free()
		return
	member_24.character_name = "Twenty Four"

	var page := page_scene.instantiate() as StatsLedgerPage
	tree.root.add_child(page)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 24
	page.configure(provider, context)
	page.refresh()

	var identity := (page.get_node("Layout/Header/Identity") as Label).text
	TestAssertions.truthy("Twenty Four" in identity, "Stats identity renders selected member 24's unique name", failures)
	TestAssertions.equal(context.selected_member_id, 24, "Stats refresh preserves selected member 24 context", failures)

	provider.configure(null, null, Callable())
	page.free()
	party.free()
