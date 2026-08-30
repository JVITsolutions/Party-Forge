extends RefCounted

const CONTROLLER_PATH := "res://scripts/ui/level_up_reveal_controller.gd"
const CARD_SCENE := preload("res://scenes/ui/upgrade_card.tscn")


func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := CARD_SCENE.instantiate() as UpgradeCard
	var typed_api := probe.has_method(&"present") and probe.has_method(&"present_preview") and probe.has_method(&"bound_choice_key")
	probe.free()
	TestAssertions.truthy(typed_api, "UpgradeCard exposes the typed projection and stable-key API", failures)
	if not typed_api:
		return failures
	_test_typed_preview_never_replaces_activation_identity(failures)
	_test_timed_reveal_binds_only_final_typed_projection(failures)
	_test_skip_and_reduced_motion_resolve_immediately(failures)
	return failures


func _test_typed_preview_never_replaces_activation_identity(failures: Array[String]) -> void:
	var card := CARD_SCENE.instantiate() as UpgradeCard
	card.call(&"_ready")
	var activations: Array[StringName] = []
	var detail_requests: Array[StringName] = []
	card.activated.connect(func(choice_key: StringName) -> void: activations.append(choice_key))
	card.detail_requested.connect(func(choice_key: StringName, _anchor: Control) -> void: detail_requests.append(choice_key))

	card.present_preview(_projection("preview:unbound", "Unbound preview"))
	card.pressed.emit()
	TestAssertions.equal(card.bound_choice_key(), &"", "preview cannot invent an activation identity", failures)
	TestAssertions.equal(activations, [], "preview-only card cannot activate", failures)

	var final_projection := _projection("choice:final", "Final offer")
	card.present(final_projection)
	card.focus_entered.emit()
	TestAssertions.equal(detail_requests, [&"choice:final"], "keyboard/controller focus exposes the final typed identity", failures)
	card.present_preview(_projection("choice:decoy", "Cycling preview"))
	TestAssertions.equal(card.bound_choice_key(), &"choice:final", "cycling preview cannot replace final activation identity", failures)
	TestAssertions.truthy(bool(card.get("_focus_inside")), "typed re-presentation preserves focus state", failures)
	card.mouse_entered.emit()
	card.present(final_projection.copy())
	TestAssertions.truthy(bool(card.get("_mouse_inside")), "typed re-presentation preserves hover state", failures)
	card.pressed.emit()
	TestAssertions.equal(activations, [&"choice:final"], "activation emits the final bound key only", failures)
	card.free()


func _test_timed_reveal_binds_only_final_typed_projection(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var controller: Object = fixture.controller
	var cards: Array[UpgradeCard] = fixture.cards
	var projections: Array[UpgradeOfferProjection] = fixture.projections
	var resolved_count := [0]
	controller.connect(&"resolved", func() -> void: resolved_count[0] += 1)
	controller.call(&"play", cards, projections, fixture.previews, false)

	TestAssertions.truthy(controller.call(&"is_revealing"), "timed reveal begins active", failures)
	for index: int in cards.size():
		var card := cards[index]
		TestAssertions.truthy(card.disabled, "revealing card %d is disabled" % index, failures)
		TestAssertions.equal(card.bound_choice_key(), StringName(projections[index].choice_key), "revealing card %d preserves final activation key" % index, failures)
		TestAssertions.near(card.position.y, fixture.base_positions[index].y - 520.0, 0.001, "revealing card %d begins above its base" % index, failures)

	controller.call(&"advance", 0.5)
	for index: int in cards.size():
		var card := cards[index]
		TestAssertions.truthy((card.get_node("Content/Name") as Label).text.begins_with("Preview"), "card %d cycles supplied preview text" % index, failures)
		TestAssertions.equal(card.bound_choice_key(), StringName(projections[index].choice_key), "preview card %d retains final activation key" % index, failures)
		TestAssertions.near(card.position.y, fixture.base_positions[index].y, 0.001, "card %d completes synchronized drop" % index, failures)

	controller.call(&"advance", 0.61)
	TestAssertions.truthy(not controller.call(&"is_revealing"), "timed reveal resolves at total duration", failures)
	TestAssertions.equal(resolved_count[0], 1, "timed reveal emits resolved exactly once", failures)
	_assert_final_cards(cards, projections, failures, "timed")
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

	controller.call(&"play", cards, fixture.projections, fixture.previews, false)
	controller.call(&"skip")
	controller.call(&"skip")
	TestAssertions.truthy(not controller.call(&"is_revealing"), "skip resolves active reveal", failures)
	TestAssertions.equal(resolved_count[0], 1, "skip emits resolved once", failures)
	_assert_final_cards(cards, fixture.projections, failures, "skip")

	controller.call(&"play", cards, fixture.projections, fixture.previews, true)
	TestAssertions.truthy(not controller.call(&"is_revealing"), "reduced motion resolves during play", failures)
	TestAssertions.equal(resolved_count[0], 2, "reduced motion emits one additional resolved", failures)
	_assert_final_cards(cards, fixture.projections, failures, "reduced motion")
	_free_cards(cards)
	controller.free()


func _fixture(failures: Array[String]) -> Dictionary:
	var controller_script := load(CONTROLLER_PATH) as Script
	TestAssertions.truthy(controller_script != null, "LevelUpRevealController script exists", failures)
	if controller_script == null:
		return {}
	var controller: Object = controller_script.new()
	var cards: Array[UpgradeCard] = []
	var projections: Array[UpgradeOfferProjection] = []
	var base_positions: Array[Vector2] = []
	for index: int in 5:
		var card := CARD_SCENE.instantiate() as UpgradeCard
		card.position = Vector2(float(index * 20), float(40 + index * 7))
		card.call(&"_ready")
		var projection := _projection("choice:%d" % index, "Final %d" % index, "Capped." if index == 1 else "")
		card.present(projection)
		cards.append(card)
		projections.append(projection)
		base_positions.append(card.position)
	var previews: Array[UpgradeOfferProjection] = []
	for index: int in 4:
		previews.append(_projection("preview:%d" % index, "Preview %d" % index))
	return {
		"controller": controller,
		"cards": cards,
		"projections": projections,
		"previews": previews,
		"base_positions": base_positions,
	}


func _projection(key: String, name: String, disabled_reason: String = "") -> UpgradeOfferProjection:
	var projection := UpgradeOfferProjection.new()
	projection.choice_key = key
	projection.display_name = name
	projection.category_id = &"authored"
	projection.rarity_label = "Common"
	projection.effect_text = "%s effect" % name
	projection.scope_text = "Party"
	projection.rank_text = "Rank 1"
	projection.eligibility_text = "Eligible"
	projection.disabled_reason = disabled_reason
	return projection


func _assert_final_cards(cards: Array[UpgradeCard], projections: Array[UpgradeOfferProjection], failures: Array[String], context: String) -> void:
	for index: int in cards.size():
		TestAssertions.equal((cards[index].get_node("Content/Name") as Label).text, "Final %d" % index, "%s restores card %d text" % [context, index], failures)
		TestAssertions.equal(cards[index].bound_choice_key(), StringName(projections[index].choice_key), "%s restores card %d key" % [context, index], failures)
		TestAssertions.equal(cards[index].disabled, index == 1, "%s restores card %d disabled state" % [context, index], failures)


func _free_cards(cards: Array[UpgradeCard]) -> void:
	for card: UpgradeCard in cards:
		card.free()
