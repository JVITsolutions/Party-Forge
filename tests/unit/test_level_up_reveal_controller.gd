extends RefCounted

const CONTROLLER_PATH := "res://scripts/ui/level_up_reveal_controller.gd"
const CARD_SCENE := preload("res://scenes/ui/upgrade_card.tscn")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_timed_reveal_preserves_choices_and_resolves_once(failures)
	_test_skip_and_reduced_motion_resolve_immediately(failures)
	return failures


func _test_timed_reveal_preserves_choices_and_resolves_once(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var controller: Object = fixture.controller
	var cards: Array[UpgradeCard] = fixture.cards
	var choices: Array[UpgradeChoice] = fixture.choices
	var resolved_count := [0]
	controller.connect(&"resolved", func() -> void: resolved_count[0] += 1)
	controller.call(&"play", cards, fixture.bindings, fixture.previews, false)

	TestAssertions.truthy(controller.call(&"is_revealing"), "timed reveal begins active", failures)
	for index: int in cards.size():
		var card := cards[index]
		TestAssertions.truthy(card.disabled, "revealing card %d is disabled" % index, failures)
		TestAssertions.equal(card.bound_choice(), choices[index], "revealing card %d preserves its final choice" % index, failures)
		TestAssertions.near(card.position.y, fixture.base_positions[index].y - 520.0, 0.001, "revealing card %d begins above its base" % index, failures)
		var activation_count := [0]
		card.activated.connect(func(_choice: UpgradeChoice) -> void: activation_count[0] += 1)
		card.pressed.emit()
		TestAssertions.equal(activation_count[0], 0, "revealing card %d cannot activate" % index, failures)

	controller.call(&"advance", 0.5)
	for index: int in cards.size():
		var card := cards[index]
		TestAssertions.truthy((card.get_node("Content/Name") as Label).text.begins_with("Preview"), "card %d cycles supplied preview text" % index, failures)
		TestAssertions.equal(card.bound_choice(), choices[index], "preview card %d remains bound to final choice" % index, failures)
		TestAssertions.near(card.position.y, fixture.base_positions[index].y, 0.001, "card %d completes synchronized drop" % index, failures)

	controller.call(&"advance", 0.61)
	TestAssertions.truthy(not controller.call(&"is_revealing"), "timed reveal resolves at total duration", failures)
	TestAssertions.equal(resolved_count[0], 1, "timed reveal emits resolved exactly once", failures)
	for index: int in cards.size():
		var card := cards[index]
		TestAssertions.equal((card.get_node("Content/Name") as Label).text, "Final %d" % index, "card %d restores final presentation" % index, failures)
		TestAssertions.equal(card.bound_choice(), choices[index], "card %d restores exact final choice" % index, failures)
		TestAssertions.equal(card.disabled, index == 1, "card %d applies final disabled reason" % index, failures)
		TestAssertions.near(card.position.y, fixture.base_positions[index].y, 0.001, "card %d restores exact base position" % index, failures)
	controller.call(&"advance", 1.0)
	TestAssertions.equal(resolved_count[0], 1, "resolved does not repeat after completion", failures)
	_free_cards(cards)
	controller.free()


func _test_skip_and_reduced_motion_resolve_immediately(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var controller: Object = fixture.controller
	var cards: Array[UpgradeCard] = fixture.cards
	var resolved_count := [0]
	controller.connect(&"resolved", func() -> void: resolved_count[0] += 1)

	controller.call(&"play", cards, fixture.bindings, fixture.previews, false)
	controller.call(&"skip")
	controller.call(&"skip")
	TestAssertions.truthy(not controller.call(&"is_revealing"), "skip resolves active reveal", failures)
	TestAssertions.equal(resolved_count[0], 1, "skip emits resolved once", failures)
	_assert_final_cards(cards, fixture.choices, failures, "skip")

	controller.call(&"play", cards, fixture.bindings, fixture.previews, true)
	TestAssertions.truthy(not controller.call(&"is_revealing"), "reduced motion resolves during play", failures)
	TestAssertions.equal(resolved_count[0], 2, "reduced motion emits one additional resolved", failures)
	_assert_final_cards(cards, fixture.choices, failures, "reduced motion")
	_free_cards(cards)
	controller.free()


func _fixture(failures: Array[String]) -> Dictionary:
	var controller_script := load(CONTROLLER_PATH) as Script
	TestAssertions.truthy(controller_script != null, "LevelUpRevealController script exists", failures)
	if controller_script == null:
		return {}
	var controller: Object = controller_script.new()
	var catalog := GameCatalog.load_defaults()
	var ids: Array[StringName] = [&"vanguard_wall", &"vitality", &"precision", &"tempered_armor", &"deadeye"]
	var cards: Array[UpgradeCard] = []
	var choices: Array[UpgradeChoice] = []
	var bindings: Array[Dictionary] = []
	var base_positions: Array[Vector2] = []
	for index: int in ids.size():
		var card := CARD_SCENE.instantiate() as UpgradeCard
		card.position = Vector2(float(index * 20), float(40 + index * 7))
		card.call(&"_ready")
		var choice := UpgradeChoice.authored(catalog.upgrade_by_id(ids[index]))
		var presentation := _presentation("Final %d" % index)
		card.bind_choice(choice, presentation, "Capped." if index == 1 else "")
		cards.append(card)
		choices.append(choice)
		bindings.append({
			"choice": choice,
			"presentation": presentation,
			"disabled_reason": "Capped." if index == 1 else "",
		})
		base_positions.append(card.position)
	var previews: Array[Dictionary] = []
	for index: int in 4:
		previews.append(_presentation("Preview %d" % index))
	return {
		"controller": controller,
		"cards": cards,
		"choices": choices,
		"bindings": bindings,
		"previews": previews,
		"base_positions": base_positions,
	}


func _presentation(name: String) -> Dictionary:
	return {
		"name": name,
		"scope_badge": "Party",
		"rank_text": "Rank 1",
		"summary": "%s summary" % name,
	}


func _assert_final_cards(cards: Array[UpgradeCard], choices: Array[UpgradeChoice], failures: Array[String], context: String) -> void:
	for index: int in cards.size():
		TestAssertions.equal((cards[index].get_node("Content/Name") as Label).text, "Final %d" % index, "%s restores card %d text" % [context, index], failures)
		TestAssertions.equal(cards[index].bound_choice(), choices[index], "%s restores card %d choice" % [context, index], failures)
		TestAssertions.equal(cards[index].disabled, index == 1, "%s restores card %d disabled state" % [context, index], failures)


func _free_cards(cards: Array[UpgradeCard]) -> void:
	for card: UpgradeCard in cards:
		card.free()
